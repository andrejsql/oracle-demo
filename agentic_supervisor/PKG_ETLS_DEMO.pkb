CREATE OR REPLACE PACKAGE BODY pkg_etls_demo AS
  FUNCTION fetch_batch RETURN CLOB IS
    l_start NUMBER;
    l_end NUMBER;
    l_count NUMBER;
    l_logs CLOB;
    l_result CLOB;
  BEGIN
    SELECT last_log_id INTO l_start FROM etls_checkpoint WHERE singleton = 1;
    SELECT JSON_ARRAYAGG(
             JSON_OBJECT('log_id' VALUE log_id, 'job_name' VALUE job_name,
                         'message' VALUE message RETURNING CLOB)
             ORDER BY log_id RETURNING CLOB),
           COUNT(*), MAX(log_id)
      INTO l_logs, l_count, l_end
      FROM (SELECT log_id, job_name, message FROM etls_job_log
            WHERE log_id > l_start ORDER BY log_id FETCH FIRST 3 ROWS ONLY);
    SELECT JSON_OBJECT(
      'status' VALUE CASE WHEN l_count = 0 THEN 'NO_NEW_LOG' ELSE 'OK' END,
      'start_log_id' VALUE l_start, 'end_log_id' VALUE NVL(l_end, l_start),
      'count' VALUE l_count, 'logs' VALUE NVL(l_logs, TO_CLOB('[]')) FORMAT JSON
      RETURNING CLOB)
      INTO l_result FROM dual;
    RETURN l_result;
  END;

  FUNCTION embed_text(p_text IN VARCHAR2) RETURN VECTOR IS
  BEGIN
    RETURN dbms_vector_chain.utl_to_embedding(
      p_text,
      JSON('{
        "provider":"ocigenai",
        "credential_name":"OCI_GENAI_CRED_VEC",
        "url":"https://inference.generativeai.eu-frankfurt-1.oci.oraclecloud.com/20231130/actions/embedText",
        "model":"cohere.embed-v4.0"
      }'));
  END;

  FUNCTION search_kb(p_query IN VARCHAR2) RETURN CLOB IS
    l_vector VECTOR;
    l_code VARCHAR2(20);
    l_hits CLOB;
    l_count NUMBER;
    l_error VARCHAR2(4000);
    l_result CLOB;
  BEGIN
    l_vector := embed_text(p_query);
    l_code := REGEXP_SUBSTR(p_query, 'ORA-[0-9]{5}');
    SELECT JSON_ARRAYAGG(
             JSON_OBJECT('entry_id' VALUE entry_id, 'error_text' VALUE error_text,
                         'action' VALUE action, 'distance' VALUE distance
                         RETURNING CLOB)
             ORDER BY distance RETURNING CLOB),
           COUNT(*)
      INTO l_hits, l_count
      FROM (
        SELECT entry_id, error_text, action,
               VECTOR_DISTANCE(embedding, l_vector, COSINE) AS distance
          FROM etls_kb
         WHERE embedding IS NOT NULL
           AND (l_code IS NULL OR REGEXP_SUBSTR(error_text, 'ORA-[0-9]{5}') = l_code)
           AND VECTOR_DISTANCE(embedding, l_vector, COSINE) <= 0.25
         ORDER BY distance FETCH FIRST 3 ROWS ONLY
      );
    SELECT JSON_OBJECT(
      'status' VALUE CASE WHEN l_count = 0 THEN 'NO_HITS' ELSE 'OK' END,
      'hits_count' VALUE l_count,
      'hits' VALUE NVL(l_hits, TO_CLOB('[]')) FORMAT JSON RETURNING CLOB)
      INTO l_result FROM dual;
    RETURN l_result;
  EXCEPTION WHEN OTHERS THEN
    l_error := SQLERRM;
    SELECT JSON_OBJECT('status' VALUE 'ERROR', 'error' VALUE l_error RETURNING CLOB)
      INTO l_result FROM dual;
    RETURN l_result;
  END;

  FUNCTION restart_job(p_log_id IN NUMBER) RETURN CLOB IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_job etls_job_log.job_name%TYPE;
    l_result CLOB;
  BEGIN
    SELECT job_name INTO l_job FROM etls_job_log WHERE log_id = p_log_id;
    -- Deliberately simulated, just as in the sequential demo.
    SELECT JSON_OBJECT('status' VALUE 'SUCCESS', 'simulated' VALUE 'true' FORMAT JSON,
                            'log_id' VALUE p_log_id, 'job_name' VALUE l_job,
                       'action' VALUE 'RESTART_ETL_JOB' RETURNING CLOB)
      INTO l_result FROM dual;
    INSERT INTO etls_action_log(log_id, action, result)
      VALUES(p_log_id, 'RESTART_ETL_JOB', l_result);
    COMMIT;
    RETURN l_result;
  EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
  END;

  FUNCTION store_experience(p_log_id IN NUMBER, p_action IN VARCHAR2) RETURN CLOB IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_message etls_job_log.message%TYPE;
    l_vector VECTOR;
    l_id NUMBER;
    l_result CLOB;
  BEGIN
    IF p_action IS NULL OR p_action NOT IN ('RESTART_ETL_JOB', 'NOTIFY_DB_OPS') THEN
      RETURN '{"status":"SKIPPED"}';
    END IF;
    SELECT message INTO l_message FROM etls_job_log WHERE log_id = p_log_id;
    l_vector := embed_text(l_message);
    INSERT INTO etls_kb(source_log_id, error_text, action, embedding)
      VALUES(p_log_id, l_message, p_action, l_vector)
      RETURNING entry_id INTO l_id;
    COMMIT;
    SELECT JSON_OBJECT('status' VALUE 'STORED', 'entry_id' VALUE l_id RETURNING CLOB)
      INTO l_result FROM dual;
    RETURN l_result;
  EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
  END;

  FUNCTION finish_batch(p_end_log_id IN NUMBER) RETURN CLOB IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_result CLOB;
  BEGIN
    UPDATE etls_checkpoint
       SET last_log_id = GREATEST(last_log_id, p_end_log_id)
     WHERE singleton = 1;
    COMMIT;
    SELECT JSON_OBJECT('status' VALUE 'SUCCESS',
                       'last_log_id' VALUE p_end_log_id RETURNING CLOB)
      INTO l_result FROM dual;
    RETURN l_result;
  END;
END pkg_etls_demo;
/
