SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Worker roster, not a fixed workflow. Delegations still run one at a time.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TEAM(
    team_name => 'ETLS_OPS_TEAM',
    attributes => q'~{
  "process": "sequential",
  "supervisor_agent": "ETLS_SUPERVISOR",
  "agents": [
    {
      "name": "ETLS_FETCHER_AGENT",
      "task": "ETLS_FETCH_TASK"
    },
    {
      "name": "ETLS_RESOLVER_AGENT",
      "task": "ETLS_RESOLVE_TASK"
    },
    {
      "name": "ETLS_HUMAN_AGENT",
      "task": "ETLS_HUMAN_TASK"
    },
    {
      "name": "ETLS_EXECUTOR_AGENT",
      "task": "ETLS_EXECUTE_TASK"
    },
    {
      "name": "ETLS_FINALIZER_AGENT",
      "task": "ETLS_FINALIZE_TASK"
    }
  ]
}~');
END;
/

PAUSE Review the results, then press Enter to close this window.
EXIT
