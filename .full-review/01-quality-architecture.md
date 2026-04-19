# Phase 1: Code Quality & Architecture Review

---

## Code Quality Findings

### Critical

#### CQ-C1: Massive role duplication — 6 K3s roles fully copied from `k3s` into `proxmox_lxc`
**Severity:** Critical
**Files:**
- `ansible_collections/homelab/proxmox_lxc/roles/k3s_server/`
- `ansible_collections/homelab/proxmox_lxc/roles/k3s_agent/`
- `ansible_collections/homelab/proxmox_lxc/roles/k3s_upgrade/`
- `ansible_collections/homelab/proxmox_lxc/roles/airgap/`
- `ansible_collections/homelab/proxmox_lxc/roles/prereq/`
- `ansible_collections/homelab/proxmox_lxc/roles/raspberrypi/`

Six K3s-specific roles exist as near-identical copies in both `homelab.k3s` and `homelab.proxmox_lxc`. Diffs show only trivial whitespace/formatting differences. These roles have no relevance to Proxmox LXC management, are never imported by any root playbook, and create drift risk.

**Fix:** Delete all 6 from `proxmox_lxc`. Removes ~2,000 lines of duplicate code.

---

#### CQ-C2: `security_hardening` role triplicated across all three collections
**Severity:** Critical
**Files:**
- `ansible_collections/homelab/common/roles/security_hardening/`
- `ansible_collections/homelab/k3s/roles/security_hardening/`
- `ansible_collections/homelab/proxmox_lxc/roles/security_hardening/`

The `common` and `k3s` copies are nearly identical (same task files, same variable namespace `pi_security_hardening`). The `proxmox_lxc` variant uses `iptables` instead of `ufw` and a different variable namespace (`security_hardening`). The canonical copy should live only in `common`.

**Fix:** Consolidate into `homelab.common.security_hardening` with a variable to control firewall backend (`ufw` vs `iptables`). Delete the `k3s` and `proxmox_lxc` copies.

---

#### CQ-C3: `playbooks/rollback.yml` references non-existent files — entirely non-functional
**Severity:** Critical
**File:** `playbooks/rollback.yml` — lines 132, 211, 239

Three broken references:
1. Line 132: `include_tasks: ../ansible_collections/homelab/common/tasks/rollback_{{ item }}.yml` — no `rollback_*.yml` files exist
2. Line 211: `include: tests/test_suite.yml` — file does not exist
3. Line 239: `template: src: rollback_report.html.j2` — template does not exist

This playbook will fail at every step. In an incident, running it would waste critical time.

**Fix:** Delete it or implement it properly. It is a dangerous stub.

---

### High

#### CQ-H1: `proxmox_default_node` underscore/hyphen mismatch — latent KeyError
**Severity:** High
**Files:**
- `ansible_collections/homelab/common/inventory/group_vars/all.yml` line 77: `proxmox_default_node: pve_mac`
- `inventory/group_vars/lxc_containers.yml` line 49: `proxmox_default_node: pve-mac`
- `inventory/group_vars/enclave.yml` line 130: `enclave_proxmox_node: pve_mac`

`proxmox_config` keys use hyphens (`pve-mac`, `pve-nas`). The common collection all.yml sets `pve_mac` (underscore), which will fail a lookup like `proxmox_config[proxmox_default_node]` when the common value takes precedence.

**Fix:** Standardize to `pve-mac` / `pve-nas` everywhere.

---

#### CQ-H2: Legacy `lxc_container` role duplicates `container_base`
**Severity:** High
**Files:**
- `ansible_collections/homelab/proxmox_lxc/roles/lxc_container/`
- `ansible_collections/homelab/common/roles/container_base/`

Both create LXC containers via `community.proxmox.proxmox`. `container_base` is the comprehensive active version. `lxc_container` is a legacy simpler version only referenced by `security-deploy.yml` and `phase2-security.yml`.

**Fix:** Remove `lxc_container` from `proxmox_lxc`. Remove or update the two legacy playbooks that reference it.

---

#### CQ-H3: Legacy root-level playbooks reference stale hostnames and deprecated roles
**Severity:** High
**Files:**
- `security-deploy.yml` — references `unbound-lxc`, `adguard-lxc` hostnames (not in inventory)
- `phase2-security.yml` — same stale hostname pattern, also uses `yes` instead of `true`
- `test-template-download.yml`, `test-security-hardening.yml`, `test-proxmox-api-tokens.yml` — outside `tests/`
- `vault_variables_template.yml` — duplicates `inventory/group_vars/all/vault.yml.example`

