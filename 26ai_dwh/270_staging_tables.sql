SET ECHO OFF
REM File name...: 270_staging_tables.sql
REM Author......: Andrej Pashchenko
REM Description.: Staging-table properties and restrictions
REM Dependencies: define.sql
REM Requirements: Oracle AI Database 26ai
@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 180

COLUMN table_name FORMAT A18
COLUMN staging FORMAT A8
COLUMN compression FORMAT A12
COLUMN stattype_locked FORMAT A16
COLUMN last_analyzed FORMAT A20

DROP TABLE IF EXISTS stg_load PURGE;
DROP TABLE IF EXISTS stg_ctas PURGE;
DROP TABLE IF EXISTS stg_convert PURGE;

-------------------------------------------------------------------------------
-- Create a staging table and inspect its properties
-------------------------------------------------------------------------------
CREATE TABLE stg_load (
  load_id  NUMBER,
  payload  VARCHAR2(100)
) FOR STAGING;

SELECT table_name, staging, compression
FROM user_tables
WHERE table_name = 'STG_LOAD';

SELECT table_name, stattype_locked, num_rows, last_analyzed
FROM user_tab_statistics
WHERE table_name = 'STG_LOAD'
  AND partition_name IS NULL;

PAUSE Press Enter to try explicit statistics gathering

-- Expected: ORA-20005, because statistics are locked.
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'STG_LOAD');
END;
/

PAUSE Press Enter for the CTAS caveat

-------------------------------------------------------------------------------
-- CTAS gathers statistics while it creates the data.
-- They remain present but locked on the resulting staging table.
-------------------------------------------------------------------------------
CREATE TABLE stg_ctas FOR STAGING AS
SELECT LEVEL AS load_id, RPAD('x', 20, 'x') AS payload
FROM dual
CONNECT BY LEVEL <= 1000;

SELECT t.table_name, t.staging, s.stattype_locked,
       s.num_rows, s.last_analyzed
FROM user_tables t
JOIN user_tab_statistics s
  ON s.table_name = t.table_name
 AND s.partition_name IS NULL
WHERE t.table_name = 'STG_CTAS';

PAUSE Press Enter to try compression

-- Expected: ORA-38500, compression is disallowed for staging tables.
ALTER TABLE stg_load COMPRESS;

PAUSE Press Enter to convert an existing table

-------------------------------------------------------------------------------
-- An existing heap table can be converted in either direction.
-------------------------------------------------------------------------------
CREATE TABLE stg_convert (
  load_id NUMBER
);

ALTER TABLE stg_convert FOR STAGING;

SELECT table_name, staging, compression
FROM user_tables
WHERE table_name = 'STG_CONVERT';

ALTER TABLE stg_convert NOT FOR STAGING;

SELECT table_name, staging, compression
FROM user_tables
WHERE table_name = 'STG_CONVERT';

PAUSE Press Enter to verify recycle-bin behavior

-------------------------------------------------------------------------------
-- DROP bypasses the recycle bin even when PURGE is not specified.
-------------------------------------------------------------------------------
DROP TABLE stg_load;

SELECT original_name, object_name
FROM user_recyclebin
WHERE original_name = 'STG_LOAD';

PAUSE Press Enter to finish and clean up

DROP TABLE stg_ctas;
DROP TABLE stg_convert PURGE;

EXIT
