#!/bin/bash
set -euo pipefail

password=$(terraform -chdir=01-infrastructure output -raw packer_password)

echo "NOTE: Packer user:     packer"
echo "NOTE: Packer password: $password"
