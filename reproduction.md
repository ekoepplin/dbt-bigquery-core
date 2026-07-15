# Reproduction Spec — Two-Layer Data Contracts for a dlt → dbt Pipeline

**Audience:** an AI coding agent (Copilot, Claude, Cursor, …) tasked with
recreating this setup in *another* project. This is a self-contained
implementation brief: follow the tasks in order, substitute the placeholders,
and run the acceptance check after each task. Do **not** skip the acceptance
checks — several steps have non-obvious failure modes documented in
[§8 Gotchas](#8-validated-gotchas).

---

## 1. Objective

Add **two independent layers of data contract** to an ingestion→transform
pipeline, so it is guaranteed at *both* ends:

1. **Inbound (ODCS / `datacontract-cli`)** — a standalone contract on the raw
   feed *as it lands*, testable against a parquet dump with no warehouse.
2. **Internal (dbt native model contracts)** — build-time schema enforcement
   on the transformation models.
3. **Outbound (ODCS / `datacontract-cli`)** — a published contract on the
   final mart that non-dbt consumers can point at, diff, and test.

Target architecture:

```
raw source ──(dlt)──▶ raw tables ─┐
                └──(dlt filesystem)──▶ raw parquet  ◀── 🟠 inbound ODCS contract
                                          │
                                   dbt staging (source)
                                          │
                              dbt intermediate (VIEW) ◀── 🔵 dbt contract
                                          │
                                dbt mart (TABLE) ◀────── 🔵 dbt contract
                                          │            └─ 🟠 outbound ODCS contract
                                     consumers
```

The two ODCS contracts and the dbt contracts are **maintained
independently** — enabling one does nothing to the other; they are chained
in CI ([§7](#7-ci-gates)), not coupled in code.

---

## 2. Placeholders to substitute

Replace these throughout when applying to your project:

| Placeholder | This reference project | Your value |
|---|---|---|
| `<SOURCE_SYSTEM>` | NewsAPI | ? |
| `<PIPELINE_DIR>` | `dlt-data-dumper` | ? |
| `<DBT_DIR>` | `dbt-bigquery-core` | ? |
| `<SCHEMA>` (dataset) | `ingest_newsapi_v1` | ? |
| `<RAW_TABLE>` | `articles_us_en` | ? |
| `<RAW_COLUMNS>` | `author, title, url, published_at, source__id, …` | ? |
| `<MART_MODEL>` | `mart_newsapi__daily_articles` | ? |
| `<INT_MODEL>` | `int_newsapi__articles` | ? |
| `<DEV_DB_PATH>` | `/tmp/newsapi_articles.duckdb` | ? |
| `<RAW_BUCKET>` | `file:///tmp/newsapi_raw` | ? |

**Design rule that stays constant:** dev target = **DuckDB** (no cloud creds,
fully local); prod target = your warehouse (BigQuery/Snowflake/…). Everything
below is validated on the DuckDB/local path so the whole thing runs in CI
with zero credentials.

---

## 3. Prerequisites & dependencies

Use **`uv`** for Python deps (Python `>=3.13`). Add to `pyproject.toml`:

```toml
[project]
requires-python = ">=3.13"
dependencies = [
    "duckdb>=1.5.4",
    "pyarrow>=24.0.0",                 # parquet read/write
    "dbt-core>=1.11.0,<2.0.0",
    "dbt-duckdb>=1.10.1",              # dev target
    # "dbt-<your-warehouse>>=1.11.0",  # prod target
    "dlt[filesystem]>=1.28.0,<2.0.0",  # filesystem extra = native parquet landing
]

[dependency-groups]
dev = [
    "datacontract-cli[duckdb]>=1.0.12,<2.0.0",   # NOT [all] — see Gotcha #1
]
```

dbt packages (`<DBT_DIR>/packages.yml`) — only `dbt_expectations` is required
for the quality tests mirrored into the ODCS contract:

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
  - package: metaplane/dbt_expectations
    version: 0.8.5
```

Install & sanity-check:

```bash
uv sync
uv run datacontract --version      # expect 1.0.12+
uv run dbt deps --project-dir <DBT_DIR> --profiles-dir <DBT_DIR>
```

**Acceptance:** all three commands exit 0.

---

## 4. Task list (do in order)

### T1 — dlt pipeline with a native `filesystem` (parquet) destination

The pipeline must support **three** destinations selected by flag: warehouse
(prod), DuckDB (`--test`, dev), and **filesystem** (`--filesystem`, lands
parquet natively). Add this shape to `<PIPELINE_DIR>/<pipeline>.py`:

```python
import dlt

DEFAULT_RAW_BUCKET_URL = "<RAW_BUCKET>"   # e.g. file:///tmp/newsapi_raw

def _raw_bucket_url() -> str:
    # dlt resolves the env var NAMESPACE__DESTINATION__BUCKET_URL automatically
    return dlt.config.get("<pipeline>.destination.bucket_url", str) or DEFAULT_RAW_BUCKET_URL

def run_pipeline(destination="warehouse", full_refresh=False):
    run_kwargs = {"write_disposition": "replace" if full_refresh else "append"}
    if destination == "duckdb":
        pipeline = dlt.pipeline(pipeline_name="<name>",
            destination=dlt.destinations.duckdb("<DEV_DB_PATH>"),
            dataset_name="<SCHEMA>")
    elif destination == "filesystem":
        pipeline = dlt.pipeline(pipeline_name="<name>",
            destination=dlt.destinations.filesystem(bucket_url=_raw_bucket_url()),
            dataset_name="<SCHEMA>")
        run_kwargs["loader_file_format"] = "parquet"     # <-- native parquet
    else:
        pipeline = dlt.pipeline(pipeline_name="<name>",
            destination=destination, dataset_name="<SCHEMA>")
    pipeline.run(your_source(), **run_kwargs)
```

**Layout dlt produces** (memorise — the contract path depends on it):
`<bucket>/<SCHEMA>/<RAW_TABLE>/<load_id>.<file_id>.parquet` — **one file per
load**, so downstream globs must end in `<RAW_TABLE>/*.parquet`.

**Acceptance:** `python <pipeline>.py --filesystem` (or a seeded run) creates
`.parquet` files under `<RAW_BUCKET>/<SCHEMA>/<RAW_TABLE>/`; the parquet
schema matches the warehouse table (dlt flattens nested objects to
`parent__child` and adds `_dlt_load_id`/`_dlt_id` in *both* destinations, so
one contract covers both).

### T2 — dbt models with native contracts

Two models get `contract.enforced: true`. **Prerequisite:** every returned
column must have an explicit `data_type` in the model's `.yml`.

- **Intermediate** (`+materialized: view`) — contract checks names/types only.
- **Mart** (`+materialized: table`) — contract also enforces `not_null` in DDL.

`<DBT_DIR>/models/.../<MART_MODEL>.yml`:

```yaml
models:
  - name: <MART_MODEL>
    config:
      contract:
        enforced: true
    columns:
      - name: article_date
        data_type: date
        tests: [not_null, unique]
      - name: article_count
        data_type: integer          # see Gotcha #3 (BIGINT vs INTEGER)
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              arguments: { min_value: 1, max_value: 10000 }
```

The raw feed enters as a dbt **source** — sources **cannot** hold a dbt
contract; that gap is exactly what the inbound ODCS contract (T3) fills.

**Acceptance:** `uv run dbt build --project-dir <DBT_DIR> --profiles-dir
<DBT_DIR> --select <MART_MODEL> <INT_MODEL> --target dev` succeeds.

### T3 — Inbound ODCS contract (bootstrap, don't hand-write)

Generate from a **real** parquet dump, then hand-enrich:

```bash
mkdir -p /tmp/dc_exports
# offline dump from the dev duckdb (no creds), OR use a native --filesystem file
uv run python3 -c "import duckdb;con=duckdb.connect('<DEV_DB_PATH>',read_only=True);\
con.sql(\"COPY (SELECT * FROM <SCHEMA>.<RAW_TABLE>) TO '/tmp/dc_exports/<RAW_TABLE>.parquet' (FORMAT PARQUET)\")"

uv run datacontract import parquet \
  --source /tmp/dc_exports/<RAW_TABLE>.parquet \
  --output data_contracts/<name>_raw.datacontract.yaml
```

Then hand-enrich the generated file with what `import` can't infer:
- `id`, `team.name` / owner = the **upstream vendor** (make the "vendor
  agreement" real), `description.purpose/usage/limitations`.
- `servers:` — **two** local test servers (both `type: local, format: parquet`):
  - `local_raw` → the offline single-file export path above.
  - `local_raw_native` → the dlt glob `<RAW_BUCKET path>/<RAW_TABLE>/*.parquet`.
- `quality:` — a `rowCount >= 1` library check + a `type: sql` check.
  **The SQL must use the literal table name, never `${table}`/`${column}`
  placeholders** (Gotcha #4).

```yaml
servers:
- server: local_raw
  type: local
  format: parquet
  path: /tmp/dc_exports/<RAW_TABLE>.parquet
- server: local_raw_native
  type: local
  format: parquet
  path: <RAW_BUCKET_FS_PATH>/<SCHEMA>/<RAW_TABLE>/*.parquet   # glob!
schema:
- name: <RAW_TABLE>
  physicalType: parquet
  quality:
  - type: library
    metric: rowCount
    mustBeGreaterOrEqualTo: 1
  properties:
  - name: published_at
    physicalType: TIMESTAMP
    logicalType: timestamp
    required: true
    quality:
    - type: sql
      query: "SELECT COUNT(*) FROM <RAW_TABLE> WHERE published_at IS NULL"
      mustBe: 0
```

**Acceptance:** `datacontract lint` is 🟢, and `datacontract test --server
local_raw` passes all checks against real data.

### T4 — Outbound ODCS contract (from the dbt manifest)

```bash
uv run dbt build --project-dir <DBT_DIR> --profiles-dir <DBT_DIR> --target dev  # writes target/manifest.json
uv run datacontract import dbt \
  --source <DBT_DIR>/target/manifest.json \
  --model <MART_MODEL> \
  --output data_contracts/<name>_mart.datacontract.yaml
```

Hand-enrich with `servers` (dev `type: duckdb`, prod your warehouse, and a
`local_dev` `type: local, format: parquet`), SLAs, ownership, and quality
checks mirroring the mart's `dbt_expectations` tests. Note: `type: duckdb`
catalog files **cannot** be tested live (Gotcha #6) — test the exported
parquet via the `local_dev` server instead.

**Acceptance:** `datacontract lint` 🟢; `datacontract test --server local_dev`
passes after exporting the mart table to parquet.

### T5 — Makefile targets

```makefile
DC = uv run datacontract
DBT = uv run dbt
DBT_DIR = <DBT_DIR>
EXPORT_DIR = /tmp/dc_exports

# --- inbound (raw) ---
dump-raw-parquet:                      # native landing (needs source creds)
	cd <PIPELINE_DIR> && uv run python3 <pipeline>.py --filesystem
data-contract-raw-lint:
	$(DC) lint data_contracts/<name>_raw.datacontract.yaml
data-contract-raw-test:                # offline: export then test
	mkdir -p $(EXPORT_DIR)
	uv run python3 -c "import duckdb;con=duckdb.connect('<DEV_DB_PATH>',read_only=True);con.sql(\"COPY (SELECT * FROM <SCHEMA>.<RAW_TABLE>) TO '$(EXPORT_DIR)/<RAW_TABLE>.parquet' (FORMAT PARQUET)\")"
	$(DC) test data_contracts/<name>_raw.datacontract.yaml --server local_raw
data-contract-raw-test-native:         # test the native dlt parquet glob
	$(DC) test data_contracts/<name>_raw.datacontract.yaml --server local_raw_native

# --- internal (dbt) ---
dbt-contract-test:
	$(DBT) build --project-dir $(DBT_DIR) --profiles-dir $(DBT_DIR) --select <MART_MODEL> <INT_MODEL>

# --- outbound (mart) ---
data-contract-lint:
	$(DC) lint data_contracts/<name>_mart.datacontract.yaml
data-contract-test:
	mkdir -p $(EXPORT_DIR)
	uv run python3 -c "import duckdb;con=duckdb.connect('<DEV_DB_PATH>',read_only=True);con.sql(\"COPY (SELECT * FROM <SCHEMA>.<MART_MODEL>) TO '$(EXPORT_DIR)/<MART_MODEL>.parquet' (FORMAT PARQUET)\")"
	$(DC) test data_contracts/<name>_mart.datacontract.yaml --server local_dev
```

**Acceptance:** all seven targets run green (see [§9](#9-final-acceptance)).

---

## 5. Adversarial self-check (prove the tests actually run)

A contract that only ever passes is worthless. For each `test` target, once:
temporarily invert one quality check (e.g. `IS NULL` → `IS NOT NULL`) in a
throwaway copy and confirm it **fails with a non-zero exit**. Then revert.

```bash
cp data_contracts/<name>_raw.datacontract.yaml /tmp/adv.yaml
sed -i 's/IS NULL/IS NOT NULL/' /tmp/adv.yaml
uv run datacontract test /tmp/adv.yaml --server local_raw; echo "exit=$?"   # expect 🔴 exit=1
```

---

## 6. Where the dbt layer adds capabilities the ODCS file doesn't

Keep both — they are not substitutes. dbt contracts uniquely give you:
- **Build-time hard-stop:** a violating model is never created; no separate
  command to remember.
- **Constraint enforcement in DDL** (materialization- and platform-dependent
  — see matrix below).
- **Model versions** (`versions:` + `dbt build --select state:modified+`) —
  the internal analogue of `datacontract changelog`.

Constraint enforcement matrix (verify for your warehouse):

| | `not_null` | `primary_key`/`unique` | `check` |
|---|:---:|:---:|:---:|
| DuckDB (dev) | ✅ | ✅ (unique) / definable | ❌ |
| BigQuery (prod) | ✅ | definable, **not** enforced | ❌ |

⇒ a `unique` that passes on DuckDB won't block dupes on BigQuery — keep a real
dedup dbt test *and* an ODCS quality check as backstops.

---

## 7. CI gates

Run front-to-back so a break is caught at the earliest stage:

```
1. make data-contract-raw-lint  &&  make data-contract-raw-test     # 🟠 inbound
2. make data-contract-lint                                          # 🟠 outbound (fail fast on bad YAML)
3. make dbt-contract-test                                           # 🔵 dbt build, contracts enforced
4. make data-contract-test                                          # 🟠 outbound live data check
5. uv run datacontract changelog <base>_mart.yaml <head>_mart.yaml  # 🟠 flag breaking changes to consumers
```

---

## 8. Validated gotchas

These were all hit and fixed while building the reference project — treat as
hard requirements, not trivia.

1. **`datacontract-cli[all]` breaks `uv lock`.** `[all]` pulls
   `duckdb-extension-aws` which pins `duckdb<=1.5.3`, conflicting with
   `duckdb>=1.5.4`. Use the **narrow extra for your server type**
   (`[duckdb]`, `[bigquery]`, …), never `[all]`.
2. **dlt filesystem writes one parquet per load.** The ODCS `local` server
   `path` MUST be a glob `.../<RAW_TABLE>/*.parquet`. datacontract-cli passes
   it to DuckDB `read_parquet`, which expands globs.
3. **Aggregate return types drift.** `COUNT(*)` is `BIGINT` in DuckDB but a
   contract usually says `INTEGER` → contract fails. Fix in the *model*:
   `CAST(COUNT(*) AS INTEGER)` (also valid on BigQuery). Decide per case
   whether the model or the contract is wrong — don't reflexively loosen the
   contract.
4. **ODCS `type: sql` checks use literal names, not `${table}`/`${column}`.**
   Placeholders are pasted verbatim and fail with a `$` syntax error. Also:
   literal names aren't schema-qualified, so a SQL check isn't portable across
   differently-schemad dev/prod targets — prefer library checks
   (`rowCount`, `missingCount`) where possible.
5. **Timezone types.** A tz-aware source column (`timestamp with time zone`)
   fails a contract that declares plain `timestamp`. Match reality; don't
   strip the tz.
6. **`datacontract test` can't test a live `type: duckdb` catalog file** (no
   connector as of 1.0.12) — it only warns. Its DuckDB engine backs
   `local`/`s3`/`gcs`/`azure` **file** servers. Workaround: export the table
   to parquet and test a `type: local, format: parquet` server.
7. **Avro is import-only for testing.** `import avro` (from `.avsc`) works,
   but `test` has **no avro reader** — file servers accept only
   `json`/`parquet`/`csv`/`delta`. For avro-landed data, convert/land as
   parquet for the live test step. **Prefer parquet** — it's the only format
   with a complete round trip.
8. **`datacontract export dbt-models` is lossy.** Types generalise (e.g.
   `integer`→`NUMBER`, tz-timestamp→`TIMESTAMP_TZ`). Use it as a starting
   point/consistency check; dbt stays the source of truth for types.
9. **Don't run `datacontract dbt sync` unattended.** It rewrites model YAML
   in place and breaks `dbt parse` project-wide if a model already has a
   top-level `meta:` (adds a second under `config.meta`). Keep the ODCS and
   dbt contracts as two independently-maintained files.
10. **Invoke via `uv run`** (or an activated venv). Bridge commands that shell
    out to `dbt` only find it on `PATH` under `uv run`, not via a direct
    `.venv/bin/...` path.

---

## 9. Final acceptance

The reproduction is complete when, from a clean checkout with **no cloud
credentials**, every one of these is green:

```bash
uv sync
uv run dbt deps --project-dir <DBT_DIR> --profiles-dir <DBT_DIR>
uv run dbt build --project-dir <DBT_DIR> --profiles-dir <DBT_DIR> --target dev   # seeds dev duckdb
make data-contract-raw-lint          # 🟢 1 check
make data-contract-raw-test          # 🟢 all checks, real data
make data-contract-raw-test-native   # 🟢 (after `make dump-raw-parquet` OR a seeded native landing)
make data-contract-lint              # 🟢 1 check
make data-contract-test              # 🟢 all checks
make dbt-contract-test               # 🟢 dbt build, contracts enforced
```

Plus the [§5 adversarial](#5-adversarial-self-check-prove-the-tests-actually-run)
check fails as expected (exit=1) for at least one inverted quality rule.

> Versions this was validated against: dbt-core 1.11.12, datacontract-cli
> 1.0.12, dlt 1.28.1, duckdb 1.5.4, Python 3.13. If a newer `datacontract-cli`
> adds a native `duckdb` connector or an avro reader, re-verify gotchas 6–7
> before relying on the workarounds.
