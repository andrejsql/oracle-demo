SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM File name...: 220_nested_cte.sql
REM Description.: Flat vs nested CTEs; inspecting intermediate results
REM Appendix....: SQL macro inside a CTE (version-dependent restriction)
REM Dependencies: define.sql; SELECT on SH.SALES and SH.CUSTOMERS
REM Requirements: 26ai RU 23.26.2+ for nested WITH; CREATE PROCEDURE privilege
REM Creates.....: DWH_COUNTRY_SALES_M (dropped at the end)
REM Run from the repository root: @26ai_dwh/220_nested_cte.sql
REM No source data is changed. Use a dedicated demo session (DDL commits).
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service

SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 160
SET VERIFY OFF
SET AUTOTRACE OFF
COLUMN country_amount_sold FORMAT 999,999,999,990.00
COLUMN customer_count FORMAT 999,990
COLUMN amount_sold FORMAT 999,999,999,990.00

CLEAR SCREEN

-------------------------------------------------------------------------------
-- 1a. Flat CTE chain: the transformation steps appear in sequence.
-- CUSTOMER_COUNT counts customers with sales, not all registered customers.
-------------------------------------------------------------------------------

WITH cust_sales AS (
    SELECT c.country_id
         , s.cust_id
         , SUM(s.amount_sold) amount_sold
    FROM   sh.sales s
    JOIN   sh.customers c ON c.cust_id = s.cust_id
    GROUP BY c.country_id, s.cust_id
), country_sales AS (
    SELECT country_id
         , SUM(amount_sold) country_amount_sold
         , COUNT(*) customer_count
    FROM   cust_sales
    GROUP BY country_id
)
SELECT country_id, country_amount_sold, customer_count
FROM   country_sales
WHERE  country_amount_sold > 100000
ORDER BY country_amount_sold DESC, country_id;

PAUSE Press Enter TO CONTINUE
CLEAR SCREEN

-------------------------------------------------------------------------------
-- 1b. Inspect an intermediate result: change ONLY the final SELECT.
-- COUNTRY_SALES remains in the statement but is not used by this SELECT.
-- This is convenient when debugging a longer ETL transformation chain.
-------------------------------------------------------------------------------

WITH cust_sales AS (
    SELECT c.country_id
         , s.cust_id
         , SUM(s.amount_sold) amount_sold
    FROM   sh.sales s
    JOIN   sh.customers c ON c.cust_id = s.cust_id
    GROUP BY c.country_id, s.cust_id
), country_sales AS (
    SELECT country_id
         , SUM(amount_sold) country_amount_sold
         , COUNT(*) customer_count
    FROM   cust_sales
    GROUP BY country_id
)
SELECT country_id, cust_id, amount_sold
FROM   cust_sales
ORDER BY amount_sold DESC, country_id, cust_id
FETCH FIRST 10 ROWS ONLY;

PAUSE Press Enter TO CONTINUE
CLEAR SCREEN

-------------------------------------------------------------------------------
-- 2a. Nested CTE: same calculation, but CUST_SALES has local scope.
-- Useful when embedding an existing WITH query without restructuring it.
-- Not inherently more readable than the flat chain above.
-- Before nested WITH support, this shape was rejected with ORA-32034.
-------------------------------------------------------------------------------

WITH country_sales AS (
    WITH cust_sales AS (
        SELECT c.country_id
             , s.cust_id
             , SUM(s.amount_sold) amount_sold
        FROM   sh.sales s
        JOIN   sh.customers c ON c.cust_id = s.cust_id
        GROUP BY c.country_id, s.cust_id
    )
    SELECT country_id
         , SUM(amount_sold) country_amount_sold
         , COUNT(*) customer_count
    FROM   cust_sales
    GROUP BY country_id
)
SELECT country_id, country_amount_sold, customer_count
FROM   country_sales
WHERE  country_amount_sold > 100000
ORDER BY country_amount_sold DESC, country_id;

PAUSE Press Enter TO CONTINUE
CLEAR SCREEN

