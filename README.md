## Project Overview

This repository demonstrates a modern data quality engineering workflow:

1. **Data Ingestion**:
   - Uses `dlt` (data load tool) to load NewsAPI data into BigQuery
   - Serves as a simple example of data ingestion
   - Located in the `dlt-data-dumper` directory
   - Includes NewsAPI integration for article data collection

2. **Main Focus: Data Quality Engineering**:
   - **dbt Transformations**:
     - Structured data modeling with staging, intermediate, and mart layers
     - Demonstrates testing and documentation best practices
     - Shows how to implement data contracts and quality checks
   
   - **Soda Integration**:
     - Automated data quality monitoring
     - Integration with dbt metadata
     - Real-time quality checks and alerting
     - Data freshness and volume monitoring

The primary goal is to showcase how to implement robust data quality practices using dbt and Soda in a BigQuery environment.

## Quick Start

For detailed setup and usage instructions, please see our [GETTING_STARTED.md](GETTING_STARTED.md) guide, which includes:
- Development environment setup (Dev Container recommended for Windows users)
- Prerequisites and account requirements
- Step-by-step configuration
- Testing and data quality monitoring

For comprehensive testing documentation, including all test types, configurations, and best practices, see our [GETTING_STARTED_TESTING.md](GETTING_STARTED_TESTING.md) guide.

## Credential Setup
1. Create a `credentials` directory if it doesn't exist
2. Copy `credentials/soda-credentials.env.template` to `credentials/soda-credentials.env`
3. Add your service account JSON file as `credentials/service-account.json`
4. For dlt-data-dumper:
   - Create `credentials/dlt-secrets.toml` with the following structure:
     ```toml
     [destination.bigquery]
     location = "EU"

     [destination.bigquery.credentials]
     project_id = "your-project-id"
     private_key = "your-private-key"
     client_email = "your-service-account-email"

     [sources.newsapi_pipeline_to_gcs]
     api_key = "your-newsapi-key"

     [newsapi_pipeline_to_gcs.destination]
     schema_name = "ingest_newsapi_v1"
     ```
   - Replace the placeholder values with your actual credentials
5. Update the credentials files with your actual credentials

## Important Notes

- **Development Environment**: We recommend using VS Code with Dev Containers, especially for Windows users
- **Required Accounts**:
  - Google Cloud Platform with BigQuery access
  - Soda Cloud (45-day free trial available)
  - NewsAPI account (for data ingestion)
- **Learning Resources**: 
  - [dbt Fundamentals Course](https://learn.getdbt.com/courses/dbt-fundamentals) (Recommended)
  - Detailed documentation in GETTING_STARTED.md
  - Comprehensive testing guide in GETTING_STARTED_TESTING.md

For detailed setup instructions and best practices, please refer to our comprehensive [Getting Started Guide](GETTING_STARTED.md).