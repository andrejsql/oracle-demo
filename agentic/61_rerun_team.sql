SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 60_run_team.sql
REM Author......: Andrej Pashchenko
REM Description.: Run team for SELECT AI Agent demo
REM Notes.......: -
REM Parameters..: -
REM Dependencies: uses define_alhdb.sql
REM Requirements: Oracle Database 26ai (Autonomous)
REM
REM ***************************************************************************

@define_alhdb.sql
CONNECT /@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 1000 LINESIZE 100

accept v_prompt PROMPT 'Your_prompt: '

declare 
v_ret varchar2(4000);
l_team_cov_id varchar2(4000);
begin
  SELECT  h.conversation_id
  INTO    l_team_cov_id 
  FROM    user_ai_agent_team_history h
  WHERE   team_name = 'ETL_OPS_TEAM'
  ORDER BY start_date DESC
  FETCH FIRST 1 ROW ONLY;

  v_ret := DBMS_CLOUD_AI_AGENT.RUN_TEAM(team_name   => 'ETL_OPS_TEAM'
    , user_prompt => '&v_prompt'
    , params      => '{"conversation_id": "' || l_team_cov_id || '"}'
      );
  dbms_output.put_line(l_team_cov_id||'###'||v_ret); 
end;
/

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT