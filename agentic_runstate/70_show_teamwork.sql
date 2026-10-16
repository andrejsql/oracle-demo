SET ECHO OFF
REM Andrej SQL - SELECT AI run-state demo
REM Timeline for the latest supervisor conversation, including HITL continuations.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 300 LONG 12000 LONGCHUNKSIZE 12000

spool teamrun_runstate.txt

COLUMN seq FORMAT 999
COLUMN event_time FORMAT A12
COLUMN step FORMAT A12
COLUMN task_order FORMAT 999
COLUMN agent_name FORMAT A22
COLUMN task_name FORMAT A20
COLUMN tool_name FORMAT A25
COLUMN task_state FORMAT A24
COLUMN prompt_text FORMAT A55 WORD_WRAPPED
COLUMN response_text FORMAT A75 WORD_WRAPPED

PROMPT Sequence of the latest ETLR_OPS_TEAM conversation
PROMPT SUPERVISOR -> DELEGATE/HUMAN_WAIT -> TOOL -> AGENT_TURN -> RESULT -> COMPLETE
-- A worker's start is the earliest exposed evidence of delegation.
-- A tool is shown once, at completion (or at start while it is still running).
-- AGENT_TURN is timestamped when Oracle records the conversation row. For a
-- supervisor delegation this can be after the delegated worker has returned.
-- Keep TIMESTAMP WITH TIME ZONE until sorting; display all events in Europe/Berlin.
WITH latest_conversation AS (
  SELECT h.conversation_id
  FROM user_ai_agent_team_history h
  WHERE h.team_name = 'ETLR_OPS_TEAM'
  ORDER BY h.start_date DESC, h.team_exec_id DESC
  FETCH FIRST 1 ROW ONLY
),
team_runs AS (
  SELECT h.*
  FROM user_ai_agent_team_history h
  JOIN latest_conversation c ON c.conversation_id = h.conversation_id
  WHERE h.team_name = 'ETLR_OPS_TEAM'
),
tasks AS (
  SELECT t.*
  FROM user_ai_agent_task_history t
  WHERE EXISTS (
    SELECT 1 FROM team_runs h WHERE h.team_exec_id = t.team_exec_id
  )
),
conversation_members AS (
  SELECT conversation_id, 'ETLR_SUPERVISOR' AS agent_name
  FROM latest_conversation
  UNION
  SELECT JSON_VALUE(conversation_params, '$.conversation_id'), agent_name
  FROM tasks
),
conversations AS (
  SELECT conversation_id,
         CASE
           WHEN MAX(CASE WHEN agent_name = 'ETLR_SUPERVISOR' THEN 1 ELSE 0 END) = 1
             THEN 'ETLR_SUPERVISOR'
           WHEN COUNT(DISTINCT agent_name) = 1 THEN MIN(agent_name)
           ELSE '(multiple agents)'
         END AS agent_name
  FROM conversation_members
  WHERE conversation_id IS NOT NULL
  GROUP BY conversation_id
),
events AS (
  SELECT t.start_date AS event_at,
         1 AS event_sort,
         'SUPERVISOR' AS step,
         t.team_exec_id,
         t.task_order,
         t.agent_name,
         t.task_name,
         CAST(NULL AS VARCHAR2(128)) AS tool_name,
         CASE
           WHEN t.end_date IS NULL THEN t.state
         END AS task_state,
         CAST(NULL AS VARCHAR2(500)) AS prompt_text,
         CAST(NULL AS VARCHAR2(500)) AS response_text
  FROM tasks t
  WHERE t.task_order = 0
  UNION ALL
  SELECT t.start_date,
         2,
         CASE WHEN t.task_name = 'ETLR_HUMAN_TASK'
              THEN 'HUMAN_WAIT' ELSE 'DELEGATE' END,
         t.team_exec_id,
         t.task_order,
         t.agent_name,
         t.task_name,
         CAST(NULL AS VARCHAR2(128)),
         CASE WHEN t.end_date IS NULL THEN t.state END,
         CAST(NULL AS VARCHAR2(500)),
         CAST(NULL AS VARCHAR2(500))
  FROM tasks t
  WHERE t.task_order <> 0
  UNION ALL
  SELECT COALESCE(th.end_date, th.start_date),
         3,
         'TOOL',
         th.team_exec_id,
         th.task_order,
         th.agent_name,
         th.task_name,
         th.tool_name,
         CAST(NULL AS VARCHAR2(30)),
         CAST(NULL AS VARCHAR2(500)),
         CAST(NULL AS VARCHAR2(500))
  FROM user_ai_agent_tool_history th
  WHERE EXISTS (
    SELECT 1 FROM team_runs h WHERE h.team_exec_id = th.team_exec_id
  )
  UNION ALL
  SELECT p.created,
         4,
         'AGENT_TURN',
         CAST(NULL AS VARCHAR2(128)),
         CAST(NULL AS NUMBER),
         c.agent_name,
         CAST(NULL AS VARCHAR2(128)),
         CAST(NULL AS VARCHAR2(128)),
         CAST(NULL AS VARCHAR2(30)),
         DBMS_LOB.SUBSTR(p.prompt, 500, 1),
         DBMS_LOB.SUBSTR(p.prompt_response, 500, 1)
  FROM user_cloud_ai_conversation_prompts p
  JOIN conversations c ON c.conversation_id = p.conversation_id
  UNION ALL
  SELECT t.end_date,
         5,
         'RESULT',
         t.team_exec_id,
         t.task_order,
         t.agent_name,
         t.task_name,
         CAST(NULL AS VARCHAR2(128)),
         t.state,
         CAST(NULL AS VARCHAR2(500)),
         CAST(NULL AS VARCHAR2(500))
  FROM tasks t
  WHERE t.task_order <> 0
  AND t.end_date IS NOT NULL
  UNION ALL
  SELECT t.end_date,
         6,
         'COMPLETE',
         t.team_exec_id,
         t.task_order,
         t.agent_name,
         t.task_name,
         CAST(NULL AS VARCHAR2(128)),
         t.state,
         CAST(NULL AS VARCHAR2(500)),
         CAST(NULL AS VARCHAR2(500))
  FROM tasks t
  WHERE t.task_order = 0
  AND t.end_date IS NOT NULL
)
SELECT ROW_NUMBER() OVER (
         ORDER BY event_at NULLS LAST, event_sort, team_exec_id, task_order
       ) AS seq,
       TO_CHAR(event_at AT TIME ZONE 'Europe/Berlin', 'HH24:MI:SS.FF3') AS event_time,
       step, task_order, agent_name, task_name, tool_name, task_state,
       REPLACE(REPLACE(prompt_text, CHR(13), ' '), CHR(10), ' ') AS prompt_text,
       REPLACE(REPLACE(response_text, CHR(13), ' '), CHR(10), ' ') AS response_text
FROM events
ORDER BY event_at NULLS LAST, event_sort, team_exec_id, task_order;


PAUSE Review the results, then press Enter to close this window.
EXIT


