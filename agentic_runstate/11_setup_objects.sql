SET ECHO OFF
REM Andrej SQL - SELECT AI run-state demo
REM Create isolated tables and package (run once).
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

CREATE TABLE etlr_job_log (
  log_id NUMBER PRIMARY KEY,
  job_name VARCHAR2(128) NOT NULL,
  message VARCHAR2(4000) NOT NULL,
  log_timestamp TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE TABLE etlr_checkpoint (
  singleton NUMBER PRIMARY KEY CHECK (singleton = 1),
  last_log_id NUMBER DEFAULT 0 NOT NULL
);
INSERT INTO etlr_checkpoint VALUES (1, 0);
CREATE TABLE etlr_kb (
  entry_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_log_id NUMBER UNIQUE,
  error_text VARCHAR2(4000) NOT NULL,
  action VARCHAR2(30) NOT NULL,
  embedding VECTOR,
  created_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE TABLE etlr_action_log (
  action_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  run_id VARCHAR2(32) NOT NULL,
  log_id NUMBER NOT NULL,
  action VARCHAR2(30) NOT NULL,
  result CLOB,
  created_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  UNIQUE(run_id, log_id)
);
CREATE TABLE etlr_run (
  singleton NUMBER PRIMARY KEY CHECK (singleton = 1),
  conversation_id VARCHAR2(128) NOT NULL,
  started_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);
COMMIT;

CREATE TABLE etlr_state_snapshot (
  run_id VARCHAR2(32) NOT NULL,
  variable_name VARCHAR2(30) NOT NULL,
  value CLOB NOT NULL CHECK (value IS JSON),
  updated_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  PRIMARY KEY(run_id, variable_name)
);
@@PKG_ETLR_DEMO.pks
SHOW ERRORS PACKAGE pkg_etlr_demo
@@PKG_ETLR_DEMO.pkb
SHOW ERRORS PACKAGE BODY pkg_etlr_demo
DECLARE
  l_errors NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_errors FROM user_errors WHERE name = 'PKG_ETLR_DEMO';
  IF l_errors > 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'PKG_ETLR_DEMO has compilation errors; see above.');
  END IF;
END;
/

PAUSE Review the results, then press Enter to close this window.
EXIT
