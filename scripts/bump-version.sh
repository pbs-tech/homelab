#!/bin/bash
# Bump version for all homelab collections
# Usage: ./scripts/bump-version.sh [major|minor|patch] [new_version]
#
# Examples:
#   ./scripts/bump-version.sh 1.1.0        # Set specific version
#   ./scripts/bump-version.sh minor        # Auto-increment minor version

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Collection paths
COMMON_GALAXY="ansible_collections/homelab/common/galaxy.yml"
K3S_GALAXY="ansible_collections/homelab/k3s/galaxy.yml"
PROXMOX_GALAXY="ansible_collections/homelab/proxmox_lxc/galaxy.yml"

# Function to get current version from a galaxy.yml file
get_current_version() {
    local file=$1
    grep "^version:" "$file" | awk '{print $2}' | tr -d '"'
}

# Function to set version in a galaxy.yml file
set_version() {
    local file=$1
    local new_version=$2

    # Use sed to replace version
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version:.*/version: $new_version/" "$file"
    else
        # Linux
        sed -i "s/^version:.*/version: $new_version/" "$file"
    fi
}

# Function to increment version
increment_version() {
    local version=$1
    local part=$2

    IFS='.' read -r -a parts <<< "$version"
    local major="${parts[0]}"
    local minor="${parts[1]}"
    local patch="${parts[2]}"

    case $part in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}Error: Invalid version part '$part'. Use major, minor, or patch.${NC}"
            exit 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Function to validate semantic version format
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid version format '$version'. Must be X.Y.Z${NC}"
        exit 1
    fi
}

# Main script
echo -e "${GREEN}Homelab Collections Version Bumper${NC}"
echo "===================================="
echo

# Check if we're in the right directory and all galaxy.yml files exist
if [[ ! -f "$COMMON_GALAXY" ]]; then
    echo -e "${RED}Error: Must be run from repository root${NC}"
    echo "Could not find: $COMMON_GALAXY"
    exit 1
fi

# Validate all required galaxy.yml files exist
MISSING_FILES=()
for file in "$COMMON_GALAXY" "$K3S_GALAXY" "$PROXMOX_GALAXY"; do
    if [[ ! -f "$file" ]]; then
        MISSING_FILES+=("$file")
    fi
done

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required galaxy.yml files:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
    echo
    echo "Expected collection structure:"
    echo "  ansible_collections/homelab/common/galaxy.yml"
    echo "  ansible_collections/homelab/k3s/galaxy.yml"
    echo "  ansible_collections/homelab/proxmox_lxc/galaxy.yml"
    exit 1
fi

# Verify all files are writable
READONLY_FILES=()
for file in "$COMMON_GALAXY" "$K3S_GALAXY" "$PROXMOX_GALAXY"; do
    if [[ ! -w "$file" ]]; then
        READONLY_FILES+=("$file")
    fi
done

if [[ ${#READONLY_FILES[@]} -gt 0 ]]; then
    echo -e "${RED}Error: The following files are not writable:${NC}"
    for file in "${READONLY_FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

# Get current versions from all collections
COMMON_VERSION=$(get_current_version "$COMMON_GALAXY")
K3S_VERSION=$(get_current_version "$K3S_GALAXY")
PROXMOX_VERSION=$(get_current_version "$PROXMOX_GALAXY")

# Display current versions
echo "Current versions:"
echo -e "  homelab.common:       ${YELLOW}$COMMON_VERSION${NC}"
echo -e "  homelab.k3s:          ${YELLOW}$K3S_VERSION${NC}"
echo -e "  homelab.proxmox_lxc:  ${YELLOW}$PROXMOX_VERSION${NC}"
echo

# Verify all collections have the same version
if [[ "$COMMON_VERSION" != "$K3S_VERSION" ]] || [[ "$COMMON_VERSION" != "$PROXMOX_VERSION" ]]; then
    echo -e "${RED}Error: Version mismatch detected!${NC}"
    echo "All collections must have the same version before bumping."
    echo
    echo "Please manually synchronize the versions first, or use --force to proceed anyway."
    echo "Example: $0 $COMMON_VERSION --force"
    exit 1
fi

CURRENT_VERSION="$COMMON_VERSION"
echo

# Determine new version
if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 [major|minor|patch|X.Y.Z]"
    echo
    echo "Examples:"
    echo "  $0 1.1.0        # Set specific version"
    echo "  $0 minor        # Auto-increment minor version"
    echo "  $0 patch        # Auto-increment patch version"
    echo "  $0 major        # Auto-increment major version"
    exit 1
fi

NEW_VERSION=""
case ${1:-} in
    major|minor|patch)
        NEW_VERSION=$(increment_version "$CURRENT_VERSION" "${1:-}")
        ;;
    *)
        NEW_VERSION=${1:-}
        validate_version "$NEW_VERSION"
        ;;
esac

echo -e "New version: ${GREEN}$NEW_VERSION${NC}"
echo

# Confirm with user
read -p "Update all collections to version $NEW_VERSION? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Update all galaxy.yml files
echo "Updating collection versions..."
set_version "$COMMON_GALAXY" "$NEW_VERSION"
echo -e "  ${GREEN}✓${NC} homelab.common → $NEW_VERSION"

set_version "$K3S_GALAXY" "$NEW_VERSION"
echo -e "  ${GREEN}✓${NC} homelab.k3s → $NEW_VERSION"

set_version "$PROXMOX_GALAXY" "$NEW_VERSION"
echo -e "  ${GREEN}✓${NC} homelab.proxmox_lxc → $NEW_VERSION"

echo
echo -e "${GREEN}Version bump complete!${NC}"
echo
echo "Next steps:"
echo "1. Update CHANGELOG.md with release notes"
echo "2. Review changes: git diff"
echo "3. Commit: git commit -am 'Bump version to $NEW_VERSION'"
echo "4. Create tag: git tag -a v$NEW_VERSION -m 'Release version $NEW_VERSION'"
echo "5. Push: git push origin main --tags"
echo "6. Create GitHub release: gh release create v$NEW_VERSION"
echo
echo "See RELEASING.md for detailed release instructions."
