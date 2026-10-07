SET ECHO OFF
REM ***************************************************************************
REM ********** Oracle AI Database 26ai New Features for Developers ************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 290_json_schema.sql
REM Author......: Andrej Pashchenko, ACN
REM Description.: JSON Schema validation
REM Dependencies: uses define.sql
REM Requirements: Oracle Database 26ai
REM ---------------------------------------------------------------------------
REM 15.07.2026    apa    created
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


--SET SQLFORMAT DEFAULT
set lines 500
set long 3000
set pages 1000
set echo on 
--column docid format a15
column schema_error format a80
column schema_dual format a80
column jsondoc format a80

DROP TABLE IF EXISTS addresses_json PURGE;


CREATE TABLE addresses_json
(docid NUMBER PRIMARY KEY,
 jsondoc JSON 
 );

-- Insert rows with JSON 
-- Using 23c table values constructor
PAUSE 

INSERT INTO addresses_json (docid, jsondoc)
VALUES 
(1,
'{
"addresskey":1,
"addressLine1":"Tempelhofer Weg 64",
"postalCode":"12347",
"city":"Berlin",
"stateProvince":"",
"country":"DE",
"lastChange":"2023-11-20 15:00:00.000"
}'
),
(2,
'{
"addresskey":2.1,
"addressLine2":"Messezentrum 1",
"postalCode":"90471",
"city":"Nürnberg",
"stateProvince":"",
"country":"01",
"lastChange":"20-23-15-20T28:66:00"
}'
);

-- Check the JSON validity using JSON schema
PAUSE 

-- Just first record selected  
SELECT docid, json_serialize(jsondoc pretty) jsondoc
FROM  addresses_json 
WHERE jsondoc IS JSON VALIDATE '{
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
  
  
-- Are there schema violations? Slide
PAUSE
  
  
select docid, dbms_json_schema.is_valid (json_data=>json_serialize(jsondoc),
json_schema=>'{
  "type"       : "object",
  "properties" : {"addresskey"  :{"type":"integer", "minimum": 1},
                  "addressLine1":{"type":"string",  "maxLength" : 100  },
                  "addressLine2":{"type":"string",  "maxLength" : 100  },       
                  "postalCode"  :{"type":"string",  "maxLength" : 10  },                
                  "city"        :{"type":"string",  "maxLength" : 50  }, 
                  "country"     :{"type":"string",  "minLength" : 2, "maxLength" : 2, "pattern":"[A-Z]{2}"  }, 
                  "lastChange"   :{"type":"string", "format":"date-time" }  },
  "required"   : ["addresskey", "addressLine1", "postalCode", "country"]
  }')  is_doc_valid
FROM  addresses_json;
  
  
-- Why there are schema violations?
PAUSE


select docid, json_serialize(dbms_json_schema.validate_report (json_data=>json_serialize(jsondoc),
json_schema=>'{
  "type"       : "object",
  "properties" : {"addresskey"  :{"type":"integer", "minimum": 1},
                  "addressLine1":{"type":"string",  "maxLength" : 100  },
                  "addressLine2":{"type":"string",  "maxLength" : 100  },       
                  "postalCode"  :{"type":"string",  "maxLength" : 10  },                
                  "city"        :{"type":"string",  "maxLength" : 50  }, 
                  "country"     :{"type":"string",  "minLength" : 2, "maxLength" : 2, "pattern":"[A-Z]{2}"  }, 
                  "lastChange"   :{"type":"string", "format":"date-time" }  },
  "required"   : ["addresskey", "addressLine1", "postalCode", "country"]
  }') pretty) schema_error
FROM  addresses_json;

-- Correct the data and then re-check: both documents are now valid
PAUSE

rollback;


INSERT INTO addresses_json (docid, jsondoc)
VALUES 
(1,
'{
"addresskey":1,
"addressLine1":"Tempelhofer Weg 64",
"postalCode":"12347",
"city":"Berlin",
"stateProvince":"",
"country":"DE",
"lastChange":"2023-11-20T15:00:00.000"
}'
),
(2,
'{
"addresskey":2,
"addressLine1":"Messezentrum 1",
"postalCode":"90471",
"city":"Nürnberg",
"stateProvince":"",
"country":"DE",
"lastChange":"2023-12-20T01:36:00"
}'
);

-- Re-check
PAUSE

