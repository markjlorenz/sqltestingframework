#!/usr/bin/env bash

set -e

# This is reused across test runs, and created if it does not exist.
RESULTS_TABLE_NAME="tmp_test_results"
RUN_ID=`date +"%s" | tr -d "\n"`

docker run -it --rm \
  --env PGPASSWORD="$PG_PASSWORD" \
  --volume "$PWD":/work \
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

for test_file in ./*.sql
do
  echo -n "."

  docker run -it --rm \
    --env PGPASSWORD="$PG_PASSWORD" \
	  --volume "$PWD":/work \
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
          (actual.value = expect.value) AS did_pass,
          text.value AS text
        FROM actual
        FULL JOIN expect ON 1 = 1
        FULL JOIN text   ON 1 = 1
        ;
      " \
      -f "$test_file"
done

echo ""

docker run -it --rm \
  --env PGPASSWORD="$PG_PASSWORD" \
  --volume "$PWD":/work \
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
