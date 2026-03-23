# Review Scope

## Target

Full audit of the homelab Ansible collection infrastructure — identifying unused components,
dead code, redundant patterns, and optimisation opportunities across all three homelab collections
and the orchestration layer.

## Files

### Homelab Collections (primary review targets)
- `ansible_collections/homelab/common/` — shared roles: common_setup, container_base, security_hardening, vm_base
- `ansible_collections/homelab/k3s/` — K3s cluster roles: k3s_server, k3s_agent, airgap
- `ansible_collections/homelab/proxmox_lxc/` — LXC service roles: traefik, prometheus, grafana, loki, alertmanager, adguard, unbound, wireguard, homeassistant, sonarr, radarr, bazarr, prowlarr, qbittorrent, jellyfin, pve_exporter, truenas, openwrt, ubuntu_vm, etc.

### Orchestration Layer
- `playbooks/` — infrastructure.yml, foundation.yml, networking.yml, monitoring.yml, applications.yml, enclave.yml, update-systems.yml, restart-k3s-pods.yml, provision-containers.yml, bootstrap-proxmox.yml, etc.
- `site.yml` — legacy entry point
- `phase2-security.yml`, `security-deploy.yml` — legacy security playbooks

### Configuration & Inventory
- `inventory/` — group_vars (all, lxc_containers, k3s, proxmox, etc.), hosts files
- `ansible.cfg`
- `requirements.yml`

### Testing Infrastructure
- `tests/` — quick-smoke-test.yml, validate-infrastructure.yml, validate-security.yml, validate-services.yml
- `molecule/` — root-level smoke test scenario
- Per-collection `molecule/` scenarios

### Scripts & Tooling
- `scripts/` — security-audit.sh and other helpers
- `Makefile` — build targets
- `.github/workflows/` — CI/CD pipelines
- `.pre-commit-config.yaml`, `.ansible-lint`, `.yamllint`

## Flags

- Security Focus: no
- Performance Critical: no
- Strict Mode: no
- Framework: Ansible (collections model, Molecule 6.0+)

## Review Phases

1. Code Quality & Architecture
2. Security & Performance
3. Testing & Documentation
4. Best Practices & Standards
5. Consolidated Report
