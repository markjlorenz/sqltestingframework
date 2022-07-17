CREATE TABLE IF NOT EXISTS :results_table_name (
  run_id BIGINT,
  filename TEXT,
  actual TEXT,
  expect TEXT,
  did_pass BOOLEAN,
  text TEXT
)
;
