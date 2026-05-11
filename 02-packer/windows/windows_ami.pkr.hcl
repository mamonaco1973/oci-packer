# ================================================================================
# Packer Configuration and Plugin Setup
#
# Builds a custom Windows Server 2022 OCI image using the oracle-oci builder.
# Communicates via WinRM HTTPS — bootstrap_win.ps1 enables WinRM through
# cloudbase-init user_data before Packer attempts to connect.
# ================================================================================

packer {
  required_plugins {
    oracle = {
      source  = "github.com/hashicorp/oracle"
      version = "~> 1"
    }
    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = "0.15.0"
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
  description = "OCID of the Windows Server 2022 base image"
  default     = ""
}

variable "shape" {
  description = "OCI compute shape — Windows requires at least VM.Standard.E2.2"
  default     = "VM.Standard.E2.2"
}

variable "password" {
  description = "Administrator password set during provisioning and used by WinRM"
  default     = ""
}

# ================================================================================
# Oracle-OCI Source: Windows Server 2022 Image Build
# ================================================================================

source "oracle-oci" "windows_image" {
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid
  base_image_ocid     = var.base_image_ocid
  shape               = var.shape

  # Unique image name using a sanitized timestamp
  image_name = "desktop_image_${replace(timestamp(), ":", "-")}"

  # WinRM HTTPS communicator — bootstrap_win.ps1 configures WinRM via
  # cloudbase-init user_data before Packer connects
  communicator   = "winrm"
  winrm_username = "opc"
  winrm_password = var.password
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_port     = 5986
  # Allow time for Windows boot + cloudbase-init to run bootstrap_win.ps1
  winrm_timeout  = "20m"

  # cloudbase-init reads user_data on first boot to activate the opc account.
  # templatefile injects the password; the plugin handles base64 encoding.
  user_data = templatefile("./bootstrap_win.ps1", {
    password = var.password
  })
}

# ================================================================================
# Build: Provisioning and Image Preparation
# ================================================================================

build {
  sources = ["source.oracle-oci.windows_image"]

  provisioner "windows-update" {}

  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  provisioner "powershell" {
    script = "./security.ps1"
    environment_vars = [
      "PACKER_PASSWORD=${var.password}"
    ]
  }

  provisioner "powershell" {
    inline = ["mkdir C:\\mcloud"]
  }

  provisioner "file" {
    source      = "./boot.ps1"
    destination = "C:\\mcloud\\"
  }

  provisioner "powershell" {
    script = "./chrome.ps1"
  }

  provisioner "powershell" {
    script = "./firefox.ps1"
  }

  provisioner "powershell" {
    script = "./desktop.ps1"
  }

  # Reset cloudbase-init run state so each instance deployed from this image
  # gets fresh initialization — equivalent to EC2Launch sysprep on AWS
  provisioner "powershell" {
    inline = [
      "Remove-Item -Path 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\log\\cloudbase-init*' -Force -ErrorAction SilentlyContinue",
      "if (Test-Path 'HKLM:\\SOFTWARE\\Cloudbase Solutions\\Cloudbase-Init') { Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Cloudbase Solutions\\Cloudbase-Init' -Name 'ProcessUserData' -Value 1 -Type DWord -Force }"
    ]
  }
}
