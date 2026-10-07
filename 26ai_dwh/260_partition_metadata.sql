SET ECHO OFF
REM File name...: 260_partition_metadata.sql
REM Author......: Andrej Pashchenko
REM Description.: LONG workaround, CLOB access and JSON retention candidates
REM Dependencies: define.sql; access to SH.SALES partition metadata
REM Requirements: Oracle AI Database 26ai; DBMS_XMLGEN execution
@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON PAGESIZE 100 LINESIZE 160
SET LONG 2000 LONGCHUNKSIZE 2000
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';
COLUMN partition_name FORMAT A20
COLUMN high_value_text FORMAT A95
COLUMN high_value_clob FORMAT A95

-- OLD: expose the LONG boundary expression through XML as VARCHAR2.
-- The 4000-character extraction is sufficient for this single DATE key.
-- Extract the date from TO_DATE expression text to apply the retention filter.
-- Demo-specific: one DATE key with midnight boundaries, not a general parser.
-- MAXVALUE contains no matching date and is excluded as NULL.
SELECT partition_name, high_value_text
FROM XMLTABLE(
  '/ROWSET/ROW'
  PASSING DBMS_XMLGEN.GETXMLTYPE(q'[
    SELECT partition_name, high_value
    FROM all_tab_partitions
    WHERE table_owner = 'SH' AND table_name = 'SALES'
  ]')
  COLUMNS
    partition_name VARCHAR2(128) PATH 'PARTITION_NAME',
    high_value_text VARCHAR2(4000) PATH 'HIGH_VALUE'
)
WHERE TO_DATE(
        REGEXP_SUBSTR(high_value_text, '[0-9]{4}-[0-9]{2}-[0-9]{2}'),
        'YYYY-MM-DD'
      ) <= DATE '2020-01-01';
      
PAUSE Press Enter for direct CLOB access

-- NEW: same expression text, without the XML workaround.
-- This is still SQL expression text, not a DATE value.
-- The same text parsing is needed here; only the XML conversion disappears.
SELECT partition_name, high_value_clob
FROM all_tab_partitions
WHERE table_owner = 'SH' AND table_name = 'SALES'
  AND TO_DATE(
        REGEXP_SUBSTR(DBMS_LOB.SUBSTR(high_value_clob, 4000, 1),
                      '[0-9]{4}-[0-9]{2}-[0-9]{2}'),
        'YYYY-MM-DD'
      ) <= DATE '2020-01-01'
ORDER BY partition_position;
PAUSE Press Enter for typed JSON access

-- Single-column DATE range partitions: extract the boundary as DATE.
-- Exclusive upper bound <= cutoff: all rows are before the cutoff.
-- MAXVALUE or missing/non-date high_value maps to NULL with the default
-- JSON_VALUE error handling and is not selected. Not a generic rule for
-- list partitions or composite keys.
-- Read-only candidates: no partitions are dropped by this demo.
SELECT partition_name,
       JSON_VALUE(high_value_json, '$.high_value'
                  RETURNING DATE) AS upper_bound
FROM all_tab_partitions
WHERE table_owner = 'SH' AND table_name = 'SALES'
  AND JSON_VALUE(high_value_json, '$.high_value'
                 RETURNING DATE) <= DATE '2020-01-01'
ORDER BY partition_position;
PAUSE Press Enter to finish
EXIT
