SET ECHO OFF
REM Andrej SQL - SELECT AI run-state demo
REM Worker roster, not a fixed workflow. Delegations still run one at a time.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TEAM(
    team_name => 'ETLR_OPS_TEAM',
    attributes => q'~{
  "process": "sequential",
  "supervisor_agent": "ETLR_SUPERVISOR",
  "agents": [
    {
      "name": "ETLR_FETCHER_AGENT",
      "task": "ETLR_FETCH_TASK"
    },
    {
      "name": "ETLR_RESOLVER_AGENT",
      "task": "ETLR_RESOLVE_TASK"
    },
    {
      "name": "ETLR_HUMAN_AGENT",
      "task": "ETLR_HUMAN_TASK"
    },
    {
      "name": "ETLR_EXECUTOR_AGENT",
      "task": "ETLR_EXECUTE_TASK"
    },
    {
      "name": "ETLR_FINALIZER_AGENT",
      "task": "ETLR_FINALIZE_TASK"
    }
  ]
}~');
END;
/
PAUSE Review the team result, then press Enter to close this window.
EXIT
