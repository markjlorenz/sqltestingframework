CREATE SCHEMA IF NOT EXISTS :schema_name;
CREATE TABLE IF NOT EXISTS :schema_name.:results_table_name (
   id SERIAL PRIMARY KEY
  ,run_id BIGINT
  ,filename TEXT
  ,actual TEXT
  ,expect TEXT
  ,did_pass BOOLEAN
  ,text TEXT
  ,precheck BOOLEAN[]
  ,created_at TIMESTAMP DEFAULT CLOCK_TIMESTAMP()
)
;
