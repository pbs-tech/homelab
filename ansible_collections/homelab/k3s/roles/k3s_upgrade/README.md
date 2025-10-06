# K3s Upgrade Role

Performs in-place upgrades of K3s installations on both server and agent nodes. Handles version detection, service preservation, and rolling upgrades with minimal downtime.

## Features

- **Intelligent Version Detection** - Only upgrades if newer version specified
- **Service Preservation** - Backs up and restores custom service configurations
- **Zero Configuration Changes** - Maintains existing cluster settings
- **Server and Agent Support** - Handles both node types appropriately
- **Idempotent Operations** - Safe to run multiple times
- **Rollback Support** - Service backups enable manual rollback if needed
- **Minimal Downtime** - Quick upgrade process with automatic restart

## Requirements

- Existing K3s installation (server or agent)
- Root or sudo access
- Network connectivity for downloading new K3s version
- homelab.common collection installed
- K3s install script at /usr/local/bin/k3s-install.sh

## Role Variables

### Upgrade Configuration

```yaml
# Target K3s version to upgrade to
k3s_version: "v1.28.3+k3s1"

# Systemd directory
systemd_dir: /etc/systemd/system

# Inventory groups
server_group: server
agent_group: agent
```

### Installation Options

```yaml
# Extra environment variables for installation
extra_install_envs:
  INSTALL_K3S_CHANNEL: "stable"

# Version is automatically determined from installed vs target
# Upgrade only occurs if installed_k3s_version < k3s_version
```

## Usage

### Basic Upgrade

```yaml
- hosts: k3s_cluster
  become: yes
  serial: 1  # Upgrade one node at a time
  vars:
    k3s_version: "v1.28.4+k3s1"
  roles:
    - homelab.k3s.k3s_upgrade
```

### Rolling Upgrade Strategy

```yaml
# Upgrade servers first, one at a time
- hosts: server
  become: yes
  serial: 1
  vars:
    k3s_version: "v1.28.4+k3s1"
  roles:
    - homelab.k3s.k3s_upgrade

# Then upgrade agents, can be more aggressive
- hosts: agent
  become: yes
  serial: 3
  vars:
    k3s_version: "v1.28.4+k3s1"
  roles:
    - homelab.k3s.k3s_upgrade
```

### Upgrade with Custom Install Environment

```yaml
- hosts: k3s_cluster
  become: yes
  serial: 1
  vars:
    k3s_version: "v1.28.4+k3s1"
    extra_install_envs:
      INSTALL_K3S_CHANNEL: "latest"
      INSTALL_K3S_SKIP_SELINUX_RPM: "true"
  roles:
    - homelab.k3s.k3s_upgrade
```

### Conditional Upgrade

```yaml
- hosts: k3s_cluster
  become: yes
  serial: 1
  vars:
    k3s_version: "{{ target_version | default('v1.28.3+k3s1') }}"
  roles:
    - homelab.k3s.k3s_upgrade
```

## Upgrade Process

### Pre-Upgrade Checks

1. **Version Detection** - Gets currently installed K3s version
2. **Version Comparison** - Compares installed vs target version
3. **Skip if Current** - Skips upgrade if versions match
4. **Service Discovery** - Finds all K3s-related systemd services

### Service Backup

1. **Find Service Files** - Locates k3s*.service files in systemd_dir
2. **Backup Services** - Creates .bak copies of all service files
3. **Preserve Permissions** - Maintains original file permissions
4. **Backup All Services** - Handles k3s.service and k3s-agent.service

### Installation

1. **Run Install Script** - Executes /usr/local/bin/k3s-install.sh
2. **Skip Start** - Uses INSTALL_K3S_SKIP_START to prevent auto-start
3. **Version Specification** - Passes target version to installer
4. **Binary Replacement** - Replaces K3s binary with new version

### Service Restoration

1. **Restore Service Files** - Copies backed-up services back
2. **Preserve Custom Settings** - Maintains environment variables and args
3. **Clean Backups** - Removes .bak files after restoration
4. **Verify Restoration** - Ensures services properly restored

### Service Restart

1. **Daemon Reload** - Reloads systemd to recognize any changes
2. **Server Restart** - Restarts k3s service on server nodes
3. **Agent Restart** - Restarts k3s-agent service on agent nodes
4. **Health Check** - Systemd verifies service started successfully

## Tasks Overview

### Version Management

- Get installed K3s version via `k3s --version`
- Parse version from command output
- Compare installed version with target version
- Skip upgrade block if version is current

### Service Management

- Find all K3s service files
- Create timestamped backups
- Preserve file permissions and ownership
- Restore after upgrade
- Clean up temporary files

### Installation Process

- Execute K3s install script
- Pass environment variables for version control
- Skip automatic service start
- Handle both server and agent installations

### Restart Logic

- Detect node type (server or agent)
- Restart appropriate service
- Reload systemd daemon
- Verify service started successfully

## Files and Backups

### Service File Backups

```bash
# Backup locations
/etc/systemd/system/k3s.service.bak
/etc/systemd/system/k3s-agent.service.bak
```

### Configuration Preservation

- **/etc/rancher/k3s/config.yaml** - Preserved automatically
- **/etc/systemd/system/k3s.service.env** - Preserved via service backup
- **/var/lib/rancher/k3s/** - Data directory unchanged

## Handlers

This role does not define handlers. Service restarts are handled inline based on node group membership.

## Dependencies

- Existing K3s installation
- K3s install script must be present at /usr/local/bin/k3s-install.sh
- Server nodes must be in group defined by server_group variable
- Agent nodes must be in group defined by agent_group variable

## Upgrade Strategies

### Conservative Rolling Upgrade

```yaml
# One node at a time across entire cluster
- hosts: k3s_cluster
  become: yes
  serial: 1
  max_fail_percentage: 0
  roles:
    - homelab.k3s.k3s_upgrade
```

### Aggressive Agent Upgrade

```yaml
# Servers one at a time, agents in parallel batches
- hosts: server
  become: yes
  serial: 1
  roles:
    - homelab.k3s.k3s_upgrade

- hosts: agent
  become: yes
  serial: "50%"  # Half at a time
  roles:
    - homelab.k3s.k3s_upgrade
```

### Canary Upgrade

```yaml
# Test on one agent first
- hosts: agent[0]
  become: yes
  vars:
    k3s_version: "v1.28.4+k3s1"
  roles:
    - homelab.k3s.k3s_upgrade

# Wait for validation, then continue
- hosts: agent[1:]
  become: yes
  serial: 3
  vars:
    k3s_version: "v1.28.4+k3s1"
  roles:
    - homelab.k3s.k3s_upgrade
```

## Monitoring Upgrade Progress

### Check Version Status

```bash
# On each node
k3s --version

# From server node, check all nodes
k3s kubectl get nodes -o wide
```

### Monitor Service Status

```bash
# During upgrade
watch systemctl status k3s

# Check for errors
journalctl -u k3s --since "5 minutes ago"
```

### Verify Cluster Health

```bash
# Check node status
k3s kubectl get nodes

# Verify pods are running
k3s kubectl get pods -A

# Check for pod evictions
k3s kubectl get events --sort-by='.lastTimestamp'
```

## Troubleshooting

### Upgrade Fails to Start

```bash
# Check current version
k3s --version

# Verify install script exists
ls -la /usr/local/bin/k3s-install.sh

# Check network connectivity
curl -I https://get.k3s.io/

# Review upgrade logs
journalctl -u k3s -n 100
```

### Service Won't Restart

```bash
# Check service status
systemctl status k3s
systemctl status k3s-agent

# Verify service file
cat /etc/systemd/system/k3s.service

# Check for backup
ls -la /etc/systemd/system/k3s*.bak

# Manual restore if needed
cp /etc/systemd/system/k3s.service.bak /etc/systemd/system/k3s.service
systemctl daemon-reload
systemctl restart k3s
```

### Version Mismatch After Upgrade

```bash
# Check binary version
k3s --version

# Check running version
k3s kubectl version

# Force reinstall if needed
INSTALL_K3S_VERSION=v1.28.4+k3s1 /usr/local/bin/k3s-install.sh
systemctl restart k3s
```

### Cluster Becomes Unstable

```bash
# Check node status
k3s kubectl get nodes

# Review events
k3s kubectl get events -A --sort-by='.lastTimestamp'

# Check API server health
k3s kubectl get --raw /healthz

# Rollback if necessary
# Restore from backup and restart with previous version
```

## Rollback Procedure

### Manual Rollback

```bash
# 1. Stop service
systemctl stop k3s  # or k3s-agent

# 2. Reinstall previous version
INSTALL_K3S_VERSION=v1.28.3+k3s1 /usr/local/bin/k3s-install.sh

# 3. Restore service file if needed
cp /etc/systemd/system/k3s.service.bak /etc/systemd/system/k3s.service

# 4. Reload and restart
systemctl daemon-reload
systemctl start k3s

# 5. Verify version
k3s --version
```

### Automated Rollback Playbook

```yaml
- hosts: k3s_cluster
  become: yes
  serial: 1
  tasks:
    - name: Rollback to previous version
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s-install.sh
      environment:
        INSTALL_K3S_VERSION: "v1.28.3+k3s1"
        INSTALL_K3S_SKIP_START: "true"

    - name: Restart service
      ansible.builtin.systemd:
        name: "{{ 'k3s' if 'server' in group_names else 'k3s-agent' }}"
        state: restarted
        daemon_reload: yes
```

## Best Practices

### Pre-Upgrade

- **Backup etcd** - Take etcd snapshot before upgrading servers
- **Test in Development** - Test upgrade process in non-production first
- **Review Release Notes** - Check K3s release notes for breaking changes
- **Check Compatibility** - Verify workload compatibility with new version
- **Plan Maintenance Window** - Schedule upgrade during low-traffic period

### During Upgrade

- **Monitor Progress** - Watch service status and logs during upgrade
- **Serial Execution** - Upgrade one node at a time for safety
- **Verify Each Node** - Confirm successful upgrade before proceeding
- **Check Cluster Health** - Verify cluster health between nodes
- **Have Rollback Ready** - Be prepared to rollback if issues occur

### Post-Upgrade

- **Verify All Nodes** - Confirm all nodes running same version
- **Check Workloads** - Verify all pods are running correctly
- **Monitor Logs** - Watch for errors or warnings in cluster logs
- **Run Tests** - Execute smoke tests or health checks
- **Document Changes** - Record upgrade details and any issues

## Security Considerations

- **Version Pinning** - Always specify exact version, don't use "latest"
- **Release Verification** - Download from official K3s sources only
- **Service Preservation** - Backup preserves security configurations
- **Minimal Downtime** - Quick restart reduces exposure window
- **Audit Logging** - Upgrade events logged in systemd journal

## Performance Impact

- **Upgrade Duration** - 30-60 seconds per node typical
- **Service Restart** - 5-15 seconds of API unavailability on servers
- **Pod Eviction** - Workloads may be rescheduled during agent upgrade
- **Network Disruption** - Brief network policy recalculation
- **Storage Access** - No impact on persistent volumes

## Compatibility

### Version Skew Policy

- **Server to Agent** - Agent can be up to 2 minor versions behind server
- **kubectl** - kubectl should be within 1 minor version of server
- **Workloads** - Check Kubernetes version compatibility

### Tested Upgrade Paths

- v1.27.x -> v1.28.x
- v1.28.x -> v1.29.x
- Patch version upgrades (e.g., v1.28.3 -> v1.28.4)

## License

Apache License 2.0 - See collection LICENSE file for details.
