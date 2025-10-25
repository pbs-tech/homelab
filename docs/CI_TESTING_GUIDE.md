# CI Pipeline Testing Guide

This guide explains how to test the updated CI pipeline with Docker containers.

## Changes Made

### 1. CI Workflow (`.github/workflows/ci.yml`)
- ✅ Updated to use branch-specific Docker image tags: `${{ github.ref_name }}`
- ✅ `lint` job uses `ghcr.io/pbs-tech/homelab-ci:<branch-name>`
- ✅ `collections` job uses `ghcr.io/pbs-tech/homelab-ci:<branch-name>`
- ✅ Fixed collection installation to build first, then install
- ✅ Added syntax checks for `tests/` and `playbooks/` directories

### 2. Molecule Smoke Test Workflow (`.github/workflows/molecule-smoke.yml`)
- ✅ Updated to use branch-specific Docker image tag: `${{ github.ref_name }}`
- ✅ Uses `ghcr.io/pbs-tech/homelab-ci:<branch-name>`
- ✅ Added Docker socket mounting for Docker-in-Docker support
- ✅ Removed redundant Python/Ansible installation steps

### 3. Docker Build Workflow (`.github/workflows/docker-build.yml`)
- ✅ Triggers on push to ANY branch (not just main/develop)
- ✅ Creates branch-specific tags automatically (e.g., `molecule`, `main`, `develop`)
- ✅ Added versioning with `v1.0.0` tag (on main branch only)
- ✅ Added SHA-based tags for traceability
- ✅ Configured to push both versioned and `latest` tags

### 4. Documentation Updates
- ✅ Updated `CLAUDE.md` with correct test file paths
- ✅ Updated `TESTING.md` with correct test file paths
- ✅ Updated `.github/docker/README.md` with versioning info

### 5. Docker Image Updates
- ✅ Added version labels to `Dockerfile.ci`
- ✅ Added OCI labels for better metadata

## Prerequisites

Before testing, ensure the Docker images exist in the registry:

1. **Build and push the Docker images:**
   ```bash
   # Option 1: Trigger via GitHub Actions UI
   # Go to: https://github.com/pbs-tech/homelab/actions/workflows/docker-build.yml
   # Click "Run workflow" -> Select branch -> Click "Run workflow"

   # Option 2: Push a change to trigger automatic build
   git add .github/docker/Dockerfile.ci
   git commit -m "Trigger Docker image build"
   git push origin molecule
   ```

2. **Verify images were built:**
   - Check workflow status: https://github.com/pbs-tech/homelab/actions/workflows/docker-build.yml
   - Verify images in registry: https://github.com/orgs/pbs-tech/packages

## Testing Steps

### Step 1: Push to Trigger Docker Image Build

When you push changes to the Dockerfile or docker-build workflow, images are automatically built:

```bash
# On molecule branch, this will create:
# - ghcr.io/pbs-tech/homelab-ci:molecule
# - ghcr.io/pbs-tech/homelab-ci:molecule-<sha>
# - ghcr.io/pbs-tech/homelab-molecule:molecule
# - ghcr.io/pbs-tech/homelab-molecule:molecule-<sha>

# On main branch, this will additionally create:
# - ghcr.io/pbs-tech/homelab-ci:v1.0.0
# - ghcr.io/pbs-tech/homelab-ci:latest
# - ghcr.io/pbs-tech/homelab-molecule:v1.0.0
# - ghcr.io/pbs-tech/homelab-molecule:latest
```

### Step 2: Test CI Workflow Locally (Optional)

```bash
# Pull the branch-specific CI image locally
docker pull ghcr.io/pbs-tech/homelab-ci:molecule

# Test linting in container
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/pbs-tech/homelab-ci:molecule \
  yamllint .

# Test Ansible installation
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/pbs-tech/homelab-ci:molecule \
  ansible --version
```

### Step 3: Test via Pull Request

1. **Create a test branch:**
   ```bash
   git checkout -b test/ci-containers
   git add .
   git commit -m "Update CI workflows to use Docker containers

   - Use ghcr.io/pbs-tech/homelab-ci:v1.0.0 for CI jobs
   - Fix collection installation in lint job
   - Add proper playbook syntax checking
   - Update documentation with correct paths"
   git push origin test/ci-containers
   ```

2. **Open a Pull Request:**
   - Go to: https://github.com/pbs-tech/homelab/pulls
   - Create PR from `test/ci-containers` to `main`
   - Watch the CI workflows run

3. **Monitor the workflows:**
   - CI workflow should complete in ~5-8 minutes (faster with containers)
   - Molecule smoke test should complete in ~5-10 minutes
   - Check for any failures in:
     - YAML linting
     - Markdown linting
     - Ansible collection installation
     - Ansible syntax checks
     - Collection validation

### Step 4: Verify Performance Improvements

Compare CI run times:
- **Before (without containers):** ~10-15 minutes
- **After (with containers):** ~5-8 minutes
- **Expected savings:** 2-5 minutes per job from pre-installed dependencies

## Troubleshooting

### Image Pull Failures

If you see errors like:
```
Error: failed to pull image "ghcr.io/pbs-tech/homelab-ci:v1.0.0"
```

**Solution:**
1. Ensure the docker-build workflow has completed successfully
2. Check that images are public or workflow has proper authentication
3. Verify the image tag exists in the registry

### Collection Installation Failures

If you see errors like:
```
ERROR: Failed to install homelab.common collection
```

**Solution:**
1. The workflow now builds collections first with `ansible-galaxy collection build`
2. Then installs from the `.tar.gz` file
3. Check the collection `galaxy.yml` for proper metadata

### Docker Socket Permission Issues (Molecule)

If Molecule tests fail with Docker permission errors:

**Solution:**
The workflow uses `--privileged` and mounts Docker socket:
```yaml
options: --privileged -v /var/run/docker.sock:/var/run/docker.sock
```

## Success Criteria

✅ All workflows pass without errors
✅ CI jobs complete faster than before (5-8 min vs 10-15 min)
✅ Collection builds and installations succeed
✅ All playbook syntax checks pass
✅ Molecule smoke tests complete successfully

## Next Steps

After successful testing:

1. **Merge the PR** to main branch
2. **Monitor production CI** runs on main branch
3. **Update version** when making breaking changes:
   - Update `Dockerfile.ci` version label
   - Update workflow image tags
   - Push new versioned image
4. **Keep images updated** via weekly automated builds

## Image Version Management

When to bump versions:

- **v1.0.x** (patch): Security updates, dependency updates
- **v1.x.0** (minor): New tools added, non-breaking changes
- **v2.0.0** (major): Breaking changes, major version updates

Update process:
1. Update version in `Dockerfile.ci` LABEL
2. Update version tag in `docker-build.yml`
3. Update version in all workflow files using the image
4. Update documentation

## Rollback Plan

If the containerized approach fails:

1. **Revert workflow changes:**
   ```bash
   git revert <commit-hash>
   git push origin molecule
   ```

2. **Or manually edit workflows** to use setup-python actions again

3. **Previous approach used:**
   - `actions/setup-python@v5`
   - Manual pip installation of dependencies
   - No Docker containers

## Contact

For issues or questions:
- Open an issue: https://github.com/pbs-tech/homelab/issues
- Check workflow runs: https://github.com/pbs-tech/homelab/actions
