# Accessing Collections from Private GitHub Repositories

This guide covers all methods for installing Ansible collections from private GitHub repositories, including authentication setup, best practices, and troubleshooting.

## Quick Start

### Method 1: SSH Authentication (Recommended)

**Best for:** Personal use, development workstations, dedicated Ansible control nodes

```bash
# Install using SSH URL
ansible-galaxy collection install \
  git+git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

### Method 2: Personal Access Token (PAT)

**Best for:** CI/CD pipelines, automation, temporary access

```bash
# Set your token
export GITHUB_TOKEN="ghp_your_personal_access_token"

# Install using HTTPS with token
ansible-galaxy collection install \
  git+https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

### Method 3: Git Credential Helper

**Best for:** Multi-host deployments, persistent authentication

```bash
# Configure Git credential storage (one-time setup)
git config --global credential.helper store

# Install (will prompt for credentials once)
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

---

## Detailed Setup Guides

### Option 1: SSH Key Authentication (Recommended)

SSH authentication is the most secure and convenient method for private repositories.

#### Prerequisites

- SSH key pair generated
- Public key added to GitHub account
- SSH agent running (optional but recommended)

#### Step 1: Generate SSH Key (if needed)

```bash
# Generate a new SSH key
ssh-keygen -t ed25519 -C "homelab-ansible" -f ~/.ssh/homelab_github

# Or use RSA if ed25519 is not supported
ssh-keygen -t rsa -b 4096 -C "homelab-ansible" -f ~/.ssh/homelab_github
```

#### Step 2: Add SSH Key to GitHub

```bash
# Copy public key to clipboard
cat ~/.ssh/homelab_github.pub

# Then:
# 1. Go to GitHub.com → Settings → SSH and GPG keys
# 2. Click "New SSH key"
# 3. Paste the public key
# 4. Give it a descriptive title (e.g., "Homelab Ansible Server")
```

#### Step 3: Configure SSH (Optional but Recommended)

Create or edit `~/.ssh/config`:

```bash
cat >> ~/.ssh/config <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/homelab_github
    IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
```

#### Step 4: Test SSH Connection

```bash
# Test GitHub SSH connection
ssh -T git@github.com

# Expected output:
# Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

#### Step 5: Install Collections Using SSH

**Direct installation:**

```bash
# Install single collection
ansible-galaxy collection install \
  git+git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force

# Install all collections
for collection in common k3s proxmox_lxc; do
  ansible-galaxy collection install \
    git+git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/${collection},main \
    --force
done
```

**Using requirements.yml:**

```yaml
---
collections:
  - name: git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/common
    type: git
    version: main

  - name: git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/k3s
    type: git
    version: main

  - name: git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/proxmox_lxc
    type: git
    version: main
```

```bash
# Install from requirements.yml
ansible-galaxy collection install -r requirements.yml --force
```

**Update the install script for SSH:**

```bash
# Set environment variable to use SSH
export GIT_REPO="git@github.com:pbs-tech/homelab.git"
./scripts/install-from-git.sh
```

---

### Option 2: Personal Access Token (PAT)

GitHub Personal Access Tokens provide HTTPS-based authentication for private repositories.

#### Step 1: Create Personal Access Token

1. Go to GitHub.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: "Homelab Ansible Collections"
4. Set expiration (recommend: 90 days for security)
5. Select scopes:
   - ✅ `repo` (Full control of private repositories)
