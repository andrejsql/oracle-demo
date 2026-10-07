SET ECHO OFF
REM ***************************************************************************
REM ********** Oracle AI Database 26ai New Features for Developers ************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 241_json_load_more.sql
REM Author......: Andrej Pashchenko, ACN
REM Description.: Loading JSON documents through external table
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

REM ===========================================================================
REM Connect
REM ===========================================================================
@define.sql

CONNECT &_onf_user./&_onf_password.@&_sid_or_service 

REM ===========================================================================
REM Formatting
REM ===========================================================================
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200





CLEAR SCREEN

DROP TABLE IF EXISTS countries_jsonl PURGE;

-- JSONL files can be easily loaded into Oracle Database using external tables. 
-- The following example shows how to access a JSONL file using an external table 
-- the target column is CLOB

CREATE TABLE countries_jsonl (
  clob_content clob
  )
ORGANIZATION EXTERNAL (
   TYPE ORACLE_LOADER 
   DEFAULT DIRECTORY ext_tab_dir
   ACCESS PARAMETERS (
     RECORDS DELIMITED BY NEWLINE
     FIELDS   ( clob_content CHAR(4000)  )
      )   
LOCATION ('countries_jsonl.json')
 )
REJECT LIMIT UNLIMITED
 
pause
/

-- each document in the JSONL file is a separate row in the external table. 
SELECT * 
FROM   countries_jsonl
FETCH FIRST 5 ROWS ONLY
 
pause
/
pause
 

DROP TABLE IF EXISTS countries_jsonl PURGE;

-- this example shows how to access a JSONL file using an external table the target column is JSON

CREATE TABLE countries_jsonl (
  json_content json
  )
ORGANIZATION EXTERNAL (
   TYPE ORACLE_LOADER 
   DEFAULT DIRECTORY ext_tab_dir
   ACCESS PARAMETERS (
     RECORDS DELIMITED BY NEWLINE
     FIELDS   (json_content CHAR(4000)  )
      )   
LOCATION ('countries_jsonl.json')
 )
REJECT LIMIT UNLIMITED
 
pause
/

-- Each document in the JSONL file is a separate row in the external table.
-- But the target column is JSON, so the database will validate each document and reject any invalid JSON documents.
-- The database parses the JSON documents and converts them to native binary JSON (OSON) during the query - the original formatting is lost.
SELECT * 
FROM   countries_jsonl
FETCH FIRST 5 ROWS ONLY
/


-- Array

DROP TABLE IF EXISTS countries_array PURGE;
--
-- This configuration uses newline record boundaries, not JSON document boundaries.
--
CREATE TABLE countries_array (
  clob_content clob
  )
ORGANIZATION EXTERNAL (
   TYPE ORACLE_LOADER 
   DEFAULT DIRECTORY ext_tab_dir
   ACCESS PARAMETERS (
     FIELDS   ( clob_content CHAR(1000000)  )
      )   
LOCATION ('countries_array.json')
 )
REJECT LIMIT UNLIMITED
 
pause
/

--
-- each line is not a valid document in itself, we need a pre- or post-processing 
--
SELECT DBMS_LOB.getlength(a.clob_content) as len, a.* 
FROM   countries_array a
FETCH FIRST 5 ROWS ONLY
/
  
--
-- Workaround: use a helper file containing the filename(s) to load and use LOBFILE
--

DROP TABLE IF EXISTS countries_array PURGE;

CREATE TABLE countries_array (
  clob_content CLOB
  )
ORGANIZATION EXTERNAL (
   TYPE ORACLE_LOADER 
   DEFAULT DIRECTORY ext_tab_dir
   ACCESS PARAMETERS (
     FIELDS   ( filename CHAR(128)  )
      COLUMN TRANSFORMS (clob_content FROM lobfile (filename) FROM (ext_tab_dir) CLOB)
        )   
LOCATION ('json_files_to_load.txt')
 )
REJECT LIMIT UNLIMITED
 
pause
/

