SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 10_select_wo_from.sql
REM Author......: Andrej Pashchenko
REM Description.: Show the SELECT without FROM clause
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 100

CLEAR SCREEN

-------------------------------------------------------------------------------
-- No need to type "FROM DUAL" anymore
-------------------------------------------------------------------------------
SELECT 'without DUAL!' as message;

SELECT sysdate;

pause Press Enter TO CONTINUE 

-------------------------------------------------------------------------------
-- It works in PL/SQL as well
-------------------------------------------------------------------------------
declare
v_date date; 
begin
  SELECT sysdate 
  INTO   v_date;
  dbms_output.put_line(v_date); 
  -- (!) But the right thing to do in PL/SQL is:
  v_date := sysdate;
end;
/

pause Press Enter TO CONTINUE 


-------------------------------------------------------------------------------
-- Query Transformation behind the scenes
-------------------------------------------------------------------------------

WITH FUNCTION get_sql (p_sql IN CLOB) RETURN CLOB IS
p_sql_out CLOB;
BEGIN
  DBMS_UTILITY.EXPAND_SQL_TEXT (p_sql, p_sql_out);
  RETURN p_sql_out;
END;
SELECT get_sql(q'[SELECT sysdate]')
/
   
   

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT