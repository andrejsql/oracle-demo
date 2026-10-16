SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 13_reset_demo.sql
REM Author......: Andrej Pashchenko
REM Description.: Insert log data 1st part used for SELECT AI Agent demo
REM Notes.......: -
REM Parameters..: -
REM Dependencies: uses define_alhdb.sql
REM Requirements: Oracle Database 26ai (Autonomous)
REM
REM ***************************************************************************

@define_alhdb.sql
CONNECT /@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 1000 LINESIZE 100



INSERT INTO etl_job_log (job_name, log_level, message)
VALUES (
  'LOAD_CUSTOMERS', 
  'ERROR', 
  'ORA-12899: value too large for column CUST_POSTAL_CODE (actual 12 > maximum 10)'
);

INSERT INTO etl_job_log (job_name, log_level, message)
VALUES (
  'LOAD_ORDERS', 
  'ERROR', 
  'ORA-01400: cannot insert NULL into ("STG"."STG_ORDERS"."ORDER_DATE")'
);

INSERT INTO etl_job_log (job_name, log_level, message)
VALUES (
  'LOAD_INVENTORY', 
  'ERROR', 
  'ORA-00904: "INVDATE": invalid identifier'
);

commit;
-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT