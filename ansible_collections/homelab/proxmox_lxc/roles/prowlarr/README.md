# Prowlarr Role

> **Deprecated**: This role has been superseded by `homelab.proxmox_lxc.media_stack`,
> which deploys all arr services as a unified Docker Compose stack on a single Ubuntu VM.
> This role is retained for reference only and is no longer deployed.

Deploys Prowlarr indexer management in an LXC container using Docker, providing centralized indexer management for all *arr applications.

## Features

- **Indexer Management** - Centralized indexer configuration for all *arr apps
- **Sync Integration** - Automatically syncs indexers to Sonarr, Radarr, Lidarr
- **Search Capabilities** - Manual search across all configured indexers
- **Health Monitoring** - Track indexer availability and performance
- **Docker Deployment** - Containerized for easy management

## Role Variables

```yaml
prowlarr_version: "latest"
prowlarr_port: 9696
prowlarr_puid: 1000
prowlarr_pgid: 1000
prowlarr_timezone: "UTC"
```

## Usage

```yaml
- hosts: prowlarr-lxc
  become: true
  roles:
    - homelab.proxmox_lxc.prowlarr
```

## Post-Installation

1. Access Prowlarr at `http://192.168.0.233:9696`
2. Configure authentication
3. Add indexers
4. Connect to Sonarr/Radarr applications

## License

MIT License
