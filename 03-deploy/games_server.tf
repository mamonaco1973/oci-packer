# ================================================================================
# Compute Instance: Games Server
# Deployed from the most recent custom Linux image built by Packer
# ================================================================================

resource "oci_core_instance" "games_server" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "games-server"

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.games_image.images[0].id
  }

  create_vnic_details {
    subnet_id        = var.subnet_ocid
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    # user_data must be base64-encoded — cloud-init decodes it on first boot
    user_data           = base64encode(templatefile("${path.module}/scripts/userdata.sh", {
      ami_name = data.oci_core_images.games_image.images[0].display_name
    }))
  }
}
