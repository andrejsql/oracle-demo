# SELECT AI Agent run-state demo

An isolated variant of `agentic_supervisor`: supervisor delegation still controls
the order, but PL/SQL tools exchange original records and results through
`DBMS_CLOUD_AI_AGENT.SET_VARIABLE` / `GET_VARIABLE`, not through LLM-generated
handoff payloads. All persistent objects use `ETLR_` or `PKG_ETLR_DEMO`.
Existing demos are not modified or called. Existing profiles and credentials are
referenced without changing their definitions.

## Setup and first run

Use **SELECT AI Agents -> 91 Run-state demo** in `00_Script.cmd`.
Run from the repository root. Connection and AI profile come from `define_alhdb.sql`.

1. Run **10 -> 11 -> 20 -> 30 -> 40 -> 50 -> 80**.
2. Run **15 -> 60**. Expected: incident 102 gets a simulated restart, then a single
   human question covers 101 and 103. While waiting, inspect **70 / 71 / 72**.
3. Run **61**, for example with `101=2, 103=3`.
   Expected: notification for 101, explicit SKIPPED for 103, checkpoint 103.
4. Run **60** again: NO_NEW_LOG. Optionally **16 -> 60** demonstrates KB reuse.
   NONE creates no KB experience and can require human input again.

Reset for replay with **13 -> 15 -> 60**. Reset abandons saved conversations;
never resume them afterwards. 11 is a one-time installation, not an upgrade script.
12 drops only this demo's framework definitions; tables/package/history remain.
Errors are displayed and scripts continue to their final pause; inspect output.

Prerequisites: Autonomous Database with supervisor and runtime-variable support,
the configured AI profile, `OCI_GENAI_CRED_VEC`, `EMAIL_CRED`, and optional
`OPENAI_CRED` for web search. The embedding endpoint/model matches the existing
demo. The package additionally needs direct access to
`DBMS_CLOUD_NOTIFICATION.SEND_MESSAGE` and the existing SMTP configuration.
No credentials, profiles, grants or ACLs are created here.

## What travels where

```text
Supervisor -- operation + ID --> Worker -- tool call --> PL/SQL
           <-- compact status --        <-- selected context/status
                                                        |
                                          GET_VARIABLE / SET_VARIABLE
                                                        |
                                       batch / resolutions / decisions / executions
```

| Component | LLM-visible data | Tool-side work |
|---|---|---|
| Fetcher | Status, count, incident IDs | Fetch originals; initialize four state objects |
| Resolver | One original ORA message, job name, matching KB evidence | Read incident; embed/search; validate and save resolution |
| Human worker | Pending descriptions/proposals/reasons; compact completed-action list | Read pending set; save complete human decision set |
| Executor | Incident ID; action/result status; simulation flag | Read authorization; construct/send email or simulate restart |
| Finalizer | Completion status/counts/checkpoint | Validate batch; store experience; advance original checkpoint |
| Supervisor | IDs and compact worker results | Delegate; no original-message or RAG handoff |

Original messages are deliberately visible to the resolver for reasoning.
The human overview contains up to 500 characters of each pending message and a
reason capped at 1000 characters. No KB hits or full batch are handed to the human
worker. Optional web search receives only context chosen by the resolver.

An email body is assembled from the stored original incident in PL/SQL and sent
directly with `DBMS_CLOUD_NOTIFICATION.SEND_MESSAGE`. It is never an executor tool
argument or return value. **Email is real**, using the same recipient/sender/SMTP
host as the previous demo. SUCCESS means the send procedure returned normally,
not a delivery receipt. Restarts remain simulated.

## Runtime configuration and state

`60_run_team.sql` supplies these values through `RUN_TEAM.params`:

```json
{
  "conversation_id": "<new conversation>",
  "attribute_variables": {"llm_profile": "<configured profile>"},
  "instruction_variables": {"batch_limit": "3"}
}
```

`{llm_profile}` is used in agent `profile_name` attributes; `{batch_limit}` appears
in the fetch instruction and is read by the fetch tool. Batch size is validated
as 1..3. Changing configuration does not change stored definitions.
61 supplies the same configuration while resuming the saved conversation; it
does not inject a fresh batch or overwrite any of the four state objects.

