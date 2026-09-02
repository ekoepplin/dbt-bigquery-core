SHOW ALL TABLES;

SHOW ingest_newsapi_v1.int_newsapi__articles

duckdb /tmp/newsapi_articles.duckdb "SHOW ingest_newsapi_v1.int_newsapi__articles;"

datacontract test datacontract.yaml

# Example import from dbt manifest with specifying the tables to import
datacontract import --format dbt --source /Users/ekoepplin/repos/dbt-bigquery-core/dbt-bigquery-core/target/manifest.json --dbt-model int_newsapi__articles >   /Users/ekoepplin/repos/dbt-bigquery-core/dbt-bigquery-core/data_contracts/datacontract.yaml



