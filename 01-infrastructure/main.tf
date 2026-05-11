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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "oci" {
  region = "us-ashburn-1"
}

variable "compartment_ocid" {
  description = "OCID of the compartment to deploy resources into"
}

# ================================================================================
# SSH Key Pair
# Generated fresh each deploy — private key written to keys/ (gitignored)
# ECDSA P-256 is smaller and faster than RSA while being equally secure
# ================================================================================

resource "tls_private_key" "ssh" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "./keys/Private_Key"
  file_permission = "0600"
}

# ================================================================================
# Outputs
# Consumed by apply.sh to pass values into Packer and 03-deploy
# ================================================================================

output "subnet_ocid" {
  value = oci_core_subnet.packer_subnet.id
}

output "availability_domain" {
  value = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

output "ssh_public_key" {
  value = tls_private_key.ssh.public_key_openssh
}

output "ssh_private_key_path" {
  value = local_file.private_key.filename
}

output "packer_password" {
  value     = random_password.packer.result
  sensitive = true
}
