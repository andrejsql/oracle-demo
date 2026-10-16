SET ECHO OFF
REM Andrej SQL - SELECT AI run-state demo
REM Seed two unknown errors and one known error in the middle.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

-- Run after 11, or after 13 for another demonstration.
INSERT INTO etlr_job_log(log_id, job_name, message) VALUES (
  101, 'LOAD_CUSTOMERS',
  'ORA-12899: value too large for column CUST_POSTAL_CODE (actual 12 > maximum 10)');
INSERT INTO etlr_job_log(log_id, job_name, message) VALUES (
  102, 'PROCESS_SALES',
  'ORA-08103: object no longer exists');
INSERT INTO etlr_job_log(log_id, job_name, message) VALUES (
  103, 'LOAD_INVENTORY',
  'ORA-00904: "INVDATE": invalid identifier');

-- A prior, simulated restart is the sole seeded experience.
-- The same raw text is used for retrieval, making the intended known match clear.
INSERT INTO etlr_kb(error_text, action, embedding)
VALUES ('ORA-08103: object no longer exists', 'RESTART_ETL_JOB',
        pkg_etlr_demo.embed_text('ORA-08103: object no longer exists'));
COMMIT;
SELECT log_id, job_name, message FROM etlr_job_log ORDER BY log_id;
PROMPT Expected: restart 102 before asking one combined question about 101 and 103.

PAUSE Review the results, then press Enter to close this window.
EXIT
