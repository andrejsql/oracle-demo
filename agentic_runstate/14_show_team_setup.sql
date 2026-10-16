SET ECHO OFF
REM Andrej SQL - SELECT AI run-state demo
REM Show only run-state demo metadata.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

COLUMN object_name FORMAT A26
COLUMN attribute_name FORMAT A25
COLUMN attribute_value FORMAT A100 WORD_WRAPPED
SELECT agent_name AS object_name, attribute_name, attribute_value
FROM user_ai_agent_attributes
WHERE agent_name IN ('ETLR_SUPERVISOR', 'ETLR_FETCHER_AGENT',
                     'ETLR_RESOLVER_AGENT', 'ETLR_HUMAN_AGENT',
                     'ETLR_EXECUTOR_AGENT', 'ETLR_FINALIZER_AGENT')
ORDER BY agent_name, attribute_name;
PAUSE Press Enter to show tasks
SELECT task_name AS object_name, attribute_name, attribute_value
FROM user_ai_agent_task_attributes
WHERE task_name IN ('ETLR_FETCH_TASK', 'ETLR_RESOLVE_TASK', 'ETLR_HUMAN_TASK',
                    'ETLR_EXECUTE_TASK', 'ETLR_FINALIZE_TASK')
ORDER BY task_name, attribute_name;
PAUSE Press Enter to show team
SELECT agent_team_name AS object_name, attribute_name, attribute_value
FROM user_ai_agent_team_attributes
WHERE agent_team_name = 'ETLR_OPS_TEAM'
ORDER BY agent_team_name, attribute_name;

PAUSE Review the results, then press Enter to close this window.
EXIT
