# nas_mounts

Mounts TrueNAS NFS shares on a Proxmox host and bind-mounts them into unprivileged LXC containers
via `mp<n>:` entries in the container config.

> **Note:** This role is for **unprivileged LXC containers only**. For VMs or privileged LXC,
> mount NFS directly inside the guest using `ansible.posix.mount` in your role's tasks.
> The `homelab.proxmox_lxc.media_stack` role does this for the media stack VM.

## Why the host-mount approach?

Unprivileged LXC containers cannot call `mount(2)` directly. The solution is to mount NFS on
the Proxmox host and then expose it into the container as a bind mount — the same pattern used
for `/dev/net/tun` in `container_base`.

## Variables

| Variable            | Default                          | Description                          |
|---------------------|----------------------------------|--------------------------------------|
| `nas_nfs_server`    | 192.168.0.220                    | NFS server IP (TrueNAS)              |
| `nas_nfs_opts`      | rw,nfsvers=3,hard,...            | Mount options                        |
| `nas_proxmox_node`  | pve-nas                          | Proxmox node key from `proxmox_config`|
| `nas_mounts`        | [{path: /mnt/nas, src: ...}]     | List of {path, src} mount entries    |
| `nas_subdirs`       | []                               | Subdirs to create after mounting     |
| `nas_subdir_owner`  | 1000                             | Owner UID for created subdirs        |
| `nas_subdir_group`  | 1000                             | Owner GID for created subdirs        |

## Usage

```yaml
- name: Mount NAS NFS shares
  ansible.builtin.include_role:
    name: homelab.common.nas_mounts
  vars:
    nas_mounts:
      - path: /mnt/nas
        src: "{{ nas_nfs_server }}:/mnt/tank/data"
    nas_subdirs:
      - /mnt/nas/media/tv
```
