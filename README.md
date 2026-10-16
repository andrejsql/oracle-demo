# Oracle Database Demos

Practical SQL and PL/SQL examples exploring new Oracle Database
features for developers.

The demos focus on what changed, where a feature is useful, and how
it affects SQL code, application behavior, or performance.

The current examples cover Oracle AI Database 26ai, with an emphasis on data
warehousing, ETL/ELT, and SELECT AI Agents.

## Contents

The [26ai_dwh](26ai_dwh/) directory contains examples covering:

- SQL enhancements: QUALIFY, FILTER, GROUP BY, and table value constructors
- DML enhancements: non-positional INSERT, DML joins, and RETURNING
- Time calculations: time bucketing, date functions, and interval aggregation
- Schema features: assertions, domains, annotations, and schema privileges
- Data loading, partitioning, and direct path operations

The repository also contains three variants of an ETL operations demo for
SELECT AI Agents:

- [agentic](agentic/) implements the original sequential team. It processes
  one ETL error per run and demonstrates tools, RAG, human interaction,
  knowledge-base updates, and checkpointing.
- [agentic_supervisor](agentic_supervisor/) uses the supervisor pattern. The
  supervisor delegates incident processing to specialized agents, executes
  actions that are already authorized by knowledge-base evidence, and combines
  pending incidents into one human interaction.
- [agentic_runstate](agentic_runstate/) extends the supervisor variant with
  `DBMS_CLOUD_AI_AGENT.SET_VARIABLE` and `GET_VARIABLE`. Tools exchange original
  records and intermediate results through run state, while agents receive
  compact delegation payloads.

These are capability demonstrations, not production workflow or authorization
implementations. See the README files in the supervisor and run-state directories
for their setup, behavior, and deliberate limitations.

## Configuration

The repository includes `define_alhdb.sql`, which supplies the SQLcl
substitution variables used by the Agentic demos:

- `_sid_or_service` is the name of a saved SQLcl connection. Authentication for
  that connection is handled by the SQLcl Secure Password Store; the Agentic
  scripts do not contain its database password.
- `_AIPROFILE` identifies the SELECT AI profile configured in the target
  database.

OCI Generative AI, web-search, and email credential names referenced by the
scripts must already exist in the target database. Their creation and secret
configuration are outside the scope of these demos.

## License

Copyright (c) 2026 Andrej Pashchenko

This repository is licensed under the [Apache License, Version 2.0](LICENSE).

## Disclaimer

The scripts are provided for demonstration and educational purposes.
Unless required by applicable law or agreed to in writing, they are
provided without warranties or conditions of any kind, either express
or implied, as set out in the license.

Scripts may create or drop database objects, modify data, and commit
transactions. Review them before execution and use a dedicated test
environment. No support or maintenance commitment is provided.
