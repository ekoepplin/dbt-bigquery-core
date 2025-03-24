# Stage 1: Base
FROM --platform=${TARGETPLATFORM:-linux/amd64} python:3.9.21 as base

# Install Poetry and DuckDB CLI with minimal dependencies
RUN pip install poetry --no-cache-dir && \
    apt-get update && \
    apt-get install -y \
    wget \
    unzip && \
    wget https://github.com/duckdb/duckdb/releases/download/v1.2.1/duckdb_cli-linux-amd64.zip && \
    unzip duckdb_cli-linux-amd64.zip -d /usr/local/bin && \
    rm duckdb_cli-linux-amd64.zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Stage : Development
FROM --platform=${TARGETPLATFORM:-linux/amd64} base as development
WORKDIR /app
COPY pyproject.toml poetry.lock ./
RUN poetry config virtualenvs.create false && poetry install

# Stage : Production
FROM --platform=${TARGETPLATFORM:-linux/amd64} base as production
WORKDIR /app
COPY Makefile pyproject.toml poetry.lock ./
COPY ./dbt-bigquery-core ./dbt-bigquery-core
RUN poetry config virtualenvs.create false && poetry install --only main --no-interaction --no-ansi
RUN make dbt-deps

# Expose DuckDB UI port
EXPOSE 4213

# Default command to keep container running for interactive `make` commands
CMD ["sleep", "infinity"]
