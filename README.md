# Release Orchestrator Repository

## What This Repository Is (Ground Rule)

The **Release Orchestrator repo**:

* Contains **NO AEM code**
* Contains **NO platform or tenant builds**
* Contains **NO business logic**
* Exists **only** to define and coordinate releases

Think of it as **"release intent + automation"**.

## Release Philosophy

* What is fan-in
* When to use orchestrator
* How releases are approved
* Who can trigger prod releases

**Owner:** Platform / DevOps

## Cloud Manager Setup

### Prerequisites

- Access to Adobe Cloud Manager with API permissions
- Cloud Manager API credentials (Client ID, Client Secret, Technical Account Key)
- Pipeline IDs and Program IDs for each pipeline (platform and tenants)
- GitHub repository with Actions enabled

### How to Obtain Cloud Manager API Credentials

#### **Step 1: Access Adobe Developer Console**
1. Go to: https://developer.adobe.com/console
2. Sign in with your Adobe ID
3. Select your organization (Starbucks)

#### **Step 2: Create/Access Cloud Manager API Project**
1. Click **"Create new project"** or select existing Cloud Manager project
2. Add **"Cloud Manager"** API to your project
3. Configure OAuth Server-to-Server credentials

#### **Step 3: Generate Credentials**
The console will provide:
- **Client ID** (`CM_CLIENT_ID`)
- **Client Secret** (`CM_CLIENT_SECRET`) 
- **Organization ID** (`CM_ORG_ID`)
- **Technical Account ID** (used for technical account key)

#### **Step 4: Generate Technical Account Key**
1. Download the private key from the console
2. Base64 encode it: `base64 -i private.key` (macOS/Linux)
3. This becomes your `CM_TECHNICAL_ACCOUNT_KEY`

#### **Step 5: API Key**
- Usually same as Client ID: `CM_API_KEY = CM_CLIENT_ID`
- Sometimes provided separately in console

### Security Notes
- 🔐 **Never commit credentials** to repository
- 🔐 **Use GitHub Secrets** for all credential storage
- 🔐 **Rotate credentials** regularly
- 🔐 **Limit API permissions** to necessary operations only

### Pipeline Configuration

1. Update `pipelines/*.yaml` files with actual Cloud Manager Pipeline IDs and Program IDs:

   ```yaml
   pipelineId: 123456  # Actual Cloud Manager Pipeline ID
   programId: 78910    # Actual Cloud Manager Program ID
   environment: prod
   ```

2. Obtain these IDs from Cloud Manager UI or API:
   - Program ID: Found in Cloud Manager program URL
   - Pipeline ID: Found in pipeline execution URL or API responses

### Workflow Permissions

Ensure the GitHub Actions workflow has the following permissions:

```yaml
permissions:
  contents: read
  id-token: write  # Required for OIDC authentication if using
```

### API Authentication

The scripts use Cloud Manager REST API v2. Authentication follows Adobe IMS:

- Uses JWT-based authentication with the technical account
- Scripts should handle token generation and refresh
- Store sensitive data only in GitHub Secrets

### Testing the Setup

1. Run a test release to dev environment first
2. Verify pipeline triggers in Cloud Manager dashboard
3. Check logs for API errors or authentication issues
4. Confirm deployment order and success notifications

### Troubleshooting

- **401 Unauthorized**: Check API credentials and secrets
- **403 Forbidden**: Verify user permissions in Cloud Manager
- **Pipeline not found**: Confirm Pipeline ID and Program ID in config files
- **Rate limiting**: Cloud Manager API has rate limits; implement retries in scripts

**Owner:** DevOps

## GitHub Actions Workflow

### File: `workflows/release.yml`

#### What It Does

* **Automatic**: Triggers on push to `release/dev` or `release/stage` branches
* **Manual**: Supports workflow_dispatch for production deployments
* Reads release manifest and determines target environment
* Validates manifests and checks approvals (production only)
* Triggers Cloud Manager pipelines in sequence
* Enforces order: platform first, then tenants
* Stops on failure with proper error reporting

#### Triggers

```yaml
on:
  # Automatic for dev/stage
  push:
    branches: ['release/dev', 'release/stage']
    paths: ['manifests/**', 'environments/**']
  
  # Manual for production
  workflow_dispatch:
    inputs:
      manifest: string
      environment: string
```

**What It Does NOT Do**

* Build code (handled by Cloud Manager)
* Deploy directly to AEM (uses Cloud Manager pipelines)
* Run tests (handled by Cloud Manager)

**Owner:** DevOps

## Automated vs Manual Deployments

### Environment-Based Triggers

The orchestrator supports **automatic deployments for dev/stage** and **manual deployments for production**:

#### **Automatic Deployments (Dev/Stage)**
- **Trigger**: Push to `release/dev` or `release/stage` branches
- **No approval required**
- **Automatic execution** when manifests change
- **Fast feedback** for development cycles

#### **Manual Deployments (Production)**
- **Trigger**: Manual workflow dispatch only
- **Approval required** (approval file must exist)
- **Controlled releases** with explicit sign-off
- **Audit trail** of who triggered the deployment

### Branch Strategy

```
main (orchestrator code)
├── release/dev     → Automatic dev deployment
├── release/stage   → Automatic stage deployment  
└── release/prod    → Manual prod deployment (via workflow_dispatch)
```

### Workflow Behavior

| Environment | Trigger | Approval Required | Use Case |
|-------------|---------|------------------|----------|
| **Dev** | Push to `release/dev` | ❌ No | Fast iteration |
| **Stage** | Push to `release/stage` | ❌ No | Pre-production testing |
| **Prod** | Manual workflow dispatch | ✅ Yes | Controlled production releases |

**Owner:** DevOps