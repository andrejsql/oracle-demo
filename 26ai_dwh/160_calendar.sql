SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 160_calendar.sql
REM Author......: Andrej Pashchenko
REM Description.: Calendar functions in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';
ALTER SESSION SET NLS_DATE_LANGUAGE = 'ENGLISH';
ALTER SESSION SET NLS_CALENDAR = 'GREGORIAN';
COLUMN fiscal_year_start FORMAT A17
COLUMN fiscal_year_end FORMAT A15

CLEAR SCREEN


-------------------------------------------------------------------------------
--   Previous expressions: fiscal year starts on October 1
-------------------------------------------------------------------------------

WITH dates (d) AS (SELECT DATE '2021-01-01' FROM dual)
SELECT  
  TRUNC(d, 'YYYY')                                      AS year_start
, ADD_MONTHS(TRUNC(d, 'YYYY'), 12) - 1                  AS year_end
, LAST_DAY(d)                                           AS month_end
, TO_CHAR(d, 'YYYY-MM')                                 AS month_desc
, TO_CHAR(d, 'YYYY "Q"Q')                               AS quarter_desc
, TO_NUMBER(TO_CHAR(d, 'MM'))                           AS month_of_year
, TO_NUMBER(TO_CHAR(d, 'Q'))                            AS quarter_of_year
, ADD_MONTHS(TRUNC(ADD_MONTHS(d, -9), 'YYYY'), 9)        AS fiscal_year_start
, ADD_MONTHS(TRUNC(ADD_MONTHS(d, -9), 'YYYY'), 21)-1      AS fiscal_year_end
, TO_NUMBER(TO_CHAR(ADD_MONTHS(d, -9), 'MM'))           AS fiscal_month
, TRUNC((TRUNC(d) -
  ADD_MONTHS(TRUNC(ADD_MONTHS(d, -9), 'YYYY'), 9)) / 7)+1 AS fiscal_week
FROM dates;



pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--   CALENDAR functions in Oracle 26ai
-------------------------------------------------------------------------------

ALTER SESSION SET CALENDAR_FISCAL_YEAR_START='10-01','MM-DD';

WITH dates (d) AS ( SELECT DATE '2021-01-01' FROM dual)
SELECT
  CALENDAR_YEAR_START_DATE(d)     AS year_start
, CALENDAR_YEAR_END_DATE(d)       AS year_end
, CALENDAR_MONTH_END_DATE(d)      AS month_end
, CALENDAR_MONTH(d,'YYYY-MM')     AS month_desc
, CALENDAR_QUARTER(d,'YYYY "Q"Q') AS quarter_desc
, CALENDAR_MONTH_OF_YEAR(d)       AS month_of_year
, CALENDAR_QUARTER_OF_YEAR(d)     AS quarter_of_year
, FISCAL_YEAR_START_DATE(d)       AS fiscal_year_start
, FISCAL_YEAR_END_DATE(d)         AS fiscal_year_end
, FISCAL_MONTH_OF_YEAR(d, DATE '2000-10-01', 'POSITION') AS fiscal_month
, FISCAL_WEEK_OF_YEAR(d)          AS fiscal_week
FROM dates;


PAUSE Press Enter for two semantic details

-- DATE (default) is calendar-month numbering; POSITION is fiscal numbering.
-- Only the month/day of the explicit fiscal-year start argument matter.
WITH dates (d) AS (SELECT DATE '2021-01-01' FROM dual)
SELECT FISCAL_MONTH_OF_YEAR(d) AS default_month,
       FISCAL_MONTH_OF_YEAR(d, DATE '2000-10-01', 'POSITION') AS fiscal_month,
       TO_CHAR(d, 'IYYY-IW') AS iso_week,
       CALENDAR_WEEK(d) AS calendar_week,
       TRUNC(d, 'IW') + 6 AS iso_week_end,
       CALENDAR_WEEK_END_DATE(d) AS calendar_week_end
FROM dates;

-- Calendar weeks here are not ISO weeks. Period end dates are at midnight
-- on the last calendar day, not exclusive upper boundaries as in TIME_BUCKET.

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT

