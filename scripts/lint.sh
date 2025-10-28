#!/bin/bash
set -euo pipefail

# Homelab Linting Script
# Runs all linting tools locally for development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install dependencies if needed
install_dependencies() {
    log_info "Checking dependencies..."

    local missing_deps=()

    if ! command_exists yamllint; then
        missing_deps+=("yamllint")
    fi

    if ! command_exists ansible-lint; then
        missing_deps+=("ansible-lint")
    fi

    if ! command_exists pymarkdown; then
        missing_deps+=("pymarkdownlnt")
    fi

    if ! command_exists shellcheck; then
        missing_deps+=("shellcheck")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        log_info "Installing missing dependencies..."

        # Try to install with pip
        if command_exists pip; then
            for dep in "${missing_deps[@]}"; do
                        pip install "$dep";
            done
        else
            log_error "pip not found. Please install Python and pip first."
            return 1
        fi
    fi
}

# Run yamllint
run_yamllint() {
    log_info "Running yamllint..."

    if yamllint . --format parsable; then
        log_success "yamllint passed"
        return 0
    else
        log_error "yamllint failed"
        return 1
    fi
}

# Run ansible-lint
run_ansible_lint() {
    log_info "Running ansible-lint..."

    # Check if Ansible collections are installed
    if [ ! -d "${HOME}/.ansible/collections" ] && [ ! -d "collections" ]; then
        log_warning "Ansible collections not found. Installing..."
        ansible-galaxy collection install -r requirements.yml
    fi

    if ansible-lint; then
        log_success "ansible-lint passed"
        return 0
    else
        log_error "ansible-lint failed"
        return 1
    fi
}

# Run pymarkdownlnt
run_markdownlint() {
    log_info "Running pymarkdownlnt..."

    if pymarkdown --config .markdownlint.yaml scan .; then
        log_success "pymarkdownlnt passed"
        return 0
    else
        log_error "pymarkdownlnt failed"
        return 1
    fi
}

# Run shellcheck
run_shellcheck() {
    log_info "Running shellcheck..."

    # Find all shell scripts and check them
    local shell_files
    shell_files=$(find . -type f -name "*.sh" \
        -not -path "*/venv/*" \
        -not -path "*/.venv/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*")

    if [ -z "$shell_files" ]; then
        log_warning "No shell scripts found to check"
        return 0
    fi

    # shellcheck disable=SC2086
    if echo "$shell_files" | xargs shellcheck --severity=warning; then
        log_success "shellcheck passed"
        return 0
    else
        log_error "shellcheck failed"
        return 1
    fi
}

# Main function
main() {
    cd "$PROJECT_ROOT"

    log_info "Starting linting process in $PROJECT_ROOT"

    local failed_checks=()

    # Parse command line arguments
    local run_yamllint=true
    local run_ansible=true
    local run_markdown=true
    local run_shellcheck=true
    local install_deps=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --yaml-only)
                run_ansible=false
                run_markdown=false
                run_shellcheck=false
                shift
                ;;
            --ansible-only)
                run_yamllint=false
                run_markdown=false
                run_shellcheck=false
                shift
                ;;
            --markdown-only)
                run_yamllint=false
                run_ansible=false
                run_shellcheck=false
                shift
                ;;
            --shellcheck-only)
                run_yamllint=false
                run_ansible=false
                run_markdown=false
                shift
                ;;
            --install-deps)
                install_deps=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --yaml-only      Run only yamllint"
                echo "  --ansible-only   Run only ansible-lint"
                echo "  --markdown-only  Run only pymarkdownlnt"
                echo "  --shellcheck-only Run only shellcheck"
                echo "  --install-deps   Install missing dependencies"
                echo "  --help           Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Install dependencies if requested
    if $install_deps; then
        install_dependencies || exit 1
    fi

    # Run linters
    if $run_yamllint; then
        run_yamllint || failed_checks+=("yamllint")
    fi

    if $run_ansible; then
        run_ansible_lint || failed_checks+=("ansible-lint")
    fi

    if $run_markdown; then
        run_markdownlint || failed_checks+=("markdownlint")
    fi

    if $run_shellcheck; then
        run_shellcheck || failed_checks+=("shellcheck")
    fi

    # Summary
    echo
    log_info "Linting Summary"
    echo "==============="

    if [ ${#failed_checks[@]} -eq 0 ]; then
        log_success "All linting checks passed! ✅"
        exit 0
    else
        log_error "The following linting checks failed: ${failed_checks[*]} ❌"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
