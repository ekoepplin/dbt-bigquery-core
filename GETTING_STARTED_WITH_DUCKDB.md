# Getting Started with DuckDB CLI

This guide focuses on using the DuckDB CLI with the existing dbt-bigquery-core project setup. The project uses DuckDB as a development database, with data stored at `/tmp/newsapi_articles.duckdb`.

## Table of Contents
1. [Basic Usage](#basic-usage)
2. [Working with Data](#working-with-data)
3. [Advanced Features](#advanced-features)
4. [Best Practices](#best-practices)

## Basic Usage

### Connecting to the Database
```bash
# Connect to the project's DuckDB database
duckdb /tmp/newsapi_articles.duckdb
```

### Basic Commands
```bash
# List all tables
.tables

# Show table schema
.schema articles_de_de
.schema articles_us_en

# Show table contents
SELECT * FROM ingest_newsapi_v1.articles_de_de LIMIT 5;
SELECT * FROM ingest_newsapi_v1.articles_us_en LIMIT 5;

# Exit DuckDB
.exit
```

## Working with Data

### Exploring the NewsAPI Data
```bash
# Count articles by source
SELECT source__name, COUNT(*) as article_count 
FROM  ingest_newsapi_v1.articles_de_de 
GROUP BY source__name 
ORDER BY article_count DESC;

# Find latest articles
SELECT title, published_at 
FROM ingest_newsapi_v1.articles_us_en 
ORDER BY published_at DESC 
LIMIT 5;

# Check data freshness
SELECT MAX(published_at) as latest_article 
FROM ingest_newsapi_v1.articles_us_en ;
```

### Exporting Data
```bash
# Export query results to CSV
COPY (
    SELECT * FROM articles_de_de 
    WHERE published_at > CURRENT_DATE - INTERVAL '1 day'
) TO 'recent_articles.csv' (HEADER, DELIMITER ',');

# Export to Parquet
COPY (
    SELECT * FROM articles_us_en 
    WHERE published_at > CURRENT_DATE - INTERVAL '1 day'
) TO 'recent_articles.parquet' (FORMAT PARQUET);
```

## Advanced Features

### Window Functions
```bash
# Calculate daily article counts
SELECT 
    DATE_TRUNC('day', published_at) as day,
    COUNT(*) as article_count,
    AVG(COUNT(*)) OVER (ORDER BY DATE_TRUNC('day', published_at) 
                        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as weekly_avg
FROM articles_de_de
GROUP BY 1
ORDER BY 1 DESC;
```

### Time Series Analysis
```bash
# Analyze article publication patterns
SELECT 
    HOUR(published_at) as hour_of_day,
    COUNT(*) as article_count,
    ROUND(AVG(COUNT(*)) OVER (), 2) as avg_count
FROM articles_us_en
GROUP BY 1
ORDER BY 1;
```

### Text Analysis
```bash
# Find most common words in titles
SELECT 
    word,
    COUNT(*) as frequency
FROM (
    SELECT UNNEST(STRING_SPLIT(LOWER(title), ' ')) as word
    FROM articles_de_de
    WHERE published_at > CURRENT_DATE - INTERVAL '7 days'
)
WHERE LENGTH(word) > 3
GROUP BY word
ORDER BY frequency DESC
LIMIT 20;
```

## Best Practices

1. **Query Optimization**
   - Use appropriate indexes
   - Filter data early in the query
   - Use appropriate join types
   - Limit result sets when exploring data

2. **Data Management**
   - Export large result sets to files
   - Use appropriate file formats (CSV for simple data, Parquet for complex)
   - Monitor database size

3. **Error Handling**
   - Check for NULL values
   - Validate data types
   - Use appropriate error handling in queries

4. **Performance Tips**
   - Use appropriate data types
   - Process data in chunks for large operations
   - Monitor query execution time

## Common Queries

### Data Quality Checks
```bash
# Check for missing values
SELECT 
    COUNT(*) as total_rows,
    COUNT(title) as non_null_titles,
    COUNT(author) as non_null_authors,
    COUNT(published_at) as non_null_dates
FROM articles_de_de;

# Check for future dates
SELECT COUNT(*) 
FROM articles_us_en 
WHERE published_at > CURRENT_TIMESTAMP;
```

### Content Analysis
```bash
# Analyze article length
SELECT 
    AVG(LENGTH(content)) as avg_length,
    MIN(LENGTH(content)) as min_length,
    MAX(LENGTH(content)) as max_length
FROM articles_de_de;

# Find most active authors
SELECT 
    author,
    COUNT(*) as article_count
FROM articles_us_en
WHERE author IS NOT NULL
GROUP BY author
ORDER BY article_count DESC
LIMIT 10;
```

## Next Steps

1. Explore the dbt models that use this data:
   - Staging models in `models/staging/`
   - Intermediate models in `models/intermediate/`
   - Mart models in `models/mart/`

2. Run dbt commands to transform the data:
   ```bash
   # From the project root
   make dbt-run
   make dbt-test
   ```

3. Check out the [dbt documentation](https://docs.getdbt.com) for more information about data transformation. 