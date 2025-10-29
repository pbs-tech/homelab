# Collection Installation Guide

This guide covers multiple methods for installing the homelab Ansible collections.

> **📌 Private Repository Access**: If your repository is private, see [PRIVATE_REPO_ACCESS.md](PRIVATE_REPO_ACCESS.md) for detailed authentication setup using SSH keys or Personal Access Tokens.

## Quick Start

### Method 1: Git-Based Installation (Recommended for Development)

**Install all collections from GitHub:**

```bash
# Using the install script
./scripts/install-from-git.sh

# Or manually
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/k3s,main \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/proxmox_lxc,main \
  --force
```

**Using requirements.yml:**

Create `requirements.yml`:

```yaml
---
collections:
  - name: https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common
    type: git
    version: main

  - name: https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/k3s
    type: git
    version: main

  - name: https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/proxmox_lxc
    type: git
    version: main
```

Install:

```bash
ansible-galaxy collection install -r requirements.yml --force
```

### Method 2: From Ansible Galaxy (Stable Releases)

```bash
ansible-galaxy collection install homelab.common
ansible-galaxy collection install homelab.k3s
ansible-galaxy collection install homelab.proxmox_lxc
```

### Method 3: Local Build and Install

**Build collections:**

```bash
# Using the build script
./scripts/build-all-collections.sh

# Or manually build each collection
cd ansible_collections/homelab/common && ansible-galaxy collection build
cd ../k3s && ansible-galaxy collection build
cd ../proxmox_lxc && ansible-galaxy collection build
```

**Install built collections:**

```bash
ansible-galaxy collection install build/collections/*.tar.gz --force
```

---

## Installation Methods Comparison

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **Git** | Development, testing | Fast updates, no publishing | Requires Git |
| **Galaxy** | Production, stable releases | Official, versioned | Requires publishing |
| **Local** | Offline, air-gapped | No dependencies | Manual distribution |

---

## Installing from Private Repositories

If your repository is private, you'll need to configure authentication. See [PRIVATE_REPO_ACCESS.md](PRIVATE_REPO_ACCESS.md) for complete details.

### Quick Start for Private Repos

**Option 1: SSH Authentication (Recommended)**

```bash
# Setup (one-time)
ssh-keygen -t ed25519 -f ~/.ssh/homelab_github
# Add public key to GitHub → Settings → SSH keys

# Install using SSH URL
GIT_REPO="git@github.com:pbs-tech/homelab.git" ./scripts/install-from-git.sh

# Or manually
ansible-galaxy collection install \
  git+git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

**Option 2: Personal Access Token**

```bash
# Setup (one-time)
# Generate token at GitHub → Settings → Developer settings → Personal access tokens
# Scope: repo (Full control of private repositories)

# Install using token
export GITHUB_TOKEN="ghp_your_token_here"
./scripts/install-from-git.sh

# Or manually
ansible-galaxy collection install \
  git+https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

**Option 3: Git Credential Helper**

```bash
# Setup (one-time)
git config --global credential.helper store

# First install prompts for credentials
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
# Enter: username and token (NOT password)

# Subsequent installs use stored credentials automatically
```

---

## Advanced Installation

### Install Specific Version from Git

```bash
# Install from a specific tag
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,v1.0.0

# Install from a specific branch
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,develop
```

### Install from Private Repository

**Using SSH:**

```bash
ansible-galaxy collection install \
  git+git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/common,main
```

**Using Personal Access Token:**

```bash
# Set token in environment
export GIT_TOKEN="your-github-token"

ansible-galaxy collection install \
  git+https://${GIT_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main
```

### Install to Custom Location

```bash
# Install to specific directory
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  -p ./my-collections

# Configure in ansible.cfg
cat >> ansible.cfg <<EOF
[defaults]
collections_paths = ./my-collections:~/.ansible/collections
EOF
```

---

## Verification

### Check Installed Collections

```bash
# List all installed collections
ansible-galaxy collection list

# List only homelab collections
ansible-galaxy collection list | grep homelab

# Check specific collection version
ansible-galaxy collection list homelab.common
```

### Test Collection Functionality

```bash
# Create a test playbook
cat > test-collections.yml <<EOF
---
- name: Test homelab collections
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Test common collection
      ansible.builtin.debug:
        msg: "homelab.common is available"

    - name: List collection roles
      ansible.builtin.command:
        cmd: ansible-galaxy role list
      register: roles
      changed_when: false

    - name: Display result
      ansible.builtin.debug:
        var: roles.stdout_lines
EOF

# Run test playbook
ansible-playbook test-collections.yml
```

