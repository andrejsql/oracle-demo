SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 80_qualify_clause.sql
REM Author......: Andrej Pashchenko
REM Description.: Show QUALIFY clause for analytical functions
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

CLEAR SCREEN

-------------------------------------------------------------------------------
--  Find top 5 products per year 
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
--   Before Oracle 26ai, analytic function results could not be filtered
--   in the same query - WHERE and HAVING both run before window functions are evaluated.
-------------------------------------------------------------------------------

-- WHERE on a window function fails: window functions are evaluated after WHERE
SELECT  t.calendar_year,
        p.prod_name,
        SUM(s.amount_sold) AS revenue,
        ROW_NUMBER() OVER (PARTITION BY t.calendar_year
                 ORDER BY SUM(s.amount_sold) DESC) AS rn
FROM sh.sales s
JOIN sh.times t    ON t.time_id = s.time_id
JOIN sh.products p ON p.prod_id = s.prod_id
WHERE   ROW_NUMBER() OVER (PARTITION BY t.calendar_year
                 ORDER BY SUM(s.amount_sold) DESC)  <= 5
GROUP BY t.calendar_year, p.prod_name;

pause Press Enter TO CONTINUE

-- HAVING on a window function fails for the same reason
SELECT  t.calendar_year,
        p.prod_name,
        SUM(s.amount_sold) AS revenue,
        ROW_NUMBER() OVER (PARTITION BY t.calendar_year
                 ORDER BY SUM(s.amount_sold) DESC) AS rn
FROM sh.sales s
JOIN sh.times t    ON t.time_id = s.time_id
JOIN sh.products p ON p.prod_id = s.prod_id
HAVING   ROW_NUMBER() OVER (PARTITION BY t.calendar_year
                 ORDER BY SUM(s.amount_sold) DESC)  <= 5
GROUP BY t.calendar_year, p.prod_name;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--   Classic workaround: wrap the analytic query in a subquery, then filter
--   with WHERE in the outer query. Works, but adds a nesting level purely for syntax.
-------------------------------------------------------------------------------

SELECT * FROM (
SELECT  t.calendar_year,
        p.prod_name,
        SUM(s.amount_sold) AS revenue,
        ROW_NUMBER() OVER (PARTITION BY t.calendar_year
                 ORDER BY SUM(s.amount_sold) DESC) AS rn
FROM sh.sales s
JOIN sh.times t    ON t.time_id = s.time_id
JOIN sh.products p ON p.prod_id = s.prod_id
GROUP BY t.calendar_year, p.prod_name
) 
WHERE rn <= 5
ORDER BY calendar_year, rn;

 
pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--   Oracle 26ai: QUALIFY filters on analytic results directly, no subquery needed.
--   Processed after GROUP BY, HAVING, and window function evaluation.
-------------------------------------------------------------------------------
SET AUTOTRACE ON EXPLAIN

SELECT  t.calendar_year,
        p.prod_name,
        SUM(s.amount_sold) AS revenue,
        ROW_NUMBER() OVER (PARTITION BY t.calendar_year
                 ORDER BY SUM(s.amount_sold) DESC) AS rn
FROM sh.sales s
JOIN sh.times t    ON t.time_id = s.time_id
JOIN sh.products p ON p.prod_id = s.prod_id
GROUP BY t.calendar_year, p.prod_name
QUALIFY rn <= 5
ORDER BY t.calendar_year, rn

Pause
/


-------------------------------------------------------------------------------
--    How Oracle transforms the QUALIFY clause internally
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE

SET LONG 1000000
SET LONGCHUNKSIZE 32767
SET PAGESIZE 3000
COLUMN expanded_sql FORMAT A120

WITH FUNCTION get_sql(p_sql IN CLOB) RETURN CLOB IS
  p_raw  CLOB;
BEGIN
  DBMS_UTILITY.EXPAND_SQL_TEXT(p_sql, p_raw);
  RETURN p_raw;
END;
SELECT get_sql(q'[
  SELECT  t.calendar_year,
          p.prod_name,
          SUM(s.amount_sold) AS revenue,
          ROW_NUMBER() OVER (PARTITION BY t.calendar_year
                   ORDER BY SUM(s.amount_sold) DESC) AS rn
  FROM sh.sales s
  JOIN sh.times t    ON t.time_id = s.time_id
  JOIN sh.products p ON p.prod_id = s.prod_id
  GROUP BY t.calendar_year, p.prod_name
  QUALIFY rn <= 5
  ORDER BY t.calendar_year, rn
]') AS expanded_sql
.

