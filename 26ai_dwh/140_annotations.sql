SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 140_annotations.sql
REM Author......: Andrej Pashchenko
REM Description.: Schema annotations in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 120

column object_name      format a18
column object_type      format a10
column column_name      format a12
column domain_name      format a15
column DOMAIN_OWNER     format a10
column annotation_name  format a15
column annotation_value format a20

CLEAR SCREEN

-------------------------------------------------------------------------------
--    Annotations are metadata attached to schema objects in the DDL.
--    A name alone (flag) or a name + value pair are both valid forms.
--    The database stores them; applications and tooling interpret them.
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS customers CASCADE CONSTRAINTS PURGE;

CREATE TABLE customers (
  cust_id    NUMBER PRIMARY KEY,
  first_name VARCHAR2(100)
             ANNOTATIONS (pii, description 'First Name'),
  last_name  VARCHAR2(100)
             ANNOTATIONS (pii, description 'Last Name'),
  email      VARCHAR2(300)
             DOMAIN dom_email
             ANNOTATIONS (pii, masked, description 'Email'),
  last_upd   TIMESTAMP
             DOMAIN dom_dml_timestamp
)
ANNOTATIONS (contains_pii, responsible 'B.Scott', version '1.0.7');

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--    Dictionary views: query what was stored
--    _ANNOTATIONS       - annotation names per object
--    _ANNOTATION_VALUES - name + value pairs
--    _ANNOTATIONS_USAGE - full context: object, column, annotation
-------------------------------------------------------------------------------

SELECT annotation_name
FROM   user_annotations;

SELECT *
FROM   user_annotation_values;

SELECT *
FROM   user_annotations_usage;

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--    Practical use: find all tables carrying a PII annotation as JSON
-------------------------------------------------------------------------------

SELECT JSON_ARRAYAGG(JSON_OBJECT(au.*))
FROM   user_annotations_usage au
WHERE  annotation_name = 'PII'
AND    object_type     = 'TABLE';

pause Press Enter TO CONTINUE

-------------------------------------------------------------------------------
--    Manage annotations with ALTER - multiple operations in one DDL statement
-------------------------------------------------------------------------------

-- Add multiple annotations at once
ALTER DOMAIN dom_email ANNOTATIONS (pii, description 'Email', masked);

-- Drop a single annotation
ALTER DOMAIN dom_email ANNOTATIONS (DROP pii);

-- Idempotent: ADD IF NOT EXISTS / DROP IF EXISTS - safe for repeated scripts
ALTER DOMAIN dom_email ANNOTATIONS (ADD IF NOT EXISTS pii,
                                    DROP IF EXISTS masked);

-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE

EXIT
