FROM --platform=${TARGETPLATFORM:-linux/amd64} python:3.9.21 as base

# Install Poetry
RUN pip install poetry --no-cache-dir
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
# Default command to keep container running for interactive `make` commands
CMD ["sleep", "infinity"]
