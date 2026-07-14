# Data Observability with dbt and Soda

This guide explains how dbt tests and Soda Cloud work together in this project to provide data observability — the ability to know whether your data is healthy, when it broke, and why.

---

## What is data observability?

**dbt tests** are assertions you write in YAML or SQL. Every time you run `dbt test`, dbt executes those assertions against your tables and reports which ones passed or failed.

**Soda Cloud** is an observability platform. The `soda ingest dbt` command reads the dbt test results from your local `target/` folder and pushes them to Soda Cloud, where you can see a historical dashboard, set alerts, and track data quality over time across your entire pipeline.

```
NewsAPI  →  dlt ingest  →  raw tables  →  dbt models  →  dbt test
                                                               │
                                                    soda ingest dbt
                                                               │
                                                         Soda Cloud
                                                   (dashboard + history)
```

---

## Running the observability workflow

```bash
# 1. Build models and run all tests
make dbt-run dbt-test

# 2. Push test results to Soda Cloud
make soda-ingest

# Or do both in one command
make dbt-test-and-observe
```

> `make all` runs the full pipeline: `dbt-run` → `dbt-test` → `soda-ingest`.

---

## Test types used in this project

This project demonstrates every major category of dbt test. The table below maps each test type to where it lives in the codebase.

| Test type | Example | Location |
|-----------|---------|----------|
| Generic built-in | `not_null`, `unique`, `accepted_values`, `relationships` | All model YML files |
| dbt_expectations | `expect_column_values_to_match_regex`, `expect_table_row_count_to_be_between` | Staging, intermediate, mart YML files |
| Custom generic | `positive_value` | `tests/generic/test_positive_value.sql` |
| Custom singular | `test_published_at_not_future` | `tests/` folder |
| Unit test | `mart_newsapi__daily_articles_unit_test` | `tests/mart_newsapi__daily_articles_unit_test.yml` |
| Source freshness | warn after 1h, error after 24h | `models/staging/newsapi/raw/_newsapi__sources.yml` |

---

### 1. Generic built-in tests

The simplest tests, written directly in column definitions:

```yaml
# models/intermediate/newsapi/int_newsapi__articles.yml
columns:
  - name: _dlt_id
    tests:
      - not_null
      - unique
  - name: language_code
    tests:
      - accepted_values:
          values: ['en', 'de']
```

**Relationship tests** enforce referential integrity between models. Here the staging model verifies every `_dlt_id` it contains also exists in the raw source it was built from:

```yaml
# models/staging/newsapi/stg_newsapi__articles_us_en.yml
columns:
  - name: _dlt_id
    tests:
      - relationships:
          to: ref('src_newsapi__articles_us_en')
          field: _dlt_id
```

---

### 2. dbt_expectations tests