**Fix:** Delete `security-deploy.yml` and `phase2-security.yml`. Move test playbooks to `tests/`. Remove duplicate vault template.

---

#### CQ-H4: `proxmox_config` defined in 3 separate places with divergent structures
**Severity:** High
- `common/inventory/group_vars/all.yml` — includes legacy `password` fields, `user: root@pam`, uses underscore keys
- `inventory/group_vars/lxc_containers.yml` — no password, token-based user, hyphen keys
- `inventory/group_vars/nas_vm.yml` — same as lxc_containers

The `password` field in common's version references `vault_proxmox_passwords` which is documented as "Legacy — will be removed." Key naming inconsistency compounds the problem.

**Fix:** Consolidate to a single definition. Remove `common`'s all.yml version or make it the single source. Remove legacy password fields.

---

#### CQ-H5: `homelab_domain` defined 4+ times; `homelab_network` defined 3 times with different DNS
**Severity:** High

`homelab_domain: homelab.lan` appears in 4+ files. `homelab_network` DNS servers differ:
- common all.yml: `[Unbound, AdGuard, 1.1.1.1]`
- lxc_containers.yml: `[AdGuard, Unbound]` (no fallback)
- nas_vm.yml: `[1.1.1.1, 1.0.0.1]` (no internal DNS — NAS VMs cannot resolve `*.homelab.lan`)

**Fix:** Define once in `inventory/group_vars/all/`. Override only where needed, with comments explaining why.

---

#### CQ-H6: Makefile references non-existent playbooks
**Severity:** High
- Line 371: `backup:` target → `playbooks/backup.yml` (does not exist)
- Line 349: `performance:` target → `tests/performance/local_performance_test.yml` (does not exist)
- Line 272: `deploy-security:` target → `security-deploy.yml` (legacy, should be removed)

**Fix:** Remove non-functional targets or implement the missing playbooks.

---

#### CQ-H7: Duplicate enclave playbooks
**Severity:** High
**Files:** `playbooks/secure-enclave.yml` (168 lines) and `playbooks/enclave.yml` (83 lines) — both deploy the same secure enclave role.

`enclave.yml` is the modern version referenced in CLAUDE.md. `secure-enclave.yml` is the legacy verbose version.

**Fix:** Remove `playbooks/secure-enclave.yml`.

---

### Medium

#### CQ-M1: Promtail installed by two different roles — double-install risk
`monitoring_agent` (common) installs both node_exporter AND promtail. `proxmox_lxc/roles/promtail` is a standalone promtail installer. Running both deployment paths creates competing systemd services.
**Fix:** Standardize on `monitoring_agent`. Remove standalone `promtail` role.

---

#### CQ-M2: `container_defaults` defined identically in `common/inventory/group_vars/all.yml` and `inventory/group_vars/lxc_containers.yml`
The only difference is `ssh_key` in the lxc_containers version.
**Fix:** Remove from common's all.yml. Keep single definition in lxc_containers.yml with `ssh_key`.

---

#### CQ-M3: `changed_when: true` used excessively (47 files) — defeats idempotency tracking
Shell tasks always report "changed" even when nothing changed. Makes `--check` mode unreliable.
Key files: `playbooks/fix-prometheus-ssh.yml` lines 18/25/33, `container_base/tasks/main.yml` lines 204/255.
**Fix:** Implement proper `changed_when` based on command stdout/return code.

---

#### CQ-M4: `ignore_errors: true` overused in test playbooks — failures silently discarded
`validate-enclave.yml` (12 occurrences), `validate-services.yml` (10), `validate-infrastructure.yml` (6). No summary task reports pass/fail counts.
**Fix:** Replace with `failed_when: false`, register results, add summary assertion task.

---

#### CQ-M5: `playbooks/fix-prometheus-ssh.yml` is a one-shot hotfix that should not persist
This recovery playbook patches Prometheus container SSH via raw `pct exec`/`sed`. The root cause should be handled by `container_base` and `common_setup` during normal deployment.
**Fix:** Verify standard workflow handles these SSH issues, then delete this playbook.

---

