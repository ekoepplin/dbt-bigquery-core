# Stage 1: Base
FROM python:3.12 as base

# Install Poetry
RUN pip install poetry --no-cache-dir

# Stage : Development
FROM base as development
# Set working directory
WORKDIR /app
# Copy Poetry configuration files
#COPY pyproject.toml poetry.lock ./
COPY pyproject.toml ./
# Install development dependencies
RUN poetry config virtualenvs.create false && poetry install

# Stage : Production
FROM base as production
# Set working directory
WORKDIR /app
# Copy Poetry configuration files
# COPY Makefile pyproject.toml poetry.lock ./
COPY Makefile pyproject.toml ./
# Copy the codebase
COPY ./dbt-bigquery-core ./dbt-bigquery-core
# Install only runtime dependencies
RUN poetry config virtualenvs.create false && poetry install --only main --no-interaction --no-ansi
RUN make dbt-deps

# Default command to keep container running for interactive `make` commands
CMD ["sleep", "infinity"]
