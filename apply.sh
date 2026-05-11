#!/bin/bash

# ==============================================================================
# APPLY PIPELINE: BUILD AND DEPLOY ENVIRONMENT
#
# Provisions networking, builds Linux (and optionally Windows) OCI custom
# images with Packer, then deploys compute instances from those images.
#
# Environment variables:
#   OCI_COMPARTMENT_ID  — compartment OCID (falls back to tenancy OCID)
#   BUILD_WINDOWS       — set to "false" to skip Windows build and deploy (default: true)
# ==============================================================================

set -euo pipefail

# ==============================================================================
# STEP 0: ENVIRONMENT VALIDATION
# ==============================================================================

./check_env.sh

# ==============================================================================
# STEP 1: RESOLVE COMPARTMENT OCID
# ==============================================================================

# Use OCI_COMPARTMENT_ID if set; otherwise fall back to the tenancy OCID from
# ~/.oci/config — same pattern as oci-setup
if [ -n "${OCI_COMPARTMENT_ID:-}" ]; then
  export TF_VAR_compartment_ocid="$OCI_COMPARTMENT_ID"
else
  tenancy_ocid=$(awk -F'=' '/^tenancy/{gsub(/ /,"",$2); print $2}' ~/.oci/config | head -1)
  export TF_VAR_compartment_ocid="$tenancy_ocid"
fi

echo "NOTE: Using compartment OCID: $TF_VAR_compartment_ocid"

# Controls whether Windows Packer build and deployment run
BUILD_WINDOWS="${BUILD_WINDOWS:-true}"
echo "NOTE: BUILD_WINDOWS=$BUILD_WINDOWS"

# ==============================================================================
# STEP 2: TERRAFORM APPLY — NETWORKING INFRASTRUCTURE
# ==============================================================================

echo "NOTE: Applying networking infrastructure"

cd 01-infrastructure
terraform init -upgrade
terraform apply -auto-approve
cd ..

# ==============================================================================
# STEP 3: READ OUTPUTS FROM 01-INFRASTRUCTURE
# ==============================================================================

subnet_ocid=$(terraform -chdir=01-infrastructure output -raw subnet_ocid)
availability_domain=$(terraform -chdir=01-infrastructure output -raw availability_domain)
ssh_public_key=$(terraform -chdir=01-infrastructure output -raw ssh_public_key)
packer_password=$(terraform -chdir=01-infrastructure output -raw packer_password)

if [[ -z "$subnet_ocid" || -z "$availability_domain" ]]; then
  echo "ERROR: Failed to read outputs from 01-infrastructure"
  exit 1
fi

echo "NOTE: Subnet OCID:          $subnet_ocid"
echo "NOTE: Availability Domain:  $availability_domain"

# ==============================================================================
# STEP 4: RESOLVE BASE IMAGE OCIDs
# ==============================================================================

echo "NOTE: Resolving Ubuntu 24.04 base image OCID..."
linux_image_ocid=$(oci compute image list \
  --compartment-id "$TF_VAR_compartment_ocid" \
  --operating-system "Canonical Ubuntu" \
  --operating-system-version "24.04" \
  --shape "VM.Standard.E2.1.Micro" \
  --sort-by TIMECREATED \
  --sort-order DESC \
  --limit 1 \
  --all \
  | jq -r '.data[0].id')

if [[ -z "$linux_image_ocid" || "$linux_image_ocid" == "null" ]]; then
  echo "ERROR: Failed to resolve Ubuntu 24.04 base image OCID"
  exit 1
fi
echo "NOTE: Linux base image OCID: $linux_image_ocid"

if [ "$BUILD_WINDOWS" = "true" ]; then
  echo "NOTE: Resolving Windows Server 2022 base image OCID..."
  windows_image_ocid=$(oci compute image list \
    --compartment-id "$TF_VAR_compartment_ocid" \
    --operating-system "Windows" \
    --operating-system-version "Server 2022 Standard" \
    --shape "VM.Standard.E2.2" \
    --sort-by TIMECREATED \
    --sort-order DESC \
    --limit 1 \
    --all \
    | jq -r '.data[0].id')

  if [[ -z "$windows_image_ocid" || "$windows_image_ocid" == "null" ]]; then
    echo "ERROR: Failed to resolve Windows Server 2022 base image OCID"
    exit 1
  fi
  echo "NOTE: Windows base image OCID: $windows_image_ocid"
fi

# ==============================================================================
# STEP 5: BUILD IMAGES WITH PACKER
# ==============================================================================

cd 02-packer

# ------------------------------------------------------------------------------
# Linux image build
# ------------------------------------------------------------------------------

cd linux
echo "NOTE: Building Linux image"

packer init linux_ami.pkr.hcl
packer build \
  -var "compartment_ocid=$TF_VAR_compartment_ocid" \
  -var "availability_domain=$availability_domain" \
  -var "subnet_ocid=$subnet_ocid" \
  -var "base_image_ocid=$linux_image_ocid" \
  -var "ssh_public_key=$ssh_public_key" \
  -var "password=$packer_password" \
  linux_ami.pkr.hcl

cd ..

# ------------------------------------------------------------------------------
# Windows image build (optional)
# ------------------------------------------------------------------------------

if [ "$BUILD_WINDOWS" = "true" ]; then
  cd windows
  echo "NOTE: Building Windows image"

  packer init windows_ami.pkr.hcl
  packer build \
    -var "compartment_ocid=$TF_VAR_compartment_ocid" \
    -var "availability_domain=$availability_domain" \
    -var "subnet_ocid=$subnet_ocid" \
    -var "base_image_ocid=$windows_image_ocid" \
    -var "password=$packer_password" \
    windows_ami.pkr.hcl

  cd ..
fi

cd ..

# ==============================================================================
# STEP 6: TERRAFORM APPLY — DEPLOY INSTANCES
# ==============================================================================

echo "NOTE: Deploying compute instances"

cd 03-deploy
terraform init -upgrade
terraform apply -auto-approve \
  -var "compartment_ocid=$TF_VAR_compartment_ocid" \
  -var "subnet_ocid=$subnet_ocid" \
  -var "availability_domain=$availability_domain" \
  -var "ssh_public_key=$ssh_public_key" \
  -var "packer_password=$packer_password" \
  -var "deploy_windows=$BUILD_WINDOWS"
cd ..

# ==============================================================================
# STEP 7: VALIDATE
# ==============================================================================

./validate.sh
