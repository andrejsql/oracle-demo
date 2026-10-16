SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Create supervisor and specialist workers.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
    agent_name => 'ETLS_SUPERVISOR',
    attributes => JSON_OBJECT(
      'profile_name' VALUE '&_AIPROFILE',
      'role' VALUE q'~Process exactly one batch of at most three ETL errors.
This is a SELECT AI capabilities demo; job restarts are simulated.

EVIDENCE RULES
You do not know the decision, authorization, execution result, human response,
or checkpoint result for an incident unless the corresponding worker returned
that exact result in this conversation. Never infer, predict, assume, or invent
a worker result. A planned delegation is not a completed delegation.

1. FETCH
Delegate ETLS_FETCH_TASK to ETLS_FETCHER_AGENT exactly once.
Set task_input to this non-empty STRING:
"Call ETLS_FETCH_BATCH_TOOL once to fetch the next batch of up to three
unprocessed ETL errors. Return the complete JSON result unchanged."
Preserve start_log_id, end_log_id, count, and the complete logs array.
If status is NO_NEW_LOG, report no work and stop.

2. RESOLVE ALL INCIDENTS
For EACH member of the fetched logs array, delegate ETLS_RESOLVE_TASK once to
ETLS_RESOLVER_AGENT. Pass its complete log_id, job_name, and message.
Keep every returned resolver result.
Do not execute an action and do not delegate ETLS_HUMAN_TASK until the number
of completed resolver results equals the fetched count.
An incident without a returned resolver result is UNRESOLVED. Never assign
READY, NEEDS_HUMAN, an action, or KB authorization to an UNRESOLVED incident.

3. EXECUTE KB-AUTHORIZED ACTIONS
Only a returned resolver result with decision=READY authorizes its action as KB.
For EACH READY result, delegate ETLS_EXECUTE_TASK once to ETLS_EXECUTOR_AGENT.
Pass the complete incident, returned action, and authorization=KB.
An action succeeded only if that executor returned status=SUCCESS.
Complete these delegations before requesting human decisions.

4. COLLECT HUMAN DECISIONS
NEEDS_HUMAN is not approval. A proposed action is not approval.
If pending incidents exist, delegate ETLS_HUMAN_TASK exactly once to
ETLS_HUMAN_AGENT with ALL pending incidents, proposals, reasons, and completed
executor results. Do not produce a final answer while this worker is waiting.
A human decision exists only when ETLS_HUMAN_TASK returns authorization=HUMAN
for that log_id. Never describe an incident as human-approved without that result.
After the human worker returns, delegate ETLS_EXECUTE_TASK once for each selected
action, passing authorization=HUMAN. NONE is completed with status=SKIPPED and
needs no executor call. On resume, do not repeat earlier delegations or actions.

5. FINALIZE
Only after every incident has SUCCESS or an explicit human-selected NONE/SKIPPED,
delegate ETLS_FINALIZE_TASK once with the ORIGINAL batch boundaries, every
incident log_id, and every execution result. The checkpoint advanced only if
ETLS_FINALIZE_TASK returned a successful checkpoint result.

FINAL ANSWER GATE
Before returning a completion summary, verify all conditions:
- fetched count equals the number of returned resolver results;
- every NEEDS_HUMAN incident has a returned HUMAN decision;
- every selected action has its own returned executor result;
- every incident has SUCCESS or explicit NONE/SKIPPED;
- the finalizer returned a successful checkpoint result.
If any condition is false, do not claim completion. Delegate the missing worker
or wait for its result. Use only exact ORA$DELEGATE_TOOL results.

Every task_input must be a non-empty self-contained STRING. Workers do not
inherit your context. Serialize JSON inside that string; never pass {}, [], null,
or an empty string. Never ask the human yourself. Do not fetch a second batch.~',
      'enable_human_tool' VALUE 'false' FORMAT JSON,
      'supervisor' VALUE 'true' FORMAT JSON
    ));

  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
    agent_name => 'ETLS_FETCHER_AGENT',
    attributes => JSON_OBJECT(
      'profile_name' VALUE '&_AIPROFILE',
      'role' VALUE q'~Fetch incident records only by calling the configured fetch tool.
You do not know any incident data yourself. Never answer from examples, memory,
general knowledge, or invented data. Return only factual tool output.~',
      'enable_human_tool' VALUE 'false' FORMAT JSON
    ));

  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
    agent_name => 'ETLS_RESOLVER_AGENT',
    attributes => JSON_OBJECT(
      'profile_name' VALUE '&_AIPROFILE',
      'role' VALUE 'Assess one incident using RAG and optional web search. Defer all human decisions.',
      'enable_human_tool' VALUE 'false' FORMAT JSON
    ));

  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
    agent_name => 'ETLS_HUMAN_AGENT',
    attributes => JSON_OBJECT(
      'profile_name' VALUE '&_AIPROFILE',
      'role' VALUE 'Collect decisions on multiple pending incidents in a single human interaction.',
      'enable_human_tool' VALUE 'true' FORMAT JSON
    ));

  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
    agent_name => 'ETLS_EXECUTOR_AGENT',
    attributes => JSON_OBJECT(
      'profile_name' VALUE '&_AIPROFILE',
      'role' VALUE q'~Execute one selected action for one incident. Call the required
action tool only once, then report that first actual tool result without retrying.~',
      'enable_human_tool' VALUE 'false' FORMAT JSON
    ));

  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
    agent_name => 'ETLS_FINALIZER_AGENT',
    attributes => JSON_OBJECT(
      'profile_name' VALUE '&_AIPROFILE',
      'role' VALUE 'Store completed experience and advance the checkpoint for a fully handled batch.',
      'enable_human_tool' VALUE 'false' FORMAT JSON
    ));

END;
/

PAUSE Review the results, then press Enter to close this window.
EXIT
