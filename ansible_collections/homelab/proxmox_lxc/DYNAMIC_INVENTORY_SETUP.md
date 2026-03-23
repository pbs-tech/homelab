# Proxmox Dynamic Inventory Setup

This collection now uses the `community.proxmox.proxmox` dynamic inventory plugin for automatic
discovery of Proxmox VMs and LXC containers.

## Setup Steps

1. **Run the setup script:**

   ```bash
   ./setup_proxmox_inventory.sh
   ```

   This will:
   - Create a vault password file at `~/.ansible_vault_pass`
   - Help you encrypt your Proxmox password
   - Provide the encrypted password to update `inventory/proxmox.yml`

2. **Update the proxmox.yml file:**
   - Replace the placeholder password section with your encrypted password
   - Adjust the Proxmox server URL if needed (currently set to `https://192.168.0.56:8006`)

3. **Test the inventory:**

   ```bash
   ansible-inventory --vault-password-file ~/.ansible_vault_pass --list
   ```

## Configuration Details

### Automatic Grouping

The dynamic inventory automatically creates groups based on:

- **Service Type**: `monitoring`, `networking`, `automation`, `logging`, `nas_services`, `nas_monitoring`, `nas_storage`
- **Container Type**: `lxc_containers`, `vms`
- **Proxmox Node**: `pve_mac`, `pve_nas`
- **Status**: `running`, `stopped`

### Automatic Variables

The following variables are automatically set:

- `ansible_host`: Container/VM IP address
- `container_id`: Proxmox VMID
- `service_port`: Automatically detected based on service name

### Filters

- Only running containers/VMs are included by default
- This can be adjusted in the `filters` section of `inventory/proxmox.yml`

## Relationship to Static Inventory

The static inventory (`inventory/hosts.yml`) remains the primary authoritative inventory for
all root playbooks under `playbooks/`. The dynamic inventory (`proxmox_lxc/inventory/proxmox.yml`)
is used within the proxmox_lxc collection context for container-specific operations.

Both inventories coexist. Use the static inventory for infrastructure-level orchestration and the
dynamic inventory for Proxmox-specific container management tasks.

If you need to add custom variables for specific hosts, create files in `inventory/host_vars/[hostname].yml`.

## Troubleshooting

1. **SSL Certificate Issues**: Set `validate_certs: false` in `proxmox.yml` if using self-signed certificates
2. **Authentication Issues**: Verify your Proxmox credentials and ensure the user has appropriate permissions
3. **Network Issues**: Ensure the Proxmox API is accessible from your Ansible control machine

## Commands

```bash
# List all discovered hosts
ansible-inventory --vault-password-file ~/.ansible_vault_pass --list

# List hosts in a specific group
ansible-inventory --vault-password-file ~/.ansible_vault_pass --graph monitoring

# Show specific host details
ansible-inventory --vault-password-file ~/.ansible_vault_pass --host prometheus-lxc

# Test connectivity to all discovered hosts
ansible all --vault-password-file ~/.ansible_vault_pass -m ping

# Run playbook with dynamic inventory
ansible-playbook --vault-password-file ~/.ansible_vault_pass site.yml
```
