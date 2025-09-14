# Homelab Infrastructure Makefile
# Provides common development and deployment tasks

.DEFAULT_GOAL := help
.PHONY: help install lint lint-yaml lint-ansible lint-markdown test deploy clean

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

test: ## Run molecule tests
	@echo "$(YELLOW)Running molecule tests...$(NC)"
	@if [ -d "molecule" ]; then \
		molecule test; \
	else \
		echo "$(YELLOW)No molecule tests found, skipping...$(NC)"; \
	fi

test-security: ## Run security hardening tests
	@echo "$(YELLOW)Running security hardening tests...$(NC)"
	ansible-playbook test-security-hardening.yml --check

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
	@echo "See: README.md, CLAUDE.md, and collection-specific docs"

status: ## Show project status
	@echo "$(YELLOW)Project Status$(NC)"
	@echo "=============="
	@echo "Git branch: $$(git branch --show-current)"
	@echo "Git status: $$(git status --porcelain | wc -l) changed files"
	@echo "Python version: $$(python --version)"
	@echo "Ansible version: $$(ansible --version | head -1)"
	@echo "Collections installed: $$(ansible-galaxy collection list | grep -c homelab || echo 0)"
