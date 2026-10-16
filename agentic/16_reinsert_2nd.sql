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
  'LOAD_ORDERS', 
  'ERROR', 
  'ORA-00904: "INVDATE": invalid identifier'
);

INSERT INTO etl_job_log (job_name, log_level, message)
VALUES (
  'PROCESS_SALES', 
  'ERROR', 
  'ORA-08103: object no longer exists'
);

INSERT INTO etl_job_log (job_name, log_level, message)
VALUES (
  'PROCESS_REPORTS', 
  'ERROR', 
  'ORA-01652: unable to extend temp segment in tablespace'
);

commit;
-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT