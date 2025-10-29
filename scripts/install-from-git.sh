#!/bin/bash
# Install homelab collections from Git (supports public and private repositories)
#
# Usage:
#   # Public repo (HTTPS)
#   ./install-from-git.sh
#
#   # Private repo (SSH - recommended)
#   GIT_REPO="git@github.com:pbs-tech/homelab.git" ./install-from-git.sh
#
#   # Private repo (PAT)
#   GITHUB_TOKEN="ghp_your_token" ./install-from-git.sh
#
#   # Custom version
#   GIT_VERSION="v1.0.0" ./install-from-git.sh
#
# For more details, see: docs/PRIVATE_REPO_ACCESS.md

set -e

# Check for required commands
if ! command -v ansible-galaxy &> /dev/null; then
    echo "ERROR: ansible-galaxy not found"
    echo "Please install Ansible: pip install ansible-core"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "ERROR: git not found"
    echo "Please install Git: sudo apt-get install git"
    exit 1
fi

# Default to public HTTPS URL
GIT_REPO="${GIT_REPO:-https://github.com/pbs-tech/homelab.git}"
GIT_VERSION="${GIT_VERSION:-main}"

# If GITHUB_TOKEN is set, use it for HTTPS authentication
if [ -n "$GITHUB_TOKEN" ]; then
    # Only modify HTTPS URLs, not SSH URLs
    if [[ "$GIT_REPO" == https://* ]]; then
        # Check if token is already in URL
        if [[ "$GIT_REPO" != *@* ]]; then
            # Extract domain and path
            REPO_URL="${GIT_REPO#https://}"
            GIT_REPO="https://${GITHUB_TOKEN}@${REPO_URL}"
            echo "Using GITHUB_TOKEN for authentication"
        fi
    fi
fi

# Determine authentication method
AUTH_METHOD="public"
if [[ "$GIT_REPO" == git@* ]]; then
    AUTH_METHOD="SSH"
elif [[ "$GIT_REPO" == *@github.com* ]]; then
    AUTH_METHOD="PAT (HTTPS)"
fi

echo "Installing homelab collections from Git..."
echo "Repository: ${GIT_REPO%%@*}@****"  # Mask credentials in output
echo "Version: $GIT_VERSION"
echo "Authentication: $AUTH_METHOD"
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
