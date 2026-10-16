SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 40_create_agents.sql
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
  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
    agent_name => 'ETL_TRIAGE_AGENT',
    attributes => JSON_OBJECT('profile_name' VALUE '&_AIPROFILE','role' VALUE 'Triage one ETL log: read, RAG, decide, ask human if needed.')
  );
  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
    agent_name => 'ETL_EXECUTOR_AGENT',
    attributes => JSON_OBJECT('profile_name' VALUE '&_AIPROFILE','role' VALUE 'Execute the chosen action, store KB, and advance checkpoint.')
  );
END;
/


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT