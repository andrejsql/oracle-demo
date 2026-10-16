SET ECHO OFF
REM Andrej SQL - SELECT AI supervisor demo
REM Start one three-error batch in a new conversation.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

VARIABLE etls_result CLOB
DECLARE
  l_conversation_id VARCHAR2(128);
  l_state VARCHAR2(128);
BEGIN
  BEGIN
    SELECT conversation_id INTO l_conversation_id FROM etls_run WHERE singleton = 1;
    l_state := DBMS_CLOUD_AI_AGENT.GET_TEAM_STATE(
      team_name => 'ETLS_OPS_TEAM',
      params => JSON_OBJECT('conversation_id' VALUE l_conversation_id));
    IF l_state IN ('WAITING_FOR_HUMAN', 'RUNNING') THEN
      RAISE_APPLICATION_ERROR(-20002,
        'A batch is still active. Use 61 to answer the human question, or 70 to inspect it.');
    END IF;
  EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
  END;

  l_conversation_id := DBMS_CLOUD_AI.CREATE_CONVERSATION();
  MERGE INTO etls_run r
  USING (SELECT 1 singleton FROM dual) s ON (r.singleton = s.singleton)
  WHEN MATCHED THEN UPDATE SET
    conversation_id = l_conversation_id, started_at = SYSTIMESTAMP
  WHEN NOT MATCHED THEN INSERT(singleton, conversation_id)
    VALUES(1, l_conversation_id);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Conversation: ' || l_conversation_id);
  :etls_result := DBMS_CLOUD_AI_AGENT.RUN_TEAM(
    team_name => 'ETLS_OPS_TEAM',
    user_prompt => 'Execute the procedure defined in your role exactly once.',
    params => JSON_OBJECT('conversation_id' VALUE l_conversation_id));
END;
/
PRINT etls_result
PROMPT If waiting for a human, inspect 70 or 71 before replying with 61.

PAUSE Review the results, then press Enter to close this window.
EXIT
