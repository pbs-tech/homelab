# vm_base Role

Core role for Proxmox KVM/QEMU virtual machine lifecycle management. Provides standardized VM
creation, configuration, and secure API integration for homelab infrastructure deployments.

## Features

- **Dual Creation Modes** - Create VMs from ISO (scratch) or clone from cloud-init templates
- **Proxmox API Integration** - Secure token-based API authentication with validation
- **Cloud-Init Support** - Automated OS configuration for cloned VMs
- **Idempotent Operations** - Safe to run multiple times without duplicating resources

## Requirements

- Proxmox VE host with API token credentials configured
- `community.proxmox` Ansible collection

## Role Variables

```yaml
# Proxmox API connection
proxmox_api_host: "192.168.0.56"
proxmox_api_token_id: "user@realm!tokenname"
proxmox_api_token_secret: "secret"

# VM creation mode: scratch (ISO) or clone (template)
vm_clone:
  enabled: false
  template_id: 9000
```

## Usage

```yaml
- hosts: proxmox_vms
  roles:
    - role: homelab.common.vm_base
```
