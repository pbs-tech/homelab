# K3s Upgrade Role

Safely upgrades K3s cluster nodes to a newer version with service preservation, configuration backup, and minimal downtime. Handles both server and agent node upgrades with intelligent version detection and rollback capabilities.

## Features

- **Intelligent Version Detection** - Only upgrades when necessary
- **Service Preservation** - Maintains service configuration during upgrade
- **Configuration Backup** - Automatically backs up service files
- **Minimal Downtime** - Quick upgrade process with service restart
- **Server and Agent Support** - Handles both node types
- **Rollback Capability** - Service file backups enable quick rollback
- **Idempotent Operations** - Safe to run multiple times
- **Version Validation** - Validates upgrade path compatibility
- **Multi-Architecture** - Supports AMD64, ARM64, and ARM
- **Daemon Reload** - Ensures systemd picks up any changes

## Requirements

- Ansible core 2.14 or higher
- Existing K3s installation (server or agent)
- Root or sudo access
- Network connectivity for K3s download (unless airgapped)
- Sufficient disk space for new binary
- K3s version variable defined

## Role Variables

### Upgrade Configuration

```yaml
# Target K3s version
k3s_version: "v1.28.5+k3s1"

# Systemd directory
systemd_dir: /etc/systemd/system

# Server node group name
server_group: server

# Agent node group name
agent_group: agent

# Extra installation environment variables
extra_install_envs: {}
```

## Usage

### Basic Cluster Upgrade

```yaml
- name: Upgrade K3s cluster
  hosts: k3s_cluster
  become: yes
  serial: 1  # Upgrade one node at a time
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.k3s_upgrade
```

### Server-First Upgrade Strategy

```yaml
- name: Upgrade K3s servers first
  hosts: k3s_servers
  become: yes
  serial: 1
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.k3s_upgrade

- name: Upgrade K3s agents
  hosts: k3s_agents
  become: yes
  serial: 3  # Upgrade 3 agents at a time
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.k3s_upgrade
```

### Rolling Upgrade with Verification

```yaml
- name: Perform rolling K3s upgrade
  hosts: k3s_cluster
  become: yes
  serial: 1
  vars:
    k3s_version: "v1.28.5+k3s1"

  pre_tasks:
    - name: Create etcd snapshot (servers only)
      command: k3s etcd-snapshot save --name pre-upgrade-{{ ansible_date_time.epoch }}
      when:
        - inventory_hostname in groups['k3s_servers']
        - inventory_hostname == groups['k3s_servers'][0]

  roles:
    - homelab.proxmox_lxc.k3s_upgrade

  post_tasks:
    - name: Wait for node to be ready
      command: kubectl wait --for=condition=Ready node/{{ inventory_hostname }} --timeout=300s
      delegate_to: "{{ groups['k3s_servers'][0] }}"
      retries: 3
      delay: 10

    - name: Verify node version
      command: kubectl get node {{ inventory_hostname }} -o jsonpath='{.status.nodeInfo.kubeletVersion}'
      delegate_to: "{{ groups['k3s_servers'][0] }}"
      register: node_version
      changed_when: false

    - name: Display upgraded version
      debug:
        msg: "Node {{ inventory_hostname }} upgraded to {{ node_version.stdout }}"
```

### Airgapped Upgrade

```yaml
- name: Upgrade K3s in airgapped environment
  hosts: k3s_cluster
  become: yes
  serial: 1
  vars:
    k3s_version: "v1.28.5+k3s1"
    airgap_dir: /opt/k3s-airgap

  pre_tasks:
    - name: Distribute new airgap assets
      include_role:
        name: homelab.proxmox_lxc.airgap

  roles:
    - homelab.proxmox_lxc.k3s_upgrade
```

## Upgrade Workflow

1. **Version Check** - Detects currently installed K3s version
2. **Upgrade Decision** - Only proceeds if upgrade is needed
3. **Service Discovery** - Finds all K3s service files
4. **Service Backup** - Creates backup of service files (.bak)
5. **Binary Installation** - Installs new K3s version
6. **Service Restoration** - Restores original service configuration
7. **Backup Cleanup** - Removes temporary backup files
8. **Service Restart** - Restarts K3s service with new binary
9. **Verification** - Service starts successfully

## Tasks Overview

The role performs the following operations:

1. **Get Installed Version** - Checks current K3s version
2. **Set Version Fact** - Stores installed version for comparison
3. **Conditional Upgrade Block** - Only runs if upgrade needed:
   - **Find Service Files** - Locates k3s*.service files
   - **Backup Services** - Creates .bak copies
   - **Install New Version** - Downloads and installs new K3s
   - **Restore Services** - Restores service configurations
   - **Clean Backups** - Removes temporary backups
   - **Restart Service** - Restarts appropriate service (server/agent)

## Dependencies

This role requires:

- Existing K3s installation (via k3s_server or k3s_agent roles)

## Files and Backups

### Service Files

```bash
# Before upgrade
/etc/systemd/system/k3s.service         # Server service
/etc/systemd/system/k3s-agent.service   # Agent service

# During upgrade (temporary)
/etc/systemd/system/k3s.service.bak     # Server backup
/etc/systemd/system/k3s-agent.service.bak  # Agent backup

# After upgrade
# Backup files are removed
```

### Version Information

```bash
# Check version before upgrade
k3s --version

# Check version after upgrade
k3s --version

# Verify from Kubernetes
kubectl version
kubectl get nodes -o wide
```

## Handlers

This role does not define handlers. Service restarts are handled inline based on node type.

## Examples

### Production Upgrade Strategy

```yaml
- name: Backup etcd before upgrade
  hosts: k3s_servers[0]
  become: yes
  tasks:
    - name: Create etcd snapshot
      command: k3s etcd-snapshot save --name pre-upgrade-{{ k3s_version }}
      register: snapshot

    - name: Copy snapshot to control node
      fetch:
        src: "/var/lib/rancher/k3s/server/db/snapshots/{{ snapshot.stdout }}"
        dest: "./backups/"
        flat: yes

- name: Upgrade first server
  hosts: k3s_servers[0]
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.k3s_upgrade

  post_tasks:
    - name: Wait for cluster to stabilize
      pause:
        seconds: 30

- name: Upgrade remaining servers
  hosts: k3s_servers[1:]
  become: yes
  serial: 1
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.k3s_upgrade

  post_tasks:
    - name: Wait between server upgrades
      pause:
        seconds: 60

- name: Upgrade agents in batches
  hosts: k3s_agents
  become: yes
  serial: "30%"  # Upgrade 30% at a time
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.k3s_upgrade

- name: Verify cluster health
  hosts: k3s_servers[0]
  become: yes
  tasks:
    - name: Check all nodes are ready
      command: kubectl get nodes
      register: nodes

    - name: Verify component status
      command: kubectl get componentstatuses
      register: components
      failed_when: false

    - name: Display cluster status
      debug:
        msg:
          - "{{ nodes.stdout_lines }}"
          - "{{ components.stdout_lines }}"
```

### Upgrade with Workload Migration

```yaml
- name: Upgrade K3s agents with workload migration
  hosts: k3s_agents
  become: yes
  serial: 1
  vars:
    k3s_version: "v1.28.5+k3s1"

  pre_tasks:
    - name: Cordon node
      command: kubectl cordon {{ inventory_hostname }}
      delegate_to: "{{ groups['k3s_servers'][0] }}"

    - name: Drain node
      command: >
        kubectl drain {{ inventory_hostname }}
        --ignore-daemonsets
        --delete-emptydir-data
        --timeout=300s
      delegate_to: "{{ groups['k3s_servers'][0] }}"

  roles:
    - homelab.proxmox_lxc.k3s_upgrade

  post_tasks:
    - name: Uncordon node
      command: kubectl uncordon {{ inventory_hostname }}
      delegate_to: "{{ groups['k3s_servers'][0] }}"

    - name: Wait for node to be ready
      command: kubectl wait --for=condition=Ready node/{{ inventory_hostname }} --timeout=300s
      delegate_to: "{{ groups['k3s_servers'][0] }}"
```

### Version-Specific Upgrade

```yaml
- name: Upgrade to specific K3s version with validation
  hosts: k3s_cluster
  become: yes
  serial: 1
  vars:
    current_version: "v1.27.10+k3s1"
    target_version: "v1.28.5+k3s1"
    k3s_version: "{{ target_version }}"

  pre_tasks:
    - name: Get current version
      command: k3s --version
      register: version_check
      changed_when: false

    - name: Verify current version
      assert:
        that:
          - current_version in version_check.stdout
        fail_msg: "Current version mismatch. Expected {{ current_version }}"
        success_msg: "Current version confirmed: {{ current_version }}"

  roles:
    - homelab.proxmox_lxc.k3s_upgrade

  post_tasks:
    - name: Verify new version
      command: k3s --version
      register: new_version
      changed_when: false

    - name: Confirm upgrade
      assert:
        that:
          - target_version in new_version.stdout
        fail_msg: "Upgrade failed. Version is {{ new_version.stdout }}"
        success_msg: "Upgrade successful to {{ target_version }}"
```

## Troubleshooting

### Upgrade Fails

```bash
# Check installed version
k3s --version

# View upgrade logs
sudo journalctl -u k3s -n 100
sudo journalctl -u k3s-agent -n 100

# Check service status
sudo systemctl status k3s
sudo systemctl status k3s-agent

# Verify binary
ls -lh /usr/local/bin/k3s
file /usr/local/bin/k3s
```

### Service Won't Start After Upgrade

```bash
# Check service configuration
sudo systemctl cat k3s
sudo systemctl cat k3s-agent

# Restore from backup if needed
sudo cp /etc/systemd/system/k3s.service.bak /etc/systemd/system/k3s.service
sudo systemctl daemon-reload
sudo systemctl restart k3s

# Check for configuration errors
sudo k3s server --help
sudo k3s agent --help
```

### Version Mismatch

```bash
# Check binary version
/usr/local/bin/k3s --version

# Check running version
sudo systemctl show k3s -p ExecStart

# Verify download
ls -lh /usr/local/bin/k3s-*
```

### Rollback Required

```bash
# Stop service
sudo systemctl stop k3s

# Restore previous binary
sudo cp /usr/local/bin/k3s.bak /usr/local/bin/k3s

# Start service
sudo systemctl start k3s

# Or restore from backup
sudo systemctl stop k3s
sudo cp /etc/systemd/system/k3s.service.bak /etc/systemd/system/k3s.service
sudo systemctl daemon-reload
sudo systemctl start k3s
```

## Best Practices

### Pre-Upgrade

1. **Backup etcd** - Create etcd snapshot before upgrading servers
2. **Test in staging** - Test upgrade path in non-production
3. **Review changelog** - Check K3s release notes for breaking changes
4. **Check compatibility** - Verify application compatibility with new version
5. **Plan maintenance window** - Schedule during low-traffic period

### During Upgrade

1. **Upgrade servers first** - Always upgrade server nodes before agents
2. **Serial upgrades** - Upgrade one server at a time
3. **Wait between upgrades** - Allow cluster to stabilize
4. **Monitor cluster** - Watch for issues during upgrade
5. **Drain nodes** - Migrate workloads before upgrading agents

### Post-Upgrade

1. **Verify versions** - Confirm all nodes upgraded successfully
2. **Check workloads** - Verify applications are running
3. **Monitor metrics** - Watch resource usage and performance
4. **Test functionality** - Validate cluster functionality
5. **Update documentation** - Record upgrade completion

## Security Considerations

- **Binary Verification** - Verify K3s binary checksums
- **Service Preservation** - Maintains security configurations
- **Backup Security** - Secure backup files appropriately
- **Version Validation** - Only upgrade to trusted versions
- **Access Control** - Restrict upgrade operations to administrators

## Performance Impact

- **Downtime** - Brief service restart (typically 10-30 seconds)
- **Workload Impact** - Minimal if using node draining
- **Network Impact** - Binary download during upgrade
- **Storage Impact** - Temporary increase for backups
- **Resource Usage** - Minimal resource overhead

## Version Skew Policy

Follow Kubernetes version skew policy:

- **kubectl** - Can be ±1 minor version from API server
- **kubelet** - Cannot be newer than API server
- **API server** - Can be at most one minor version newer than controller-manager
- **Recommended** - Upgrade one minor version at a time

## Upgrade Paths

### Supported Upgrades

```yaml
# Patch version upgrade (recommended)
v1.28.4+k3s1 → v1.28.5+k3s1

# Minor version upgrade (test thoroughly)
v1.27.10+k3s1 → v1.28.5+k3s1

# Multiple minor versions (not recommended)
v1.26.x → v1.27.x → v1.28.x  # Upgrade incrementally
```

### Unsupported Upgrades

- Downgrading to older versions
- Skipping multiple minor versions
- Upgrading agents before servers

## Integration with Other Roles

This role works with:

- **k3s_server** - Upgrades server nodes
- **k3s_agent** - Upgrades agent nodes
- **airgap** - Supports airgapped upgrades
- Monitoring tools - For upgrade verification

## License

Apache License 2.0 - See collection LICENSE file for details.
