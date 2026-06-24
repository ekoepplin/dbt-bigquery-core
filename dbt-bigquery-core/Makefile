# Variables
SODA_CONFIG := soda_testing/config.yml
DBT_TARGET := target
DBT_PROJECT := dbt_bigquery_core

.PHONY: all dbt-run dbt-test soda-ingest dbt-test-and-observe

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

# Run dbt tests then immediately push results to Soda Cloud
dbt-test-and-observe: dbt-test soda-ingest