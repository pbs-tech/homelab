#!/bin/bash
# Test collection installation from multiple sources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Testing collection installation methods..."
echo "=========================================="

# Test 1: Local build and install
echo ""
echo "Test 1: Local build and install"
"$SCRIPT_DIR/build-all-collections.sh"
ansible-galaxy collection install "$SCRIPT_DIR/../build/collections"/*.tar.gz --force
ansible-galaxy collection list | grep homelab

# Test 2: Git installation
echo ""
echo "Test 2: Git-based installation"
"$SCRIPT_DIR/install-from-git.sh"

echo ""
echo "✓ All tests passed!"
