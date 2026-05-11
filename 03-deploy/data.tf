# ================================================================================
# Data Sources — look up custom images built by the Packer pipeline
# ================================================================================

# ================================================================================
# Games Image (Linux)
# Resolves the most recent custom image produced by the Linux Packer build
# ================================================================================

data "oci_core_images" "games_image" {
  compartment_id = var.compartment_ocid

  # Restrict to custom images owned by this tenancy
  state = "AVAILABLE"

  filter {
    name   = "display_name"
    values = ["games_image.*"]
    regex  = true
  }

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

# ================================================================================
# Desktop Image (Windows)
# Only resolved when deploy_windows is true — avoids failure when no Windows
# image has been built
# ================================================================================

data "oci_core_images" "desktop_image" {
  count          = var.deploy_windows ? 1 : 0
  compartment_id = var.compartment_ocid

  state = "AVAILABLE"

  filter {
    name   = "display_name"
    values = ["desktop_image.*"]
    regex  = true
  }

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}
