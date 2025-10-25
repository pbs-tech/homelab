# CI Pipeline Testing Guide

This guide explains how to test the updated CI pipeline with Docker containers.

## Changes Made

### 1. CI Workflow (`.github/workflows/ci.yml`)
- ✅ **Builds Docker image first** as `build-docker-images` job
- ✅ Fixed invalid SHA tag format (removed `{{branch}}` prefix)
- ✅ `lint` job depends on `build-docker-images` (prevents race condition)
- ✅ `lint` job uses `ghcr.io/pbs-tech/homelab-ci:<branch-name>`
- ✅ `collections` job uses `ghcr.io/pbs-tech/homelab-ci:<branch-name>`
- ✅ Fixed collection installation to build first, then install
- ✅ Added syntax checks for `tests/` and `playbooks/` directories

### 2. Molecule Smoke Test Workflow (`.github/workflows/molecule-smoke.yml`)
- ✅ **Builds Docker image first** as `build-docker-image` job
- ✅ Fixed invalid SHA tag format (removed `{{branch}}` prefix)
- ✅ `smoke-test` job depends on `build-docker-image` (prevents race condition)
- ✅ Uses `ghcr.io/pbs-tech/homelab-ci:<branch-name>`
- ✅ Added Docker socket mounting for Docker-in-Docker support
- ✅ Removed redundant Python/Ansible installation steps
- ✅ **Image caching**: Checks if SHA-tagged image exists before building

### 3. Image Caching Strategy
- ✅ Both workflows check if image exists for current commit SHA
- ✅ If `sha-<commit>` image exists, skip build (saves ~2-3 minutes)
- ✅ Multiple workflows on same commit reuse the same image
- ✅ Separate `docker-build.yml` workflow removed (redundant)

### 4. Documentation Updates
- ✅ Updated `CLAUDE.md` with correct test file paths
- ✅ Updated `TESTING.md` with correct test file paths
- ✅ Updated `.github/docker/README.md` with versioning info

### 5. Docker Image Updates
- ✅ Added version labels to `Dockerfile.ci`
- ✅ Added OCI labels for better metadata

## Prerequisites

**No manual setup required!** Docker images are built automatically by each workflow.

### How It Works:

1. **Automatic Image Building:**
   - CI and Molecule workflows build their own images as the first job
   - Images are tagged with commit SHA: `sha-<commit>`
   - If image exists for current commit, build is skipped

2. **First Run on New Commit:**
   - First workflow to run builds the image (~3-5 minutes)
   - Image is pushed to registry with multiple tags
   - Subsequent workflows reuse the existing image (instant)

3. **Verify images were built:**
   - Check CI workflow: https://github.com/pbs-tech/homelab/actions/workflows/ci.yml
   - Check Molecule workflow: https://github.com/pbs-tech/homelab/actions/workflows/molecule-smoke.yml
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

## Fixed Issues

### Issue 1: Invalid Tag Format
**Problem:** Docker build failed with `invalid tag "ghcr.io/pbs-tech/homelab-ci:-e5c2987"`

**Root Cause:** The `type=sha,prefix={{branch}}-` tag format used an invalid `{{branch}}` template variable that doesn't exist in docker/metadata-action.

**Fix:** Removed the `{{branch}}` prefix and used just `type=sha`, which creates valid SHA tags.

### Issue 2: Race Condition
**Problem:** CI and Molecule workflows failed because they tried to pull images before they were built.

**Root Cause:** The `docker-build.yml` and CI workflows ran in parallel, causing CI jobs to fail when pulling non-existent images.

**Fix:** Integrated Docker image building directly into CI and Molecule workflows as the first job, with dependencies ensuring images are built before they're needed:
- CI workflow: `lint` depends on `build-docker-images`
- Molecule workflow: `smoke-test` depends on `build-docker-image`

## Troubleshooting

### Image Pull Failures (Should No Longer Occur)

Previously, you might have seen errors like:
```
Error: failed to pull image "ghcr.io/pbs-tech/homelab-ci:molecule"
```

**This is now fixed** because images are built within the same workflow before being used.

If you still encounter this:
1. Check the `build-docker-images` job succeeded
2. Verify GitHub Actions has `packages: write` permission
3. Check the image was pushed to the registry

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
