SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Show configured AI profile and credential names.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

COLUMN profile_name FORMAT A30
COLUMN attribute_name FORMAT A25
COLUMN attribute_value FORMAT A65
SELECT profile_name, attribute_name, attribute_value
FROM user_cloud_ai_profile_attributes
WHERE profile_name = UPPER('&_AIPROFILE')
ORDER BY attribute_name;
SELECT credential_name FROM user_credentials
WHERE credential_name IN ('OCI_GENAI_CRED_VEC', 'OPENAI_CRED', 'EMAIL_CRED')
ORDER BY credential_name;

PAUSE Review the results, then press Enter to close this window.
EXIT
