SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 70_filter_clause.sql
REM Author......: Andrej Pashchenko
REM Description.: Show FILTER clause for aggregate functions
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

CLEAR SCREEN

-------------------------------------------------------------------------------
--   Goal: one row per year with four separate KPIs (sales amount and purchase count) for
--   - the Internet channel, excluding product 138
--   - all other channels
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
--   1st try: UNION ALL
--   The prod_id 138 exclusion prevents a simple GROUP BY channel.
--   Readable, but requires two full scans of the (large) sales table.
-------------------------------------------------------------------------------

SELECT  t.calendar_year, 
        'Internet' channel_grp,
        SUM(s.amount_sold) amount_sold,
        COUNT(*) as sale_cnt
FROM    sh.sales s 
        JOIN sh.times t ON t.time_id = s.time_id 
        JOIN sh.channels c ON c.channel_id = s.channel_id 
WHERE   c.channel_desc = 'Internet'  and s.prod_id != 138      
GROUP BY t.calendar_year
UNION ALL
SELECT  t.calendar_year, 
        'Other' channel_grp,
        SUM(s.amount_sold) amount_sold,
        COUNT(*) as sale_cnt
FROM    sh.sales s 
        JOIN sh.times t ON t.time_id = s.time_id 
        JOIN sh.channels c ON c.channel_id = s.channel_id 
WHERE   c.channel_desc <> 'Internet'        
GROUP BY t.calendar_year;

 
pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--   The KPIs land as separate rows, not columns - a PIVOT is needed on top.
--   Still two table scans, plus the overhead of the pivot step.
-------------------------------------------------------------------------------

SELECT * FROM (
    SELECT  t.calendar_year, 
            'Internet' channel_grp,
            SUM(s.amount_sold) amount_sold,
            COUNT(*) as sale_cnt
    FROM    sh.sales s 
            JOIN sh.times t ON t.time_id = s.time_id 
            JOIN sh.channels c ON c.channel_id = s.channel_id 
    WHERE   c.channel_desc = 'Internet'  and s.prod_id != 138      
    GROUP BY t.calendar_year
    UNION ALL
    SELECT  t.calendar_year, 
            'Other' channel_grp,
            SUM(s.amount_sold) amount_sold,
            COUNT(*) as sale_cnt
    FROM    sh.sales s 
            JOIN sh.times t ON t.time_id = s.time_id 
            JOIN sh.channels c ON c.channel_id = s.channel_id 
    WHERE   c.channel_desc <> 'Internet'        
    GROUP BY t.calendar_year)
PIVOT (
  SUM(amount_sold) as amount_sold,
  sum(sale_cnt) as sales_cnt
  FOR channel_grp IN (
    'Internet' AS internet,
    'Other'    AS other
  )
)
ORDER BY calendar_year;


pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--    2nd try: CASE inside aggregate
--    Single scan, all four KPIs in one GROUP BY - efficient.
--    But logic is buried inside each aggregate; COUNT requires NULL (not 0) in ELSE.
-------------------------------------------------------------------------------

SELECT  t.calendar_year, 
        SUM(CASE 
               WHEN c.channel_desc = 'Internet'  and s.prod_id != 138 
                   THEN s.amount_sold 
               ELSE 0 
            END)  AS amount_sold_internet,
        SUM(CASE 
               WHEN c.channel_desc <> 'Internet' 
                   THEN s.amount_sold 
               ELSE 0 
            END) amount_sold_other,
        COUNT(CASE 
               WHEN c.channel_desc = 'Internet'  and s.prod_id != 138 
                   THEN s.amount_sold -- count some NOT NULL column
               ELSE NULL   -- otherwise count NULL, not 0!
            END)  AS sales_cnt_internet,            
        COUNT(CASE 
               WHEN c.channel_desc <> 'Internet' 
                   THEN s.amount_sold -- count some NOT NULL column
               ELSE NULL   -- otherwise count NULL, not 0!
            END) sales_cnt_other            
FROM    sh.sales s 
        JOIN sh.times t ON t.time_id = s.time_id 
        JOIN sh.channels c ON c.channel_id = s.channel_id 
GROUP BY t.calendar_year
ORDER BY calendar_year
;


pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--    Oracle 26ai: FILTER clause - single scan, readable conditions per aggregate
-------------------------------------------------------------------------------

SELECT  t.calendar_year, 
        SUM(s.amount_sold)   FILTER (WHERE c.channel_desc = 'Internet'  and s.prod_id != 138)   AS amount_sold_internet,
        SUM(s.amount_sold)   FILTER (WHERE c.channel_desc <> 'Internet')                        AS amount_sold_other,
        COUNT(s.amount_sold) FILTER (WHERE c.channel_desc = 'Internet'  and s.prod_id != 138)   AS sales_cnt_internet,            
        COUNT(s.amount_sold) FILTER (WHERE c.channel_desc <> 'Internet')                        AS sales_cnt_other            
FROM    sh.sales s 
        JOIN sh.times t ON t.time_id = s.time_id 
        JOIN sh.channels c ON c.channel_id = s.channel_id 
GROUP BY t.calendar_year
ORDER BY calendar_year;

-------------------------------------------------------------------------------
--    Under the hood Oracle rewrites FILTER to CASE WHEN ... ELSE NULL.
--    Same execution plan as the manual CASE approach - no hidden cost.
-------------------------------------------------------------------------------

pause Press Enter TO CONTINUE



SELECT "A1"."CALENDAR_YEAR_5"    "CALENDAR_YEAR",
         SUM (
             CASE
                 WHEN (    "A1"."CHANNEL_DESC_7" = 'Internet'
                       AND "A1"."PROD_ID_0" <> 138)
                 THEN
                     "A1"."AMOUNT_SOLD_3"
                 ELSE
                     NULL
             END)                  "AMOUNT_SOLD_INTERNET",
         SUM (
             CASE
                 WHEN "A1"."CHANNEL_DESC_7" <> 'Internet'
                 THEN
                     "A1"."AMOUNT_SOLD_3"
                 ELSE
                     NULL
             END)                  "AMOUNT_SOLD_OTHER",
         COUNT (
             CASE
                 WHEN (    "A1"."CHANNEL_DESC_7" = 'Internet'
                       AND "A1"."PROD_ID_0" <> 138)
                 THEN
                     "A1"."AMOUNT_SOLD_3"
                 ELSE
                     NULL
             END)                  "SALES_CNT_INTERNET",
         COUNT (
             CASE
                 WHEN "A1"."CHANNEL_DESC_7" <> 'Internet'
                 THEN
                     "A1"."AMOUNT_SOLD_3"
                 ELSE
                     NULL
             END)                  "SALES_CNT_OTHER"
    FROM (SELECT "A3"."PROD_ID_0"                   "PROD_ID_0",
                 "A3"."QCSJ_C000000000300000_1"     "QCSJ_C000000000300000",
                 "A3"."CHANNEL_ID_2"                "QCSJ_C000000000500000",
                 "A3"."AMOUNT_SOLD_3"               "AMOUNT_SOLD_3",
                 "A3"."QCSJ_C000000000300001_4"     "QCSJ_C000000000300001",
                 "A3"."CALENDAR_YEAR_5"             "CALENDAR_YEAR_5",
                 "A2"."CHANNEL_ID"                  "QCSJ_C000000000500001",
                 "A2"."CHANNEL_DESC"                "CHANNEL_DESC_7"
            FROM (SELECT "A5"."PROD_ID"           "PROD_ID_0",
                         "A5"."TIME_ID"           "QCSJ_C000000000300000_1",
                         "A5"."CHANNEL_ID"        "CHANNEL_ID_2",
                         "A5"."AMOUNT_SOLD"       "AMOUNT_SOLD_3",
                         "A4"."TIME_ID"           "QCSJ_C000000000300001_4",
                         "A4"."CALENDAR_YEAR"     "CALENDAR_YEAR_5"
                    FROM "SH"."SALES" "A5", "SH"."TIMES" "A4"
                   WHERE "A4"."TIME_ID" = "A5"."TIME_ID") "A3",
                 "SH"."CHANNELS" "A2"
           WHERE "A2"."CHANNEL_ID" = "A3"."CHANNEL_ID_2") "A1"
GROUP BY "A1"."CALENDAR_YEAR_5"
ORDER BY "A1"."CALENDAR_YEAR_5".

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--    FILTER also works with analytic (window) functions.
--    Example: year-to-date running total restricted to the Internet channel.
-------------------------------------------------------------------------------


SELECT
  t.calendar_year,
  t.time_id,
  s.cust_id, 
  s.amount_sold,
  c.channel_desc,
  NVL(SUM(s.amount_sold) FILTER (WHERE c.channel_desc = 'Internet')
    OVER (
      PARTITION BY t.calendar_year
      ORDER BY t.time_id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ),0) AS internet_ytd_rev
FROM sh.sales s
JOIN sh.times t    ON t.time_id = s.time_id
JOIN sh.channels c ON c.channel_id = s.channel_id
WHERE amount_sold < 10
ORDER BY t.calendar_year, t.time_id, s.cust_id
FETCH FIRST 10 ROWS ONLY;
 

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT