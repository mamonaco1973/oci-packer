# ================================================================================
# Compute Instance: Desktop Server (Windows)
# Only deployed when deploy_windows = true — count drives conditional creation
# ================================================================================

resource "oci_core_instance" "desktop_server" {
  count = var.deploy_windows ? 1 : 0

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  # Windows requires at least VM.Standard.E2.2 (2 OCPU, 30 GB RAM)
  shape          = "VM.Standard.E2.2"
  display_name   = "desktop-server"

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.desktop_image[0].images[0].id
  }

  create_vnic_details {
    subnet_id        = var.subnet_ocid
    assign_public_ip = true
  }

  metadata = {
    # user_data runs via cloudbase-init on first boot
    user_data = base64encode(templatefile("${path.module}/scripts/userdata.ps1", {
      ami_name = data.oci_core_images.desktop_image[0].images[0].display_name
    }))
  }
}