-------------------------------------------------------------------------------
-- 2b. Inspect the same intermediate result in the nested approach.
-- Replacing only the outer SELECT with SELECT ... FROM CUST_SALES cannot
-- access the inner CTE: that name is outside the outer SELECT's scope.
-- Instead, extract the inner WITH query and change its final SELECT.
-- Compare this structural edit with the final-SELECT-only edit in 1b.
-------------------------------------------------------------------------------

WITH cust_sales AS (
    SELECT c.country_id
         , s.cust_id
         , SUM(s.amount_sold) amount_sold
    FROM   sh.sales s
    JOIN   sh.customers c ON c.cust_id = s.cust_id
    GROUP BY c.country_id, s.cust_id
)
SELECT country_id, cust_id, amount_sold
FROM   cust_sales
ORDER BY amount_sold DESC, country_id, cust_id
FETCH FIRST 10 ROWS ONLY;

-- Takeaway: flat chains are convenient for handwritten, testable ETL SQL.
-- Nested WITH adds flexibility for embedding existing query text.
-- A view containing a CTE could already be used from another query's CTE;
-- that is not a new capability introduced by nested WITH.

PAUSE Main comparison complete. Press Enter for the SQL macro appendix
CLEAR SCREEN

-------------------------------------------------------------------------------
-- Appendix 3. Package the aggregation as a stored table SQL macro.
-- The returned SQL deliberately contains its own WITH clause.
-- CREATE rather than CREATE OR REPLACE protects an existing function.
-------------------------------------------------------------------------------

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CREATE FUNCTION dwh_country_sales_m
    RETURN VARCHAR2 SQL_MACRO(TABLE)
IS
BEGIN
    RETURN q'[
        WITH cust_sales AS (
            SELECT c.country_id
                 , s.cust_id
                 , SUM(s.amount_sold) amount_sold
            FROM   sh.sales s
            JOIN   sh.customers c ON c.cust_id = s.cust_id
            GROUP BY c.country_id, s.cust_id
        )
        SELECT country_id
             , SUM(amount_sold) country_amount_sold
             , COUNT(*) customer_count
        FROM   cust_sales
        GROUP BY country_id
    ]';
END;
/
SHOW ERRORS

WHENEVER SQLERROR CONTINUE NONE

-- First, a direct call: the macro hides the intermediate aggregation.
SELECT country_id, country_amount_sold, customer_count
FROM   dwh_country_sales_m()
WHERE  country_amount_sold > 100000
ORDER BY country_amount_sold DESC, country_id;

PAUSE Press Enter TO CONTINUE
CLEAR SCREEN

-------------------------------------------------------------------------------
-- 4. Does nested WITH also remove the SQL-macro-in-CTE restriction?
-- NO on the tested Oracle AI Database Free 23.26.3.0.0 instance:
-- the following statement still raises ORA-64630. This error is intentional.
-- Nested WITH support alone does not establish SQL-macro-in-CTE support.
-- Connor McDonald demonstrates support in an unspecified upcoming RU:
-- https://connor-mcdonald.com/2026/07/01/with-clause-gets-a-26ai-boost/
-- This is a call to a STORED macro, not a WITH FUNCTION ... SQL_MACRO
-- declaration. Do not confuse the two capabilities.
-------------------------------------------------------------------------------

WITH country_sales AS (
    SELECT country_id, country_amount_sold, customer_count
    FROM   dwh_country_sales_m()
)
SELECT country_id, country_amount_sold, customer_count
FROM   country_sales
WHERE  country_amount_sold > 100000
ORDER BY country_amount_sold DESC, country_id;

PAUSE Press Enter TO CONTINUE

-------------------------------------------------------------------------------
-- 5. Working alternative: an inline view instead of a CTE around the call.
-- The macro's own WITH remains encapsulated in the returned SQL.
-------------------------------------------------------------------------------

SELECT country_id, country_amount_sold, customer_count
FROM   (
    SELECT country_id, country_amount_sold, customer_count
    FROM   dwh_country_sales_m()
) country_sales
WHERE  country_amount_sold > 100000
ORDER BY country_amount_sold DESC, country_id;


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
-------------------------------------------------------------------------------
-- Cleanup: only the function created by this script.
-------------------------------------------------------------------------------
DROP FUNCTION dwh_country_sales_m;

EXIT


