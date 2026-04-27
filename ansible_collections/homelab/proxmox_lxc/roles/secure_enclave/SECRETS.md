# Secrets Management for Secure Enclave

## Overview

The Secure Enclave role requires several secrets for deployment and operation. This document outlines the secrets management approach and best practices.

## Required Secrets

### 1. Proxmox API Credentials

**Location**: `ansible_collections/homelab/common/inventory/group_vars/all.yml` (encrypted with Ansible Vault)

**Format**:
```yaml
vault_proxmox_api_tokens:
  pve_mac:
    token_id: "root@pam!ansible"
    token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  pve_nas:
    token_id: "root@pam!ansible"
    token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**Best Practices**:
- Use API tokens instead of passwords (more secure, auditable)
- Create dedicated API tokens with minimum required permissions
- Rotate tokens every 90 days
- Never commit unencrypted tokens to version control

### 2. SSH Keys

**Location**: `~/.ssh/` or specified path

**Usage**:
- Bastion host access
- VM/container authentication
- Inter-container communication

**Best Practices**:
- Use ED25519 keys (more secure than RSA)
- Protect private keys with passphrases
- Use SSH agent forwarding carefully
- Rotate keys annually

#### SSH Key Setup and Configuration

**1. Generate SSH Key Pair**:
```bash
# Generate ED25519 key for enclave access
ssh-keygen -t ed25519 -f ~/.ssh/enclave_id_ed25519 -C "enclave-access"

# Set proper permissions
chmod 600 ~/.ssh/enclave_id_ed25519
chmod 644 ~/.ssh/enclave_id_ed25519.pub
```

**2. Configure Ansible to Use SSH Key**:

Add to `inventory/group_vars/all.yml` or specific host group:
```yaml
# SSH configuration for enclave access
ansible_ssh_private_key_file: ~/.ssh/enclave_id_ed25519
ansible_user: root  # or pbs for bastion
ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

Or specify per-host in inventory:
```yaml
# In inventory/hosts.yml
enclave_bastion:
  ansible_host: 192.168.0.250
  ansible_user: pbs
  ansible_ssh_private_key_file: ~/.ssh/enclave_id_ed25519
```

**3. Deploy Public Key to Enclave Components**:

The role automatically deploys your public key during container/VM creation. To manually add keys:

```bash
# Copy public key to bastion
ssh-copy-id -i ~/.ssh/enclave_id_ed25519.pub pbs@192.168.0.250

# Or manually add to authorized_keys
cat ~/.ssh/enclave_id_ed25519.pub | ssh root@192.168.0.250 \
  'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
```

**4. Verify SSH Access**:
```bash
# Test connection without password prompt
ssh -i ~/.ssh/enclave_id_ed25519 pbs@192.168.0.250

# Should connect without password if configured correctly
```

**5. Key Storage Locations**:

Recommended directory structure:
```
~/.ssh/
├── enclave_id_ed25519         # Private key (600 permissions)
├── enclave_id_ed25519.pub     # Public key (644 permissions)
├── config                      # SSH client config
└── known_hosts                # Host fingerprints
```

**6. SSH Config File (Optional but Recommended)**:

Add to `~/.ssh/config`:
```
# Enclave Bastion Host
Host enclave-bastion
    HostName 192.168.0.250
    User pbs
    IdentityFile ~/.ssh/enclave_id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Enclave Attacker VM (via bastion)
Host enclave-attacker
    HostName 10.10.0.10
    User root
    IdentityFile ~/.ssh/enclave_id_ed25519
    ProxyJump enclave-bastion
```

Usage:
```bash
ssh enclave-bastion    # Direct access to bastion
ssh enclave-attacker   # Jump through bastion to attacker VM
```

**7. Integration with Ansible Playbooks**:

The secure enclave role uses the configured SSH key automatically during deployment:

```yaml
# In roles/secure_enclave/tasks/bastion.yml
- name: Deploy SSH public key to bastion
  ansible.posix.authorized_key:
    user: pbs
    key: "{{ lookup('file', '~/.ssh/enclave_id_ed25519.pub') }}"
    state: present
```

**Common Issues and Solutions**:

| Issue | Cause | Solution |
|-------|-------|----------|
| Permission denied (publickey) | Key not in authorized_keys | Run ssh-copy-id or manually add key |
| Key not found | Wrong path in ansible config | Verify ansible_ssh_private_key_file path |
| Connection timeout | Network isolation blocking | Access via bastion host |
| Password prompt despite key | Wrong permissions on key file | chmod 600 on private key |

### 3. SSL/TLS Certificates (Optional)

**Location**: Managed by Traefik (if integrated)

**Best Practices**:
- Use Let's Encrypt for automatic renewal
- Store certificates in Ansible Vault if manual
- Never commit private keys to version control

## Encryption

### Ansible Vault

All secrets MUST be encrypted using Ansible Vault:

**Encrypt a file**:
```bash
ansible-vault encrypt group_vars/all.yml
```

**Edit encrypted file**:
```bash
ansible-vault edit group_vars/all.yml
```

**Decrypt for viewing (NOT recommended)**:
```bash
ansible-vault decrypt group_vars/all.yml
# View
ansible-vault encrypt group_vars/all.yml  # Re-encrypt immediately
```

