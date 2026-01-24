# Jellyfin Role

Deploys Jellyfin media streaming server in an LXC container using Docker, providing a self-hosted media solution for movies, TV shows, music, and more.

## Features

- **Media Streaming** - Stream movies, TV shows, music, and photos
- **Cross-Platform** - Apps for web, mobile, TV, and desktop
- **Hardware Transcoding** - GPU acceleration support (Intel QSV, NVIDIA, VAAPI)
- **Live TV & DVR** - Watch and record live TV
- **User Management** - Multiple user accounts with parental controls
- **Metadata** - Automatic media information and artwork
- **Plugins** - Extensible with community plugins
- **No Subscriptions** - Completely free and open source

## Role Variables

```yaml
jellyfin_version: "latest"
jellyfin_port: 8096
jellyfin_https_port: 8920
jellyfin_puid: 1000
jellyfin_pgid: 1000
jellyfin_media_dir: "/media"
jellyfin_timezone: "UTC"
jellyfin_hardware_acceleration: false
```

## Usage

```yaml
- hosts: jellyfin-lxc
  become: true
  roles:
    - homelab.proxmox_lxc.jellyfin
```

### With Hardware Acceleration

```yaml
- hosts: jellyfin-lxc
  become: true
  vars:
    jellyfin_hardware_acceleration: true
    jellyfin_gpu_device: "/dev/dri/renderD128"
  roles:
    - homelab.proxmox_lxc.jellyfin
```

## Post-Installation

1. Access Jellyfin at `http://192.168.0.235:8096`
2. Complete the setup wizard
3. Add media libraries
4. Configure users and remote access

## License

MIT License
