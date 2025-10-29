#!/bin/bash
# Install homelab collections from Git

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
