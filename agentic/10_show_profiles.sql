SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 10_show_profiles.sql
REM Author......: Andrej Pashchenko
REM Description.: Show AI Profiles used for SELECT AI Agent demo
REM Notes.......: -
REM Parameters..: -
REM Dependencies: uses define_alhdb.sql
REM Requirements: Oracle Database 26ai (Autonomous)
REM
REM ***************************************************************************

@define_alhdb.sql
CONNECT /@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 1000 LINESIZE 100


set lines 200
set pages 3333
set long 30
set LONGCHUNKSIZE 30

column profile_name format a25
column attribute_name format a25
column attribute_value format a30

set echo on

clear SCREEN

select a.profile_name, a.attribute_name, a.attribute_value
from user_cloud_ai_profile_attributes a
where profile_name in ('ETL_OPS_OCI_GPT_OSS120','OPENAI','ETL_OPS_AI_PROFILE') 
ORDER BY a.profile_name;

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT