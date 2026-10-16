SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Inspect checkpoint, simulated restarts and learned experience.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

COLUMN job_name FORMAT A24
COLUMN message FORMAT A80 WORD_WRAPPED
COLUMN action FORMAT A20
COLUMN error_text FORMAT A80 WORD_WRAPPED
SELECT last_log_id AS checkpoint FROM etls_checkpoint WHERE singleton = 1;
SELECT log_id, job_name, message FROM etls_job_log ORDER BY log_id;
SELECT action_id, log_id, action, created_at FROM etls_action_log ORDER BY action_id;
SELECT entry_id, source_log_id, error_text, action FROM etls_kb ORDER BY entry_id;
PROMPT Before the human reply: expected restart 102, checkpoint 0.
PROMPT After handling the full first batch: expected checkpoint 103.
PROMPT Email calls appear in framework tool history (70), not the simulated restart log.

PAUSE Review the results, then press Enter to close this window.
EXIT
