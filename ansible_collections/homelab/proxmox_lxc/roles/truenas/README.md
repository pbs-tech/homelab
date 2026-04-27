# truenas Role

Deploys TrueNAS SCALE as a KVM/QEMU virtual machine on Proxmox. Handles ISO download,
VM creation, and disk configuration for homelab NAS storage workloads.

## Features

- **ISO Download** - Fetches TrueNAS SCALE ISO to Proxmox storage
- **VM Creation** - Creates and configures a KVM VM via the Proxmox API
- **Idempotent** - Skips download and creation steps if already complete

## Requirements

- Proxmox VE host with API token credentials
- `homelab.common.vm_base` role (Proxmox API integration)
- Sufficient disk space on Proxmox storage for ISO and VM disk

## Role Variables

```yaml
# TrueNAS ISO source
truenas_iso_url: "https://download.truenas.com/..."
truenas_iso_filename: "TrueNAS-SCALE.iso"
truenas_download_iso: true

# VM placement
proxmox_node: pve-nas
```

## Usage

```yaml
- hosts: truenas
  roles:
    - role: homelab.proxmox_lxc.truenas
```
