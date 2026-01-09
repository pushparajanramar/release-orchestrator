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

### Environment Setup

1. **Copy environment template**:
   ```bash
   cp .env.example .env
   ```

2. **Configure credentials** in `.env`:
   ```bash
   CM_CLIENT_ID=your_actual_client_id
   CM_CLIENT_SECRET=your_actual_client_secret  
   CM_API_KEY=your_actual_api_key
   CM_ORG_ID=your_actual_org_id
   ```

3. **Load environment variables**:
   ```bash
   source .env
   ```

### Using the Trigger Script

#### **Local Testing**
```bash
# Load environment variables
source .env

# Trigger a specific pipeline
./scripts/trigger-cm-pipeline.sh platform-dev

# Expected output:
# Triggering pipeline: platform-dev (ID: 123456, Program: 78910)
# API Endpoint: https://cloudmanager.adobe.io/api/program/78910/pipeline/123456/execution
# ✅ Access token obtained
# ✅ Pipeline triggered successfully (HTTP 201)
# 📋 Execution ID: 987654
```

#### **Script Parameters**
- **Input**: Pipeline name (matches `pipelines/*.yaml` filename)
- **Output**: Execution status and ID for tracking
- **Exit codes**: 0=success, 1=failure

### Testing the Setup
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

## Release Process

### Overview

The Release Orchestrator manages **multi-tenant AEM deployments** through a structured, auditable process that ensures:

- **Sequential deployment**: Platform first, then tenants
- **Environment isolation**: Dev → Stage → Production progression  
- **Approval gates**: Production requires explicit approval
- **Audit trails**: Complete record of who, what, when, and why

### Roles & Responsibilities

#### **👨‍💻 Development Teams**
- Deliver code to version control with proper tagging
- Communicate version numbers to Release Coordinators
- Ensure code is tested and ready for deployment

#### **👷 Release Coordinators** 
- Create and validate release manifests
- Coordinate with development teams for version alignment
- Obtain production approvals through change management
- Monitor deployment progress and handle failures

#### **👨‍⚖️ Release Approvers (CTO/VP Level)**
- Review release manifests for business impact
- Approve production deployments via approval files
- Ensure compliance with change management processes

#### **🤖 DevOps/Automation**
- Maintain infrastructure and pipeline configurations
- Monitor automated deployments
- Handle infrastructure-related failures
- Implement security and access controls

### Release Workflow

#### **Phase 1: Development & Testing**

1. **Code Development**
   - Teams develop features in feature branches
   - Code reviews and testing completed
   - Ready for release candidate

2. **Version Tagging**
   ```bash
   # Platform team tags release
   git tag v1.12.0
   git push origin v1.12.0
   
   # Tenant teams tag releases
   git tag v3.8.2  # US tenant
   git push origin v3.8.2
   ```

3. **Dev Environment Deployment**
   - Push to `release/dev` branch triggers automatic deployment
   - No approval required for dev deployments
   - Fast feedback for development teams

#### **Phase 2: Release Preparation**

4. **Create Release Manifest**
   ```yaml
   # manifests/release-2026-01.yaml
   releaseId: 2026.01
   type: standard
   
   platform:
     repo: aem-platform-core
     version: 1.12.0
     pipeline: platform
     
   tenants:
     us:
       repo: aem-tenant-us  
       version: 3.8.2
       pipeline: tenant-us
   ```

5. **Manifest Validation**
   ```bash
   ./scripts/validate-manifest.sh release-2026-01.yaml
   # ✅ Validates structure, pipelines, and dependencies
   ```

6. **Stage Environment Testing**
   - Push to `release/stage` branch
   - Automated deployment to staging
   - Integration testing and UAT performed

#### **Phase 3: Production Deployment**

7. **Change Management Approval**
   - Submit change request (e.g., CHG-48291)
   - Business stakeholders review impact
   - Obtain formal approval

8. **Create Approval File**
   ```bash
   # approvals/release-2026-01.approved
   cat > approvals/release-2026-01.approved << EOF
   approvedBy: CTO
   date: 2026-01-15
   ticket: CHG-48291
   EOF
   
   git add approvals/
   git commit -m "feat: approve release-2026-01 for production"
   git push
   ```

9. **Production Deployment**
   - Go to GitHub Actions → "Release Orchestrator"
   - Select manifest: `release-2026-01.yaml`
   - Select environment: `prod`
   - Click "Run workflow"
   - Monitor deployment progress

### Deployment Sequence

#### **Standard Release Order**
```
1. Platform Deployment
   ├── Trigger: platform pipeline
   ├── Wait: for completion (up to 60 min)
   └── Status: ✅ Success or ❌ Failure

2. Tenant Deployments (Sequential)
   ├── US Tenant
   │   ├── Trigger: tenant-us pipeline  
   │   ├── Wait: for completion
   │   └── Status: ✅ Success or ❌ Failure
   │
   ├── CA Tenant
   │   ├── Trigger: tenant-ca pipeline
   │   ├── Wait: for completion
   │   └── Status: ✅ Success or ❌ Failure
   │
   └── All tenants complete
```

