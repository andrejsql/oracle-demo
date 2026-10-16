SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Show only supervisor demo metadata.
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
WHERE agent_name LIKE 'ETLS!_%' ESCAPE '!'
ORDER BY agent_name, attribute_name;
PAUSE Press Enter to show tasks
SELECT task_name AS object_name, attribute_name, attribute_value
FROM user_ai_agent_task_attributes
WHERE task_name LIKE 'ETLS!_%' ESCAPE '!'
ORDER BY task_name, attribute_name;
PAUSE Press Enter to show team
SELECT agent_team_name AS object_name, attribute_name, attribute_value
FROM user_ai_agent_team_attributes
WHERE agent_team_name = 'ETLS_OPS_TEAM'
ORDER BY attribute_name;

PAUSE Review the results, then press Enter to close this window.
EXIT
