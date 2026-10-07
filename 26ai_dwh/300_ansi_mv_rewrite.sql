SET ECHO OFF
REM File name...: 300_ansi_mv_rewrite.sql
REM Author......: Andrej Pashchenko
REM Description.: Query rewrite across ANSI and Oracle join syntax
REM Dependencies: define.sql; DBMS_XPLAN; PLAN_TABLE
REM Requirements: Oracle AI Database 26ai; CREATE MATERIALIZED VIEW
@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON PAGESIZE 100 LINESIZE 180
COLUMN plan_table_output FORMAT A120

DROP MATERIALIZED VIEW IF EXISTS product_sales_mv;
DROP TABLE IF EXISTS mv_sales PURGE;
DROP TABLE IF EXISTS mv_products PURGE;
DELETE FROM plan_table
WHERE statement_id IN ('MV_ANSI_QUERY', 'MV_ORACLE_QUERY');
COMMIT;

CREATE TABLE mv_products (
  prod_id    NUMBER PRIMARY KEY,
  prod_name  VARCHAR2(30) NOT NULL
);

CREATE TABLE mv_sales (
  sale_id      NUMBER PRIMARY KEY,
  prod_id      NUMBER NOT NULL REFERENCES mv_products(prod_id),
  amount_sold  NUMBER NOT NULL
);

INSERT INTO mv_products
SELECT LEVEL, 'Product ' || LEVEL
FROM dual
CONNECT BY LEVEL <= 100;

INSERT INTO mv_sales
SELECT LEVEL, MOD(LEVEL, 100) + 1, MOD(LEVEL, 500) + 1
FROM dual
CONNECT BY LEVEL <= 100000;

COMMIT;

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'MV_PRODUCTS');
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'MV_SALES');
END;
/

PAUSE Press Enter to create the materialized view with an ANSI join

CREATE MATERIALIZED VIEW product_sales_mv
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
  ENABLE QUERY REWRITE
AS
SELECT p.prod_name,
       SUM(s.amount_sold)   AS amount_sold,
       COUNT(s.amount_sold) AS amount_count,
       COUNT(*)             AS row_count
FROM mv_sales s
JOIN mv_products p
  ON p.prod_id = s.prod_id
GROUP BY p.prod_name;

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'PRODUCT_SALES_MV');
END;
/

ALTER SESSION SET query_rewrite_enabled = TRUE;

PAUSE Press Enter for an ANSI query against the base tables

-- REWRITE makes the eligibility test deterministic rather than cost-based.
EXPLAIN PLAN SET STATEMENT_ID = 'MV_ANSI_QUERY' FOR
SELECT /*+ REWRITE */
       p.prod_name,
       SUM(s.amount_sold) AS amount_sold
FROM mv_sales s
JOIN mv_products p
  ON p.prod_id = s.prod_id
GROUP BY p.prod_name;

SELECT plan_table_output
FROM TABLE(DBMS_XPLAN.DISPLAY(
  NULL, 'MV_ANSI_QUERY', 'BASIC +ALIAS +NOTE'));

PAUSE Press Enter for the same query using Oracle join syntax

EXPLAIN PLAN SET STATEMENT_ID = 'MV_ORACLE_QUERY' FOR
SELECT /*+ REWRITE */
       p.prod_name,
       SUM(s.amount_sold) AS amount_sold
FROM mv_sales s,
     mv_products p
WHERE p.prod_id = s.prod_id
GROUP BY p.prod_name;

SELECT plan_table_output
FROM TABLE(DBMS_XPLAN.DISPLAY(
  NULL, 'MV_ORACLE_QUERY', 'BASIC +ALIAS +NOTE'));

PAUSE Press Enter to finish and clean up

DROP MATERIALIZED VIEW product_sales_mv;
DROP TABLE mv_sales PURGE;
DROP TABLE mv_products PURGE;
DELETE FROM plan_table
WHERE statement_id IN ('MV_ANSI_QUERY', 'MV_ORACLE_QUERY');
COMMIT;

EXIT
