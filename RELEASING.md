# Releasing Collections to Ansible Galaxy

This document describes the process for releasing the homelab Ansible collections to Ansible Galaxy.

## Overview

This repository contains three Ansible collections:

- **homelab.common** - Shared utilities and roles for infrastructure management
- **homelab.k3s** - K3s Kubernetes cluster deployment and management
- **homelab.proxmox_lxc** - Proxmox LXC container services management

All collections are published to [Ansible Galaxy](https://galaxy.ansible.com/) and follow semantic versioning.

## Semantic Versioning

We follow [Semantic Versioning 2.0.0](https://semver.org/) for all collections:

- **MAJOR version** (X.0.0): Incompatible API changes or breaking changes
  - Example: Removing a role, changing required variables, restructuring inventory
- **MINOR version** (0.X.0): New functionality in a backwards-compatible manner
  - Example: Adding new roles, new optional features, new playbooks
- **PATCH version** (0.0.X): Backwards-compatible bug fixes
  - Example: Fixing bugs, updating documentation, security patches

### Version Synchronization

Currently, all three collections share the same version number for simplicity:

- If any collection has breaking changes → bump MAJOR for all
- If any collection adds features → bump MINOR for all
- If only bug fixes → bump PATCH for all

This may change in the future if collections evolve independently.

## Prerequisites

Before you can publish collections, you need:

1. **Ansible Galaxy Account**
   - Create an account at [galaxy.ansible.com](https://galaxy.ansible.com/)
   - Join or create the `homelab` namespace

2. **API Token**
   - Go to [galaxy.ansible.com/me/preferences](https://galaxy.ansible.com/me/preferences)
   - Click "API Key" and copy your token
   - Add the token to GitHub repository secrets as `GALAXY_API_KEY`
     - Go to: Settings → Secrets and variables → Actions → New repository secret
     - Name: `GALAXY_API_KEY`
     - Value: Your Galaxy API token

## Release Process

### 1. Prepare the Release

Before creating a release, ensure all changes are tested and documented:

```bash
# Run full test suite
make test

# Run linting checks
make lint

# Run molecule tests (recommended)
make test-molecule-smoke
# or for comprehensive testing
make test-molecule-all

# Verify CI is passing
# Check GitHub Actions: https://github.com/pbs-tech/homelab/actions
```

### 2. Update Version Numbers

Use the provided script to update versions across all collections:

```bash
# Auto-increment version
./scripts/bump-version.sh minor   # For feature releases (1.0.0 → 1.1.0)
./scripts/bump-version.sh patch   # For bug fixes (1.0.0 → 1.0.1)
./scripts/bump-version.sh major   # For breaking changes (1.0.0 → 2.0.0)

# Or set specific version
./scripts/bump-version.sh 1.2.0
```

The script will update all three `galaxy.yml` files simultaneously:
- `ansible_collections/homelab/common/galaxy.yml`
- `ansible_collections/homelab/k3s/galaxy.yml`
- `ansible_collections/homelab/proxmox_lxc/galaxy.yml`

**Manual Update (Alternative):**

If you prefer to update manually, edit the version line in each file:

```yaml
version: 1.1.0  # Update to your new version
```

### 3. Update CHANGELOG

Update the `CHANGELOG.md` file with details of what changed:

```markdown
## [1.1.0] - 2025-01-15

### Added
- New role for XYZ functionality
- Support for ABC feature

### Changed
- Updated role XYZ to improve performance
- Improved documentation for ABC

### Fixed
- Fixed bug in XYZ role
- Corrected typo in documentation
```

### 4. Commit and Push Changes

```bash
# Commit version bump and changelog
git add ansible_collections/*/galaxy.yml CHANGELOG.md
git commit -m "Bump version to 1.1.0"
git push origin main
```

### 5. Create a GitHub Release

Create a new release through the GitHub web interface:

1. Go to: https://github.com/pbs-tech/homelab/releases/new
2. Click "Choose a tag" and create a new tag: `v1.1.0`
3. Set the release title: `Release v1.1.0`
4. Add release notes (copy from CHANGELOG.md)
5. Click "Publish release"

Alternatively, use the GitHub CLI:

```bash
# Create and push a git tag
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin v1.1.0

# Create GitHub release with gh CLI
gh release create v1.1.0 \
  --title "Release v1.1.0" \
  --notes "$(sed -n '/## \[1.1.0\]/,/## \[/p' CHANGELOG.md | head -n -1)"
```

### 6. Automated Publishing

Once the release is published, the GitHub Actions workflow will automatically:

1. Build all three collections
2. Publish `homelab.common` to Galaxy
3. Wait for common to be processed
4. Publish `homelab.k3s` to Galaxy
5. Publish `homelab.proxmox_lxc` to Galaxy

Monitor the workflow at: https://github.com/pbs-tech/homelab/actions

The collections will be available at:
- https://galaxy.ansible.com/homelab/common
- https://galaxy.ansible.com/homelab/k3s
- https://galaxy.ansible.com/homelab/proxmox_lxc

## Manual Publishing (Alternative)

If you need to publish manually without creating a release:

### Build Collections

```bash
# Build each collection
cd ansible_collections/homelab/common
ansible-galaxy collection build
cd ../k3s
ansible-galaxy collection build
cd ../proxmox_lxc
ansible-galaxy collection build
```

### Publish to Galaxy

```bash
# Publish common first (dependency for others)
cd ansible_collections/homelab/common
ansible-galaxy collection publish *.tar.gz --api-key=YOUR_API_KEY

# Wait a minute for Galaxy to process, then publish others
cd ../k3s
ansible-galaxy collection publish *.tar.gz --api-key=YOUR_API_KEY

cd ../proxmox_lxc
ansible-galaxy collection publish *.tar.gz --api-key=YOUR_API_KEY
```

### Using Workflow Dispatch

You can also trigger the publishing workflow manually:

1. Go to: https://github.com/pbs-tech/homelab/actions/workflows/galaxy-publish.yml
2. Click "Run workflow"
3. Select which collection(s) to publish (all, common, k3s, or proxmox_lxc)
4. Click "Run workflow"

This is useful for:
- Publishing a single collection after a hotfix
- Re-publishing if the automated workflow fails
- Testing the publishing process

## Verification

After publishing, verify the collections are available:

```bash
# Search for collections
ansible-galaxy collection list homelab

# Install from Galaxy to test
ansible-galaxy collection install homelab.common --force
ansible-galaxy collection install homelab.k3s --force
ansible-galaxy collection install homelab.proxmox_lxc --force

# Verify versions
ansible-galaxy collection list homelab
```

## Testing the Publishing Workflow

Before creating an actual release, it's recommended to test the publishing workflow to ensure everything is configured correctly.

### Pre-Release Workflow Testing

**Option 1: Manual Workflow Dispatch (Recommended for Testing)**

Test the workflow without creating a release:

1. **Prepare a test version:**
   ```bash
   # Bump to a test version (e.g., 1.0.0-rc1)
   ./scripts/bump-version.sh 1.0.0-rc1
   git add ansible_collections/*/galaxy.yml
   git commit -m "Test version bump for workflow validation"
   git push origin your-branch
   ```

2. **Trigger the workflow manually:**
   ```bash
   # Using GitHub CLI
   gh workflow run galaxy-publish.yml -f collection=common

   # Or via the web interface:
   # Go to: https://github.com/pbs-tech/homelab/actions/workflows/galaxy-publish.yml
   # Click "Run workflow"
   # Select branch and collection to test
   ```

3. **Monitor the workflow:**
   ```bash
   # Watch the workflow run
   gh run watch

   # Or view in browser:
   # https://github.com/pbs-tech/homelab/actions
   ```

4. **Verify the test collection on Galaxy:**
   ```bash
   # Check if the test version appears on Galaxy
   ansible-galaxy collection install homelab.common:1.0.0-rc1

   # Clean up the test version (if needed)
   # Note: Galaxy doesn't allow deleting versions easily
   # Use yank feature if absolutely necessary
   ```

5. **Revert the test version:**
   ```bash
   # Revert to the actual version
   ./scripts/bump-version.sh 1.0.0
   git add ansible_collections/*/galaxy.yml
   git commit -m "Revert test version bump"
   git push
   ```

**Option 2: Dry-Run Build Validation (Local Testing)**

Test the build process locally without publishing:

```bash
# Install dependencies
pip install "ansible-core>=2.17" galaxy-importer

# Install external dependencies
ansible-galaxy collection install -r requirements.yml --force

# Build each collection
for collection in common k3s proxmox_lxc; do
  echo "Building homelab.$collection..."
  cd ansible_collections/homelab/$collection

  # Clean old builds
  rm -f *.tar.gz

  # Build the collection
  ansible-galaxy collection build

  # Validate with galaxy-importer
  echo "Validating homelab.$collection..."
  python -m galaxy_importer.main *.tar.gz

  if [ $? -eq 0 ]; then
    echo "✓ homelab.$collection validated successfully"
  else
    echo "✗ homelab.$collection validation failed"
    exit 1
  fi

  cd ../../..
done

echo "All collections built and validated successfully!"
```

**Option 3: Fork Testing (Safest for First-Time Setup)**

If you're setting up the workflow for the first time:

1. Create a test namespace on Galaxy (e.g., `homelab_test`)
2. Fork the repository or create a test branch
3. Update galaxy.yml files to use the test namespace
4. Create a test release (e.g., v0.0.1-test)
5. Verify the workflow completes successfully
6. Revert changes and proceed with actual release

### Workflow Testing Checklist

Before your first production release, verify:

- [ ] `GALAXY_API_KEY` secret is set in GitHub repository settings
- [ ] API key has publishing permissions for the `homelab` namespace
- [ ] All three galaxy.yml files have correct metadata:
  - [ ] Correct namespace (`homelab`)
  - [ ] Valid version format (X.Y.Z)
  - [ ] Correct repository URLs
  - [ ] Valid license identifiers
- [ ] CI/CD pipeline passes (linting, molecule tests, collection validation)
- [ ] Local build and validation succeeds for all collections
- [ ] Test workflow dispatch completes without errors
- [ ] Collections install correctly from Galaxy after test publish
- [ ] Dependency resolution works (k3s and proxmox_lxc can find homelab.common)

### Common Testing Issues

**Issue: Workflow fails with "Invalid API key"**
- Solution: Verify the secret name is exactly `GALAXY_API_KEY`
- Verify the API key is valid on Galaxy
- Check that the key has publishing permissions

**Issue: Collection not found during dependency installation**
- Solution: This is expected during testing if common hasn't been published yet
- The workflow will automatically fall back to local installation
- Check logs for: "✓ Installed homelab.common from Galaxy" or "⚠ Galaxy installation failed, using local collection"

**Issue: Galaxy importer validation fails**
- Solution: Check galaxy.yml metadata format
- Verify all required files are present (README.md, roles/, etc.)
- Run galaxy-importer locally for detailed error messages

**Issue: Namespace not found**
- Solution: Ensure you have publishing rights to the `homelab` namespace on Galaxy
- Contact namespace owner or create the namespace if it doesn't exist

### Monitoring Published Collections

After publishing, monitor for issues:

```bash
# Check collection page on Galaxy
open https://galaxy.ansible.com/homelab/common

# Verify version appears correctly
ansible-galaxy collection install homelab.common --force

# Check download stats and version history
# Visit: https://galaxy.ansible.com/homelab/common/versions

# Test installation in a clean environment
docker run -it --rm python:3.12 bash -c "
  pip install ansible-core>=2.17 && \
  ansible-galaxy collection install homelab.common homelab.k3s homelab.proxmox_lxc && \
  ansible-galaxy collection list homelab
"
```

## Troubleshooting

### Publishing Fails with "Namespace not found"

Ensure you have access to the `homelab` namespace on Galaxy. Contact the namespace owner to request access.

### Publishing Fails with "Invalid API key"

- Verify the `GALAXY_API_KEY` secret is set correctly in GitHub
- Generate a new API key from Galaxy and update the secret
- Ensure the API key has publishing permissions

### API Key Rotation

For security best practices, rotate your Galaxy API key periodically:

**Recommended Rotation Schedule:**
- Regular rotation: Every 90 days
- After team member changes: Immediately
- After suspected compromise: Immediately

**Rotation Procedure:**

1. **Generate a new API key from Galaxy:**
   - Go to: https://galaxy.ansible.com/me/preferences
   - Click "API Key" → "Show" to reveal current key (optional: save for rollback)
   - Click "Reset" to generate a new key
   - Copy the new API key immediately (it won't be shown again)

2. **Update GitHub Secret:**
   - Go to: https://github.com/pbs-tech/homelab/settings/secrets/actions
   - Click on `GALAXY_API_KEY`
   - Click "Update secret"
   - Paste the new API key
   - Click "Update secret"

3. **Test the new key:**
   ```bash
   # Test publishing (dry-run not available, use a test collection if possible)
   # Or trigger a manual workflow dispatch with a single collection
   gh workflow run galaxy-publish.yml -f collection=common
   ```

4. **Monitor the workflow:**
   - Go to: https://github.com/pbs-tech/homelab/actions
   - Verify the publishing workflow completes successfully
   - If it fails with authentication errors, verify the key was copied correctly

5. **Document the rotation:**
   - Record rotation date in your security log
   - Note the reason for rotation (scheduled, team change, etc.)

**Rollback Procedure (if new key fails):**

If the new API key doesn't work and you saved the old key:

1. Revert the GitHub secret to the old key
2. Verify the old key still works on Galaxy
3. Investigate why the new key failed
4. Try generating another new key

**Best Practices:**
- Use a password manager to securely store the API key temporarily during rotation
- Never commit API keys to the repository
- Limit API key access to necessary team members only
- Monitor Galaxy for unusual publishing activity
- Consider using separate API keys for different automation workflows if Galaxy supports it

### Collection Build Fails

```bash
# Validate collection metadata
ansible-galaxy collection build --force

# Check for syntax errors
ansible-playbook --syntax-check playbooks/*.yml

# Run galaxy-importer for validation
pip install galaxy-importer
python -m galaxy_importer.main *.tar.gz
```

### Dependency Issues

If k3s or proxmox_lxc fail to publish due to missing homelab.common:

1. Ensure common was published successfully
2. Wait 1-2 minutes for Galaxy to process the collection
3. Re-run the workflow for the failed collection

## Best Practices

1. **Test Before Release**
   - Always run the full test suite before releasing
   - Verify molecule tests pass
   - Check CI/CD pipeline status

2. **Semantic Versioning**
   - Be conservative with MAJOR version bumps
   - Clearly document breaking changes
   - Keep CHANGELOG.md up to date

3. **Release Cadence**
   - Regular releases (monthly or quarterly)
   - Hotfix releases for critical bugs
   - Feature releases when significant functionality is added

4. **Communication**
   - Announce releases in relevant channels
   - Document migration paths for breaking changes
   - Provide upgrade guides for MAJOR versions

5. **Dependency Management**
   - Keep external dependencies up to date
   - Test compatibility with new Ansible versions
   - Document minimum required versions

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## References

- [Ansible Galaxy Documentation](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html)
- [Semantic Versioning](https://semver.org/)
- [Collection Structure](https://docs.ansible.com/ansible/latest/dev_guide/developing_collections_structure.html)
- [Publishing Collections](https://docs.ansible.com/ansible/latest/dev_guide/developing_collections_distributing.html)
