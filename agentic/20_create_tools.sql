SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 20_create_tools.sql
REM Author......: Andrej Pashchenko
REM Description.: Create tools used for SELECT AI Agent demo
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

  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name  => 'ETL_GET_LAST_LOG_ID_TOOL',
    attributes => JSON_OBJECT('instruction' VALUE 
q'[Return the log_id of the last ETL log record that was already processed. 
   This value acts as a processing marker to ensure each run handles the next log record only. 
   Return the value as-is without interpretation.]'
    , 'function' VALUE 'ETL_OPS.PKG_ETL_OPS_AGENT.GET_LAST_PROCESSED_LOG_ID')  
  );


  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name  => 'ETL_SET_LAST_LOG_ID_TOOL',
    attributes => JSON_OBJECT('instruction' VALUE 
 q'[Persist the log_id of the ETL log record that has just been processed. 
    This updates the processing marker so the next run continues with the following log record. 
    Call this only after the current record has been fully handled.]'
    , 'function' VALUE 'ETL_OPS.PKG_ETL_OPS_AGENT.SET_LAST_PROCESSED_LOG_ID'
    , 'tool_inputs' VALUE JSON_ARRAY(JSON_OBJECT('name' VALUE 'p_log_id', 'description' VALUE 'log_id of the ETL log record that has just been processed'))
     )    
  );


  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name  => 'ETL_LOG_READER_TOOL',
    attributes => JSON_OBJECT('instruction' VALUE 
q'[Fetch exactly ONE next ETL log record after the provided start log id. 
   Return a single JSON object (not an array) representing that log record. 
   If no newer record exists, return a JSON object with status = \"NO_NEW_LOG\" and include the start_log_id you received. 
   Do not interpret or summarize; return factual data only.]'
   , 'function' VALUE 'ETL_OPS.PKG_ETL_OPS_AGENT.RETRIEVE_NEXT_LOG_RECORD'
   , 'tool_inputs' VALUE JSON_ARRAY(JSON_OBJECT('name' VALUE 'p_log_id', 'description' VALUE 'Last processed log id (exclusive). Return the next record with log_id > p_start_log_id.'))
    )
  );
  
  

  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name  => 'ETL_RESTART_JOB_TOOL',
    attributes => JSON_OBJECT('instruction' VALUE 
q'[Restart exactly one ETL job by name. Use only when the task explicitly authorizes execution]'
    , 'function' VALUE 'ETL_OPS.PKG_ETL_OPS_AGENT.RESTART_ETL_JOB'
    , 'tool_inputs' VALUE JSON_ARRAY(JSON_OBJECT('name' VALUE 'p_job_name', 'description' VALUE 'Exact ETL job name to restart'))
    )
  );


  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name  => 'ETL_DIY_RAG_TOOL',
    attributes => JSON_OBJECT('instruction' VALUE 
q'[Search the KB vector store for relevant prior resolutions. 
   Always return JSON with status (OK|NO_HITS|ERROR), hits_count, and context_text. If no hits, return NO_HITS and empty context_text]'
   , 'function' VALUE 'ETL_OPS.PKG_ETL_OPS_AGENT.ETL_DIY_RAG_SEARCH'
    , 'tool_inputs' VALUE JSON_ARRAY(JSON_OBJECT('name' VALUE 'p_query', 'description' VALUE 'Short retrieval query (do NOT pass full logs)')
                        , JSON_OBJECT('name' VALUE 'p_top_k', 'description' VALUE 'Number of hits to retrieve'))
    )
  );

  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name  => 'ETL_KB_STORE_TOOL',
    attributes => JSON_OBJECT('instruction' VALUE 
q'[
Store a KB entry only if execution.status == "SUCCESS".

Create values:

- p_error_signature:
  short stable signature from the processed log record (prefer ORA-xxxxx plus short message).

- p_error_text (critical):
  use the raw error message/details from the ETL log record exactly as recorded.
  Prefer fields like message, error_message, details, ora_message, stack, or similar.
  Do not rewrite, do not summarize, do not mention the action. If the raw message is multi-line, keep it as-is.

- p_action_type:
  RESTART_ETL_JOB or NOTIFY_DB_OPS

- p_action_params_json:
  for restart: {"job_name":"<job_name>"} (only if job name exists)

- p_outcome:
  SUCCESS

- p_action_text:
  short action summary (not embedded), e.g. "Restarted <job_name> successfully".

- p_kb_payload_json:
  include useful metadata (at least log_id and job_name if available) as JSON.

Call ETL_KB_STORE_TOOL with these values.

If status is not SUCCESS: do nothing and return {"kb_update":"SKIPPED"}.
Return ONLY JSON.
]'
    , 'function' VALUE 'ETL_OPS.PKG_ETL_OPS_AGENT.ETL_KB_STORE'
   , 'tool_inputs' VALUE JSON_ARRAY(
    JSON_OBJECT(
      'name' VALUE 'p_error_signature',
      'description' VALUE 'Short stable identifier of the incident, typically an ORA code with brief context. Used for filtering and audit (not embedded).'
    )
  , JSON_OBJECT(
      'name' VALUE 'p_error_text',
      'description' VALUE 'Raw error message / error details taken directly from the ETL log record (for example the log message column or ORA message text). This field is embedded and used for semantic KB search. Do not summarize and do not describe the action.'
    )
  , JSON_OBJECT(
      'name' VALUE 'p_action_type',
      'description' VALUE 'Remediation action that resolved the incident, for example RESTART_ETL_JOB or NOTIFY_DB_OPS (not embedded).'
    )
  , JSON_OBJECT(
      'name' VALUE 'p_action_params_json',
      'description' VALUE 'JSON with action parameters, for example {"job_name":"LOAD_ORDERS"} (not embedded).'
    )
  , JSON_OBJECT(
      'name' VALUE 'p_outcome',
      'description' VALUE 'Outcome of the action, typically SUCCESS or FAILED.'
    )
  , JSON_OBJECT(
      'name' VALUE 'p_action_text',
      'description' VALUE 'Short human-readable action summary, for example "Restarted LOAD_ORDERS successfully" (not embedded).'
    )
  , JSON_OBJECT(
      'name' VALUE 'p_kb_payload_json',
      'description' VALUE 'Optional JSON payload for audit/metadata. May include log_id, job_name, timestamps, tool outputs, etc.'
    )
)
    )
  );

  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name  => 'ETL_NOTIFY_PER_MAIL',
    attributes => JSON_OBJECT('tool_type' VALUE 'NOTIFICATION',    
          'tool_params' VALUE JSON_OBJECT(    
              'notification_type' VALUE 'EMAIL',     
              'credential_name' VALUE 'EMAIL_CRED',      
              'recipient' VALUE '<...>',
              'sender'  VALUE '<...>' ,  
              'smtp_host' VALUE '<...>'
                          )
              )
  );
  
  DBMS_CLOUD_AI_AGENT.CREATE_TOOL(
    tool_name  => 'WEBSEARCH_TOOL',
    attributes => '{"instruction":"Search the web when needed.","tool_type":"WEBSEARCH","tool_params":{"credential_name":"OPENAI_CRED"}}'
  );

  
END;
/

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT