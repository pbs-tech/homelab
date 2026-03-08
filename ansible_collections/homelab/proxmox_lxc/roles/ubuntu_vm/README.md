# ubuntu_vm Role

Clones Ubuntu cloud-init VMs from a Proxmox template (created by `playbooks/create-vm-template.yml`).
Configures networking, SSH keys, and hardware via cloud-init before waiting for the VM to become
reachable over SSH.

## Features

- **Template Validation** - Verifies the cloud-init template exists before cloning
- **Full Clone** - Creates independent VMs from template ID 9000 (default)
- **Cloud-Init Config** - Injects IP, gateway, DNS, search domain, and SSH public key
- **Firewall Groups** - Applies `basic-network`, `allow-ssh`, and `allow-web` security groups
- **SSH Readiness Wait** - Blocks until the VM is reachable before returning

## Requirements

- Proxmox VE host with API token credentials
- Cloud-init template created via `ansible-playbook playbooks/create-vm-template.yml`
- `homelab.common.vm_base` role

## Role Variables

```yaml
# Template to clone from (created by create-vm-template.yml)
ubuntu_vm_template_id: 9000

# Cloud-init settings
vm_cloudinit:
  user: ansible
  ip_config: "ip={{ ansible_host }}/24,gw={{ homelab_network.gateway_ip }}"
  dns_servers: "{{ homelab_network.dns_servers | join(' ') }}"
  search_domain: "{{ homelab_domain }}"
  ssh_public_key: "{{ lookup('file', '~/.ssh/homelab_ed25519.pub') }}"

# Hardware
vm_resources:
  cores: 2
  memory: 2048
  disk_size: 32
```

## Usage

```yaml
- hosts: ubuntu_vms
  roles:
    - role: homelab.proxmox_lxc.ubuntu_vm
```

The cloud-init template must exist on the target Proxmox node before running this role:

```bash
ansible-playbook playbooks/create-vm-template.yml --ask-vault-pass
```
