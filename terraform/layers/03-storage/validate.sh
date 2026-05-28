#!/bin/bash
# Template for validate.sh (Example tuned for 01-vpc)
set -e

echo "Validating infrastructure state..."

# Source central variables for context
VPC_ID=$(grep '^vpc_id ' ../../central.tfvars | awk -F '"' '{print $2}')

if [ -z "$VPC_ID" ]; then
    echo "ERROR: vpc_id not found in central.tfvars. Did the layer apply successfully?"
    exit 1
fi

# Query AWS to ensure the resource is physically present and available
STATE=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].State' --output text)

if [ "$STATE" == "available" ]; then
    echo "SUCCESS: VPC $VPC_ID is available."
else
    echo "FAILED: VPC is in state $STATE."
    exit 1
fi