#### CQ-M6: `monitoring_agent` role hardcodes `amd64` architecture — wrong for Raspberry Pi (aarch64)
Download URLs for node_exporter and promtail are hardcoded to `linux-amd64`. K3s nodes (Pi) would get wrong binaries.
**Fix:** Add `node_exporter_arch: "{{ 'arm64' if ansible_architecture == 'aarch64' else 'amd64' }}"`.

---

#### CQ-M7: `container_base` hardcodes `local-lvm` storage pool
`disk: "local-lvm:{{ container_disk_size }}"` ignores the configurable `lxc_config.storage` setting.
**Fix:** `disk: "{{ lxc_config.storage }}:{{ container_disk_size }}"`.

---

#### CQ-M8: `promtail` role uses bare module names (not FQCNs) — inconsistent and triggers ansible-lint
Every module in `proxmox_lxc/roles/promtail/tasks/main.yml` uses short names (`apt:`, `user:`, `systemd:`, etc.).
**Fix:** Convert to FQCNs (`ansible.builtin.apt`, etc.).

---

#### CQ-M9: `step_ca` role adds iptables rules without `iptables-persistent` — rules lost on reboot
`iptables-save > /etc/iptables/rules.v4` without installing `iptables-persistent` or `netfilter-persistent`.
**Fix:** Install `iptables-persistent`, use `netfilter-persistent save`.

---

#### CQ-M10: `common_setup` DNS check hardcodes `archive.ubuntu.com` — fails with internal-only DNS
`getent hosts archive.ubuntu.com` will fail on containers using AdGuard/Unbound without external forwarding.
**Fix:** Check an internal hostname or make the check conditional on external DNS availability.

---

#### CQ-M11: `teardown-secure-enclave.yml` not referenced from Makefile or CLAUDE.md
**Fix:** Add `teardown-enclave` Makefile target.

---

#### CQ-M12: `common/inventory/group_vars/all.yml` still contains legacy `password` fields
References `vault_proxmox_passwords` documented as "Legacy — will be removed." May cause undefined variable errors.
**Fix:** Remove the password fields entirely.

---

### Low

#### CQ-L1: `deploy-security` Makefile target calls legacy `security-deploy.yml`
**Fix:** Remove or update to use `playbooks/infrastructure.yml --tags foundation,phase1`.

---

#### CQ-L2: `package.json` / `package-lock.json` at repository root — purpose undocumented
Likely for `markdownlint-cli2`. If so, document it; if unused, remove.

---

#### CQ-L3: `apt: upgrade: true` in promtail role — full system upgrade as side effect of role
**Fix:** Remove `upgrade: true`. System upgrades belong in `update-systems.yml`.

---

## Architecture Findings

### Critical

#### AR-C1: `when` conditionals on `import_playbook` are silently ignored by Ansible
**Severity:** Critical
**File:** `playbooks/infrastructure.yml` lines 37, 44, 51, 59

```yaml
- import_playbook: networking.yml
  when: not skip_networking | default(false)  # THIS IS IGNORED
```

Ansible does not support `when` on `import_playbook`. The clause is silently discarded — every phase runs regardless of `skip_*` variables. Any operator relying on this skip pattern gets no error, just silent non-skipping.

**Fix:** Remove all `when` clauses from `import_playbook` directives. Use tags for selective execution (already supported). If conditional skipping is needed, add a pre_task inside the imported playbook that ends the play early.

---

### High

#### AR-H1: 6 K3s roles duplicated in `proxmox_lxc` — never imported by any root playbook
Identical to CQ-C1. Additionally: the `proxmox_lxc/site.yml` that references them uses `-lxc` suffixed hostnames that do not match the current static inventory.

---

#### AR-H2: `proxmox_config` key naming mismatch — latent KeyError in `container_base`
**Severity:** High

`container_base` uses `proxmox_config[proxmox_node | default(proxmox_default_node)]`. The `proxmox_node` values in `inventory/hosts.yml` use hyphens (`pve-mac`). The `common/inventory/group_vars/all.yml` defines `proxmox_default_node: pve_mac` (underscore) and `proxmox_config` keys with underscores. The lxc_containers group_vars shadows this with correct hyphen keys — but only because it wins on variable precedence. This is fragile.

**Fix:** Standardize to hyphens everywhere, matching the Proxmox node names in hosts.yml.

---

### Medium

