# ================================================================================
# OCI Provider Configuration
# Auth reads from ~/.oci/config DEFAULT profile — no credentials in code
# ================================================================================

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  region = "us-ashburn-1"
}

output "games_server_ip" {
  value = oci_core_instance.games_server.public_ip
}

output "desktop_server_ip" {
  value = var.deploy_windows ? oci_core_instance.desktop_server[0].public_ip : "windows deployment disabled"
}
