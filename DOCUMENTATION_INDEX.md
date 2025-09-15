# Documentation Index

Complete index of all documentation available in the homelab infrastructure repository. This index provides quick access to all guides, references, and specialized documentation.

## 📖 Quick Navigation

### For New Users

1. **[README.md](README.md)** - Start here for project overview and architecture
2. **[INSTALLATION.md](INSTALLATION.md)** - Complete step-by-step installation guide
3. **[API.md](API.md)** - Service APIs and integration reference

### For Operators

1. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide
2. **[SECURITY-ARCHITECTURE.md](SECURITY-ARCHITECTURE.md)** - Security model and controls
3. **[CLAUDE.md](CLAUDE.md)** - Key commands and operational procedures

### For Developers

1. **[TESTING.md](TESTING.md)** - Testing strategies and procedures
2. **[MOLECULE_TESTING.md](MOLECULE_TESTING.md)** - Development testing with Molecule
3. **[DEVOPS_ASSESSMENT.md](DEVOPS_ASSESSMENT.md)** - DevOps practices and assessment

## 📚 Documentation Categories

### Core Documentation

| Document | Purpose | Audience | Complexity |
|----------|---------|----------|------------|
| [README.md](README.md) | Project overview, architecture, quick start | Everyone | Beginner |
| [INSTALLATION.md](INSTALLATION.md) | Complete installation guide | Operators | Intermediate |
| [CLAUDE.md](CLAUDE.md) | Repository commands and guidance | Developers/Operators | Intermediate |
| [API.md](API.md) | Service APIs and integration | Developers | Advanced |

### Operational Guides

| Document | Purpose | Audience | Complexity |
|----------|---------|----------|------------|
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Issue diagnosis and resolution | Operators | Intermediate |
| [SECURITY-ARCHITECTURE.md](SECURITY-ARCHITECTURE.md) | Security design and controls | Security/Ops | Advanced |
| [CLIENT-VPN-SETUP.md](CLIENT-VPN-SETUP.md) | VPN client configuration | Users | Beginner |

### Development Documentation

| Document | Purpose | Audience | Complexity |
|----------|---------|----------|------------|
| [TESTING.md](TESTING.md) | Testing strategies and procedures | Developers | Intermediate |
| [MOLECULE_TESTING.md](MOLECULE_TESTING.md) | Development testing framework | Developers | Advanced |
| [DEVOPS_ASSESSMENT.md](DEVOPS_ASSESSMENT.md) | DevOps practices evaluation | Developers/Ops | Advanced |

### Collection Documentation

| Collection | README | Galaxy Metadata | Description |
|------------|--------|-----------------|-------------|
| **homelab.common** | [README](ansible_collections/homelab/common/README.md) | [galaxy.yml](ansible_collections/homelab/common/galaxy.yml) | Shared utilities and configuration |
| **homelab.k3s** | [README](ansible_collections/homelab/k3s/README.md) | [galaxy.yml](ansible_collections/homelab/k3s/galaxy.yml) | K3s Kubernetes cluster management |
| **homelab.proxmox_lxc** | [README](ansible_collections/homelab/proxmox_lxc/README.md) | [galaxy.yml](ansible_collections/homelab/proxmox_lxc/galaxy.yml) | Proxmox LXC service deployment |

### Role Documentation

| Role | Collection | README | Purpose |
|------|------------|---------|---------|
| **traefik** | proxmox_lxc | [README](ansible_collections/homelab/proxmox_lxc/roles/traefik/README.md) | Reverse proxy and SSL termination |
| **security_hardening** | common | [README](ansible_collections/homelab/common/roles/security_hardening/README.md) | Security configuration and hardening |

### Specialized Documentation

| Document | Purpose | Complexity |
|----------|---------|------------|
| [Dynamic Inventory Setup](ansible_collections/homelab/proxmox_lxc/DYNAMIC_INVENTORY_SETUP.md) | Proxmox dynamic inventory configuration | Intermediate |
| [.github/SECURITY.md](.github/SECURITY.md) | Security policy and vulnerability reporting | All |

## 🎯 Documentation by Use Case

### Getting Started

1. Read [README.md](README.md) for overview
2. Follow [INSTALLATION.md](INSTALLATION.md) for setup
3. Use [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if issues arise
4. Refer to [API.md](API.md) for service integration

### Daily Operations

- **Service Management**: [CLAUDE.md](CLAUDE.md) for commands
- **Issue Resolution**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Security Monitoring**: [SECURITY-ARCHITECTURE.md](SECURITY-ARCHITECTURE.md)
- **Performance Monitoring**: Collection READMEs for service-specific guidance

### Development and Customization

- **Code Changes**: [TESTING.md](TESTING.md) for testing procedures
- **New Features**: [MOLECULE_TESTING.md](MOLECULE_TESTING.md) for development testing
- **Best Practices**: [DEVOPS_ASSESSMENT.md](DEVOPS_ASSESSMENT.md)
- **Role Development**: Individual role READMEs

### Integration and Automation

- **Service APIs**: [API.md](API.md)
- **Collection Usage**: Collection READMEs
- **Role Configuration**: Role-specific READMEs
- **Dynamic Inventory**: [Dynamic Inventory Setup](ansible_collections/homelab/proxmox_lxc/DYNAMIC_INVENTORY_SETUP.md)

## 🔧 Maintenance and Updates

### Document Maintenance

- **Validation**: Run `./scripts/validate-docs.sh` to check documentation integrity
- **Links**: All internal links are validated automatically
- **Consistency**: Documentation follows markdown best practices
- **Updates**: Documentation is updated with each significant change

### Contributing to Documentation

1. **Follow existing patterns** in structure and style
2. **Update cross-references** when adding new documents
3. **Validate changes** using the validation script
4. **Include examples** and practical guidance
5. **Test all procedures** before documenting them

### Documentation Standards

- **Markdown compliance** with `.markdownlint.yaml` configuration
- **Clear structure** with proper heading hierarchy
- **Comprehensive examples** for all procedures
- **Troubleshooting sections** in technical documents
- **Cross-references** between related documents

## 📊 Documentation Metrics

Current documentation coverage:

- **Total Documents**: 20 markdown files
- **Collection READMEs**: 3 collections with full documentation
- **Role READMEs**: 2 key roles documented (more available on request)
- **API Coverage**: Complete API documentation for all services
- **Installation Coverage**: Step-by-step guides from prerequisites to deployment
- **Troubleshooting Coverage**: Comprehensive issue resolution guides
- **Security Documentation**: Complete security architecture and policies

## 🔍 Finding Information

### Quick Search Tips

```bash
# Search all documentation for specific terms
grep -r "prometheus" *.md ansible_collections/*/README.md

# Find configuration examples
grep -r "ansible-playbook" *.md

# Locate troubleshooting information
grep -r -A 5 -B 5 "troubleshoot\|debug\|fix" *.md
```

### Documentation Locations

- **Repository root**: Core documentation and guides
- **Collection directories**: Collection-specific documentation
- **Role directories**: Role-specific documentation and examples
- **`.github/`**: Repository policies and contribution guidelines

### Help and Support

- **Issues**: Use GitHub issues for bugs and feature requests
- **Questions**: Use GitHub discussions for general questions
- **Security**: Follow [Security Policy](.github/SECURITY.md) for security issues
- **Contributing**: See individual collection READMEs for contribution guidelines

## 📅 Documentation Roadmap

### Completed

- ✅ Core documentation structure
- ✅ Installation and troubleshooting guides
- ✅ Collection and role documentation
- ✅ API documentation
- ✅ Security documentation
- ✅ Testing documentation
- ✅ Validation automation

### Future Enhancements

- 📋 Additional role documentation for specialized services
- 📋 Video tutorials for complex procedures
- 📋 Interactive troubleshooting tools
- 📋 Performance tuning guides
- 📋 Advanced configuration examples
- 📋 Multi-language documentation (if needed)

This documentation index is maintained automatically and provides a comprehensive overview of all available documentation in the homelab infrastructure repository.
