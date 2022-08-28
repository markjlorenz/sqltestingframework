#!/usr/bin/env bash

set -e

# Hide the cursor while the program is running
function cleanup() {
    tput cnorm
}
trap cleanup EXIT
tput civis

# If a filename is provided, run only that file in the test
# suite, if no filename is provided, then run all the files
# in the current directory
[ $# -ge 1 ] && FILE_GLOB="$@" || FILE_GLOB="./*.sql"

# This is reused across test runs, and created if it does not exist.
# these can be overridden by assigning in `./runner.sh`s environment e.g.:
#   export STF_ECHO=queries
SCHEMA_NAME=${SCHEMA_NAME:-"stf"}
RESULTS_TABLE_NAME=${RESULTS_TABLE_NAME:-"test_results"}
PRECHECK_TABLE_NAME=${PRECHECK_TABLE_NAME:-"prechecks"}
MAD_MAX_DEVIATIONS=${MAD_MAX_DEVIATIONS:-"6"}
STF_ECHO=${STF_ECHO:-"none"} # none | errors | queries | all

RUN_ID=`date +"%s" | tr -d "\n"`

docker run -it --rm \
  --env PGPASSWORD="$PG_PASSWORD" \
  --volume "$PWD":/work:ro \
  --workdir /work \
  --env PGOPTIONS="--client-min-messages=warning" \
  postgres psql \
    -h host.docker.internal \
    -p "$PG_PORT" \
    -U postgres \
    --quiet \
    --variable ON_ERROR_STOP="1" \
    --variable schema_name="$SCHEMA_NAME" \
    --variable results_table_name="$RESULTS_TABLE_NAME" \
    --variable prechecks="$PRECHECK_TABLE_NAME" \
    -f "./config/setup.sql"

# Draw an empty circle for each test file that willl run
for i in $FILE_GLOB
do
  echo -n " ◦"
done
echo -en "\r"

for test_file in $FILE_GLOB; do
  # Fill in dots as the test files run
  echo -n " ●"

  docker run -it --rm \
    --env PGPASSWORD="$PG_PASSWORD" \
	  --volume "$PWD":/work:ro \
	  --volume "$PWD/../":/queries:ro \
	  --workdir /work \
    --env PGOPTIONS="--client-min-messages=warning" \
    postgres psql \
      -h host.docker.internal \
      -p "$PG_PORT" \
      -U postgres \
      --quiet \
      --variable ECHO="$STF_ECHO" \
      --variable ON_ERROR_STOP="1" \
      --variable schema_name="$SCHEMA_NAME" \
      --variable results_table_name="$RESULTS_TABLE_NAME" \
      --variable prechecks="$PRECHECK_TABLE_NAME" \
      --variable run_id="$RUN_ID" \
      --variable filename="$test_file" \
      --variable mad_max_deviations="$MAD_MAX_DEVIATIONS" \
      --variable setup_test="
        BEGIN;
        \\if :{?query}
          \\set query_variable \`cat :query\` \\\\
          CREATE TEMP TABLE :\"query\"
            ON COMMIT DROP
            AS :query_variable
          ;
        \\endif \\\\
        CREATE TEMP TABLE :\"prechecks\" (value BOOLEAN)
          ON COMMIT DROP
        ;
      " \
      --variable get_mad_max="
        SELECT
           median
          ,mad
          ,mad * :mad_max_deviations + median AS max
        FROM (
          SELECT
            PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY median_deviation) AS mad
            ,MAX(median) AS median
          FROM (
            SELECT
               ABS(:mad_max_col - median.value) AS median_deviation
              ,median.value AS median
            FROM :mad_max_tbl
            FULL JOIN (
              SELECT
                PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY :mad_max_col) AS value
              FROM :mad_max_tbl
            ) median ON TRUE
          ) median_deviations
        ) calcs
      " \
      --variable evaluate_test="
        INSERT INTO :schema_name.:results_table_name (
           run_id
          ,filename
          ,actual
          ,expect
          ,did_pass
          ,text
        )
        SELECT
           :run_id AS run_id
          ,:'filename' AS filename
          ,actual.value AS actual
          ,expect.value AS expect
          ,actual.value IS NOT DISTINCT FROM expect.value AS did_pass
          ,text.value AS text
        FROM actual
        FULL JOIN expect    ON TRUE
        FULL JOIN text      ON TRUE
        ;

        CREATE TEMP TABLE IF NOT EXISTS :\"prechecks\" (value BOOLEAN)
        ;
        WITH latest_test_run AS (
          SELECT * FROM :schema_name.:results_table_name
          ORDER BY id DESC
          LIMIT 1
        ), aggregated_prechecks AS (
          SELECT
             latest_test_run.id AS id
             ,ARRAY_REMOVE(ARRAY_AGG(prechecks.value), NULL) AS value
          FROM latest_test_run
          FULL JOIN :\"prechecks\" ON TRUE
          GROUP BY latest_test_run.id
        )
        UPDATE :schema_name.:results_table_name
        SET precheck = aggregated_prechecks.value
        FROM aggregated_prechecks
        WHERE aggregated_prechecks.id = :schema_name.:results_table_name.id
        ;
      " \
      --variable cleanup_test="
        \\unset query_variable \\\\
        \\unset query \\\\
        COMMIT;
      " \
      -f "$test_file"
done

echo ""

docker run -it --rm \
  --env PGPASSWORD="$PG_PASSWORD" \
  --volume "$PWD":/work:ro \
  --workdir /work \
  --env PGOPTIONS="--client-min-messages=warning" \
  --env PSQL_PAGER="./config/output_format.sh" \
  postgres psql \
    -h host.docker.internal \
    -p "$PG_PORT" \
    -U postgres \
    --quiet \
    --pset="pager=always" \
    --variable ON_ERROR_STOP="1" \
    --variable schema_name="$SCHEMA_NAME" \
    --variable results_table_name="$RESULTS_TABLE_NAME" \
    --variable prechecks="$PRECHECK_TABLE_NAME" \
    --variable run_id="$RUN_ID" \
    -f "./config/teardown.sql"
