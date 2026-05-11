# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

Three-phase Packer pipeline that builds OCI Custom Images and deploys compute instances from them.

- **Phase 1 (`01-infrastructure`):** Terraform provisions a VCN, IGW, route table, security list, and subnet. Generates an ECDSA SSH key pair and a random password, both surfaced as Terraform outputs.
- **Phase 2 (`02-packer`):** Packer builds a Linux `games` image (Ubuntu 24.04 + Apache + retro games) and optionally a Windows `desktop` image (Server 2022 + Chrome + Firefox).
- **Phase 3 (`03-deploy`):** Terraform deploys OCI compute instances from the custom images.

## Commands

```bash
./apply.sh               # validate env, provision, build, deploy (Windows on by default)
BUILD_WINDOWS=false ./apply.sh  # skip Windows Packer build and deployment
./destroy.sh             # teardown instances, delete custom images, destroy networking
./validate.sh            # print IP addresses and access commands
```

SSH to the Linux instance after deploy:

```bash
ssh -i 01-infrastructure/keys/Private_Key ubuntu@<games_server_ip>
```

## Architecture

**Network chain:** `oci_core_vcn` → `oci_core_internet_gateway` → `oci_core_route_table` → `oci_core_security_list` → `oci_core_subnet`

Security List attaches at the **subnet** level (not instance level like AWS Security Groups). Ingress ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 5986 (WinRM HTTPS), 3389 (RDP). One subnet is sufficient — no multi-AZ requirement.

**Packer plugin:** `github.com/hashicorp/oracle ~> 1` — source type `oracle-oci`.

**Linux build:** `VM.Standard.E2.1.Micro`, SSH communicator, `ubuntu` user. SSH public key injected via `metadata.ssh_authorized_keys`. Auth for Packer connection uses the key generated in Phase 1.

**Windows build:** `VM.Standard.E2.2` (minimum — Windows requires ≥ 2 OCPU). WinRM HTTPS communicator on port 5986. `bootstrap_win.ps1` is injected as cloudbase-init `user_data` to set the Administrator password and enable WinRM before Packer connects. Final provisioner resets cloudbase-init run state (equivalent to EC2Launch sysprep on AWS) so each deployed instance re-initializes.

**Deploy instances:**
- Games server: `VM.Standard.E2.1.Micro` (Always Free eligible)
- Desktop server: `VM.Standard.E2.2` — only created when `deploy_windows = true`

Custom images are resolved at deploy time via `oci_core_images` data source, filtered by display name regex (`games_image.*` / `desktop_image.*`), sorted `TIMECREATED DESC`, index `[0]`.

## Auth and Variable Wiring

- OCI auth: `~/.oci/config` DEFAULT profile — no credentials in code
- Compartment: set `OCI_COMPARTMENT_ID` env var; scripts export it as `TF_VAR_compartment_ocid`
- If `OCI_COMPARTMENT_ID` is unset, scripts fall back to the tenancy OCID from `~/.oci/config`
- Phase 1 outputs are read by `apply.sh` via `terraform -chdir=01-infrastructure output -raw <name>` and passed as `-var` flags to Packer and Phase 3 Terraform

## Optional Windows Toggle

`BUILD_WINDOWS` (shell env var, default `true`) gates both the Windows Packer build in Phase 2 and the Windows instance in Phase 3.

In `03-deploy`, `variable "deploy_windows" { type = bool, default = true }` drives:
- `data "oci_core_images" "desktop_image" { count = var.deploy_windows ? 1 : 0 }`
- `resource "oci_core_instance" "desktop_server" { count = var.deploy_windows ? 1 : 0 }`

`apply.sh` passes `-var "deploy_windows=$BUILD_WINDOWS"` to the Phase 3 apply. `destroy.sh` reads the same `BUILD_WINDOWS` env var to match the state.

## Keys

Terraform generates an ECDSA P-256 key pair via `tls_private_key` in Phase 1. The private key is written to `01-infrastructure/keys/Private_Key` (0600). The `keys/` directory is gitignored. The public key is passed to Packer (via `ssh_public_key` var) and to deployed Linux instances (via `metadata.ssh_authorized_keys`).

## Known OCI Quirks

- **cloud-init timing:** OCI fires cloud-init before DNS/routing is ready. `install.sh` and `userdata.sh` loop on `curl -4` to test actual IPv4 HTTP connectivity before running `apt-get`.
- **Ubuntu mirror DDoS (May 2026):** `archive.ubuntu.com` under sustained DDoS. Both `install.sh` and `userdata.sh` rewrite apt sources to `us.archive.ubuntu.com` via a heredoc before installing packages.
- **iptables default-deny:** OCI Ubuntu images block all ports via iptables regardless of the Security List. `install.sh` and `userdata.sh` both run `iptables -I INPUT -p tcp --dport 80 -j ACCEPT` explicitly.
- **cloudbase-init reset:** OCI Windows images use cloudbase-init instead of EC2Launch. The final Windows Packer provisioner removes cloudbase-init log files and sets `ProcessUserData = 1` in the registry so the initialization re-runs on each deployed instance.
- **WinRM timeout:** Windows boot + cloudbase-init execution takes time. `winrm_timeout = "20m"` in the Packer template prevents premature connection failures.
