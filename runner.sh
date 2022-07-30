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
[ $# -ge 1 -a -f "$1" ] && FILE_GLOB="$1" || FILE_GLOB="./*.sql"
FILE_COUNT=$(ls -1q $FILE_GLOB | wc -l)

# This is reused across test runs, and created if it does not exist.
RESULTS_TABLE_NAME="tmp_test_results"
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
    --variable results_table_name="$RESULTS_TABLE_NAME" \
    -f "./config/setup.sql"

# Draw an empty circle for each test file that willl run
for i in $FILE_GLOB
do
  echo -n " ◦"
done
echo -en "\r"

for test_file in $FILE_GLOB
do
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
      --variable ON_ERROR_STOP="1" \
      --variable results_table_name="$RESULTS_TABLE_NAME" \
      --variable run_id="$RUN_ID" \
      --variable filename="$test_file" \
      --variable evaluate_test="
        INSERT INTO :results_table_name (
          run_id,
          filename,
          actual,
          expect,
          did_pass,
          text
        )
        SELECT
          :run_id AS run_id,
          :'filename' AS filename,
          actual.value AS actual,
          expect.value AS expect,
          (actual.value IS NOT DISTINCT FROM expect.value) AS did_pass,
          text.value AS text
        FROM actual
        FULL JOIN expect ON 1 = 1
        FULL JOIN text   ON 1 = 1
        ;
      " \
      --variable setup_test="
        \\set query_variable \`cat :query\`
        \\; -- to force a new line
        BEGIN;
        CREATE TEMP TABLE :\"query\" ON COMMIT DROP
          AS :query_variable
        ;
      " \
      --variable cleanup_test="
        \\unset query_variable \\;
        \\unset query \\;
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
    --variable results_table_name="$RESULTS_TABLE_NAME" \
    --variable run_id="$RUN_ID" \
    -f "./config/teardown.sql"