pause  Press Enter TO CONTINUE

  SELECT "from$_subquery$_006"."CALENDAR_YEAR"     "CALENDAR_YEAR",
         "from$_subquery$_006"."PROD_NAME"         "PROD_NAME",
         "from$_subquery$_006"."REVENUE"           "REVENUE",
         "from$_subquery$_006"."RN"                "RN"
    FROM (  SELECT "T"."CALENDAR_YEAR"
                       "CALENDAR_YEAR",
                   "P"."PROD_NAME"
                       "PROD_NAME",
                   SUM ("S"."AMOUNT_SOLD")
                       "REVENUE",
                   ROW_NUMBER ()
                       OVER (PARTITION BY "T"."CALENDAR_YEAR"
                             ORDER BY SUM ("S"."AMOUNT_SOLD") DESC)
                       "RN",
                   ROW_NUMBER ()
                       OVER (PARTITION BY "T"."CALENDAR_YEAR"
                             ORDER BY SUM ("S"."AMOUNT_SOLD") DESC) <=  5  "sys_qualify$_h$_predex$_0",
                   "T"."CALENDAR_YEAR"
                       "sys_qualify$_h$_obyex$_00000",
                   ROW_NUMBER ()
                       OVER (PARTITION BY "T"."CALENDAR_YEAR"
                             ORDER BY SUM ("S"."AMOUNT_SOLD") DESC)
                       "sys_qualify$_h$_obyex$_00001"
              FROM "SH"."SALES" "S", "SH"."TIMES" "T", "SH"."PRODUCTS" "P"
             WHERE     "P"."PROD_ID" = "S"."PROD_ID"
                   AND "T"."TIME_ID" = "S"."TIME_ID"
          GROUP BY "T"."CALENDAR_YEAR", "P"."PROD_NAME") "from$_subquery$_006"
   WHERE "from$_subquery$_006"."sys_qualify$_h$_predex$_0" = TRUE
ORDER BY "from$_subquery$_006"."sys_qualify$_h$_obyex$_00000",
         "from$_subquery$_006"."sys_qualify$_h$_obyex$_00001"

----------------------------------------------------------------------------------------------------------------
--| Id  | Operation                         | Name     | Rows  | Bytes | Cost (%CPU)| Time     | Pstart| Pstop |
----------------------------------------------------------------------------------------------------------------
--|   0 | SELECT STATEMENT                  |          |   237 | 17064 |  3890   (2)| 00:00:01 |       |       |
--|   1 |  SORT ORDER BY                    |          |   237 | 17064 |  3890   (2)| 00:00:01 |       |       |
--|*  2 |   VIEW                            |          |   237 | 17064 |  3889   (2)| 00:00:01 |       |       |
--|   3 |    WINDOW SORT                    |          |   237 | 13272 |  3889   (2)| 00:00:01 |       |       |
--|   4 |     HASH GROUP BY                 |          |   237 | 13272 |  3889   (2)| 00:00:01 |       |       |
--|*  5 |      HASH JOIN                    |          |   918K|    49M|  3849   (1)| 00:00:01 |       |       |
--|   6 |       PART JOIN FILTER CREATE     | :BF0000  |  1826 | 21912 |    17   (0)| 00:00:01 |       |       |
--|     |        TABLE ACCESS FULL          | TIMES    |  1826 | 21912 |    17   (0)| 00:00:01 |       |       |
--|*  8 |       HASH JOIN                   |          |   918K|    38M|  3829   (1)| 00:00:01 |       |       |
--|   9 |        TABLE ACCESS FULL          | PRODUCTS |    72 |  1944 |     3   (0)| 00:00:01 |       |       |
--|  10 |        PARTITION RANGE JOIN-FILTER|          |   918K|    14M|  3824   (1)| 00:00:01 |:BF0000|:BF0000|
--|  11 |         TABLE ACCESS FULL         | SALES    |   918K|    14M|  3824   (1)| 00:00:01 |:BF0000|:BF0000|
----------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE

EXIT