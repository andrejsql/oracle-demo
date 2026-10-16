CREATE OR REPLACE PACKAGE BODY ETL_OPS.pkg_etl_ops_agent AS



procedure log (p_message in clob)  is
pragma autonomous_transaction;
begin
   insert into tool_calls (call_tstp, message) values (systimestamp, p_message);
   commit; 
end;

FUNCTION retrieve_logs(p_start_date IN DATE) RETURN CLOB IS
pragma autonomous_transaction;
  l_logs CLOB;
BEGIN
  insert into tool_calls(call_tstp)  values (systimestamp);
  commit;
  
  SELECT JSON_ARRAYAGG(JSON_OBJECT(*))
  INTO l_logs 
    FROM etl_job_log l
  WHERE log_timestamp >= p_start_date
   ORDER BY log_timestamp;

  RETURN l_logs;
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'Error fetching logs: ' || SQLERRM;
END retrieve_logs;


FUNCTION retrieve_next_log_record(p_start_log_id IN NUMBER) RETURN CLOB IS
pragma autonomous_transaction;
  l_logs CLOB;
BEGIN
 
  SELECT JSON_OBJECT(*)
  INTO l_logs 
    FROM etl_job_log l
  WHERE log_id > p_start_log_id
   ORDER BY log_id
  FETCH NEXT 1 ROWS ONLY;

  RETURN l_logs;
  
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 'No more unprocessed log records';

  WHEN OTHERS THEN
    RETURN 'Error fetching logs: ' || SQLERRM;
END retrieve_next_log_record;


FUNCTION restart_etl_job (p_job_name IN VARCHAR2) return CLOB IS
BEGIN
  RETURN 'ETL Job '||p_job_name ||' was successfully restarted.'; 
END;

FUNCTION get_last_processed_log_id return number IS
pragma autonomous_transaction;
v_last_log_id NUMBER := 0;
BEGIN
  insert into tool_calls (call_tstp, message) values (systimestamp, 'get_last_processed_log_id');
  commit;
  select s.last_log_id_processed
  into  v_last_log_id   
  from   etl_log_settings s;    
  return v_last_log_id;
exception
when others then 
  return v_last_log_id;
END;


FUNCTION set_last_processed_log_id (p_log_id IN NUMBER) return varchar2 IS
pragma autonomous_transaction;
BEGIN

  merge into etl_log_settings t
  using (select  p_log_id as log_id from dual) q
  on (t.rowid is not null)
  when matched then update 
    set    last_log_id_processed = q.log_id
  when not matched then insert (last_read_date, last_log_id_processed) 
                    values (sysdate, q.log_id)    ;  
  commit;
  return 'Last log read date has been set successfully';
exception
when others then 
  return 'Error seeting the last log read date '||sqlerrm;
END;



FUNCTION etl_embed_text(p_text IN CLOB) RETURN VECTOR
IS
  v VECTOR;
BEGIN
    v := dbms_vector_chain.utl_to_embedding(
            p_text,
            JSON('{
                "provider":"ocigenai",
                "credential_name":"OCI_GENAI_CRED_VEC",
                "url":"https://inference.generativeai.eu-frankfurt-1.oci.oraclecloud.com/20231130/actions/embedText",
                "model":"cohere.embed-v4.0"
            }') 
            ); 
  RETURN v; 
END;


FUNCTION etl_diy_rag_search(
  p_query     IN VARCHAR2
, p_top_k     IN NUMBER DEFAULT 5
, p_max_dist  IN NUMBER DEFAULT 0.25
) RETURN CLOB
IS
  l_query_vec VECTOR;
  l_context   CLOB := '';
  l_hits      PLS_INTEGER := 0;
  l_best_dist NUMBER;
  l_ora_code  VARCHAR2(20);
  l_msg       VARCHAR2(500);
