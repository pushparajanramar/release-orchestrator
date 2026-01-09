#!/bin/bash

PIPELINE_NAME=$1
MAX_WAIT_MINUTES=${2:-60}  # Default 60 minutes timeout

# Validate input
if [ -z "$PIPELINE_NAME" ]; then
  echo "❌ Usage: $0 <pipeline-name> [max-wait-minutes]"
  echo "   Example: $0 platform-prod 30"
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

PIPELINE_ID=$(yq e ".pipelineId" "pipelines/$PIPELINE_NAME.yaml")
PROGRAM_ID=$(yq e ".programId" "pipelines/$PIPELINE_NAME.yaml")

if [ "$PIPELINE_ID" = "null" ] || [ "$PROGRAM_ID" = "null" ]; then
  echo "❌ Invalid pipeline config: missing pipelineId or programId"
  exit 1
fi

echo "⏳ Waiting for pipeline: $PIPELINE_NAME (ID: $PIPELINE_ID, Program: $PROGRAM_ID)"
echo "   Timeout: $MAX_WAIT_MINUTES minutes"

# Cloud Manager API base URL
API_BASE="https://cloudmanager.adobe.io/api/program/${PROGRAM_ID}/pipeline/${PIPELINE_ID}"

# Function to get access token
get_access_token() {
  local token_response
  token_response=$(curl -s -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=${CM_CLIENT_ID}&client_secret=${CM_CLIENT_SECRET}&scope=openid,AdobeID,additional_info.projectedProductContext" \
    https://ims-na1.adobelogin.com/ims/token/v3)

  if [ $? -ne 0 ]; then
    echo "❌ Failed to get access token"
    return 1
  fi

  local token
  token=$(echo "$token_response" | jq -r '.access_token')
  if [ "$token" = "null" ] || [ -z "$token" ]; then
    echo "❌ Invalid access token received"
    return 1
  fi

  echo "$token"
  return 0
}

# Function to get current execution
get_current_execution() {
  local token=$1
  local response

  response=$(curl -s -X GET \
    -H "Authorization: Bearer $token" \
    -H "x-api-key: ${CM_API_KEY}" \
    -H "Content-Type: application/json" \
    "${API_BASE}/execution")

  if [ $? -ne 0 ]; then
    echo "❌ Failed to get execution status"
    return 1
  fi

  echo "$response"
  return 0
}

# Function to check execution status
check_execution_status() {
  local execution_data=$1
  local status
  local execution_id

  # Extract status from the most recent execution
  status=$(echo "$execution_data" | jq -r '._embedded.executions[0].status // empty')
  execution_id=$(echo "$execution_data" | jq -r '._embedded.executions[0].id // empty')

  if [ -z "$status" ]; then
    echo "❌ No execution found for pipeline"
    return 1
  fi

  echo "$status:$execution_id"
  return 0
}

# Main polling loop
START_TIME=$(date +%s)
TOKEN=$(get_access_token)
if [ $? -ne 0 ]; then
  exit 1
fi

echo "✅ Access token obtained"

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED_MINUTES=$(( (CURRENT_TIME - START_TIME) / 60 ))

  if [ $ELAPSED_MINUTES -ge $MAX_WAIT_MINUTES ]; then
    echo "❌ Timeout: Pipeline did not complete within $MAX_WAIT_MINUTES minutes"
    exit 1
  fi

  # Get current execution status
  EXECUTION_DATA=$(get_current_execution "$TOKEN")
  if [ $? -ne 0 ]; then
    echo "⚠️  Failed to check status, retrying in 30 seconds..."
    sleep 30
    continue
  fi

  # Check if there's an execution
  STATUS_INFO=$(check_execution_status "$EXECUTION_DATA")
  if [ $? -ne 0 ]; then
    echo "⏳ No active execution found, waiting..."
    sleep 30
    continue
  fi

  STATUS=$(echo "$STATUS_INFO" | cut -d: -f1)
  EXECUTION_ID=$(echo "$STATUS_INFO" | cut -d: -f2)

  echo "📊 Pipeline Status: $STATUS (Execution: $EXECUTION_ID, Elapsed: ${ELAPSED_MINUTES}m)"

  case $STATUS in
    "RUNNING"|"STARTING"|"CANCELLED")
      echo "⏳ Still running, checking again in 30 seconds..."
      sleep 30
      ;;
    "FINISHED")
      echo "✅ Pipeline completed successfully!"
      exit 0
      ;;
    "ERROR"|"FAILED")
      echo "❌ Pipeline failed!"
      exit 1
      ;;
    *)
      echo "⚠️  Unknown status: $STATUS, checking again in 30 seconds..."
      sleep 30
      ;;
  esac
done