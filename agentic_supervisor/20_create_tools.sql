SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Register isolated tools; email settings match the original demo.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name => 'ETLS_FETCH_BATCH_TOOL',
    attributes => REPLACE(q'~{
  "instruction": "Fetch up to three next unprocessed log records. Returns JSON: status OK or NO_NEW_LOG, start_log_id, end_log_id, count and logs. Does not advance the checkpoint.",
  "function": "__OWNER__.PKG_ETLS_DEMO.FETCH_BATCH"
}~', '__OWNER__', USER));

  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name => 'ETLS_RAG_TOOL',
    attributes => REPLACE(q'~{
  "instruction": "Search the supervisor demo KB with the raw incident message. Returns JSON status OK, NO_HITS or ERROR and prior actions.",
  "function": "__OWNER__.PKG_ETLS_DEMO.SEARCH_KB",
  "tool_inputs": [
    {
      "name": "p_query",
      "description": "The incident MESSAGE exactly as recorded, including its ORA code."
    }
  ]
}~', '__OWNER__', USER));

  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name => 'ETLS_RESTART_TOOL',
    attributes => REPLACE(q'~{
  "instruction": "Simulate restarting the job for this log_id. Returns JSON with status, log_id, job_name and simulated=true.",
  "function": "__OWNER__.PKG_ETLS_DEMO.RESTART_JOB",
  "tool_inputs": [
    {
      "name": "p_log_id",
      "description": "The current incident log_id; the function retrieves the job name from its log."
    }
  ]
}~', '__OWNER__', USER));

  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name => 'ETLS_KB_STORE_TOOL',
    attributes => REPLACE(q'~{
  "instruction": "Store experience after a successful action. Reads and embeds the original log message. Notification experience means escalation, not proven resolution.",
  "function": "__OWNER__.PKG_ETLS_DEMO.STORE_EXPERIENCE",
  "tool_inputs": [
    {
      "name": "p_log_id",
      "description": "Incident whose selected action succeeded."
    },
    {
      "name": "p_action",
      "description": "RESTART_ETL_JOB or NOTIFY_DB_OPS."
    }
  ]
}~', '__OWNER__', USER));

  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name => 'ETLS_CHECKPOINT_TOOL',
    attributes => REPLACE(q'~{
  "instruction": "Advance the checkpoint only after every incident in the fetched batch has been handled, including explicit NONE decisions.",
  "function": "__OWNER__.PKG_ETLS_DEMO.FINISH_BATCH",
  "tool_inputs": [
    {
      "name": "p_end_log_id",
      "description": "end_log_id from the original fetched batch."
    }
  ]
}~', '__OWNER__', USER));

  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name => 'ETLS_WEBSEARCH_TOOL',
    attributes => q'~{
  "tool_type": "WEBSEARCH",
  "tool_params": {
    "credential_name": "OPENAI_CRED"
  }
}~');
  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name => 'ETLS_EMAIL_TOOL',
    attributes => q'~{
  "tool_type": "NOTIFICATION",
  "tool_params": {
    "notification_type": "EMAIL",
    "credential_name": "EMAIL_CRED",
    "recipient": "<...>",
    "sender": "<...>",
    "smtp_host": "<...>"
  }
}~');
END;
/

PAUSE Review the results, then press Enter to close this window.
EXIT
