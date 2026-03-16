# Phase 4: Best Practices & Standards

---

## Framework & Language Findings (Ansible Idioms)

### High

#### FW-H1: `when:` on `import_playbook` silently ignored — phase skip variables never worked
**File:** `playbooks/infrastructure.yml` lines 37–59

`import_playbook` is a static directive resolved at parse time; Ansible discards any `when:` clause on it. The `skip_networking`, `skip_monitoring`, `skip_applications`, `skip_k3s` variables have never worked. Users believe they can selectively skip phases — they cannot. This is the same issue as AR-C1 but deserves separate noting as a framework anti-pattern.

**Fix:** Remove all `when:` clauses from `import_playbook` directives. Use `--tags` for selective execution (already documented and functional).

---

#### FW-H2: 7 roles fully duplicated between `k3s` and `proxmox_lxc` collections — diverged silently
**Files:** `proxmox_lxc/roles/k3s_server/`, `k3s_agent/`, `k3s_upgrade/`, `airgap/`, `prereq/`, `raspberrypi/`, `security_hardening/`

The two copies have already diverged (`security_hardening` uses `ufw` in k3s vs `iptables` in proxmox_lxc). With the `homelab.common` version, there are now **three** security hardening implementations. These `proxmox_lxc` copies are never imported by any root playbook.

**Fix:** Delete all 7 from `proxmox_lxc`. Reference `homelab.k3s` roles or `homelab.common.security_hardening` where needed.

---

#### FW-H3: `promtail` role uses zero FQCN module names — suppressed from linting
**File:** `proxmox_lxc/roles/promtail/tasks/main.yml`

Every module call (`apt:`, `user:`, `template:`, `systemd:`, etc.) uses short (non-FQCN) names. The rest of the codebase uses `ansible.builtin.*`. The `.ansible-lint` config suppresses `fqcn[action-core]` globally, hiding this.

**Fix:** Convert all module names to FQCNs. Remove the `fqcn[action-core]` suppression from `.ansible-lint` once done.

---

#### FW-H4: `apt: upgrade: true` in 5 service roles — full system upgrade as side effect
**Files:** `traefik`, `grafana`, `loki`, `promtail`, `openwrt` role task files

Unconditional system-wide package upgrades on every role execution. Makes runs non-idempotent, can break services mid-deployment. System upgrades belong only in `playbooks/update-systems.yml`.

**Fix:** Remove `upgrade: true` from all service roles.

---

### Medium

#### FW-M1: `community.general.proxmox` still used in 10 task files — superseded module
The `community.proxmox.proxmox` collection supersedes `community.general.proxmox`. The newer module is in `requirements.yml` but the old module is still called.

**Fix:** Replace `community.general.proxmox*` with `community.proxmox.proxmox*` in all 10 task files.

---

#### FW-M2: `when:` in `meta/dependencies` is silently ignored — opt-out variables don't work
The `use_container_base` / `use_security_hardening` opt-out variables advertised in 7 role `meta/main.yml` files have never worked — Ansible ignores `when:` on meta dependencies.

**Fix:** Remove the fake conditional dependencies. If opt-out is needed, add an early-return check inside the role's `tasks/main.yml`.

---

#### FW-M3: Management CIDR hardcoded in `security_hardening` task files
`192.168.0.0/24` hardcoded instead of referencing `container_network_cidr` variable. Breaks for anyone with a different subnet.

**Fix:** Use `{{ container_network_cidr | default('192.168.0.0/24') }}` throughout.

---

#### FW-M4: `deprecation_warnings = False` in `ansible.cfg` masks all deprecation feedback globally
No visibility into deprecated module usage. Contradicts the purpose of keeping an up-to-date codebase.

**Fix:** Remove this setting. Fix the specific deprecation warnings it's suppressing, then enforce at least `ANSIBLE_DEPRECATION_WARNINGS=1`.

---

