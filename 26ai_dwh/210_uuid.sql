SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 210_uuid.sql
REM Author......: Andrej Pashchenko
REM Description.: UUID data type and functions in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 


SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

CLEAR SCREEN

-------------------------------------------------------------------------------
--        Generate old and new one UUID
-------------------------------------------------------------------------------

WITH uuids AS 
(SELECT SYS_GUID() uu_old , UUID() uu_new)
SELECT * FROM uuids;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--        The new UUID can be converted to a canonical string
-------------------------------------------------------------------------------

WITH uuids AS 
(SELECT SYS_GUID() uu_old , UUID() uu_new)
SELECT uu_new, raw_to_uuid(uu_new) FROM uuids;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--   But not each RAW(16) can be converted, the old SYS_GUID-generated - cannot
-------------------------------------------------------------------------------

WITH uuids AS 
(SELECT SYS_GUID() uu_old , UUID() uu_new)
SELECT uu_old, raw_to_uuid(uu_old)  FROM uuids;


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT
