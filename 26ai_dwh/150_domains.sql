SET ECHO OFF
REM ***************************************************************************
REM ******** Oracle AI Database 26ai New Features for Data Warehouses *********
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 150_domains.sql
REM Author......: Andrej Pashchenko
REM Description.: Data Usage Domains in Oracle 26ai
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ***************************************************************************

@define.sql
CONNECT &_onf_user./&_onf_password.@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 100 LINESIZE 200

CLEAR SCREEN

column DOMAIN_NAME_EMAIL format a27
column email format a20
column cust_id format a7
column DOMAIN_DISPLAY_EMAIL format a18
column DOMAIN_ORDER_EMAIL format a18
column DOMAIN_CHECK_EMAIL format a18
column domain_name_tstp format a30 
column domain_name_address format a20
column domain_display_address format a45
column schema_domain format a80

set linesize 120
set echo on
  
PURGE RECYCLEBIN;

DROP TABLE IF EXISTS addresses cascade constraint purge;

DROP TABLE IF EXISTS customers CASCADE CONSTRAINTS PURGE;


DROP DOMAIN IF EXISTS dom_email FORCE;

CREATE DOMAIN IF NOT EXISTS dom_email
AS VARCHAR2(254)
CONSTRAINT C_EMAIL_CHK 
CHECK (regexp_like( DOM_EMAIL, '^(\S{1,64})@([a-z0-9-]+)\.([a-z]{2,63})$') 
       and DOM_EMAIL = lower(DOM_EMAIL)
       )
DISPLAY '---'||regexp_substr(DOM_EMAIL,'@.*')
ORDER  regexp_substr(DOM_EMAIL,'[^@]+$')||':'||regexp_substr(DOM_EMAIL,'^[^@]+');

pause

DROP DOMAIN IF EXISTS dom_dml_timestamp;

CREATE DOMAIN IF NOT EXISTS dom_dml_timestamp AS TIMESTAMP 
DEFAULT ON NULL FOR INSERT AND UPDATE systimestamp;

Pause 

DROP TABLE IF EXISTS addresses_json PURGE;

DROP DOMAIN IF EXISTS dom_adr_json;

CREATE DOMAIN IF NOT EXISTS dom_adr_json AS 
JSON VALIDATE '{
  "type"       : "object",
  "properties" : {"addresskey"  :{"type":"integer", "minimum": 1},
                  "addressLine1":{"type":"string",  "maxLength" : 100  },
                  "addressLine2":{"type":"string",  "maxLength" : 100  },       
                  "postalCode"  :{"type":"string",  "maxLength" : 10  },                
                  "city"        :{"type":"string",  "maxLength" : 50  }, 
                  "country"     :{"type":"string",  "minLength" : 2, "maxLength" : 2, "pattern":"[A-Z]{2}"  }, 
                  "lastChange"   :{"type":"string", "format":"date-time" }  },
  "required"   : ["addresskey", "addressLine1", "postalCode", "country"]
  }';

CREATE TABLE IF NOT EXISTS addresses_json
(docid NUMBER PRIMARY KEY,
 jsondoc dom_adr_json 
 );


  
pause

DROP DOMAIN IF EXISTS DOM_ADDRESS;

DROP DOMAIN IF EXISTS DOM_ADDRESS_ALL;
DROP DOMAIN IF EXISTS DOM_ADDRESS_DE;
DROP DOMAIN IF EXISTS DOM_ADDRESS_US;


-- create multi-column domain for address
pause

CREATE DOMAIN IF NOT EXISTS  DOM_ADDRESS_ALL AS (
 address_line_1    AS VARCHAR2(100),
 postal_code       AS VARCHAR2(10),
 city              AS VARCHAR2(50) ,
 state_province    AS VARCHAR2(100)
 )
CONSTRAINT C_ADDRESS_CHK_ALL CHECK ( address_line_1 IS NOT NULL 
                                AND postal_code IS NOT NULL
                                AND city IS NOT NULL
                                )
 DISPLAY  address_line_1||', '||postal_code||' '||city ||' '|| state_province   
 ORDER postal_code 
 ;

