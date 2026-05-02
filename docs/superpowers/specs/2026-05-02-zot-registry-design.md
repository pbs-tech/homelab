# Zot OCI Registry Design

**Date:** 2026-05-02
**Status:** Approved

## Summary

Deploy a single Zot OCI registry LXC container on pve-mac to serve as the homelab's Docker image
and Helm chart registry. Zot is an OCI-native CNCF project that handles both use cases in a single
lightweight binary with an optional web UI.

## Requirements

- Store and serve Docker images and Helm charts (as OCI artifacts)
- Accessible from local machines and the K3s cluster (local network only)
- HTTPS via step-ca (consistent with all other homelab services)
- Basic web UI for browsing images and charts
- Managed by Ansible following existing collection patterns

## Architecture

### Container

| Property     | Value                        |
|--------------|------------------------------|
| Host         | `registry-lxc`               |
| IP           | `192.168.0.211`              |
| Container ID | `211`                        |
| Proxmox node | `pve-mac`                    |
| OS           | Ubuntu 22.04 (unprivileged)  |
| vCPU         | 1                            |
| RAM          | 512 MB                       |
| Disk         | 20 GB                        |

### Zot Service

- Binary installed to `/usr/local/bin/zot` (downloaded from GitHub releases, amd64)
- Runs as `zot` system user via systemd
- Listens on port 5000 with TLS termination
- Config at `/etc/zot/config.json`
- Blob/index storage at `/var/lib/zot`

### Extensions Enabled

- `search` — powers the UI's browse and search functionality
- `ui` — serves the Zot web SPA at `https://registry.homelab.lan/`

### TLS

- Certificate issued by the homelab step-ca for `registry.homelab.lan`
- Cert/key stored at `/etc/zot/tls.crt` and `/etc/zot/tls.key`
- Renewed by a systemd timer (`zot-cert-renew.timer`) that runs `step ca certificate`
  and restarts Zot on renewal

### Authentication

- htpasswd file at `/etc/zot/htpasswd`
- Single admin account; username in `vault_zot_admin_user`, password in `vault_zot_admin_password`

### Firewall

- UFW allows port 5000/tcp from `192.168.0.0/24`

## Traefik Integration

New router in Traefik's dynamic config:

- Domain: `registry.homelab.lan`
- Backend: `https://192.168.0.211:5000`
- Mode: HTTP proxy with step-ca root in Traefik's trusted CA pool
- Traefik forwards requests to Zot; Zot handles TLS termination

## K3s Integration

A `registries.yaml` deployed to all K3s nodes at `/etc/rancher/k3s/registries.yaml`:

```yaml
mirrors:
  registry.homelab.lan:
    endpoint:
      - "https://registry.homelab.lan"
configs:
  "registry.homelab.lan":
    auth:
      username: "{{ vault_zot_admin_user }}"
      password: "{{ vault_zot_admin_password }}"
    tls:
      ca_file: /etc/ssl/certs/homelab-ca.crt
```

The step-ca root cert must be present on each K3s node (already handled by the
`security_hardening` role if it deploys the CA cert, otherwise added as a new task).

## Ansible Role Structure

```
ansible_collections/homelab/proxmox_lxc/roles/zot/
├── defaults/main.yml                     # zot_version, port, storage path, vault refs
├── tasks/main.yml                        # install, config, tls, systemd, UFW
├── templates/
│   ├── config.json.j2                    # Zot config with extensions
│   ├── zot.service.j2                    # systemd unit
│   ├── zot-cert-renew.service.j2         # cert renewal oneshot
│   └── zot-cert-renew.timer.j2           # cert renewal timer
└── handlers/main.yml                     # restart zot
```

## Inventory Changes

### New host in `inventory/hosts.yml` (and dynamic inventory)

```yaml
registry:
  hosts:
    registry-lxc:
      ansible_host: 192.168.0.211
      container_id: 211
      service_port: 5000
      proxmox_node: pve-mac
```

### New `inventory/group_vars/registry.yml`

```yaml
lxc_cores: 1
lxc_memory: 512
lxc_swap: 0
lxc_disk_size: 20
```

## Playbook Changes

### `playbooks/applications.yml`

New play targeting `registry` group:
- pre-task: `homelab.common.container_base` (provisions LXC)
- role: `homelab.common.common_setup`
- role: `homelab.proxmox_lxc.zot`
- tag: `registry`

New play targeting `k3s_cluster`:
- Deploys `/etc/rancher/k3s/registries.yaml`
- Restarts k3s if config changed
- tag: `registry`

### Traefik role update

Add `registry.homelab.lan` router to the Traefik dynamic config template.

## Usage

```bash
# Push Docker image
docker tag myimage registry.homelab.lan/myimage:latest
docker push registry.homelab.lan/myimage:latest

# Push Helm chart (OCI mode)
helm push mychart-1.0.0.tgz oci://registry.homelab.lan/charts

# Pull in K3s deployment
image: registry.homelab.lan/myimage:latest

# Web UI
https://registry.homelab.lan/
```

## Deployment

```bash
# Deploy registry only
ansible-playbook playbooks/applications.yml --tags registry

# Or as part of full infrastructure
ansible-playbook playbooks/infrastructure.yml --tags "applications,phase4"
```
