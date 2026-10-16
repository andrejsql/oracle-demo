SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Reset ONLY supervisor demo data; leaves team definitions intact.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

DELETE FROM etls_run;
DELETE FROM etls_action_log;
DELETE FROM etls_kb;
DELETE FROM etls_job_log;
UPDATE etls_checkpoint SET last_log_id = 0 WHERE singleton = 1;
COMMIT;
PROMPT Supervisor data reset. Run 15 to seed the mixed batch and its one known incident.
PROMPT Old framework history remains available; old conversations must not be resumed.

PAUSE Review the results, then press Enter to close this window.
EXIT