---

## Multi-Host Deployment

### Distribute Collections to Multiple Hosts

**Option 1: Git-based (Recommended)**

On each target host:

```bash
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force
```

**Option 2: Build once, distribute tarballs**

```bash
# On build host
./scripts/build-all-collections.sh

# Copy to target hosts
for host in bastion1 bastion2 node1 node2; do
  scp build/collections/*.tar.gz $host:/tmp/
  ssh $host "ansible-galaxy collection install /tmp/*.tar.gz --force"
done
```

**Option 3: Ansible playbook for distribution**

Create `deploy-collections.yml`:

```yaml
---
- name: Deploy homelab collections to all hosts
  hosts: all
  become: true
  tasks:
    - name: Install collections from Git
      ansible.builtin.command:
        cmd: >
          ansible-galaxy collection install
          git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/{{ item }},main
          --force
      loop:
        - common
        - k3s
        - proxmox_lxc
      changed_when: true
```

Run:

```bash
ansible-playbook -i inventory/hosts.yml deploy-collections.yml
```

---

## Updating Collections

### Update from Git

```bash
# Update all collections to latest version
./scripts/install-from-git.sh

# Or manually
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main \
  --force --upgrade
```

### Update from Galaxy

```bash
ansible-galaxy collection install homelab.common --upgrade
ansible-galaxy collection install homelab.k3s --upgrade
ansible-galaxy collection install homelab.proxmox_lxc --upgrade
```

---

## Troubleshooting

### Common Issues

**Issue**: `ERROR! - the configured path ... does not exist`

**Solution**: Create the collections directory

```bash
mkdir -p ~/.ansible/collections/ansible_collections
```

**Issue**: `ERROR! - Unknown error when attempting to call Galaxy`

**Solution**: Use explicit Git URL format

```bash
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common
```

**Issue**: `ERROR! failed to download collection`

**Solution**: Verify Git is installed and repository is accessible

```bash
git --version
git ls-remote https://github.com/pbs-tech/homelab.git
```

**Issue**: `ERROR! Collection already installed`

**Solution**: Use `--force` flag to overwrite

```bash
ansible-galaxy collection install <collection> --force
```

### Debugging Installation

**Enable verbose output:**

```bash
ansible-galaxy collection install <collection> -vvv
```

**Check collection path:**

```bash
ansible-config dump | grep COLLECTIONS_PATHS
```

**Verify collection structure:**

```bash
tree ~/.ansible/collections/ansible_collections/homelab/
```

---

## Offline Installation

### Prepare for Offline Installation

**On internet-connected host:**

```bash
# Build all collections
./scripts/build-all-collections.sh

# Download external dependencies
ansible-galaxy collection download -r requirements.yml -p ./offline-collections

# Package everything
tar -czf homelab-collections-offline.tar.gz \
  build/collections/*.tar.gz \
  offline-collections/
```

**On offline host:**

```bash
# Extract package
tar -xzf homelab-collections-offline.tar.gz

# Install external dependencies
cd offline-collections
ansible-galaxy collection install *.tar.gz --force

# Install homelab collections
cd ../build/collections
ansible-galaxy collection install *.tar.gz --force
```

---

## Automation

### Add to Makefile

Add these targets to your `Makefile`:

```makefile
.PHONY: install-collections install-collections-git build-collections

install-collections-git:
	@echo "Installing collections from Git..."
	@./scripts/install-from-git.sh

build-collections:
	@echo "Building collections..."
	@./scripts/build-all-collections.sh

install-collections: build-collections
	@echo "Installing locally built collections..."
	@ansible-galaxy collection install build/collections/*.tar.gz --force
```

Usage:

```bash
make install-collections-git  # Install from Git
make build-collections        # Build locally
make install-collections      # Build and install locally
```

---

## Best Practices

1. **Version Pinning**: Always specify version for production deployments
2. **Testing**: Test collection updates in development before production
3. **Documentation**: Keep track of which collections are installed where
4. **Automation**: Use requirements.yml for reproducible installations
5. **Updates**: Regularly update collections to get bug fixes and features

---

## Next Steps

- Review [COLLECTION_SHARING_ALTERNATIVES.md](COLLECTION_SHARING_ALTERNATIVES.md) for detailed comparison
- Set up automated collection installation in your deployment pipeline
- Configure collections for your specific environment

