# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| develop | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do not** create a public issue
2. Email the maintainer directly with details
3. Include steps to reproduce the issue
4. Allow time for investigation and patching

## Security Practices

This repository implements several security measures:

### Infrastructure Security

- **Bastion Host Architecture**: All infrastructure access routes through secured jump hosts
- **SSH Key-based Authentication**: Password authentication disabled across all services
- **Network Segmentation**: Services isolated in appropriate network segments
- **Unprivileged Containers**: All LXC containers run unprivileged by default
- **Security Hardening**: Automated security hardening roles for both K3s and LXC

### Configuration Security

- **Ansible Vault**: Sensitive data encrypted using Ansible Vault
- **No Hardcoded Secrets**: All credentials use vault variables or environment variables
- **SSL/TLS**: Certificate management handled centrally with Let's Encrypt
- **Firewall Rules**: Service-specific firewall rules implemented

### CI/CD Security

- **Secret Scanning**: TruffleHog OSS scans for exposed credentials
- **Security Linting**: Ansible-lint with security profile enabled
- **Dependency Scanning**: OWASP Dependency Check for vulnerabilities
- **CodeQL Analysis**: Static analysis for security issues

## Secrets Management

### Required Vault Variables

The following variables must be defined in your Ansible Vault:

```yaml
# Grafana admin password
vault_grafana_admin_password: "secure_password_here"

# OpenWrt root password hash (bcrypt)
vault_openwrt_root_password_hash: "$2y$10$..."

# SSL certificate email
vault_ssl_email: "your-email@domain.com"

# Service API keys
vault_sonarr_api_key: "api_key_here"
vault_radarr_api_key: "api_key_here"
vault_prowlarr_api_key: "api_key_here"
```

### Creating Vault Files

```bash
# Create encrypted vault file
ansible-vault create inventory/group_vars/all/vault.yml

# Edit existing vault file
ansible-vault edit inventory/group_vars/all/vault.yml
```

## Security Checklist

Before deploying to production:

- [ ] All vault variables are properly configured
- [ ] SSH keys are unique and properly secured
- [ ] Default passwords have been changed
- [ ] Firewall rules are appropriately configured
- [ ] SSL certificates are properly configured
- [ ] Monitoring and logging are enabled
- [ ] Security hardening roles have been applied
- [ ] All GitHub Actions security checks pass

## Security Contacts

For security-related questions or concerns, please contact the project maintainers.
