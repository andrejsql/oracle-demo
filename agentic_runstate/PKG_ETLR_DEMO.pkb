CREATE OR REPLACE PACKAGE BODY pkg_etlr_demo AS
  -- State is authoritative for this run. Snapshots support inspection in a
  -- separate SQLcl window; they are never used to rehydrate framework state.
  FUNCTION state_object(p_name VARCHAR2) RETURN JSON_OBJECT_T IS
    l_value CLOB;
  BEGIN
    l_value := DBMS_CLOUD_AI_AGENT.GET_VARIABLE('state_variables', p_name);
    IF l_value IS NULL THEN
      RAISE_APPLICATION_ERROR(-20010, 'Missing run state: ' || p_name);
    END IF;
    RETURN JSON_OBJECT_T.parse(l_value);
  END;

  PROCEDURE snapshot(p_run_id VARCHAR2, p_name VARCHAR2, p_value CLOB) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    MERGE INTO etlr_state_snapshot d
    USING (SELECT p_run_id run_id, p_name variable_name FROM dual) s
    ON (d.run_id = s.run_id AND d.variable_name = s.variable_name)
    WHEN MATCHED THEN UPDATE SET value = p_value, updated_at = SYSTIMESTAMP
    WHEN NOT MATCHED THEN INSERT(run_id, variable_name, value)
      VALUES(p_run_id, p_name, p_value);
    COMMIT;
  EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
  END;

  PROCEDURE put_state(p_name VARCHAR2, p_value JSON_OBJECT_T) IS
    l_batch JSON_OBJECT_T;
    l_value CLOB;
  BEGIN
    l_value := p_value.to_clob();
    DBMS_CLOUD_AI_AGENT.SET_VARIABLE('state_variables', p_name, l_value);
    l_batch := state_object('batch');
    snapshot(l_batch.get_string('run_id'), p_name, l_value);
  END;

  FUNCTION incident(p_log_id NUMBER) RETURN JSON_OBJECT_T IS
    l_batch JSON_OBJECT_T;
    l_logs JSON_ARRAY_T;
    l_log JSON_OBJECT_T;
  BEGIN
    l_batch := state_object('batch');
    l_logs := l_batch.get_array('logs');
    IF l_logs.get_size() > 0 THEN
      FOR i IN 0 .. l_logs.get_size() - 1 LOOP
        l_log := TREAT(l_logs.get(i) AS JSON_OBJECT_T);
        IF l_log.get_number('log_id') = p_log_id THEN RETURN l_log; END IF;
      END LOOP;
    END IF;
    RAISE_APPLICATION_ERROR(-20011, 'Incident is not in this batch');
  END;

  FUNCTION id_key(p_log_id NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN TO_CHAR(p_log_id, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''');
  END;

  PROCEDURE check_action(p_action VARCHAR2) IS
  BEGIN
    IF p_action IS NULL OR p_action NOT IN
      ('RESTART_ETL_JOB', 'NOTIFY_DB_OPS', 'NONE') THEN
      RAISE_APPLICATION_ERROR(-20012, 'Invalid action');
    END IF;
  END;

  FUNCTION embed_text(p_text IN VARCHAR2) RETURN VECTOR IS
  BEGIN
    RETURN dbms_vector_chain.utl_to_embedding(p_text, JSON('{
      "provider":"ocigenai","credential_name":"OCI_GENAI_CRED_VEC",
      "url":"https://inference.generativeai.eu-frankfurt-1.oci.oraclecloud.com/20231130/actions/embedText",
      "model":"cohere.embed-v4.0"}'));
  END;

  FUNCTION fetch_batch RETURN CLOB IS
    l_start NUMBER;
    l_end NUMBER;
    l_count NUMBER;
    l_limit NUMBER;
    l_limit_text CLOB;
    l_logs CLOB;
    l_ids CLOB;
    l_json CLOB;
    l_batch JSON_OBJECT_T;
    l_empty JSON_OBJECT_T := JSON_OBJECT_T();
    l_manifest JSON_OBJECT_T;
  BEGIN
    -- A duplicate fetch must not replace a batch already in progress.
    IF DBMS_CLOUD_AI_AGENT.GET_VARIABLE('state_variables', 'batch') IS NOT NULL THEN
      l_batch := state_object('batch');
      l_manifest := l_batch.get_object('manifest');
      RETURN l_manifest.to_clob();
    END IF;
    l_limit_text := DBMS_CLOUD_AI_AGENT.GET_VARIABLE('instruction_variables', 'batch_limit');
    l_limit := TO_NUMBER(DBMS_LOB.SUBSTR(l_limit_text, 20, 1));
    IF l_limit IS NULL OR l_limit NOT BETWEEN 1 AND 3 OR l_limit <> TRUNC(l_limit) THEN
      RAISE_APPLICATION_ERROR(-20013, 'batch_limit must be an integer from 1 to 3');
    END IF;
    SELECT last_log_id INTO l_start FROM etlr_checkpoint WHERE singleton = 1;
    SELECT JSON_ARRAYAGG(JSON_OBJECT('log_id' VALUE log_id, 'job_name' VALUE job_name,
             'message' VALUE message RETURNING CLOB) ORDER BY log_id RETURNING CLOB),
           JSON_ARRAYAGG(log_id ORDER BY log_id RETURNING CLOB), COUNT(*), MAX(log_id)
      INTO l_logs, l_ids, l_count, l_end
      FROM (SELECT log_id, job_name, message FROM etlr_job_log
            WHERE log_id > l_start ORDER BY log_id FETCH FIRST l_limit ROWS ONLY);
    SELECT JSON_OBJECT('status' VALUE CASE WHEN l_count = 0 THEN 'NO_NEW_LOG' ELSE 'OK' END,
             'count' VALUE l_count, 'log_ids' VALUE NVL(l_ids, TO_CLOB('[]')) FORMAT JSON
             RETURNING CLOB) INTO l_json FROM dual;
    l_batch := JSON_OBJECT_T();
    l_batch.put('run_id', RAWTOHEX(SYS_GUID()));
    l_batch.put('start_log_id', l_start);
    l_batch.put('end_log_id', NVL(l_end, l_start));
    l_batch.put('logs', JSON_ARRAY_T.parse(NVL(l_logs, TO_CLOB('[]'))));
    l_batch.put('manifest', JSON_OBJECT_T.parse(l_json));
    put_state('batch', l_batch);
    put_state('resolutions', l_empty);
    put_state('decisions', l_empty);
    put_state('executions', l_empty);
    RETURN l_json;
  END;

  FUNCTION resolve_context(p_log_id IN NUMBER) RETURN CLOB IS
    l_log JSON_OBJECT_T;
    l_resolutions JSON_OBJECT_T;
    l_entry JSON_OBJECT_T;
    l_rag JSON_OBJECT_T;
    l_vector VECTOR;
    l_message VARCHAR2(4000);
    l_code VARCHAR2(20);
    l_hits CLOB;
    l_count NUMBER;
    l_json CLOB;
    l_error VARCHAR2(4000);
  BEGIN
    l_log := incident(p_log_id);
    l_resolutions := state_object('resolutions');
    IF l_resolutions.has(id_key(p_log_id)) THEN
      l_entry := l_resolutions.get_object(id_key(p_log_id));
      l_rag := l_entry.get_object('rag');
    ELSE
      l_message := l_log.get_string('message');
      l_code := REGEXP_SUBSTR(l_message, 'ORA-[0-9]{5}');
      BEGIN
        l_vector := embed_text(l_message);
        SELECT JSON_ARRAYAGG(JSON_OBJECT('entry_id' VALUE entry_id,
                 'error_text' VALUE error_text, 'action' VALUE action,
                 'distance' VALUE distance RETURNING CLOB) ORDER BY distance RETURNING CLOB),
               COUNT(*) INTO l_hits, l_count
          FROM (SELECT entry_id, error_text, action,
                       VECTOR_DISTANCE(embedding, l_vector, COSINE) distance
                  FROM etlr_kb WHERE embedding IS NOT NULL
                   AND (l_code IS NULL OR REGEXP_SUBSTR(error_text, 'ORA-[0-9]{5}') = l_code)
                   AND VECTOR_DISTANCE(embedding, l_vector, COSINE) <= 0.25
                 ORDER BY distance FETCH FIRST 3 ROWS ONLY);
        SELECT JSON_OBJECT('status' VALUE CASE WHEN l_count = 0 THEN 'NO_HITS' ELSE 'OK' END,
                 'hits' VALUE NVL(l_hits, TO_CLOB('[]')) FORMAT JSON RETURNING CLOB)
          INTO l_json FROM dual;
      EXCEPTION WHEN OTHERS THEN
        l_error := SQLERRM;
        SELECT JSON_OBJECT('status' VALUE 'ERROR', 'error' VALUE l_error,
                 'hits' VALUE '[]' FORMAT JSON RETURNING CLOB) INTO l_json FROM dual;
      END;
      l_rag := JSON_OBJECT_T.parse(l_json);
      l_entry := JSON_OBJECT_T();
      l_entry.put('rag', l_rag);
      l_resolutions.put(id_key(p_log_id), l_entry);
      put_state('resolutions', l_resolutions);
    END IF;
    -- Only this tool intentionally exposes an original incident and KB text.
    l_entry := JSON_OBJECT_T();
    l_entry.put('incident', l_log);
    l_entry.put('rag', l_rag);
    RETURN l_entry.to_clob();
  END;

  FUNCTION save_resolution(p_log_id IN NUMBER, p_decision IN VARCHAR2,
    p_action IN VARCHAR2, p_reason IN VARCHAR2) RETURN CLOB IS
    l_log JSON_OBJECT_T;
    l_resolutions JSON_OBJECT_T;
    l_entry JSON_OBJECT_T;
    l_rag JSON_OBJECT_T;
    l_hits JSON_ARRAY_T;
    l_hit JSON_OBJECT_T;
    l_decisions JSON_OBJECT_T;
    l_decision JSON_OBJECT_T;
    l_allowed BOOLEAN := FALSE;
    l_result CLOB;
  BEGIN
    l_log := incident(p_log_id);
    check_action(p_action);
    IF p_decision IS NULL OR p_decision NOT IN ('READY', 'NEEDS_HUMAN') OR p_reason IS NULL THEN
      RAISE_APPLICATION_ERROR(-20014, 'Decision and reason are required');
    END IF;
    l_resolutions := state_object('resolutions');
    IF NOT l_resolutions.has(id_key(p_log_id)) THEN
      RAISE_APPLICATION_ERROR(-20015, 'Read resolution context first');
    END IF;
    l_entry := l_resolutions.get_object(id_key(p_log_id));
    IF l_entry.has('decision') THEN
      IF l_entry.get_string('decision') <> p_decision OR l_entry.get_string('action') <> p_action THEN
        RAISE_APPLICATION_ERROR(-20016, 'Resolution already stored; cannot replace it');
      END IF;
    ELSE
      l_rag := l_entry.get_object('rag');
      IF p_decision = 'READY' THEN
        l_hits := l_rag.get_array('hits');
        IF l_rag.get_string('status') = 'OK' AND l_hits.get_size() > 0 THEN
          FOR i IN 0 .. l_hits.get_size() - 1 LOOP
            l_hit := TREAT(l_hits.get(i) AS JSON_OBJECT_T);
            IF l_hit.get_string('action') = p_action AND p_action <> 'NONE' THEN
              l_allowed := TRUE;
            END IF;
          END LOOP;
        END IF;
        IF NOT l_allowed THEN
          RAISE_APPLICATION_ERROR(-20017, 'READY action must match retrieved KB evidence');
        END IF;
      END IF;
      l_entry.put('decision', p_decision);
      l_entry.put('action', p_action);
      l_entry.put('reason', SUBSTR(p_reason, 1, 1000));
      l_resolutions.put(id_key(p_log_id), l_entry);
      put_state('resolutions', l_resolutions);
    END IF;
    IF p_decision = 'READY' THEN
      l_decisions := state_object('decisions');
      l_decision := JSON_OBJECT_T();
      l_decision.put('action', p_action);
      l_decision.put('authorization', 'KB');
      l_decisions.put(id_key(p_log_id), l_decision);
      put_state('decisions', l_decisions);
    END IF;
    SELECT JSON_OBJECT('log_id' VALUE p_log_id, 'decision' VALUE p_decision,
      'action' VALUE p_action RETURNING CLOB) INTO l_result FROM dual;
    RETURN l_result;
  END;

  FUNCTION human_context RETURN CLOB IS
    l_batch JSON_OBJECT_T;
    l_logs JSON_ARRAY_T;
    l_log JSON_OBJECT_T;
    l_resolutions JSON_OBJECT_T;
    l_decisions JSON_OBJECT_T;
    l_executions JSON_OBJECT_T;
    l_entry JSON_OBJECT_T;
    l_item JSON_OBJECT_T;
    l_pending JSON_ARRAY_T := JSON_ARRAY_T();
    l_completed JSON_ARRAY_T := JSON_ARRAY_T();
    l_result JSON_OBJECT_T := JSON_OBJECT_T();
    l_key VARCHAR2(128);
  BEGIN
    l_batch := state_object('batch');
    l_logs := l_batch.get_array('logs');
    l_resolutions := state_object('resolutions');
    l_decisions := state_object('decisions');
    l_executions := state_object('executions');
    IF l_logs.get_size() > 0 THEN
      FOR i IN 0 .. l_logs.get_size() - 1 LOOP
        l_log := TREAT(l_logs.get(i) AS JSON_OBJECT_T);
        l_key := id_key(l_log.get_number('log_id'));
        IF NOT l_resolutions.has(l_key) THEN
          RAISE_APPLICATION_ERROR(-20018, 'Resolve all incidents before human interaction');
        END IF;
        l_entry := l_resolutions.get_object(l_key);
        IF NOT l_entry.has('decision') THEN
          RAISE_APPLICATION_ERROR(-20018, 'Incident has no stored resolution');
        END IF;
        l_item := JSON_OBJECT_T();
        l_item.put('log_id', l_log.get_number('log_id'));
        l_item.put('job_name', l_log.get_string('job_name'));
        IF l_entry.get_string('decision') = 'NEEDS_HUMAN' AND NOT l_decisions.has(l_key) THEN
          l_item.put('description', SUBSTR(l_log.get_string('message'), 1, 500));
          l_item.put('proposed_action', l_entry.get_string('action'));
          l_item.put('reason', l_entry.get_string('reason'));
          l_pending.append(l_item);
        ELSIF l_entry.get_string('decision') = 'READY' THEN
          IF NOT l_executions.has(l_key) THEN
            RAISE_APPLICATION_ERROR(-20019, 'Execute KB decisions before human interaction');
          END IF;
          l_entry := l_executions.get_object(l_key);
          IF l_entry.get_string('status') <> 'SUCCESS' THEN
            RAISE_APPLICATION_ERROR(-20019, 'KB action did not succeed');
          END IF;
          l_item.put('action', l_entry.get_string('action'));
          l_item.put('status', l_entry.get_string('status'));
          l_completed.append(l_item);
        END IF;
      END LOOP;
    END IF;
    l_result.put('pending', l_pending);
    l_result.put('completed', l_completed);
    RETURN l_result.to_clob();
  END;

  FUNCTION save_human_decisions(p_decisions IN CLOB) RETURN CLOB IS
    l_input JSON_ARRAY_T;
    l_item JSON_OBJECT_T;
    l_decision JSON_OBJECT_T;
    l_resolution JSON_OBJECT_T;
    l_log JSON_OBJECT_T;
    l_resolutions JSON_OBJECT_T;
    l_decisions JSON_OBJECT_T;
    l_ids JSON_ARRAY_T := JSON_ARRAY_T();
    l_result JSON_OBJECT_T := JSON_OBJECT_T();
    l_key VARCHAR2(128);
    l_action VARCHAR2(30);
    l_guard CLOB;
    l_batch JSON_OBJECT_T;
    l_logs JSON_ARRAY_T;
    l_seen JSON_OBJECT_T := JSON_OBJECT_T();
  BEGIN
    -- The HUMAN worker interprets actual ORA$HUMAN_TOOL input. This is not
    -- a cryptographic approval boundary: the tool cannot attest that input.
    l_guard := human_context();
    l_input := JSON_ARRAY_T.parse(p_decisions);
    IF l_input.get_size() = 0 THEN RAISE_APPLICATION_ERROR(-20020, 'No decisions'); END IF;
    l_resolutions := state_object('resolutions');
    l_decisions := state_object('decisions');
    FOR i IN 0 .. l_input.get_size() - 1 LOOP
      l_item := TREAT(l_input.get(i) AS JSON_OBJECT_T);
      l_log := incident(l_item.get_number('log_id'));
      l_key := id_key(l_log.get_number('log_id'));
      IF l_seen.has(l_key) THEN RAISE_APPLICATION_ERROR(-20026, 'Duplicate human decision'); END IF;
      l_seen.put(l_key, TRUE);
      l_resolution := l_resolutions.get_object(l_key);
      IF l_resolution.get_string('decision') <> 'NEEDS_HUMAN' THEN
        RAISE_APPLICATION_ERROR(-20021, 'Human decision must refer to a pending incident');
      END IF;
      l_action := l_item.get_string('action');
      check_action(l_action);
      IF l_decisions.has(l_key) THEN
        l_decision := l_decisions.get_object(l_key);
        IF l_decision.get_string('action') <> l_action THEN
          RAISE_APPLICATION_ERROR(-20022, 'Cannot replace a stored human decision');
        END IF;
      ELSE
        l_decision := JSON_OBJECT_T();
        l_decision.put('action', l_action);
        l_decision.put('authorization', 'HUMAN');
        l_decisions.put(l_key, l_decision);
      END IF;
      l_ids.append(l_log.get_number('log_id'));
    END LOOP;
    -- Validate the whole pending set before publishing any decision changes.
    l_batch := state_object('batch');
    l_logs := l_batch.get_array('logs');
    FOR i IN 0 .. l_logs.get_size() - 1 LOOP
      l_log := TREAT(l_logs.get(i) AS JSON_OBJECT_T);
      l_key := id_key(l_log.get_number('log_id'));
      l_resolution := l_resolutions.get_object(l_key);
      IF l_resolution.get_string('decision') = 'NEEDS_HUMAN' AND NOT l_decisions.has(l_key) THEN
        RAISE_APPLICATION_ERROR(-20027, 'Missing human decision');
      END IF;
    END LOOP;
    put_state('decisions', l_decisions);
    l_result.put('status', 'STORED');
    l_result.put('authorized_log_ids', l_ids);
    RETURN l_result.to_clob();
  END;

  PROCEDURE record_action(p_run_id VARCHAR2, p_log_id NUMBER, p_action VARCHAR2, p_result CLOB) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO etlr_action_log(run_id, log_id, action, result)
      VALUES(p_run_id, p_log_id, p_action, p_result);
    COMMIT;
  EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
  END;

  FUNCTION execute_decision(p_log_id IN NUMBER) RETURN CLOB IS
    l_log JSON_OBJECT_T;
    l_batch JSON_OBJECT_T;
    l_decisions JSON_OBJECT_T;
    l_decision JSON_OBJECT_T;
    l_executions JSON_OBJECT_T;
    l_result JSON_OBJECT_T;
    l_action VARCHAR2(30);
    l_key VARCHAR2(128);
    l_status VARCHAR2(20);
    l_params CLOB;
    l_body CLOB;
    l_error VARCHAR2(4000);
    l_job VARCHAR2(128);
    l_subject VARCHAR2(100);
  BEGIN
    l_log := incident(p_log_id);
    l_batch := state_object('batch');
    l_key := id_key(p_log_id);
    l_decisions := state_object('decisions');
    IF NOT l_decisions.has(l_key) THEN RAISE_APPLICATION_ERROR(-20023, 'No authorization'); END IF;
    l_decision := l_decisions.get_object(l_key);
    IF l_decision.get_string('authorization') IS NULL OR
       l_decision.get_string('authorization') NOT IN ('KB', 'HUMAN') THEN
      RAISE_APPLICATION_ERROR(-20023, 'Invalid authorization');
    END IF;
    l_action := l_decision.get_string('action');
    check_action(l_action);
    l_executions := state_object('executions');
    IF l_executions.has(l_key) THEN
      l_result := l_executions.get_object(l_key);
      l_result.remove('error');
      RETURN l_result.to_clob();
    END IF;
    l_result := JSON_OBJECT_T();
    l_result.put('log_id', p_log_id);
    l_result.put('action', l_action);
    l_result.put('status', 'STARTED');
    l_executions.put(l_key, l_result);
    put_state('executions', l_executions);
    BEGIN
      IF l_action = 'RESTART_ETL_JOB' THEN
        -- Simulated; no scheduler job is run.
        l_result.put('simulated', TRUE);
        l_status := 'SUCCESS';
      ELSIF l_action = 'NOTIFY_DB_OPS' THEN
        l_job := l_log.get_string('job_name');
        l_subject := SUBSTR('ETL incident ' || id_key(p_log_id) || ': ' || l_job, 1, 100);
        SELECT JSON_OBJECT('recipient' VALUE '<...>',
          'sender' VALUE '<...>',
          'smtp_host' VALUE '<...>',
          'subject' VALUE l_subject RETURNING CLOB) INTO l_params FROM dual;
        l_body := 'Job: ' || l_log.get_string('job_name') || CHR(10) ||
          l_log.get_string('message') || CHR(10) || 'Selected escalation: NOTIFY_DB_OPS';
        DBMS_CLOUD_NOTIFICATION.SEND_MESSAGE(provider => 'email',
          credential_name => 'EMAIL_CRED', message => l_body, params => l_params);
        l_status := 'SUCCESS';
      ELSE
        l_status := 'SKIPPED';
      END IF;
    EXCEPTION WHEN OTHERS THEN
      l_status := 'FAILED';
      l_error := SQLERRM;
      -- Keep diagnostic details in state, not in the executor LLM response.
    END;
    l_result.put('status', l_status);
    IF l_error IS NOT NULL THEN l_result.put('error', l_error); END IF;
    record_action(l_batch.get_string('run_id'), p_log_id, l_action, l_result.to_clob());
    l_executions.put(l_key, l_result);
    put_state('executions', l_executions);
    l_result.remove('error');
    RETURN l_result.to_clob();
  END;

  PROCEDURE store_experience(p_log_id NUMBER, p_message VARCHAR2, p_action VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_count NUMBER;
    l_vector VECTOR;
  BEGIN
    SELECT COUNT(*) INTO l_count FROM etlr_kb WHERE source_log_id = p_log_id;
    IF l_count = 0 THEN
      l_vector := embed_text(p_message);
      INSERT INTO etlr_kb(source_log_id, error_text, action, embedding)
        VALUES(p_log_id, p_message, p_action, l_vector);
    END IF;
    COMMIT;
  EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
  END;

  PROCEDURE advance_checkpoint(p_start NUMBER, p_end NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE etlr_checkpoint SET last_log_id = p_end
    WHERE singleton = 1 AND last_log_id = p_start;
    IF SQL%ROWCOUNT <> 1 THEN RAISE_APPLICATION_ERROR(-20024, 'Checkpoint changed'); END IF;
    COMMIT;
  EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
  END;

  FUNCTION finalize_batch RETURN CLOB IS
    l_batch JSON_OBJECT_T;
    l_logs JSON_ARRAY_T;
    l_log JSON_OBJECT_T;
    l_resolutions JSON_OBJECT_T;
    l_resolution JSON_OBJECT_T;
    l_decisions JSON_OBJECT_T;
    l_decision JSON_OBJECT_T;
    l_executions JSON_OBJECT_T;
    l_execution JSON_OBJECT_T;
    l_key VARCHAR2(128);
    l_action VARCHAR2(30);
    l_result CLOB;
    l_stored NUMBER := 0;
    l_final JSON_OBJECT_T;
    l_count NUMBER;
    l_end NUMBER;
  BEGIN
    l_batch := state_object('batch');
    IF l_batch.has('final_result') THEN
      l_final := l_batch.get_object('final_result');
      RETURN l_final.to_clob();
    END IF;
    l_logs := l_batch.get_array('logs');
    IF l_logs.get_size() = 0 THEN RETURN '{"status":"NO_NEW_LOG"}'; END IF;
    l_resolutions := state_object('resolutions');
    l_decisions := state_object('decisions');
    l_executions := state_object('executions');
    FOR i IN 0 .. l_logs.get_size() - 1 LOOP
      l_log := TREAT(l_logs.get(i) AS JSON_OBJECT_T);
      l_key := id_key(l_log.get_number('log_id'));
      IF NOT l_resolutions.has(l_key) OR NOT l_decisions.has(l_key) OR NOT l_executions.has(l_key) THEN
        RETURN '{"status":"INCOMPLETE"}';
      END IF;
      l_resolution := l_resolutions.get_object(l_key);
      l_decision := l_decisions.get_object(l_key);
      l_execution := l_executions.get_object(l_key);
      l_action := l_decision.get_string('action');
      check_action(l_action);
      IF l_resolution.get_string('decision') IS NULL OR
         l_resolution.get_string('decision') NOT IN ('READY', 'NEEDS_HUMAN') OR
         (l_resolution.get_string('decision') = 'READY' AND
          NVL(l_resolution.get_string('action'), '?') <> l_action) OR
         l_execution.get_string('action') IS NULL OR
         l_execution.get_string('action') <> l_action OR
         l_execution.get_string('status') IS NULL OR
         (l_action = 'NONE' AND l_execution.get_string('status') <> 'SKIPPED') OR
         (l_action <> 'NONE' AND l_execution.get_string('status') <> 'SUCCESS') OR
         (l_resolution.get_string('decision') = 'NEEDS_HUMAN' AND
          NVL(l_decision.get_string('authorization'), '?') <> 'HUMAN') OR
         (l_resolution.get_string('decision') = 'READY' AND
          NVL(l_decision.get_string('authorization'), '?') <> 'KB') THEN
        RETURN '{"status":"INCOMPLETE"}';
      END IF;
    END LOOP;
    -- No KB writes or checkpoint update until the whole batch passes validation.
    FOR i IN 0 .. l_logs.get_size() - 1 LOOP
      l_log := TREAT(l_logs.get(i) AS JSON_OBJECT_T);
      l_decision := l_decisions.get_object(id_key(l_log.get_number('log_id')));
      l_action := l_decision.get_string('action');
      IF l_action <> 'NONE' THEN
        store_experience(l_log.get_number('log_id'), l_log.get_string('message'), l_action);
        l_stored := l_stored + 1;
      END IF;
    END LOOP;
    advance_checkpoint(l_batch.get_number('start_log_id'), l_batch.get_number('end_log_id'));
    l_count := l_logs.get_size();
    l_end := l_batch.get_number('end_log_id');
    SELECT JSON_OBJECT('status' VALUE 'SUCCESS', 'handled' VALUE l_count,
      'experience_count' VALUE l_stored, 'checkpoint' VALUE l_end
      RETURNING CLOB) INTO l_result FROM dual;
    l_batch.put('final_result', JSON_OBJECT_T.parse(l_result));
    put_state('batch', l_batch);
    RETURN l_result;
  END;
END pkg_etlr_demo;
/
