SET ECHO OFF
REM ***************************************************************************
REM ********** Oracle AI Database 26ai New Features for Developers ************
REM ***************************************************************************
REM File name...: 240_json_load.sql
REM Author......: Andrej Pashchenko, ACN
REM Description.: JSONL, JSON documents and array-to-row mapping
REM Requirements: Oracle AI Database 26ai; EXT_TAB_DIR with the files below
REM Files.......: countries_jsonl.json, countries_array.json
REM More examples: 241_json_load_more.sql (LOBFILE, JSON target, other layouts)
REM ***************************************************************************
@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service
SET ECHO ON TERMOUT ON PAGESIZE 100 LINESIZE 160
COLUMN country FORMAT A40
COLUMN first_country FORMAT A40

CLEAR SCREEN
-- 1. JSONL: one document per physical line works with ORACLE_LOADER.
-- Record boundaries in this configuration are newlines, not JSON structure.
DROP TABLE IF EXISTS countries_jsonl PURGE;
CREATE TABLE countries_jsonl (clob_content CLOB)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER
  DEFAULT DIRECTORY ext_tab_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    FIELDS (clob_content CHAR(100000))
  )
  LOCATION ('countries_jsonl.json')
)
REJECT LIMIT UNLIMITED

PAUSE Press Enter to create the JSONL external table
/

SELECT COUNT(*) AS document_rows FROM countries_jsonl;

SELECT JSON_VALUE(a.clob_content, '$.name.common') AS country
FROM countries_jsonl a
ORDER BY country
FETCH FIRST 5 ROWS ONLY;
PAUSE Press Enter for the array file

-- The supplied JSONL file has 250 countries; the array file has five.
-- 2. ORACLE_BIGDATA reads the JSON structure, including multiline documents.
-- The default path is $: the entire array is ONE JSON value in ONE row.
-- Text is parsed and converted to native binary JSON (OSON) during the query.

DROP TABLE IF EXISTS countries_array PURGE;
CREATE TABLE countries_array (json_content JSON)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_BIGDATA
  DEFAULT DIRECTORY ext_tab_dir
  ACCESS PARAMETERS (com.oracle.bigdata.fileformat = jsondoc)
  LOCATION ('countries_array.json')
)
REJECT LIMIT UNLIMITED

PAUSE Press Enter to read the entire array as one document
/
SELECT COUNT(*) AS document_rows FROM countries_array;
SELECT JSON_VALUE(a.json_content, '$[0].name.common') AS first_country
FROM countries_array a;
PAUSE Press Enter to map array elements to rows

-- 3. Same file, but $[*] maps each country to its own external-table row.
DROP TABLE IF EXISTS countries_array PURGE;
CREATE TABLE countries_array (json_content JSON)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_BIGDATA
  DEFAULT DIRECTORY ext_tab_dir
  ACCESS PARAMETERS (
    com.oracle.bigdata.fileformat = jsondoc
    com.oracle.bigdata.json.path = '$[*]'
  )
  LOCATION ('countries_array.json')
)
REJECT LIMIT UNLIMITED

PAUSE Press Enter to create the array-element mapping
/
SELECT COUNT(*) AS country_rows FROM countries_array;

SELECT JSON_VALUE(a.json_content, '$.name.common') AS country
FROM countries_array a
ORDER BY country
FETCH FIRST 5 ROWS ONLY;

PAUSE Press Enter to finish

DROP TABLE IF EXISTS countries_jsonl PURGE;
DROP TABLE IF EXISTS countries_array PURGE;

EXIT