#### FW-M5: Three separate inventory trees create variable precedence ambiguity
`inventory/` (root, authoritative), `ansible_collections/homelab/common/inventory/`, `ansible_collections/homelab/proxmox_lxc/inventory/` all define overlapping variables. `proxmox_config` is defined twice with different key formats (`pve_mac` vs `pve-mac`).

**Fix:** Document that root `inventory/` is authoritative. Remove or clearly mark collection-internal inventories as non-authoritative.

---

#### FW-M6: Config templates missing `validate:` parameter
Prometheus (`prometheus.yml.j2`), Traefik (`traefik.yml.j2`), Loki (`loki-config.yml.j2`) templates deploy without syntax validation. A bad template causes immediate service failure.

**Fix:** Add `validate:` parameter using the tool's `--check-config` flag where available:
```yaml
ansible.builtin.template:
  src: prometheus.yml.j2
  dest: /etc/prometheus/prometheus.yml
  validate: promtool check config %s
```

---

### Low

#### FW-L1: Legacy playbooks reference non-existent hostnames but pass CI syntax checks
`phase2-security.yml` and `security-deploy.yml` reference `unbound-lxc`, `adguard-lxc` (not in inventory). They also use deprecated `yes`/`no` truthy values. These pass `ansible-lint --syntax-check` because syntax checking doesn't validate inventory.

**Fix:** Delete both files. Update `docs/PRE_MERGE_CHECKS.md` to remove them from the syntax-check loop.

---

#### FW-L2: `ansible.builtin.pip` installs into system Python without virtualenv (5 roles)
`monitoring_agent`, `step_ca`, and 3 others install Python packages system-wide. Breaks on Ubuntu 23.04+ (PEP 668). Creates dependency conflicts.

**Fix:** Use `virtualenv:` parameter or install via system package manager where possible.

---

#### FW-L3: Iptables restore systemd unit duplicated verbatim across 7 roles
The 15-line `iptables-restore.service` block is copy-pasted identically in `traefik`, `wireguard`, `unbound`, `adguard`, `bastion`, `security_hardening`, and `step_ca`.

**Fix:** Extract to a shared task file in `homelab.common/tasks/iptables-persist.yml`. Include it from each role.

---

#### FW-L4: `common/galaxy.yml` declares `kubernetes.core` dependency — only used in k3s collection
`requirements.yml` in `homelab.common` pulls `kubernetes.core` which is only needed for `homelab.k3s`. Adds unnecessary download/install overhead for operators only using common or proxmox_lxc.

**Fix:** Move `kubernetes.core` to `homelab.k3s/requirements.yml`.

---

---

## CI/CD & DevOps Findings

### High

#### CICD-H1: Galaxy API token interpolated via Jinja in shell command text — secret exposure risk
**File:** `.github/actions/build-publish-collection/action.yml` line 87

```yaml
ansible-galaxy collection publish *.tar.gz --token ${{ env.ANSIBLE_GALAXY_TOKEN }}
```

GitHub Actions masks secrets in logs but the Jinja expansion substitutes the value into the shell script text *before* masking, meaning the value can appear in `/proc/<pid>/cmdline` during execution.

**Fix:** Reference the shell environment variable directly (already set in `env:` block):
```bash
ansible-galaxy collection publish *.tar.gz --token "$ANSIBLE_GALAXY_TOKEN"
```

---

#### CICD-H2: `pyproject.toml` requires Python 3.14 but CI uses Python 3.12
**File:** `pyproject.toml` line 6

`requires-python = ">=3.14"` while all CI workflows use `PYTHON_VERSION: '3.12'` and `ansible-core>=2.17` supports 3.12. Python 3.14 is pre-release. Tooling that reads `pyproject.toml` (uv, tox, `actions/setup-python` with `python-version-file`) would install a pre-release interpreter. The file also has `description = "Add your description here"` — never configured.

**Fix:** Set `requires-python = ">=3.12"`. Fill in the description.

---

#### CICD-H3: `backup`, `restore`, `performance` Makefile targets call non-existent playbooks
**File:** `Makefile` lines 349, 371, and related

