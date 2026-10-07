SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 130_datediff.sql
REM Author......: Andrej Pashchenko
REM Description.: DATEDIFF function in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

CLEAR SCREEN

alter session set nls_territory = 'GERMANY';
set lines 200

column d1 format a19
column d2 format a19
column years format 99
column fiscal_years format 99
column months format 999
column weeks format 999
column weeks_monday format 999
column weeks_sunday format 999
column minutes format 9999999
column elapsed_duration format a29
column seconds format 9999999999
alter session set nls_calendar = 'GREGORIAN';

-------------------------------------------------------------------------------
-- Counts period boundaries, not completed units of elapsed time.
-- YEAR with start_of_period = 9 uses September 1 as the fiscal-year boundary.
-- The year-end example spans one minute but crosses one year and one month.
-- start_of_period is supported only for WEEK, QUARTER and YEAR.
-------------------------------------------------------------------------------

-- Previous approach: expressions for each unit; sample rows use older syntax.
WITH dates (d1, d2) AS (
  SELECT TIMESTAMP '2025-09-30 00:00:00', DATE '2026-08-30' FROM dual
  UNION ALL
  SELECT TIMESTAMP '2025-09-30 00:00:00', DATE '2026-10-01' FROM dual
  UNION ALL
  SELECT TIMESTAMP '2025-12-31 23:59:00', DATE '2026-01-01' FROM dual
  UNION ALL
  SELECT TIMESTAMP '2025-09-30 13:00:01', DATE '2026-10-01' FROM dual
)
SELECT to_char(d1, 'YYYY-MM-DD HH24:MI:SS') d1,
       to_char(d2, 'YYYY-MM-DD HH24:MI:SS') d2,
       d2 - d1 AS elapsed_duration, EXTRACT(YEAR FROM d2) - EXTRACT(YEAR FROM d1) AS years
,      EXTRACT(YEAR FROM ADD_MONTHS(d2, -8)) - EXTRACT(YEAR FROM ADD_MONTHS(d1, -8)) AS fiscal_years
,      (EXTRACT(YEAR FROM d2) - EXTRACT(YEAR FROM d1)) * 12
       + EXTRACT(MONTH FROM d2) - EXTRACT(MONTH FROM d1) AS months
,      (TRUNC(CAST(d2 AS DATE), 'D') - TRUNC(CAST(d1 AS DATE), 'D')) / 7 AS weeks
,      (TRUNC(CAST(d2 AS DATE), 'IW') - TRUNC(CAST(d1 AS DATE), 'IW')) / 7 AS weeks_monday
,      (TRUNC(CAST(d2 AS DATE) + 1, 'IW') - TRUNC(CAST(d1 AS DATE) + 1, 'IW')) / 7 AS weeks_sunday
,      ROUND((CAST(TRUNC(d2, 'MI') AS DATE) - CAST(TRUNC(d1, 'MI') AS DATE)) * 24 * 60) AS minutes
,      EXTRACT(DAY FROM (d2 - d1)) * 86400 
       + EXTRACT(HOUR FROM (d2 - d1)) * 3600
       + EXTRACT(MINUTE FROM (d2 - d1)) * 60
       + EXTRACT(SECOND FROM (d2 - d1))  AS seconds
FROM dates;

pause Press Enter for DATEDIFF

with dates (d1, d2) as 
     ( values (date '2025-09-30', date '2026-08-30') 
       ,      (date '2025-09-30', date '2026-10-01') 
       ,      (timestamp '2025-12-31 23:59:00', date '2026-01-01') 
       ,      (timestamp '2025-09-30 13:00:01', date '2026-10-01')
     )
select to_char(d1, 'YYYY-MM-DD HH24:MI:SS') d1,
       to_char(d2, 'YYYY-MM-DD HH24:MI:SS') d2,
       d2 - d1 AS elapsed_duration, datediff(year, d1, d2)   years
,      datediff(year, d1, d2,9) fiscal_years
,      datediff(month, d1, d2)   months
,      datediff(week, d1, d2)    weeks  -- determined by NLS_TERRITORY
,      datediff(week, d1, d2,1)  weeks_monday
,      datediff(week, d1, d2,7)  weeks_sunday
,      datediff(minute, d1, d2)  minutes
,      datediff(second, d1, d2) seconds
from dates ;   

pause Press Enter for TIMESTAMPDIFF

-- TIMESTAMPDIFF is a synonym of DATEDIFF in Oracle: identical semantics.
with dates (d1, d2) as 
     ( values (date '2025-09-30', date '2026-08-30') 
       ,      (date '2025-09-30', date '2026-10-01') 
       ,      (timestamp '2025-12-31 23:59:00', date '2026-01-01') 
       ,      (timestamp '2025-09-30 13:00:01', date '2026-10-01')
     )
select to_char(d1, 'YYYY-MM-DD HH24:MI:SS') d1,
       to_char(d2, 'YYYY-MM-DD HH24:MI:SS') d2,
       d2 - d1 AS elapsed_duration, timestampdiff(year, d1, d2)   years
,      timestampdiff(year, d1, d2,9) fiscal_years
,      timestampdiff(month, d1, d2)   months
,      timestampdiff(week, d1, d2)    weeks  -- determined by NLS_TERRITORY
,      timestampdiff(week, d1, d2,1)  weeks_monday
,      timestampdiff(week, d1, d2,7)  weeks_sunday
,      timestampdiff(minute, d1, d2)  minutes
,      timestampdiff(second, d1, d2) seconds
from dates ;   

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT


