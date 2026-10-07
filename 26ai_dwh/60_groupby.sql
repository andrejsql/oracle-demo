SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 60_groupby.sql
REM Author......: Andrej Pashchenko
REM Description.: Show Group By enhancements
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

CLEAR SCREEN

-------------------------------------------------------------------------------
--    Before 26ai: expressions had to be repeated verbatim in GROUP BY and HAVING,
--    even when they already had an alias in the SELECT list.
-------------------------------------------------------------------------------

SELECT  prod_id
,       TO_CHAR(t.time_id, 'IYYY-IW') AS kw
,       SUM(s.amount_sold) AS revenue
FROM    sh.sales s
JOIN    sh.times t ON t.time_id = s.time_id
GROUP BY  prod_id, TO_CHAR(t.time_id, 'IYYY-IW')
HAVING    SUM(s.amount_sold)  > 50000
ORDER BY revenue DESC
FETCH FIRST 10 ROWS ONLY;

 
pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--    Oracle 26ai: GROUP BY and HAVING accept SELECT aliases directly.
--    kw and revenue resolve to their expressions - no duplication.
-------------------------------------------------------------------------------

SELECT   prod_id,
         TO_CHAR(t.time_id, 'IYYY-IW') AS kw,
         SUM(s.amount_sold) AS revenue
FROM     sh.sales s
JOIN     sh.times t ON t.time_id = s.time_id
GROUP BY prod_id, kw
HAVING   revenue  > 50000
ORDER BY revenue DESC
FETCH FIRST 10 ROWS ONLY;


pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--    Column positions in GROUP BY (like ORDER BY has always supported).
--    Requires: ALTER SESSION SET group_by_position_enabled = TRUE.
--    Handy for ad-hoc queries; named aliases are clearer in production code.
-------------------------------------------------------------------------------

alter session set group_by_position_enabled=true;
 
SELECT   prod_id
,        TO_CHAR(t.time_id, 'IYYY-IW') AS kw
,        SUM(s.amount_sold) AS revenue
FROM     sh.sales s
JOIN     sh.times t ON t.time_id = s.time_id
GROUP BY 1, 2
HAVING   revenue > 50000
ORDER BY revenue DESC
FETCH FIRST 10 ROWS ONLY;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--    GROUP BY ALL: Oracle automatically groups by every non-aggregated column
--    in the SELECT list. No more copying column names from SELECT to GROUP BY.
--    The optimizer expands ALL to an explicit list - same execution plan.
-------------------------------------------------------------------------------

SELECT   prod_id
,        c.channel_desc
,        p.promo_name
,        TO_CHAR(t.time_id, 'IYYY-IW') AS kw
,        SUM(s.amount_sold) AS revenue
FROM     sh.sales s
JOIN     sh.times t ON t.time_id = s.time_id
JOIN     sh.channels c on c.channel_id = s.channel_id
JOIN     sh.promotions p on p.promo_id = s.promo_id
GROUP BY ALL
HAVING   revenue > 50000
ORDER BY revenue DESC
FETCH FIRST 10 ROWS ONLY;
 

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT