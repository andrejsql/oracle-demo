SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 190_assertions.sql
REM Author......: Andrej Pashchenko
REM Description.: SQL Assertions in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 

SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

CLEAR SCREEN

DROP ASSERTION IF EXISTS emp_mgr_salary_check;

-- Cross-row rule: no employee may earn more than their manager.
-- But ANSI Joins are not supported
CREATE ASSERTION IF NOT EXISTS emp_mgr_salary_check
CHECK (
  NOT EXISTS (
    SELECT 1
    FROM emp e
         JOIN emp m
           ON m.empno = e.mgr
    WHERE e.sal > m.sal
  )
);

 pause Press Enter TO CONTINUE 

-- Oracle join notation for the same rule.

CREATE ASSERTION IF NOT EXISTS emp_mgr_salary_check
CHECK (
  NOT EXISTS (
    SELECT 1
    FROM emp e, emp m
    WHERE m.empno = e.mgr AND e.sal > m.sal
  )
); 

pause Press Enter TO CONTINUE 


CREATE ASSERTION IF NOT EXISTS emp_mgr_salary_check
CHECK (
  NOT EXISTS (
    SELECT 1
    FROM emp e, emp m
    WHERE m.empno = e.mgr AND e.sal > m.sal
    AND   e.mgr IS NOT NULL
  )
);

pause Press Enter TO CONTINUE 

-- Create Assertion without enforcing it or validating existing rows.
CREATE ASSERTION IF NOT EXISTS emp_mgr_salary_check
CHECK (
  NOT EXISTS (
    SELECT 1
    FROM emp e, emp m
    WHERE m.empno = e.mgr AND e.sal > m.sal
    AND   e.mgr IS NOT NULL
  )
) DISABLE NOVALIDATE;

pause Press Enter TO CONTINUE 

-- Raise JONES above the 3000 salary of his reports in the standard EMP data.
UPDATE emp
set   sal = 3001
WHERE ENAME = 'JONES';

COMMIT;

pause Press Enter TO CONTINUE 

-- Validate current data and enable enforcement for subsequent changes.
ALTER ASSERTION emp_mgr_salary_check ENABLE VALIDATE;

pause Press Enter TO CONTINUE 


UPDATE emp
set   sal = 2975
WHERE ENAME = 'JONES';

pause Press Enter TO CONTINUE 


DROP ASSERTION IF EXISTS emp_mgr_salary_check;

UPDATE emp
set   sal = 2975
WHERE ENAME = 'JONES';

COMMIT;

pause Press Enter TO CONTINUE 

-- ALL ... SATISFY expresses the rule for every employee/manager pair.
-- This version is stricter: equal salaries also violate the rule (< vs <=).
-- It is created disabled, so existing salary violations are not checked.
CREATE ASSERTION emp_mgr_salary_check
CHECK (
  ALL (
    SELECT e.sal staff_sal
         , m.sal mgr_sal
    FROM emp e
       , emp m
    WHERE e.mgr = m.empno
      AND e.mgr IS NOT NULL
  ) x
  SATISFY (
    staff_sal < mgr_sal
  )
) DISABLE NOVALIDATE;


pause Press Enter TO CONTINUE 

-- Every department must contain at least one employee.
-- An existing empty department prevents creation of this enabled assertion.
CREATE ASSERTION no_empty_departments CHECK  
(NOT EXISTS  
  (SELECT 'an empty department' 
     FROM dept d 
     WHERE d.deptno is not null and NOT EXISTS 
                   (SELECT 'an employee in the department' 
                      FROM emp e 
                      WHERE e.deptno = d.deptno
                      and  e.deptno is not null)));

 pause Press Enter TO CONTINUE                     
                      
-- Express the same department rule positively with ALL ... SATISFY.
CREATE ASSERTION no_empty_departments_2 CHECK
(ALL (SELECT d.deptno 
       FROM dept d) da 
 SATISFY 
  (EXISTS 
    (SELECT '' 
       FROM emp e 
       WHERE e.deptno = da.deptno
       and  e.deptno is not null)));    
       
pause Press Enter TO CONTINUE       
       
-- Promotions in the same category/subcategory must not overlap.

CREATE ASSERTION no_overlapping_promos CHECK (
  NOT EXISTS (
    SELECT p1.*, p2.*
    FROM promotions p1
       , promotions p2
    WHERE p1.promo_id < p2.promo_id
      AND p1.promo_category_id = p2.promo_category_id
      AND p1.promo_subcategory_id = p2.promo_subcategory_id
      AND p1.promo_begin_date < p2.promo_end_date
      AND p2.promo_begin_date < p1.promo_end_date
             )
);


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
-- ROLLBACK affects only pending DML; it does not undo assertion DDL.
-- The department and promotion assertions are retained by this script.
ROLLBACK;
DROP ASSERTION IF EXISTS emp_mgr_salary_check;

EXIT
