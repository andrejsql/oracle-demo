SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 170_join_to_one.sql
REM Author......: Andrej Pashchenko
REM Description.: JOIN TO ONE syntax in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 


SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

spool jointoone.out

DROP TABLE IF EXISTS promotions PURGE;

CREATE TABLE IF NOT EXISTS promotions AS SELECT * FROM sh.promotions;


SET TIMING ON

SET AUTOTRACE ON EXPLAIN

select sum(s.amount_sold) 
from   sh.sales s
join   sh.customers c
  on   c.cust_id = s.cust_id
join   promotions p
  on   p.promo_id = s.promo_id;

SET AUTOTRACE OFF  

-------------------------------------------------------------------------------
-- Simulate a duplicate in PROMOTIONS - the kind of data quality issue
-- that can sneak in and silently corrupt aggregates.
-------------------------------------------------------------------------------

insert into promotions select * from promotions where promo_id = 999;


pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
-- The aggregate is now wrong - silently. No error, just a higher number.
-- This is the chasm trap / row multiplication problem.
-------------------------------------------------------------------------------

select sum(s.amount_sold) 
from   sh.sales s
join   sh.customers c
  on   c.cust_id = s.cust_id
join   promotions p
  on   p.promo_id = s.promo_id;


-------------------------------------------------------------------------------
-- JOIN TO ONE catches the duplicate at runtime and raises an error.
-- The RWT (sales) grain is protected - no silent row multiplication.
-------------------------------------------------------------------------------

pause Press Enter TO CONTINUE


select sum(s.amount_sold)
from   sh.sales s
join to one (customers c  on c.cust_id = s.cust_id, promotions p  on p.promo_id = s.promo_id );


pause Press Enter TO CONTINUE

ROLLBACK;

SET AUTOTRACE ON EXPLAIN

--select sum(s.amount_sold)
--from   sales s
--join to one (customers c  on c.cust_id = s.cust_id, promotions p  on p.promo_id = s.promo_id );

-- THINK TWICE: this query ran for over an hour and was cancelled.
-- The runtime uniqueness check is a correlated scalar subquery inside a LATERAL view -
-- one extra lookup per sales row. Without ENABLE VALIDATE PK/UK constraints,
-- Oracle cannot skip this check. The plan below confirms it.

--SELECT SUM ("A1"."AMOUNT_SOLD_2")     "SUM(S.AMOUNT_SOLD)"
--  FROM (SELECT "A3"."QCSJ_C000000000300000_0"     "QCSJ_C000000000300000",
--               "A3"."PROMO_ID_1"                  "QCSJ_C000000000500000",
--               "A3"."AMOUNT_SOLD_2"               "AMOUNT_SOLD_2",
--               "A3"."QCSJ_C000000000300001_3"     "QCSJ_C000000000300001",
--               "A2"."PROMO_ID"                    "QCSJ_C000000000500001"
--          FROM (SELECT "A5"."CUST_ID"         "QCSJ_C000000000300000_0",
--                       "A5"."PROMO_ID"        "PROMO_ID_1",
--                       "A5"."AMOUNT_SOLD"     "AMOUNT_SOLD_2",
--                       "A4"."CUST_ID"         "QCSJ_C000000000300001_3"
--                  FROM "ETL_OPS"."SALES" "A5", "ETL_OPS"."CUSTOMERS" "A4"
--                 WHERE     "A4"."CUST_ID" = "A5"."CUST_ID"
--                       AND 'C' = (SELECT 'C'     "C"
--                                    FROM "ETL_OPS"."CUSTOMERS" "A6"
--                                   WHERE "A6"."CUST_ID" = "A5"."CUST_ID"))
--               "A3",
--               "ETL_OPS"."PROMOTIONS"  "A2"
--         WHERE     "A2"."PROMO_ID" = "A3"."PROMO_ID_1"
--               AND 'P' = (SELECT 'P'     "C"
--                            FROM "ETL_OPS"."PROMOTIONS" "A7"
--                           WHERE "A7"."PROMO_ID" = "A3"."PROMO_ID_1")) "A1";


--SQL_ID  1s79bb8uqrg3g, child number 0
---------------------------------------
--select sum(s.amount_sold) from   sales s join to one (customers c  on 
--c.cust_id = s.cust_id, promotions p  on p.promo_id = s.promo_id )
-- 
--Plan hash value: 2545663031
-- 
---------------------------------------------------------------------------------------------
--| Id  | Operation               | Name            | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------------
--|   0 | SELECT STATEMENT        |                 |       |       |    11M(100)|          |
--|   1 |  SORT AGGREGATE         |                 |     1 |    14 |            |          |
--|   2 |   MERGE JOIN OUTER      |                 |   918K|    12M|    11M  (8)| 00:07:44 |
--|   3 |    MERGE JOIN OUTER     |                 |   918K|    12M|  8180K (11)| 00:05:20 |
--|   4 |     TABLE ACCESS FULL   | SALES           |   918K|    12M|    20  (45)| 00:00:01 |
--|   5 |     BUFFER SORT         |                 |     1 |       |  8180K (11)| 00:05:20 |
--|   6 |      VIEW               | VW_LAT_A22CA6F4 |     1 |       |     9  (12)| 00:00:01 |
--|*  7 |       FILTER            |                 |       |       |            |          |
--|*  8 |        TABLE ACCESS FULL| CUSTOMERS       |     1 |     5 |     4   (0)| 00:00:01 |
--|*  9 |        TABLE ACCESS FULL| CUSTOMERS       |     1 |     5 |     4   (0)| 00:00:01 |
--|  10 |    BUFFER SORT          |                 |     1 |       |    11M  (8)| 00:07:44 |
--|  11 |     VIEW                | VW_LAT_A22CA6F4 |     1 |       |     4   (0)| 00:00:01 |
--|* 12 |      FILTER             |                 |       |       |            |          |
--|* 13 |       TABLE ACCESS FULL | PROMOTIONS      |     1 |     4 |     2   (0)| 00:00:01 |
--|* 14 |       TABLE ACCESS FULL | PROMOTIONS      |     1 |     4 |     2   (0)| 00:00:01 |
---------------------------------------------------------------------------------------------
-- 
--Predicate Information (identified by operation id):
-----------------------------------------------------
-- 
--   7 - filter(='C')
--   8 - filter("C"."CUST_ID"="S"."CUST_ID")
--   9 - filter("C"."CUST_ID"=:B1)
--  12 - filter(='P')
--  13 - filter("P"."PROMO_ID"="S"."PROMO_ID")
--  14 - filter("P"."PROMO_ID"=:B1)
-- 


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
ROLLBACK;

EXIT
