# Bazarr Role

> **Deprecated**: This role has been superseded by `homelab.proxmox_lxc.media_stack`,
> which deploys all arr services as a unified Docker Compose stack on a single Ubuntu VM.
> This role is retained for reference only and is no longer deployed.

Deploys Bazarr subtitle management in an LXC container using Docker, providing automated subtitle downloading for movies and TV shows.

## Features

- **Subtitle Management** - Automated downloading of subtitles
- **Multi-Language Support** - Download subtitles in multiple languages
- **Provider Integration** - Works with OpenSubtitles, Subscene, and more
- **Sonarr/Radarr Integration** - Syncs with media libraries automatically
- **Quality Selection** - Prefer hearing impaired or forced subtitles
- **Docker Deployment** - Containerized for easy management

## Role Variables

```yaml
bazarr_version: "latest"
bazarr_port: 6767
bazarr_puid: 1000
bazarr_pgid: 1000
bazarr_timezone: "UTC"
```

## Usage

```yaml
- hosts: bazarr-lxc
  become: true
  roles:
    - homelab.proxmox_lxc.bazarr
```

## Post-Installation

1. Access Bazarr at `http://192.168.0.232:6767`
2. Configure Sonarr/Radarr connections
3. Add subtitle providers
4. Configure language preferences

## License

MIT License
