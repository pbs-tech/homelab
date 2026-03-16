# Phase 2: Security & Performance Review

---

## Security Findings

### Critical

#### SEC-C1: `when` on `import_playbook` silently ignored — security phases cannot be skipped safely
**CWE:** CWE-670 | **File:** `playbooks/infrastructure.yml` lines 37, 44, 51, 59

Ansible does not evaluate `when` on `import_playbook`. The `skip_networking`, `skip_monitoring`, `skip_applications`, `skip_k3s` variables have zero effect. Operators believe they can selectively skip phases during incidents, but cannot. Also prevents safe ordering enforcement.

**Fix:** Remove all `when` clauses. Use tags for selective execution (already supported). Document this explicitly.

---

#### SEC-C2: Broken rollback playbook — disaster recovery is non-functional
**CWE:** CWE-754 | **File:** `playbooks/rollback.yml` lines 132, 211, 237

References `rollback_{{ item }}.yml` task files (none exist), `tests/test_suite.yml` (doesn't exist), and `rollback_report.html.j2` template (doesn't exist). Fails at every step. False confidence in recovery capability.

**Fix:** Delete or fully implement. A non-functional DR tool is worse than none.

---

#### SEC-C3: TruffleHog GitHub Action pinned to `@main` — CI supply chain vulnerability
**CWE:** CWE-829 | **File:** `.github/workflows/ci.yml` line 107

`trufflesecurity/trufflehog@main` — mutable branch reference. A compromise of the TruffleHog repo executes arbitrary code in CI with access to the repository and secrets. Deeply ironic: the secret-scanning tool becomes the exfiltration vector.

**Fix:** Pin to a specific commit SHA. Apply same practice to `anthropics/claude-code-action@v1`.

---

#### SEC-C4: Proxmox TLS certificate validation globally disabled
**CWE:** CWE-295 | **Files:** `common/inventory/group_vars/all.yml` line 64, `inventory/group_vars/lxc_containers.yml` lines 31/40, `proxmox_lxc/inventory/proxmox.yml` line 15

`proxmox_validate_certs: false` across all locations. All Proxmox API calls (carrying API tokens) over HTTPS without certificate verification. Comments in code say "CHANGE TO true FOR PRODUCTION" — this is production.

**Attack scenario:** ARP spoofing → intercept API calls → capture tokens → full Proxmox control.

**Fix:** Generate proper TLS certs for Proxmox hosts via step-ca or Let's Encrypt. Set `proxmox_validate_certs: true`.

---

### High

#### SEC-H1: SSH host key checking disabled globally
**CWE:** CWE-345 | **File:** `ansible.cfg` line 7

`host_key_checking = False` — eliminates TOFU protection for all Ansible connections. Combined with global `become = True`, ARP spoofing of any managed host allows arbitrary privileged code execution.

**Fix:** `host_key_checking = True`. Distribute known_hosts file in repo. Manage keys with `ansible.builtin.known_hosts` during bootstrap.

---

#### SEC-H2: Legacy Proxmox password fields — fallback authentication bypass
**CWE:** CWE-287 | **File:** `common/inventory/group_vars/all.yml` lines 31, 42

`password: "{{ vault_proxmox_passwords.pve_mac | default('') }}"` — if `vault_proxmox_passwords` is defined, any code path using `proxmox_config[node].password` authenticates as `root@pam` with full privileges, bypassing token-scoped permission restrictions.

**Fix:** Remove `password` fields entirely. Add a guard task that fails if `vault_proxmox_passwords` is defined.

---

#### SEC-H3: Security bypass via world-writable tmpfile
**CWE:** CWE-732 | **File:** `proxmox_lxc/tasks/bypass_security_checks.yml` lines 6-9

Creating `/tmp/bypass_security_checks` (world-writable directory) disables all security prerequisite checks. Even documented in the failure message: "touch /tmp/bypass_security_checks". Any user or cron job on the Ansible controller can trigger this.

**Fix:** Replace with a required extra-var (`-e bypass_security_checks=true`). Creates an auditable trail in CI logs.

---

#### SEC-H4: `monitoring_agent` deploys amd64 binaries to ARM (Raspberry Pi) nodes
**CWE:** CWE-1024 | **File:** `common/roles/monitoring_agent/tasks/main.yml` lines 47, 98

node_exporter and promtail download URLs hardcoded to `linux-amd64`. K3s cluster runs aarch64 Raspberry Pis. Wrong binaries fail silently with `exec format error`, leaving Pi nodes unmonitored — extending attacker dwell time.

**Fix:** `{{ 'arm64' if ansible_architecture == 'aarch64' else 'amd64' }}` — pattern already used in `airgap` role.

---

#### SEC-H5: `step_ca` iptables rules lost on reboot — PKI becomes unreachable
**CWE:** CWE-754 | **File:** `proxmox_lxc/roles/step_ca/tasks/main.yml` lines 242-261

Saves iptables rules but doesn't install `iptables-persistent` or create a restore service. `wireguard` and `traefik` roles already handle this correctly with `iptables-restore.service`. After reboot: port 8443 blocked → Traefik ACME renewals fail → certificates expire → users train themselves to click through TLS warnings.

**Fix:** Add the same `iptables-restore.service` pattern as wireguard/traefik roles.

---

#### SEC-H6: LXC templates downloaded over HTTP without integrity verification
**CWE:** CWE-494 | **File:** `proxmox_lxc/roles/lxc_template/defaults/main.yml` lines 5, 10, 15

All three templates use `http://download.proxmox.com/...` with no `checksum:` parameter. MITM attacker substitutes backdoored template → every container created from it is compromised.

**Fix:** Change to `https://`. Add `checksum: "sha256:<hash>"`. Proxmox publishes checksums.

---

#### SEC-H7: Grafana admin password written to cleartext config file
**CWE:** CWE-312 | **File:** `proxmox_lxc/roles/grafana/templates/grafana.ini.j2` line 28

`admin_password = {{ grafana_admin_password }}` and `secret_key` both written to `/etc/grafana/grafana.ini`. The secret key allows forging session tokens. The grafana-cli reset command already sets the password separately — the ini file entry is redundant.

**Fix:** Use a dummy value in ini, set password via grafana-cli only. Move secret_key to `GF_SECURITY_SECRET_KEY` environment variable in a restricted EnvironmentFile.

---

#### SEC-H8: Enclave router provisioned with `ansible_user: root`
**CWE:** CWE-250 | **File:** `proxmox_lxc/roles/secure_enclave/tasks/router.yml` line 95

The enclave router (dual-homed between management and isolated networks) is added to inventory with `ansible_user: root`. Inconsistent with entire rest of infrastructure using `ansible` user + `become`. Compromise of this node trivially allows lateral movement.

**Fix:** Create `ansible` user on router via container_base. Use `ansible_user: ansible` + `ansible_become: true`.

---

### Medium

#### SEC-M1: Collection dependencies use `>=` version bounds — not pinned
`requirements.yml` — all external collections use `>=` version constraints. Pulls any newer potentially breaking/vulnerable version.
**Fix:** Pin to specific versions. Use Renovate/Dependabot for managed upgrades.

---

#### SEC-M2: Grafana missing `cookie_secure` and `cookie_samesite`
`grafana/templates/grafana.ini.j2` — session cookies sent over any connection.
**Fix:** Add `cookie_secure = true` and `cookie_samesite = lax` to `[security]` section.

---

#### SEC-M3: `NOPASSWD: ALL` sudo granted to `ansible` and `pbs` users in every container
`common/roles/container_base/tasks/main.yml` lines 321, 388 — two unrestricted sudo accounts per container.
**Fix:** Restrict to specific commands: `NOPASSWD: /usr/bin/apt-get, /usr/bin/systemctl, /usr/bin/tee, ...`

---

#### SEC-M4: Traefik dashboard exposed on port 8080 without authentication
`proxmox_lxc/roles/traefik/defaults/main.yml` — dashboard enabled, port opened to any source. Exposes full routing config.
**Fix:** Add BasicAuth middleware, or restrict UFW/iptables rule to `src: 192.168.0.0/24`.

---

#### SEC-M5: WireGuard `REPLACE_WITH_ACTUAL_*` placeholder keys in defaults
`proxmox_lxc/roles/wireguard/defaults/main.yml` lines 21-32 — if operator forgets to override, invalid peers configured silently.
**Fix:** Add assertion that fails if any client key contains "REPLACE". Move client definitions to vault.

---

#### SEC-M6: K3s kubeconfig fetched without enforcing permissions
`k3s/roles/k3s_server/tasks/main.yml` lines 159-163 — `fetch` module does not set permissions; file may be world-readable (umask 022).
**Fix:** Add post-fetch task: `ansible.builtin.file: path: ~/.kube/config mode: "0600"`.

---

#### SEC-M7: Enclave DNS allowed to Unbound — potential exfiltration channel
`proxmox_lxc/roles/secure_enclave/tasks/network_isolation.yml` line 31 — DNS to 192.168.0.202 explicitly allowed through isolation boundary.
**Fix:** Rate-limit DNS queries from enclave: `iptables -m limit --limit 50/sec`.

---

#### SEC-M8: Claude GitHub Actions workflows — overly broad permissions, `@claude` triggerable by any commenter
`.github/workflows/claude.yml` and `claude-code-review.yml` — `id-token: write` granted; any user can trigger `@claude` mentions; no author filtering.
**Fix:** Add org/team membership filter. Remove unused `id-token: write`. Pin action to commit SHA.

---

#### SEC-M9: `promtail` and `loki` roles hardcode amd64 download URLs
`proxmox_lxc/roles/promtail/tasks/main.yml` line 44, `loki/tasks/main.yml` line 47.
**Fix:** Use architecture detection variable, consistent with `airgap` role pattern.

---

#### SEC-M10: step-ca CA password generated on target, not stored in vault — lost on rebuild
`proxmox_lxc/roles/step_ca/tasks/main.yml` lines 155-171 — `/dev/urandom` on target, 0600 local file, no vault integration.
**Fix:** Generate locally, store in vault, deploy to target.

---

### Low

- **SEC-L1:** `ssh-rsa` in `HostKeyAlgorithms` — replace with `rsa-sha2-256,rsa-sha2-512` or remove RSA
- **SEC-L2:** fail2ban `ignoreip` includes entire /16 and /24 subnets — narrow to specific management IPs
- **SEC-L3:** `become = True` globally in `ansible.cfg` — should default to False, opt-in per task
- **SEC-L4:** Rollback log files created with 0644 (world-readable) — use 0600
- **SEC-L5:** K3s audit policy logs `RequestResponse` for all resources — could log Secret values; exclude secrets
- **SEC-L6:** Grafana (3000) and Traefik metrics (8082) open to all sources — add `-s 192.168.0.0/24`
- **SEC-L7:** Container Proxmox firewall has blanket `ACCEPT -source 192.168.0.0/24` rule — negates all other security groups

### Positive Observations
- Vault usage is consistent — all secrets reference `vault_*` variables, vault file is AES256-encrypted
- `no_log: true` applied in 32+ sensitive task instances
- Containers unprivileged by default
- SSH hardening is comprehensive (password auth disabled, Ed25519, modern cipher suites)
- WireGuard private key handling is correct — on-target generation, 0600, no_log
- Enclave ENCLAVE_FORWARD chain with iptables-restore.service is well-designed
- K3s token handling uses `no_log` throughout

---

## Performance Findings

### Critical

#### PERF-C1: No `forks` setting — default parallelism of 5
**File:** `ansible.cfg` | **Estimated impact: 3–8 minutes on full run**

With 20+ managed hosts, default `forks = 5` serialises plays unnecessarily. Phases 3 and 4 target 6+ hosts each with no inter-dependency.

**Fix (one line):** Add `forks = 15` to `ansible.cfg [defaults]`.

---

### High

#### PERF-H1: No fact caching — facts re-gathered on every play
**File:** `ansible.cfg` | **Estimated impact: 30–90 seconds per full run**

No `fact_caching` configured. Every play re-collects all facts. In a full run: foundation (proxmox), networking, k3s (4 plays × 4 nodes = 16 gather rounds), monitoring.

**Fix (two lines):**
```ini
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible-facts-cache
fact_caching_timeout = 7200
```

---

#### PERF-H2: `container_base` invoked 3–4× per container per full run
**Files:** `provision-containers.yml`, `networking.yml` (pre_tasks), `monitoring.yml` (pre_tasks ×2), `applications.yml` (pre_tasks) | **Estimated impact: 4–13 minutes wasted**

Each invocation makes 6+ Proxmox API round-trips. Phase 1 already provisions all containers; phases 2-4 pre_tasks are redundant in a full run.

**Fix:** Set a host fact `container_provisioned: true` at end of `provision-containers.yml`. Gate phases 2-4 pre_tasks with `when: not (container_provisioned | default(false))`.

---

#### PERF-H3: 40 `apt update_cache: true` calls, several without `cache_valid_time`
**Files:** `grafana/tasks/main.yml` lines 19/52, `loki/tasks/main.yml` line 3, `traefik/tasks/main.yml` line 20, `prometheus/tasks/main.yml` line 2 | **Estimated impact: 40–120 seconds**

`common_setup` already refreshes the cache with `cache_valid_time: 3600`. Service roles should rely on it. `grafana` calls `update_cache: true` twice in the same role.

**Fix:** Add `cache_valid_time: 3600` to all service role apt tasks, or remove `update_cache: true` from roles that run after `common_setup`.

---

#### PERF-H4: `iptables-save` always `changed_when: true` — 5 roles, copy-pasted
**Files:** `traefik:177`, `wireguard:292`, `unbound:168`, `adguard:329`, `bastion:86`, `security_hardening/configure_iptables.yml:86`

Always reports changed → downstream handlers fire every run → breaks `--check` mode. The 15-line `iptables-restore.service` block is also copy-pasted identically across all 5 roles.

**Fix:** Extract to a shared handler in `homelab.common`. Use stdout sentinel for idempotent `changed_when`.

---

#### PERF-H5: `container_base` SSH fix always `changed_when: true`
**File:** `common/roles/container_base/tasks/main.yml:256`

Runs and reports changed on every invocation for every container. Breaks `--check` mode, triggers change notifications.

**Fix:** Emit a sentinel in the shell script on actual change; use `changed_when: "'changed' in result.stdout"`.

---

#### PERF-H6: AdGuard stops service and deletes config unconditionally every run
**File:** `proxmox_lxc/roles/adguard/tasks/main.yml` lines 173-186

`state: stopped` + `file: state: absent` for config files fires unconditionally regardless of whether anything changed. Causes a DNS outage on every idempotent re-run.

**Fix:** Use `notify: Restart adguard` from the template task only. Remove the unconditional stop/delete.

---

### Medium

#### PERF-M1: Grafana dashboards downloaded with `force: true` every run
**File:** `grafana/tasks/dashboards.yml:28` | **Estimated impact: 30–60 seconds**

`force: true` bypasses HTTP `If-Modified-Since`. Dashboards re-downloaded and re-imported on every run.
**Fix:** Remove `force: true`. Consider storing dashboards in repo instead.

---

#### PERF-M2: Loki binary download not guarded — re-downloads when `/tmp` is cleaned
**File:** `loki/tasks/main.yml:45` | **Estimated impact: 30–60 seconds**

No `creates:` guard. Static `/tmp/loki.zip` filename without version. After reboot, always re-downloads.
**Fix:** Version the filename, add `stat` check against installed binary before downloading (same pattern as `alertmanager`).

---

#### PERF-M3: Traefik binary download not guarded — static `/tmp` filename
**File:** `traefik/tasks/main.yml:53` | **Estimated impact: 20–40 seconds**

