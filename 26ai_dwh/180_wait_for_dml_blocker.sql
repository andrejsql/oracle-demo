SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 180_wait_for_dml_blocker.sql
REM Author......: Andrej Pashchenko
REM Description.: DML with WAIT clause - blocker session setup
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai RU 23.26.2+ for WAIT clause
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200
SET AUTOCOMMIT OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CLEAR SCREEN


update sh.sales
set    amount_sold = amount_sold + 1
where  prod_id = 37
wait   5;


-------------------------------------------------------------------------------
--   Keep this transaction open. Run 181 in session 2 now.
--   Wait for both NOWAIT and WAIT 5 tests to finish before continuing here.
-------------------------------------------------------------------------------

pause Press Enter TO CONTINUE

ROLLBACK;


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT
