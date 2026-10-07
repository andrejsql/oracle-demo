SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 110_dml_with_join.sql
REM Author......: Andrej Pashchenko
REM Description.: Direct Join in DML in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

CLEAR SCREEN

-------------------------------------------------------------------------------
--    UPDATE with FROM: raise prices for products that appear in sales > 1000.
--    Problem: if sales has multiple rows per prod_id, the product is updated
--    multiple times. Result is non-deterministic when rows differ.
-------------------------------------------------------------------------------

-- Before 26ai: required a correlated subquery
-- UPDATE sh.products p SET prod_min_price = prod_min_price * 1.1
-- WHERE EXISTS (SELECT 1 FROM sh.sales s WHERE s.prod_id = p.prod_id AND s.amount_sold > 1000);

-- Oracle 26ai: direct FROM clause
UPDATE sh.products p
SET    prod_min_price = prod_min_price * 1.1
FROM   sh.sales s
WHERE  s.prod_id = p.prod_id
AND    s.amount_sold > 1000;

-------------------------------------------------------------------------------
--    Safe version: inline view with DISTINCT ensures each product is joined
--    to exactly one sales row - UPDATE executes once per product.
-------------------------------------------------------------------------------

pause Press Enter TO CONTINUE

UPDATE sh.products p
SET    prod_min_price = prod_min_price * 1.1
FROM   (SELECT DISTINCT s1.prod_id FROM sh.sales s1 WHERE s1.amount_sold > 1000) s
WHERE  s.prod_id = p.prod_id
;



ROLLBACK;

pause Press Enter TO CONTINUE


-------------------------------------------------------------------------------
--    DELETE with FROM: remove all sales rows for the Internet channel.
--    Without FROM this would require a correlated subquery per sales row.
-------------------------------------------------------------------------------

DELETE sh.sales s
FROM   sh.channels c
WHERE  c.channel_id = s.channel_id
AND    c.channel_desc = 'Internet';




-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE

ROLLBACK;

 
EXIT