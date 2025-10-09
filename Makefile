# Homelab Infrastructure Makefile
# Provides common development and deployment tasks

.DEFAULT_GOAL := help
.PHONY: help install lint lint-yaml lint-ansible lint-markdown test deploy clean performance drift-check release monitor backup restore ci-status

# Colors for output
YELLOW := \033[1;33m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m # No Color

# Default Python and Ansible versions
PYTHON_VERSION ?= 3.11
ANSIBLE_CORE_VERSION ?= 2.15

help: ## Show this help message
	@echo "$(YELLOW)Homelab Infrastructure Management$(NC)"
	@echo "=================================="
	@echo
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

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

test-api: ## Validate Proxmox API authentication
	@echo "$(YELLOW)Testing Proxmox API token authentication...$(NC)"
	@ansible-playbook test-proxmox-api-tokens.yml

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
