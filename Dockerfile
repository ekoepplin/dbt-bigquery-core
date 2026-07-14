FROM --platform=${TARGETPLATFORM:-linux/amd64} python:3.13 as base

ENV UV_SYSTEM_PYTHON=1

# Install uv, Node.js, and DuckDB CLI
RUN pip install uv --no-cache-dir && \
    apt-get update && \
    apt-get install -y wget unzip curl zsh git && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then DUCKDB_ARCH="aarch64"; else DUCKDB_ARCH="amd64"; fi && \
    wget https://github.com/duckdb/duckdb/releases/download/v1.2.1/duckdb_cli-linux-${DUCKDB_ARCH}.zip && \
    unzip duckdb_cli-linux-${DUCKDB_ARCH}.zip -d /usr/local/bin && \
    rm duckdb_cli-linux-${DUCKDB_ARCH}.zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Stage : Development
FROM base as development
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync && \
    npm install -g @anthropic-ai/claude-code && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
ENV SHELL=/usr/bin/zsh

# Stage : Production
FROM base as production
WORKDIR /app
COPY Makefile pyproject.toml uv.lock ./
COPY ./dbt-bigquery-core ./dbt-bigquery-core
RUN uv sync --no-dev
RUN make dbt-deps
# Default command to keep container running for interactive `make` commands
CMD ["sleep", "infinity"]
