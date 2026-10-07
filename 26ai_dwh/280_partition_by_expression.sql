SET ECHO OFF
REM File name...: 280_partition_by_expression.sql
REM Author......: Andrej Pashchenko
REM Description.: Expression partitioning versus virtual-column partitioning
REM Dependencies: define.sql; DBMS_XPLAN; PLAN_TABLE
REM Requirements: Oracle AI Database 26ai; Partitioning
@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON PAGESIZE 100 LINESIZE 180

COLUMN table_name FORMAT A12
COLUMN column_name FORMAT A34
COLUMN hidden_column FORMAT A14
COLUMN virtual_column FORMAT A15
COLUMN plan_table_output FORMAT A120

DROP TABLE IF EXISTS sales_vc PURGE;
DROP TABLE IF EXISTS sales_expr PURGE;
DELETE FROM plan_table
WHERE statement_id IN ('PBE_VC_26AI', 'PBE_EXPR_26AI');
COMMIT;

-------------------------------------------------------------------------------
-- Before 26ai: expose and name the virtual column explicitly.
-------------------------------------------------------------------------------
CREATE TABLE sales_vc (
  sale_id     NUMBER,
  sale_date   DATE NOT NULL,
  amount      NUMBER(10,2),
  sale_month  DATE GENERATED ALWAYS AS
                (TRUNC(sale_date, 'MM')) VIRTUAL
)
PARTITION BY RANGE (sale_month) (
  PARTITION p2025_01 VALUES LESS THAN (DATE '2025-02-01'),
  PARTITION p2025_02 VALUES LESS THAN (DATE '2025-03-01'),
  PARTITION pmax     VALUES LESS THAN (MAXVALUE)
);

PAUSE Press Enter for partitioning by expression

-------------------------------------------------------------------------------
-- 26ai: put the expression directly into the partitioning clause.
-------------------------------------------------------------------------------
CREATE TABLE sales_expr (
  sale_id     NUMBER,
  sale_date   DATE NOT NULL,
  amount      NUMBER(10,2)
)
PARTITION BY RANGE (TRUNC(sale_date, 'MM')) (
  PARTITION p2025_01 VALUES LESS THAN (DATE '2025-02-01'),
  PARTITION p2025_02 VALUES LESS THAN (DATE '2025-03-01'),
  PARTITION pmax     VALUES LESS THAN (MAXVALUE)
);

PAUSE Press Enter to inspect the virtual partition keys

-------------------------------------------------------------------------------
-- Both tables use a virtual partition key. In the new syntax Oracle creates
-- and manages it as a hidden column.
-------------------------------------------------------------------------------
SELECT table_name, column_name, hidden_column, virtual_column
FROM user_tab_cols
WHERE table_name IN ('SALES_VC', 'SALES_EXPR')
  AND virtual_column = 'YES'
ORDER BY table_name;

SELECT name AS table_name, column_name, column_position
FROM user_part_key_columns
WHERE name IN ('SALES_VC', 'SALES_EXPR')
ORDER BY name, column_position;

PAUSE Press Enter to load identical data

INSERT ALL
  INTO sales_vc (sale_id, sale_date, amount)
    VALUES (1, DATE '2025-01-05', 100)
  INTO sales_vc (sale_id, sale_date, amount)
    VALUES (2, DATE '2025-01-20', 200)
  INTO sales_vc (sale_id, sale_date, amount)
    VALUES (3, DATE '2025-02-10', 300)
  INTO sales_vc (sale_id, sale_date, amount)
    VALUES (4, DATE '2025-03-15', 400)
SELECT 1 FROM dual;

INSERT INTO sales_expr (sale_id, sale_date, amount)
SELECT sale_id, sale_date, amount
FROM sales_vc;

COMMIT;

SELECT 'VIRTUAL COLUMN' AS variant, COUNT(*) AS february_rows
FROM sales_vc PARTITION (p2025_02)
UNION ALL
SELECT 'EXPRESSION', COUNT(*)
FROM sales_expr PARTITION (p2025_02);

PAUSE Press Enter to compare partition pruning

EXPLAIN PLAN SET STATEMENT_ID = 'PBE_VC_26AI' FOR
SELECT SUM(amount)
FROM sales_vc
WHERE sale_month = DATE '2025-02-01';

SELECT plan_table_output
FROM TABLE(DBMS_XPLAN.DISPLAY(
  NULL, 'PBE_VC_26AI', 'BASIC +PARTITION +PREDICATE'));

PAUSE Press Enter for the expression variant

EXPLAIN PLAN SET STATEMENT_ID = 'PBE_EXPR_26AI' FOR
SELECT SUM(amount)
FROM sales_expr
WHERE TRUNC(sale_date, 'MM') = DATE '2025-02-01';

SELECT plan_table_output
FROM TABLE(DBMS_XPLAN.DISPLAY(
  NULL, 'PBE_EXPR_26AI', 'BASIC +PARTITION +PREDICATE'));

PAUSE Press Enter to finish and clean up

DROP TABLE sales_vc PURGE;
DROP TABLE sales_expr PURGE;
DELETE FROM plan_table
WHERE statement_id IN ('PBE_VC_26AI', 'PBE_EXPR_26AI');
COMMIT;

EXIT
