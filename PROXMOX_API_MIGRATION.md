# Proxmox API Token Migration Guide

This guide covers migrating from username/password authentication to secure API token authentication for Proxmox integration in the homelab infrastructure.

## Table of Contents

- [Overview](#overview)
- [Security Benefits](#security-benefits)
- [Prerequisites](#prerequisites)
- [Creating API Tokens](#creating-api-tokens)
- [Configuration Update](#configuration-update)
- [Validation and Testing](#validation-and-testing)
- [Troubleshooting](#troubleshooting)
- [Token Management](#token-management)

## Overview

API tokens provide a more secure authentication method for Proxmox automation compared to username/password authentication. Tokens offer:

- **Granular Permissions**: Tokens can inherit user permissions or have restricted access
- **Auditability**: Token usage is logged separately in Proxmox audit logs
- **Revocability**: Tokens can be disabled/deleted without affecting user accounts
- **Rotation**: Easy to rotate tokens without changing passwords
- **Non-interactive**: Secure for automation without exposing passwords

## Security Benefits

### ✅ **Improved Security Posture**

- No passwords stored in configuration files
- Reduced credential exposure in logs and debugging
- Fine-grained access control per automation task
- Easy token lifecycle management

### ✅ **Compliance Advantages**

- Supports credential rotation policies
- Enhanced audit trails for automation activities
- Separation of human and machine authentication
- Meets enterprise security standards

### ✅ **Operational Benefits**

- Faster authentication (no password hashing)
- Better debugging and troubleshooting
- Cleaner logs without password exposure warnings
- Simplified credential management

## Prerequisites

### Proxmox Requirements

- Proxmox VE 6.2 or later (API token support)
- Administrative access to Proxmox web interface
- Understanding of Proxmox user/permission model

### Ansible Requirements

- `community.general` collection version 3.0+ (API token support)
- Ansible Vault configured for secret management
- Access to update inventory and group variables

## Creating API Tokens

### Step 1: Create Service User (Recommended)

Instead of using the root user, create a dedicated service account:

```bash
# Connect to Proxmox node via SSH
ssh root@192.168.0.56

# Create service user for automation
pveum user add ansible@pve --comment "Ansible automation service account"

# Create group with appropriate permissions
pveum group add automation --comment "Automation service accounts"

# Add user to group
pveum user modify ansible@pve --groups automation
```

### Step 2: Assign Permissions

Grant minimal required permissions to the automation group:

```bash
# Essential permissions for LXC container management
pveum acl modify / --groups automation --roles Administrator

# Alternative: Granular permissions (more secure)
pveum acl modify /nodes --groups automation --roles PVEVMAdmin
pveum acl modify /storage --groups automation --roles PVEDatastoreUser
pveum acl modify /pool --groups automation --roles PVEPoolAdmin
```

### Step 3: Generate API Token

#### Via Web Interface (Recommended)

1. Login to Proxmox web interface
2. Navigate to **Datacenter** → **Permissions** → **API Tokens**
3. Click **Add** button
4. Configure token:
   - **User**: `ansible@pve`
   - **Token ID**: `homelab-automation` (descriptive name)
   - **Privilege Separation**: `false` (inherits user permissions)
   - **Comment**: "Homelab infrastructure automation"
5. Click **Add**
6. **IMPORTANT**: Copy the token secret immediately (only shown once)

#### Via Command Line

```bash
# Generate API token for user
pveum user token add ansible@pve homelab-automation --comment "Homelab automation token"

# Example output:
# full-tokenid: ansible@pve!homelab-automation
# info:
#   comment: Homelab automation token
# value: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Step 4: Document Token Information

Record the following information securely:

```yaml
# Token Information (store securely)
token_id: "ansible@pve!homelab-automation"        # Full token ID
token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Secret value (32 chars)
```

## Configuration Update

### Step 1: Create Vault Variables

Add API tokens to your Ansible Vault:

```bash
# Edit your vault file
ansible-vault edit group_vars/all/vault.yml

# Add the following structure:
vault_proxmox_api_tokens:
  pve_mac:
    token_id: "ansible@pve!homelab-automation"
    token_secret: "your-actual-token-secret-here"
  pve_nas:
    token_id: "ansible@pve!homelab-automation"
    token_secret: "your-actual-token-secret-here"
```

### Step 2: Update Group Variables

The repository configuration already supports API tokens in `group_vars/all.yml`:

```yaml
# Configuration is already updated to support tokens
proxmox_config:
  pve_mac:
    host: 192.168.0.56
    user: root@pam  # Legacy, can be removed
    node: pve-mac
    # API Token Authentication (preferred)
    api_token_id: "{{ vault_proxmox_api_tokens.pve_mac.token_id }}"
    api_token_secret: "{{ vault_proxmox_api_tokens.pve_mac.token_secret }}"
    validate_certs: false
```

### Step 3: Update Dynamic Inventory

The dynamic inventory (`inventory/proxmox.yml`) is already configured for token authentication:

```yaml
# Already configured in the repository
plugin: community.proxmox.proxmox
url: https://192.168.0.56:8006
api_token_id: "{{ vault_proxmox_api_tokens.pve_mac.token_id }}"
api_token_secret: "{{ vault_proxmox_api_tokens.pve_mac.token_secret }}"
```

## Validation and Testing

### Step 1: Validate Configuration

Run the validation playbook to test API connectivity:

```bash
# Test Proxmox API connectivity
ansible-playbook -i inventory/proxmox.yml playbooks/validate-proxmox.yml --tags validation

# Test specific node connectivity
ansible-playbook -i inventory/proxmox.yml test-proxmox-connectivity.yml -e proxmox_node=pve-mac
```

### Step 2: Test Container Operations

Test basic container operations with new tokens:

```bash
# Deploy a test container using API tokens
ansible-playbook site.yml --tags "containers" --limit "test-container" --check

# Verify dynamic inventory works
ansible-inventory -i inventory/proxmox.yml --list
```

### Step 3: Monitor API Usage

Check Proxmox logs to verify token authentication:

```bash
# On Proxmox node, check API access logs
tail -f /var/log/pveproxy/access.log | grep "ansible@pve"

# Check authentication logs
journalctl -u pveproxy -f | grep "successful auth"
```

## Troubleshooting

### Common Issues

#### 1. Token Not Found Error

```
Error: 401 Unauthorized - invalid PVE ticket
```

**Solutions:**

- Verify token ID format: `user@realm!token_name`
- Check token exists: `pveum user token list ansible@pve`
- Ensure token is not expired or disabled

#### 2. Permission Denied Error

```
Error: 403 Forbidden - permission denied
```

**Solutions:**

- Check user permissions: `pveum user list`
- Verify group memberships: `pveum user modify ansible@pve --groups automation`
- Review ACL settings: `pveum acl list`

#### 3. SSL Certificate Issues

```
Error: certificate verify failed
```

**Solutions:**

- Set `validate_certs: false` in configuration
- Or install proper SSL certificates on Proxmox
- Or use `--insecure` flag for testing

### Debug Commands

```bash
# Test API token directly with curl
curl -k -H "Authorization: PVEAPIToken=ansible@pve!homelab-automation=your-token-secret" \
  https://192.168.0.56:8006/api2/json/nodes

# Verify token permissions
pveum user permissions ansible@pve --format yaml

# Check token status
pveum user token list ansible@pve --output-format yaml
```

## Token Management

### Token Rotation Procedure

Rotate tokens regularly (recommended: every 90 days):

```bash
# 1. Generate new token
pveum user token add ansible@pve homelab-automation-v2 --comment "Homelab automation token v2"

# 2. Update Ansible Vault with new token
ansible-vault edit group_vars/all/vault.yml

# 3. Test new token
ansible-playbook test-proxmox-connectivity.yml

# 4. Remove old token after successful testing
pveum user token remove ansible@pve homelab-automation
```

### Security Monitoring

Monitor token usage for security:

```bash
# Create monitoring script
cat > /usr/local/bin/monitor-api-tokens.sh << 'EOF'
#!/bin/bash
# Monitor API token usage
echo "Recent API token activity:"
grep "ansible@pve" /var/log/pveproxy/access.log | tail -10

echo -e "\nActive tokens:"
pveum user token list ansible@pve
EOF

chmod +x /usr/local/bin/monitor-api-tokens.sh
```

### Token Lifecycle Management

1. **Creation**: Document token purpose and scope
2. **Usage**: Monitor access patterns and usage frequency
3. **Rotation**: Replace tokens every 90 days or on security events
4. **Revocation**: Immediately revoke compromised tokens
5. **Audit**: Regular review of active tokens and permissions

## Migration Checklist

- [ ] Create dedicated service user (`ansible@pve`)
- [ ] Configure appropriate permissions for automation tasks
- [ ] Generate API tokens for each Proxmox node
- [ ] Update Ansible Vault with encrypted token values
- [ ] Test API connectivity with new tokens
- [ ] Validate container creation/management operations
- [ ] Update documentation and procedures
- [ ] Remove legacy password authentication
- [ ] Implement token rotation schedule
- [ ] Set up monitoring and alerting for token usage

## Security Recommendations

### ✅ **Best Practices**

- Use dedicated service accounts for automation
- Implement principle of least privilege
- Rotate tokens every 90 days
- Monitor token usage patterns
- Use separate tokens for different environments

### ⚠️ **Security Considerations**

- Store tokens in Ansible Vault only
- Never commit tokens to version control
- Revoke tokens immediately on compromise
- Use strong naming conventions for tokens
- Audit token permissions regularly

### 🔒 **Compliance Standards**

- SOC 2: Implements proper access controls
- PCI DSS: Separates authentication credentials
- NIST: Follows credential management guidelines
- CIS: Applies security configuration standards

## Support and Resources

- **Proxmox API Documentation**: <https://pve.proxmox.com/pve-docs/api-viewer/>
- **Ansible Proxmox Module**: <https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_module.html>
- **Token Management**: <https://pve.proxmox.com/wiki/User_Management#pveum_tokens>
- **Security Best Practices**: Internal documentation in `SECURITY.md`

For additional support, refer to the troubleshooting section or consult the homelab documentation index.