**Run playbook with vault**:
```bash
ansible-playbook playbooks/secure-enclave.yml --ask-vault-pass
# OR
ansible-playbook playbooks/secure-enclave.yml --vault-password-file ~/.vault_pass
```

### Vault Password File

Store vault password securely:

```bash
# Create vault password file (one-time)
echo "your-secure-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Configure in ansible.cfg
vault_password_file = ~/.vault_pass
```

**CRITICAL**: Never commit `.vault_pass` to version control!

Add to `.gitignore`:
```
.vault_pass
**/vault_pass
**/*.vault
```

## Creating API Tokens in Proxmox

1. **Navigate to Proxmox Web UI** → Datacenter → Permissions → API Tokens

2. **Create Token**:
   - User: `root@pam`
   - Token ID: `ansible`
   - Privilege Separation: `No` (for full permissions)
   - Click "Add"

3. **Copy Token Secret** (shown only once!)

4. **Store in Vault**:
```bash
ansible-vault edit inventory/group_vars/all.yml
```

Add:
```yaml
vault_proxmox_api_tokens:
  pve_mac:
    token_id: "root@pam!ansible"
    token_secret: "paste-secret-here"
```

## Required Permissions

### Proxmox API Token Permissions

Minimum required permissions:
- `VM.Allocate` - Create VMs/containers
- `VM.Config.Disk` - Configure disks
- `VM.Config.Network` - Configure network
- `VM.PowerMgmt` - Start/stop/shutdown
- `Datastore.AllocateSpace` - Use storage
- `SDN.Use` - Use software-defined networking (if applicable)

**Grant permissions**:
```bash
# Via Proxmox CLI
pveum acl modify / -token 'root@pam!ansible' -role PVEVMAdmin
```

## Secrets Rotation Schedule

| Secret Type | Rotation Frequency | Last Rotated | Next Rotation |
|-------------|-------------------|--------------|---------------|
| Proxmox API Tokens | 90 days | YYYY-MM-DD | YYYY-MM-DD |
| SSH Keys | 365 days | YYYY-MM-DD | YYYY-MM-DD |
| Vault Password | 180 days | YYYY-MM-DD | YYYY-MM-DD |

## Emergency Procedures

### Compromised API Token

1. **Immediately revoke** token in Proxmox UI
2. **Generate new** token with different ID
3. **Update** vault file with new token
4. **Rotate** vault password
5. **Audit** all enclave activity logs
6. **Review** firewall rules and network isolation

### Compromised SSH Key

1. **Remove** public key from all authorized_keys files
2. **Generate** new key pair
3. **Deploy** new public key to all systems
4. **Update** vault with new key paths
5. **Audit** SSH access logs

### Vault Password Leak

1. **Change** vault password immediately
2. **Re-encrypt** all vault files with new password
3. **Rotate** ALL secrets in vault (API tokens, SSH keys, etc.)
4. **Audit** all playbook execution logs
5. **Review** Git history for leaked passwords

## Security Best Practices

### 1. Principle of Least Privilege

- Grant only necessary permissions
- Use separate tokens for different purposes
- Avoid using root account directly

### 2. Defense in Depth

- Multiple layers of encryption (vault + SSH)
- Network isolation (enclave separated from production)
- Access controls (bastion host, key-based auth)

### 3. Audit and Monitoring

- Enable audit logging (auditd)
- Monitor API token usage
- Track all enclave access
- Regular security audits

### 4. Secure Development

- Never commit secrets to Git
- Use .gitignore for sensitive files
- Scan repositories for secrets (trufflehog, gitleaks)
- Code review for security issues

### 5. Backup and Recovery

- Backup encrypted vault files
- Store vault password in password manager
- Document recovery procedures
- Test recovery regularly

## Compliance Considerations

### Data Classification

- **Highly Sensitive**: API tokens, private keys, vault passwords
- **Sensitive**: Configuration files, IP addresses, hostnames
- **Public**: Role code, documentation, README files

### Retention Policy

- Keep audit logs for 90 days minimum
- Archive encrypted vault backups for 1 year
- Securely delete rotated secrets

### Access Control

- Limit vault password to authorized personnel only
- Use separate vaults for different environments (dev/staging/prod)
- Implement two-person rule for production changes

## Tools and Resources

### Recommended Tools

- **Ansible Vault**: Built-in encryption for Ansible
- **1Password/Bitwarden**: Password managers for vault passwords
- **git-secrets**: Prevent committing secrets to Git
- **trufflehog**: Scan Git history for secrets
- **SOPS**: Alternative to Ansible Vault (Mozilla)

### Useful Commands

**Check for unencrypted secrets**:
```bash
grep -r "api_token_secret" . --include="*.yml" | grep -v "vault"
```

**Verify vault encryption**:
```bash
head -1 group_vars/all.yml | grep '$ANSIBLE_VAULT'
```

**List vault IDs**:
```bash
ansible-vault view group_vars/all.yml | grep -E "(token_id|api_token)"
```

## References

- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Proxmox API Token Management](https://pve.proxmox.com/wiki/User_Management#pveum_tokens)
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [CIS Ansible Security Guidelines](https://www.cisecurity.org/)

---

**Last Updated**: 2025-01-XX
**Version**: 1.0
**Maintainer**: Infrastructure Team
