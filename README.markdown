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
\set query /queries/sales-by-store.sql
:setup_test
WITH text AS (
  SELECT 'Store #1 has the right number of sales' AS value
), expect AS (
  SELECT
    SUM(payment.amount) AS value
  FROM store
  JOIN staff USING(store_id)
  JOIN payment USING(staff_id)
  WHERE store_id = 1
    AND DATE_PART('month', payment_date) = 3
), precheck_not_blank AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(SUM(value) > 0, FALSE)
  FROM expect
), precheck_that_always_fails AS (
 INSERT INTO :"prechecks" (value)
 SELECT FALSE
), actual AS (
  SELECT
    total_payment AS value
  FROM "/queries/sales-by-store.sql"
  WHERE store_id = 1
    AND payment_month = 3
)
:evaluate_test
:cleanup_test
```

## Skew

```sql
\set mad_max_tbl payment
\set mad_max_col amount
:setup_test
WITH text AS (
  SELECT 'A sample test with skew precheck' AS value
), expect AS (
  SELECT TRUE AS value
), mad_max AS (
  -- one row with `mad` and `max` columns
  -- `mad` is the median absolute deviation
  -- `max` is 6 mad deviations from the median
  -- anything outside of that is probably an outlier
  :get_mad_max</span>
), precheck_no_skew AS (
  INSERT INTO :"prechecks" (value)
  SELECT COALESCE(COUNT(amount) = 0, FALSE)
  FROM payment
  FULL JOIN mad_max ON TRUE
  WHERE payment.amount > mad_max.max + mad_max.mad
), actual AS (
  SELECT TRUE AS value
)
:evaluate_test
:cleanup_test
```

```sql
postgres=# \set mad_max_tbl payment
postgres=# \set mad_max_col amount
postgres=# \include test/utils/histogram.sql
```
