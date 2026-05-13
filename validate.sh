#!/bin/bash

# ==============================================================================
# VALIDATE SCRIPT: DISPLAY DEPLOYED OCI INSTANCE ACCESS DETAILS
# ==============================================================================
# Retrieves key Terraform outputs and prints them in a human-readable format.
# Run after a successful apply.sh.
# ==============================================================================

set -euo pipefail
cd 03-deploy

# ------------------------------------------------------------------------------
# VERIFY TERRAFORM INITIALIZATION
# ------------------------------------------------------------------------------
if [ ! -d ".terraform" ]; then
  echo "ERROR: Terraform is not initialized in this directory."
  echo "Run 'terraform init' before executing this script."
  exit 1
fi

# ------------------------------------------------------------------------------
# RETRIEVE TERRAFORM OUTPUTS
# ------------------------------------------------------------------------------
GAMES_SERVER_IP=$(terraform output -raw games_server_ip)
DESKTOP_SERVER_IP=$(terraform output -raw desktop_server_ip)

# ------------------------------------------------------------------------------
# DISPLAY RESULTS
# ------------------------------------------------------------------------------
echo "============================================================"
echo " OCI Compute Instance Access Details"
echo "============================================================"
echo
echo " Games Server Public IP:"
echo "   ${GAMES_SERVER_IP}"
echo "   http://${GAMES_SERVER_IP}"
echo "   ssh -i ./01-infrastructure/keys/Private_Key ubuntu@${GAMES_SERVER_IP}"
echo
echo " Windows Desktop Server Public IP:"
echo "   ${DESKTOP_SERVER_IP}"
echo "   RDP to ${DESKTOP_SERVER_IP} with user 'packer'"
echo "   Run ./get_password.sh to retrieve the packer account password"
echo
echo "============================================================"

cd ..
