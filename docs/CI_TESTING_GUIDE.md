# CI Pipeline Testing Guide

This guide explains how to test the simplified CI pipeline with Docker containers and reusable workflows.

## Changes Made

### 1. Reusable Docker Build Workflow (`.github/workflows/build-ci-image.yml`)
- ✅ **New centralized workflow** for Docker image building
- ✅ **Outputs image tag and name** for consumption by calling workflows
- ✅ SHA-based tagging (`sha-${{ github.sha }}`) for reproducibility
- ✅ **Image caching**: Checks if SHA-tagged image exists before building
- ✅ Eliminates duplicate Docker build code across workflows
- ✅ Single source of truth for image building logic

### 2. CI Workflow (`.github/workflows/ci.yml`)
- ✅ **Uses reusable workflow** via `uses: ./.github/workflows/build-ci-image.yml`
- ✅ **Fixed image references** using `${{ needs.build-docker-image.outputs.image-name }}`
- ✅ `lint` job depends on `build-docker-image` (prevents race condition)
- ✅ `collections` job depends on both `build-docker-image` and `lint`
- ✅ Fixed collection installation to build first, then install
- ✅ Added syntax checks for `tests/` and `playbooks/` directories

### 3. Molecule Smoke Test Workflow (`.github/workflows/molecule-smoke.yml`)
- ✅ **Uses reusable workflow** via `uses: ./.github/workflows/build-ci-image.yml`
- ✅ **Fixed image reference** using `${{ needs.build-docker-image.outputs.image-name }}`
- ✅ `smoke-test` job depends on `build-docker-image` (prevents race condition)
- ✅ Added Docker socket mounting for Docker-in-Docker support
- ✅ Removed redundant Python/Ansible installation steps

### 4. Image Caching Strategy
- ✅ Reusable workflow checks if image exists for current commit SHA
- ✅ If `sha-<commit>` image exists, skip build (saves ~2-3 minutes)
- ✅ Multiple workflows on same commit reuse the same image
- ✅ All workflows share identical image via consistent SHA tagging
- ✅ Workflow outputs ensure correct image tag propagation

### 5. Documentation Updates
- ✅ Updated `CLAUDE.md` with reusable workflow information
- ✅ Updated `TESTING.md` with simplified CI/CD section
- ✅ Updated `CI_TESTING_GUIDE.md` with current architecture
- ✅ Updated `.github/docker/README.md` with versioning info

### 6. Docker Image Updates
- ✅ Added version labels to `Dockerfile.ci`
- ✅ Added OCI labels for better metadata

## Prerequisites

**No manual setup required!** Docker images are built automatically by the reusable workflow.

### How It Works:

1. **Reusable Workflow Architecture:**
   - `.github/workflows/build-ci-image.yml` is a reusable workflow called by other workflows
   - Outputs `image-tag` and `image-name` for consumption by dependent jobs
   - Centralizes all Docker build logic in one place
   - Eliminates ~70 lines of duplicate code

2. **Automatic Image Building:**
   - CI and Molecule workflows call the reusable workflow as their first job
   - Images are tagged with commit SHA: `sha-<commit>` for reproducibility
   - If image exists for current commit, build is skipped
   - Workflow outputs propagate the exact image name to downstream jobs

3. **Image Sharing Across Jobs:**
   - Reusable workflow outputs: `image-tag` (e.g., `sha-abc123`) and `image-name` (full registry path)
   - Dependent jobs reference: `${{ needs.build-docker-image.outputs.image-name }}`
   - All jobs in a workflow run use the exact same Docker image
   - Multiple workflows on same commit reuse the same cached image

4. **First Run on New Commit:**
   - First workflow to run builds the image (~3-5 minutes)
   - Image is pushed to registry with multiple tags (SHA, branch, version)
   - Subsequent workflows reuse the existing image (instant)
   - GitHub Actions cache further speeds up repeated builds

5. **Verify images were built:**
   - Check CI workflow: https://github.com/pbs-tech/homelab/actions/workflows/ci.yml
   - Check Molecule workflow: https://github.com/pbs-tech/homelab/actions/workflows/molecule-smoke.yml
   - Verify images in registry: https://github.com/orgs/pbs-tech/packages

## Workflow Architecture

### File Structure

```text
.github/workflows/
├── build-ci-image.yml      # Reusable workflow for Docker image building
├── ci.yml                  # Main CI workflow (calls build-ci-image.yml)
└── molecule-smoke.yml      # Molecule smoke test workflow (calls build-ci-image.yml)
```

### Reusable Workflow Pattern

**build-ci-image.yml** (Reusable Workflow):
```yaml
on:
  workflow_call:
    outputs:
      image-tag:        # e.g., "sha-abc123"
      image-name:       # e.g., "ghcr.io/owner/homelab-ci:sha-abc123"

jobs:
  build:
    outputs:
      image-tag: ${{ steps.determine-tag.outputs.tag }}
      image-name: ${{ steps.determine-tag.outputs.full-name }}
```

**ci.yml** (Calling Workflow):
```yaml
jobs:
  build-docker-image:
    uses: ./.github/workflows/build-ci-image.yml
    permissions:
      contents: read
      packages: write

  lint:
    needs: build-docker-image
    container:
      image: ${{ needs.build-docker-image.outputs.image-name }}
```

### Benefits of This Architecture

1. **DRY Principle**: Docker build logic exists in exactly one place
2. **Type Safety**: Workflow outputs ensure correct image references
3. **Maintainability**: Changes to Docker build process only need one update
4. **Consistency**: All workflows use identical images for same commit
5. **Debugging**: Single workflow to troubleshoot for image build issues

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

### Issue 1: Image Tag Mismatch
**Problem:** Docker images were built with SHA tags (`sha-${{ github.sha }}`) but referenced with branch names (`${{ github.ref_name }}`), causing image pull failures.

**Root Cause:**
- Images built as: `ghcr.io/owner/homelab-ci:sha-abc123`
- Jobs trying to pull: `ghcr.io/owner/homelab-ci:molecule`
- Tag mismatch resulted in "image not found" errors

**Fix:**
1. Created reusable workflow that outputs the exact image name
2. Dependent jobs now reference `${{ needs.build-docker-image.outputs.image-name }}`
3. Ensures all jobs use the same SHA-tagged image built in the workflow

### Issue 2: Duplicate Docker Build Code
**Problem:** Both `ci.yml` and `molecule-smoke.yml` had ~70 lines of identical Docker build code, making maintenance difficult.

**Root Cause:** No code reuse mechanism for common Docker build logic across workflows.

**Fix:**
1. Created `.github/workflows/build-ci-image.yml` as a reusable workflow
2. Both CI and Molecule workflows now call this shared workflow
3. Eliminated duplicate code and created single source of truth
4. Changes to Docker build logic now only require one file update

### Issue 3: Race Condition
**Problem:** CI and Molecule workflows failed because they tried to pull images before they were built.

**Root Cause:** The `docker-build.yml` and CI workflows ran in parallel, causing CI jobs to fail when pulling non-existent images.

**Fix:** Integrated Docker image building directly into CI and Molecule workflows via reusable workflow call:
- CI workflow: `lint` depends on `build-docker-image`
- Molecule workflow: `smoke-test` depends on `build-docker-image`
- Reusable workflow ensures build completes before downstream jobs start

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
