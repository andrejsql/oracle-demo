CREATE OR REPLACE PACKAGE pkg_etls_demo AUTHID DEFINER AS
  FUNCTION fetch_batch RETURN CLOB;
  FUNCTION embed_text(p_text IN VARCHAR2) RETURN VECTOR;
  FUNCTION search_kb(p_query IN VARCHAR2) RETURN CLOB;
  FUNCTION restart_job(p_log_id IN NUMBER) RETURN CLOB;
  FUNCTION store_experience(p_log_id IN NUMBER, p_action IN VARCHAR2) RETURN CLOB;
  FUNCTION finish_batch(p_end_log_id IN NUMBER) RETURN CLOB;
END pkg_etls_demo;
/
