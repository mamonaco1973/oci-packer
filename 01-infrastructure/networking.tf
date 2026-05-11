# ================================================================================
# Networking — VCN → IGW → Route Table → Security List → Subnet
# OCI has no implicit default network — every component must be explicit
# ================================================================================

# OCI requires explicit AD selection — resolved dynamically so this works
# across regions with different numbers of availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# ================================================================================
# VCN
# ================================================================================

resource "oci_core_vcn" "packer_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "packer-vcn"
  # dns_label must be alphanumeric and ≤ 15 chars — forms the VCN DNS domain
  dns_label      = "packervcn"
}

# ================================================================================
# Internet Gateway + Route Table
# ================================================================================

resource "oci_core_internet_gateway" "packer_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.packer_vcn.id
  display_name   = "packer-igw"
  enabled        = true
}

resource "oci_core_route_table" "packer_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.packer_vcn.id
  display_name   = "packer-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.packer_igw.id
  }
}

# ================================================================================
# Subnet
# One subnet is sufficient — OCI security lists are per-subnet, not per-instance
# ================================================================================

resource "oci_core_subnet" "packer_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.packer_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "packer-subnet"
  dns_label         = "packersubnet"
  route_table_id    = oci_core_route_table.packer_rt.id
  security_list_ids = [oci_core_security_list.packer_sl.id]
}
