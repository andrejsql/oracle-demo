SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Add similar incidents to demonstrate reuse of learned experience.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

INSERT INTO etls_job_log(log_id, job_name, message) VALUES (
  201, 'LOAD_CUSTOMERS_NEXT',
  'ORA-12899: value too large for column CUST_POSTAL_CODE (actual 12 > maximum 10)');
INSERT INTO etls_job_log(log_id, job_name, message) VALUES (
  202, 'PROCESS_SALES_NEXT',
  'ORA-08103: object no longer exists');
INSERT INTO etls_job_log(log_id, job_name, message) VALUES (
  203, 'LOAD_INVENTORY_NEXT',
  'ORA-00904: "INVDATE": invalid identifier');
COMMIT;
PROMPT Run 60 again after completing the first batch.
PROMPT A prior NONE choice creates no KB entry, so that error can need human input again.

PAUSE Review the results, then press Enter to close this window.
EXIT
