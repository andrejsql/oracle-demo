SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Create isolated tables and package (run once).
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

CREATE TABLE etls_job_log (
  log_id NUMBER PRIMARY KEY,
  job_name VARCHAR2(128) NOT NULL,
  message VARCHAR2(4000) NOT NULL,
  log_timestamp TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE TABLE etls_checkpoint (
  singleton NUMBER PRIMARY KEY CHECK (singleton = 1),
  last_log_id NUMBER DEFAULT 0 NOT NULL
);
INSERT INTO etls_checkpoint VALUES (1, 0);
CREATE TABLE etls_kb (
  entry_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_log_id NUMBER,
  error_text VARCHAR2(4000) NOT NULL,
  action VARCHAR2(30) NOT NULL,
  embedding VECTOR,
  created_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE TABLE etls_action_log (
  action_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  log_id NUMBER NOT NULL,
  action VARCHAR2(30) NOT NULL,
  result CLOB,
  created_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE TABLE etls_run (
  singleton NUMBER PRIMARY KEY CHECK (singleton = 1),
  conversation_id VARCHAR2(128) NOT NULL,
  started_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);
COMMIT;

@@PKG_ETLS_DEMO.pks
SHOW ERRORS PACKAGE pkg_etls_demo
@@PKG_ETLS_DEMO.pkb
SHOW ERRORS PACKAGE BODY pkg_etls_demo
DECLARE
  l_errors NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_errors FROM user_errors WHERE name = 'PKG_ETLS_DEMO';
  IF l_errors > 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'PKG_ETLS_DEMO has compilation errors; see above.');
  END IF;
END;
/

PAUSE Review the results, then press Enter to close this window.
EXIT
