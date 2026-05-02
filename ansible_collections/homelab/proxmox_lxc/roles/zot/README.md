# Zot Role

Deploys and configures [Zot](https://zotregistry.dev/) as an OCI-native container image and Helm chart registry in an LXC container. Zot is a CNCF project that handles both Docker images and OCI artifacts (Helm charts) in a single lightweight binary.

## Features

- **OCI-native** — Full OCI Distribution Spec v1.1 compliance
- **Web UI** — Browse images and charts at `https://registry.homelab.lan/`
- **Search** — Full-text search across repositories and tags
- **htpasswd auth** — Simple user/password authentication with bcrypt
- **TLS via Traefik** — HTTPS termination handled by the central Traefik reverse proxy
- **UFW firewall** — Port 5000 opened for registry traffic

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Traefik reverse proxy configured with `registry` service entry
- `vault_zot_admin_user` and `vault_zot_admin_password` defined in vault (password min 12 chars)

## Role Variables

```yaml
zot_version: "2.1.2"
zot_port: 5000
zot_user: zot
zot_group: zot
zot_config_dir: /etc/zot
zot_storage_dir: /var/lib/zot
zot_log_dir: /var/log/zot
zot_admin_user: "{{ vault_zot_admin_user }}"
zot_admin_password: "{{ vault_zot_admin_password }}"
zot_configure_firewall: true
```

## Usage

```bash
# Deploy registry
ansible-playbook playbooks/applications.yml --tags registry

# Push a Docker image
docker login registry.homelab.lan -u admin
docker tag myimage:latest registry.homelab.lan/myimage:latest
docker push registry.homelab.lan/myimage:latest

# Push a Helm chart (OCI mode)
helm push mychart-1.0.0.tgz oci://registry.homelab.lan/charts

# Web UI
https://registry.homelab.lan/
```

## Security

- Credentials stored in Ansible vault (`vault_zot_admin_user`, `vault_zot_admin_password`)
- htpasswd file owned by `zot:zot` with mode `0640`
- Config and storage directories mode `0750`
- TLS termination by Traefik using step-ca certificates
- K3s nodes configured to pull from this registry via `registries.yaml`
