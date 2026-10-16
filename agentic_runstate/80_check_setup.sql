SET ECHO OFF
REM Read-only; no state writes, embeddings, agents or mail.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

SELECT object_name, object_type, status FROM user_objects
WHERE object_name LIKE 'ETLR!_%' ESCAPE '!' OR object_name = 'PKG_ETLR_DEMO'
ORDER BY object_type, object_name;
SELECT name, type, line, position, text FROM user_errors
WHERE name = 'PKG_ETLR_DEMO' ORDER BY sequence;
SELECT owner, object_name, procedure_name FROM all_procedures
WHERE object_name = 'DBMS_CLOUD_AI_AGENT'
  AND procedure_name IN ('SET_VARIABLE', 'GET_VARIABLE', 'RUN_TEAM', 'CREATE_TEAM')
ORDER BY owner, procedure_name;
SELECT agent_name, status FROM user_ai_agents
WHERE agent_name IN ('ETLR_SUPERVISOR', 'ETLR_FETCHER_AGENT',
                     'ETLR_RESOLVER_AGENT', 'ETLR_HUMAN_AGENT',
                     'ETLR_EXECUTOR_AGENT', 'ETLR_FINALIZER_AGENT')
ORDER BY agent_name;
SELECT log_id, job_name, message FROM
  (SELECT log_id, job_name, message FROM etlr_job_log
   WHERE log_id > (SELECT last_log_id FROM etlr_checkpoint WHERE singleton = 1)
   ORDER BY log_id FETCH FIRST 3 ROWS ONLY);
PROMPT Run 60, inspect 70/71/72 while paused, and resume with 61.
PAUSE Review the results, then press Enter to close this window.
EXIT