`make backup` → `playbooks/backup.yml` (doesn't exist). `make restore` → `playbooks/rollback.yml` (exists but completely broken, see CQ-C3). `make performance` → `tests/performance/local_performance_test.yml` (doesn't exist). Engineers may believe a backup was taken when none was.

**Fix:** Gate targets with `$(error Playbook not yet implemented: ...)` until the files exist.

---

### Medium

#### CICD-M1: No job timeout on `ci.yml` lint and collections jobs
A hung `pip install` or stalled `ansible-galaxy collection install` blocks a runner indefinitely.

**Fix:** Add `timeout-minutes: 20` to the `lint` job and `timeout-minutes: 15` to the `collections` matrix job.

---

#### CICD-M2: `galaxy-publish.yml` has no per-job timeout
The `wait-for-galaxy-collection` polling action (18 attempts × 10s) can overrun if Galaxy API is unresponsive.

**Fix:** Add `timeout-minutes: 30` to each publish job.

---

#### CICD-M3: First-party GitHub Actions not pinned to commit SHA
`actions/checkout@v4`, `actions/setup-python@v5`, `actions/cache@v4` — mutable version tags. Per GitHub hardening guidelines, all actions should be SHA-pinned.

**Fix:** Pin to full commit SHAs. Renovate is already present and configured for `github-actions` — add SHA pinning to its config to automate updates.

---

#### CICD-M4: `deploy-security` Makefile target calls deprecated `security-deploy.yml`
`make deploy-security` runs the legacy file. The target name implies it is the authoritative security deployment path, but it is not.

**Fix:** Update to call `playbooks/infrastructure.yml --tags foundation,phase1,phase2` or add a deprecation notice.

---

#### CICD-M5: `detect-secrets` in requirements but never run in CI
`make security-scan` calls `detect-secrets` (in `requirements.txt`) but no CI workflow invokes it. CI relies solely on TruffleHog (pinned to `@main` — see SEC-C3).

**Fix:** Add `detect-secrets audit .secrets.baseline` as a CI step, or remove it from `requirements.txt` and document that `make security-scan` is local-only.

---

#### CICD-M6: Destructive deploy Makefile targets have no confirmation guard
`make deploy`, `make deploy-phase1`, `make deploy-enclave-persistent` run without interactive confirmation. An accidental keypress has production consequences.

**Fix:** Add a guard to the `deploy` target:
```make
deploy: lint
	@read -p "Deploy to production? [y/N] " ans && [ "$${ans}" = "y" ]
	ansible-playbook playbooks/infrastructure.yml
```

---

#### CICD-M7: Pre-commit `check-secrets` hook doesn't scan shell scripts
The local `check-secrets` hook scans only `.yml`/`.yaml` files. Shell scripts, which may contain hardcoded tokens in `curl`/`ssh` commands, are not scanned.

**Fix:** Add `--include="*.sh"` to the hook. Consider replacing with a proper `detect-secrets-hook`.

---

#### CICD-M8: `markdownlint-cli2` (pre-commit) vs `pymarkdown` (CI) — different rule sets
Pre-commit uses `DavidAnson/markdownlint-cli2`; CI uses `pymarkdownlnt`. A commit passing local hooks can fail CI.

**Fix:** Standardise on `markdownlint-cli2`. Update CI lint job to use `npx markdownlint-cli2`.

---

#### CICD-M9: No CI check that all three `galaxy.yml` versions are in sync
A developer could manually edit one `galaxy.yml` without bumping the others. The publish workflow would release collections with mismatched versions.

**Fix:** Add a cheap lint-job step:
```bash
versions=$(grep '^version:' ansible_collections/homelab/*/galaxy.yml | awk '{print $2}' | sort -u | wc -l)
[ "$versions" -eq 1 ] || { echo "ERROR: galaxy.yml version mismatch"; exit 1; }
```

---

