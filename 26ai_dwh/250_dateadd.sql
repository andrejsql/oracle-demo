SET ECHO OFF
REM File name...: 250_dateadd.sql
REM Author......: Andrej Pashchenko
REM Description.: Date arithmetic before and with DATEADD
@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON PAGESIZE 100 LINESIZE 200
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF3';
COLUMN plus_days FORMAT A24
COLUMN overlap_start FORMAT A24
COLUMN plus_hours FORMAT A24
COLUMN plus_months FORMAT A24
COLUMN month_end FORMAT A24

-- OLD: different expressions for dates, intervals and month arithmetic.
WITH t (d, ts) AS (
  SELECT DATE '2026-04-30', TIMESTAMP '2026-04-30 10:15:00.250'
  FROM dual
)
SELECT d + 7                              AS plus_days,
       ts - INTERVAL '15' MINUTE           AS overlap_start,
       ts + NUMTODSINTERVAL(1, 'HOUR')     AS plus_hours,
       ts + NUMTOYMINTERVAL(1, 'MONTH')    AS plus_months,
       ADD_MONTHS(ts, 1)                   AS month_end
FROM t;
PAUSE Press Enter for DATEADD

-- NEW: one syntax; the return type matches the input datetime type.
-- First four results match OLD. Last column intentionally differs:
-- ADD_MONTHS returns May 31 as DATE; DATEADD returns May 30 as TIMESTAMP.
WITH t (d, ts) AS (
  SELECT DATE '2026-04-30', TIMESTAMP '2026-04-30 10:15:00.250'
  FROM dual
)
SELECT DATEADD(DAY,     7, d)  AS plus_days,
       DATEADD(MINUTE,-15, ts) AS overlap_start,
       DATEADD(HOUR,    1, ts) AS plus_hours,
       DATEADD(MONTH,   1, ts) AS plus_months,
       DATEADD(MONTH,   1, ts) AS month_end
FROM t;
PAUSE Press Enter to finish
EXIT

