# Changelog

All notable changes to the homelab Ansible collections will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

<!-- pyml disable-next-line no-duplicate-heading-->
### Added

- `playbooks/update-systems.yml` - Rolling system update playbook for Raspberry Pis (serial:1) and LXC containers (serial:3)
- `playbooks/restart-k3s-pods.yml` - K3s deployment rolling restart playbook with namespace/deployment filtering and dry-run support
- UFW firewall rules for Prometheus, Grafana, and Loki roles (matching existing AlertManager pattern)
- `wireguard_client_dns_method` variable for WireGuard client DNS integration (systemd-resolved, resolvconf, none)
- Makefile targets: `update-systems`, `update-pi`, `update-lxc`, `restart-k3s-pods`
- Proxmox cluster firewall security groups (`basic-network`, `allow-ssh`, `allow-web`) defined in `cluster.fw`
  - `basic-network`: DHCP, DNS (UDP+TCP), ICMP
  - `allow-ssh`: SSH from LAN (192.168.0.0/24)
  - `allow-web`: HTTP/HTTPS (opt-in per VM)
- Per-VM/CT firewall deployment via `container_base` role (`/etc/pve/firewall/<vmid>.fw`)
  - Automatically references `basic-network` and `allow-ssh` security groups
  - Configurable via `container_firewall_groups` and `container_firewall_extra_rules` variables
  - Deployed between container creation and start for immediate effect
- Proxmox firewall architecture documentation in `docs/SECURITY-ARCHITECTURE.md`
- Troubleshooting guide for new VMs without internet access in `docs/TROUBLESHOOTING.md`

<!-- pyml disable-next-line no-duplicate-heading-->
### Fixed

- New VMs/CTs with Proxmox firewall enabled could not access internet (DHCP/DNS blocked by default DROP policy)
  - Root cause: cluster.fw `[RULES]` only apply to host traffic, not per-VM chains
  - Fix: deploy per-VM firewall files that reference security groups at the correct level
- Phase 6 enclave deployment was skipped by default (`skip_enclave` defaulted to `true` instead of `false`)
- WireGuard client DNS not working on systems with NetworkManager/systemd-resolved (added PostUp/PostDown resolvectl scripts)
- Prometheus, Grafana, and Loki not accessible by IP due to missing UFW firewall rules

<!-- pyml disable-next-line no-duplicate-heading-->
### Changed

- GitHub Actions workflow for automated publishing to Ansible Galaxy
- Comprehensive release documentation (RELEASING.md)
- Semantic versioning strategy for all collections
- Composite action for Galaxy collection polling (`.github/actions/wait-for-galaxy-collection`)
- Galaxy REST API version validation to prevent race conditions

<!-- pyml disable-next-line no-duplicate-heading-->
### Changed

- Updated galaxy.yml files with correct GitHub repository URLs (pbs-tech/homelab)
- **SECURITY**: Workflow now uses `ANSIBLE_GALAXY_TOKEN` environment variable instead of `--api-key` flag
- Improved polling logic with Galaxy REST API checks for specific versions
- Enhanced error handling for cancelled workflows in addition to failures
- Eliminated code duplication in publishing workflow (72 lines reduced via composite action)

<!-- pyml disable-next-line no-duplicate-heading-->
### Fixed

- Race condition in collection dependency installation (now validates specific versions via API)
- Potential API key exposure through command line arguments
- Missing version extraction from galaxy.yml files
- Inconsistent error handling for cancelled jobs in summary

## [1.0.0] - 2025-10-26

<!-- pyml disable-next-line no-duplicate-heading-->
### Added

- Initial release of three homelab Ansible collections
- **homelab.common**: Shared utilities and roles for infrastructure management
  - `common_setup` role for base system configuration
  - `container_base` role for LXC container management
  - `security_hardening` role for security best practices
- **homelab.k3s**: K3s Kubernetes cluster deployment and management
  - `k3s_server` role for K3s control plane nodes
  - `k3s_agent` role for K3s worker nodes
  - `airgap` role for offline installation support
  - Integrated security hardening via homelab.common
  - Raspberry Pi 4 support
- **homelab.proxmox_lxc**: Proxmox LXC container services management
  - Traefik reverse proxy integration
  - Prometheus monitoring stack
  - Grafana dashboards and visualization
  - DNS services (Unbound, AdGuard)
  - VPN services (WireGuard)
  - Media management suite (Sonarr, Radarr, Jellyfin, etc.)
  - Home automation (Home Assistant)
  - Security-first deployment approach with bastion hosts

### Infrastructure

- Comprehensive CI/CD pipeline with GitHub Actions
  - YAML, Ansible, and Markdown linting
  - Molecule testing with smoke tests
  - Collection building and validation with galaxy-importer
  - TruffleHog secrets scanning
- Makefile targets for common development tasks
- Fast smoke tests (< 5 minutes for full validation)
- Molecule 6.0+ testing framework support
- Pre-commit hooks for code quality

### Documentation

- Comprehensive README with architecture overview
- Collection-specific documentation for each major component
- Testing procedures (TESTING.md)
- Security architecture documentation
- Troubleshooting guides
- CLAUDE.md for AI-assisted development guidance

### Security

- Multi-layered security with bastion host architecture
- SSH key-based authentication across all services
- Container security with unprivileged LXC containers
- Security hardening roles for all infrastructure components
- Network segmentation and service-specific firewall rules
- Automated secrets scanning in CI/CD

## Release Notes

### homelab.common v1.0.0

Initial release with shared infrastructure roles and utilities. Provides foundation for K3s and Proxmox LXC collections.

### homelab.k3s v1.0.0

Initial release with K3s cluster deployment for Raspberry Pi. Includes security hardening and monitoring integration.

### homelab.proxmox_lxc v1.0.0

Initial release with comprehensive LXC service management for Proxmox. Includes monitoring, networking, security, and application services.

## Future Plans

### Planned Features

- [ ] Backup and disaster recovery automation
- [ ] Enhanced monitoring with custom Grafana dashboards
- [ ] Additional media management integrations
- [ ] Kubernetes workload templates
- [ ] Advanced networking with SDN support
- [ ] Certificate management automation
- [ ] Enhanced security scanning and compliance checks

### Potential Breaking Changes

- Migration from static to dynamic inventory (planned for v2.0.0)
- Restructuring of role dependencies (TBD)
- Python 3.13+ requirement (future consideration)

## How to Upgrade

### From v1.0.0 to v1.1.0 (when released)

No breaking changes expected. Standard upgrade process:

```bash
ansible-galaxy collection install homelab.common --upgrade
ansible-galaxy collection install homelab.k3s --upgrade
ansible-galaxy collection install homelab.proxmox_lxc --upgrade
```

### Future Major Version Upgrades

Major version upgrades may require:

- Configuration changes
- Inventory restructuring
- Manual migration steps

Detailed upgrade guides will be provided in RELEASING.md for each major version.

## Links

- [GitHub Repository](https://github.com/pbs-tech/homelab)
- [Issue Tracker](https://github.com/pbs-tech/homelab/issues)
- [Ansible Galaxy - homelab.common](https://galaxy.ansible.com/homelab/common)
- [Ansible Galaxy - homelab.k3s](https://galaxy.ansible.com/homelab/k3s)
- [Ansible Galaxy - homelab.proxmox_lxc](https://galaxy.ansible.com/homelab/proxmox_lxc)
