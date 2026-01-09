# Release Process Documentation

## Overview

The Release Orchestrator manages **multi-tenant AEM deployments** through a structured, auditable process that ensures:

- **Sequential deployment**: Platform first, then tenants
- **Environment isolation**: Dev → Stage → Production progression
- **Approval gates**: Production requires explicit approval
- **Audit trails**: Complete record of who, what, when, and why

## Roles & Responsibilities

### 👨‍💻 Development Teams
- Deliver code to version control with proper tagging
- Communicate version numbers to Release Coordinators
- Ensure code is tested and ready for deployment

### 👷 Release Coordinators
- Create and validate release manifests
- Coordinate with development teams for version alignment
- Obtain production approvals through change management
- Monitor deployment progress and handle failures

### 👨‍⚖️ Release Approvers (CTO/VP Level)
- Review release manifests for business impact
- Approve production deployments via approval files
- Ensure compliance with change management processes

### 🤖 DevOps/Automation
- Maintain infrastructure and pipeline configurations
- Monitor automated deployments
- Handle infrastructure-related failures
- Implement security and access controls

## Release Workflow

### Phase 1: Development & Testing

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

### Phase 2: Release Preparation

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

### Phase 3: Production Deployment

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

## Deployment Sequence

### Standard Release Order
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

### Hotfix Release Order
```
1. Platform Deployment (if needed)
2. Only affected tenants (e.g., US only)
   └── Faster, targeted deployment
```

## Environment-Specific Processes

### Development Environment
- **Trigger**: Push to `release/dev` branch
- **Approval**: None required
- **Purpose**: Fast iteration and testing
- **Duration**: ~15-30 minutes

### Staging Environment
- **Trigger**: Push to `release/stage` branch
- **Approval**: None required
- **Purpose**: Pre-production validation
- **Duration**: ~30-45 minutes

### Production Environment
- **Trigger**: Manual via GitHub Actions UI
- **Approval**: Required (approval file + change ticket)
- **Purpose**: Live customer deployments
- **Duration**: ~45-90 minutes

## Monitoring & Status Tracking

### GitHub Actions Dashboard
- Real-time deployment logs
- Step-by-step execution status
- Failure notifications and reasons

### Cloud Manager Dashboard
- Pipeline execution details
- Build logs and test results
- Performance metrics and reports

### Execution Tracking
```bash
# Check pipeline status
./scripts/wait-for-pipeline.sh platform-prod

# Expected output:
⏳ Waiting for pipeline: platform-prod
📊 Pipeline Status: RUNNING (Execution: 123456)
📊 Pipeline Status: FINISHED
✅ Pipeline completed successfully!
```

## Failure Handling & Rollback

### Automatic Failure Handling
- **Pipeline failures**: Stop deployment, notify team
- **Timeout handling**: 60-minute default timeout
- **Dependency checks**: Validate before proceeding

### Manual Intervention
- **Pause deployments**: Stop workflow if issues detected
- **Rollback procedures**: Revert to previous versions
- **Emergency fixes**: Hotfix process for critical issues

### Rollback Process
1. Identify failed component (platform/tenant)
2. Trigger rollback pipeline in Cloud Manager
3. Update manifest with previous version
4. Redeploy affected components
5. Verify system stability

## Quality Gates

### Pre-Deployment Checks
- ✅ Manifest validation (structure, versions, pipelines)
- ✅ Pipeline configuration exists
- ✅ Environment-specific approvals
- ✅ Change management compliance

### Deployment Validation
- ✅ Platform deployment success
- ✅ Tenant deployment success
- ✅ Health checks pass
- ✅ Smoke tests complete

### Post-Deployment
- ✅ Monitoring alerts configured
- ✅ Performance baselines established
- ✅ Rollback procedures documented

## Security & Compliance

### Access Controls
- GitHub repository permissions
- Cloud Manager API credentials
- Approval file signatures
- Audit logging

### Change Management
- Formal approval processes
- Change tickets required
- Impact assessments
- Rollback planning

### Audit Trail
- Who triggered deployment
- What was deployed (versions)
- When deployment occurred
- Why deployment was approved

## Troubleshooting Guide

### Common Issues

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

### Emergency Contacts
- **DevOps On-Call**: For infrastructure issues
- **Release Coordinator**: For deployment coordination
- **Development Teams**: For code-related issues
- **Cloud Manager Support**: For Adobe-specific issues

## Metrics & Reporting

### Deployment Metrics
- Deployment frequency (releases/week)
- Success rate (successful deployments/total)
- Mean time to deploy (MTTD)
- Mean time to recovery (MTTR)

### Quality Metrics
- Change failure rate
- Deployment lead time
- Automated test coverage
- Rollback frequency

## Continuous Improvement

### Retrospectives
- Post-deployment reviews
- Process improvement identification
- Tool and automation enhancements
- Training and documentation updates

### Automation Opportunities
- Further pipeline automation
- Enhanced monitoring and alerting
- Self-service deployment portals
- AI-assisted release planning

---

**This release process ensures reliable, auditable, and efficient deployments across all AEM environments while maintaining proper governance and compliance.**

**Owner:** Release Management Team</content>
<parameter name="filePath">/Users/pramar/Code/SBUX-AEM/release-orchestrator/RELEASE-PROCESS.md