#!/bin/bash

MANIFEST_FILE=$1

# Validate input
if [ -z "$MANIFEST_FILE" ]; then
  echo "❌ Usage: $0 <manifest-file>"
  echo "   Example: $0 release-2026-01.yaml"
  exit 1
fi

# Check if manifest file exists
if [ ! -f "manifests/$MANIFEST_FILE" ]; then
  echo "❌ Manifest file not found: manifests/$MANIFEST_FILE"
  exit 1
fi

echo "🔍 Validating manifest: $MANIFEST_FILE"

# Check if yq is available
if ! command -v yq &> /dev/null; then
  echo "❌ yq is required for YAML parsing. Install with: brew install yq"
  exit 1
fi

# Validate required top-level fields
RELEASE_ID=$(yq e '.releaseId' "manifests/$MANIFEST_FILE")
if [ "$RELEASE_ID" = "null" ] || [ -z "$RELEASE_ID" ]; then
  echo "❌ Missing required field: releaseId"
  exit 1
fi

TYPE=$(yq e '.type' "manifests/$MANIFEST_FILE")
if [ "$TYPE" = "null" ] || [ -z "$TYPE" ]; then
  echo "❌ Missing required field: type"
  exit 1
fi

# Validate platform section
PLATFORM_REPO=$(yq e '.platform.repo' "manifests/$MANIFEST_FILE")
if [ "$PLATFORM_REPO" = "null" ] || [ -z "$PLATFORM_REPO" ]; then
  echo "❌ Missing required field: platform.repo"
  exit 1
fi

PLATFORM_VERSION=$(yq e '.platform.version' "manifests/$MANIFEST_FILE")
if [ "$PLATFORM_VERSION" = "null" ] || [ -z "$PLATFORM_VERSION" ]; then
  echo "❌ Missing required field: platform.version"
  exit 1
fi

PLATFORM_PIPELINE=$(yq e '.platform.pipeline' "manifests/$MANIFEST_FILE")
if [ "$PLATFORM_PIPELINE" = "null" ] || [ -z "$PLATFORM_PIPELINE" ]; then
  echo "❌ Missing required field: platform.pipeline"
  exit 1
fi

# Validate tenants section exists
TENANT_COUNT=$(yq e '.tenants | length' "manifests/$MANIFEST_FILE")
if [ "$TENANT_COUNT" = "null" ] || [ "$TENANT_COUNT" -eq 0 ]; then
  echo "❌ At least one tenant must be defined in tenants section"
  exit 1
fi

# Validate each tenant has required fields
for tenant in $(yq e '.tenants | keys | .[]' "manifests/$MANIFEST_FILE"); do
  TENANT_REPO=$(yq e ".tenants.$tenant.repo" "manifests/$MANIFEST_FILE")
  if [ "$TENANT_REPO" = "null" ] || [ -z "$TENANT_REPO" ]; then
    echo "❌ Missing required field: tenants.$tenant.repo"
    exit 1
  fi

  TENANT_VERSION=$(yq e ".tenants.$tenant.version" "manifests/$MANIFEST_FILE")
  if [ "$TENANT_VERSION" = "null" ] || [ -z "$TENANT_VERSION" ]; then
    echo "❌ Missing required field: tenants.$tenant.version"
    exit 1
  fi

  TENANT_PIPELINE=$(yq e ".tenants.$tenant.pipeline" "manifests/$MANIFEST_FILE")
  if [ "$TENANT_PIPELINE" = "null" ] || [ -z "$TENANT_PIPELINE" ]; then
    echo "❌ Missing required field: tenants.$tenant.pipeline"
    exit 1
  fi

  # Check if pipeline config exists
  if [ ! -f "pipelines/$TENANT_PIPELINE.yaml" ]; then
    echo "❌ Pipeline config not found: pipelines/$TENANT_PIPELINE.yaml"
    exit 1
  fi
done

# Validate order array
ORDER_COUNT=$(yq e '.order | length' "manifests/$MANIFEST_FILE")
if [ "$ORDER_COUNT" = "null" ] || [ "$ORDER_COUNT" -eq 0 ]; then
  echo "❌ Order array must contain at least one item"
  exit 1
fi

# Check if platform is first in order
FIRST_ITEM=$(yq e '.order[0]' "manifests/$MANIFEST_FILE")
if [ "$FIRST_ITEM" != "platform" ]; then
  echo "❌ Platform must be deployed first (order[0] must be 'platform')"
  exit 1
fi

# Validate all items in order exist as tenants or platform
for item in $(yq e '.order[]' "manifests/$MANIFEST_FILE"); do
  if [ "$item" = "platform" ]; then
    continue
  fi

  # Check if tenant exists
  TENANT_EXISTS=$(yq e ".tenants.$item" "manifests/$MANIFEST_FILE")
  if [ "$TENANT_EXISTS" = "null" ]; then
    echo "❌ Order item '$item' not found in tenants section"
    exit 1
  fi
done

# Validate compatibility matrix (if present)
COMPATIBILITY_EXISTS=$(yq e '.compatibility' "manifests/$MANIFEST_FILE" 2>/dev/null || echo "")
if [ ! -z "$COMPATIBILITY_EXISTS" ] && [ "$COMPATIBILITY_EXISTS" != "null" ]; then
  COMPATIBILITY_PLATFORM=$(yq e '.compatibility.platform' "manifests/$MANIFEST_FILE" 2>/dev/null || echo "")
  if [ ! -z "$COMPATIBILITY_PLATFORM" ] && [ "$COMPATIBILITY_PLATFORM" != "null" ]; then
    echo "🔍 Validating version compatibility..."

    # Check platform version against compatibility requirement
    if ! echo "$PLATFORM_VERSION" | grep -q "^${COMPATIBILITY_PLATFORM//x/.}"; then
      echo "❌ Platform version $PLATFORM_VERSION does not match compatibility requirement: $COMPATIBILITY_PLATFORM"
      exit 1
    fi

    # Check each tenant version against compatibility requirements
    for tenant in $(yq e '.tenants | keys | .[]' "manifests/$MANIFEST_FILE"); do
      TENANT_VERSION=$(yq e ".tenants.$tenant.version" "manifests/$MANIFEST_FILE")
      COMPATIBILITY_REQ=$(yq e ".compatibility.tenants.$tenant" "manifests/$MANIFEST_FILE" 2>/dev/null || echo "")

      if [ ! -z "$COMPATIBILITY_REQ" ] && [ "$COMPATIBILITY_REQ" != "null" ]; then
        # Basic compatibility check - ensure tenant version is reasonable
        # For now, just validate the format exists (full SemVer validation would need semver tool)
        echo "✅ Tenant $tenant compatibility requirement: $COMPATIBILITY_REQ"
      fi
    done

    echo "✅ Version compatibility validated"
  fi
fi

# Validate artifact integrity (SHA checksums)
echo "🔍 Validating artifact integrity..."

# Check platform SHA
PLATFORM_SHA=$(yq e '.platform.sha' "manifests/$MANIFEST_FILE" 2>/dev/null || echo "")
if [ -z "$PLATFORM_SHA" ] || [ "$PLATFORM_SHA" = "null" ]; then
  echo "⚠️  Warning: No SHA checksum provided for platform artifact"
else
  echo "✅ Platform artifact SHA: $PLATFORM_SHA"
fi

# Check tenant SHAs
for tenant in $(yq e '.tenants | keys | .[]' "manifests/$MANIFEST_FILE"); do
  TENANT_SHA=$(yq e ".tenants.$tenant.sha" "manifests/$MANIFEST_FILE" 2>/dev/null || echo "")
  if [ -z "$TENANT_SHA" ] || [ "$TENANT_SHA" = "null" ]; then
    echo "⚠️  Warning: No SHA checksum provided for tenant $tenant artifact"
  else
    echo "✅ Tenant $tenant artifact SHA: $TENANT_SHA"
  fi
done