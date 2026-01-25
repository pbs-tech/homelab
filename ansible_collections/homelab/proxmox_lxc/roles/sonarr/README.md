# Sonarr Role

Deploys Sonarr TV series management in an LXC container using Docker, providing automated TV show downloading, organization, and library management.

## Features

- **TV Series Management** - Automated downloading and organizing of TV shows
- **Quality Profiles** - Define preferred video quality and format
- **Calendar View** - Track upcoming episodes and releases
- **Download Client Integration** - Works with qBittorrent, SABnzbd, and others
- **Indexer Support** - Integrates with Prowlarr for indexer management
- **Media Server Integration** - Works with Jellyfin, Plex, Emby
- **Notifications** - Alert on downloads, errors, and updates
- **Docker Deployment** - Containerized for easy management

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- NAS storage mounted for media files
- Download client configured (e.g., qBittorrent)
- Indexers configured (e.g., via Prowlarr)

## Role Variables

```yaml
# Version and ports
sonarr_version: "latest"
sonarr_port: 8989

# User configuration
sonarr_uid: 1000
sonarr_gid: 1000

# Media directories
sonarr_media_dir: "/media/tv"
sonarr_download_dir: "/downloads"

# Timezone
sonarr_timezone: "UTC"
```

## Usage

### Basic Deployment

```yaml
- hosts: sonarr-lxc
  become: true
  roles:
    - homelab.proxmox_lxc.sonarr
```

### With Custom Media Paths

```yaml
- hosts: sonarr-lxc
  become: true
  vars:
    sonarr_media_dir: "/mnt/nas/media/tv"
    sonarr_download_dir: "/mnt/nas/downloads/tv"
    sonarr_timezone: "America/New_York"
  roles:
    - homelab.proxmox_lxc.sonarr
```

## Post-Installation

1. Access Sonarr at `http://192.168.0.230:8989`
2. Configure authentication
3. Add download clients (qBittorrent, etc.)
4. Add indexers via Prowlarr
5. Configure media library root folder
6. Add TV series to monitor

## Dependencies

- homelab.common.container_base (recommended)

## License

MIT License
