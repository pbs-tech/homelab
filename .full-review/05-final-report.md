# Comprehensive Code Review Report

## Review Target

Full audit of the homelab Ansible collection infrastructure — all three collections (`homelab.common`, `homelab.k3s`, `homelab.proxmox_lxc`), the orchestration layer (`playbooks/`), inventory, scripts, and CI/CD tooling.

---

## Executive Summary

The infrastructure codebase shows strong foundational practices — vault usage is consistent, SSH hardening is comprehensive, and the three-collection architecture is a sound design. However, there is a significant gap between the documented security posture and the actual deployed configuration: TLS certificate validation is globally disabled, a file-based security bypass mechanism exists, and the documented disaster recovery playbook is entirely non-functional. Technical debt is concentrated in copy-pasted patterns across roles (7 duplicated roles, 47 `changed_when: true` instances, verbatim iptables unit blocks in 7 roles) and a silent framework misuse that means phase-skip variables and role opt-out flags have never worked.

---

## Findings by Priority

### Critical Issues (P0 — Must Fix Immediately)

| ID | Phase | Finding |
|----|-------|---------|
| SEC-C3 | Security | TruffleHog GitHub Action pinned to `@main` — secret scanner is itself a supply chain attack vector |
| SEC-C4 | Security | `proxmox_validate_certs: false` globally — all Proxmox API tokens transmitted without TLS verification |
| AR-C1 / SEC-C1 / FW-H1 | Quality/Security/Practices | `when:` on `import_playbook` silently ignored — phase-skip variables have never worked |
| CQ-C3 / SEC-C2 | Quality/Security | `playbooks/rollback.yml` references 3 non-existent files — disaster recovery is completely non-functional |
| CQ-C1 | Quality | 6 K3s roles duplicated into `proxmox_lxc` — never called, silently diverged, ~2,000 lines of dead code |
| CQ-C2 | Quality | `security_hardening` role triplicated — three implementations (common, k3s, proxmox_lxc) now diverged |
| CICD-H2 | CI/CD | `pyproject.toml` requires Python 3.14 (pre-release) while CI runs Python 3.12 |
| CICD-H3 | CI/CD | `make backup` / `make restore` call non-existent playbooks — operators have false confidence in DR capability |
| CICD-H1 | CI/CD | Galaxy API token expanded via Jinja in shell script text — potential secret exposure via `/proc/<pid>/cmdline` |

---

### High Priority (P1 — Fix Before Next Release)

#### Security

| ID | Finding |
|----|---------|
| SEC-H1 | `host_key_checking = False` in `ansible.cfg` — eliminates TOFU protection; combined with `become = True`, any ARP-spoofed host allows arbitrary privileged code execution |
| SEC-H2 | Legacy `password: root@pam` fields in `common/inventory/group_vars/all.yml` — if `vault_proxmox_passwords` is defined, bypasses token-scoped permission restrictions |
| SEC-H3 | `/tmp/bypass_security_checks` (world-writable) disables all deployment safety checks — any process on Ansible controller can trigger this |
| SEC-H4 | `monitoring_agent` deploys amd64 binaries to ARM (Raspberry Pi aarch64) — nodes silently unmonitored |
| SEC-H5 | `step_ca` iptables rules lost on reboot — PKI becomes unreachable → Traefik ACME renewals fail → certificate expiry |
| SEC-H6 | LXC templates downloaded over HTTP without checksum verification — MITM substitution of backdoored template |
| SEC-H7 | Grafana admin password + secret key written to cleartext `/etc/grafana/grafana.ini` |
| SEC-H8 | Enclave router managed with `ansible_user: root` — inconsistent with all other infrastructure |

#### Code Quality & Architecture

| ID | Finding |
|----|---------|
| CQ-H1 | `proxmox_default_node` underscore/hyphen mismatch — latent KeyError in `container_base` on variable precedence change |
| CQ-H2 | Legacy `lxc_container` role duplicates `container_base` — only referenced by deleted legacy playbooks |
| CQ-H3 | Root-level legacy playbooks reference stale hostnames (`unbound-lxc`, `adguard-lxc`) and deprecated roles |
| CQ-H4 | `proxmox_config` defined in 3 separate places with divergent key formats and legacy password fields |
| CQ-H5 | `homelab_domain` defined 4+ times; `homelab_network` DNS differs across 3 files — NAS VMs cannot resolve `*.homelab.local` |
| CQ-H6 | Makefile references non-existent playbooks (`backup.yml`, `performance/local_performance_test.yml`) |
| CQ-H7 | Duplicate enclave playbooks: `secure-enclave.yml` and `enclave.yml` |
| AR-H1 | 6 K3s roles in `proxmox_lxc` use `-lxc` hostnames not in inventory — dead code that misleads |
| AR-H2 | `proxmox_config` key naming mismatch — variable precedence masks a latent KeyError |
| FW-H2 | 7 roles duplicated between `k3s` and `proxmox_lxc` — already diverged silently |
| FW-H3 | `promtail` role: zero FQCN module names, suppressed in `.ansible-lint` |
| FW-H4 | `apt: upgrade: true` in 5 service roles — system upgrade as side effect of any role run |

#### Performance

| ID | Finding | Impact |
|----|---------|--------|
| PERF-C1 | Default `forks = 5` for 20+ managed hosts | 3–8 min wasted per full run |
| PERF-H1 | No fact caching — facts re-gathered every play | 30–90 sec per run |
| PERF-H2 | `container_base` invoked 3–4× per container per full run | 4–13 min wasted |
| PERF-H3 | 40 `apt update_cache: true` calls without `cache_valid_time` | 40–120 sec |
| PERF-H4 | `iptables-save` always `changed_when: true` in 7 roles — copy-pasted | Breaks `--check` mode |
| PERF-H5 | `container_base` SSH fix always `changed_when: true` | Breaks `--check` mode |
| PERF-H6 | AdGuard stops service and deletes config unconditionally every run | DNS outage on every re-run |

#### Testing

