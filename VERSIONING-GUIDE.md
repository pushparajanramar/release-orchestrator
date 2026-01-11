# SBUX AEM Versioning & Tagging Guide

## Overview

This guide establishes the **Semantic Versioning (SemVer) + Calendar Qualifier** strategy for the Starbucks AEM multi-tenant platform. This hybrid approach provides both technical precision and business clarity for release management.

## Versioning Strategy

### Core Principles

**SemVer (MAJOR.MINOR.PATCH) + Calendar Qualifier (YEAR.MONTH)**

- **SemVer** communicates technical impact (breaking vs compatible changes)
- **Calendar prefix** gives business/release-wave context
- **Hybrid pattern** is common in enterprise multi-tenant/SaaS platforms

### SemVer Rules

| Component | Description | Examples |
|-----------|-------------|----------|
| **MAJOR** | Breaking changes / incompatible API | `1.0.0` → `2.0.0` |
| **MINOR** | Backward-compatible new features | `1.0.0` → `1.1.0` |
| **PATCH** | Backward-compatible bug fixes | `1.0.0` → `1.0.1` |

### Calendar Qualifier

| Component | Description | Examples |
|-----------|-------------|----------|
| **YEAR.MONTH** | Release wave identifier | `2026.01`, `2026.02` |
| **Purpose** | Business alignment, manifest naming | Links to change tickets, communications |

## Tag Patterns & Examples

### Platform Core Tagging

```bash
# 1. Create technical version tag (SemVer)
git tag -a v1.12.0 -m "Platform core 1.12.0: new component model, breaking internal API"

# 2. Create release wave tag (calendar-qualified)
git tag -a 2026.01-v1.12.0 -m "January 2026 coordinated platform release"

# 3. Push both tags immediately
git push origin v1.12.0 2026.01-v1.12.0
```

### Tenant Tagging Examples

```bash
# Partners Tenant
git tag -a v3.8.2 -m "Partners tenant 3.8.2: enhanced loyalty features"
git tag -a 2026.01-v3.8.2 -m "January 2026 partners release"
git push origin v3.8.2 2026.01-v3.8.2

# US Tenant
git tag -a v3.8.2 -m "US tenant 3.8.2: regional compliance updates"
git tag -a 2026.01-v3.8.2 -m "January 2026 US release"
git push origin v3.8.2 2026.01-v3.8.2
```

### Coordinated Release Pattern

```
Release Wave: January 2026 (2026.01)
├── Platform: 2026.01-v1.12.0
├── Partners: 2026.01-v3.8.2
├── US:       2026.01-v3.8.2
└── CA:       2026.01-v2.4.1
```

*Same calendar prefix signals coordinated release wave*

## Compatibility Matrix

### Platform Requirements per Tenant

```yaml
# manifests/release-2026-01.yaml
compatibility:
  platform: "1.12.x"        # Platform version pattern
  tenants:
    partners: ">=1.12.0 <2.0.0"  # Range expressions
    us: ">=1.12.0 <2.0.0"
    ca: ">=1.10.0 <2.0.0"        # CA can use older platform
```

### Version Bump Guidelines

| Version Change | Safety Level | Platform Change Required | Testing Required |
|----------------|--------------|--------------------------|------------------|
| **PATCH** (1.12.0 → 1.12.1) | 🟢 Always Safe | None | Unit tests only |
| **MINOR** (1.12.0 → 1.13.0) | 🟡 Usually Safe | Contract unchanged | Integration tests |
| **MAJOR** (1.12.0 → 2.0.0) | 🔴 Breaking Change | Major platform bump | Full regression testing |

### Range Expression Examples

```yaml
# Compatible version ranges (SemVer)
compatibility:
  platform: ">=1.12.0 <2.0.0"    # Any 1.x version
  tenants:
    partners: "^1.12.0"           # Compatible with 1.12.x
    us: "~1.12.0"                 # Compatible with 1.12.x only
    ca: ">=1.10.0 <2.0.0"         # Flexible range
```

## Tagging Workflow

### Developer Workflow

```bash
# 1. Complete development on feature branch
git checkout feature/new-loyalty-features
# ... development work ...

# 2. Merge to release/dev branch
git checkout release/dev
git merge feature/new-loyalty-features

# 3. Run CI/CD pipeline (tests, builds, etc.)
# ... CI passes ...

# 4. Create version tags (only after CI success)
git tag -a v3.8.2 -m "Partners tenant 3.8.2: enhanced loyalty features"
git tag -a 2026.01-v3.8.2 -m "January 2026 partners release"

# 5. Push tags immediately (triggers deployment)
git push origin --tags
```

