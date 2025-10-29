#!/bin/bash
# Build all homelab collections

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$REPO_ROOT/build/collections"

# Check for ansible-galaxy
if ! command -v ansible-galaxy &> /dev/null; then
    echo "ERROR: ansible-galaxy not found"
    echo "Please install Ansible: pip install ansible-core"
    exit 1
fi

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
