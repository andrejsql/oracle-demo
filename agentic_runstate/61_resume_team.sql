SET ECHO OFF
REM Andrej SQL - SELECT AI run-state demo
REM Reply to the combined human question in the saved supervisor conversation.
REM Requires Autonomous Database with Select AI supervisor support.
@define_alhdb.sql
WHENEVER SQLERROR CONTINUE NONE
CONNECT /@&_sid_or_service
SET ECHO ON TERMOUT ON SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 1000 LINESIZE 180 LONG 12000 LONGCHUNKSIZE 12000

SET ECHO OFF VERIFY OFF
PROMPT Reply with Approve all, or log_id=choice pairs.
PROMPT Example: 101=2, 103=3
ACCEPT etlr_reply CHAR PROMPT 'Your decisions: '
VARIABLE etlr_result CLOB
DECLARE
  l_conversation_id VARCHAR2(128);
  l_state VARCHAR2(128);
BEGIN
  SELECT conversation_id INTO l_conversation_id FROM etlr_run WHERE singleton = 1;
  l_state := DBMS_CLOUD_AI_AGENT.GET_TEAM_STATE(
    team_name => 'ETLR_OPS_TEAM',
    params => JSON_OBJECT('conversation_id' VALUE l_conversation_id));
  IF l_state IS NULL OR l_state <> 'WAITING_FOR_HUMAN' THEN
    RAISE_APPLICATION_ERROR(-20003, 'This conversation is not waiting for human input. Use 60 for a new batch.');
  END IF;
  DBMS_OUTPUT.PUT_LINE('Resuming conversation: ' || l_conversation_id);
  :etlr_result := DBMS_CLOUD_AI_AGENT.RUN_TEAM(
    team_name => 'ETLR_OPS_TEAM',
    user_prompt => q'~&etlr_reply~',
    params => JSON_OBJECT('conversation_id' VALUE l_conversation_id,
      'attribute_variables' VALUE JSON_OBJECT('llm_profile' VALUE '&_AIPROFILE'),
      'instruction_variables' VALUE JSON_OBJECT('batch_limit' VALUE '3')));
END;
/
UNDEFINE etlr_reply
PRINT etlr_result

PAUSE Review the results, then press Enter to close this window.
EXIT