#### CICD-M10: No scheduled workflow for infrastructure health validation
There is no cron-scheduled workflow running `tests/quick-smoke-test.yml` against real infrastructure. Silent drift (crashed container, NotReady K3s node) goes undetected until someone manually runs a check.

**Fix:** Add a scheduled workflow (`schedule: cron: '0 6 * * *'`) for `tests/quick-smoke-test.yml`. If GitHub-hosted runners can't reach the homelab, document this as a `workflow_dispatch`-only target.

---

#### CICD-M11: Renovate custom manager `lookupNameTemplate` unreliable for multi-word packages
`"lookupNameTemplate": "{{depName}}/{{depName}}"` works for `prometheus/prometheus` but breaks for `node_exporter_version` → `node_exporter/node_exporter` (should be `prometheus/node_exporter`). Likely producing failed lookups silently.

**Fix:** Remove the custom manager or add explicit `depNameTemplate` mappings per monitored variable.

---

### Low

#### CICD-L1: `molecule-smoke.yml` push-to-main trigger redundant with `ci.yml`
Both trigger on `push: branches: [main]`, doubling runner usage and complicating PR status checks.

**Fix:** Remove the `push: branches: [main]` trigger from `molecule-smoke.yml` (it's already validated at PR time).

---

#### CICD-L2: `claude-code-review.yml` missing `concurrency` group — redundant reviews on rapid pushes
Multiple Claude review jobs queue and run concurrently on rapid PR pushes, consuming API budget.

**Fix:** Add `concurrency: group: "${{ github.workflow }}-${{ github.event.pull_request.number }}" cancel-in-progress: true`.

---

#### CICD-L3: Ansible collection cache key missing OS and Python version
`key: ansible-collections-${{ hashFiles('**/requirements.yml') }}` — stale cached collections from a different Python/OS environment could be silently restored.

**Fix:** Prefix with `${{ runner.os }}-${{ env.PYTHON_VERSION }}-`.

---

#### CICD-L4: `validate-docs.sh` broken-link error counter silently broken (subshell)
The `while` loop runs in a pipeline subshell — `((errors++))` increments don't propagate. Broken links print warnings but script exits 0.

**Fix:** Use process substitution: `while ...; do ... done < <(grep ...)`.

---

#### CICD-L5: `security-audit.sh` checks wrong path for `SECURITY.md`
Checks `SECURITY.md` at repo root; file is at `.github/SECURITY.md`. Security audit section always reports a false negative.

**Fix:** `[ -f ".github/SECURITY.md" ]`.

---

#### CICD-L6: `setup-pre-commit.sh` uses `set -e` not `set -euo pipefail`
Inconsistent with all other scripts which use `set -euo pipefail`. Pipe failures silently continue.

**Fix:** Change line 3 to `set -euo pipefail`.

---

#### CICD-L7: `lint-fix` Makefile target doesn't fix anything
`lint-fix` is documented as "auto-fix" but only runs `yamllint . --format parsable | head -20 || true`. `yamllint` has no auto-fix mode.

**Fix:** Rename to `lint-report` or implement actual fixing.

---

#### CICD-L8: `ANSIBLE_VERSION: '>=2.17'` is a range — CI picks up latest minor release
Could silently install `ansible-core 2.18+` on the next CI run, picking up new deprecation warnings that break `ansible-lint`.

**Fix:** Pin to `ansible-core~=2.17.0` in CI. Let Renovate manage intentional bumps.

---

#### CICD-L9: `package.json` is an empty object `{}`
Confuses Node.js tooling and Renovate's npm manager. Renovate may attempt to process it.

**Fix:** Delete if unused, or add `"private": true` with `name` and `version` if kept for `markdownlint-cli2`.

---

#### CICD-L10: No workflow for `update-systems.yml` (system patching)
Patching requires someone to remember to run `make update-systems` periodically. No audit trail.

**Fix:** Add a `workflow_dispatch` (optionally scheduled monthly) workflow for `update-systems.yml`.