-- create multi-column domain for DE-address
CREATE DOMAIN IF NOT EXISTS  DOM_ADDRESS_DE AS (
 address_line_1    AS VARCHAR2(100),
 postal_code       AS VARCHAR2(10),
 city              AS VARCHAR2(50) ,
 state_province    AS VARCHAR2(100)
 )
CONSTRAINT C_ADDRESS_CHK_DE CHECK ( address_line_1 IS NOT NULL 
                                AND length(postal_code) = 5 AND REGEXP_LIKE(postal_code, '^[0-9]{5}$') 
                                AND city IS NOT NULL
                                AND state_province IS NOT NULL
                                )
DISPLAY  address_line_1||', '||postal_code||' '||city ||' '|| state_province    
ORDER postal_code                                 ;

-- create multi-column domain for US-address
pause                                

CREATE DOMAIN IF NOT EXISTS  DOM_ADDRESS_US AS (
 address_line_1    AS VARCHAR2(100),
 postal_code       AS VARCHAR2(10),
 city              AS VARCHAR2(50) ,
 state_province    AS VARCHAR2(100)
 )
CONSTRAINT C_ADDRESS_CHK_US CHECK ( address_line_1 IS NOT NULL 
                                AND (length(postal_code) = 5 or length(postal_code)=9)
                                AND city IS NOT NULL
                                AND state_province IS NOT NULL
                                )
DISPLAY  address_line_1||', '||city ||' '|| state_province||' '||postal_code  
ORDER postal_code ;


-- create flexible domain
pause

CREATE FLEXIBLE DOMAIN dom_address (address_line_1, postal_code, city, state_province)
CHOOSE DOMAIN USING (country varchar2(2))
FROM CASE
       WHEN country in ('DE') then dom_address_de(address_line_1, postal_code, city, state_province)
       WHEN country in ('US') then dom_address_us(address_line_1, postal_code, city, state_province)
       ELSE dom_address_all(address_line_1, postal_code, city, state_province)
END;

pause

CREATE TABLE IF NOT EXISTS addresses
(address_id         NUMBER PRIMARY KEY,
 address_line_1     VARCHAR2(100),
 postal_code        VARCHAR2(10),
 city               VARCHAR2(50),
 state_province     VARCHAR2(100),
 country            VARCHAR2(2),
 last_change        DOMAIN dom_dml_timestamp,
 DOMAIN             dom_address (address_line_1, postal_code, city, state_province) 
    USING (country)
 );


insert into addresses (address_id, address_line_1,postal_code, city, state_province, country  ) 
values 
(1, 'Tempelhofer Weg 64', '12347', 'Berlin', 'Berlin', 'DE') ,
(2, 'Berlinerplatz 1', '41061', 'M�nchengladbach', 'NRW', 'DE') ,
(3, '395 9th Ave', '10001', 'New York', 'NY', 'US') ;


-- example
pause


select  domain_name(last_change) domain_name_tstp, 
        domain_name(address_line_1, postal_code, city, state_province, country) domain_name_address,
        domain_display(address_line_1, postal_code, city, state_province, country)  domain_display_address
from    addresses;

pause

CREATE TABLE IF NOT EXISTS customers (
 cust_id 		NUMBER PRIMARY KEY,
 first_name 	VARCHAR2(100),
 last_name 		VARCHAR2(100),
 email     		VARCHAR2(300) 
				DOMAIN dom_email,
 last_upd	    TIMESTAMP 
				DOMAIN dom_dml_timestamp 
 ); 
 
INSERT INTO customers (cust_id, first_name, last_name, email ) 
VALUES (4711, 'Bruse', 'Scott', 'scott@oracle.com');

select domain_check(dom_email, cast('scott@oracle.com' as dom_email) );



SELECT cust_id
,      DOMAIN_NAME(email) domain_name_email
,      email
,      DOMAIN_DISPLAY(email) domain_display_email
,      DOMAIN_ORDER(email)  domain_order_email
,      DOMAIN_CHECK(dom_email,email) domain_check_email
FROM   customers
ORDER BY DOMAIN_ORDER(email);




-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT