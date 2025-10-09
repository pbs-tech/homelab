#!/bin/bash
# Documentation validation script

set -e

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_ROOT"

echo "=== Documentation Validation ==="
echo "Repository root: $REPO_ROOT"
echo

# Function to check if file exists
check_file() {
    local file=$1
    local description=$2

    if [[ -f "$file" ]]; then
        echo "✓ $description: $file"
        return 0
    else
        echo "✗ $description: $file (MISSING)"
        return 1
    fi
}

# Function to check if directory exists
check_dir() {
    local dir=$1
    local description=$2

    if [[ -d "$dir" ]]; then
        echo "✓ $description: $dir"
        return 0
    else
        echo "✗ $description: $dir (MISSING)"
        return 1
    fi
}

echo "Checking core documentation files..."
errors=0

# Core documentation files
check_file "README.md" "Main README" || ((errors++))
check_file "INSTALLATION.md" "Installation Guide" || ((errors++))
check_file "CLAUDE.md" "Repository Guidance" || ((errors++))
check_file "API.md" "API Documentation" || ((errors++))
check_file "TESTING.md" "Testing Guide" || ((errors++))
check_file "TROUBLESHOOTING.md" "Troubleshooting Guide" || ((errors++))
check_file "SECURITY-ARCHITECTURE.md" "Security Architecture" || ((errors++))
check_file "MOLECULE_TESTING.md" "Molecule Testing" || ((errors++))
check_file "CLIENT-VPN-SETUP.md" "VPN Setup Guide" || ((errors++))
check_file "DEVOPS_ASSESSMENT.md" "DevOps Assessment" || ((errors++))
check_file ".github/SECURITY.md" "Security Policy" || ((errors++))

echo
echo "Checking collection documentation..."

# Collection documentation
check_dir "ansible_collections/homelab/common" "Common Collection" || ((errors++))
check_file "ansible_collections/homelab/common/README.md" "Common Collection README" || ((errors++))
check_file "ansible_collections/homelab/common/galaxy.yml" "Common Collection Metadata" || ((errors++))

check_dir "ansible_collections/homelab/k3s" "K3s Collection" || ((errors++))
check_file "ansible_collections/homelab/k3s/README.md" "K3s Collection README" || ((errors++))
check_file "ansible_collections/homelab/k3s/galaxy.yml" "K3s Collection Metadata" || ((errors++))

check_dir "ansible_collections/homelab/proxmox_lxc" "Proxmox LXC Collection" || ((errors++))
check_file "ansible_collections/homelab/proxmox_lxc/README.md" "Proxmox LXC Collection README" || ((errors++))
check_file "ansible_collections/homelab/proxmox_lxc/galaxy.yml" "Proxmox LXC Collection Metadata" || ((errors++))

echo
echo "Checking role documentation..."

# Key role documentation
check_file "ansible_collections/homelab/proxmox_lxc/roles/traefik/README.md" "Traefik Role README" || ((errors++))
check_file "ansible_collections/homelab/common/roles/security_hardening/README.md" "Security Hardening Role README" || ((errors++))

echo
echo "Checking specialized documentation..."

# Specialized documentation
check_file "ansible_collections/homelab/proxmox_lxc/DYNAMIC_INVENTORY_SETUP.md" "Dynamic Inventory Setup" || ((errors++))

echo
echo "Checking playbook structure..."

# Playbook structure
check_dir "playbooks" "Playbooks Directory" || ((errors++))
check_file "playbooks/infrastructure.yml" "Main Infrastructure Playbook" || ((errors++))
check_file "playbooks/foundation.yml" "Foundation Playbook" || ((errors++))
check_file "playbooks/networking.yml" "Networking Playbook" || ((errors++))
check_file "playbooks/monitoring.yml" "Monitoring Playbook" || ((errors++))
check_file "playbooks/applications.yml" "Applications Playbook" || ((errors++))

echo
echo "Checking configuration files..."

# Configuration files
check_file "requirements.yml" "Requirements File" || ((errors++))
check_file "Makefile" "Makefile" || ((errors++))
check_file ".markdownlint.yaml" "Markdown Linting Config" || ((errors++))
check_file ".pre-commit-config.yaml" "Pre-commit Config" || ((errors++))

echo
echo "Validating README links..."

# Check for common broken link patterns in README.md
if [[ -f "README.md" ]]; then
    # Extract markdown links and check if files exist
    grep -o '\[.*\]([^)]*\.md)' README.md | while IFS= read -r link; do
        file=$(echo "$link" | sed 's/.*(\(.*\))/\1/')
        if [[ ! -f "$file" ]]; then
            echo "✗ Broken link in README.md: $file"
            ((errors++))
        else
            echo "✓ Valid link: $file"
        fi
    done
fi

echo
echo "Checking galaxy.yml metadata..."

# Validate galaxy.yml files have required fields
for galaxy_file in ansible_collections/homelab/*/galaxy.yml; do
    if [[ -f "$galaxy_file" ]]; then
        collection_name=$(dirname "$galaxy_file" | xargs basename)
        echo "Validating $collection_name galaxy.yml..."

        # Check required fields
        required_fields=("namespace" "name" "version" "description" "authors")
        for field in "${required_fields[@]}"; do
            if grep -q "^$field:" "$galaxy_file"; then
                echo "  ✓ $field field present"
            else
                echo "  ✗ $field field missing"
                ((errors++))
            fi
        done
    fi
done

echo
echo "Checking for TODO/FIXME comments in documentation..."

# Check for unresolved TODOs in documentation
todo_count=$(find . -name "*.md" -exec grep -l -E "(TODO|FIXME|XXX)" {} \; | wc -l)
if [[ $todo_count -gt 0 ]]; then
    echo "⚠ Found $todo_count documentation files with TODO/FIXME comments:"
    find . -name "*.md" -exec grep -H -E "(TODO|FIXME|XXX)" {} \;
else
    echo "✓ No TODO/FIXME comments found in documentation"
fi

echo
echo "Checking documentation file sizes..."

# Check for overly large documentation files (>50KB)
large_docs=$(find . -name "*.md" -size +50k)
if [[ -n "$large_docs" ]]; then
    echo "⚠ Large documentation files (>50KB) that might need splitting:"
    echo "$large_docs" | while read -r file; do
        size=$(du -h "$file" | cut -f1)
        echo "  $file ($size)"
    done
else
    echo "✓ All documentation files are reasonably sized"
fi

echo
echo "=== Validation Summary ==="

if [[ $errors -eq 0 ]]; then
    echo "✅ All documentation checks passed!"
    echo "📚 Documentation appears to be comprehensive and well-structured."
else
    echo "❌ Found $errors documentation issues."
    echo "📝 Please review and fix the issues listed above."
fi

echo
echo "Documentation metrics:"
echo "- Total .md files: $(find . -name "*.md" | wc -l)"
echo "- Collection READMEs: $(find ansible_collections -name "README.md" | wc -l)"
echo "- Role READMEs: $(find ansible_collections -path "*/roles/*/README.md" | wc -l)"
echo "- Total documentation size: $(du -sh . --include="*.md" 2>/dev/null | cut -f1 || echo "N/A")"

exit $errors
