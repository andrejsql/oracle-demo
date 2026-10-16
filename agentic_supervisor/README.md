# SELECT AI supervisor demo

A separate version of the sequential `agentic` demo. The focus is supervisor
delegation, RAG, tool use and a combined human-in-the-loop interaction.

## Setup

Use **SELECT AI Agent -> 90 Supervisor demo** in `00_Script.cmd`.
Scripts use the existing `define_alhdb.sql` connection and AI profile.
Run from the repository root, as with the original launcher.

Run **10 -> 11 -> 20 -> 30 -> 40 -> 50 -> 15 -> 80**.
- 11 creates the isolated tables and package once. Existing tables produce errors;
  use 13 to reset data instead of rerunning 11.
- 20 registers tools, including the real email tool with the same recipient and
  SMTP settings as the original demo.
- 15 seeds three incidents and one prior experience; it requests an OCI embedding.
- 80 checks objects and the fetch result without calling an LLM or sending email.

All launcher scripts pause before EXIT. SQL errors are displayed and execution
continues to the final pause, so inspect the output before moving to the next step.

Prerequisites are the configured AI profile, `DBMS_CLOUD_AI_AGENT` with supervisor
support, vector/embedding support, and the existing credentials
`OCI_GENAI_CRED_VEC`, `OPENAI_CRED` (optional web-search use), and `EMAIL_CRED`.
The embedding endpoint/model in `PKG_ETLS_DEMO.pkb` matches the original demo.
No profiles, credentials, network ACLs or privileges are created here.

All new persistent objects use `ETLS_` or `PKG_ETLS_DEMO`. No original tables,
package, tools, tasks, agents or team are used or modified. The AI profile and
credentials are reused, read-only. The package is created in the connected schema.

## Demonstration

1. **60** starts a new conversation and fetches up to three errors.
2. The Resolver assesses each error without asking the human.
3. Incident **102** has seeded KB experience and should be restarted automatically
   (simulated). Incidents **101** and **103** should need human decisions.
4. One Human Decision worker asks about **101 and 103 together**.
5. While paused, **71** should show a restart for 102 and checkpoint **0**.
   **70** shows a combined timeline for the latest supervisor conversation:
   TASK rows contain task input/result, TOOL rows contain every recorded tool call,
   and TURN rows show supervisor and worker prompts/responses. Text is previewed
   to 1000 characters; execution, task and conversation IDs support full inspection.
   Turns are not assigned to tool calls by timestamp proximity. The timeline uses
   task/tool completion time (start time when unfinished) and prompt creation time.
6. **61** resumes the saved conversation. Reply `101=2, 103=3`, for example,
   or `Approve all` to accept the displayed proposals.
7. Only the pending actions should run. The Finalizer stores eligible experience,
   then advances the checkpoint to **103**.
8. **60** again demonstrates the no-work branch.
9. Optionally **16 -> 60** adds three similar errors for KB reuse.
   Incidents previously assigned NONE have no learned action and can need HITL again.

To replay the first scenario, use **13 -> 15 -> 60**.
Reset abandons the saved conversation; do not resume an old conversation afterward.
Use a single active presenter/run. This is not a concurrent processing design.

## What the audience should see

```text
Supervisor -> Fetch batch -> Resolve each incident
                         -> Execute READY incidents
                         -> Ask once about all NEEDS_HUMAN incidents
                         -> Execute human-selected actions
                         -> Store experience and advance batch checkpoint
```

The roster deliberately lists the Human worker before the Executor. The supervisor
instructions require known actions to run before the human question: roster order
does not define execution order.

Only `ETLS_HUMAN_TASK` enables the human tool. Assessment returns NEEDS_HUMAN instead
of pausing. The checkpoint remains unchanged until the whole batch is handled.
The saved conversation supplies continuity across separate launcher windows;
it is not another checkpoint. Pending decisions remain in conversation context.

## Deliberate demo simplifications

- Restarts are simulated and recorded in `ETLS_ACTION_LOG`; email notifications are real.
- A successful notification is experience about escalation, not proof of resolution.
- Batching, deferred decisions and checkpoint policy are our prompts and PL/SQL.
  Oracle supplies supervisor delegation, worker contexts, tools and HITL pause/resume.
- Agent instructions guide the intended route; they are not a deterministic workflow
  engine or an exactly-once execution guarantee. No production recovery design is added.
- RAG uses cosine distance with a 0.25 threshold and an ORA-code filter.
  Identical seeded text makes the intended first known incident easy to retrieve.
- A failed/incomplete batch leaves its checkpoint unchanged. Inspect/reset for the
  demo instead of treating a fresh run as automatic recovery.
- Cleanup 12 removes only this demo's framework definitions; data/package remain.
  Reset 13 clears only this demo's data. Framework history is retained.

## Scripts

| Script | Purpose |
|---|---|
| 10 | Profile and credential names |
| 11 | Tables and package installation |
| 12 | Supervisor framework cleanup |
| 13 | Supervisor data reset |
| 14 | Team metadata |
| 15 / 16 | Mixed first batch / repeat batch |
| 20 / 30 / 40 / 50 | Tools / tasks / agents / team |
| 60 / 61 | Start batch / answer combined human question |
| 70 / 71 | Framework history / demo state |
| 80 | Read-only setup checks |

## Oracle documentation

- [Supervisor Agent Pattern](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/supervisor-agent.html)
- [Package API, including RUN_TEAM and GET_TEAM_STATE](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/dbms-cloud-ai-agent-package.html)
- [Supervisor example](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/examples-using-select-ai-agent.html)

The supervisor has `supervisor=true`; the team names it in `supervisor_agent`.
`process=sequential` still means one worker at a time. Workers receive self-contained
delegations; they do not inherit the supervisor's full conversation.
