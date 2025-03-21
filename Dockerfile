# Stage 1: Base
FROM --platform=${TARGETPLATFORM:-linux/amd64} python:3.9.21 as base

# Install Poetry
RUN pip install poetry --no-cache-dir

# Stage : Development
FROM --platform=${TARGETPLATFORM:-linux/amd64} base as development
# Set working directory
WORKDIR /app
# Copy Poetry configuration files
COPY pyproject.toml poetry.lock ./
# Install development dependencies
RUN poetry config virtualenvs.create false && poetry install

# Stage : Production
FROM --platform=${TARGETPLATFORM:-linux/amd64} base as production
# Set working directory
WORKDIR /app
# Copy Poetry configuration files
COPY Makefile pyproject.toml poetry.lock ./
# Copy the codebase
COPY ./dbt-bigquery-core ./dbt-bigquery-core
# Install only runtime dependencies
RUN poetry config virtualenvs.create false && poetry install --only main --no-interaction --no-ansi
RUN make dbt-deps

# Default command to keep container running for interactive `make` commands
CMD ["sleep", "infinity"]
