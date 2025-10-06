# Unbound DNS Role

**Status:** Planned / Not Yet Implemented

This role is planned to deploy Unbound recursive DNS server in an LXC container. Unbound provides secure, fast, and lightweight DNS resolution with DNSSEC validation.

## Planned Features

- Unbound recursive DNS server deployment
- DNSSEC validation
- DNS caching for improved performance
- DNS-over-TLS support
- Custom DNS zones and forwarding
- Integration with AdGuard for filtered DNS
- Prometheus metrics export

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Network configuration for DNS services

## Current Status

This role contains placeholder templates but has not been fully implemented yet.

To deploy Unbound manually, use the package manager:
```bash
apt-get install unbound
```

## Related Documentation

- [Unbound Official Documentation](https://unbound.docs.nlnetlabs.nl/)
- Related role: `adguard` (DNS filtering)

## License

Apache License 2.0 - See collection LICENSE file for details.
