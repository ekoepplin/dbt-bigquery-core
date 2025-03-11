-include .env
export

REPOSITORY=
DBT_FOLDER = dbt-bigquery-core
DBT_TARGET = dev
DBT_DATA_SOURCE = bigquery
DATABASE_NAME ?= dev_ekoepplin
DOCKER ?= false
DOCKER_CMD = 
DOCKER_IMAGE ?= ghcr.io/$(REPOSITORY)

ifeq ($(DOCKER),true)
    DOCKER_CMD = docker run --rm -w /app \
        -v $(GOOGLE_APPLICATION_CREDENTIALS):$(GOOGLE_APPLICATION_CREDENTIALS) \
        -e GOOGLE_APPLICATION_CREDENTIALS=$(GOOGLE_APPLICATION_CREDENTIALS) \
        $(DOCKER_IMAGE)
endif

## Docker 
build:
	docker build --label org.opencontainers.image.source=https://github.com/$(GITHUB_REPOSITORY) -t $(DOCKER_IMAGE) --build-arg PLATFORM=arm64 .

## Development
dbt-deps:
	$(DOCKER_CMD) dbt deps \
		--project-dir $$DBT_FOLDER \
		--profiles-dir $$DBT_FOLDER 

