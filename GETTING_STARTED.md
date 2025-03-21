# Getting Started with dbt and Soda Integration

This guide will help you set up and run the dbt-bigquery-core project with Soda data quality testing integration. We recommend using Dev Containers for the easiest setup, especially on Windows.

## Prerequisites

- Windows, macOS, or Linux operating system
- For Dev Container setup (recommended, especially for Windows):
  - [VS Code](https://code.visualstudio.com/download)
  - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
  - VS Code "Remote - Containers" extension
- For local setup (alternative, more complex on Windows):
  - Python 3.9.x
  - Poetry
  - WSL2 (Windows only)
- Accounts needed:
  - Google Cloud Platform account with BigQuery access
  - Google Cloud Service Account with appropriate permissions
  - Soda Cloud account:
    - Sign up for a [45-day free trial](https://cloud.soda.io/signup)
    - The trial includes:
      - Full access to Soda Cloud features
      - Data quality monitoring dashboard
      - Alert configurations
      - Metadata management
      - Integration with dbt artifacts
    - After trial expiration, you'll need to upgrade to a paid plan to continue using Soda Cloud features

## Recommended Setup Using Dev Container

1. **Install Prerequisites**:
   - Install [VS Code](https://code.visualstudio.com/download)
   - Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Install the "Remote - Containers" extension in VS Code

2. **Clone and Open Project**:
   - Clone the repository
   - Open the project folder in VS Code
   - When prompted, click "Reopen in Container" or
   - Press F1, type "Remote-Containers: Reopen in Container"

3. **Set up credentials** (BEFORE opening the devcontainer):
   ```bash
   # Create credentials directory in your project root
   mkdir -p credentials
   
   # Copy your service account JSON file to credentials/service-account.json
   # This must be done BEFORE opening the devcontainer
   ```
   
   Create the soda-credentials.env file either:
   
   **Option 1: Using terminal commands**
   ```bash
   # Create with echo commands
   echo "SODA_CLOUD_API_KEY_ID=your_soda_api_key_id" > credentials/soda-credentials.env
   echo "SODA_CLOUD_API_KEY_SECRET=your_soda_api_key_secret" >> credentials/soda-credentials.env
   ```
   
   **Option 2: Create manually**
   - Create a new file at `credentials/soda-credentials.env`
   - Add the following lines, replacing with your actual credentials:
     ```
     SODA_CLOUD_API_KEY_ID=your_soda_api_key_id
     SODA_CLOUD_API_KEY_SECRET=your_soda_api_key_secret
     ```
   - Save the file

4. **Open the project in devcontainer**:
   - VS Code: Click on the green button in the bottom left > "Reopen in Container"
   - Or use the Command Palette (Ctrl+Shift+P) and select "Dev Containers: Reopen in Container"

## Alternative: Local Setup

If you prefer not to use Dev Containers, follow these steps:

1. Clone the repository and navigate to the project directory

2. Install dependencies using Poetry:
```bash
poetry install
```

3. Set up credentials:
   - Create a `credentials` directory if it doesn't exist
   - Copy `credentials/soda-credentials.env.template` to `credentials/soda-credentials.env`
   - Add your Google Cloud service account JSON file as `credentials/service-account.json`
   - Update the credentials files with your actual credentials

4. Configure environment variables:
```bash
export GOOGLE_SERVICE_ACCOUNT_KEY_PATH=/path/to/credentials/service-account.json
export SODA_CLOUD_API_KEY_ID=your_soda_api_key_id
export SODA_CLOUD_API_KEY_SECRET=your_soda_api_key_secret
```

## Development Environment Options

### 1. Development Container (Recommended)
This project is optimized for development using VS Code Dev Containers, which provides a consistent, isolated development environment:

1. **Benefits of Dev Container**:
   - Works identically on Windows, macOS, and Linux
   - No need to install Python, Poetry, or other tools locally
   - Avoids common Windows-specific issues
   - Pre-configured environment matches production
   - Automatic port forwarding for development

2. **Container Features**:
   - Poetry for dependency management
   - Pre-configured dbt and Soda tools
   - Development and production stages available
   - WSL2 integration on Windows
   - Git configuration persistence

3. **Working with the Container**:
   - Use VS Code's integrated terminal (it's already in the container)
   - Files edited in VS Code are automatically synchronized
   - Debugging tools are pre-configured
   - Extensions are automatically installed

### 2. Local Development
The local setup described earlier is available but requires additional configuration, especially on Windows:
- WSL2 installation and configuration
- Python version management
- Manual dependency installation
- Environment variable setup in Windows

## Project Structure

```
dbt-bigquery-core/
├── models/                    # dbt models
│   ├── staging/              # Staging models
│   ├── intermediate/         # Intermediate models
│   └── mart/                 # Mart (final) models
├── tests/                    # dbt and custom tests
├── soda_testing/            # Soda configuration
└── dbt_project.yml         # dbt project configuration
```

## Running the Pipeline

The project uses a Makefile for common operations. Here are the main commands:

1. Run the complete pipeline:
```bash
make all
```

This will execute:
- `make dbt-run`: Runs all dbt models
- `make dbt-test`: Runs dbt tests
- `make soda-ingest`: Runs Soda data quality checks

2. Run individual components:
```bash
# Run only dbt models
make dbt-run

# Run only dbt tests
make dbt-test

# Run only Soda checks
make soda-ingest
```

## dbt Configuration

The project uses dbt with BigQuery. Key configuration files:

1. `profiles.yml`: Contains BigQuery connection settings
2. `dbt_project.yml`: Defines project structure and model configurations
3. `packages.yml`: Lists dbt package dependencies

## Soda Integration

Soda is integrated for data quality monitoring. Configuration is in:

1. `soda_testing/config.yml`: Main Soda configuration file
2. The pipeline automatically runs Soda checks after dbt transformations

## Model Organization

The dbt models are organized in layers:

1. **Staging (`models/staging/`)**: 
   - Raw data ingestion
   - Basic cleaning and typing

2. **Intermediate (`models/intermediate/`)**:
   - Combined and transformed data
   - Business logic implementation

3. **Mart (`models/mart/`)**:
   - Final presentation layer
   - Aggregated and ready-to-use tables

## Testing

For comprehensive information about testing in this project, including:
- Generic tests (built-in and custom)
- Custom SQL tests
- Unit tests
- Freshness tests
- Volume tests
- Data contracts
- SQL linting
- Best practices and troubleshooting

Please refer to our detailed [Testing Guide](GETTING_STARTED_TESTING.md).

## Troubleshooting

Common issues and solutions:

1. **BigQuery Authentication**:
   - Ensure `GOOGLE_SERVICE_ACCOUNT_KEY_PATH` points to a valid service account JSON file
   - Verify the service account has necessary BigQuery permissions

2. **Soda Connection**:
   - Check Soda Cloud credentials in environment variables
   - Verify Soda configuration in `soda_testing/config.yml`

3. **dbt Issues**:
   - Run `dbt debug` to check configuration
   - Ensure profiles.yml is properly configured
   - Check for package compatibility in packages.yml

## Learning Resources

### dbt Fundamentals Course

We highly recommend taking the [dbt Fundamentals course](https://learn.getdbt.com/courses/dbt-fundamentals) before diving deep into development. This free course covers:

1. **Core Concepts**:
   - Data modeling fundamentals
   - dbt project structure
   - Writing models in SQL
   - Model materialization strategies

2. **Development Best Practices**:
   - Source configuration
   - Testing strategies
   - Documentation
   - Version control integration

3. **Advanced Topics**:
   - Incremental models
   - Seeds and snapshots
   - Package management
   - Macros and Jinja

The course provides hands-on exercises and is an excellent foundation for working with this project.

## Next Steps

1. Review the model documentation in the .yml files
2. Explore the test coverage in the tests/ directory
3. Set up your own data quality checks in Soda
4. Customize the models according to your needs

For more detailed information:
- dbt documentation: https://docs.getdbt.com
- Soda documentation: https://docs.soda.io
- Project testing guide: [GETTING_STARTED_TESTING.md](GETTING_STARTED_TESTING.md)

## Getting started with dbt

- [What is dbt](https://docs.getdbt.com/docs/introduction)?
- Read the [dbt viewpoint](https://docs.getdbt.com/docs/about/viewpoint)
- [Installation](https://docs.getdbt.com/docs/get-started/getting-started/overview)
- Join the [chat](https://www.getdbt.com/community/) on Slack for live questions and support.

### Setting up GCP Service Account for BigQuery

1. Create a service account in GCP Console:
   - Navigate to "IAM & Admin" > "Service Accounts"
   - Click "Create Service Account"
   - Give it a name and description

2. Assign required roles:
   - `BigQuery Data Editor` - For creating and modifying tables
   - `BigQuery Job User` - For running queries and jobs
   - `BigQuery Read Session User` - For reading data from BigQuery

3. Create and download key:
   - Click on your service account
   - Go to "Keys" tab
   - Add new key (JSON format)
   - Save the downloaded JSON file as `credentials/service-account.json`

For detailed instructions, refer to [GCP's official documentation on creating service accounts](https://cloud.google.com/iam/docs/creating-managing-service-accounts). 