The [`dbt_expectations`](https://github.com/calogica/dbt-expectations) package brings Great Expectations-style assertions to dbt. These tests are more expressive than the built-ins.

**Table-level: row count**

```yaml
# models/staging/newsapi/stg_newsapi__articles_us_en.yml
models:
  - name: stg_newsapi__articles_us_en
    tests:
      - dbt_expectations.expect_table_row_count_to_be_between:
          min_value: 1
          severity: warn
```

Using `severity: warn` here means the test reports a warning (not a failure) when no rows exist — appropriate for a staging table that might be empty during development.

**Table-level: schema validation**

```yaml
# models/intermediate/newsapi/int_newsapi__articles.yml
tests:
  - dbt_expectations.expect_table_columns_to_match_set:
      column_list:
        - source_name
        - author
        - title
        - url
        - published_at
        - language_code
        - _dlt_id
        - source_table
        # ... full list
```

This catches accidental column additions or renames that would silently break downstream consumers.

**Column-level: regex validation**

```yaml
columns:
  - name: url
    tests:
      - dbt_expectations.expect_column_values_to_match_regex:
          regex: "^https?://"
```

**Column-level: string length**

```yaml
columns:
  - name: title
    tests:
      - dbt_expectations.expect_column_value_lengths_to_be_between:
          min_value: 5
          max_value: 500
```

**Column-level: value range**

```yaml
# models/mart/newsapi/mart_newsapi__daily_articles.yml
columns:
  - name: article_count
    tests:
      - dbt_expectations.expect_column_values_to_be_between:
          min_value: 1
          max_value: 10000
```

**Column-level: data type**

```yaml
columns:
  - name: published_at
    tests:
      - dbt_expectations.expect_column_values_to_be_of_type:
          column_type: timestamp
          severity: warn
```

---

### 3. Custom generic tests

Generic tests are reusable macros stored in `tests/generic/`. They work exactly like built-in tests and can be applied to any column:

```yaml
# tests/generic/test_positive_value.sql
{% test positive_value(model, column_name) %}
select *
from {{ model }}
where {{ column_name }} <= 0
{% endtest %}
```

Applied in YAML:

```yaml
columns:
  - name: article_count
    tests:
      - positive_value
```

---

### 4. Custom singular tests

One-off SQL assertions in the `tests/` folder. dbt runs every `.sql` file there and expects zero rows returned (rows = failures).

```sql
-- tests/test_published_at_not_future.sql
-- No article should have a publication date in the future
select *
from {{ ref('int_newsapi__articles') }}
where published_at > current_timestamp
```

The cross-layer integrity test verifies that every date in the mart traces back to a real article:

```sql
-- tests/test_mart_dates_within_source_range.sql
with source_range as (
    select
        cast(min(published_at) as date) as min_date,
        cast(max(published_at) as date) as max_date
    from {{ ref('int_newsapi__articles') }}
)
select mart.article_date
from {{ ref('mart_newsapi__daily_articles') }} mart, source_range
where mart.article_date < source_range.min_date
   or mart.article_date > source_range.max_date
```

---

### 5. Unit tests

Unit tests let you test model logic with mocked input data, without touching the actual database. Defined in YAML:

```yaml
# tests/mart_newsapi__daily_articles_unit_test.yml
unit_tests:
  - name: test_daily_article_count
    model: mart_newsapi__daily_articles
    given:
      - input: ref('int_newsapi__articles')
        rows:
          - {published_at: "2024-01-01T10:00:00", ...}
          - {published_at: "2024-01-01T14:00:00", ...}
          - {published_at: "2024-01-02T09:00:00", ...}
    expect:
      rows:
        - {article_date: "2024-01-01", article_count: 2}
        - {article_date: "2024-01-02", article_count: 1}
```

---

### 6. Source freshness

Defined on the source itself, not on a model. Warns or errors if the data hasn't been refreshed recently:

```yaml
# models/staging/newsapi/raw/_newsapi__sources.yml
sources:
  - name: newsapi
    freshness:
      warn_after: {count: 1, period: hour}
      error_after: {count: 24, period: hour}
    loaded_at_field: "_dlt_loads.inserted_at"
```

Run freshness checks with:
```bash
dbt source freshness
```

---

## How Soda ingest works

`soda ingest dbt` reads the JSON artifacts produced by dbt after a test run:

| Artifact | Location | Contains |
|----------|----------|----------|
| `manifest.json` | `target/` | Model graph, test definitions, column metadata |
| `run_results.json` | `target/` | Pass/fail status and timing for every test |

Soda maps each dbt test result to a **check** on the corresponding dataset in Soda Cloud. After ingest:

- Each model becomes a **dataset** in Soda Cloud
- Each dbt test becomes a **check** with its pass/fail history
- Failed tests show the failing rows count and test SQL
- You can set alert routing (email, Slack) per dataset or check

The Soda configuration for this project lives at `soda_testing/config.yml` and reads credentials from environment variables `SODA_CLOUD_API_KEY_ID` and `SODA_CLOUD_API_KEY_SECRET`.

---

## Further reading

- [dbt testing documentation](https://docs.getdbt.com/docs/build/data-tests)
- [dbt_expectations package](https://github.com/calogica/dbt-expectations)
- [Soda ingest dbt](https://docs.soda.io/soda/ingest.html)
- [Soda Cloud](https://cloud.soda.io)
