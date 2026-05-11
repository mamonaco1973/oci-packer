# ================================================================================
# Security List
# Attaches at the subnet level — unlike AWS Security Groups which attach to
# instances. All instances in the subnet share these rules.
# ================================================================================

resource "oci_core_security_list" "packer_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.packer_vcn.id
  display_name   = "packer-security-list"

  # SSH — Packer Linux communicator and deployed instance access
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  # HTTP — games server web traffic
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS — general browser and build traffic
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  # WinRM HTTPS — Packer communicator for Windows builds
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 5986
      max = 5986
    }
  }

  # RDP — Windows desktop server remote access
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 3389
      max = 3389
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}
