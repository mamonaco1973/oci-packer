# Security rules consolidated into networking.tf as oci_core_security_list.
# OCI attaches security at the subnet level (Security List), not per-instance
# (Security Group), so a separate file is not needed.
