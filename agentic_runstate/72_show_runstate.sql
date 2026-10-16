SET ECHO OFF
REM Database snapshots of runtime variables; never a recovery source.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 30000 LONGCHUNKSIZE 30000
COLUMN variable_name FORMAT A15
COLUMN value FORMAT A130 WORD_WRAPPED
PROMPT Latest run-state snapshots. GET_VARIABLE in this new session cannot inspect another run.
WITH latest_run AS (
  SELECT run_id FROM etlr_state_snapshot WHERE variable_name = 'batch'
  ORDER BY updated_at DESC FETCH FIRST 1 ROW ONLY
)
SELECT s.run_id, s.variable_name, s.updated_at, JSON_SERIALIZE(s.value PRETTY RETURNING CLOB) value
FROM etlr_state_snapshot s JOIN latest_run r ON r.run_id = s.run_id
ORDER BY CASE s.variable_name WHEN 'batch' THEN 1 WHEN 'resolutions' THEN 2
  WHEN 'decisions' THEN 3 ELSE 4 END;
PROMPT Full originals appear here for presenter inspection, not in supervisor delegations.
PAUSE Review the results, then press Enter to close this window.
EXIT
