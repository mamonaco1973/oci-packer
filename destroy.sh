#!/bin/bash

# ==============================================================================
# DESTROY PIPELINE: TEARDOWN AND CLEANUP
#
# WARNING: Destructive and irreversible. Destroys deployed instances, deletes
# all custom images built by Packer, and tears down networking infrastructure.
# ==============================================================================

set -euo pipefail

# Resolve compartment OCID — same logic as apply.sh
if [ -n "${OCI_COMPARTMENT_ID:-}" ]; then
  export TF_VAR_compartment_ocid="$OCI_COMPARTMENT_ID"
else
  tenancy_ocid=$(awk -F'=' '/^tenancy/{gsub(/ /,"",$2); print $2}' ~/.oci/config | head -1)
  export TF_VAR_compartment_ocid="$tenancy_ocid"
fi

# Must match the BUILD_WINDOWS value used during apply so Terraform's count
# evaluation matches the existing state — avoids phantom create-then-destroy
BUILD_WINDOWS="${BUILD_WINDOWS:-true}"

# ==============================================================================
# STEP 1: DESTROY DEPLOYED INSTANCES
# ==============================================================================

cd 03-deploy
terraform init -upgrade
terraform destroy -auto-approve \
  -var "compartment_ocid=$TF_VAR_compartment_ocid" \
  -var "subnet_ocid=ocid1.placeholder" \
  -var "availability_domain=placeholder" \
  -var "ssh_public_key=placeholder" \
  -var "packer_password=placeholder" \
  -var "deploy_windows=$BUILD_WINDOWS"
cd ..

# ==============================================================================
# STEP 2: DELETE CUSTOM IMAGES BUILT BY PACKER
# ==============================================================================

echo "NOTE: Deleting custom games images..."
for image_id in $(oci compute image list \
  --compartment-id "$TF_VAR_compartment_ocid" \
  --all \
  | jq -r '.data[] | select(.["display-name"] | test("^games_image_")) | .id'); do

  echo "NOTE: Deleting image: $image_id"
  oci compute image delete --image-id "$image_id" --force
done

echo "NOTE: Deleting custom desktop images..."
for image_id in $(oci compute image list \
  --compartment-id "$TF_VAR_compartment_ocid" \
  --all \
  | jq -r '.data[] | select(.["display-name"] | test("^desktop_image_")) | .id'); do

  echo "NOTE: Deleting image: $image_id"
  oci compute image delete --image-id "$image_id" --force
done

# ==============================================================================
# STEP 3: DESTROY NETWORKING INFRASTRUCTURE
# ==============================================================================

cd 01-infrastructure
terraform init -upgrade
terraform destroy -auto-approve
cd ..
