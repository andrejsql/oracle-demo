SET ECHO OFF
REM Andrej SQL - SELECT AI run-state demo
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

DECLARE
  PROCEDURE worker(p_name VARCHAR2, p_role VARCHAR2, p_human BOOLEAN DEFAULT FALSE) IS
    l_attrs CLOB;
    l_human VARCHAR2(5);
  BEGIN
    IF p_human THEN l_human := 'true'; ELSE l_human := 'false'; END IF;
    SELECT JSON_OBJECT('profile_name' VALUE '{llm_profile}', 'role' VALUE p_role,
      'enable_human_tool' VALUE l_human FORMAT JSON RETURNING CLOB) INTO l_attrs FROM dual;
    DBMS_CLOUD_AI_AGENT.CREATE_AGENT(agent_name => p_name, attributes => l_attrs);
  END;
BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(agent_name => 'ETLR_SUPERVISOR',
    attributes => JSON_OBJECT('profile_name' VALUE '{llm_profile}',
      'supervisor' VALUE 'true' FORMAT JSON, 'enable_human_tool' VALUE 'false' FORMAT JSON,
      'role' VALUE q'~Process exactly one ETL batch using compact worker results.
Original incidents, RAG evidence, decisions and executions are kept in tool state.
Delegate only operation and log_id. Never ask workers to return full records,
messages, RAG hits, reasons or execution payloads. All task_input values must be
non-empty self-contained STRINGS. Workers get their data through configured tools.

1. Delegate ETLR_FETCH_TASK to ETLR_FETCHER_AGENT once with task_input="Fetch one batch."
   Preserve the returned count and log_ids. NO_NEW_LOG means stop with no work.
2. For EVERY returned log_id delegate ETLR_RESOLVE_TASK to ETLR_RESOLVER_AGENT
   with task_input="Assess incident <log_id>." Wait for all resolver results.
   Only actual returned results count; never invent a decision or action.
3. For every READY result delegate ETLR_EXECUTE_TASK to ETLR_EXECUTOR_AGENT
   with task_input="Execute stored decision for incident <log_id>."
   Finish these actions before the human interaction. A FAILED or STARTED result
   means stop with an incomplete report; do not retry actions.
4. If any result is NEEDS_HUMAN, delegate ETLR_HUMAN_TASK to ETLR_HUMAN_AGENT
   once with task_input="Collect all pending decisions from run state."
   Wait for the actual worker result, including through human pause/resume.
   Never infer approval. After its STORED result delegate ETLR_EXECUTE_TASK once
   for every returned authorized_log_id, including NONE decisions.
   On resume do not repeat completed delegations or actions.
5. Only after every incident has an actual SUCCESS or SKIPPED executor result,
   delegate ETLR_FINALIZE_TASK to ETLR_FINALIZER_AGENT with
   task_input="Validate and finalize the batch held in run state."
   Claim completion only if the finalizer returned status SUCCESS.
   INCOMPLETE or an error is not completion. Do not fetch a second batch.

Do not ask the human yourself. Never substitute conversation claims for tool state.
This is a capabilities demo: restarts are simulated and mail is real.~'));
  worker('ETLR_FETCHER_AGENT', 'Fetch with the configured tool; return only its actual compact manifest.');
  worker('ETLR_RESOLVER_AGENT', 'Reason about one actual incident and KB evidence; save the resolution using the configured tool.');
  worker('ETLR_HUMAN_AGENT', 'Collect actual human decisions for pending incidents and save them. Never assume approval.', TRUE);
  worker('ETLR_EXECUTOR_AGENT', 'Execute a stored decision by ID through the tool once; return its compact observation.');
  worker('ETLR_FINALIZER_AGENT', 'Finalize from tool state; never reconstruct or claim missing evidence.');
END;
/
PAUSE Review the results, then press Enter to close this window.
EXIT
