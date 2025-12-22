# AdGuard Home Role

**Status:** Planned / Not Yet Implemented

This role is planned to deploy AdGuard Home DNS server in an LXC container. AdGuard Home provides network-wide ad blocking, privacy protection, and DNS filtering.

## Planned Features

- AdGuard Home DNS server deployment
- Network-wide ad and tracker blocking
- DNS filtering and custom blocklists
- HTTPS/DNS-over-TLS support
- Statistics and query logging
- Parental controls
- Integration with Unbound for upstream DNS

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Network configuration for DNS services
- Vault variable: `vault_adguard_admin_password` (minimum 12 characters)

## Current Status

This role contains placeholder templates but has not been fully implemented yet.

To deploy AdGuard Home manually, consider using the official AdGuard Home installation script or Docker image until this role is completed.

## Related Documentation

- [AdGuard Home Official Documentation](https://github.com/AdGuardTeam/AdGuardHome/wiki)
- Related role: `unbound` (upstream DNS)

## License

Apache License 2.0 - See collection LICENSE file for details.
