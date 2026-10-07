SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 200_schema_privs.sql
REM Author......: Andrej Pashchenko
REM Description.: Schema-level privilege grants in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

CLEAR SCREEN

CONNECT system/&_system_password.@&_sid_or_service 

drop user if exists demo_owner cascade;

create user demo_owner identified by demo_owner
  default tablespace users quota 1m on users;

grant create session, create table to demo_owner;

drop user if exists demo_user cascade;

create user demo_user identified by demo_user;

grant create session to demo_user;

-------------------------------------------------------------------------------
--               Connect as DEMO_OWNER and create a table
-------------------------------------------------------------------------------
CONNECT demo_owner/demo_owner@&_sid_or_service 

create table t1 (
  id number
);

insert into t1 values (1);
commit;

pause Press Enter TO CONTINUE
-------------------------------------------------------------------------------
--        DEMO_USER can't see this table
-------------------------------------------------------------------------------
CONNECT demo_user/demo_user@&_sid_or_service 

select * from demo_owner.t1;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--        We need an explicit GRANT or ANY privilege
-------------------------------------------------------------------------------
CONNECT demo_owner/demo_owner@&_sid_or_service 

grant read on t1 to demo_user;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--       Now DEMO_USER can see T1
-------------------------------------------------------------------------------
CONNECT demo_user/demo_user@&_sid_or_service 

select * from demo_owner.t1;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--       Now DEMO_OWNER creates a table T2
-------------------------------------------------------------------------------
CONNECT demo_owner/demo_owner@&_sid_or_service 

create table t2 (
  id number
);

insert into t2 values (2);
commit;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--       But DEMO_USER can't see T2
-------------------------------------------------------------------------------
CONNECT demo_user/demo_user@&_sid_or_service 

select * from demo_owner.t2;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--      How to fix it with SCHEMA PRIVILEGE?
-------------------------------------------------------------------------------
CONNECT demo_owner/demo_owner@&_sid_or_service  

grant read any table on schema demo_owner to demo_user;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--       And DEMO_USER can see it
-------------------------------------------------------------------------------
CONNECT demo_user/demo_user@&_sid_or_service 

select * from demo_owner.t2;

pause Press Enter TO CONTINUE


-------------------------------------------------------------------------------
--       Now DEMO_OWNER creates a table T3
-------------------------------------------------------------------------------
CONNECT demo_owner/demo_owner@&_sid_or_service 

create table t3 (
  id number
);

insert into t3 values (3);
commit;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--       DEMO_USER sees it as well
-------------------------------------------------------------------------------
CONNECT demo_user/demo_user@&_sid_or_service 

select * from demo_owner.t3;



-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE

CONNECT system/&_system_password.@&_sid_or_service

drop user if exists demo_user cascade;
drop user if exists demo_owner cascade;

EXIT
