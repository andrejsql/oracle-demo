SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM Description.: Unrestricted direct loads: load, inspect, modify, roll back
REM Dependencies: define.sql; SELECT on SH.SALES, V_$MYSTAT and V_$STATNAME
REM Requirements: CREATE TABLE and quota; heap table in ASSM/AUTOALLOCATE
REM               tablespace; COMPATIBLE >= 23.0
REM Creates.....: DWH_DP_STAGE (dropped at the end; no existing object replaced)
REM Run.........: @26ai_dwh/230_direct_path_transaction.sql
REM Dedicated demo session: setup/cleanup DDL commits; source data is read-only.
REM Serial APPEND is tested here, not parallel execution or SQL*Loader.
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 160
SET VERIFY OFF AUTOCOMMIT OFF
SET AUTOTRACE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

ALTER SESSION ENABLE PARALLEL DML;

CREATE TABLE dwh_dp_stage (
    batch_id    NUMBER,
    cust_id     NUMBER,
    amount_sold NUMBER,
    load_status VARCHAR2(10)
) NOPARALLEL;

VARIABLE writes_before NUMBER
BEGIN
    SELECT s.value INTO :writes_before
    FROM   v$mystat s
    JOIN   v$statname n ON n.statistic# = s.statistic#
    WHERE  n.name = 'physical writes direct';
END;
/

CLEAR SCREEN
-------------------------------------------------------------------------------
-- 1. Direct-path load. No COMMIT follows this INSERT.
-- Earlier releases: reading the target afterwards raised ORA-12838.
-------------------------------------------------------------------------------

INSERT /*+ APPEND NO_PARALLEL */ INTO dwh_dp_stage
SELECT 1, cust_id, amount_sold, 'NEW'
FROM   sh.sales
WHERE  ROWNUM <= 10000;

-- Evidence of actual direct writes: an APPEND hint alone is not proof.
SELECT s.value - :writes_before direct_blocks_written
FROM   v$mystat s
JOIN   v$statname n ON n.statistic# = s.statistic#
WHERE  n.name = 'physical writes direct';

-- Online statistics gathered during the first load into the empty heap.
-- This identifies statistics gathered on load, not every direct-path INSERT:
-- subsequent loads into a nonempty table need not gather fresh statistics.
COLUMN notes FORMAT A30
COLUMN column_name FORMAT A20
SELECT column_name, num_distinct, notes
FROM   user_tab_col_statistics
WHERE  table_name = 'DWH_DP_STAGE'
ORDER BY column_name;
-- Expected in column statistics: STATS_ON_LOAD.

-- Read and validate the loaded batch in the SAME transaction.
SELECT batch_id, COUNT(*) row_count, SUM(amount_sold) total_amount
FROM   dwh_dp_stage
GROUP BY batch_id;

PAUSE Press Enter TO CONTINUE

-------------------------------------------------------------------------------
-- 2. Another direct-path load into the SAME table, still without COMMIT.
-- Savepoint lets us discard only the second batch.
-------------------------------------------------------------------------------

SAVEPOINT first_batch_loaded;

INSERT /*+ APPEND NO_PARALLEL */ INTO dwh_dp_stage
SELECT 2, cust_id, amount_sold, 'NEW'
FROM   sh.sales
WHERE  ROWNUM <= 10000;

SELECT batch_id, COUNT(*) row_count
FROM   dwh_dp_stage
GROUP BY batch_id
ORDER BY batch_id;

PAUSE Press Enter TO CONTINUE

ROLLBACK TO first_batch_loaded;

-- Only batch 1 remains, and it is STILL UNCOMMITTED.
SELECT batch_id, COUNT(*) row_count
FROM   dwh_dp_stage
GROUP BY batch_id;

PAUSE Press Enter TO CONTINUE

-------------------------------------------------------------------------------
-- 3. Conventional DML after the direct-path load, in the SAME transaction.
-- Example: mark a batch after its validation step has completed.
-------------------------------------------------------------------------------

UPDATE /*+ NO_PARALLEL */ dwh_dp_stage
SET    load_status = 'CHECKED'
WHERE  batch_id = 1;

SELECT load_status, COUNT(*) row_count
FROM   dwh_dp_stage
GROUP BY load_status;

PAUSE Press Enter TO CONTINUE

-------------------------------------------------------------------------------
-- 4. Reject the load: roll back both the first INSERT and its UPDATE.
-- In a successful real batch, COMMIT would go here instead.
-- No intermediate COMMIT was needed to inspect or modify the target.
-------------------------------------------------------------------------------

ROLLBACK;

SELECT COUNT(*) rows_after_rollback FROM dwh_dp_stage;


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------

PAUSE Press Enter TO FINISH

DROP TABLE dwh_dp_stage PURGE;

-- Documentation: "Restrictions on Parallel DML" / lifted restrictions
-- https://docs.oracle.com/en/database/oracle/oracle-database/26/vldbg/using-parallel.html
-- New Features: "Unrestricted Direct Loads"
-- https://docs.oracle.com/en/database/oracle/oracle-database/26/nfcoa/all-nfg.html
EXIT
