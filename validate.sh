#!/bin/bash
set -euo pipefail

# ==============================================================================
# VALIDATION: PRINT ACCESS DETAILS FOR DEPLOYED INSTANCES
# ==============================================================================

games_ip=$(terraform -chdir=03-deploy output -raw games_server_ip)
desktop_ip=$(terraform -chdir=03-deploy output -raw desktop_server_ip)

echo "NOTE: Games URL is http://$games_ip"
echo "NOTE: Games server IP is $games_ip"
echo "NOTE: SSH: ssh -i 01-infrastructure/keys/Private_Key ubuntu@$games_ip"

echo "NOTE: Windows desktop IP is $desktop_ip"
echo "NOTE: RDP to $desktop_ip with user 'packer'"
