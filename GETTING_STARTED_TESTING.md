# Testing Guide for dbt-bigquery-core

This guide provides a comprehensive overview of all testing aspects in the dbt-bigquery-core project, including generic tests, custom tests, unit tests, freshness tests, volume tests, contracts, and SQL linting.

## Table of Contents
1. [Generic Tests](#generic-tests)
2. [Custom Tests](#custom-tests)
3. [Unit Tests](#unit-tests)
4. [Freshness Tests](#freshness-tests)
5. [Volume Tests](#volume-tests)
6. [Data Contracts](#data-contracts)
7. [SQL Linting](#sql-linting)

## Generic Tests

### Built-in Generic Tests

The project uses several built-in dbt generic tests:

1. **not_null**
   ```yaml
   columns:
     - name: title
       tests:
         - not_null
   ```

2. **unique**
   ```yaml
   columns:
     - name: _dlt_id
       tests:
         - unique
   ```

3. **accepted_values**
   ```yaml
   columns:
     - name: language_code
       tests:
         - accepted_values:
             values: ['en', 'de']
   ```

4. **relationships** (referential integrity)
   ```yaml
   columns:
     - name: source_table
       tests:
         - relationships:
             to: source('newsapi', 'raw_newsapi__articles_us_en')
             field: _dlt_id
   ```

### Custom Generic Tests

1. **positive_value**
   ```sql
   {% test positive_value(model, column_name) %}
   select *
   from {{ model }}
   where {{ column_name }} <= 0
   {% endtest %}
   ```
   Usage:
   ```yaml
   columns:
     - name: article_count
       tests:
         - positive_value
   ```

## Custom Tests

The project includes several custom SQL tests:

1. **test_articles_language_match_source.sql**
   ```sql
   WITH validation AS (
       SELECT
           *,
           CASE 
               WHEN source_table = 'us_en' AND language_code = 'en' THEN TRUE
               WHEN source_table = 'de_de' AND language_code = 'de' THEN TRUE
               ELSE FALSE
           END AS is_valid
       FROM {{ ref('int_newsapi__articles') }}
   )
   SELECT *
   FROM validation
   WHERE NOT is_valid
   ```

2. **test_no_duplicate_articles_across_languages.sql**
   ```sql
   WITH article_counts AS (
       SELECT
           title,
           COUNT(DISTINCT language_code) AS language_count
       FROM {{ ref('int_newsapi__articles') }}
       GROUP BY title
       HAVING COUNT(DISTINCT language_code) > 1
   )
   SELECT *
   FROM article_counts
   ```

3. **test_published_at_not_future.sql**
   ```sql
   SELECT *
   FROM {{ ref('int_newsapi__articles') }}
   WHERE published_at > CURRENT_TIMESTAMP()
   ```

## Unit Tests

The project uses the `dbt-unit-testing` package for unit testing. Configuration in `packages.yml`:
```yaml
packages:
  - git: "https://github.com/EqualExperts/dbt-unit-testing"
    revision: v0.4.11
```

Example unit test structure:
```yaml
unit_tests:
  - name: test_daily_articles_calculation
    model: mart_newsapi__daily_articles
    input:
      - name: int_newsapi__articles
        data:
          - published_at: "2024-01-01 10:00:00"
            language_code: "en"
          - published_at: "2024-01-01 11:00:00"
            language_code: "en"
    expected:
      - article_date: "2024-01-01"
        language_code: "en"
        article_count: 2
```

## Freshness Tests

Freshness tests are configured in source files:

```yaml
sources:
  - name: newsapi
    freshness:
      warn_after: {count: 1, period: hour}
      error_after: {count: 24, period: hour}
    loaded_at_field: "_dlt_loads.inserted_at"
```

## Volume Tests

The project uses dbt_utils for volume testing:

```yaml
tests:
  - dbt_utils.equal_rowcount:
      compare_model: ref('stg_newsapi__articles_us_en')
      severity: warn
```

## Data Contracts

Data contracts are enforced at the model level:

```yaml
models:
  - name: mart_newsapi__daily_articles
    config:
      contract:
        enforced: true
    columns:
      - name: article_date
        type: date
        tests:
          - not_null
      - name: article_count
        type: integer
        tests:
          - not_null
```

## SQL Linting

The project uses SQLFluff for SQL linting. Configuration can be found in `.sqlfluff`:

```ini
[sqlfluff]
dialect = bigquery
exclude_rules = L031,L034
max_line_length = 88
indent_size = 4
```

### Running Linting

```bash
# Check SQL files
sqlfluff lint models/

# Fix SQL files
sqlfluff fix models/
```

## Running Tests

Use the Makefile commands to run different types of tests:

```bash
# Run all dbt tests
make dbt-test

# Run specific test
dbt test --select test_name

# Run tests for specific model
dbt test --select model_name

# Run tests with custom severity
dbt test --severity warn
```

## Test Organization

Tests are organized in the following structure:
```
dbt-bigquery-core/
├── tests/
│   ├── generic/           # Generic tests
│   │   └── test_positive_value.sql
│   ├── unit/             # Unit tests
│   └── custom/           # Custom SQL tests
│       ├── test_articles_language_match_source.sql
│       ├── test_no_duplicate_articles_across_languages.sql
│       └── test_published_at_not_future.sql
```

## Best Practices

1. **Test Coverage**:
   - Every model should have at least one test
   - Critical columns should have multiple tests
   - Use appropriate test severity levels (error, warn)

2. **Test Organization**:
   - Group related tests together
   - Use descriptive test names
   - Document test purpose and assumptions

3. **Performance**:
   - Use incremental models for large datasets
   - Consider test execution time
   - Use appropriate test materialization

4. **Maintenance**:
   - Review and update tests regularly
   - Remove obsolete tests
   - Keep test documentation up to date

## Troubleshooting

Common test issues and solutions:

1. **Test Failures**:
   - Check test SQL syntax
   - Verify test dependencies
   - Review test data assumptions

2. **Performance Issues**:
   - Optimize test queries
   - Use appropriate test materialization
   - Consider test scheduling

3. **Configuration Issues**:
   - Verify dbt_project.yml settings
   - Check test package versions
   - Review environment variables 