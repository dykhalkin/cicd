# Python API CI/CD Scaffolding

This repository provides a reusable CI/CD pipeline scaffolding for deploying Python API applications using systemd services, based on the AnkiChat deployment approach.

## Structure

```
cicd/
├── .github/workflows/
│   ├── deploy-python-api.yml      # Reusable workflow template
│   └── ankichat-deploy.yml         # Example implementation for AnkiChat
├── scripts/
│   ├── deploy-python-api.sh        # Main deployment script
│   └── health-check.sh             # Health check script
└── README.md
```

## Usage

### 1. Using the Reusable Workflow (Recommended)

Create a deployment workflow in your application repository by creating `.github/workflows/deploy.yml` that calls the reusable workflow:

```yaml
name: Deploy My App

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production
      branch:
        description: 'Branch to deploy'
        required: true
        default: 'main'
        type: string
  push:
    branches:
      - main  # Auto-deploy main branch to staging

jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/main' || github.event.inputs.environment == 'staging'
    uses: breathman/cicd/.github/workflows/deploy-python-api.yml@main
    with:
      app_name: myapp
      repo_name: myusername/myapp
      branch: ${{ github.event.inputs.branch || 'main' }}
      environment: staging
      python_version: '3.9'
      app_directory: /opt/myapp-staging
    secrets:
      DEPLOY_KEY: ${{ secrets.STAGING_DEPLOY_KEY }}
      SERVER_HOST: ${{ secrets.STAGING_SERVER_HOST }}
      SERVER_USER: ${{ secrets.STAGING_SERVER_USER }}
      ENV_VARS: ${{ secrets.STAGING_ENV_VARS }}

  deploy-production:
    if: github.event.inputs.environment == 'production'
    needs: deploy-staging  # Ensure staging deployment succeeds first
    uses: breathman/cicd/.github/workflows/deploy-python-api.yml@main
    with:
      app_name: myapp
      repo_name: myusername/myapp
      branch: ${{ github.event.inputs.branch || 'main' }}
      environment: production
      python_version: '3.9'
      app_directory: /opt/myapp-production
    secrets:
      DEPLOY_KEY: ${{ secrets.PRODUCTION_DEPLOY_KEY }}
      SERVER_HOST: ${{ secrets.PRODUCTION_SERVER_HOST }}
      SERVER_USER: ${{ secrets.PRODUCTION_SERVER_USER }}
      ENV_VARS: ${{ secrets.PRODUCTION_ENV_VARS }}
```

### 2. Setup Steps for New Applications

When deploying a new Python API application using this scaffolding:

#### A. Repository Setup
1. **Create the deployment workflow**: Add `.github/workflows/deploy.yml` (see example above)
2. **Ensure application structure**:
   - `requirements.txt` file exists
   - `src/main.py` as the entry point
   - Optional: `pyproject.toml` for code quality checks
   - Optional: `pytest.ini` or pytest configuration

#### B. Configure GitHub Secrets
Navigate to your repository Settings → Secrets and variables → Actions and add:

**Per Environment Secrets**:
- `STAGING_DEPLOY_KEY` / `PRODUCTION_DEPLOY_KEY` - SSH private key for deployment
- `STAGING_SERVER_HOST` / `PRODUCTION_SERVER_HOST` - Server hostname or IP
- `STAGING_SERVER_USER` / `PRODUCTION_SERVER_USER` - Server username
- `STAGING_ENV_VARS` / `PRODUCTION_ENV_VARS` - Environment variables as JSON

#### C. Server Preparation
Ensure your target servers have:
- Python 3.9+ installed
- Git installed  
- SSH access configured with the deploy key
- User with sudo privileges
- `www-data` user/group exists

#### D. Environment Variables Configuration
The `ENV_VARS` secret should be a JSON string containing all environment variables your application needs:

```json
{
  "API_KEY": "your_api_key_here",
  "DATABASE_URL": "postgresql://user:pass@localhost/myapp",
  "LOG_LEVEL": "INFO",
  "DEBUG": "false"
}
```

#### E. Deployment
- **Automatic**: Push to `main` branch triggers staging deployment
- **Manual**: Use GitHub Actions "Run workflow" button to deploy to staging or production

### 3. Quick Start for AI Agents

When asked to set up deployment for a new Python API:

1. **Create deployment workflow** in the application repository:
   ```bash
   mkdir -p .github/workflows
   # Copy the example workflow above to .github/workflows/deploy.yml
   # Update app_name and repo_name to match the application
   ```

2. **Verify application structure**:
   - Ensure `src/main.py` exists as entry point
   - Ensure `requirements.txt` exists with dependencies
   - Add `pyproject.toml` if code quality checks are needed

3. **Configure secrets** (provide instructions to user):
   - Generate SSH key pair for deployment
   - Add public key to target servers
   - Configure GitHub secrets with server details and environment variables

4. **Test deployment**:
   - Push to main branch for staging deployment
   - Use manual workflow dispatch for production deployment

## Features

### Deployment Process
1. **Code Quality Checks**: Black, isort, flake8, mypy (if configured)
2. **Testing**: Pytest with coverage (if configured)
3. **Remote Deployment**: 
   - Clone/update repository on target server
   - Create Python virtual environment
   - Install dependencies
   - Configure environment variables
   - Create systemd service
   - Start/restart service
4. **Health Check**: Verify service is running and check logs

### Service Management
- Each app/environment gets its own systemd service: `{app_name}-{environment}.service`
- Services run as `www-data` user
- Automatic restart on failure
- Centralized logging via syslog

### Directory Structure on Server
```
/opt/{app_name}-{environment}/
├── .venv/              # Python virtual environment
├── .env                # Environment variables
├── src/                # Application source code
├── config/             # Configuration files
├── data/               # Application data
└── .git/               # Git repository

/var/log/{app_name}-{environment}/  # Log directory
```

## Customization

You can customize the deployment by:

1. **Modifying the reusable workflow**: Edit `.github/workflows/deploy-python-api.yml`
2. **Customizing deployment script**: Edit `scripts/deploy-python-api.sh` (includes systemd service configuration)