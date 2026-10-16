SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 60_run_team.sql
REM Author......: Andrej Pashchenko
REM Description.: Show the results of the last team run for SELECT AI Agent demo
REM Notes.......: -
REM Parameters..: -
REM Dependencies: uses define_alhdb.sql
REM Requirements: Oracle Database 26ai (Autonomous)
REM
REM ***************************************************************************

@define_alhdb.sql
CONNECT /@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 1000 LINESIZE 100

column team_name format a15
column task_name format a20
column agent_name format a18
column state format a10
column prompt format a5
column prompt_response format a35 WORD_WRAPPED
column tool_input format a20 WORD_WRAPPED
column tool_output format a20 WORD_WRAPPED
column tool_name format a20
set long 600
set longchunksize 600
set linesize 320
set pages 3333

spool teamrun.txt





WITH latest_team AS (
  SELECT team_exec_id, team_name, start_date, h.state, h.conversation_id
  FROM user_ai_agent_team_history h
  ORDER BY start_date DESC
  FETCH FIRST 1 ROW ONLY
),
latest_task AS (
  SELECT team_exec_id
       , task_name
       , agent_name
       , conversation_params
       , start_date
       , end_date
       , task_order
  FROM user_ai_agent_task_history
),
prompts AS (
  SELECT p.*
       , LAG(p.created) OVER (
           PARTITION BY p.conversation_id
           ORDER BY p.created
         ) AS prev_created
  FROM user_cloud_ai_conversation_prompts p
)
SELECT team.state
     , task.task_name
     , TO_CHAR(task.start_date, 'YYYY-MM-DD HH24:MI:SS') AS start_date
     , task.agent_name
     , REPLACE(REPLACE(DBMS_LOB.SUBSTR(p.prompt, 500, 1), CHR(13)), CHR(10), ' ') AS prompt
     , REPLACE(REPLACE(DBMS_LOB.SUBSTR(p.prompt_response, 600, 1), CHR(13)), CHR(10), ' ') AS prompt_response
     , th.tool_name
--     , TO_CHAR(th.start_date, 'YYYY-MM-DD HH24:MI:SS') AS tool_start_date
--     , TO_CHAR(th.end_date, 'YYYY-MM-DD HH24:MI:SS') AS tool_end_date
     , REPLACE(REPLACE(DBMS_LOB.SUBSTR(th.input, 200, 1), CHR(13)), CHR(10), ' ') AS tool_input
     , REPLACE(REPLACE(DBMS_LOB.SUBSTR(th.output, 200, 1), CHR(13)), CHR(10), ' ') AS tool_output
     --, p.created
FROM latest_team team
JOIN latest_task task
  ON task.team_exec_id = team.team_exec_id
LEFT JOIN prompts p
  ON p.conversation_id = JSON_VALUE(task.conversation_params, '$.conversation_id')
OUTER APPLY (
  SELECT th.*
  FROM user_ai_agent_tool_history th
  WHERE th.team_exec_id = task.team_exec_id
  AND th.task_order = task.task_order
  AND th.end_date > NVL(p.prev_created, TIMESTAMP '1900-01-01 00:00:00')
  AND th.end_date < p.created
  AND p.prompt_response IS NOT NULL
  ORDER BY th.end_date DESC
  FETCH FIRST 1 ROW ONLY
) th
ORDER BY task.start_date ASC NULLS LAST
       , p.created ASC NULLS LAST;

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT