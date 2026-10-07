SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 181_wait_for_dml.sql
REM Author......: Andrej Pashchenko
REM Description.: DML with WAIT clause in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai RU 23.26.2+; run 180 first
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200
SET AUTOCOMMIT OFF TIMING ON
WHENEVER SQLERROR CONTINUE NONE

CLEAR SCREEN


-- Session 180 must still hold the locks on product 37.
-- Expected: immediate lock error; only this statement is rolled back.
update sh.sales
set    amount_sold = amount_sold + 10
where  prod_id = 37
nowait ;

pause Press Enter TO CONTINUE



-- Expected: lock timeout after approximately five seconds.
-- WAIT limits lock waiting.
update sh.sales
set    amount_sold = amount_sold + 10
where  prod_id = 37
wait   5;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------

ROLLBACK;

pause Press Enter TO CONTINUE
 
EXIT