#### AR-M1: `security_hardening` in `common` has K3s-specific task files (`configure_ufw_k3s.yml`) — misleading placement
Despite being in "common", the role is K3s-centric. The variable namespace `pi_security_hardening` is Pi/K3s-specific.
**Fix:** Rename variable namespace to `security_hardening` universally when consolidating.

---

#### AR-M2: `proxmox_lxc/site.yml` is a broken parallel orchestration path
Targets `-lxc` suffixed hostnames not in the static inventory. Deploys `promtail` standalone (conflicts with `monitoring_agent`). References `tasks/bypass_security_checks.yml` with file-based bypass mechanism.
**Fix:** Mark as deprecated with comment pointing to `playbooks/infrastructure.yml`, or delete entirely.

---

#### AR-M3: Container provisioning double-invocation in full deployment
`container_base` is invoked in phase 1 (`provision-containers.yml`) AND as pre_tasks in phases 2-4 (`networking.yml`, `monitoring.yml`, `applications.yml`). Idempotent but adds 15-30s per container per extra invocation.
**Fix:** Remove `container_base` pre_tasks from phase 2-4 playbooks now that phase 1 handles it.

---

#### AR-M4: `monitoring_agent` defines a handler for non-existent service `monitoring_agent`
`handlers/main.yml` line 18: handler restarts a `monitoring_agent` systemd unit that doesn't exist. The role installs `node_exporter` and `promtail`.
**Fix:** Remove this handler or replace with handlers for the actual services.

---

#### AR-M5: Dual inventory systems (static + dynamic Proxmox) create ambiguity
Static inventory in `inventory/hosts.yml` is used by root playbooks. Dynamic Proxmox inventory in `proxmox_lxc/inventory/` creates different group names (`bastion_host` vs `bastion_hosts`). Mixing them would cause host targeting failures.
**Fix:** Document that static inventory is authoritative. Mark dynamic inventory as collection-internal only.

---

#### AR-M6: `container_base` and `vm_base` both duplicate Proxmox API token-parsing logic
Both roles contain the same token extraction pattern (parsing `user@realm!tokenname`). Similar API validation logic is also in the `lxc_container` role.
**Fix:** Extract to a shared task file or module in `common`.

---

#### AR-M7: `ubuntu_vm` role in `proxmox_lxc` is orphaned — no playbook references it
The role wraps `homelab.common.vm_base` but no root playbook or `site.yml` imports it.
**Fix:** Delete it or wire it into an appropriate phase playbook.

---

### Low

#### AR-L1: Tag taxonomy is inconsistent between root playbooks and collection site.yml
Root playbooks: `foundation`, `networking`, `phase1`-`phase5`. Collection site.yml: `deploy`, `templates`, `verify`, `health-check`. Minor since site.yml is effectively deprecated.
**Fix:** Document tag taxonomy in CLAUDE.md.

---

#### AR-L2: NAS VM DNS uses only public resolvers — cannot resolve `*.homelab.lan`
`inventory/group_vars/nas_vm.yml` DNS: `[1.1.1.1, 1.0.0.1]`. May be intentional for ISO-based VMs.
**Fix:** Document rationale explicitly in the group_vars file.

---

#### AR-L3: `container_defaults` resource sizing inline in playbook tasks overrides group_vars
Playbooks like `networking.yml` use `cores: "{{ lxc_cores | default(1) }}"` inline, creating a third layer of defaults that shadows group_vars.
**Fix:** Remove inline defaults from playbook vars. Rely on group_vars hierarchy.

---

## Critical Issues for Phase 2 Context

The following findings should inform the security and performance review:

1. **AR-C1** (`when` on `import_playbook` silently ignored): Phases could deploy out of order or skip security hardening phases unexpectedly — verify all phases run in correct sequence.
2. **CQ-C3** (broken rollback playbook): During a security incident, the rollback mechanism is non-functional.
3. **CQ-H4** (`proxmox_config` multi-definition including legacy password fields): Legacy `password: root@pam` fields may expose credentials if the wrong variable wins.
4. **CQ-M9** (`step_ca` iptables rules lost on reboot): The certificate authority's port forwarding disappears after reboot — PKI infrastructure may become unreachable.
5. **CQ-M6** (`monitoring_agent` hardcoded amd64): Monitoring agents silently deploy wrong binaries on Pi nodes — metrics gaps in security observability.
6. **AR-M2** (`proxmox_lxc/site.yml` bypass_security_checks): File-based bypass mechanism could allow security checks to be bypassed unintentionally.
