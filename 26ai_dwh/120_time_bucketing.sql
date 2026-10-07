SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 120_time_bucketing.sql
REM Author......: Andrej Pashchenko
REM Description.: Time bucketing functions in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

CLEAR SCREEN

-------------------------------------------------------------------------------
-- Group sales from 2020-01-01 into consecutive 10-day buckets.
-- Bucket boundaries are [start, end); END labels the exclusive upper boundary.
-- Buckets do not restart at the beginning of each month.
-------------------------------------------------------------------------------


SELECT
      DATE '2020-01-01'
    + FLOOR( (time_id - DATE '2020-01-01') / 10 ) * 10
    + 10 AS bucket_end,
     COUNT(*),
     SUM(amount_sold)
FROM sh.sales
WHERE time_id >= DATE '2020-01-01'
GROUP BY DATE '2020-01-01'
       + FLOOR((time_id - DATE '2020-01-01') / 10) * 10 + 10
ORDER BY bucket_end
FETCH FIRST 10 ROWS ONLY;

pause Press Enter TO CONTINUE

-- origin is required; START is the default, END is explicit here.
SELECT
  TIME_BUCKET(time_id, INTERVAL '10' DAY, DATE '2020-01-01', END ) AS bucket_end,
  COUNT(*),
  SUM(amount_sold)
FROM sh.sales
WHERE time_id >= date '2020-01-01'
GROUP BY bucket_end
ORDER BY bucket_end
FETCH FIRST 10 ROWS ONLY;


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT
