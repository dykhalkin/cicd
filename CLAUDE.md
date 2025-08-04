# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a CI/CD scaffolding repository that provides reusable GitHub Actions workflows and deployment scripts for Python API applications. The deployment approach uses systemd services with Python virtual environments, based on the AnkiChat deployment pattern.

## Architecture Overview

### Core Components

1. **Reusable GitHub Actions Workflow** (`.github/workflows/deploy-python-api.yml`)
   - Accepts parameters for app name, repository, branch, environment, and target server details
   - Runs tests and code quality checks on the source application
   - Executes deployment via SSH to target servers
   - Performs health checks post-deployment

2. **Deployment Script** (`scripts/deploy-python-api.sh`)
   - SSH-based deployment that clones/updates application code on target servers
   - Creates Python virtual environments and installs dependencies
   - Generates systemd service files dynamically
   - Manages service lifecycle (stop, start, enable)
   - Configures environment variables from JSON input

3. **Health Check Script** (`scripts/health-check.sh`)
   - Verifies systemd service status
   - Checks application logs for errors
   - Monitors system resources

### Deployment Flow

1. **Test Phase**: Code quality checks (black, isort, flake8, mypy) and pytest execution
2. **Deploy Phase**: SSH to target server, update code, configure service, restart
3. **Verify Phase**: Health checks and service status validation

### Service Architecture on Target Servers

Each deployed application follows this pattern:
- **Service Name**: `{app_name}-{environment}.service`
- **Application Directory**: `/opt/{app_name}-{environment}/`
- **Virtual Environment**: `{app_dir}/.venv/`
- **Log Directory**: `/var/log/{app_name}-{environment}/`
- **Service User**: `www-data`
- **Entry Point**: `src/main.py`

## Key Environment Variables

The deployment script requires these environment variables:
- `APP_NAME`, `REPO_NAME`, `BRANCH`, `ENVIRONMENT`, `APP_DIR`
- `SERVER_HOST`, `SERVER_USER` (for SSH access)
- `ENV_VARS` (JSON string containing application environment variables)

## Usage Pattern for AI Agents

When setting up deployment for a new Python API application, follow this workflow:

### 1. Create Deployment Workflow
Create `.github/workflows/deploy.yml` in the application repository:

```yaml
name: Deploy [APP_NAME]

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'staging'
        type: choice
        options: [staging, production]
      branch:
        description: 'Branch to deploy'
        required: true
        default: 'main'
        type: string
  push:
    branches: [main]

jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/main' || github.event.inputs.environment == 'staging'
    uses: breathman/cicd/.github/workflows/deploy-python-api.yml@main
    with:
      app_name: [APP_NAME]
      repo_name: [OWNER/REPO_NAME]
      branch: ${{ github.event.inputs.branch || 'main' }}
      environment: staging
      python_version: '3.9'
      app_directory: /opt/[APP_NAME]-staging
      skip_tests: false
      skip_quality_checks: false
    secrets:
      DEPLOY_KEY: ${{ secrets.STAGING_DEPLOY_KEY }}
      SERVER_HOST: ${{ secrets.STAGING_SERVER_HOST }}
      SERVER_USER: ${{ secrets.STAGING_SERVER_USER }}

  deploy-production:
    if: github.event.inputs.environment == 'production'
    needs: deploy-staging
    uses: breathman/cicd/.github/workflows/deploy-python-api.yml@main
    with:
      app_name: [APP_NAME]
      repo_name: [OWNER/REPO_NAME]
      branch: ${{ github.event.inputs.branch || 'main' }}
      environment: production
      python_version: '3.9'
      app_directory: /opt/[APP_NAME]-production
      skip_tests: false
      skip_quality_checks: false
    secrets:
      DEPLOY_KEY: ${{ secrets.PRODUCTION_DEPLOY_KEY }}
      SERVER_HOST: ${{ secrets.PRODUCTION_SERVER_HOST }}
      SERVER_USER: ${{ secrets.PRODUCTION_SERVER_USER }}
```

Replace `[APP_NAME]` with the application name and `[OWNER/REPO_NAME]` with the repository path.

### 2. Verify Application Compatibility
Ensure the target application has:
- `src/main.py` as the entry point
- `requirements.txt` with Python dependencies  
- Optional: `pyproject.toml` for code quality tools (black, isort, flake8, mypy)
- Optional: `pytest.ini` or pytest config in `pyproject.toml` for testing

### 3. Secrets Configuration Instructions
Provide these instructions to the user for configuring GitHub repository secrets:

**Required Secrets (per environment)**:
- `STAGING_DEPLOY_KEY` / `PRODUCTION_DEPLOY_KEY` - SSH private key for server access
- `STAGING_SERVER_HOST` / `PRODUCTION_SERVER_HOST` - Server IP or hostname
- `STAGING_SERVER_USER` / `PRODUCTION_SERVER_USER` - SSH username

**Environment Variables Configuration**:
The deployment script automatically creates a `.env` file on the target server using:
1. All environment variables starting with `APP_` prefix
2. Common application variables: `DATABASE_URL`, `API_KEY`, `LOG_LEVEL`, `PORT`, `HOST`, `DEBUG`

Set these as environment variables in your GitHub Actions workflow or repository environment settings.

**Optional Parameters**:
- `skip_tests: true` - Skip running pytest tests (useful for quick deployments)
- `skip_quality_checks: true` - Skip code quality checks (black, isort, etc.)
- `python_version` - Specify Python version (default: '3.12')

**Quick Deployment Example** (skip tests and quality checks):
```yaml
skip_tests: true
skip_quality_checks: true
```

### 4. Common Deployment Tasks for AI Agents

**When asked to "set up deployment" for a Python API**:
1. Check if `src/main.py` exists, if not guide user to restructure
2. Check if `requirements.txt` exists, if not create it from imports
3. Create the deployment workflow file with proper app_name and repo_name
4. Provide secrets configuration instructions to user
5. Offer to create `pyproject.toml` for code quality if desired

**When asked to "deploy to production"**:
1. Verify staging deployment exists and works
2. Ensure production secrets are configured
3. Guide user to use GitHub Actions UI or push workflow

**When deployment fails**:
1. Check service logs: `journalctl -u {app_name}-{environment} -f`
2. Verify application structure and dependencies
3. Check server requirements and permissions
4. Validate environment variables format

## Testing Deployment Scripts

To test the deployment scripts locally, you need to set the required environment variables and have SSH access to a target server. The scripts use `ssh` and `scp` commands with `StrictHostKeyChecking=no`.

## Application Requirements

Target applications must have:
- `requirements.txt` for Python dependencies
- `src/main.py` as the application entry point
- Optional: `pyproject.toml` for code quality tools
- Optional: `pytest.ini` or pytest configuration for testing