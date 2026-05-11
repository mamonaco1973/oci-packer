#!/bin/bash
set -euo pipefail

echo "NOTE: Validating that required commands are found in your PATH."
commands=("oci" "packer" "terraform" "jq")

all_found=true

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: $cmd is not found in the current PATH."
    all_found=false
  else
    echo "NOTE: $cmd is found in the current PATH."
  fi
done

if [ "$all_found" = false ]; then
  echo "ERROR: One or more commands are missing."
  exit 1
fi

echo "NOTE: All required commands are available."

# Verify OCI config exists and the CLI can reach the API
if [ ! -f "$HOME/.oci/config" ]; then
  echo "ERROR: ~/.oci/config not found. Run 'oci setup config' to configure."
  exit 1
fi

echo "NOTE: Checking OCI CLI connection..."
oci iam region list --output table > /dev/null

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to connect to OCI. Check ~/.oci/config credentials."
  exit 1
fi

echo "NOTE: Successfully connected to OCI."
