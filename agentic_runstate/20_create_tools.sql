SET ECHO OFF
REM Andrej SQL - SELECT AI run-state demo
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

DECLARE
  PROCEDURE tool(p_name VARCHAR2, p_function VARCHAR2, p_instruction VARCHAR2,
                 p_inputs CLOB DEFAULT NULL) IS
    l_attributes CLOB;
  BEGIN
    SELECT JSON_OBJECT('instruction' VALUE p_instruction,
      'function' VALUE USER || '.PKG_ETLR_DEMO.' || p_function,
      'tool_inputs' VALUE NVL(p_inputs, TO_CLOB('[]')) FORMAT JSON RETURNING CLOB)
      INTO l_attributes FROM dual;
    DBMS_CLOUD_AI_AGENT.CREATE_TOOL(tool_name => p_name, attributes => l_attributes);
  END;
BEGIN
  tool('ETLR_FETCH_BATCH_TOOL', 'FETCH_BATCH',
    'Fetch one batch into state_variables. Return only status, count and log_ids.');
  tool('ETLR_RESOLVE_CONTEXT_TOOL', 'RESOLVE_CONTEXT',
    'Read exactly one incident from state and search its original message in the KB. Return this incident and its RAG evidence only.',
    '[{"name":"p_log_id","description":"Incident ID from the delegation."}]');
  tool('ETLR_SAVE_RESOLUTION_TOOL', 'SAVE_RESOLUTION',
    'Store one reasoned resolution. READY requires an action present in retrieved KB; NEEDS_HUMAN is only a proposal. Return compact routing result.',
    '[{"name":"p_log_id","description":"Incident ID."},
      {"name":"p_decision","description":"READY or NEEDS_HUMAN."},
      {"name":"p_action","description":"RESTART_ETL_JOB, NOTIFY_DB_OPS or NONE."},
      {"name":"p_reason","description":"Short reason based on observed context, at most 1000 characters."}]');
  tool('ETLR_HUMAN_CONTEXT_TOOL', 'HUMAN_CONTEXT',
    'Read a compact overview of pending proposals and automatically completed actions. No full batch or RAG payload is returned.');
  tool('ETLR_SAVE_HUMAN_TOOL', 'SAVE_HUMAN_DECISIONS',
    'Store only decisions explicitly received from the human tool. Never call before actual human input. Return only authorized_log_ids.',
    '[{"name":"p_decisions","description":"JSON array as a STRING: [{\"log_id\":101,\"action\":\"NOTIFY_DB_OPS\"}]. No messages or job names."}]');
  tool('ETLR_EXECUTE_TOOL', 'EXECUTE_DECISION',
    'Read and execute the stored authorized decision for one incident. Builds mail in PL/SQL; restarts are simulated. Existing results are not executed again.',
    '[{"name":"p_log_id","description":"Incident ID. No action or authorization is accepted from the LLM."}]');
  tool('ETLR_FINALIZE_TOOL', 'FINALIZE_BATCH',
    'Validate all resolutions, authorizations and executions in state; store eligible experience and advance the original checkpoint. No payload arguments.');
  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(tool_name => 'ETLR_WEBSEARCH_TOOL',
    attributes => '{"tool_type":"WEBSEARCH","tool_params":{"credential_name":"OPENAI_CRED"}}');
END;
/
PAUSE Review the results, then press Enter to close this window.
EXIT
