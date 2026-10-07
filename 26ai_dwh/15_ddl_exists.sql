SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 15_ddl_exists.sql
REM Author......: Andrej Pashchenko
REM Description.: DDL with EXISTS / NOT EXISTS
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 100

CLEAR SCREEN

-------------------------------------------------------------------------------
-- Old way
-------------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE customers PURGE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
      RAISE;
    END IF;
END;
/

pause Press Enter TO CONTINUE 

-------------------------------------------------------------------------------
-- New way
-------------------------------------------------------------------------------

DESC customers

-- Table does not exist
DROP TABLE IF EXISTS customers PURGE;

pause Press Enter TO CONTINUE 

ALTER TABLE IF EXISTS customers ADD customer_name VARCHAR2(100);

pause Press Enter TO CONTINUE 

CREATE TABLE IF NOT EXISTS customers (
  id NUMBER PRIMARY KEY
);

pause Press Enter TO CONTINUE 

-- No replacement and no definition comparison: this is a successful no-op.
CREATE TABLE IF NOT EXISTS customers (
    id NUMBER PRIMARY KEY
  , customer_name VARCHAR2(100)
);

pause Press Enter TO CONTINUE 


ALTER TABLE IF EXISTS customers ADD customer_name VARCHAR2(100);

pause Press Enter TO CONTINUE 

-- IF EXISTS checks the table, not the requested alteration.
-- Expected: ORA-01430 because CUSTOMER_NAME already exists.
ALTER TABLE IF EXISTS customers ADD customer_name VARCHAR2(100);

pause Press Enter TO CONTINUE

DESC customers


DROP TABLE IF EXISTS customers PURGE;

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT