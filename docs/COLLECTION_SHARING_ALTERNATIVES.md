# Ansible Collection Sharing Alternatives

## Current State Analysis

### Existing Galaxy Publishing Setup

The repository currently has a comprehensive GitHub Actions workflow for publishing to Ansible Galaxy:

- **Workflow**: `.github/workflows/galaxy-publish.yml`
- **Custom Actions**:
  - `build-publish-collection` - Builds and publishes collections
  - `wait-for-galaxy-collection` - Handles dependency resolution with polling
- **Collections**:
  - `homelab.common` (v1.0.0) - Base collection with shared utilities
  - `homelab.k3s` (v1.0.0) - K3s cluster management (depends on common)
  - `homelab.proxmox_lxc` (v1.0.0) - Proxmox LXC management (depends on common)

### Recent Fixes Applied

**Commit ba66a8b**: Corrected `ansible-galaxy publish` flag from `--secret` to `--token`
- Previous: `ansible-galaxy collection publish *.tar.gz --secret $GALAXY_API_KEY`
- Current: `ansible-galaxy collection publish *.tar.gz --token $GALAXY_API_KEY`

### Potential Issues with Current Setup

1. **Galaxy Token Requirement**: Needs `GALAXY_API_KEY` secret configured in GitHub
2. **Namespace Requirements**: `homelab` namespace must be created/approved on Galaxy
3. **Publishing Delays**: Galaxy API propagation can take minutes
4. **Dependency Chain**: k3s and proxmox_lxc wait for common to be available
5. **Network Dependency**: Requires Galaxy infrastructure to be accessible

---

## Alternative Collection Sharing Methods

### Option 1: Ansible Galaxy (Current Approach - RECOMMENDED for Public Sharing)

**Description**: Publish collections to the official Ansible Galaxy repository.

#### Pros
- ✅ Official, centralized repository
- ✅ Built-in version management
- ✅ Dependency resolution handled automatically
- ✅ Discoverable by the community
- ✅ Supports semantic versioning
- ✅ Simple installation: `ansible-galaxy collection install homelab.common`

#### Cons
- ❌ Requires Galaxy account and API token
- ❌ Namespace approval process
- ❌ Publishing delays (API propagation)
- ❌ Public visibility (unless using private automation hub)
- ❌ Requires internet connectivity for installation

#### Setup Requirements
1. Create Ansible Galaxy account
2. Request namespace approval for `homelab`
3. Generate API token
4. Add `GALAXY_API_KEY` to GitHub secrets
5. Trigger workflow via release or manual dispatch

#### Current Status
✅ Workflow configured and fixed
⚠️  Requires Galaxy namespace setup and API token

---

### Option 2: Git-Based Installation (BEST for Internal/Development)

**Description**: Install collections directly from Git repositories without building.

#### Pros
- ✅ No external dependencies (Galaxy)
- ✅ Works with private repositories
- ✅ Fast updates (no publishing delay)
- ✅ Version control via Git tags/branches
- ✅ No API tokens needed
- ✅ Works offline (after initial clone)

#### Cons
- ❌ Requires Git on target hosts
- ❌ Larger footprint (includes .git directory)
- ❌ Manual dependency management
- ❌ No built-in version discovery

#### Implementation

**requirements.yml** (for consumers):
```yaml
---
collections:
  # Option A: From GitHub (public/private)
  - name: https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common
    type: git
    version: main

  # Option B: With specific version tag
  - name: https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common
    type: git
    version: v1.0.0

  # Option C: From local repository
  - name: /path/to/homelab/ansible_collections/homelab/common
    type: dir
```

**Installation**:
```bash
# Install from Git
ansible-galaxy collection install -r requirements.yml

# Or directly
ansible-galaxy collection install \
  git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main
```

**For Private Repos**:
```bash
# Using SSH authentication (recommended)
ansible-galaxy collection install \
  git+git@github.com:pbs-tech/homelab.git#/ansible_collections/homelab/common,main

# Using Personal Access Token
export GITHUB_TOKEN="ghp_your_token"
ansible-galaxy collection install \
  git+https://${GITHUB_TOKEN}@github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common,main

# Or configure Git credentials
git config --global credential.helper store
```

> **📌 For detailed private repository authentication**, see [PRIVATE_REPO_ACCESS.md](PRIVATE_REPO_ACCESS.md) which covers SSH keys, Personal Access Tokens, credential helpers, multi-host deployment, CI/CD integration, and troubleshooting.

#### Current Status
✅ Already functional (no changes needed)
✅ Works with current repository structure
✅ Comprehensive private repo authentication documented

---

### Option 3: Private Automation Hub (Enterprise Solution)

**Description**: Self-hosted Ansible Galaxy alternative using Red Hat Automation Hub or Pulp.

#### Pros
- ✅ Full control over infrastructure
- ✅ Private collections
- ✅ Galaxy-compatible API
- ✅ Support for multiple namespaces
- ✅ Access control and permissions
- ✅ Works with existing workflows

#### Cons
- ❌ Requires infrastructure setup
- ❌ Ongoing maintenance overhead
- ❌ Red Hat subscription (for official hub)
- ❌ Resource requirements
- ❌ Complex initial setup

#### Implementation Options

**Option 3A: Red Hat Automation Hub** (Commercial)
- Requires Red Hat Ansible Automation Platform subscription
- Fully supported enterprise solution
- Integrated with AAP

**Option 3B: Pulp** (Open Source)
- Free, self-hosted alternative
- Galaxy-compatible API
- Container-based deployment available

**Setup** (Pulp via Docker):
```yaml
# docker-compose.yml
version: '3.8'
services:
  pulp:
    image: pulp/pulp:latest
    ports:
      - "8080:80"
    volumes:
      - pulp_data:/var/lib/pulp
    environment:
      - PULP_GALAXY_REQUIRE_CONTENT_APPROVAL=false

volumes:
  pulp_data:
```

**Configuration**:
```bash
# Configure ansible.cfg
cat >> ansible.cfg <<EOF
[galaxy]
server_list = private_hub, galaxy

[galaxy_server.private_hub]
url=http://your-pulp-server:8080/api/galaxy/
token=your-private-token

[galaxy_server.galaxy]
url=https://galaxy.ansible.com/
EOF
```

#### Current Status
⚠️  Requires significant infrastructure setup
❌ Not recommended for homelab use (overkill)

---

### Option 4: HTTP/S File Server (Simple Alternative)

**Description**: Build and host collection tarballs on a simple web server.

#### Pros
- ✅ Simple infrastructure (nginx, Apache, etc.)
- ✅ Fast installation
- ✅ No Galaxy dependency
- ✅ Can run on existing infrastructure
- ✅ Low maintenance

#### Cons
- ❌ Manual version management
- ❌ No dependency resolution
- ❌ No discovery mechanism
- ❌ Requires web server setup
- ❌ Manual builds

#### Implementation

**Build collections**:
```bash
# Add to Makefile or CI/CD
build-collections:
  cd ansible_collections/homelab/common && ansible-galaxy collection build -f
  cd ansible_collections/homelab/k3s && ansible-galaxy collection build -f
  cd ansible_collections/homelab/proxmox_lxc && ansible-galaxy collection build -f
  mkdir -p dist/
  find ansible_collections -name "*.tar.gz" -exec mv {} dist/ \;
```

**Host files** (nginx example):
```nginx
server {
    listen 80;
    server_name collections.homelab.local;
    root /var/www/ansible-collections;
    autoindex on;
}
```

**Installation**:
```bash
# Direct URL installation
ansible-galaxy collection install \
  http://collections.homelab.local/homelab-common-1.0.0.tar.gz

# Or requirements.yml
collections:
  - name: http://collections.homelab.local/homelab-common-1.0.0.tar.gz
    type: url
```

#### Current Status
⚠️  Requires web server infrastructure
✅ Could integrate with existing Traefik/LXC setup

---

### Option 5: Local Build and Install (Development Only)

**Description**: Build collections locally and install from filesystem.

#### Pros
- ✅ No infrastructure needed
- ✅ Fast iteration during development
- ✅ Complete offline capability
- ✅ No external dependencies

#### Cons
- ❌ Manual distribution to hosts
- ❌ No version management
- ❌ Not scalable
- ❌ Requires local builds on each host

#### Implementation

**Build script** (`scripts/build-collections.sh`):
```bash
#!/bin/bash
set -e

COLLECTIONS_DIR="ansible_collections/homelab"
BUILD_DIR="build/collections"

mkdir -p "$BUILD_DIR"

for collection in common k3s proxmox_lxc; do
    echo "Building homelab.$collection..."
    cd "$COLLECTIONS_DIR/$collection"
    ansible-galaxy collection build --force --output-path="../../../$BUILD_DIR"
    cd ../../..
done

echo "Collections built in $BUILD_DIR/"
ls -lh "$BUILD_DIR"/*.tar.gz
```

**Installation**:
```bash
# Build
./scripts/build-collections.sh

# Install locally
ansible-galaxy collection install build/collections/*.tar.gz --force

# Or install from directory (development mode)
ansible-galaxy collection install ansible_collections/homelab/common --force
```

**Distribution to other hosts**:
```bash
# Copy to remote host
scp build/collections/*.tar.gz remote-host:/tmp/

# Install on remote
ssh remote-host "ansible-galaxy collection install /tmp/*.tar.gz --force"
```

#### Current Status
✅ Works immediately (no setup needed)
✅ Useful for development/testing

---

### Option 6: Git Submodules (Advanced)

**Description**: Use Git submodules to embed collections in downstream repositories.

#### Pros
- ✅ Native Git integration
- ✅ Version pinning via commit hashes
- ✅ No build/publish steps
- ✅ Works with private repos

#### Cons
- ❌ Complex Git workflow
- ❌ Submodule management overhead
- ❌ Not Ansible-native approach
- ❌ Steep learning curve

#### Implementation

**Setup** (in consuming repository):
```bash
# Add collections as submodules
git submodule add https://github.com/pbs-tech/homelab.git \
  .ansible/collections/homelab-source

# Create symlinks to collections
mkdir -p collections/ansible_collections/homelab
ln -s ../../../.ansible/collections/homelab-source/ansible_collections/homelab/common \
  collections/ansible_collections/homelab/common
```

**Configure ansible.cfg**:
```ini
[defaults]
collections_paths = ./collections:~/.ansible/collections:/usr/share/ansible/collections
```

#### Current Status
⚠️  Not recommended (too complex for benefit)

---

## Recommendation Matrix

| Method | Best For | Setup Complexity | Maintenance | Offline Support | Multi-Host |
|--------|----------|------------------|-------------|-----------------|------------|
| **Ansible Galaxy** | Public sharing, production | Medium | Low | ❌ | ✅ |
| **Git Installation** | Internal use, development | Low | Low | ✅* | ✅ |
| **Private Hub** | Enterprise, many teams | High | High | ✅ | ✅ |
| **HTTP Server** | Internal, simple needs | Medium | Low | ✅ | ✅ |
| **Local Build** | Development, testing | Low | Low | ✅ | ❌ |
| **Git Submodules** | Tight integration | High | High | ✅* | ✅ |

\* After initial clone

---

## Recommended Approach for Your Homelab

### Primary Recommendation: Hybrid Approach

**Option A + Option 2 Combined**

1. **Public Collections → Ansible Galaxy** (When ready for community sharing)
   - Publish stable releases to Galaxy
   - Benefits community users
   - Provides official version tracking

2. **Internal Development → Git-Based Installation** (Immediate use)
   - Use Git installation for development and testing
   - Fast iteration without publishing delays
   - Works with your existing infrastructure

### Implementation Plan

#### Phase 1: Enable Git-Based Installation (Immediate)

**Create `docs/INSTALLATION.md`**:
```markdown
# Collection Installation

## From Git (Development/Internal Use)

### Install All Collections

Create `requirements.yml`:

\`\`\`yaml
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
\`\`\`

Install:
\`\`\`bash
ansible-galaxy collection install -r requirements.yml --force
\`\`\`

## From Ansible Galaxy (Stable Releases)

\`\`\`bash
ansible-galaxy collection install homelab.common
ansible-galaxy collection install homelab.k3s
ansible-galaxy collection install homelab.proxmox_lxc
\`\`\`
```

#### Phase 2: Fix Galaxy Publishing (When Ready)

1. **Create Galaxy Account**
   - Sign up at <https://galaxy.ansible.com>
   - Request `homelab` namespace

2. **Configure GitHub Secret**
   ```bash
   # In GitHub repository settings
   # Secrets and variables → Actions → New repository secret
   # Name: GALAXY_API_KEY
   # Value: <your-galaxy-api-token>
   ```

3. **Test Publishing**
   ```bash
   # Trigger workflow manually
   # Actions → Publish to Ansible Galaxy → Run workflow
   # Select collection: common
   ```

4. **Create Release for Publishing**
   ```bash
   # Tag and release
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0

   # Create GitHub release
   # This triggers automatic Galaxy publishing
   ```

---

## Quick Start Scripts

### Script 1: Build Collections Locally

**File**: `scripts/build-all-collections.sh`
```bash
#!/bin/bash
# Build all homelab collections

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$REPO_ROOT/build/collections"

echo "Building homelab collections..."
echo "================================"

mkdir -p "$BUILD_DIR"

cd "$REPO_ROOT"

for collection in common k3s proxmox_lxc; do
    echo ""
    echo "Building homelab.$collection..."
    collection_path="ansible_collections/homelab/$collection"

    if [ ! -d "$collection_path" ]; then
        echo "ERROR: Collection not found at $collection_path"
        exit 1
    fi

    cd "$collection_path"
    ansible-galaxy collection build --force --output-path="../../../$BUILD_DIR"
    cd "$REPO_ROOT"
done

echo ""
echo "✓ Collections built successfully!"
echo "================================"
echo "Output: $BUILD_DIR"
ls -lh "$BUILD_DIR"/*.tar.gz
```

### Script 2: Install Collections from Git

**File**: `scripts/install-from-git.sh`
```bash
#!/bin/bash
# Install homelab collections from Git

set -e

GIT_REPO="${GIT_REPO:-https://github.com/pbs-tech/homelab.git}"
GIT_VERSION="${GIT_VERSION:-main}"

echo "Installing homelab collections from Git..."
echo "Repository: $GIT_REPO"
echo "Version: $GIT_VERSION"
echo ""

for collection in common k3s proxmox_lxc; do
    echo "Installing homelab.$collection..."
    ansible-galaxy collection install \
        "${GIT_REPO}#/ansible_collections/homelab/${collection},${GIT_VERSION}" \
        --force
done

echo ""
echo "✓ Collections installed successfully!"
ansible-galaxy collection list | grep homelab
```

### Script 3: Test Collection Installation

**File**: `scripts/test-collection-install.sh`
```bash
#!/bin/bash
# Test collection installation from multiple sources

set -e

echo "Testing collection installation methods..."
echo "=========================================="

# Test 1: Local build and install
echo ""
echo "Test 1: Local build and install"
./scripts/build-all-collections.sh
ansible-galaxy collection install build/collections/*.tar.gz --force
ansible-galaxy collection list | grep homelab

# Test 2: Git installation
echo ""
echo "Test 2: Git-based installation"
./scripts/install-from-git.sh

echo ""
echo "✓ All tests passed!"
```

---

## Troubleshooting

### Galaxy Publishing Issues

**Issue**: `ERROR! The API token is invalid`
- **Fix**: Verify `GALAXY_API_KEY` secret is set correctly
- **Check**: Token hasn't expired on Galaxy

**Issue**: `ERROR! Namespace 'homelab' not found`
- **Fix**: Request namespace approval on Galaxy
- **Alternative**: Use different namespace (e.g., `yourusername.homelab_common`)

**Issue**: `ERROR! Collection already exists`
- **Fix**: Increment version in `galaxy.yml`
- **Note**: Galaxy doesn't allow republishing same version

### Git Installation Issues

**Issue**: `ERROR! failed to download collection`
- **Fix**: Verify Git is installed: `git --version`
- **Fix**: Check repository URL is accessible

**Issue**: `ERROR! Unknown error when attempting to call Galaxy`
- **Fix**: Use explicit Git URL format:
  ```bash
  ansible-galaxy collection install \
    git+https://github.com/pbs-tech/homelab.git#/ansible_collections/homelab/common
  ```

---

## Next Steps

1. **Immediate**: Enable Git-based installation for development
2. **Short-term**: Create installation documentation
3. **Medium-term**: Set up Galaxy account and namespace
4. **Long-term**: Consider automation hub if team grows

---

## Additional Resources

- [Ansible Galaxy Documentation](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html)
- [Collection Publishing Guide](https://docs.ansible.com/ansible/latest/dev_guide/developing_collections_distributing.html)
- [Git Installation Method](https://docs.ansible.com/ansible/latest/collections_guide/collections_installing.html#installing-a-collection-from-a-git-repository)
- [Private Automation Hub](https://www.ansible.com/products/automation-hub)

