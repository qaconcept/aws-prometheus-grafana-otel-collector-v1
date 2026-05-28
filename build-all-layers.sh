#!/bin/bash
# Location: root_project/build-all-layers.sh
# Execute this script from the project root folder (aws-prometheus-grafana-otel-collector-v1)

# Fail immediately if any native shell command returns a non-zero exit code
set -e

echo "========================================================================="
echo "Starting Cold-Start Rebuild: aws-prometheus-grafana-otel-collector-v1"
echo "========================================================================="

# Safeguard: Verify the execution context is the project root folder
if [ ! -d "terraform" ]; then
  echo "=> CRITICAL ERROR: This script must be executed from the project root folder containing the /terraform directory."
  exit 1
fi

# Step 1: Transition into the core terraform configuration plane
cd terraform

# Step 2: Loop through each infrastructure layer sequentially
for dir in $(ls -d layers/*/ | sort); do
  # Extract clean folder name (e.g., transforms 'layers/01-vpc/' into '01-vpc')
  LAYER_NAME=$(basename "$dir")
  
  echo "------------------------------------------------------------------------"
  echo "Processing Layer: $LAYER_NAME"
  echo "------------------------------------------------------------------------"
  
  # Navigate into the target layer path
  cd "layers/$LAYER_NAME"
  
  echo "=> Initializing Terraform..."
  terraform init -input=false
  
  echo "=> Executing Plan Verification..."
  terraform plan -var-file="../../central.tfvars"
  
  echo "=> Applying Infrastructure Changes..."
  terraform apply -var-file="../../central.tfvars" -auto-approve
  
  # Step 3: Return to the /terraform plane to execute the state bridge sync
  cd ../..
  
  echo "=> Orchestrating downstream variable sync for $LAYER_NAME..."
  
  # Capture both stdout and stderr from the sync execution engine while passing the required argument
  SYNC_OUTPUT=$(./sync-vars.sh "$LAYER_NAME" 2>&1)
  
  # Print the raw engine tracking data directly out to the primary terminal log
  echo "$SYNC_OUTPUT"
  
  # Step 4: Strict Validation Check for "Sync complete." string match
  if [[ "$SYNC_OUTPUT" == *"Sync complete."* ]]; then
    echo "=> SUCCESS: State synchronization verified for layer [$LAYER_NAME]."
  else
    echo "=> CRITICAL STATE BREAK: 'Sync complete.' token not found in synchronization output!"
    echo "Aborting deployment sequence to protect state integrity."
    exit 1
  fi
done

echo "========================================================================="
echo "DEPLOYMENT COMPLETE: All layers successfully applied and synchronized!"
echo "========================================================================="