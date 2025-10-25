# Custom Docker Images for Homelab CI/CD

This directory contains Dockerfiles for custom images used in the homelab CI/CD pipeline to speed up builds and tests.

## Images

### 1. CI Image (`Dockerfile.ci`)

**Purpose:** General CI image with pre-installed dependencies for linting, validation, and building collections.

**Base Image:** `ubuntu:22.04`

**Pre-installed:**
- Python 3.x
- Ansible Core 2.17+
- Molecule 6.0+
- yamllint, ansible-lint, pymarkdownlnt
- galaxy-importer
- Common Ansible collections (community.general, community.docker, ansible.posix)

**Usage:**
```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/pbs-tech/homelab-ci:v1.0.0
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
```

### 2. Molecule Test Image (`Dockerfile.molecule`)

**Purpose:** Molecule test image with pre-installed dependencies for running Ansible roles in containers.

**Base Image:** `geerlingguy/docker-ubuntu2204-ansible:latest`

**Pre-installed:**
- System utilities (curl, wget, git, vim, htop, etc.)
- Python packages (jinja2, netaddr, dnspython, pytz)
- Pre-created common directories (/etc/prometheus, /etc/grafana, /etc/traefik, etc.)

**Usage:**
```yaml
platforms:
  - name: ubuntu-test
    image: ghcr.io/pbs-tech/homelab-molecule:v1.0.0
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
```

## Building Images

### Build locally

```bash
# Build CI image
docker build -f .github/docker/Dockerfile.ci -t homelab-ci:v1.0.0 .

# Build Molecule image
docker build -f .github/docker/Dockerfile.molecule -t homelab-molecule:v1.0.0 .
```

### Build and push to GitHub Container Registry

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u pbs-tech --password-stdin

# Build and push CI image with version tag
docker build -f .github/docker/Dockerfile.ci -t ghcr.io/pbs-tech/homelab-ci:v1.0.0 .
docker tag ghcr.io/pbs-tech/homelab-ci:v1.0.0 ghcr.io/pbs-tech/homelab-ci:latest
docker push ghcr.io/pbs-tech/homelab-ci:v1.0.0
docker push ghcr.io/pbs-tech/homelab-ci:latest

# Build and push Molecule image with version tag
docker build -f .github/docker/Dockerfile.molecule -t ghcr.io/pbs-tech/homelab-molecule:v1.0.0 .
docker tag ghcr.io/pbs-tech/homelab-molecule:v1.0.0 ghcr.io/pbs-tech/homelab-molecule:latest
docker push ghcr.io/pbs-tech/homelab-molecule:v1.0.0
docker push ghcr.io/pbs-tech/homelab-molecule:latest
```

## Automated Builds

A GitHub Actions workflow (`.github/workflows/docker-build.yml`) automatically builds and pushes these images when:
- Changes are made to Dockerfiles in `.github/docker/`
- Manual workflow dispatch is triggered
- Weekly schedule (to keep dependencies up to date)

## Benefits

1. **Faster CI builds:** Dependencies are pre-installed, reducing build time by 2-5 minutes per job
2. **Consistent environment:** All CI jobs use the same versions of tools and dependencies
3. **Reduced network usage:** No need to download dependencies on every CI run
4. **Better caching:** GitHub Actions can cache the container images
5. **Reproducible builds:** Same environment locally and in CI

## Image Updates

Images should be rebuilt and pushed when:
- Ansible version changes
- Molecule version changes
- New dependencies are added to the project
- Security updates are needed

Use semantic versioning for image tags:
- `v1.0.0` - Specific version (recommended for production)
- `latest` - Latest stable build (auto-updated from main branch)
- `main` - Latest build from main branch
- `develop` - Development/testing builds
- `main-<sha>` - Specific commit from main branch

**Current stable version:** `v1.0.0`

**Recommendation:** Use specific version tags (e.g., `v1.0.0`) in workflows for reproducibility and stability.

## Security Considerations

- Images are scanned for vulnerabilities using Trivy
- Base images are updated regularly
- No secrets or credentials are included in images
- Images run with minimal required privileges
- Health checks ensure container integrity
