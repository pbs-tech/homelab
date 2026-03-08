# step_ca Role

Deploys [smallstep step-ca](https://smallstep.com/docs/step-ca/) as a local ACME certificate
authority in an LXC container. Provides TLS certificates for homelab services via the ACME
TLS-ALPN-01 challenge, integrated with Traefik as the certificate resolver.

## Features

- **Local ACME CA** - Issues TLS certificates for `*.homelab.local` without external dependencies
- **TLS-ALPN-01 Challenge** - Works without exposing port 80; compatible with Traefik
- **Automatic ACME Provisioner** - Configures the `acme` provisioner on first run
- **Idempotent** - Safe to re-run; skips CA initialization if already complete
- **Firewall** - Optional iptables rule to restrict access to the CA port

## Requirements

- Ubuntu 22.04 LXC container provisioned via `homelab.common.container_base`
- Unbound DNS at `192.168.0.202` resolving `homelab.local`
- Traefik configured to use step-ca as its ACME `caServer`

## Role Variables

```yaml
# step-ca and step CLI versions to install
step_ca_version: "0.27.4"
step_cli_version: "0.27.4"

# CA identity
step_ca_name: "Homelab CA"
step_ca_port: 8443

# DNS SANs on the CA's own TLS certificate
step_ca_dns_names:
  - "step-ca.homelab.local"
  - "192.168.0.212"

# ACME provisioner name (must match Traefik caServer URL path)
step_ca_acme_provisioner: "acme"

# Max certificate duration issued via ACME
step_ca_acme_max_tls_duration: "2160h"
step_ca_acme_default_tls_duration: "2160h"

# Firewall
step_ca_enable_firewall: true
```

## Usage

```yaml
- hosts: step-ca
  roles:
    - role: homelab.proxmox_lxc.step_ca
```

After deployment, install the root CA on client devices:

```bash
ssh ansible@192.168.0.212 "sudo cat /etc/step-ca/certs/root_ca.crt" > homelab-ca.crt
# Linux (Arch):
sudo cp homelab-ca.crt /etc/ca-certificates/trust-source/anchors/
sudo update-ca-trust
```
