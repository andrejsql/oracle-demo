SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 13_reset_demo.sql
REM Author......: Andrej Pashchenko
REM Description.: Show team setup used for SELECT AI Agent demo
REM Notes.......: -
REM Parameters..: -
REM Dependencies: uses define_alhdb.sql
REM Requirements: Oracle Database 26ai (Autonomous)
REM
REM ***************************************************************************

@define_alhdb.sql
CONNECT /@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 1000 LINESIZE 100

-------------------------------------------------------------------------------
--              T O O L S
-------------------------------------------------------------------------------

set echo on 
SET pagesize 3333
column attribute_name format a20
column tool_name format a30
column attribute_value format a60 WORD_WRAPPED
set long 180
set longchunksize 180
set linesize 200

select tool_id, tool_name, attribute_name, replace(replace(dbms_lob.substr(attribute_value,180,1),chr(13)),chr(10),' ') attribute_value
from   user_ai_agent_tool_attributes
ORDER BY tool_id, tool_name, attribute_name;

-------------------------------------------------------------------------------
--               T A S K S
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE


set echo on 
SET pagesize 3333
column attribute_name format a20
column task_name format a30
column attribute_value format a60 WORD_WRAPPED
set long 180
set longchunksize 180
set linesize 200

select task_id, task_name, attribute_name, replace(replace(dbms_lob.substr(attribute_value,180,1),chr(13)),chr(10),' ') attribute_value
from   user_ai_agent_task_attributes
ORDER BY task_id;

-------------------------------------------------------------------------------
--               A G E N T S
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE

set echo on 
column attribute_name format a20
column agent_name format a25
column attribute_value format a60
set long 2000
set longchunksize 2000
set linesize 200

select agent_id, agent_name, attribute_name, attribute_value
from   user_ai_agent_attributes;

-------------------------------------------------------------------------------
--               T E A M
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE

set echo on 
column attribute_name format a15
column agent_team_name format a15
column attribute_value format a60
set long 2000
set longchunksize 2000
set linesize 200

select agent_team_id, agent_team_name, attribute_name, attribute_value
from   user_ai_agent_team_attributes;


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT