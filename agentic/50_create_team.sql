SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 50_create_team.sql
REM Author......: Andrej Pashchenko
REM Description.: Create agents used for SELECT AI Agent demo
REM Notes.......: -
REM Parameters..: -
REM Dependencies: uses define_alhdb.sql
REM Requirements: Oracle Database 26ai (Autonomous)
REM
REM ***************************************************************************

@define_alhdb.sql
CONNECT /@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 1000 LINESIZE 100

BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TEAM(
    team_name  => 'ETL_OPS_TEAM',
    attributes => '{
      "agents": [
        {"name":"ETL_TRIAGE_AGENT","task":"ETL_GET_CHECKPOINT_TASK"},
        {"name":"ETL_TRIAGE_AGENT","task":"ETL_READ_LOG_TASK"},
        {"name":"ETL_TRIAGE_AGENT","task":"ETL_RAG_TASK"},
        {"name":"ETL_TRIAGE_AGENT","task":"ETL_DECIDE_TASK"},
        {"name":"ETL_EXECUTOR_AGENT","task":"ETL_EXECUTE_TASK"}
      ],
      "process":"sequential"
    }'
  );
END;
/

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT