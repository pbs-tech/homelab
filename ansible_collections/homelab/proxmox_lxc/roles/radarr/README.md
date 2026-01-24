# Radarr Role

Deploys Radarr movie management in an LXC container using Docker, providing automated movie downloading, organization, and library management.

## Features

- **Movie Management** - Automated downloading and organizing of movies
- **Quality Profiles** - Define preferred video quality and format
- **Release Monitoring** - Track upcoming movie releases
- **Download Client Integration** - Works with qBittorrent, SABnzbd, and others
- **Indexer Support** - Integrates with Prowlarr for indexer management
- **Media Server Integration** - Works with Jellyfin, Plex, Emby
- **Docker Deployment** - Containerized for easy management

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- NAS storage mounted for media files
- Download client configured (e.g., qBittorrent)

## Role Variables

```yaml
radarr_version: "latest"
radarr_port: 7878
radarr_puid: 1000
radarr_pgid: 1000
radarr_media_dir: "/media/movies"
radarr_download_dir: "/downloads"
radarr_timezone: "UTC"
```

## Usage

```yaml
- hosts: radarr-lxc
  become: true
  roles:
    - homelab.proxmox_lxc.radarr
```

## Post-Installation

1. Access Radarr at `http://192.168.0.231:7878`
2. Configure authentication
3. Add download clients
4. Add indexers via Prowlarr
5. Configure media library root folder

## License

MIT License