### Release Manager Workflow

```bash
# 1. Collect version numbers from all teams
# Platform: v1.12.0 (breaking internal API)
# Partners: v3.8.2 (new loyalty features)
# US: v3.8.2 (regional updates)
# CA: v2.4.1 (bug fixes)

# 2. Create manifest with compatibility validation
# manifests/release-2026-01.yaml

# 3. Validate manifest
./scripts/validate-manifest.sh release-2026-01.yaml

# 4. Get approvals and deploy
# ... approval and deployment process ...
```

## Best Practices

### Tag Management

| Practice | Command | Why |
|----------|---------|-----|
| **Annotated Tags** | `git tag -a v1.12.0 -m "message"` | Preserves metadata for audits |
| **Push Immediately** | `git push origin --tags` | Shares tags for team visibility |
| **Never Force Push** | Avoid `--force` on tags | Maintains audit trail |
| **Tag on release/dev** | Only after CI success | Prevents premature tagging |

### Version Planning

| Scenario | Version Pattern | Example |
|----------|----------------|---------|
| **Bug Fix** | PATCH increment | `v1.12.0` → `v1.12.1` |
| **New Feature** | MINOR increment | `v1.12.0` → `v1.13.0` |
| **Breaking Change** | MAJOR increment | `v1.12.0` → `v2.0.0` |
| **Hotfix** | PATCH from tagged commit | `git checkout v1.12.0` → fix → `v1.12.1` |

### Compatibility Planning

| Component | Version Strategy | Update Frequency |
|-----------|------------------|------------------|
| **Platform Core** | Conservative MAJOR bumps | Quarterly |
| **Shared Components** | MINOR for features, PATCH for fixes | Monthly |
| **Tenant Features** | Independent MINOR/PATCH | Weekly |
| **Security Fixes** | PATCH across all components | As needed |

## Troubleshooting

### Common Issues

**❌ Version Compatibility Failure**
```bash
# Check compatibility matrix in manifest
# Update tenant versions to match platform requirements
# Consult platform team for breaking changes
```

**❌ Tag Conflicts**
```bash
# Check existing tags: git tag -l "v*"
# Use different version number
# Coordinate with team to avoid conflicts
```

**❌ Calendar Prefix Mismatch**
```bash
# Ensure all components in release wave use same prefix
# Example: 2026.01-v1.12.0, 2026.01-v3.8.2
# Different prefixes indicate separate release waves
```

**❌ Missing SHA Checksums**
```bash
# Generate SHA: sha256sum artifact.jar
# Include in manifest for integrity validation
# Required for production deployments
```

## Migration Guide

### From Legacy Versioning

| Legacy Pattern | New Pattern | Migration |
|----------------|-------------|-----------|
| `1.12.0` | `v1.12.0` + `2026.01-v1.12.0` | Add v prefix + calendar qualifier |
| `2026.01` | `2026.01-v1.12.0` | Include SemVer in calendar tag |
| No tags | Annotated tags | Use `git tag -a` with messages |

### Implementation Timeline

| Phase | Action | Timeline |
|-------|--------|----------|
| **Phase 1** | Update documentation | Immediate |
| **Phase 2** | Train development teams | Within 1 sprint |
| **Phase 3** | Update CI/CD pipelines | Within 2 sprints |
| **Phase 4** | Migrate existing tags | Within 1 month |

## Benefits

✅ **Technical Precision** - SemVer communicates breaking vs compatible changes  
✅ **Business Clarity** - Calendar qualifiers align with release planning  
✅ **Audit Compliance** - Annotated tags preserve change history  
✅ **Rollback Safety** - Version history enables safe rollbacks  
✅ **Multi-Tenant Coordination** - Release wave grouping for stakeholders  
✅ **Tool Integration** - Works with existing SemVer tooling  

## Quick Reference

### Commands
```bash
# Create technical tag
git tag -a v1.12.0 -m "Platform 1.12.0 release"

# Create release tag
git tag -a 2026.01-v1.12.0 -m "January 2026 platform release"

# Push all tags
git push origin --tags

# List tags
git tag -l --sort=-version:refname
```

### Version Ranges
```yaml
# Exact version
version: "1.12.0"

# Compatible range
compatibility: ">=1.12.0 <2.0.0"

# Patch-level compatible
compatibility: "~1.12.0"

# Minor-level compatible
compatibility: "^1.12.0"
```

This versioning strategy provides the perfect balance of technical rigor and business practicality for enterprise multi-tenant platforms.</content>
<parameter name="filePath">/Users/pramar/Code/SBUX-AEM/release-orchestrator/VERSIONING-GUIDE.md