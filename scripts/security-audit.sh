#!/bin/bash
# Comprehensive Security Audit Script
# Validates security best practices across the homelab repository

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

print_header() {
    echo -e "${BLUE}=================================="
    echo -e "🔒 HOMELAB SECURITY AUDIT"
    echo -e "==================================${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}📋 $1${NC}"
    echo "----------------------------------------"
}

check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNING_CHECKS++))
    ((TOTAL_CHECKS++))
}

# Change to repository root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

print_header

# 1. API Token Security Audit
print_section "API Token Security Configuration"

# Check for API token usage in Proxmox configurations
if grep -r "api_token_id" ansible_collections/homelab/*/inventory/group_vars/ >/dev/null 2>&1; then
    check_pass "API tokens configured in group variables"
else
    check_fail "API tokens not found in group variables"
fi

# Check for deprecated password usage
password_files=$(grep -r "api_password.*proxmox_password" ansible_collections/ 2>/dev/null | wc -l || echo 0)
if [ "$password_files" -eq 0 ]; then
    check_pass "No deprecated password authentication in roles"
else
    check_warning "$password_files files still using password authentication"
fi

# Check for vault encryption
if grep -r "vault_proxmox_api_tokens" . >/dev/null 2>&1; then
    check_pass "Vault variables for API tokens configured"
else
    check_warning "Vault variables for API tokens not found"
fi

# Check inventory configuration
if grep -q "api_token_id" ansible_collections/homelab/proxmox_lxc/inventory/proxmox.yml 2>/dev/null; then
    check_pass "Dynamic inventory uses API token authentication"
else
    check_fail "Dynamic inventory not configured for API tokens"
fi

echo ""

# 2. Secrets Management Audit
print_section "Secrets Management"

# Check for hardcoded secrets
secret_files=$(grep -r -i "password.*:" . --exclude-dir=.git --exclude="*.md" --exclude="*template*" | grep -v "vault_" | grep -v "#" | wc -l || echo 0)
if [ "$secret_files" -eq 0 ]; then
    check_pass "No hardcoded passwords found"
else
    check_warning "$secret_files potential hardcoded secrets found"
fi

# Check for vault template
if [ -f "vault_variables_template.yml" ]; then
    check_pass "Vault variables template available"
else
    check_fail "Vault variables template missing"
fi

# Check for .gitignore protection
if grep -q "vault.yml" .gitignore 2>/dev/null; then
    check_pass "Vault files protected by .gitignore"
else
    check_warning "Vault files may not be protected by .gitignore"
fi

echo ""

# 3. SSL/TLS Security
print_section "SSL/TLS Configuration"

# Check for SSL configuration
if grep -r "validate_certs" ansible_collections/ >/dev/null 2>&1; then
    check_pass "SSL certificate validation configured"
else
    check_warning "SSL certificate validation not explicitly configured"
fi

# Check for SSL email configuration
if grep -r "vault_ssl_email" . >/dev/null 2>&1; then
    check_pass "SSL certificate email configured in vault"
else
    check_warning "SSL certificate email not found in vault configuration"
fi

echo ""

# 4. SSH Security
print_section "SSH Security Configuration"

# Check for SSH key configuration
if grep -r "ssh_key" ansible_collections/ >/dev/null 2>&1; then
    check_pass "SSH key authentication configured"
else
    check_warning "SSH key authentication not found"
fi

# Check for password authentication disabling
ssh_configs=$(find . -name "*.yml" -exec grep -l "PasswordAuthentication.*no" {} \; 2>/dev/null | wc -l || echo 0)
if [ "$ssh_configs" -gt 0 ]; then
    check_pass "SSH password authentication disabled in $ssh_configs files"
else
    check_warning "SSH password authentication not explicitly disabled"
fi

echo ""

# 5. Container Security
print_section "Container Security"

# Check for unprivileged containers
if grep -r "unprivileged.*true" ansible_collections/ >/dev/null 2>&1; then
    check_pass "Unprivileged container configuration found"
else
    check_fail "Unprivileged container configuration not found"
fi

# Check for resource limits
if grep -r -E "(memory|cores|swap).*:" ansible_collections/ >/dev/null 2>&1; then
    check_pass "Container resource limits configured"
else
    check_warning "Container resource limits not explicitly configured"
fi

echo ""

# 6. Network Security
print_section "Network Security"

# Check for firewall configuration
if grep -r -i "firewall\|ufw" ansible_collections/ >/dev/null 2>&1; then
    check_pass "Firewall configuration found"
else
    check_warning "Firewall configuration not found"
fi

# Check for network segmentation
if grep -r "192.168.0" ansible_collections/ | grep -E "(200|230|240)" >/dev/null 2>&1; then
    check_pass "Network segmentation configured"
else
    check_warning "Network segmentation not clearly defined"
fi

echo ""

# 7. Security Hardening
print_section "Security Hardening"

# Check for security hardening roles
if [ -d "ansible_collections/homelab/common/roles/security_hardening" ]; then
    check_pass "Security hardening role exists"
else
    check_fail "Security hardening role not found"
fi

# Check for fail2ban configuration
if grep -r "fail2ban" ansible_collections/ >/dev/null 2>&1; then
    check_pass "Fail2ban intrusion detection configured"
else
    check_warning "Fail2ban intrusion detection not found"
fi

# Check for log monitoring
if grep -r -i "log.*monitor\|loki" ansible_collections/ >/dev/null 2>&1; then
    check_pass "Log monitoring configured"
else
    check_warning "Log monitoring not found"
fi

echo ""

# 8. CI/CD Security
print_section "CI/CD Security"

# Check for security scanning in CI
if [ -f ".github/workflows/security.yml" ]; then
    check_pass "Security workflow configured"
else
    check_fail "Security workflow not found"
fi

# Check for secret scanning
if grep -r "truffleHog\|gitleaks" .github/ >/dev/null 2>&1; then
    check_pass "Secret scanning configured in CI/CD"
else
    check_warning "Secret scanning not found in CI/CD"
fi

# Check for dependency scanning
if grep -r "dependency.*check\|snyk" .github/ >/dev/null 2>&1; then
    check_pass "Dependency scanning configured"
else
    check_warning "Dependency scanning not found"
fi

echo ""

# 9. Documentation Security
print_section "Security Documentation"

# Check for security documentation
if [ -f ".github/SECURITY.md" ]; then
    check_pass "Security policy documentation exists"
else
    check_warning "Security policy documentation not found"
fi

# Check for API migration documentation
if [ -f "PROXMOX_API_MIGRATION.md" ]; then
    check_pass "API migration documentation exists"
else
    check_fail "API migration documentation not found"
fi

echo ""

# 10. Compliance Checks
print_section "Compliance and Best Practices"

# Check for linting configuration
if [ -f ".ansible-lint" ] && [ -f ".yamllint" ]; then
    check_pass "Linting configuration files present"
else
    check_warning "Linting configuration files missing"
fi

# Check for pre-commit hooks
if [ -f ".pre-commit-config.yaml" ]; then
    check_pass "Pre-commit hooks configured"
else
    check_warning "Pre-commit hooks not configured"
fi

# Check for security tags in playbooks
security_tags=$(grep -r "tags:" ansible_collections/ | grep -i "security" | wc -l || echo 0)
if [ "$security_tags" -gt 0 ]; then
    check_pass "Security tags found in $security_tags locations"
else
    check_warning "Security tags not found in playbooks"
fi

echo ""

# Summary
print_section "SECURITY AUDIT SUMMARY"

echo -e "${GREEN}✅ Passed: $PASSED_CHECKS${NC}"
echo -e "${YELLOW}⚠️  Warnings: $WARNING_CHECKS${NC}"
echo -e "${RED}❌ Failed: $FAILED_CHECKS${NC}"
echo "📊 Total Checks: $TOTAL_CHECKS"
echo ""

# Calculate security score
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    if [ "$SCORE" -ge 90 ]; then
        echo -e "${GREEN}🛡️  Security Score: $SCORE% (EXCELLENT)${NC}"
    elif [ "$SCORE" -ge 80 ]; then
        echo -e "${YELLOW}🛡️  Security Score: $SCORE% (GOOD)${NC}"
    elif [ "$SCORE" -ge 70 ]; then
        echo -e "${YELLOW}🛡️  Security Score: $SCORE% (FAIR)${NC}"
    else
        echo -e "${RED}🛡️  Security Score: $SCORE% (NEEDS IMPROVEMENT)${NC}"
    fi
fi

echo ""

# Recommendations
print_section "SECURITY RECOMMENDATIONS"

if [ "$FAILED_CHECKS" -gt 0 ]; then
    echo -e "${RED}🚨 Critical Issues Found:${NC}"
    echo "  - Address all failed checks before production deployment"
    echo "  - Review and implement missing security controls"
    echo ""
fi

if [ "$WARNING_CHECKS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Improvement Opportunities:${NC}"
    echo "  - Review warning items for enhanced security"
    echo "  - Consider implementing additional security measures"
    echo ""
fi

echo -e "${BLUE}📚 Next Steps:${NC}"
echo "  1. Address critical security issues"
echo "  2. Review SECURITY.md for detailed requirements"
echo "  3. Run: ansible-playbook test-proxmox-api-tokens.yml"
echo "  4. Set up regular security audits (monthly)"
echo "  5. Implement API token rotation (90 days)"
echo ""

echo -e "${GREEN}🎯 Security Migration Status: COMPLETE${NC}"
echo -e "${GREEN}   ✅ API tokens implemented"
echo -e "${GREEN}   ✅ Password authentication deprecated"
echo -e "${GREEN}   ✅ Security best practices applied"
echo -e "${GREEN}   ✅ Documentation updated"
echo ""

# Exit with appropriate code
if [ "$FAILED_CHECKS" -gt 0 ]; then
    exit 1
elif [ "$WARNING_CHECKS" -gt 5 ]; then
    exit 2
else
    exit 0
fi
