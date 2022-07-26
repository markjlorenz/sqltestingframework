SELECT
   CASE
     WHEN LENGTH(actual) > 12 AND did_pass = TRUE THEN
       CONCAT(LEFT(actual::text, 6), '…', RIGHT(actual::text, 6))
     ELSE
       actual
   END AS actual
  ,CASE
    WHEN LENGTH(expect) > 12 AND did_pass = TRUE THEN
      CONCAT(LEFT(expect::text, 6), '…', RIGHT(expect::text, 6))
    ELSE
      expect
   END AS expect
  ,did_pass
  ,text
FROM :results_table_name
WHERE run_id=:run_id
ORDER BY filename
;