Same issue as Loki. `/tmp/traefik.tar.gz` without version; no existence check.
**Fix:** Version filename, check installed version matches target version before downloading.

---

#### PERF-M4: Unconditional `daemon_reload: true` on `state: started` tasks (~60 occurrences)
**Files:** `loki:98`, `prometheus:144`, `bastion:110`, `adguard:242`, `unbound:133`, `wireguard:321`, +15 more

`daemon_reload: true` on a start task fires on every run. Should only fire when unit files change (i.e., from a handler).
**Fix:** Remove `daemon_reload: true` from `state: started` tasks. Move it to the handler notified by the service file template task.

---

#### PERF-M5: `common_setup` DNS wait + package install runs on every play invocation
**File:** `common/roles/common_setup/tasks/main.yml` | **Estimated impact: 10–30 seconds per container**

`wait_for` TCP probe, `getent` with 5 retries × 10s delay, full `apt install` — all run on every invocation even when the container is already configured.
**Fix:** Write a sentinel file (`/etc/ansible-common-setup-done`) on first run; gate subsequent runs with a `stat` check.

---

#### PERF-M6: `provision-containers.yml` has 4 plays each re-running Proxmox API validation
**File:** `playbooks/provision-containers.yml` | **Estimated impact: 8–16 seconds**

`run_once: true` scopes to the play, not playbook. API validation runs 4× for each of the 4 group plays.
**Fix:** Consolidate into a single play targeting `lxc_containers` group.

---

#### PERF-M7: `networking.yml` applies `serial: 1` to all networking hosts including non-DNS services
**File:** `playbooks/networking.yml` | **Estimated impact: 3–5 minutes**

Serial deployment is needed for DNS services (port 53 conflict). WireGuard, step-ca, OpenWrt have no such constraint but inherit the serial limit.
**Fix:** Split into DNS play (`serial: 1`) and non-DNS networking play (parallel).

---

#### PERF-M8: `monitoring_agent` pip installs system packages without virtualenv or version pins
**File:** `common/roles/monitoring_agent/tasks/main.yml`

Probes PyPI every run for version currency. Breaks on Ubuntu 23.04+ (PEP 668 enforcement).
**Fix:** Pin versions, use `virtualenv: /opt/monitoring-agent/venv`.

---

#### PERF-M9: Molecule idempotence check disabled for `proxmox_lxc`
**File:** `proxmox_lxc/molecule/default/molecule.yml`

Idempotence step absent due to the `changed_when: true` bugs above — symptom masking rather than fixing.
**Fix:** Fix the `changed_when: true` issues, then re-enable idempotence testing.

---

### Low

- **PERF-L1:** `security_hardening` has two separate `apt install` calls for packages differing by one item — consolidate with conditional list
- **PERF-L2:** 10-second unconditional `pause` per monitoring host before health checks — remove, rely on `uri` retry loop
- **PERF-L3:** K3s pre-checks use hardcoded IPs instead of `hostvars` inventory references — brittle
- **PERF-L4:** 6 dead K3s roles in `proxmox_lxc` collection parsed on every collection load — remove

---

## Critical Issues for Phase 3 Context

The following findings affect testing and documentation requirements:

1. **SEC-C1 + PERF findings** (`when` on `import_playbook`): Test playbooks cannot rely on skip variables — tests must verify all phases execute.
2. **SEC-H3** (bypass_security_checks via tmpfile): Test infrastructure should verify the bypass mechanism cannot be triggered in CI.
3. **SEC-C3** (TruffleHog `@main`): CI security scanning itself is a supply chain risk — testing findings can't fully be trusted until this is resolved.
4. **PERF-M9** (Molecule idempotence disabled): `proxmox_lxc` role testing has a significant coverage gap.
5. **SEC-H4 / PERF-L4** (monitoring_agent amd64 on ARM): Tests only run on x86 CI — ARM-specific failures are invisible.
6. **SEC-C2** (broken rollback): No tested recovery path exists — DR documentation is inaccurate.
