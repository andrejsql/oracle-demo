CREATE OR REPLACE PACKAGE pkg_etlr_demo AUTHID DEFINER AS
  FUNCTION embed_text(p_text IN VARCHAR2) RETURN VECTOR;
  FUNCTION fetch_batch RETURN CLOB;
  FUNCTION resolve_context(p_log_id IN NUMBER) RETURN CLOB;
  FUNCTION save_resolution(p_log_id IN NUMBER, p_decision IN VARCHAR2,
    p_action IN VARCHAR2, p_reason IN VARCHAR2) RETURN CLOB;
  FUNCTION human_context RETURN CLOB;
  FUNCTION save_human_decisions(p_decisions IN CLOB) RETURN CLOB;
  FUNCTION execute_decision(p_log_id IN NUMBER) RETURN CLOB;
  FUNCTION finalize_batch RETURN CLOB;
END pkg_etlr_demo;
/
