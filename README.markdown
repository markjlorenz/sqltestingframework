# SQL Testing Framework Template

Full docs at: [https://sqltestingframework.com](https://www.sqltestingframework.com/)

## How to use it

Clone this repository into a `queries/test` directory of your project.  This is where you will keep your test files.

Run the test running by:

```sh
cd queries/test
./runner.sh
```

## Basic tests

```sql
WITH text AS (
  SELECT 'Rentals can only have one payment' AS value
), expect AS (
  SELECT 1 AS value
), actual AS (
  SELECT
    COUNT(rental_id) AS value
  FROM payment
  GROUP BY rental_id
  ORDER BY COUNT(rental_id) DESC
  LIMIT 1
)
:evaluate_test
```

## Testing `SELECT` queries

```sql
\set query /queries/degrees-of-kevin-bloom.sql
:setup_test
WITH text AS (
  SELECT 'Each actor can only be in a single "degree" group' AS value
), expect AS (
  SELECT
    COUNT(actor_id) AS value
  FROM "/queries/degrees-of-kevin-bloom.sql"
), actual AS (
  SELECT
    COUNT(DISTINCT actor_id) AS value
  FROM "/queries/degrees-of-kevin-bloom.sql"
)
:evaluate_test
:cleanup_test
```

## Precheck assertions

```sql
```
