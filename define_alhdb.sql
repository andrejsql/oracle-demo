SET ECHO OFF

SET TERMOUT OFF ECHO OFF

REM ***************************************************************************
REM Privileges..: None
REM File name...: define_alhdb.sql
REM Description.: Defines the users and passwords used in the example scripts
REM ***************************************************************************

REM CLEAR SCREEN

REM ===========================================================================
REM Substition variables to be changed for right environment
REM Please ammend for your environment
REM ===========================================================================

DEFINE _sid_or_service = etl_ops_alhdb

REM define _AIPROFILE='ETL_OPS_OCI_GPT_OSS120'

define _AIPROFILE='GOOGLE'

DEFINE _service = FREEPDB1

DEFINE _sid_or_service_cdb = FREE
DEFINE _service_cdb = FREE



DEFINE _hr_user = hr
DEFINE _hr_password = hr

DEFINE _sh_user = sh
DEFINE _sh_password = sh





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


