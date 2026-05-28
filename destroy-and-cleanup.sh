#!/bin/bash
# Location: root_project/destroy-and-cleanup.sh
# Execute this script from the project root folder (aws-prometheus-grafana-otel-collector-v1)

# Fail immediately if any native shell command returns a non-zero exit code
set -e

echo "========================================================================="
echo "Starting Complete Infrastructure Teardown & Workspace Purge"
echo "Project: aws-prometheus-grafana-otel-collector-v1"
echo "========================================================================="

# Safeguard: Verify execution context matches the root folder
if [ ! -d "terraform" ]; then
  echo "=> CRITICAL ERROR: This script must be executed from the project root folder containing the /terraform directory."
  exit 1
fi

# Step 1: Enter the core terraform configuration plane
cd terraform

# Step 2: Infrastructure Teardown Loop (Strict Reverse Order)
echo "=> Initiating reverse-order destruction of Fargate infrastructure layers..."
set +e
for dir in $(ls -d layers/*/ | sort -r); do
  LAYER_NAME=$(basename "$dir")
  echo "------------------------------------------------------------------------"
  echo "DESTROYING LAYER: $LAYER_NAME"
  echo "------------------------------------------------------------------------"
  
  cd "layers/$LAYER_NAME"
  
  # Run destruction using the central variables source of truth
  terraform destroy -var-file="../../central.tfvars" -auto-approve
  
  cd ../..
done
set -e 

echo "------------------------------------------------------------------------"
echo "=> Infrastructure destruction loop completed."
echo "------------------------------------------------------------------------"

# Step 3: Local Filesystem Purge
echo "=> Purging local .terraform directories, locks, states, and cache binaries..."

find . -type d -name ".terraform" -exec rm -rf {} \; 2>/dev/null || true
find . -type f -name ".terraform.lock.hcl" -delete
find . -type f -name "*.tfstate" -delete
find . -type f -name "*.tfstate.backup" -delete
find . -type f -name "*.plan" -delete

echo "=> Verification scan for residual local state artifacts (should be empty):"
find . -name ".terraform" -o -name "*.tfstate*"

# Step 4: Reset the State Bridge (central.tfvars) to Core Variables Baseline
echo "=> Resetting central.tfvars back to core baseline definition..."

cat << 'EOF' > central.tfvars
project_name        = "aws-prometheus-grafana-otel-collector-v1"
region              = "us-east-1"
aws_region          = "us-east-1"
environment         = "dev"
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
domain_name         = "sreconcepts.com"
create_ssl_cert     = false
dockerhub_username  = "qaconcept" # used for 11-test-app which is optional.
EOF

echo "========================================================================="
echo "CLEANUP COMPLETE: Infrastructure destroyed and workspace reset to cold-start state!"
echo "========================================================================="