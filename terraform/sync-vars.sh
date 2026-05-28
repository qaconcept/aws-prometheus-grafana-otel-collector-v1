#!/bin/bash
# Usage: ./sync-vars.sh <layer_directory_name> (e.g., ./sync-vars.sh 01-vpc)

LAYER=$1
if [ -z "$LAYER" ]; then
  echo "Error: Must provide layer directory name."
  exit 1
fi

LAYER_DIR="layers/$LAYER"
CENTRAL_TFVARS="../../central.tfvars"

cd "$LAYER_DIR" || exit 1

# Export outputs to JSON
OUTPUT_JSON=$(terraform output -json)

if [ -z "$OUTPUT_JSON" ] || [ "$OUTPUT_JSON" == "{}" ]; then
  echo "No outputs found for $LAYER."
  exit 0
fi

echo "Syncing outputs from $LAYER to central.tfvars..."

# Iterate through JSON keys
KEYS=$(echo "$OUTPUT_JSON" | jq -r 'keys[]')

for KEY in $KEYS; do
  VALUE=$(echo "$OUTPUT_JSON" | jq -c ".\"$KEY\".value")
  
  # Format lists properly for HCL, otherwise leave as string/number
  if echo "$VALUE" | grep -q "^\["; then
    FORMATTED_VALUE="$VALUE"
  else
    FORMATTED_VALUE=$(echo "$VALUE" | sed 's/^"//;s/"$//')
    FORMATTED_VALUE="\"$FORMATTED_VALUE\""
  fi

  # Check if key exists in central.tfvars, update if so, append if not
  if grep -q "^${KEY}[[:space:]]*=" "$CENTRAL_TFVARS"; then
    # Use awk to safely replace the specific key's line
    awk -v k="$KEY" -v v="$FORMATTED_VALUE" '
      $1 == k { print k " = " v; next }
      { print }
    ' "$CENTRAL_TFVARS" > tmp_tfvars && mv tmp_tfvars "$CENTRAL_TFVARS"
  else
    echo "$KEY = $FORMATTED_VALUE" >> "$CENTRAL_TFVARS"
  fi
done

echo "Sync complete."