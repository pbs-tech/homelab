# Phase 3: Testing & Documentation Review

---

## Test Coverage Findings

### Critical

#### TEST-C1: `rollback.yml` completely broken with zero test coverage
`playbooks/rollback.yml` line 132 calls `rollback_{{ item }}.yml` task files that don't exist. `common/tasks/` contains only 3 unrelated files. Also references non-existent `tests/test_suite.yml` and `rollback_report.html.j2`. No molecule scenario, no validate-*.yml, no CI job has ever tested this playbook. A non-functional DR tool with false confidence.

---

#### TEST-C2: `monitoring_agent` amd64 bug invisible in CI — rescue block masks failure
The smoke test wraps `monitoring_agent` in a `rescue:` block that swallows all failures. CI only runs on `ubuntu-latest` (x86_64). Wrong-architecture binaries deploying to Raspberry Pi (aarch64) nodes have never been caught. No test asserts architecture-awareness in download URLs.

---

#### TEST-C3: `bypass_security_checks` tmpfile — no CI guard
`/tmp/bypass_security_checks` (world-writable) disables all security prerequisite checks. No CI step verifies the file doesn't exist in the runner environment. Any stray process could silently disable all deployment safety checks.

---

### High

#### TEST-H1: All 34 integration test assertions use `ignore_errors: true` with no result aggregation
`validate-services.yml` (13 HTTP checks), `validate-infrastructure.yml`, `validate-enclave.yml` (12 instances), `quick-smoke-test.yml` — every check uses `ignore_errors: true`, gates assertions on `when: X is succeeded`, and prints a DEGRADED/HEALTHY message to stdout only. **CI pipeline shows green even if every service is down.** No task ever raises a non-zero exit code on failure.

---

#### TEST-H2: Smoke test executes zero `proxmox_lxc` service roles
Root `molecule/smoke/converge.yml` — the proxmox_lxc section does only `ansible.builtin.stat` calls on localhost to verify directories exist. 27 service roles (`prometheus`, `grafana`, `traefik`, `loki`, `alertmanager`, `adguard`, `unbound`, `wireguard`, `homeassistant`, `sonarr`, `radarr`, `bazarr`, `prowlarr`, `qbittorrent`, `jellyfin`, etc.) have **zero execution** in CI. The `verify.yml` asserts only that inventory variables from `molecule.yml` group_vars are defined — it validates Ansible's own inventory reading, not any role outcome.

---

#### TEST-H3: Rescue-block anti-pattern masks all role failures in converge playbooks
`molecule/smoke/converge.yml` and `common/molecule/common-roles/converge.yml` wrap role executions in `rescue:` blocks with only a `debug:` message. YAML parse errors, missing variables, wrong module names — all produce a green result. There is no scenario where a rescue block in a test is appropriate without a subsequent `fail:` or `assert:`.

---

#### TEST-H4: `when` on `import_playbook` silently ignored — no test covers it
No test exercises or validates the behaviour of `skip_networking`, `skip_monitoring`, etc. `ansible-lint` may warn but is not confirmed to be configured to error on this. Users relying on skip variables get no feedback that they don't work.

---

#### TEST-H5: K3s `raspberry-pi` scenario has ghost groups — plays run against zero hosts
`k3s/molecule/raspberry-pi/molecule.yml` defines only `k3s_servers`. `converge.yml` targets `k3s_agents` and `raspberry_pi_test` (both undefined). Agent join — the most failure-prone K3s step — has never been tested. Security hardening play for Pi nodes runs against no hosts.

---

### Medium

#### TEST-M1: Only 1 of 8 molecule scenarios has the idempotence step enabled
| Scenario | Idempotence | Notes |
|---|---|---|
| `common/default` | ✅ Yes | Only one |
| `common/common-roles` | ❌ No | No justification |
| `k3s/default` | ❌ No | Partially valid for install tasks only |
| `k3s/raspberry-pi` | ❌ No | No justification |
| `proxmox_lxc/default` | ❌ No | Blanket justification covers 27 untested roles |
| `proxmox_lxc/integration` | ❌ No | — |
| `proxmox_lxc/media-services` | ❌ No | — |
| `molecule/smoke` | ❌ No | — |

The 47 `changed_when: true` bugs are directly masked by missing idempotence checks.

---

#### TEST-M2: `proxmox-integration` scenario (best test in the collection) never runs in CI
`proxmox_lxc/molecule/proxmox-integration/` — the verify step does real end-to-end testing (log injection → Loki query). Uses `driver: default, managed: false` with hardcoded live IPs. Not in any CI matrix. No documented procedure for running it. No conditional CI path using repository secrets.

---

#### TEST-M3: `molecule-notest` tag applied but never configured in molecule provisioner
`security_hardening/tasks/main.yml` applies `tags: [molecule-notest]` to package install tasks. No `molecule.yml` sets `skip_tags: [molecule-notest]`. Tag is inert decoration — tasks run regardless. Contributors believe it causes skipping when it does not.

---

#### TEST-M4: `validate-security.yml` assertions are incomplete
SSH check only verifies `PermitRootLogin no` and `PasswordAuthentication no` — omits `ChallengeResponseAuthentication`, `X11Forwarding`, `MaxAuthTries`, `AllowUsers`, `PubkeyAuthentication`. SSL check uses `validate_certs: false` and only checks HTTP reachability, never the certificate subject/expiry/chain. Vault variables are never tested for presence or policy compliance.

---

#### TEST-M5: `validate-infrastructure.yml` has broken group reference
Line 120 references `groups['server']` — the inventory group is `k3s_server`. The task `systemd: name: "{{ 'k3s' if inventory_hostname in groups['server'] else 'k3s-agent' }}"` will either raise `AnsibleUndefinedVariable` or assign all nodes as agents. Wrapped in `ignore_errors: true` — never surfaced.

---

#### TEST-M6: Individual collection molecule scenarios never triggered in CI
`ci.yml` runs `galaxy-importer` validation and the smoke scenario only. The collection-specific scenarios (`common/default`, `common/common-roles`, `k3s/default`, `proxmox_lxc/default`, etc.) are not in any CI workflow trigger. The most meaningful collection-level tests never run automatically.

---

### Low

#### TEST-L1: `proxmox_lxc/integration` scenario deploys config files but never starts services
`converge.yml` manually creates config files with inline YAML. `verify.yml` checks those same files exist. This tests the test's own `copy` tasks, not the actual roles.

#### TEST-L2: Smoke verify asserts inventory variables, not role outcomes
All `smoke-proxmox` verify assertions check values injected directly from `molecule.yml` group_vars — these are always true regardless of whether any role ran.

#### TEST-L3: K3s agent node count assertion only requires `>= 1` node
Even in a 4-node scenario, agent join failure goes undetected as long as the server formed.

---

## Documentation Findings

### Critical

#### DOC-C1: `when` on `import_playbook` not documented — skip variables advertised as functional
`CLAUDE.md`, `README.md`, `SETUP.md`, `INSTALLATION.md`, and `playbooks/infrastructure.yml` inline comments are all silent on this Ansible limitation. Operators who pass `-e skip_monitoring=true` during an incident get no warning and no skip — full deployment proceeds. This is the most dangerous documentation gap.

---

### High

#### DOC-H1: `DYNAMIC_INVENTORY_SETUP.md` says static inventory is "no longer used" — false
Line 55: "The old static inventory (`inventory/hosts.yml`) has been kept for reference but is **no longer used**." The static inventory is actively authoritative for all root playbooks. A new operator following this document could delete `inventory/hosts.yml`, breaking all deployments.

---

#### DOC-H2: Legacy files partially deprecated in docs but still referenced as active
`SETUP.md` line 318 still recommends `playbooks/secure-enclave.yml` without deprecation notice. `docs/PRE_MERGE_CHECKS.md` lines 224/310-311 includes `security-deploy.yml` and `phase2-security.yml` in its syntax-check loop — implying maintained status. No deprecation header in the files themselves.

---

#### DOC-H3: Bootstrap sequence absent from quick-start guides
`SETUP.md` and `INSTALLATION.md` jump directly to Phase 1 deployment without mentioning `playbooks/bootstrap-proxmox.yml`. On fresh install, Proxmox hosts have no `ansible` user — `infrastructure.yml` fails immediately. This critical prerequisite is buried in `docs/CONTAINER-PROVISIONING.md` and project memory, not in the quick-start path.

---

#### DOC-H4: `proxmox_config` key naming inconsistency undocumented
`inventory/group_vars/lxc_containers.yml` uses hyphen keys (`pve-mac`, `pve-nas`). `container_base` role defaults use dot notation (`proxmox_config.pve_mac` — underscore). `container_base/README.md` example at line 130 shows underscore keys. No documentation explains the conflict or which wins and why. This is a latent KeyError waiting to surface.

---

#### DOC-H5: `bypass_security_checks` mechanism undocumented in user-facing docs
The `/tmp/bypass_security_checks` file mechanism appears only inside task source code (buried in failure message text). Not in any runbook, troubleshooting guide, or operational doc. Operators needing to bypass during recovery must read source code to discover it.

---

### Medium

#### DOC-M1: `SECURITY-ARCHITECTURE.md` claims unimplemented features as active controls
- Claims "TLS everywhere / Zero Trust Networking" — but `proxmox_validate_certs: false` is hardcoded everywhere with "CHANGE TO true FOR PRODUCTION" comments
- Claims "OWASP Dependency Check" and "CodeQL" in CI — neither workflow exists in `.github/workflows/`
- Claims "Pod Security Standards: restricted" and "Network Policies: default deny" for K3s — not enforced in `k3s_server` defaults

---

#### DOC-M2: `README.md` references non-existent molecule scenarios
Lines 327-333 document `molecule test -s service-stack` and `cd molecule/full-stack/ && molecule test` — both removed per CLAUDE.md. README not updated when scenarios were removed.

---

#### DOC-M3: `container_base` README documents wrong SSH key path (`id_rsa.pub`)
Lines 130 and 367 show `~/.ssh/id_rsa.pub`. Actual key is `~/.ssh/homelab_ed25519.pub`. Same stale path in `roles/lxc_container/README.md` line 75. Following these examples creates containers with empty/wrong SSH keys.

---

#### DOC-M4: No complete tag taxonomy reference
28+ tags spread across playbooks with no single reference document. Operators wanting to redeploy only Grafana or only DNS must read playbook sources.

---

#### DOC-M5: NAS VM DNS using public resolvers — undocumented intentional design
`inventory/group_vars/nas_vm.yml` uses `1.1.1.1`/`1.0.0.1`. NAS VMs cannot resolve `*.homelab.lan`. No comment or doc explains whether this is intentional (ISO-install bootstrap) or an oversight.

---

#### DOC-M6: `container_base` double-invocation pattern undocumented
Phases 2-4 pre_tasks silently re-provision containers that phase 1 already provisioned. No documentation explains the dual-invocation pattern, the idempotency reliance, or the Proxmox module version dependency.

---

#### DOC-M7: Ansible minimum version inconsistent across files (2.15 vs 2.17)
`README.md` and `INSTALLATION.md`: 2.17+. Collection READMEs: >= 2.15.0. `infrastructure.yml` runtime assert: 2.15. Three different values.

---

### Low

#### DOC-L1: `SETUP.md` vault file path wrong in quick-start
Line 83: `inventory/group_vars/vault.yml.example` (doesn't exist). Actual: `inventory/group_vars/all/vault.yml.example`. Same error in `CLAUDE.md` line 238 and `INSTALLATION.md` line 277. First `cp` command in quick-start fails.

#### DOC-L2: CHANGELOG has duplicate `### Changed` section headers (lines 31 and 49)
Violates Keep a Changelog format.

#### DOC-L3: Several service roles missing README files
`proxmox_lxc/roles/grafana/`, `loki/`, `wireguard/`, `prometheus/`, `openwrt/`. `common/roles/monitoring_agent/`, `common_setup/`. All other roles have READMEs.
