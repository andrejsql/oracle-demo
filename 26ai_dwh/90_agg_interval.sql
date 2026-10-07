SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM File name...: 90_agg_interval.sql
REM Author......: Andrej Pashchenko
REM Description.: Aggregate ETL run durations without numeric conversion
REM Dependencies: define.sql; CREATE TABLE privilege and tablespace quota
REM Requirements: Oracle Database 26ai
REM ***************************************************************************
@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON PAGESIZE 100 LINESIZE 160
SET AUTOCOMMIT OFF
COLUMN pipeline_name FORMAT A18
COLUMN duration FORMAT A30
COLUMN total_runtime FORMAT A30
COLUMN avg_runtime FORMAT A30
COLUMN running_runtime FORMAT A30

-- Dedicated demo object; recreated on each run.
DROP TABLE IF EXISTS dwh_interval_run_demo PURGE;
CREATE TABLE dwh_interval_run_demo (
  run_id        NUMBER PRIMARY KEY,
  pipeline_name VARCHAR2(30) NOT NULL,
  started_at    TIMESTAMP(3) NOT NULL,
  finished_at   TIMESTAMP(3) NOT NULL,
  CHECK (finished_at >= started_at)
);

-- Fixed timestamps give reproducible results, including fractional seconds.
INSERT INTO dwh_interval_run_demo (run_id, pipeline_name, started_at, finished_at)
VALUES
  (1, 'SALES_LOAD', TIMESTAMP '2026-09-01 01:00:00', TIMESTAMP '2026-09-01 01:10:00.250'),
  (2, 'SALES_LOAD', TIMESTAMP '2026-09-02 01:00:00', TIMESTAMP '2026-09-02 01:20:00.750'),
  (3, 'SALES_LOAD', TIMESTAMP '2026-09-03 01:00:00', TIMESTAMP '2026-09-03 01:15:00.500'),
  (4, 'CUSTOMER_LOAD', TIMESTAMP '2026-09-01 02:00:00', TIMESTAMP '2026-09-01 02:04:00'),
  (5, 'CUSTOMER_LOAD', TIMESTAMP '2026-09-02 02:00:00', TIMESTAMP '2026-09-02 02:06:00'),
  (6, 'CUSTOMER_LOAD', TIMESTAMP '2026-09-03 02:00:00', TIMESTAMP '2026-09-03 02:05:00');
COMMIT;


-- TIMESTAMP subtraction produces INTERVAL DAY TO SECOND.
SELECT pipeline_name, run_id, finished_at - started_at AS duration
FROM dwh_interval_run_demo
ORDER BY pipeline_name, started_at, run_id;

PAUSE Press Enter for the previous approach

-- Previously: convert the interval to seconds, aggregate, then convert back.
-- Casting timestamps to DATE would lose fractional seconds.
WITH run_durations AS (
  SELECT pipeline_name, finished_at - started_at AS duration
  FROM dwh_interval_run_demo
), run_seconds AS (
  SELECT pipeline_name,
         EXTRACT(DAY    FROM duration) * 86400
       + EXTRACT(HOUR   FROM duration) * 3600
       + EXTRACT(MINUTE FROM duration) * 60
       + EXTRACT(SECOND FROM duration) AS seconds_elapsed
  FROM run_durations
)
SELECT pipeline_name,
       NUMTODSINTERVAL(SUM(seconds_elapsed), 'SECOND') AS total_runtime,
       NUMTODSINTERVAL(AVG(seconds_elapsed), 'SECOND') AS avg_runtime
FROM run_seconds
GROUP BY pipeline_name
ORDER BY pipeline_name;
PAUSE Press Enter for direct interval aggregation

-- 26ai: same results, with the interval retained throughout.
-- SALES_LOAD: total 00:45:01.500; average 00:15:00.500.
-- CUSTOMER_LOAD: total 00:15:00; average 00:05:00.
-- SUM is accumulated run time, not elapsed batch time for overlapping runs.
SELECT pipeline_name,
       SUM(finished_at - started_at) AS total_runtime,
       AVG(finished_at - started_at) AS avg_runtime
FROM dwh_interval_run_demo
GROUP BY pipeline_name
ORDER BY pipeline_name;

PAUSE Press Enter for analytic interval aggregation

-- Retain each run and show cumulative duration and the pipeline average.
SELECT pipeline_name, run_id,
       finished_at - started_at AS duration,
       SUM(finished_at - started_at) OVER (
         PARTITION BY pipeline_name
         ORDER BY started_at, run_id
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_runtime,
       AVG(finished_at - started_at) OVER (
         PARTITION BY pipeline_name
       ) AS avg_runtime
FROM dwh_interval_run_demo
ORDER BY pipeline_name, started_at, run_id;

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
PAUSE Press Enter to clean up and finish
DROP TABLE dwh_interval_run_demo PURGE;
EXIT
