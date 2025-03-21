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
	$(DOCKER_CMD) dbt deps \
		--project-dir $$DBT_FOLDER \
		--profiles-dir $$DBT_FOLDER 

