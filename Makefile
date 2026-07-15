-include .env
export

DBT_FOLDER = dbt-bigquery-core
DOCKER ?= false
DOCKER_CMD = 

ifeq ($(DOCKER),true)
    DOCKER_CMD = docker run --rm -w /app \
        -v $(GOOGLE_APPLICATION_CREDENTIALS):$(GOOGLE_APPLICATION_CREDENTIALS) \
        -e GOOGLE_APPLICATION_CREDENTIALS=$(GOOGLE_APPLICATION_CREDENTIALS)
endif

## Development
dbt-deps:
	$(DOCKER_CMD) uv run dbt deps \
		--project-dir $$DBT_FOLDER \
		--profiles-dir $$DBT_FOLDER

## Data Contracts
# dbt's native, build-time model contracts (schema shape enforced by dbt itself)
dbt-contract-test:
	$(DOCKER_CMD) uv run dbt build \
		--project-dir $$DBT_FOLDER \
		--profiles-dir $$DBT_FOLDER \
		--select mart_newsapi__daily_articles int_newsapi__articles

# datacontract-cli (project dev dependency, see GETTING_STARTED_DATA_CONTRACTS.md)
DATACONTRACT_CMD = uv run datacontract
CONTRACT_EXPORT_DIR = /tmp/datacontract_exports

data-contract-lint:
	$(DATACONTRACT_CMD) lint data_contracts/newsapi_mart.datacontract.yaml

# `type: duckdb` has no live-test connector in datacontract-cli, so this
# exports the dev mart to parquet first and tests that snapshot instead
# (the `local_dev` server in data_contracts/newsapi_mart.datacontract.yaml)
data-contract-test:
	mkdir -p $(CONTRACT_EXPORT_DIR)
	uv run python3 -c "import duckdb; con = duckdb.connect('/tmp/newsapi_articles.duckdb', read_only=True); con.sql(\"COPY (SELECT * FROM ingest_newsapi_v1.mart_newsapi__daily_articles) TO '$(CONTRACT_EXPORT_DIR)/mart_newsapi__daily_articles.parquet' (FORMAT PARQUET)\")"
	$(DATACONTRACT_CMD) test data_contracts/newsapi_mart.datacontract.yaml --server local_dev

# Inbound contract on the raw NewsAPI feed (before dbt) — see
# GETTING_STARTED_DATA_CONTRACTS.md, Part 2a
data-contract-raw-lint:
	$(DATACONTRACT_CMD) lint data_contracts/newsapi_raw.datacontract.yaml

# Same export-then-test pattern as data-contract-test, but for the raw dlt
# source table `articles_us_en` (the `local_raw` server in
# data_contracts/newsapi_raw.datacontract.yaml)
data-contract-raw-test:
	mkdir -p $(CONTRACT_EXPORT_DIR)
	uv run python3 -c "import duckdb; con = duckdb.connect('/tmp/newsapi_articles.duckdb', read_only=True); con.sql(\"COPY (SELECT * FROM ingest_newsapi_v1.articles_us_en) TO '$(CONTRACT_EXPORT_DIR)/raw_newsapi__articles_us_en.parquet' (FORMAT PARQUET)\")"
	$(DATACONTRACT_CMD) test data_contracts/newsapi_raw.datacontract.yaml --server local_raw

# Land the raw feed NATIVELY as parquet via the dlt filesystem destination
# (no warehouse). Needs a NewsAPI key in dlt-data-dumper/.dlt/secrets.toml,
# since it fetches live. Files land under file:///tmp/newsapi_raw by default
# (override with the dlt env var NEWSAPI_PIPELINE__DESTINATION__BUCKET_URL).
dump-raw-parquet:
	cd dlt-data-dumper && uv run python3 newsapi_pipeline.py --filesystem

# Test the contract against the natively-landed parquet (the `local_raw_native`
# server, a *.parquet glob over the dlt filesystem output). Run
# `make dump-raw-parquet` first to produce the files.
data-contract-raw-test-native:
	$(DATACONTRACT_CMD) test data_contracts/newsapi_raw.datacontract.yaml --server local_raw_native

