#!/bin/bash

PIPELINE_NAME=$1

# Read pipeline config
PIPELINE_ID=$(yq e ".pipelineId" pipelines/$PIPELINE_NAME.yaml)
PROGRAM_ID=$(yq e ".programId" pipelines/$PIPELINE_NAME.yaml)

# Call Cloud Manager API to trigger pipeline
# Use curl with authentication
echo "Triggering pipeline: $PIPELINE_NAME (ID: $PIPELINE_ID, Program: $PROGRAM_ID)"
# Add API call here