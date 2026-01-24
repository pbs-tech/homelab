# qBittorrent Role

Deploys qBittorrent in an LXC container using Docker, providing a feature-rich BitTorrent client with web UI.

## Features

- **BitTorrent Client** - Full-featured torrent downloading
- **Web UI** - Modern web interface for remote management
- **Category Management** - Organize downloads by category
- **RSS Support** - Automated downloading via RSS feeds
- **VPN Support** - Optional VPN integration for privacy
- **API Access** - RESTful API for automation
- **Docker Deployment** - Containerized for easy management

## Role Variables

```yaml
qbittorrent_version: "latest"
qbittorrent_webui_port: 8080
qbittorrent_torrent_port: 6881
qbittorrent_puid: 1000
qbittorrent_pgid: 1000
qbittorrent_download_dir: "/downloads"
qbittorrent_timezone: "UTC"
```

## Usage

```yaml
- hosts: qbittorrent-lxc
  become: true
  roles:
    - homelab.proxmox_lxc.qbittorrent
```

## Post-Installation

1. Access qBittorrent at `http://192.168.0.234:8080`
2. Default credentials: admin / adminadmin (change immediately!)
3. Configure download paths
4. Set up categories for Sonarr/Radarr integration

## License

MIT License