select docid, json_serialize(dbms_json_schema.validate_report (json_data=>json_serialize(jsondoc),
json_schema=>'{
  "type"       : "object",
  "properties" : {"addresskey"  :{"type":"integer", "minimum": 1},
                  "addressLine1":{"type":"string",  "maxLength" : 100  },
                  "addressLine2":{"type":"string",  "maxLength" : 100  },       
                  "postalCode"  :{"type":"string",  "maxLength" : 10  },                
                  "city"        :{"type":"string",  "maxLength" : 50  }, 
                  "country"     :{"type":"string",  "minLength" : 2, "maxLength" : 2, "pattern":"[A-Z]{2}"  }, 
                  "lastChange"   :{"type":"string", "format":"date-time" }  },
  "required"   : ["addresskey", "addressLine1", "postalCode", "country"]
  }') pretty) schema_error
FROM  addresses_json;

-- what is the datatype of lastChange?
select a.jsondoc.lastChange.type() from addresses_json a;

rollback;

-- Is the JSON schema itself valid?
pause

select dbms_json_schema.is_schema_valid (
'{
  "type"       : "object",
  "properties" : {"addresskey"  :{"type":"integer", "minimum": 1},
                  "addressLine1":{"type":"string",  "maxLength" : 100  },
                  "addressLine2":{"type":"string",  "maxLength" : 100  },       
                  "postalCode"  :{"type":"string",  "maxLength" : 10  },                
                  "city"        :{"type":"string",  "maxLength" : 50  }, 
                  "country"     :{"type":"string",  "minLength" : 2, "maxLength" : 2, "pattern":"[A-Z]{2}"  }, 
                  "lastChange"   :{"type":"string", "format":"date-time" }  },
  "required"   : ["addresskey", "addressLine1", "postalCode", "country"]
  }') schema_valid
;


-- Create JSON-Schema for relational objects
PAUSE

SELECT json_serialize(dbms_json_schema.describe('DUAL','SYS') pretty) schema_dual;




--- VALIDATE with CAST to extended type
pause

DROP TABLE IF EXISTS addresses_json PURGE;


CREATE TABLE addresses_json
(docid NUMBER PRIMARY KEY,
 jsondoc JSON VALIDATE CAST '{
  "type"       : "object",
  "properties" : {"addresskey"  :{"type":"integer", "minimum": 1},
                  "addressLine1":{"type":"string",  "maxLength" : 100  },
                  "addressLine2":{"type":"string",  "maxLength" : 100  },       
                  "postalCode"  :{"type":"string",  "maxLength" : 10  },                
                  "city"        :{"type":"string",  "maxLength" : 50  }, 
                  "country"     :{"type":"string",  "minLength" : 2, "maxLength" : 2, "pattern":"[A-Z]{2}"  }, 
                  "lastChange"   :{"extendedType":"timestamp"}  },
  "required"   : ["addresskey", "addressLine1", "postalCode", "country"]
  }'
 );

-- Insert rows with JSON 
-- Using 23c table values constructor
PAUSE 

INSERT INTO addresses_json (docid, jsondoc)
VALUES 
(2,
'{
"addresskey":2,
"addressLine1":"Messezentrum 1",
"postalCode":"90471",
"city":"Nürnberg",
"stateProvince":"",
"country":"DE",
"lastChange":"20-23-15-20T28:66:00"
}'
);

-- check
pause

select json_serialize(dbms_json_schema.validate_report (json_data=>'{
"addresskey":2,
"addressLine1":"Messezentrum 1",
"postalCode":"90471",
"city":"Nürnberg",
"stateProvince":"",
"country":"DE",
"lastChange":"20-23-15-20T28:66:00"
}',
json_schema=>'{
   "type"       : "object",
  "properties" : {"addresskey"  :{"type":"integer", "minimum": 1},
                  "addressLine1":{"type":"string",  "maxLength" : 100  },
                  "addressLine2":{"type":"string",  "maxLength" : 100  },       
                  "postalCode"  :{"type":"string",  "maxLength" : 10  },                
                  "city"        :{"type":"string",  "maxLength" : 50  }, 
                  "country"     :{"type":"string",  "minLength" : 2, "maxLength" : 2, "pattern":"[A-Z]{2}"  }, 
                  "lastChange"   :{"extendedType":"timestamp"}  },
  "required"   : ["addresskey", "addressLine1", "postalCode", "country"]
  }') pretty) schema_error
;

-- correct and re-insert
pause

INSERT INTO addresses_json (docid, jsondoc)
VALUES 
(2,
'{
"addresskey":2,
"addressLine1":"Messezentrum 1",
"postalCode":"90471",
"city":"Nürnberg",
"stateProvince":"",
"country":"DE",
"lastChange":"2023-12-20T01:36:00"
}'
);


select a.jsondoc.lastChange.type() from addresses_json a;



-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE

DROP TABLE addresses_json PURGE;

EXIT
