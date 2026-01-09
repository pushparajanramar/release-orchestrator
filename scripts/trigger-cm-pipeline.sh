#!/bin/bash

PIPELINE_NAME=$1

# Validate input
if [ -z "$PIPELINE_NAME" ]; then
  echo "❌ Usage: $0 <pipeline-name>"
  echo "   Example: $0 platform-dev"
  exit 1
fi

# Validate required environment variables
if [ -z "$CM_CLIENT_ID" ] || [ -z "$CM_CLIENT_SECRET" ] || [ -z "$CM_API_KEY" ]; then
  echo "❌ Missing required environment variables:"
  echo "   CM_CLIENT_ID, CM_CLIENT_SECRET, CM_API_KEY must be set"
  echo "   Run: source .env"
  exit 1
fi

# Read pipeline config
if [ ! -f "pipelines/$PIPELINE_NAME.yaml" ]; then
  echo "❌ Pipeline config not found: pipelines/$PIPELINE_NAME.yaml"
  exit 1
fi

PIPELINE_ID=$(yq e ".pipelineId" pipelines/$PIPELINE_NAME.yaml)
PROGRAM_ID=$(yq e ".programId" pipelines/$PIPELINE_NAME.yaml)

if [ "$PIPELINE_ID" = "null" ] || [ "$PROGRAM_ID" = "null" ]; then
  echo "❌ Invalid pipeline config: missing pipelineId or programId"
  exit 1
fi

# Cloud Manager API endpoint for triggering pipeline execution
API_BASE="https://cloudmanager.adobe.io/api/program/${PROGRAM_ID}/pipeline/${PIPELINE_ID}/execution"

echo "Triggering pipeline: $PIPELINE_NAME (ID: $PIPELINE_ID, Program: $PROGRAM_ID)"
echo "API Endpoint: $API_BASE"

# Get access token using Adobe IMS
ACCESS_TOKEN=$(curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${CM_CLIENT_ID}&client_secret=${CM_CLIENT_SECRET}&scope=openid,AdobeID,additional_info.projectedProductContext" \
  https://ims-na1.adobelogin.com/ims/token/v3)

if [ $? -ne 0 ]; then
  echo "❌ Failed to get access token"
  exit 1
fi

TOKEN=$(echo $ACCESS_TOKEN | jq -r '.access_token')
if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Invalid access token received"
  exit 1
fi

echo "✅ Access token obtained"

# Trigger pipeline execution
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: ${CM_API_KEY}" \
  -H "Content-Type: application/json" \
  "$API_BASE")

if [ $? -ne 0 ]; then
  echo "❌ Failed to trigger pipeline"
  exit 1
fi

# Check response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: ${CM_API_KEY}" \
  -H "Content-Type: application/json" \
  "$API_BASE")

if [ $HTTP_CODE -eq 201 ] || [ $HTTP_CODE -eq 202 ]; then
  echo "✅ Pipeline triggered successfully (HTTP $HTTP_CODE)"
  EXECUTION_ID=$(echo $RESPONSE | jq -r '._links.self.href' | grep -o 'execution/[0-9]*' | cut -d'/' -f2)
  if [ ! -z "$EXECUTION_ID" ]; then
    echo "📋 Execution ID: $EXECUTION_ID"
  fi
else
  echo "❌ Pipeline trigger failed (HTTP $HTTP_CODE)"
  echo "Response: $RESPONSE"
  exit 1
fi