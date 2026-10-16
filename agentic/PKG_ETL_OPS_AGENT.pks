CREATE OR REPLACE PACKAGE ETL_OPS.pkg_etl_ops_agent AS


 FUNCTION retrieve_next_log_record(p_start_log_id IN NUMBER) RETURN CLOB;
 
 FUNCTION restart_etl_job (p_job_name IN VARCHAR2) return CLOB;

 FUNCTION get_last_processed_log_id return number;


 FUNCTION set_last_processed_log_id (p_log_id IN NUMBER) return varchar2; 

FUNCTION etl_embed_text(p_text IN CLOB) RETURN VECTOR;


FUNCTION etl_diy_rag_search(
  p_query   IN VARCHAR2,
  p_top_k   IN NUMBER DEFAULT 5
  , p_max_dist  IN NUMBER DEFAULT 0.25
) RETURN CLOB;

FUNCTION etl_kb_store(
  p_error_signature   IN VARCHAR2
, p_error_text        IN CLOB
, p_action_type       IN VARCHAR2
, p_action_params_json IN CLOB
, p_outcome           IN VARCHAR2
, p_action_text       IN CLOB
, p_kb_payload_json   IN CLOB
) RETURN CLOB;

function etl_notification_stub (p_message in clob) return clob;


END pkg_etl_ops_agent;
/
