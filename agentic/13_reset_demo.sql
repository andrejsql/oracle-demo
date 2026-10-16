SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 13_reset_demo.sql
REM Author......: Andrej Pashchenko
REM Description.: Reset log tables used for SELECT AI Agent demo
REM Notes.......: -
REM Parameters..: -
REM Dependencies: uses define_alhdb.sql
REM Requirements: Oracle Database 26ai (Autonomous)
REM
REM ***************************************************************************

@define_alhdb.sql
CONNECT /@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 1000 LINESIZE 100



DELETE FROM etl_job_log;

DELETE FROM ETL_LOG_SETTINGS;

DELETE FROM ETL_KB_ENTRIES;

commit;

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT