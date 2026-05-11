# ================================================================================
# Packer Credentials
# No OCI Secrets Manager equivalent in scope — password is generated here and
# surfaced via terraform output for apply.sh to pass to Packer at build time
# ================================================================================

resource "random_password" "packer" {
  # Alphanumeric only for compatibility with WinRM and cloud-init injection
  length  = 24
  special = false
}
