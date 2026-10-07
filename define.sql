SET ECHO OFF
REM ***************************************************************************
REM Privileges..: None
REM File name...: define.sql
REM Description.: Defines the users and passwords used in the example scripts
REM ***************************************************************************

SET TERMOUT OFF ECHO OFF


DEFINE _sid_or_service = //localhost:1526/FREEPDB1

DEFINE _service = FREEPDB1

DEFINE _sid_or_service_cdb = FREE
DEFINE _service_cdb = FREE

DEFINE _sys_password = oracle
DEFINE _system_password = oracle

DEFINE _scott_user = scott
DEFINE _scott_password = tiger

DEFINE _streamora_user = streamora
--DEFINE _streamora_password = 

DEFINE _redaction_user = normal_user
DEFINE _redaction_password = normal

DEFINE _redaction_app_user = app_user
DEFINE _redaction_app_password = app

DEFINE _hr_user = hr
DEFINE _hr_password = hr

DEFINE _sh_user = sh
DEFINE _sh_password = sh

DEFINE _onf_user = onf
DEFINE _onf_password = oracle

DEFINE _test2_user = test2
DEFINE _test2_password = test2

DEFINE _data_path = /opt/oracle/oradata/FREE/FREEPDB1
DEFINE _json_path = /opt/oracle/oradata/ext_data
DEFINE _ext_data_path = /opt/oracle/oradata/ext_data

SET SQLPR '_user>'
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 300 

--wrap off

REM ===========================================================================
REM Formating for the columns
REM ===========================================================================

column table_name       format a12
column constraint_type  format a16
column search_condition format a40
column column_name      format a12
column data_type        format a10
column hidden_column    format a15
column virtual_column   format a15
column periodname       format a12
column periodstart      format a12
column periodend        format a12
column spare            format a12

COLUMN username     FORMAT A30
COLUMN granted_role FORMAT A30

COLUMN first_name   FORMAT A12
COLUMN last_name    FORMAT A12
COLUMN email        FORMAT A30

CLEAR SCREEN