-- Now, the whole JSON document is in one row.
SELECT DBMS_LOB.getlength(a.clob_content) as len, a.* 
FROM   countries_array a
FETCH FIRST 5 ROWS ONLY
/

-------------------------------------------------------------------------------
--           Load JSON using ORACLE_BIGDATA driver (23/26ai)
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS countries_jsonl PURGE;


CREATE TABLE countries_jsonl (
  json_content JSON
  )
ORGANIZATION EXTERNAL (
   TYPE ORACLE_BIGDATA  
   DEFAULT DIRECTORY ext_tab_dir
   ACCESS PARAMETERS (com.oracle.bigdata.fileformat = jsondoc)
LOCATION ('countries_jsonl.json')
 )
REJECT LIMIT UNLIMITED
 
pause
/

--
-- each document in the JSONL file is a separate row in the external table. 
--
SELECT a.* 
FROM   countries_jsonl a
FETCH FIRST 5 ROWS ONLY
/

DROP TABLE IF EXISTS countries_array PURGE;


CREATE TABLE countries_array (
  json_content JSON
  )
ORGANIZATION EXTERNAL (
   TYPE ORACLE_BIGDATA  
   DEFAULT DIRECTORY ext_tab_dir
   ACCESS PARAMETERS (com.oracle.bigdata.fileformat = jsondoc)
LOCATION ('countries_array.json')
 )
REJECT LIMIT UNLIMITED
 
pause
/

--
-- The entire array is one JSON value in one external-table row.
-- Use $[*] in the following example to return one row per array element.
SELECT a.* 
FROM   countries_array a
FETCH FIRST 5 ROWS ONLY
/


--
-- Using inline external table definition  
-- Each array element is a separate row in the external table.
--
SELECT a.*
FROM EXTERNAL
     (
       (
         json_content JSON
       )
       TYPE ORACLE_BIGDATA
       DEFAULT DIRECTORY ext_tab_dir
       ACCESS PARAMETERS
       (
         com.oracle.bigdata.fileformat = jsondoc
         com.oracle.bigdata.json.path  = '$[*]'
       )
       LOCATION ('countries_array.json')
       REJECT LIMIT UNLIMITED
     ) a
FETCH FIRST 5 ROWS ONLY
 
pause
/


--
-- Using inline external table definition  
-- Each array element is a separate row in the external table.
--
SELECT a.*
FROM EXTERNAL
     (
       (
         json_content JSON
       )
       TYPE ORACLE_BIGDATA
       DEFAULT DIRECTORY ext_tab_dir
       ACCESS PARAMETERS
       (
         com.oracle.bigdata.fileformat = jsondoc
         com.oracle.bigdata.json.path  = '$[*].languages'
       )
       LOCATION ('countries_array.json')
       REJECT LIMIT UNLIMITED
     ) a
FETCH FIRST 5 ROWS ONLY
 
pause
/


--
-- Using inline external table definition  
-- Loading multiline JSON documents from multiple files.
--
SELECT a.*
FROM EXTERNAL
     (
       (
         json_content JSON
       )
       TYPE ORACLE_BIGDATA
       DEFAULT DIRECTORY ext_tab_dir
       ACCESS PARAMETERS
       (
         com.oracle.bigdata.fileformat = jsondoc
       )
       LOCATION ('countries_file*.json')
       REJECT LIMIT UNLIMITED
     ) a
FETCH FIRST 5 ROWS ONLY
 
pause
/

--
-- Using inline external table definition  
-- The file contains multiple multi-line JSON documents. 
--
SELECT a.*
FROM EXTERNAL
     (
       (
         json_content JSON
       )
       TYPE ORACLE_BIGDATA
       DEFAULT DIRECTORY ext_tab_dir
       ACCESS PARAMETERS
       (
         com.oracle.bigdata.fileformat = jsondoc
       )
       LOCATION ('countries_multiline.json')
       REJECT LIMIT UNLIMITED
     ) a
FETCH FIRST 5 ROWS ONLY
 
pause
/



-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE

DROP TABLE IF EXISTS countries_jsonl PURGE;
DROP TABLE IF EXISTS countries_array PURGE;
EXIT

