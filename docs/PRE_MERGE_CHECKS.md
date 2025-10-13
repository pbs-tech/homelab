# Pre-Merge Check Strategies

This document outlines various strategies for implementing pre-merge checks to ensure code quality, prevent broken builds, and maintain repository standards before code is merged into main branches.

## Table of Contents

- [Current Implementation](#current-implementation)
- [Alternative Strategies](#alternative-strategies)
  - [1. Pre-commit Hooks](#1-pre-commit-hooks)
  - [2. GitHub Branch Protection Rules](#2-github-branch-protection-rules)
  - [3. Local Git Hooks](#3-local-git-hooks)
  - [4. Makefile Validation Targets](#4-makefile-validation-targets)
  - [5. CI/CD Pipeline Strategies](#5-cicd-pipeline-strategies)
  - [6. Pull Request Templates](#6-pull-request-templates)
- [Hybrid Approach (Recommended)](#hybrid-approach-recommended)
- [Implementation Guide](#implementation-guide)

---

## Current Implementation

The homelab project currently uses:

1. **GitHub Actions CI/CD** (`.github/workflows/`)
   - `molecule-smoke.yml` - Fast smoke testing (< 5 min)
   - `ci.yml` - Comprehensive linting and collection validation
   - Automated on pull requests and pushes to main branches

2. **Makefile targets** for local validation
   - `make test-molecule-smoke` - Fast validation
   - `make lint` - YAML, Ansible, and Markdown linting
   - `make test` - Complete validation suite

3. **Molecule testing** - Collection-level testing with Docker

---

## Alternative Strategies

### 1. Pre-commit Hooks

**What:** Automated checks that run before each commit is created

**Advantages:**
- Catches issues early in development cycle
- Fast feedback loop (seconds)
- Prevents committing broken code
- Works offline

**Implementation:**

```bash
# Install pre-commit framework
pip install pre-commit

# Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml <<EOF
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
        args: ['--unsafe']  # Allow custom YAML tags
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: check-merge-conflict
      - id: detect-private-key

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        args: ['-c', '.yamllint']

  - repo: https://github.com/ansible/ansible-lint
    rev: v24.2.0
    hooks:
      - id: ansible-lint
        files: \.(yaml|yml)$
        args: ['--profile=production']

  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.39.0
    hooks:
      - id: markdownlint
        args: ['--config', '.markdownlint.yaml']

  - repo: local
    hooks:
      - id: ansible-syntax-check
        name: Ansible syntax check
        entry: ansible-playbook --syntax-check
        language: system
        files: ^(site|playbooks/.*)\.yml$
        pass_filenames: true

      - id: no-direct-main-commits
        name: Prevent direct commits to main
        entry: bash -c 'if [ "$PRE_COMMIT_FROM_REF" = "refs/heads/main" ]; then echo "Direct commits to main are not allowed"; exit 1; fi'
        language: system
        always_run: true
EOF

# Install hooks
pre-commit install

# Test hooks
pre-commit run --all-files

# Skip hooks for emergency commits (use sparingly)
git commit --no-verify -m "Emergency fix"
```

**Configuration Tips:**
- Start with basic hooks, gradually add more
- Use `--no-verify` sparingly for emergency fixes
- Configure per-repository in `.pre-commit-config.yaml`
- Run `pre-commit autoupdate` monthly to keep hooks current

---

### 2. GitHub Branch Protection Rules

**What:** Server-side enforcement of merge requirements

**Advantages:**
- Cannot be bypassed by developers
- Centralized policy enforcement
- Works with all Git clients
- Integrates with CI/CD status checks

**Implementation:**

1. **Navigate to Repository Settings** → Branches → Add Rule

2. **Configure Protection Rules:**
   ```yaml
   Branch name pattern: main

   Require status checks before merging:
     ☑ Require status checks to pass before merging
     ☑ Require branches to be up to date before merging
     Required checks:
       - lint (YAML, Ansible, Markdown)
       - collections / Validate Collections (common)
       - collections / Validate Collections (k3s)
       - collections / Validate Collections (proxmox_lxc)
       - smoke-test / Smoke Test - All Collections

   Require pull request reviews:
     ☑ Require pull request reviews before merging
     Number of required approvals: 1
     ☑ Dismiss stale reviews when new commits are pushed

   Other restrictions:
     ☑ Require conversation resolution before merging
     ☑ Require linear history
     ☑ Do not allow bypassing the above settings (even for admins)
   ```

3. **Configure Status Checks** in workflows:
   ```yaml
   # .github/workflows/ci.yml
   name: CI
   on:
     pull_request:
       branches: [main, develop]

   jobs:
     lint:
       name: lint (YAML, Ansible, Markdown)
       runs-on: ubuntu-latest
       # ... job configuration
   ```

**Best Practices:**
- Always require status checks for main/production branches
- Require at least 1 review for critical changes
- Enable "Require branches to be up to date" to prevent race conditions
- Use CODEOWNERS file for automatic reviewer assignment

---

### 3. Local Git Hooks

**What:** Custom shell scripts that run at various Git lifecycle points

**Advantages:**
- Full control over validation logic
- Fast execution (local)
- No external dependencies
- Can customize per-developer

**Implementation:**

Create `.git/hooks/pre-push` (runs before `git push`):

```bash
#!/bin/bash
# .git/hooks/pre-push - Comprehensive validation before push

set -e

echo "🔍 Running pre-push validation checks..."

# 1. YAML Linting
echo "📝 Running YAML lint..."
if ! yamllint . --format github 2>&1 | grep -v "warning"; then
    echo "❌ YAML linting failed"
    exit 1
fi

# 2. Ansible Linting
echo "🔧 Running Ansible lint..."
if ! ansible-lint --format quiet --nocolor; then
    echo "❌ Ansible linting failed"
    exit 1
fi

# 3. Ansible Syntax Check
echo "✅ Running Ansible syntax checks..."
for playbook in site.yml security-deploy.yml phase2-security.yml; do
    if ! ansible-playbook --syntax-check "$playbook" > /dev/null 2>&1; then
        echo "❌ Syntax check failed for $playbook"
        exit 1
    fi
done

# 4. Molecule Smoke Test (optional - can be slow)
if [ "${RUN_MOLECULE_TESTS:-0}" = "1" ]; then
    echo "🧪 Running Molecule smoke tests..."
    if ! make test-molecule-smoke; then
        echo "❌ Molecule smoke tests failed"
        exit 1
    fi
fi

# 5. Check for secrets
echo "🔐 Scanning for secrets..."
if command -v trufflehog &> /dev/null; then
    if ! trufflehog git file://. --only-verified --fail; then
        echo "❌ Secrets detected!"
        exit 1
    fi
fi

echo "✅ All pre-push checks passed!"
echo ""
echo "📦 Ready to push to remote repository"
```

Make it executable:
```bash
chmod +x .git/hooks/pre-push

# To share with team, create scripts/ directory
mkdir -p scripts/hooks
cp .git/hooks/pre-push scripts/hooks/
echo "Run: cp scripts/hooks/pre-push .git/hooks/ && chmod +x .git/hooks/pre-push" > scripts/install-hooks.sh
```

**Available Git Hooks:**
- `pre-commit` - Before commit is created
- `prepare-commit-msg` - Before commit message editor opens
- `commit-msg` - Validate commit message format
- `post-commit` - After commit is created
- `pre-push` - Before push to remote (recommended for heavier checks)
- `pre-receive` - Server-side hook (requires server access)

---

### 4. Makefile Validation Targets

**What:** Centralized validation commands via Make targets

**Advantages:**
- Single source of truth for validation
- Easy to run locally and in CI
- Self-documenting with `make help`
- Works across environments

**Implementation:**

Add to `Makefile`:

```makefile
##@ Pre-Merge Validation

.PHONY: pre-merge-check
pre-merge-check: lint test-quick security-scan ## Run all pre-merge checks (< 3 min)
	@echo "✅ All pre-merge checks passed!"
	@echo "Ready to create pull request or merge"

.PHONY: pre-merge-full
pre-merge-full: lint test security-scan test-molecule-smoke ## Run comprehensive pre-merge checks (< 10 min)
	@echo "✅ All comprehensive checks passed!"

.PHONY: security-scan
security-scan: ## Scan for secrets and security issues
	@echo "🔐 Scanning for secrets..."
	@command -v trufflehog >/dev/null 2>&1 || { echo "⚠️  trufflehog not installed, skipping"; exit 0; }
	@trufflehog git file://. --only-verified --fail

.PHONY: validate-syntax
validate-syntax: ## Validate Ansible playbook syntax
	@echo "✅ Validating Ansible syntax..."
	@ansible-playbook --syntax-check site.yml
	@ansible-playbook --syntax-check security-deploy.yml
	@ansible-playbook --syntax-check phase2-security.yml
	@ansible-playbook --syntax-check ansible_collections/homelab/k3s/playbooks/site.yml
	@ansible-playbook --syntax-check ansible_collections/homelab/proxmox_lxc/site.yml

.PHONY: pre-commit
pre-commit: lint validate-syntax ## Quick pre-commit validation (< 30s)
	@echo "✅ Pre-commit checks passed!"

.PHONY: check-uncommitted
check-uncommitted: ## Verify no uncommitted changes exist
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "❌ Uncommitted changes detected"; \
		git status --short; \
		exit 1; \
	fi
	@echo "✅ No uncommitted changes"

.PHONY: check-branch-updated
check-branch-updated: ## Verify branch is up-to-date with main
	@git fetch origin main --quiet
	@if ! git merge-base --is-ancestor origin/main HEAD; then \
		echo "❌ Branch is not up-to-date with main"; \
		echo "Run: git pull --rebase origin main"; \
		exit 1; \
	fi
	@echo "✅ Branch is up-to-date with main"

.PHONY: pre-merge-local
pre-merge-local: check-uncommitted check-branch-updated pre-merge-check ## Complete local pre-merge validation
	@echo "🎉 Ready to push and create PR!"
```

**Usage:**
```bash
# Before committing
make pre-commit

# Before creating PR
make pre-merge-local

# Full validation (optional, CI will run this)
make pre-merge-full
```

---

### 5. CI/CD Pipeline Strategies

**What:** Automated validation pipelines with various triggering strategies

**Advantages:**
- Consistent environment across all developers
- Can run expensive/slow tests
- Provides public status badges
- Can deploy preview environments

**Implementation Strategies:**

#### A. Multi-Stage Pipeline (Current)

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

jobs:
  # Stage 1: Fast checks (< 2 min)
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: YAML/Ansible/Markdown lint
        run: make lint

  # Stage 2: Smoke tests (< 5 min)
  smoke-test:
    name: Smoke Test
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run smoke tests
        run: make test-molecule-smoke

  # Stage 3: Full validation (< 10 min)
  full-test:
    name: Full Validation
    needs: [lint, smoke-test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run full tests
        run: make test
```

#### B. Parallel Pipeline (Faster)

```yaml
# .github/workflows/parallel-ci.yml
name: Parallel CI

on:
  pull_request:
    branches: [main]

jobs:
  # All jobs run in parallel
  yaml-lint:
    name: YAML Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make lint-yaml

  ansible-lint:
    name: Ansible Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make lint-ansible

  smoke-test:
    name: Smoke Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make test-molecule-smoke

  # Merge gate - requires all jobs to pass
  merge-gate:
    name: Merge Gate
    needs: [yaml-lint, ansible-lint, smoke-test]
    runs-on: ubuntu-latest
    steps:
      - run: echo "All checks passed!"
```

#### C. Path-Based Triggering (Efficient)

```yaml
# .github/workflows/smart-ci.yml
name: Smart CI

on:
  pull_request:
    paths:
      - '**.yml'
      - '**.yaml'
      - 'ansible_collections/**'
      - 'molecule/**'
      - 'requirements.yml'

jobs:
  # Only runs when relevant files change
  changed-collections:
    runs-on: ubuntu-latest
    outputs:
      common: ${{ steps.filter.outputs.common }}
      k3s: ${{ steps.filter.outputs.k3s }}
      proxmox: ${{ steps.filter.outputs.proxmox }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            common:
              - 'ansible_collections/homelab/common/**'
            k3s:
              - 'ansible_collections/homelab/k3s/**'
            proxmox:
              - 'ansible_collections/homelab/proxmox_lxc/**'

  test-common:
    needs: changed-collections
    if: needs.changed-collections.outputs.common == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: make test-molecule-common

  test-k3s:
    needs: changed-collections
    if: needs.changed-collections.outputs.k3s == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: make test-molecule-k3s
```

---

### 6. Pull Request Templates

**What:** Standardized PR descriptions with checklists

**Advantages:**
- Ensures consistent PR quality
- Reminds developers of validation steps
- Provides context for reviewers
- Self-documenting changes

**Implementation:**

Create `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Description

<!-- Briefly describe the changes in this PR -->

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Infrastructure/tooling update

## Related Issues

<!-- Link to related issues using #issue_number -->
Fixes #
Relates to #

## Changes Made

<!-- List the specific changes made in this PR -->

-
-
-

## Pre-Merge Checklist

### Local Validation
- [ ] Code has been locally tested
- [ ] `make lint` passes without errors
- [ ] `make pre-merge-check` passes
- [ ] All new/modified roles have been tested with molecule
- [ ] Changes work on target infrastructure (if applicable)

### Code Quality
- [ ] Code follows project conventions and style
- [ ] Complex logic is commented
- [ ] No secrets or sensitive data committed
- [ ] Commit messages are clear and follow conventions

### Documentation
- [ ] README files updated (if needed)
- [ ] Role documentation updated (if applicable)
- [ ] CLAUDE.md updated (if changing project structure)
- [ ] Comments added for complex code

### Testing
- [ ] Existing tests still pass
- [ ] New tests added for new functionality
- [ ] Edge cases considered and tested
- [ ] Molecule scenarios updated (if adding new roles)

### Security
- [ ] No hardcoded credentials or secrets
- [ ] Security implications considered
- [ ] Follows security best practices
- [ ] Dependencies are up to date

## Testing Performed

<!-- Describe the testing performed -->

### Local Testing
```bash
# Commands run locally
make lint
make test-molecule-smoke
# ... other commands
```

### Infrastructure Testing
<!-- If tested on actual infrastructure -->
- Environment:
- Results:

## Screenshots (if applicable)

<!-- Add screenshots for UI changes or monitoring dashboards -->

## Additional Notes

<!-- Any additional information reviewers should know -->

## Reviewer Checklist

- [ ] Code review completed
- [ ] Architecture review completed (for significant changes)
- [ ] Security review completed (for security-related changes)
- [ ] Documentation review completed
- [ ] CI/CD checks passed
```

---

## Hybrid Approach (Recommended)

The most effective strategy combines multiple approaches for defense-in-depth:

### Recommended Setup

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Developer Workstation (Immediate Feedback)         │
│ - Pre-commit hooks (fast checks: linting, syntax)           │
│ - Makefile targets (easy manual validation)                 │
│ Time: < 30 seconds                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Pre-Push Validation (Comprehensive Local)          │
│ - Git pre-push hook (syntax, linting, quick tests)          │
│ - `make pre-merge-local` command                            │
│ Time: 1-3 minutes                                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: CI/CD Pipeline (Automated Cloud Validation)        │
│ - GitHub Actions workflows                                  │
│ - Molecule smoke tests                                      │
│ - Full test suite                                           │
│ - Security scanning                                         │
│ Time: 5-10 minutes                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Branch Protection (Enforcement)                    │
│ - GitHub branch protection rules                            │
│ - Required status checks                                    │
│ - Required reviews                                          │
│ - No bypass allowed                                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: Post-Merge Validation (Continuous)                 │
│ - Main branch CI runs                                       │
│ - Nightly full test suite                                   │
│ - Security scans                                            │
│ - Dependency updates                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Guide

### Quick Start (15 minutes)

1. **Install Pre-commit Hooks**
   ```bash
   pip install pre-commit
   # Use the .pre-commit-config.yaml from this document
   pre-commit install
   pre-commit run --all-files
   ```

2. **Configure Branch Protection**
   - Go to GitHub Settings → Branches
   - Add protection rule for `main` branch
   - Require CI status checks
   - Require 1 review

3. **Add Makefile Targets**
   ```bash
   # Add targets from section 4 to your Makefile
   make pre-commit  # Test it works
   ```

4. **Update PR Template**
   ```bash
   mkdir -p .github
   # Copy PR template from section 6
   ```

### Advanced Setup (1 hour)

1. **Implement Smart CI**
   - Add path-based triggering
   - Set up parallel job execution
   - Configure caching for dependencies

2. **Create Local Git Hooks**
   ```bash
   mkdir -p scripts/hooks
   # Copy pre-push hook from section 3
   chmod +x scripts/hooks/pre-push
   ln -s ../../scripts/hooks/pre-push .git/hooks/pre-push
   ```

3. **Set Up CODEOWNERS**
   ```bash
   cat > .github/CODEOWNERS <<EOF
   # Global reviewers
   * @team-leads

   # Collection-specific reviewers
   /ansible_collections/homelab/common/ @infrastructure-team
   /ansible_collections/homelab/k3s/ @kubernetes-team
   /ansible_collections/homelab/proxmox_lxc/ @lxc-team

   # Security-sensitive files
   *security* @security-team
   *.key @security-team
   EOF
   ```

4. **Configure Automated Dependency Updates**
   ```yaml
   # .github/dependabot.yml
   version: 2
   updates:
     - package-ecosystem: "github-actions"
       directory: "/"
       schedule:
         interval: "weekly"

     - package-ecosystem: "pip"
       directory: "/"
       schedule:
         interval: "weekly"
   ```

---

## Troubleshooting

### Common Issues

**Pre-commit hooks slow?**
- Run expensive checks in pre-push instead
- Use `SKIP=hook-name` to skip specific hooks
- Consider `--no-verify` for emergency commits

**CI pipeline failing intermittently?**
- Add retry logic for flaky tests
- Increase timeouts
- Check for race conditions in parallel jobs
- Review dependency caching

**Branch protection blocking urgent fixes?**
- Create "hotfix" branch with relaxed rules
- Require post-merge validation and revert if needed
- Document emergency procedures

**Developers bypassing checks?**
- Use `--no-verify` only for emergencies
- Server-side hooks can't be bypassed
- Education and documentation are key
- Make checks fast to reduce temptation

---

## Best Practices

1. **Start Small, Iterate**
   - Begin with basic linting
   - Add more checks as team adapts
   - Monitor check execution times

2. **Fast Feedback Loops**
   - Fast checks first (< 30s)
   - Expensive tests in CI only
   - Parallel execution where possible

3. **Clear Error Messages**
   - Explain what failed
   - Provide fix suggestions
   - Link to documentation

4. **Make It Easy to Do the Right Thing**
   - One-command validation: `make pre-merge-check`
   - Automated fix suggestions
   - Good documentation

5. **Balance Speed vs. Thoroughness**
   - Pre-commit: Fast (< 10s)
   - Pre-push: Moderate (1-3 min)
   - CI: Comprehensive (< 10 min)
   - Nightly: Exhaustive (unlimited)

---

## Resources

- [Pre-commit Framework](https://pre-commit.com/)
- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Git Hooks Documentation](https://git-scm.com/docs/githooks)
- [GitHub Actions Best Practices](https://docs.github.com/en/actions/learn-github-actions/usage-limits-billing-and-administration)
- [Molecule Testing](https://molecule.readthedocs.io/)
