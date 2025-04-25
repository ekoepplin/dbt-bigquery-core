# Variables
SODA_CONFIG := soda_testing/config.yml
DBT_TARGET := target
DBT_PROJECT := dbt_bigquery_core

.PHONY: all dbt-run dbt-test soda-ingest

# Default target
all: dbt-run dbt-test soda-ingest

# Run dbt models
dbt-run:
	@echo "Running dbt models..."
	dbt run

# Test dbt models
dbt-test:
	@echo "Testing dbt models..."
	dbt test

# Run Soda ingest
soda-ingest: 
	@echo "Running Soda ingest..."
	soda ingest dbt -d $(DBT_PROJECT) -c $(SODA_CONFIG) --dbt-artifacts $(DBT_TARGET)

# Run Soda ingest
ingest-newsapi-data-test: 
	@echo "Running ingest for newsapi data in test mode..."
	cd ../dlt-data-dumper && $(MAKE) test

ingest-newsapi-data-prod: 
	@echo "Running ingest for newsapi data in production mode..."
	cd ../dlt-data-dumper && $(MAKE) run