#### **Hotfix Release Order**
```
1. Platform Deployment (if needed)
2. Only affected tenants (e.g., US only)
   └── Faster, targeted deployment
```

### Environment-Specific Processes

#### **Development Environment**
- **Trigger**: Push to `release/dev` branch
- **Approval**: None required
- **Purpose**: Fast iteration and testing
- **Duration**: ~15-30 minutes

#### **Staging Environment**  
- **Trigger**: Push to `release/stage` branch
- **Approval**: None required
- **Purpose**: Pre-production validation
- **Duration**: ~30-45 minutes

#### **Production Environment**
- **Trigger**: Manual via GitHub Actions UI
- **Approval**: Required (approval file + change ticket)
- **Purpose**: Live customer deployments
- **Duration**: ~45-90 minutes

### Monitoring & Status Tracking

#### **GitHub Actions Dashboard**
- Real-time deployment logs
- Step-by-step execution status
- Failure notifications and reasons

#### **Cloud Manager Dashboard**
- Pipeline execution details
- Build logs and test results
- Performance metrics and reports

#### **Execution Tracking**
```bash
# Check pipeline status
./scripts/wait-for-pipeline.sh platform-prod

# Expected output:
⏳ Waiting for pipeline: platform-prod
📊 Pipeline Status: RUNNING (Execution: 123456)
📊 Pipeline Status: FINISHED
✅ Pipeline completed successfully!
```

### Failure Handling & Rollback

#### **Automatic Failure Handling**
- **Pipeline failures**: Stop deployment, notify team
- **Timeout handling**: 60-minute default timeout
- **Dependency checks**: Validate before proceeding

#### **Manual Intervention**
- **Pause deployments**: Stop workflow if issues detected
- **Rollback procedures**: Revert to previous versions
- **Emergency fixes**: Hotfix process for critical issues

#### **Rollback Process**
1. Identify failed component (platform/tenant)
2. Trigger rollback pipeline in Cloud Manager
3. Update manifest with previous version
4. Redeploy affected components
5. Verify system stability

### Quality Gates

#### **Pre-Deployment Checks**
- ✅ Manifest validation (structure, versions, pipelines)
- ✅ Pipeline configuration exists
- ✅ Environment-specific approvals
- ✅ Change management compliance

#### **Deployment Validation**
- ✅ Platform deployment success
- ✅ Tenant deployment success
- ✅ Health checks pass
- ✅ Smoke tests complete

#### **Post-Deployment**
- ✅ Monitoring alerts configured
- ✅ Performance baselines established
- ✅ Rollback procedures documented

### Security & Compliance

#### **Access Controls**
- GitHub repository permissions
- Cloud Manager API credentials
- Approval file signatures
- Audit logging

#### **Change Management**
- Formal approval processes
- Change tickets required
- Impact assessments
- Rollback planning

#### **Audit Trail**
- Who triggered deployment
- What was deployed (versions)
- When deployment occurred
- Why deployment was approved

### Troubleshooting Guide

#### **Common Issues**

**❌ Manifest Validation Fails**
```bash
# Check manifest syntax
./scripts/validate-manifest.sh release-2026-01.yaml

# Common fixes:
# - Ensure pipeline configs exist
# - Check YAML formatting
# - Verify version numbers
```

**❌ Missing Approval for Production**
```bash
# Create approval file
cat > approvals/release-2026-01.approved << EOF
approvedBy: CTO
date: 2026-01-15
ticket: CHG-48291
EOF
```

**❌ Pipeline Timeout**
```bash
# Check Cloud Manager status
# Increase timeout in script if needed
# Investigate build performance issues
```

**❌ API Authentication Issues**
```bash
# Verify GitHub Secrets are set
# Check Cloud Manager credentials
# Regenerate tokens if expired
```

#### **Emergency Contacts**
- **DevOps On-Call**: For infrastructure issues
- **Release Coordinator**: For deployment coordination
- **Development Teams**: For code-related issues
- **Cloud Manager Support**: For Adobe-specific issues

### Metrics & Reporting

#### **Deployment Metrics**
- Deployment frequency (releases/week)
- Success rate (successful deployments/total)
- Mean time to deploy (MTTD)
- Mean time to recovery (MTTR)

#### **Quality Metrics**
- Change failure rate
- Deployment lead time
- Automated test coverage
- Rollback frequency

### Continuous Improvement

#### **Retrospectives**
- Post-deployment reviews
- Process improvement identification
- Tool and automation enhancements
- Training and documentation updates

#### **Automation Opportunities**
- Further pipeline automation
- Enhanced monitoring and alerting
- Self-service deployment portals
- AI-assisted release planning

---

**This release process ensures reliable, auditable, and efficient deployments across all AEM environments while maintaining proper governance and compliance.**

**Owner:** Release Management Team

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