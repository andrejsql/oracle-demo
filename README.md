# Oracle Database Demos

Practical SQL and PL/SQL examples exploring new Oracle Database
features for developers.

The demos focus on what changed, where a feature is useful, and how
it affects SQL code, application behavior, or performance.

The current examples cover Oracle 26ai, with an emphasis on data
warehousing and ETL/ELT. 

## Contents

The [26ai_dwh](26ai_dwh/) directory contains examples covering:

- SQL enhancements: QUALIFY, FILTER, GROUP BY, and table value constructors
- DML enhancements: non-positional INSERT, DML joins, and RETURNING
- Time calculations: time bucketing, date functions, and interval aggregation
- Schema features: assertions, domains, annotations, and schema privileges
- Data loading, partitioning, and direct path operations

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
