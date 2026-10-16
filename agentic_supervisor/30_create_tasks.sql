SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Independent worker tasks; only the combined decision task enables HITL.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name => 'ETLS_FETCH_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE q'~Fetch the next batch of ETL incidents.

Delegated request:
{query}

You have no ETL incident data in the delegated request.
You MUST call ETLS_FETCH_BATCH_TOOL exactly once.
Do not generate, infer, reconstruct, summarize, or provide example incident data.

After ETLS_FETCH_BATCH_TOOL returns, return ONLY its complete JSON output unchanged.
Do not add, remove, rename, or modify any field or value.
Do not call another tool.

If you have not received an observation from ETLS_FETCH_BATCH_TOOL,
you MUST NOT produce a final answer.
Do not ask a human or change the checkpoint.~',
      'tools' VALUE JSON_ARRAY('ETLS_FETCH_BATCH_TOOL'),
      'enable_human_tool' VALUE 'false' FORMAT JSON
    ));

  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name => 'ETLS_RESOLVE_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE q'~Assess exactly one incident from the delegated request: {query}
The request contains log_id, job_name and message. Preserve those values.
Call ETLS_RAG_TOOL with the raw message as p_query.
If status is OK and a useful action is present, return decision=READY and the selected action.
If status is NO_HITS or ERROR, return decision=NEEDS_HUMAN.
For NEEDS_HUMAN, propose an action and explain it briefly. You may use
ETLS_WEBSEARCH_TOOL if it helps, but do not ask the human here.
Allowed actions: RESTART_ETL_JOB, NOTIFY_DB_OPS, NONE.
Return ONLY JSON:
{"log_id":number,"job_name":"...","message":"...","decision":"READY|NEEDS_HUMAN",
 "action":"RESTART_ETL_JOB|NOTIFY_DB_OPS|NONE","reason":"...","rag_status":"..."}
For NEEDS_HUMAN, action is a proposal, not authorization to execute.
Do not execute an action or advance the checkpoint.~',
      'tools' VALUE JSON_ARRAY('ETLS_RAG_TOOL', 'ETLS_WEBSEARCH_TOOL'),
      'enable_human_tool' VALUE 'false' FORMAT JSON
    ));

  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name => 'ETLS_HUMAN_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE q'~Collect decisions for all pending incidents in this delegated request: {query}
The request supplies the pending incident array plus results already completed automatically.
Call ORA$HUMAN_TOOL with ONE combined message containing:
- The automatically completed actions, clearly marked as already done.
- Each pending log_id, job_name, short incident description, proposed action and reason.
- One question: "Approve all proposed actions, or reply with an action for each log_id:
1=Restart ETL job, 2=Notify DB Ops, 3=Do nothing. Example: 101=2, 103=3."
Wait for the human response. "Approve all" approves the proposals you showed.
Map numbered replies to actions. If a reply omits an incident or is ambiguous,
ask one follow-up covering only the missing decisions. Do not invent an approval.
Return ONLY JSON {"decisions":[{"log_id":number,"job_name":"...","message":"...",
"action":"RESTART_ETL_JOB|NOTIFY_DB_OPS|NONE","authorization":"HUMAN"}]}.
Do not execute actions. Do not ask about incidents already completed automatically.~',
      'tools' VALUE JSON_ARRAY(),
      'enable_human_tool' VALUE 'true' FORMAT JSON
    ));

  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name => 'ETLS_EXECUTE_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE q'~Execute exactly one decided incident in this delegated request: {query}
It includes log_id, job_name, message, action and authorization (KB or HUMAN).
For RESTART_ETL_JOB call ETLS_RESTART_TOOL with this log_id exactly once.
After the first ETLS_RESTART_TOOL observation, do not call it again.
Use that observation to produce the final output immediately.
For NOTIFY_DB_OPS call ETLS_EMAIL_TOOL exactly once with:
{"tool_name":"ETLS_EMAIL_TOOL","email_subject":"ETL incident <log_id>: <job_name>",
 "email_body":"<incident message and selected escalation>"}
After the first ETLS_EMAIL_TOOL observation, do not call it again.
Use correctly escaped JSON strings.
For NONE call no tool and return status=SKIPPED.
Return ONLY JSON with log_id, job_name, message, action and status (SUCCESS, FAILED or SKIPPED).
Include simulated=true for a simulated restart. Report tool failures as FAILED.
Do not store KB experience, change the checkpoint or process another incident.~',
      'tools' VALUE JSON_ARRAY('ETLS_RESTART_TOOL', 'ETLS_EMAIL_TOOL'),
      'enable_human_tool' VALUE 'false' FORMAT JSON
    ));

  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name => 'ETLS_FINALIZE_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE q'~Finalize the complete batch in this delegated request: {query}
The request includes original batch start_log_id, end_log_id, all incident log_ids
and all execution results. Check that every incident has a result:
SUCCESS for an executed action, or SKIPPED for an explicitly selected NONE.
If anything is missing or FAILED, return {"status":"INCOMPLETE"} without updating the checkpoint.
For each SUCCESS result call ETLS_KB_STORE_TOOL once with log_id and action.
Do not store NONE as successful experience.
After storing eligible experience, call ETLS_CHECKPOINT_TOOL once using the ORIGINAL end_log_id.
If a tool fails, report the failure instead of claiming completion.
Return JSON summarizing the stored entries and checkpoint result.
Do not execute or repeat incident actions.~',
      'tools' VALUE JSON_ARRAY('ETLS_KB_STORE_TOOL', 'ETLS_CHECKPOINT_TOOL'),
      'enable_human_tool' VALUE 'false' FORMAT JSON
    ));

END;
/

PAUSE Review the results, then press Enter to close this window.
EXIT