| ID | Finding |
|----|---------|
| TEST-H1 | 34 integration test assertions use `ignore_errors: true` with no aggregation — CI shows green even if every service is down |
| TEST-H2 | Smoke test executes zero `proxmox_lxc` service roles — 27 service roles have zero CI execution |
| TEST-H3 | `rescue:` blocks in converge playbooks swallow all role failures — YAML errors, missing vars, wrong module names all produce green |
| TEST-H4 | `when` on `import_playbook` — no test verifies skip variables work (they don't) |
| TEST-H5 | K3s `raspberry-pi` scenario targets undefined groups — agent join never tested |

#### Documentation

| ID | Finding |
|----|---------|
| DOC-H1 | `DYNAMIC_INVENTORY_SETUP.md` says static inventory is "no longer used" — it is actively authoritative |
| DOC-H2 | Legacy files in `SETUP.md` and `docs/PRE_MERGE_CHECKS.md` presented as maintained/active |
| DOC-H3 | Bootstrap sequence absent from quick-start guides — `bootstrap-proxmox.yml` prerequisite undocumented |
| DOC-H4 | `proxmox_config` key naming inconsistency undocumented — which format wins and why is unexplained |
| DOC-H5 | `/tmp/bypass_security_checks` mechanism undocumented in any runbook |

#### CI/CD

| ID | Finding |
|----|---------|
| CICD-M1 | No job timeout on `ci.yml` lint/collections jobs |
| CICD-M3 | First-party GitHub Actions not SHA-pinned |
| CICD-M4 | `make deploy-security` calls deprecated `security-deploy.yml` |
| CICD-M6 | Destructive deploy Makefile targets have no confirmation guard |
| CICD-M9 | No CI check that all three `galaxy.yml` versions are in sync |
| CICD-M10 | No scheduled infrastructure health validation workflow |

---

### Medium Priority (P2 — Plan for Next Sprint)

**Security (9 findings):** `requirements.yml` unpinned collection versions (SEC-M1); missing Grafana cookie security settings (SEC-M2); `NOPASSWD: ALL` sudo in every container (SEC-M3); Traefik dashboard unauthenticated (SEC-M4); WireGuard placeholder keys in defaults with no validation (SEC-M5); K3s kubeconfig fetched without enforcing 0600 permissions (SEC-M6); Enclave DNS to Unbound without rate limiting (SEC-M7); Claude GitHub Actions overly broad permissions (SEC-M8); architecture-hardcoded download URLs in promtail/loki (SEC-M9).

**Code Quality (12 findings):** `changed_when: true` on 47 shell tasks (CQ-M3); `ignore_errors: true` in test playbooks with no summary (CQ-M4); `fix-prometheus-ssh.yml` one-shot hotfix that should be deleted (CQ-M5); `monitoring_agent` amd64 hardcode on ARM (CQ-M6); `container_base` hardcodes `local-lvm` storage (CQ-M7); `promtail` bare module names (CQ-M8); `step_ca` iptables rules not persisted (CQ-M9); `common_setup` DNS check hardcodes external FQDN (CQ-M10); `teardown-secure-enclave.yml` not in Makefile (CQ-M11); legacy password fields in `common/inventory` (CQ-M12); Promtail double-install risk (CQ-M1); `container_defaults` duplicate definition (CQ-M2).

**Architecture (7 findings):** `security_hardening` variable namespace inconsistency (AR-M1); `proxmox_lxc/site.yml` broken orchestration path (AR-M2); container provisioning double-invocation (AR-M3); `monitoring_agent` handler for non-existent service (AR-M4); dual inventory system ambiguity (AR-M5); shared Proxmox API token-parsing logic (AR-M6); orphaned `ubuntu_vm` role (AR-M7).

**Performance (9 findings):** Grafana dashboards `force: true` every run (PERF-M1); Loki/Traefik download not guarded (PERF-M2/M3); `daemon_reload: true` on start tasks instead of handlers (PERF-M4); `common_setup` runs full package install on every invocation (PERF-M5); Proxmox API validation runs 4× in single playbook (PERF-M6); `networking.yml` serial: 1 applied to non-DNS services (PERF-M7); `monitoring_agent` pip without virtualenv/version pins (PERF-M8).

**Testing (6 findings):** Only 1 of 8 molecule scenarios has idempotence enabled (TEST-M1); `proxmox-integration` scenario never runs in CI (TEST-M2); `molecule-notest` tag inert (TEST-M3); `validate-security.yml` assertions incomplete (TEST-M4); `validate-infrastructure.yml` broken group reference masked by `ignore_errors` (TEST-M5); collection-specific molecule scenarios never triggered in CI (TEST-M6).

**Documentation (7 findings):** `SECURITY-ARCHITECTURE.md` claims unimplemented features as active controls including OWASP Dependency Check, CodeQL, and Pod Security Standards (DOC-M1); README references removed molecule scenarios (DOC-M2); `container_base` README documents wrong SSH key path (DOC-M3); no tag taxonomy reference (DOC-M4); NAS VM public DNS undocumented (DOC-M5); `container_base` double-invocation pattern undocumented (DOC-M6); Ansible minimum version inconsistent across files (2.15 vs 2.17) (DOC-M7).

**CI/CD (8 findings):** `galaxy-publish.yml` no job timeout (CICD-M2); `detect-secrets` not in CI (CICD-M5); pre-commit `check-secrets` doesn't scan shell scripts (CICD-M7); `markdownlint-cli2` vs `pymarkdown` divergence (CICD-M8); Renovate `lookupNameTemplate` unreliable (CICD-M11); `validate-docs.sh` broken-link counter broken in subshell (CICD-L4); no `update-systems.yml` workflow (CICD-L10).

---

### Low Priority (P3 — Track in Backlog)

**Security (7 findings):** `ssh-rsa` in HostKeyAlgorithms (SEC-L1); fail2ban ignores broad /16 and /24 subnets (SEC-L2); `become = True` globally (SEC-L3); rollback logs world-readable 0644 (SEC-L4); K3s audit logs Secret values (SEC-L5); Grafana/Traefik metrics open to all sources (SEC-L6); Proxmox firewall blanket ACCEPT rule (SEC-L7).

**Code Quality (3 findings):** `deploy-security` Makefile calls legacy file (CQ-L1); `package.json` undocumented (CQ-L2); `apt: upgrade: true` in promtail role (CQ-L3).

**Architecture (3 findings):** Tag taxonomy inconsistency between root and collection playbooks (AR-L1); NAS VM public DNS undocumented design (AR-L2); inline container resource defaults override group_vars (AR-L3).

**Performance (4 findings):** Two separate `apt install` calls in security_hardening (PERF-L1); 10-second pause before monitoring health checks (PERF-L2); K3s pre-checks use hardcoded IPs (PERF-L3); 6 dead K3s roles parsed on every collection load (PERF-L4).

**Testing (3 findings):** Integration scenario deploys config files but never starts services (TEST-L1); smoke verify asserts inventory vars not role outcomes (TEST-L2); K3s agent count assertion accepts 1/4 nodes (TEST-L3).

**Documentation (3 findings):** `SETUP.md` vault path wrong in quick-start (DOC-L1); CHANGELOG duplicate section headers (DOC-L2); 7 service roles missing README files (DOC-L3).

**CI/CD (10 findings):** molecule-smoke redundant push trigger (CICD-L1); claude-code-review missing concurrency group (CICD-L2); cache key missing OS/Python version (CICD-L3); `security-audit.sh` wrong SECURITY.md path (CICD-L5); `setup-pre-commit.sh` missing `pipefail` (CICD-L6); `lint-fix` target doesn't fix anything (CICD-L7); `ANSIBLE_VERSION` range instead of pin (CICD-L8); empty `package.json` (CICD-L9); `build-publish-collection` installs `yq` unpinned (CICD-L3b); shellcheck severity mismatch between pre-commit and lint.sh.

**Framework (4 findings):** `meta/dependencies` `when:` silently ignored (FW-M2); management CIDR hardcoded in task files (FW-M3); `deprecation_warnings = False` globally (FW-M4); `kubernetes.core` in wrong collection's `requirements.yml` (FW-L4).

---

## Findings by Category

| Category | Critical | High | Medium | Low | Total |
|----------|----------|------|--------|-----|-------|
| Code Quality | 3 | 7 | 12 | 3 | 25 |
| Architecture | 1 | 2 | 7 | 3 | 13 |
| Security | 4 | 8 | 10 | 7 | 29 |
| Performance | 1 | 6 | 9 | 4 | 20 |
| Testing | 0 | 5 | 6 | 3 | 14 |
| Documentation | 1 | 5 | 7 | 3 | 16 |
| Framework/Practices | 2 | 4 | 4 | 4 | 14 |
| CI/CD & DevOps | 3 | 6 | 8 | 10 | 27 |
| **Total** | **15** | **43** | **63** | **37** | **158** |

---

## Recommended Action Plan

### Week 1 — Stop the Bleeding (Critical P0)

1. **[Small] Pin TruffleHog to commit SHA** (`.github/workflows/ci.yml`) — 5 minutes, eliminates supply chain risk in secret scanner
2. **[Small] Delete `playbooks/rollback.yml`** — remove false confidence; document that DR is manual until reimplemented
3. **[Small] Fix `pyproject.toml`** — set `requires-python = ">=3.12"`, fill in description
4. **[Small] Gate broken Makefile targets** with `$(error)` — `backup`, `restore`, `performance`
5. **[Small] Fix Galaxy token CLI reference** — change `${{ env.ANSIBLE_GALAXY_TOKEN }}` to `"$ANSIBLE_GALAXY_TOKEN"` in publish action
6. **[Medium] Remove `when:` from all `import_playbook` directives** — update docs to clarify `--tags` is the skip mechanism; audit if any skip behaviour was actually needed and implement via play-level early exit
7. **[Medium] Delete 6 duplicate K3s roles from `proxmox_lxc`** — no root playbook references them
8. **[Medium] Consolidate `security_hardening`** — single role in `homelab.common` with firewall backend variable

### Week 2 — Security Hardening

9. **[Small] Add `cache_valid_time: 3600`** to all apt tasks without it
10. **[Small] Fix `host_key_checking`** — set `True` in `ansible.cfg`, add `known_hosts` management to bootstrap
11. **[Small] Remove legacy `password:` fields** from `common/inventory/group_vars/all.yml`
12. **[Small] Replace `/tmp/bypass_security_checks`** with required extra-var
13. **[Medium] Fix LXC template downloads** — `https://` URLs + `checksum:` parameter
14. **[Medium] Fix `monitoring_agent` architecture detection** — `{{ 'arm64' if ansible_architecture == 'aarch64' else 'amd64' }}`
15. **[Medium] Fix `step_ca` iptables persistence** — add `iptables-restore.service` (copy from wireguard role)
16. **[Small] Move Grafana secret_key** to environment variable; remove from `grafana.ini`

### Week 3 — Performance & Idempotency

17. **[Small] Add `forks = 15`** to `ansible.cfg` — single line, 3–8 min savings
18. **[Small] Add fact caching** to `ansible.cfg` — two lines, 30–90 sec savings
19. **[Medium] Fix `changed_when: true`** on the 5 most-used instances (iptables-save pattern) — extract shared handler to `homelab.common`
20. **[Medium] Fix AdGuard unconditional stop/delete** — move to handler pattern
21. **[Small] Add `container_provisioned` sentinel** to gate phases 2–4 `container_base` re-invocation
22. **[Small] Split `networking.yml`** into DNS play (serial: 1) and non-DNS play (parallel)

### Sprint 1 — Test Coverage

23. **[Medium] Fix `ignore_errors` in validate playbooks** — replace with `failed_when: false` + results registration + summary assertion that fails on any degraded service
24. **[Medium] Fix `rescue:` blocks in converge playbooks** — add `fail:` task inside rescue blocks so test failures surface
25. **[Small] Fix K3s `raspberry-pi` molecule scenario** — add `k3s_agents` and `raspberry_pi_test` groups to `molecule.yml`
26. **[Medium] Enable idempotence testing** once `changed_when: true` issues are fixed

### Sprint 2 — Documentation & Cleanup

27. **[Small] Fix `DYNAMIC_INVENTORY_SETUP.md`** — static inventory is authoritative, correct the claim
28. **[Small] Add bootstrap sequence** to `SETUP.md` and `INSTALLATION.md` quick-start
29. **[Small] Fix vault path in quick-start** docs (3 files) — `inventory/group_vars/all/vault.yml.example`
30. **[Small] Remove or deprecate** `phase2-security.yml`, `security-deploy.yml`, `secure-enclave.yml`, `fix-prometheus-ssh.yml`
31. **[Small] Fix `container_base` README** — update SSH key path from `id_rsa.pub` to `homelab_ed25519.pub`
32. **[Small] Update `SECURITY-ARCHITECTURE.md`** — mark unimplemented features (CodeQL, OWASP Dependency Check, Pod Security Standards) as planned, not active
33. **[Medium] Create tag taxonomy reference** in `docs/TAGS.md`

### Ongoing — CI/CD Hardening

34. **[Small] Add galaxy.yml version sync check** to CI lint job
35. **[Small] Add job timeouts** to all CI workflows
36. **[Small] Fix `validate-docs.sh` subshell bug** — use process substitution
37. **[Small] Add `workflow_dispatch` workflows** for `update-systems.yml` and infrastructure health check
38. **[Small] Standardise markdown linter** — `markdownlint-cli2` in both pre-commit and CI
39. **[Small] Fix `security-audit.sh` SECURITY.md path** and `setup-pre-commit.sh` `pipefail`

---

## Review Metadata

- **Review date:** 2026-03-16
- **Phases completed:** 1 (Code Quality & Architecture), 2 (Security & Performance), 3 (Testing & Documentation), 4 (Best Practices & CI/CD), 5 (Consolidated Report)
- **Flags applied:** framework=ansible
- **Total findings:** 158 across 8 categories
- **Critical (P0):** 15 | **High (P1):** 43 | **Medium (P2):** 63 | **Low (P3):** 37