BEGIN
  l_query_vec := etl_embed_text(p_query);
  log(p_query);
  IF l_query_vec IS NULL THEN
    RETURN JSON_OBJECT('status' VALUE 'NO_HITS'
                     , 'hits_count' VALUE 0
                     , 'context_text' VALUE ''
                     , 'notes' VALUE 'Embeddings not available (query embedding is NULL). Proceed without KB.');
  END IF;
  l_ora_code := REGEXP_SUBSTR(p_query, 'ORA-\d{5}');
  SELECT MIN(VECTOR_DISTANCE(embedding, l_query_vec, COSINE))
    INTO l_best_dist
    FROM etl_kb_entries
   WHERE embedding IS NOT NULL
     AND (l_ora_code IS NULL OR REGEXP_SUBSTR(error_signature, 'ORA-\d{5}') = l_ora_code);
  IF l_best_dist IS NULL OR l_best_dist > p_max_dist THEN
    RETURN JSON_OBJECT('status' VALUE 'NO_HITS'
                     , 'hits_count' VALUE 0
                     , 'context_text' VALUE ''
                     , 'notes' VALUE 'No sufficiently similar match (best_dist='||NVL(TO_CHAR(l_best_dist),'NULL')||', max_dist='||TO_CHAR(p_max_dist)||').');
  END IF;
  FOR r IN (
    SELECT entry_id
         , error_signature
         , error_text message
         , action_type
         , action_params_json
         , outcome
         , action_text
         , VECTOR_DISTANCE(embedding, l_query_vec, COSINE) AS dist
      FROM etl_kb_entries
     WHERE embedding IS NOT NULL
       AND VECTOR_DISTANCE(embedding, l_query_vec, COSINE) <= p_max_dist
       AND (l_ora_code IS NULL OR REGEXP_SUBSTR(error_signature, 'ORA-\d{5}') = l_ora_code)
     ORDER BY VECTOR_DISTANCE(embedding, l_query_vec, COSINE)
     FETCH FIRST p_top_k ROWS ONLY
  )
  LOOP
    l_hits := l_hits + 1;
    l_context := l_context||CHR(10)||'---'
                        ||CHR(10)||'KB_ENTRY_ID: '||r.entry_id
                        ||CHR(10)||'ERROR_SIGNATURE: '||NVL(r.error_signature,'')
                        ||CHR(10)||'DIST: '||TO_CHAR(r.dist)
                        ||CHR(10)||'MESSAGE: '||DBMS_LOB.SUBSTR(r.message, 1000, 1)
                        ||CHR(10)||'ACTION_TYPE: '||NVL(r.action_type,'')
                        ||CHR(10)||'ACTION_PARAMS_JSON: '||DBMS_LOB.SUBSTR(r.action_params_json, 1000, 1)
                        ||CHR(10)||'OUTCOME: '||NVL(r.outcome,'')
                        ||CHR(10)||'ACTION_TEXT: '||DBMS_LOB.SUBSTR(r.action_text, 1000, 1)
                        ||CHR(10);
  END LOOP;
  IF l_hits = 0 THEN
    RETURN JSON_OBJECT('status' VALUE 'NO_HITS'
                     , 'hits_count' VALUE 0
                     , 'context_text' VALUE ''
                     , 'notes' VALUE 'All candidates filtered out by distance threshold.');
  END IF;
  RETURN JSON_OBJECT('status' VALUE 'OK'
                   , 'hits_count' VALUE l_hits
                   , 'context_text' VALUE l_context
                   , 'notes' VALUE 'best_dist='||TO_CHAR(l_best_dist)||', max_dist='||TO_CHAR(p_max_dist));
EXCEPTION
  WHEN OTHERS THEN
    l_msg := SQLERRM;
    RETURN JSON_OBJECT('status' VALUE 'ERROR'
                     , 'hits_count' VALUE 0
                     , 'context_text' VALUE ''
                     , 'error' VALUE ('DIY_RAG_FAILED: '||l_msg));
END;



FUNCTION etl_kb_store(
  p_error_signature   IN VARCHAR2
, p_error_text        IN CLOB
, p_action_type       IN VARCHAR2
, p_action_params_json IN CLOB
, p_outcome           IN VARCHAR2
, p_action_text       IN CLOB
, p_kb_payload_json   IN CLOB
) RETURN CLOB
IS
  l_vec VECTOR;
  l_entry_id NUMBER;
  l_ora_code VARCHAR2(20);
BEGIN
  l_vec := etl_embed_text(DBMS_LOB.SUBSTR(p_error_text, 4000, 1));
  log(p_error_text);
  l_ora_code := REGEXP_SUBSTR(p_error_signature, 'ORA-\d{5}');
  INSERT INTO etl_kb_entries(
    error_signature
  , error_text
  , action_type
  , action_params_json
  , outcome
  , action_text
  , kb_payload_json
  , embedding
  ) VALUES (
    p_error_signature
  , p_error_text
  , p_action_type
  , p_action_params_json
  , p_outcome
  , p_action_text
  , p_kb_payload_json
  , l_vec
  )
  RETURNING entry_id INTO l_entry_id;
  COMMIT;
  RETURN JSON_OBJECT(
    'status' VALUE 'STORED'
  , 'entry_id' VALUE TO_CHAR(l_entry_id)
  , 'embedding_status' VALUE CASE WHEN l_vec IS NULL THEN 'NOT_EMBEDDED' ELSE 'EMBEDDED' END
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN JSON_OBJECT(
      'status' VALUE 'ERROR'
    , 'error' VALUE ('KB_STORE_FAILED: '||SQLERRM)
    );
END;

function etl_notification_stub (p_message in clob) return clob is
begin
   insert into tool_calls (call_tstp, message) values (systimestamp, p_message);
   commit; 
   return 'Notification has been sent successfully';
end;



END pkg_etl_ops_agent;
/
