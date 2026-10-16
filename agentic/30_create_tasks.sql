SET ECHO OFF
REM ***************************************************************************
REM ********************* Andrej SQL    Oracle Demos  *************************
REM ***************************************************************************
REM
REM Privileges..: User
REM File name...: 30_create_tasks.sql
REM Author......: Andrej Pashchenko
REM Description.: Create tasks used for SELECT AI Agent demo
REM Notes.......: -
REM Parameters..: -
REM Dependencies: uses define_alhdb.sql
REM Requirements: Oracle Database 26ai (Autonomous)
REM
REM ***************************************************************************

@define_alhdb.sql
CONNECT /@&_sid_or_service 
SET ECHO ON TERMOUT ON SERVEROUTPUT ON PAGESIZE 1000 LINESIZE 100


BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name  => 'ETL_GET_CHECKPOINT_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE 
q'[Retrieve the log_id processing marker for ETL incident processing.

Call ETL_GET_LAST_LOG_ID_TOOL.

Return ONLY one line in this format:
START_LOG_ID=<number>.]'
    , 'tools' VALUE JSON_ARRAY(
        'ETL_GET_LAST_LOG_ID_TOOL'
      )
    , 'enable_human_tool' VALUE 'false'
    )
  );
END;
/


BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name  => 'ETL_READ_LOG_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE 
q'[Call ETL_LOG_READER_TOOL.

If tool returns status="NO_NEW_LOG", return ONLY:
NO_WORK

Otherwise return ONLY these lines (copy values from tool output):
LOG_ID=<number>
JOB_NAME=<value or NULL>
MESSAGE=<value>
]'
    , 'tools' VALUE JSON_ARRAY(
        'ETL_LOG_READER_TOOL'
      )
    , 'input' VALUE 'ETL_GET_CHECKPOINT_TASK'
    , 'enable_human_tool' VALUE 'false'
    )
  );
END;
/


BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name  => 'ETL_RAG_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE 
q'[Lookup the knowledge base for previous incidents.

If input is:
NO_WORK

Return ONLY:
NO_WORK

Otherwise:
extract a short error description from MESSAGE.

Call ETL_DIY_RAG_TOOL with:
p_query = short error description
p_top_k = 3

Return ONLY these lines:
LOG_ID=<number>
JOB_NAME=<value or NULL>
MESSAGE=<same as input>
RAG_RESULT=<raw tool output>.]'
    , 'tools' VALUE JSON_ARRAY(
        'ETL_DIY_RAG_TOOL'
      )
    , 'input' VALUE 'ETL_READ_LOG_TASK'
    , 'enable_human_tool' VALUE 'false'
    )
  );
END;
/



BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name  => 'ETL_DECIDE_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE 
q'[Decide how to handle one ETL incident.

If input is NO_WORK return ONLY:
NO_WORK

Input format:
LOG_ID=<number>
JOB_NAME=<text>
MESSAGE=<text>
RAG_RESULT=<text>

Copy LOG_ID, JOB_NAME, and MESSAGE exactly from the input.
Do not modify these values.

Allowed ACTION values:
RESTART_ETL_JOB | NOTIFY_DB_OPS | NONE

Rules:

1) If RAG_RESULT contains "NO_HITS":

   Analyze the MESSAGE and determine the most likely cause.

   If helpful, you may use WEBSEARCH_TOOL to gather additional context.

   Decide a PROPOSED_ACTION:
   RESTART_ETL_JOB | NOTIFY_DB_OPS | NONE

   Provide a short REASON for your decision.

   Then call ORA$HUMAN_TOOL.

   MESSAGE_TO_HUMAN must contain:
   - Incident summary
   - Proposed action
   - Reason
   - The exact question below

   The message must end EXACTLY with:
   "Choose action: 1=Restart ETL job, 2=Notify DB Ops, 3=Do nothing. Reply with 1, 2, or 3 only."

   Then WAIT.

   After the human reply, map:
   1 -> RESTART_ETL_JOB
   2 -> NOTIFY_DB_OPS
   3 -> NONE

2) Otherwise (RAG_RESULT has useful matches):

   Decide ACTION based on RAG_RESULT.
   Do not ask the human.

Final output:

After human interaction (if any), return ONLY:

LOG_ID=<copied>
ACTION=<RESTART_ETL_JOB | NOTIFY_DB_OPS | NONE>
JOB_NAME=<copied>
MESSAGE=<copied>

Do not output any explanations outside the required format.
]'
    , 'tools' VALUE JSON_ARRAY(
        'WEBSEARCH_TOOL'
      )
    , 'input' VALUE 'ETL_RAG_TASK'
    , 'enable_human_tool' VALUE 'true'
    )
  );
END;
/


BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name  => 'ETL_EXECUTE_TASK',
    attributes => JSON_OBJECT(
      'instruction' VALUE 
q'[Execute the selected action.

If input is:
NO_WORK

Return ONLY:
EXEC_STATUS=SKIPPED

Otherwise read:
LOG_ID
ACTION
JOB_NAME
MESSAGE

If ACTION=RESTART_ETL_JOB
call ETL_RESTART_JOB_TOOL.


ONLY if ACTION=NOTIFY_DB_OPS: call the tool ETL_NOTIFY_PER_MAIL exactly once.

Tool input MUST be valid JSON with ONLY these keys:
{"tool_name":"ETL_NOTIFY_PER_MAIL", "email_subject":"<text>", "email_body":"<text>"}

email_subject: short, e.g. "ETL incident: <JOB_NAME> <LOG_ID>"
email_body: include the raw log MESSAGE text.

In subject and message do not include unescaped double quotes. Replace " with ' if needed.


If ACTION=NONE
do nothing.

If an action was executed successfully:
store experience using ETL_KB_STORE_TOOL passing a MESSAGE from log as P_ERROR_TEXT.

Finally update the processing marker by calling
ETL_SET_LAST_LOG_ID_TOOL with p_log_id=LOG_ID.

Return ONLY one line:
EXEC_STATUS=<SUCCESS | FAILED | SKIPPED>.]'
    , 'tools' VALUE JSON_ARRAY(
        'ETL_RESTART_JOB_TOOL'
      , 'ETL_NOTIFY_PER_MAIL'
      , 'ETL_KB_STORE_TOOL'
      , 'ETL_SET_LAST_LOG_ID_TOOL'
      )
    , 'input' VALUE 'ETL_DECIDE_TASK'
    , 'enable_human_tool' VALUE 'false'
    )
  );
END;
/


-------------------------------------------------------------------------------
--               E  N  D   O F   S C R I P T
-------------------------------------------------------------------------------
pause Press Enter TO CONTINUE
 
EXIT