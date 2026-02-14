# Homelab Infrastructure Makefile
# Provides common development and deployment tasks

.DEFAULT_GOAL := help
.PHONY: help install install-dev lint lint-yaml lint-ansible lint-markdown lint-fix test test-quick test-infrastructure test-security test-services test-api test-molecule test-molecule-smoke test-molecule-all test-molecule-common test-molecule-common-roles test-molecule-k3s test-molecule-k3s-pi test-molecule-proxmox test-molecule-proxmox-integration molecule-converge molecule-converge-smoke molecule-converge-common molecule-converge-k3s molecule-converge-proxmox molecule-verify molecule-verify-common molecule-verify-k3s molecule-verify-proxmox molecule-destroy molecule-reset deploy deploy-phase1 deploy-phase2 deploy-security deploy-enclave deploy-enclave-persistent deploy-phase6 enclave-status enclave-shutdown validate clean security-scan docs performance drift-check release monitor backup restore status ci-status

# Colors for output
YELLOW := \033[1;33m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m # No Color

# Default Python and Ansible versions (aligned with CI/CD pipeline)
PYTHON_VERSION ?= 3.12
ANSIBLE_CORE_VERSION ?= 2.17

# Collection paths
COLLECTIONS_PATH := ansible_collections/homelab
COMMON_PATH := $(COLLECTIONS_PATH)/common
K3S_PATH := $(COLLECTIONS_PATH)/k3s
PROXMOX_PATH := $(COLLECTIONS_PATH)/proxmox_lxc

help: ## Show this help message
	@echo "$(YELLOW)Homelab Infrastructure Management$(NC)"
	@echo "=================================="
	@echo
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  $(GREEN)%-30s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies and collections
	@echo "$(YELLOW)Installing Python dependencies...$(NC)"
	python -m pip install --upgrade pip
	pip install -r requirements.txt
	@echo "$(YELLOW)Installing Ansible collections...$(NC)"
	ansible-galaxy collection install -r requirements.yml --force
	find ansible_collections/ -name "requirements.yml" -exec ansible-galaxy collection install -r {} --force \;
	@echo "$(GREEN)Dependencies installed successfully!$(NC)"

install-dev: install ## Install development dependencies and setup pre-commit
	@echo "$(YELLOW)Setting up development environment...$(NC)"
	pre-commit install
	@echo "$(YELLOW)Installing Molecule test dependencies...$(NC)"
	pip install "molecule>=6.0" "molecule-plugins[docker]>=23.5.0"
	@echo "$(GREEN)Development environment ready!$(NC)"

lint: ## Run all linting checks
	@echo "$(YELLOW)Running all linting checks...$(NC)"
	@./scripts/lint.sh

lint-yaml: ## Run YAML linting only
	@echo "$(YELLOW)Running YAML linting...$(NC)"
	@./scripts/lint.sh --yaml-only

lint-ansible: ## Run Ansible linting only
	@echo "$(YELLOW)Running Ansible linting...$(NC)"
	@./scripts/lint.sh --ansible-only

lint-markdown: ## Run Markdown linting with pymarkdownlnt
	@echo "$(YELLOW)Running Markdown linting with pymarkdownlnt...$(NC)"
	@./scripts/lint.sh --markdown-only

lint-shellcheck: ## Run shellcheck on shell scripts
	@echo "$(YELLOW)Running shellcheck on shell scripts...$(NC)"
	@./scripts/lint.sh --shellcheck-only

lint-fix: ## Attempt to auto-fix linting issues where possible
	@echo "$(YELLOW)Auto-fixing linting issues...$(NC)"
	yamllint . --format parsable | head -20 || true
	@echo "$(YELLOW)Note: Some issues may need manual fixing$(NC)"

# ============================================
# Testing Targets
# ============================================

test: ## Run all validation tests
	@echo "$(YELLOW)Running full validation test suite...$(NC)"
	@echo "$(YELLOW)Test 1/4: Quick smoke test$(NC)"
	@ansible-playbook tests/quick-smoke-test.yml
	@echo "$(YELLOW)Test 2/4: Infrastructure validation$(NC)"
	@ansible-playbook tests/validate-infrastructure.yml
	@echo "$(YELLOW)Test 3/4: Security validation$(NC)"
	@ansible-playbook tests/validate-security.yml
	@echo "$(YELLOW)Test 4/4: Service validation$(NC)"
	@ansible-playbook tests/validate-services.yml
	@echo "$(GREEN)All validation tests completed!$(NC)"

test-quick: ## Run quick smoke tests (< 2 min)
	@echo "$(YELLOW)Running quick smoke tests...$(NC)"
	@ansible-playbook tests/quick-smoke-test.yml

test-infrastructure: ## Validate infrastructure health
	@echo "$(YELLOW)Validating infrastructure health...$(NC)"
	@ansible-playbook tests/validate-infrastructure.yml

test-security: ## Validate security configuration
	@echo "$(YELLOW)Running security validation tests...$(NC)"
	@ansible-playbook tests/validate-security.yml

test-services: ## Validate service functionality
	@echo "$(YELLOW)Running service validation tests...$(NC)"
	@ansible-playbook tests/validate-services.yml

test-enclave: ## Validate secure enclave (network isolation, security)
	@echo "$(YELLOW)Running secure enclave validation tests...$(NC)"
	@ansible-playbook tests/validate-enclave.yml

test-api: ## Validate Proxmox API authentication
	@echo "$(YELLOW)Testing Proxmox API token authentication...$(NC)"
	@ansible-playbook test-proxmox-api-tokens.yml

# ============================================
# Molecule Testing Targets
# ============================================

test-molecule: ## Run Molecule tests for all collections (default scenarios)
	@echo "$(YELLOW)Running Molecule tests for all collections (default scenarios)...$(NC)"
	@echo "$(YELLOW)Testing common collection...$(NC)"
	@cd $(COMMON_PATH) && molecule test -s default || { echo "$(RED)Common collection tests failed!$(NC)"; exit 1; }
	@echo "$(YELLOW)Testing k3s collection...$(NC)"
	@cd $(K3S_PATH) && molecule test -s default || { echo "$(RED)K3s collection tests failed!$(NC)"; exit 1; }
	@echo "$(YELLOW)Testing proxmox_lxc collection...$(NC)"
	@cd $(PROXMOX_PATH) && molecule test -s default || { echo "$(RED)Proxmox LXC collection tests failed!$(NC)"; exit 1; }
	@echo "$(GREEN)All Molecule tests passed!$(NC)"

test-molecule-smoke: ## Run fast smoke test for ALL roles across all collections
	@echo "$(YELLOW)Running Molecule smoke test for all roles...$(NC)"
	@echo "$(YELLOW)This is a fast syntax and basic validation test (< 5 min)$(NC)"
	@molecule test -s smoke || { echo "$(RED)Smoke test failed!$(NC)"; exit 1; }
	@echo "$(GREEN)Smoke test passed!$(NC)"

test-molecule-all: ## Run ALL Molecule scenarios (including real infrastructure)
	@echo "$(YELLOW)Running ALL Molecule scenarios (including real infrastructure)...$(NC)"
	@echo "$(YELLOW)Testing common collection - default scenario...$(NC)"
	@cd $(COMMON_PATH) && molecule test -s default || { echo "$(RED)Common default scenario failed!$(NC)"; exit 1; }
	@echo "$(YELLOW)Testing common collection - common-roles scenario...$(NC)"
	@cd $(COMMON_PATH) && molecule test -s common-roles || { echo "$(RED)Common roles scenario failed!$(NC)"; exit 1; }
	@echo "$(YELLOW)Testing k3s collection - default scenario...$(NC)"
	@cd $(K3S_PATH) && molecule test -s default || { echo "$(RED)K3s default scenario failed!$(NC)"; exit 1; }
	@echo "$(YELLOW)Testing k3s collection - raspberry-pi scenario...$(NC)"
	@cd $(K3S_PATH) && molecule test -s raspberry-pi || { echo "$(RED)K3s raspberry-pi scenario failed!$(NC)"; exit 1; }
	@echo "$(YELLOW)Testing proxmox_lxc collection - default scenario...$(NC)"
	@cd $(PROXMOX_PATH) && molecule test -s default || { echo "$(RED)Proxmox LXC default scenario failed!$(NC)"; exit 1; }
	@echo "$(YELLOW)Testing proxmox_lxc collection - proxmox-integration scenario...$(NC)"
	@cd $(PROXMOX_PATH) && molecule test -s proxmox-integration || { echo "$(RED)Proxmox integration scenario failed!$(NC)"; exit 1; }
	@echo "$(GREEN)All Molecule scenarios passed!$(NC)"

test-molecule-common: ## Run Molecule tests for common collection
	@echo "$(YELLOW)Running Molecule tests for common collection...$(NC)"
	@cd $(COMMON_PATH) && molecule test -s default
	@echo "$(GREEN)Common collection tests passed!$(NC)"

test-molecule-common-roles: ## Run Molecule tests for common-roles scenario
	@echo "$(YELLOW)Running Molecule tests for common-roles scenario...$(NC)"
	@cd $(COMMON_PATH) && molecule test -s common-roles
	@echo "$(GREEN)Common roles scenario passed!$(NC)"

test-molecule-k3s: ## Run Molecule tests for k3s collection
	@echo "$(YELLOW)Running Molecule tests for k3s collection...$(NC)"
	@cd $(K3S_PATH) && molecule test -s default
	@echo "$(GREEN)K3s collection tests passed!$(NC)"

test-molecule-k3s-pi: ## Run Molecule tests for k3s raspberry-pi scenario
	@echo "$(YELLOW)Running Molecule tests for k3s raspberry-pi scenario...$(NC)"
	@cd $(K3S_PATH) && molecule test -s raspberry-pi
	@echo "$(GREEN)K3s raspberry-pi scenario passed!$(NC)"

test-molecule-proxmox: ## Run Molecule tests for proxmox_lxc collection
	@echo "$(YELLOW)Running Molecule tests for proxmox_lxc collection...$(NC)"
	@cd $(PROXMOX_PATH) && molecule test -s default
	@echo "$(GREEN)Proxmox LXC collection tests passed!$(NC)"

test-molecule-proxmox-integration: ## Run Molecule tests for proxmox-integration scenario
	@echo "$(YELLOW)Running Molecule tests for proxmox-integration scenario...$(NC)"
	@cd $(PROXMOX_PATH) && molecule test -s proxmox-integration
	@echo "$(GREEN)Proxmox integration scenario passed!$(NC)"

# ============================================
# Molecule Converge Targets (for debugging)
# ============================================

molecule-converge: ## Run converge on all collections (no destroy)
	@echo "$(YELLOW)Running converge for all collections...$(NC)"
	@echo "$(YELLOW)Converging common collection...$(NC)"
	@cd $(COMMON_PATH) && molecule converge -s default
	@echo "$(YELLOW)Converging k3s collection...$(NC)"
	@cd $(K3S_PATH) && molecule converge -s default
	@echo "$(YELLOW)Converging proxmox_lxc collection...$(NC)"
	@cd $(PROXMOX_PATH) && molecule converge -s default
	@echo "$(GREEN)All converge operations completed!$(NC)"

molecule-converge-smoke: ## Run converge for smoke test scenario
	@echo "$(YELLOW)Running converge for smoke test...$(NC)"
	@molecule converge -s smoke

molecule-converge-common: ## Run converge for common collection
	@echo "$(YELLOW)Running converge for common collection...$(NC)"
	@cd $(COMMON_PATH) && molecule converge -s default

molecule-converge-k3s: ## Run converge for k3s collection
	@echo "$(YELLOW)Running converge for k3s collection...$(NC)"
	@cd $(K3S_PATH) && molecule converge -s default

molecule-converge-proxmox: ## Run converge for proxmox_lxc collection
	@echo "$(YELLOW)Running converge for proxmox_lxc collection...$(NC)"
	@cd $(PROXMOX_PATH) && molecule converge -s default

# ============================================
# Molecule Verify Targets
# ============================================

molecule-verify: ## Run verify for all collections
	@echo "$(YELLOW)Running verify for all collections...$(NC)"
	@cd $(COMMON_PATH) && molecule verify -s default
	@cd $(K3S_PATH) && molecule verify -s default
	@cd $(PROXMOX_PATH) && molecule verify -s default
	@echo "$(GREEN)All verify operations completed!$(NC)"

molecule-verify-common: ## Run verify for common collection
	@echo "$(YELLOW)Running verify for common collection...$(NC)"
	@cd $(COMMON_PATH) && molecule verify -s default

molecule-verify-k3s: ## Run verify for k3s collection
	@echo "$(YELLOW)Running verify for k3s collection...$(NC)"
	@cd $(K3S_PATH) && molecule verify -s default

molecule-verify-proxmox: ## Run verify for proxmox_lxc collection
	@echo "$(YELLOW)Running verify for proxmox_lxc collection...$(NC)"
	@cd $(PROXMOX_PATH) && molecule verify -s default

# ============================================
# Molecule Cleanup Targets
# ============================================

molecule-destroy: ## Destroy all Molecule test instances
	@echo "$(YELLOW)Destroying all Molecule test instances...$(NC)"
	@molecule destroy -s smoke || true
	@cd $(COMMON_PATH) && molecule destroy -s default || true
	@cd $(COMMON_PATH) && molecule destroy -s common-roles || true
	@cd $(K3S_PATH) && molecule destroy -s default || true
	@cd $(K3S_PATH) && molecule destroy -s raspberry-pi || true
	@cd $(PROXMOX_PATH) && molecule destroy -s default || true
	@cd $(PROXMOX_PATH) && molecule destroy -s proxmox-integration || true
	@echo "$(GREEN)All Molecule instances destroyed!$(NC)"

molecule-reset: ## Reset Molecule test instances (destroy + create)
	@echo "$(YELLOW)Resetting all Molecule test instances...$(NC)"
	@$(MAKE) molecule-destroy
	@echo "$(YELLOW)Creating fresh instances...$(NC)"
	@cd $(COMMON_PATH) && molecule create -s default
	@cd $(K3S_PATH) && molecule create -s default
	@cd $(PROXMOX_PATH) && molecule create -s default
	@echo "$(GREEN)All Molecule instances reset!$(NC)"

# ============================================
# Deployment Targets
# ============================================

deploy: lint ## Deploy infrastructure (with linting check first)
	@echo "$(YELLOW)Deploying infrastructure...$(NC)"
	ansible-playbook playbooks/infrastructure.yml

deploy-phase1: lint ## Deploy Phase 1 (Foundation)
	@echo "$(YELLOW)Deploying Phase 1: Foundation...$(NC)"
	ansible-playbook playbooks/infrastructure.yml --tags "foundation,phase1"

deploy-phase2: lint ## Deploy Phase 2 (Networking)
	@echo "$(YELLOW)Deploying Phase 2: Networking...$(NC)"
	ansible-playbook playbooks/infrastructure.yml --tags "networking,phase2"

deploy-security: lint ## Deploy security-focused configuration
	@echo "$(YELLOW)Deploying security configuration...$(NC)"
	ansible-playbook security-deploy.yml

# ============================================
# Secure Enclave Targets
# ============================================

deploy-enclave: lint ## Deploy secure enclave (temporary mode - auto-shutdown enabled)
	@echo "$(YELLOW)Deploying Secure Enclave (temporary mode)...$(NC)"
	@echo "$(RED)WARNING: This deploys intentionally vulnerable systems$(NC)"
	ansible-playbook playbooks/enclave.yml -e enclave_security_acknowledged=true

deploy-enclave-persistent: lint ## Deploy secure enclave (persistent mode - runs continuously)
	@echo "$(YELLOW)Deploying Secure Enclave (persistent mode)...$(NC)"
	@echo "$(RED)WARNING: This deploys intentionally vulnerable systems that auto-start on boot$(NC)"
	ansible-playbook playbooks/enclave.yml \
		-e enclave_security_acknowledged=true \
		-e enclave_persistent_mode=true

deploy-phase6: deploy-enclave-persistent ## Deploy Phase 6 (Secure Enclave - persistent)

enclave-status: ## Show secure enclave status
	@echo "$(YELLOW)Secure Enclave Status$(NC)"
	@echo "====================="
	@ssh -o ConnectTimeout=3 pbs@192.168.0.250 'enclave-status' 2>/dev/null || echo "$(RED)Enclave bastion not reachable$(NC)"

enclave-shutdown: ## Emergency shutdown of all enclave VMs
	@echo "$(YELLOW)Shutting down all enclave VMs...$(NC)"
	@ssh -o ConnectTimeout=3 pbs@192.168.0.250 'enclave-shutdown' 2>/dev/null || echo "$(RED)Enclave bastion not reachable$(NC)"

update-systems: ## Update all systems (Raspberry Pis and LXC containers)
	@echo "$(YELLOW)Updating all systems...$(NC)"
	ansible-playbook playbooks/update-systems.yml

update-pi: ## Update Raspberry Pi nodes only (rolling, one at a time)
	@echo "$(YELLOW)Updating Raspberry Pi nodes...$(NC)"
	ansible-playbook playbooks/update-systems.yml --tags pi

update-lxc: ## Update LXC containers only
	@echo "$(YELLOW)Updating LXC containers...$(NC)"
	ansible-playbook playbooks/update-systems.yml --tags lxc

restart-k3s-pods: ## Restart all K3s deployments (use TARGET_NS=x or TARGET_DEPLOY=x to filter)
	@echo "$(YELLOW)Restarting K3s deployments...$(NC)"
	ansible-playbook playbooks/restart-k3s-pods.yml \
		$(if $(TARGET_NS),-e target_namespace=$(TARGET_NS)) \
		$(if $(TARGET_DEPLOY),-e target_deployment=$(TARGET_DEPLOY))

validate: lint test ## Run full validation (lint + test)
	@echo "$(GREEN)Full validation completed successfully!$(NC)"

clean: ## Clean up temporary files and caches
	@echo "$(YELLOW)Cleaning up...$(NC)"
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name ".pytest_cache" -type d -exec rm -rf {} + 2>/dev/null || true
	rm -rf .cache/ .molecule/ .ansible/
	@echo "$(GREEN)Cleanup completed!$(NC)"

security-scan: ## Run security scans
	@echo "$(YELLOW)Running security scans...$(NC)"
	@if command -v detect-secrets >/dev/null 2>&1; then \
		detect-secrets scan --baseline .secrets.baseline; \
	else \
		echo "$(RED)detect-secrets not installed. Run: pip install detect-secrets$(NC)"; \
	fi

docs: ## Generate documentation
	@echo "$(YELLOW)Generating documentation...$(NC)"
	@echo "$(YELLOW)Documentation is maintained in markdown files$(NC)"
	@echo "See: README.md, CLAUDE.md, TESTING.md, and collection-specific docs"
	@echo ""
	@echo "$(YELLOW)Available documentation:$(NC)"
	@find . -name "*.md" -not -path "./.git/*" | sed 's/^/  - /'

performance: ## Run performance tests locally
	@echo "$(YELLOW)Running performance tests...$(NC)"
	@mkdir -p tests/performance/results
	@ansible-playbook tests/performance/local_performance_test.yml

drift-check: ## Check for configuration drift
	@echo "$(YELLOW)Checking for configuration drift...$(NC)"
	@ansible-playbook playbooks/infrastructure.yml --check --diff

release: lint test ## Prepare a release (run tests and linting first)
	@echo "$(YELLOW)Preparing release...$(NC)"
	@echo "Current version in galaxy.yml files:"
	@grep "version:" ansible_collections/homelab/*/galaxy.yml
	@echo "$(GREEN)Ready for release! Create a git tag to trigger release workflow.$(NC)"

monitor: ## Display monitoring dashboard URLs
	@echo "$(YELLOW)Monitoring Dashboard URLs$(NC)"
	@echo "========================="
	@echo "Prometheus: http://192.168.0.200:9090"
	@echo "Grafana: http://192.168.0.201:3000"
	@echo "Traefik: http://192.168.0.205:8080"
	@echo "AlertManager: http://192.168.0.206:9093"

backup: ## Create infrastructure backup
	@echo "$(YELLOW)Creating infrastructure backup...$(NC)"
	@ansible-playbook playbooks/backup.yml

restore: ## Restore from backup (requires BACKUP_TIMESTAMP variable)
	@echo "$(YELLOW)Restoring from backup...$(NC)"
	@if [ -z "$(BACKUP_TIMESTAMP)" ]; then \
		echo "$(RED)Error: BACKUP_TIMESTAMP variable is required$(NC)"; \
		echo "Usage: make restore BACKUP_TIMESTAMP=2024-01-15_14:30:00"; \
		exit 1; \
	fi
	@ansible-playbook playbooks/rollback.yml -e "backup_timestamp=$(BACKUP_TIMESTAMP)"

status: ## Show project status
	@echo "$(YELLOW)Project Status$(NC)"
	@echo "=============="
	@echo "Git branch: $$(git branch --show-current)"
	@echo "Git status: $$(git status --porcelain | wc -l) changed files"
	@echo "Python version: $$(python --version)"
	@echo "Ansible version: $$(ansible --version | head -1)"
	@echo "Collections installed: $$(ansible-galaxy collection list | grep -c homelab || echo 0)"
	@echo ""
	@echo "$(YELLOW)Infrastructure Status$(NC)"
	@echo "==================="
	@ansible all -m ping -i inventory/hosts.yml --one-line 2>/dev/null | head -10 || echo "$(RED)Infrastructure check failed$(NC)"

ci-status: ## Show CI/CD pipeline status
	@echo "$(YELLOW)CI/CD Pipeline Status$(NC)"
	@echo "========================"
	@echo "Last commit: $$(git log -1 --pretty=format:'%h - %s (%an, %ar)')"
	@echo "GitHub Actions: Check repository for latest workflow runs"
	@echo "Available workflows:"
	@ls -1 .github/workflows/*.yml | sed 's/.*\//  - /' | sed 's/\.yml$$//'