6. Click "Generate token"
7. **Copy the token immediately** (you won't see it again!)

**Fine-grained token (alternative):**

1. Go to Personal access tokens → Fine-grained tokens
2. Click "Generate new token"
3. Configure:
   - Token name: "Homelab Ansible Collections"
   - Expiration: 90 days
   - Repository access: Select "Only select repositories" → Choose `pbs-tech/homelab`
   - Permissions → Repository permissions:
     - Contents: Read-only
4. Generate and copy token

#### Step 2: Store Token Securely

**Option A: Environment Variable (Temporary)**

```bash
# Set for current session
export GITHUB_TOKEN="ghp_your_token_here"

# Or add to ~/.bashrc or ~/.zshrc for persistence
echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.bashrc
source ~/.bashrc
```

**Option B: Git Credential Store (Persistent)**

```bash
# Enable credential storage
git config --global credential.helper store

# First use will prompt and store credentials
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force

# Username: your_github_username
# Password: ghp_your_token_here (NOT your GitHub password!)
```

**Option C: Ansible Vault (Most Secure)**

```bash
# Create vault file for token
ansible-vault create ~/.ansible_vault_github.yml

# Add content:
---
github_token: "ghp_your_token_here"

# Save vault password
echo "your_vault_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass
```

Then use in playbooks:

```yaml
---
- name: Install collections from private repo
  hosts: localhost
  vars_files:
    - ~/.ansible_vault_github.yml
  tasks:
    - name: Install collections
      ansible.builtin.command:
        cmd: >
          ansible-galaxy collection install
          git+https://{{ github_token }}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/{{ item }},main
          --force
      loop:
        - common
        - k3s
        - proxmox_lxc
      changed_when: true
```

#### Step 3: Install Collections Using PAT

**Direct installation:**

```bash
# Using environment variable
ansible-galaxy collection install \
  git+https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force

# Or inline (not recommended - visible in process list)
ansible-galaxy collection install \
  git+https://ghp_your_token@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

**Using requirements.yml with token substitution:**

```yaml
---
collections:
  # Note: Token substitution requires environment variable or script processing
  - name: https://{{ lookup('env', 'GITHUB_TOKEN') }}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common
    type: git
    version: main
```

**Install script with PAT support:**

```bash
#!/bin/bash
# install-from-private-git.sh

set -e

if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GITHUB_TOKEN environment variable not set"
    echo "Set it with: export GITHUB_TOKEN='ghp_your_token'"
    exit 1
fi

GIT_REPO="https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git"
GIT_VERSION="${GIT_VERSION:-main}"

echo "Installing homelab collections from private GitHub repo..."
echo "Version: $GIT_VERSION"
echo ""

for collection in common k3s proxmox_lxc; do
    echo "Installing homelab.$collection..."
    ansible-galaxy collection install \
        "git+${GIT_REPO}#/ansible_collections/homelab/${collection},${GIT_VERSION}" \
        --force
done

echo ""
echo "✓ Collections installed successfully!"
ansible-galaxy collection list | grep homelab
```

---

### Option 3: Git Credential Helper

Git credential helpers securely store authentication credentials.

#### Step 1: Choose Credential Helper

**Linux - libsecret (Recommended):**

```bash
# Install dependencies
sudo apt-get install libsecret-1-0 libsecret-1-dev

# Configure Git to use libsecret
git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
```

**macOS - Keychain:**

```bash
# macOS includes this by default
git config --global credential.helper osxkeychain
```

**Cross-platform - Store (Simple but less secure):**

```bash
# Stores credentials in plaintext file ~/.git-credentials
git config --global credential.helper store
```

**Cross-platform - Cache (Temporary):**

```bash
# Cache credentials in memory for 1 hour (3600 seconds)
git config --global credential.helper 'cache --timeout=3600'
```

#### Step 2: Configure Credential Helper

```bash
# Set global credential helper
git config --global credential.helper store

# Verify configuration
git config --global --get credential.helper
```

#### Step 3: First-Time Authentication

```bash
# First install will prompt for credentials
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force

# Enter:
# Username: your_github_username
# Password: ghp_your_personal_access_token (or your password if 2FA is not enabled)

# Subsequent installs will use stored credentials automatically
```

#### Step 4: Verify Stored Credentials

```bash
# For 'store' helper, check credentials file
cat ~/.git-credentials
# Format: https://username:token@github.com

# For 'cache' helper, credentials are in memory only
```

---

## Multi-Host Deployment with Private Repos

### Scenario 1: Deploy to Multiple Ansible Control Nodes

**Using SSH keys:**

```bash
#!/bin/bash
# deploy-to-control-nodes.sh

CONTROL_NODES="control1 control2 control3"
SSH_KEY="~/.ssh/homelab_github"

for node in $CONTROL_NODES; do
    echo "Setting up $node..."

    # Copy SSH key
    scp $SSH_KEY* $node:~/.ssh/

    # Set permissions
    ssh $node "chmod 600 ~/.ssh/homelab_github"

    # Install collections
    ssh $node "ansible-galaxy collection install \
        git+git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
        --force"
done
```

**Using PAT:**

```bash
#!/bin/bash
# deploy-to-control-nodes-pat.sh

CONTROL_NODES="control1 control2 control3"
GITHUB_TOKEN="ghp_your_token"

for node in $CONTROL_NODES; do
    echo "Setting up $node..."

    # Set token on remote node
    ssh $node "echo 'export GITHUB_TOKEN=\"$GITHUB_TOKEN\"' >> ~/.bashrc"

    # Install collections
    ssh $node "ansible-galaxy collection install \
        git+https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
        --force"
done
```

### Scenario 2: Ansible Playbook for Distribution

**Using SSH (preferred):**

```yaml
---
# playbooks/install-collections-private.yml
- name: Install collections from private GitHub repo
  hosts: all
  vars:
    git_url: "git@github.com:pbs-tech/homelab.git"
    git_version: "main"
    collections:
      - common
      - k3s
      - proxmox_lxc
  tasks:
    - name: Ensure SSH directory exists
      ansible.builtin.file:
        path: "{{ ansible_env.HOME }}/.ssh"
        state: directory
        mode: '0700'

    - name: Copy GitHub SSH key
      ansible.builtin.copy:
        src: ~/.ssh/homelab_github
        dest: "{{ ansible_env.HOME }}/.ssh/homelab_github"
        mode: '0600'
      when: ansible_connection != 'local'

    - name: Install collections from private repo
      ansible.builtin.command:
        cmd: >
          ansible-galaxy collection install
          git+{{ git_url }}#/ansible_collections/homelab/{{ item }},{{ git_version }}
          --force
      loop: "{{ collections }}"
      changed_when: true
```

**Using PAT with Ansible Vault:**

```yaml
---
# playbooks/install-collections-private.yml
- name: Install collections from private GitHub repo
  hosts: all
  vars_files:
    - vars/github_vault.yml  # Contains: github_token: "ghp_..."
  vars:
    git_version: "main"
    collections:
      - common
      - k3s
      - proxmox_lxc
  tasks:
    - name: Install collections from private repo
      ansible.builtin.command:
        cmd: >
          ansible-galaxy collection install
          git+https://{{ github_token }}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/{{ item }},{{ git_version }}
          --force
      loop: "{{ collections }}"
      changed_when: true
      no_log: true  # Prevent token from appearing in logs
```

---

## Advanced Configuration

### Using Git Configuration Files

**~/.gitconfig:**

```ini
[credential]
    helper = store

[credential "https://github.com"]
    username = your_github_username

[url "git@github.com:"]
    insteadOf = https://github.com/
```

This configuration automatically converts HTTPS URLs to SSH URLs.

### Using .netrc File

The `.netrc` file provides automatic authentication for HTTPS:

```bash
# Create .netrc file
cat > ~/.netrc <<EOF
machine github.com
login your_github_username
password ghp_your_personal_access_token
EOF

chmod 600 ~/.netrc
```

Then install without embedding token in URL:

```bash
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Install Collections
on: [push]

jobs:
  install:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install collections
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          ansible-galaxy collection install \
            git+https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
            --force
```

### GitLab CI

```yaml
install_collections:
  script:
    - |
      ansible-galaxy collection install \
        git+https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
        --force
  variables:
    GITHUB_TOKEN: $GITHUB_PAT  # Set in GitLab CI/CD variables
```

### Jenkins

```groovy
pipeline {
    agent any
    environment {
        GITHUB_TOKEN = credentials('github-pat')
    }
    stages {
        stage('Install Collections') {
            steps {
                sh '''
                    ansible-galaxy collection install \
                      git+https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
                      --force
                '''
            }
        }
    }
}
```

---

## Troubleshooting

### Issue: Permission Denied (SSH)

**Symptoms:**
```
Permission denied (publickey).
fatal: Could not read from remote repository.
```

**Solutions:**

```bash
# 1. Verify SSH key is added to GitHub
ssh -T git@github.com

# 2. Check SSH agent has key loaded
ssh-add -l

# 3. Add key to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/homelab_github

# 4. Test with verbose output
ssh -vvv git@github.com

# 5. Verify SSH config
cat ~/.ssh/config
```

### Issue: Authentication Failed (HTTPS)

**Symptoms:**
```
fatal: Authentication failed for 'https://github.com/pbs-tech/homelab.git/'
```

**Solutions:**

```bash
# 1. Verify token is valid
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# 2. Check token has repo scope
# Go to GitHub → Settings → Developer settings → Personal access tokens
# Verify 'repo' scope is enabled

# 3. Verify token is correctly set
echo $GITHUB_TOKEN  # Should show ghp_...

# 4. Try with explicit token
ansible-galaxy collection install \
  git+https://ghp_your_token@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  -vvv

# 5. Clear credential cache
git credential-cache exit
```

### Issue: Repository Not Found

**Symptoms:**
```
ERROR! the configured path ... does not exist or is not accessible
fatal: repository 'https://github.com/pbs-tech/homelab.git/' not found
```

**Solutions:**

```bash
# 1. Verify repository name is correct
# Should be: pbs-tech/homelab (not PBS-Tech/homelab)

# 2. Verify you have access to repository
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/pbs-tech/homelab

# 3. Check if repository is private
# Ensure authentication is properly configured

# 4. Test Git clone manually
git clone git@github.com:pbs-tech/homelab.git /tmp/test-clone
```

### Issue: Token Expired

**Symptoms:**
```
fatal: Authentication failed
HTTP 401: Unauthorized
```

**Solutions:**

```bash
# 1. Generate new token at GitHub
# Settings → Developer settings → Personal access tokens

# 2. Update stored credentials
# For credential store:
rm ~/.git-credentials
# Then reinstall to store new credentials

# 3. Update environment variable
export GITHUB_TOKEN="new_token_here"

# 4. Update Ansible vault
ansible-vault edit ~/.ansible_vault_github.yml
```

---

## Security Best Practices

### 1. Token Management

- ✅ Use fine-grained tokens with minimal permissions
- ✅ Set expiration dates (90 days recommended)
- ✅ Rotate tokens regularly
- ✅ Use Ansible Vault for storing tokens in playbooks
- ✅ Never commit tokens to repositories
- ❌ Don't use classic tokens with full access
- ❌ Don't set tokens to never expire
- ❌ Don't share tokens between users/systems

### 2. SSH Key Management

- ✅ Use separate keys for different purposes
- ✅ Protect private keys with passphrases
- ✅ Use SSH agent for passphrase caching
- ✅ Set appropriate file permissions (600)
- ✅ Regularly audit authorized keys on GitHub
- ❌ Don't reuse personal SSH keys
- ❌ Don't distribute private keys
- ❌ Don't use keys without passphrases in production

### 3. Credential Storage

- ✅ Use OS-native credential managers (Keychain, libsecret)
- ✅ Encrypt credentials at rest
- ✅ Use environment-specific credentials
- ✅ Audit credential access logs
- ❌ Don't use plaintext storage in production
- ❌ Don't commit `.netrc` or `.git-credentials` files
- ❌ Don't store credentials in playbooks

### 4. Logging and Auditing

```yaml
# Use no_log to prevent sensitive data in logs
- name: Install with token
  ansible.builtin.command:
    cmd: ansible-galaxy collection install git+https://{{ github_token }}@github.com/...
  no_log: true  # Prevents token from appearing in logs
  changed_when: true
```

---

## Quick Reference

### SSH Method

```bash
# One-time setup
ssh-keygen -t ed25519 -f ~/.ssh/homelab_github
# Add public key to GitHub

# Install
ansible-galaxy collection install \
  git+git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

### PAT Method

```bash
# One-time setup
# Generate token at GitHub → Settings → Developer settings → PAT
export GITHUB_TOKEN="ghp_..."

# Install
ansible-galaxy collection install \
  git+https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

### Credential Helper Method

```bash
# One-time setup
git config --global credential.helper store

# First install (prompts for credentials)
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
# Username: your_username
# Password: ghp_your_token

# Subsequent installs use stored credentials
```

---

## Summary Comparison

| Method | Security | Ease of Use | Multi-Host | CI/CD | Recommendation |
|--------|----------|-------------|------------|-------|----------------|
| **SSH Keys** | High | Medium | Medium | Low | ⭐ Best for development |
| **PAT (env var)** | Medium | High | High | High | ⭐ Best for automation |
| **PAT (vault)** | High | Medium | High | High | ⭐ Best for production |
| **Credential Helper** | Medium-High | High | Low | Low | Good for single host |
| **.netrc** | Low | High | Medium | Medium | Not recommended |

---

## Additional Resources

- [GitHub: Managing Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [GitHub: Connecting to GitHub with SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Git Credential Storage](https://git-scm.com/book/en/v2/Git-Tools-Credential-Storage)
- [Ansible: Using Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)

