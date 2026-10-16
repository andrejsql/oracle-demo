SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Read-only checks; does not run agents, send mail or request embeddings.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

SELECT object_name, object_type, status FROM user_objects
WHERE object_name LIKE 'ETLS!_%' ESCAPE '!' OR object_name = 'PKG_ETLS_DEMO'
ORDER BY object_type, object_name;
SELECT name, type, line, position, text FROM user_errors
WHERE name = 'PKG_ETLS_DEMO' ORDER BY sequence;
SELECT agent_name, status FROM user_ai_agents
WHERE agent_name LIKE 'ETLS!_%' ESCAPE '!' ORDER BY agent_name;
SELECT pkg_etls_demo.fetch_batch() AS next_batch FROM dual;
PROMPT Full runtime validation: run 60, inspect 70/71 while waiting, then resume with 61.

PAUSE Review the results, then press Enter to close this window.
EXIT
