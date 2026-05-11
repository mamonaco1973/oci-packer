# ================================================================================
# Packer Configuration and Plugin Setup
#
# Builds a custom Ubuntu 24.04 OCI image using the oracle-oci builder.
# Workflow:
#   1. Launch a temporary compute instance from the Ubuntu base image
#   2. Provision files and run configuration scripts
#   3. Create a custom image and terminate the build instance
#
# Variables are supplied at runtime via apply.sh — no hardcoded OCIDs.
# ================================================================================

packer {
  required_plugins {
    oracle = {
      source  = "github.com/hashicorp/oracle"
      version = "~> 1"
    }
  }
}

# ================================================================================
# Variables
# ================================================================================

variable "compartment_ocid" {
  description = "Compartment where the build instance and output image are created"
  default     = ""
}

variable "availability_domain" {
  description = "Availability domain for the temporary build instance"
  default     = ""
}

variable "subnet_ocid" {
  description = "Subnet for the temporary build instance — must allow internet egress"
  default     = ""
}

variable "base_image_ocid" {
  description = "OCID of the Ubuntu 24.04 base image"
  default     = ""
}

variable "shape" {
  description = "OCI compute shape for the temporary build instance"
  default     = "VM.Standard.E2.1.Micro"
}

variable "ssh_public_key" {
  description = "SSH public key injected into the build instance for Packer access"
  default     = ""
}

variable "password" {
  description = "Password for the packer OS user created during provisioning"
  default     = ""
}

# ================================================================================
# Oracle-OCI Source: Custom Ubuntu Image Build
# ================================================================================

source "oracle-oci" "ubuntu_image" {
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid
  base_image_ocid     = var.base_image_ocid
  shape               = var.shape

  # Unique image name using a sanitized timestamp
  image_name = "games_image_${replace(timestamp(), ":", "-")}"

  # Default SSH username for Canonical Ubuntu OCI images
  ssh_username = "ubuntu"

  # Packer injects our generated public key — private key is on disk for auth
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# ================================================================================
# Build: File Provisioning and Configuration Scripts
# ================================================================================

build {
  sources = ["source.oracle-oci.ubuntu_image"]

  provisioner "shell" {
    inline = ["mkdir -p /tmp/html"]
  }

  provisioner "file" {
    source      = "./html/"
    destination = "/tmp/html/"
  }

  provisioner "shell" {
    script = "./install.sh"
  }

  provisioner "shell" {
    script = "./config_ssh.sh"
    environment_vars = [
      "PACKER_PASSWORD=${var.password}"
    ]
  }
}