| `state_variables` key | Contents |
|---|---|
| `batch` | Unique run ID, original boundaries, original incident array, compact manifest, eventual final result |
| `resolutions` | Map keyed by log_id: retrieved evidence, READY/NEEDS_HUMAN, action/proposal, reason |
| `decisions` | Map keyed by log_id: selected action and KB/HUMAN authorization |
| `executions` | Map keyed by log_id: actual STARTED/SUCCESS/FAILED/SKIPPED result |

State objects are serialized JSON CLOBs. Tools read state explicitly; original
records are not expanded into instruction placeholders. `variables`, the
deprecated alias for `instruction_variables`, is not used.

Oracle documents `ephemeral` as the supported scope, tool-to-tool handoff in the
same run, and save/restore of values written by SET_VARIABLE across HITL.
This is not durable application recovery after arbitrary errors or a new run.
`SET_TEAM` could provide session defaults; this variant uses `RUN_TEAM` parameters
because each launcher opens another database session.

`ETLR_STATE_SNAPSHOT` mirrors the four objects for presenter inspection with 72
from another session. It is **never read by execution tools** and is not a recovery
store. Its JSON includes originals and KB evidence; these are database inspection
results, not data returned to the supervisor LLM. Framework history in 70 lets
you compare small delegations/worker results with the richer resolver observations.

## Tool checks and deliberate limits

- Incident IDs must belong to the fetched batch. READY requires an action present
  in the actual KB hits for that incident; a proposal alone cannot execute.
- Stored resolutions/decisions cannot be replaced with different choices.
  Human choices must cover the complete pending set; duplicates, missing choices
  and unrelated IDs are rejected before publishing changes.
- Execution takes only log_id; it obtains action/authorization from state. It
  records STARTED before the action and returns existing results on repeated calls
  within the run. FAILED/STARTED are not retried automatically.
- NONE is executed through the same tool to record SKIPPED. Finalization checks
  every resolution, authorization, matching action and execution status in PL/SQL.
  Missing/failed work returns INCOMPLETE without KB or checkpoint writes.
- Successful notification experience describes escalation, not proven resolution.
  KB writes are committed individually; a later failure can leave partial learning
  with the checkpoint unchanged. Source IDs prevent duplicate learning on a repeat
  finalization. The checkpoint update checks the original start boundary.

The supervisor remains LLM-directed, not a deterministic workflow engine. Its
instructions and compact return contracts still need runtime verification.
State namespaces are not per-agent access controls: tool availability and tool
outputs implement the data separation in this demo. Human approval is interpreted
by the human worker; its save tool validates decisions but does not independently
attest that ORA$HUMAN_TOOL supplied them. No production authorization boundary or
exactly-once guarantee for external email is claimed.

Use one active presenter/run. After an incomplete/failed run inspect state/history;
do not treat a new conversation as recovery. A fresh run can repeat actions for
incidents whose checkpoint has not advanced.

## Scripts

| Script | Purpose |
|---|---|
| 10 / 11 / 12 / 13 / 14 | Profiles / installation / framework cleanup / data reset / metadata |
| 15 / 16 | First mixed batch / repeat batch |
| 20 / 30 / 40 / 50 | Tools / tasks / agents / teams |
| 60 / 61 | Start batch / resume actual human interaction |
| 70 / 71 / 72 | Framework timeline / persistent demo results / run-state snapshots |
| 80 | Read-only setup and API checks |

## Oracle documentation

- [Runtime Configuration for Agent Teams](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/runtime-configuration-teams.html)
- [DBMS_CLOUD_AI_AGENT: GET_VARIABLE, SET_VARIABLE, RUN_TEAM, SET_TEAM](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/dbms-cloud-ai-agent-package.html)
- [Supervisor Agent Pattern](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/supervisor-agent.html)
- [DBMS_CLOUD_NOTIFICATION: SEND_MESSAGE](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-dbms-cloud-notification.html)

Batching, payload selection, KB filtering, approval interpretation, action checks,
snapshots and checkpoint policy are custom demo PL/SQL/prompts. Oracle supplies
runtime namespaces, tools, supervisor delegation and HITL pause/resume.
