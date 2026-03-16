# Phase 3 Audit: Ansible Idioms, Collection Structure, and Modernisation

**Scope:** Full audit of `ansible_collections/homelab/`, `playbooks/`, `inventory/`, tooling
**Ansible Core version in use:** 2.20.3
**Date:** 2026-03-16

---

## Summary Table

| # | Severity | Area | Finding |
|---|----------|------|---------|
| 1 | High | Deprecated pattern | `when:` on `import_playbook` is silently ignored |
| 2 | High | Duplicate roles | 7 roles exist identically in both `k3s/` and `proxmox_lxc/` collections |
| 3 | High | Non-FQCN modules | `promtail` role uses zero FQCN names; `bypass_security_checks.yml` uses bare names |
| 4 | High | `changed_when: true` | 34 occurrences in homelab roles — idempotency is fully broken for these tasks |
| 5 | High | `apt: upgrade: true` | 5 roles unconditionally upgrade all system packages on every run |
| 6 | Medium | Deprecated module | `community.general.proxmox` used in 10 task files — superseded by `community.proxmox.proxmox` |
| 7 | Medium | Role meta `when:` conditions | `when:` inside `meta/dependencies` is not a supported feature |
| 8 | Medium | Hardcoded IPs in tasks | Management CIDR `192.168.0.0/24` hardcoded in `security_hardening` task files, not in defaults |
| 9 | Medium | `deprecation_warnings = False` | Suppresses the only feedback mechanism for deprecated patterns |
| 10 | Medium | `ansible_ssh_common_args: '-o StrictHostKeyChecking=no'` | Disables host key checking globally for all hosts |
| 11 | Medium | Inconsistent `min_ansible_version` | Ranges from 2.12 to 2.17 across roles; actual runtime is 2.20.3 |
| 12 | Medium | Inline Python one-liners in `shell:` | Prometheus role extracts kubeconfig fields via `python3 -c` shell tasks |
| 13 | Medium | Inventory structure conflict | Three separate inventory trees in use simultaneously |
| 14 | Low | Legacy playbooks still wired in CI | `security-deploy.yml` and `phase2-security.yml` pass syntax check; reference nonexistent host names |
| 15 | Low | `ansible.builtin.pip` without `virtualenv` | 5 roles install Python packages globally via pip |
| 16 | Low | `ansible.builtin.service` (short name) vs `systemd` | `bastion` role uses `ansible.builtin.service` for fail2ban, rest of codebase uses `systemd` |
| 17 | Low | `failed_when: false` overuse | 50 occurrences suppress genuine failures silently |
| 18 | Low | No `validate:` on all config templates | Most non-SSH config templates lack `validate:` parameter |
| 19 | Low | `common` galaxy.yml depends on `kubernetes.core` | `kubernetes.core` is only used in K3s, not in common roles |
| 20 | Low | `truthy:` YAML values | Legacy playbooks use `yes`/`no`; yamllint permits them but ansible-lint flags |

---

## Detailed Findings

---

### Finding 1 — High: `when:` conditions on `import_playbook` are silently ignored

**File:** `/home/pbs/ansible/homelab/playbooks/infrastructure.yml`, lines 37, 44, 51, 59

**Current pattern:**
```yaml
- name: Deploy networking services
  import_playbook: networking.yml
  tags:
    - networking
    - phase2
  when: not skip_networking | default(false)
```

**Problem:** Ansible does not support `when:` on `import_playbook`. The statement is parsed without error but the condition is never evaluated — `networking.yml` always runs regardless of the value of `skip_networking`. This was silently broken from day one and is confirmed in the Ansible documentation: *"Note: import_playbook does not support when."*

Since `import_playbook` is a static inclusion resolved at parse time (before any variable evaluation), `when:` has no effect.

**Recommendation:** Replace `when:` + `import_playbook` with a dedicated orchestration playbook that uses `include_playbook` (the dynamic form), or accept that phases cannot be conditionally skipped and remove the misleading `when:` lines. The `--tags` mechanism (which does work) is the supported way to skip phases.

```yaml
# OPTION A: remove the misleading when: clauses entirely (tags still work)
- name: Deploy networking services
  import_playbook: networking.yml
  tags: [networking, phase2]

# OPTION B: switch to include_playbook (dynamic, supports when:)
# Note: include_playbook does not support tags directly on the include statement itself
- name: Deploy networking services
  ansible.builtin.include_playbook:   # requires ansible-core >= 2.16
    file: networking.yml
  when: not skip_networking | default(false)
```

---

### Finding 2 — High: 7 roles are fully duplicated across two collections

**Files:**
- `ansible_collections/homelab/k3s/roles/{k3s_server,k3s_agent,k3s_upgrade,airgap,prereq,raspberrypi,security_hardening}/`
- `ansible_collections/homelab/proxmox_lxc/roles/{k3s_server,k3s_agent,k3s_upgrade,airgap,prereq,raspberrypi,security_hardening}/`

**Problem:** All 7 roles exist in both the `k3s` and `proxmox_lxc` collections. A diff of `k3s_server/tasks/main.yml` shows they are near-identical with minor whitespace and comment differences. A diff of `security_hardening/tasks/main.yml` shows the two have diverged: the `k3s` version adds Pi-specific detection and UFW, while the `proxmox_lxc` version uses iptables. This silent fork is the worst kind of duplication: both copies appear maintained, but changes to one are not reflected in the other.

This also means `homelab.proxmox_lxc.security_hardening` and `homelab.common.security_hardening` are *three* different security_hardening implementations across the codebase, with differing firewall backends.

**Recommendation:**
- K3s-specific roles (`k3s_server`, `k3s_agent`, `k3s_upgrade`, `airgap`, `prereq`, `raspberrypi`) belong exclusively in the `k3s` collection. The copies in `proxmox_lxc` should be deleted.
- The `security_hardening` role in `proxmox_lxc` deliberately differs from the `common` one (iptables vs UFW). Rename it `lxc_security_hardening` to make the split intentional and document why.

---

### Finding 3 — High: `promtail` role uses no FQCN module names

**File:** `/home/pbs/ansible/homelab/ansible_collections/homelab/proxmox_lxc/roles/promtail/tasks/main.yml`

**Current pattern:**
```yaml
- name: Update system packages
  apt:
    update_cache: true
    upgrade: true
- name: Create promtail user
  user:
    name: "{{ promtail_user }}"
...
- name: Deploy Promtail configuration
  template:
    src: promtail.yml.j2
...
- name: Enable and start Promtail
  systemd:
    name: promtail
```

Every task in this role uses short (non-FQCN) module names. This means `ansible.cfg`'s `fqcn[action-core]` suppression in `.ansible-lint` hides the violation. In a collection context (since Ansible 2.10), short module names resolve via the collection's own `plugins/modules` directory first, which can cause subtle routing bugs when a collection ships modules with the same short name as a builtin.

**Additional:** `bypass_security_checks.yml` also uses bare `stat:`, `debug:`, and `include_tasks:` (the non-FQCN form).

**Recommendation:** Apply FQCN names throughout. For the promtail role, every module call should be prefixed: `ansible.builtin.apt`, `ansible.builtin.user`, `ansible.builtin.template`, `ansible.builtin.systemd`, `ansible.builtin.get_url`, `ansible.builtin.unarchive`, `ansible.builtin.copy`, `ansible.builtin.wait_for`, `ansible.builtin.uri`, `ansible.builtin.debug`.

Remove the `fqcn[action-core]` suppression from `.ansible-lint` once this is fixed — the suppression was added as a workaround, not an intentional exception.

---

### Finding 4 — High: `changed_when: true` hardcoded on 34 tasks — idempotency broken

**Files (homelab collection only):**
- `common/roles/container_base/tasks/main.yml` — lines 204, 256 (firewall write, SSH fix)
- `common/roles/vm_base/tasks/main.yml` — lines 235, 297
- `common/tasks/proxmox_firewall_setup.yml` — lines 31, 65
- `common/roles/security_hardening/tasks/pi_system_hardening.yml` — line 120
- `proxmox_lxc/roles/traefik/tasks/main.yml` — line 177 (`iptables-save`)
- `proxmox_lxc/roles/wireguard/tasks/main.yml` — line 292 (`iptables-save`)
- `proxmox_lxc/roles/unbound/tasks/main.yml` — line 168 (`iptables-save`)
- `proxmox_lxc/roles/bastion/tasks/main.yml` — line 86 (`iptables-save`)
- `proxmox_lxc/roles/adguard/tasks/main.yml` — line 329 (`iptables-save`)
- `proxmox_lxc/roles/security_hardening/tasks/configure_iptables.yml` — line 86
- `proxmox_lxc/roles/secure_enclave/tasks/` — multiple
- K3s roles (`k3s_server`, `k3s_agent`, `airgap`, `k3s_upgrade`) — K3s install steps

**The most widespread pattern** (iptables-save, repeated across 6+ roles):
```yaml
- name: Save iptables rules
  ansible.builtin.shell: iptables-save > /etc/iptables/rules.v4
  changed_when: true   # <-- always marks changed
```

**Problem:** `changed_when: true` causes every Ansible run to report these tasks as "changed" even when nothing changed. This breaks drift detection, makes `--check` mode unreliable, and overwhelms handlers. It also means `ansible-playbook --diff` will show noise on every run.

**Correct pattern for iptables-save:**
```yaml
- name: Save iptables rules
  ansible.builtin.shell:
    cmd: iptables-save > /etc/iptables/rules.v4
  register: iptables_save_result
  changed_when: iptables_save_result.rc == 0
  # Or better: use a handler that only fires when iptables rules actually changed
```

**Correct pattern for firewall config writes:**
The existing code already reads the existing config (`slurp`) and compares before writing (in `container_base/tasks/main.yml`). The `changed_when: true` following that comparison logic is contradictory — the comparison correctly sets `when:` to only write on change, but then marks the write as always-changed.

---

### Finding 5 — High: Unconditional `apt: upgrade: true` in 5 service roles

**Files:**
- `proxmox_lxc/roles/traefik/tasks/main.yml`
- `proxmox_lxc/roles/grafana/tasks/main.yml`
- `proxmox_lxc/roles/loki/tasks/main.yml`
- `proxmox_lxc/roles/promtail/tasks/main.yml`
- `proxmox_lxc/roles/openwrt/tasks/main.yml`

**Current pattern:**
```yaml
- name: Update system packages
  ansible.builtin.apt:
    update_cache: true
    upgrade: true
```

**Problem:** `upgrade: true` upgrades all installed packages every time the role runs. This:
1. Makes every role run non-idempotent (always marks changed).
2. Can break service functionality by pulling in unexpected kernel or library updates.
3. Takes significant time on slow LXC containers.
4. Is correctly omitted in most other roles (prometheus, alertmanager, adguard, etc.) which only do `update_cache: true`.

**Recommendation:** Remove `upgrade: true` from all service role first tasks. Full system upgrades belong in `playbooks/update-systems.yml` which is already purpose-built for that.

```yaml
# Replace with:
- name: Update package cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600
```

---

### Finding 6 — Medium: `community.general.proxmox` used in 10 task files (deprecated)

**Files:**
- `proxmox_lxc/roles/wireguard/tasks/main.yml` — line 47
- `proxmox_lxc/roles/secure_enclave/tasks/router.yml` — lines 6, 63
- `proxmox_lxc/roles/secure_enclave/tasks/bastion.yml` — lines 6, 40
- `proxmox_lxc/roles/secure_enclave/tasks/cleanup.yml` — line 16
- `proxmox_lxc/roles/secure_enclave/tasks/attacker_vm.yml` — lines 84, 124
- `proxmox_lxc/roles/secure_enclave/tasks/deploy_vulnerable_target.yml` — lines 6, 42

**Problem:** `community.general.proxmox` is the legacy module that was moved to the `community.proxmox` collection. The rest of the codebase (including `container_base`, `provision-containers.yml`) has been updated to `community.proxmox.proxmox`. These 10 usages are stragglers that will break when `community.general` removes the module or when its behaviour diverges from the canonical collection.

**Recommendation:**
```yaml
# Replace all occurrences of:
community.general.proxmox:
# with:
community.proxmox.proxmox:
```

---

### Finding 7 — Medium: `when:` inside `meta/dependencies` is not a supported Ansible feature

**Files:**
- `proxmox_lxc/roles/prometheus/meta/main.yml`
- `proxmox_lxc/roles/grafana/meta/main.yml`
- `proxmox_lxc/roles/alertmanager/meta/main.yml`
- `proxmox_lxc/roles/traefik/meta/main.yml`
- `proxmox_lxc/roles/homeassistant/meta/main.yml`
- `proxmox_lxc/roles/pve_exporter/meta/main.yml`
- `proxmox_lxc/roles/promtail/meta/main.yml`

**Current pattern** (from `prometheus/meta/main.yml`):
```yaml
dependencies:
  - role: homelab.common.container_base
    when: use_container_base | default(true)
  - role: homelab.common.security_hardening
    when: use_security_hardening | default(true)
```

**Problem:** Ansible role meta `dependencies` do not support `when:` conditions. The `when:` key is silently ignored and the dependency always runs. This is documented behaviour. The variables `use_container_base` and `use_security_hardening` appear to have been added with the intent to make dependencies optional, but they have no effect. Users who set `use_container_base: false` will still have `container_base` run.

**Recommendation:** Remove the `when:` clauses from meta dependencies. If optional dependency inclusion is genuinely needed, handle it inside the depending role's tasks using `include_role:` with a `when:` condition:

```yaml
# In prometheus/tasks/main.yml:
- name: Run container_base if not already provisioned
  ansible.builtin.include_role:
    name: homelab.common.container_base
  when: use_container_base | default(false)
```

Or simply document that `container_base` should be called explicitly from the playbook before service roles, and remove the meta dependency entirely.

---

### Finding 8 — Medium: Management CIDR `192.168.0.0/24` hardcoded in task files

**Files:**
- `proxmox_lxc/roles/security_hardening/tasks/configure_iptables.yml` — line 24
- `proxmox_lxc/roles/security_hardening/tasks/configure_ufw.yml` — line 19
- `common/roles/security_hardening/tasks/configure_ufw_k3s.yml` — line 47 (uses a variable `192.168.0.0/24` in the comment but the actual allow rule uses `container_network_cidr`)

**Current pattern in `configure_iptables.yml`:**
```yaml
- name: Allow SSH from management network
  ansible.builtin.iptables:
    chain: INPUT
    protocol: tcp
    source: 192.168.0.0/24      # hardcoded
    destination_port: "{{ security_hardening.ssh_hardening.port | default(22) }}"
    jump: ACCEPT
```

**Problem:** The CIDR is hardcoded directly in the task rather than referencing the `container_network_cidr` variable that already exists in defaults. If the network ever changes, this task silently uses the wrong CIDR while `container_network_cidr` is updated.

**Recommendation:** Reference the existing variable:
```yaml
source: "{{ container_network_cidr | default('192.168.0.0/24') }}"
```

---

### Finding 9 — Medium: `deprecation_warnings = False` suppresses the only deprecation feedback mechanism

**File:** `/home/pbs/ansible/homelab/ansible.cfg`, line 9

**Current pattern:**
```ini
deprecation_warnings = False
```

**Problem:** Deprecation warnings are the primary way Ansible communicates that an API, module, or pattern is going away. Suppressing them project-wide means silent accumulation of deprecated patterns that will break on future upgrades. This is particularly concerning given that this audit has already found deprecated patterns (`community.general.proxmox`, `when:` on `import_playbook`, `when:` in meta dependencies) that are all masked by this setting.

**Recommendation:** Remove this line. If specific deprecations are genuinely noise (e.g., from third-party collections), use `ANSIBLE_DEPRECATION_WARNINGS=false` temporarily as a per-run override rather than a permanent project configuration, or upgrade the offending dependency.

---

### Finding 10 — Medium: `StrictHostKeyChecking=no` disables SSH host verification globally

**File:** `/home/pbs/ansible/homelab/inventory/hosts.yml`, line 242

**Current pattern:**
```yaml
vars:
  ansible_python_interpreter: /usr/bin/python3
  ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
```

**Problem:** This is applied to the `all` group, disabling SSH host key verification for every host in the inventory. Combined with `host_key_checking = False` in `ansible.cfg`, this is doubly redundant. More importantly, both settings remove the ability to detect MITM attacks or inadvertent connections to the wrong host (e.g., IP reuse after a container rebuild). This matters most for the Proxmox hosts that also have `proxmox_validate_certs: false`.

**Recommendation:**
1. Remove `ansible_ssh_common_args` from `inventory/hosts.yml`.
2. Keep `host_key_checking = False` only in `ansible.cfg` with a comment explaining it's acceptable for the known-network homelab environment (or add a `known_hosts` file for the infrastructure and set `host_key_checking = True`).
3. Do not set both.

---

### Finding 11 — Medium: Inconsistent `min_ansible_version` across roles (2.12–2.17)

**Pattern:** Roles across all three collections declare `min_ansible_version` values ranging from `"2.12"` to `"2.17"`, while:
- The actual runtime is 2.20.3 (from `ansible --version`)
- `infrastructure.yml` asserts `ansible_version.full is version('2.15.0', '>=')`
- The CI pipeline installs `ansible-core>=2.17`
- The `common` collection's `galaxy.yml` does not declare a minimum version at all

This means roles that declare `min_ansible_version: "2.12"` are tested with 2.20.3 but may advertise compatibility with versions that lack features they actually use (e.g., `community.proxmox` collection requires 2.13+).

**Recommendation:** Standardise all role `meta/main.yml` to `min_ansible_version: "2.17"` to match the CI/CD minimum. Add `min_ansible_version: "2.17"` to all three `galaxy.yml` collection metadata files.

---

### Finding 12 — Medium: Inline Python one-liners in `ansible.builtin.shell` tasks

**File:** `proxmox_lxc/roles/prometheus/tasks/main.yml`, lines 104–113

**Current pattern:**
```yaml
- name: Extract k3s client certificate from kubeconfig
  ansible.builtin.shell:
    cmd: "python3 -c \"import yaml,base64; d=yaml.safe_load(open('/etc/prometheus/kubeconfig')); open('/etc/prometheus/k3s-client.crt','wb').write(base64.b64decode(d['users'][0]['user']['client-certificate-data']))\""
  changed_when: false
```

**Problems:**
1. The task always runs (no `creates:` guard) — this is a hidden `changed_when: false` anti-pattern: the task produces side effects every run but claims no change.
2. The cert extraction should detect if the output file already matches the kubeconfig content and only write when changed.
3. The inline Python is fragile and hard to maintain.

**Recommendation:** Replace with native Ansible modules:
```yaml
- name: Read kubeconfig for cert extraction
  ansible.builtin.slurp:
    src: /etc/prometheus/kubeconfig
  register: _kubeconfig_content
  no_log: true

- name: Extract k3s client certificate
  ansible.builtin.copy:
    content: "{{ (_kubeconfig_content.content | b64decode | from_yaml).users[0].user['client-certificate-data'] | b64decode }}"
    dest: /etc/prometheus/k3s-client.crt
    owner: prometheus
    group: prometheus
    mode: "0644"
  no_log: true
```

---

### Finding 13 — Medium: Three separate inventory trees create variable precedence confusion

**Inventories in use:**
1. `/home/pbs/ansible/homelab/inventory/` — root inventory (used by `ansible.cfg`)
2. `/home/pbs/ansible/homelab/ansible_collections/homelab/k3s/inventory/` — K3s collection inventory
3. `/home/pbs/ansible/homelab/ansible_collections/homelab/proxmox_lxc/inventory/` — proxmox_lxc collection inventory (includes a dynamic `proxmox.yml` plugin)

**Problems:**
- The root inventory's `group_vars/all/` contains a `proxmox_config` dict that partially overlaps with `ansible_collections/homelab/common/inventory/group_vars/all.yml` which also defines `proxmox_config` with different key naming (`pve_mac` vs `pve-mac`).
- The `k3s/inventory/hosts.yml` defines `ansible_user` at the host level, which may conflict with the root inventory's `k3s_cluster.vars.ansible_user: pbs`.
- The dynamic `proxmox.yml` inventory cannot be used with the root `ansible.cfg` (which points to `./inventory`) without explicit `-i` flags.

**Recommendation:** Pick one inventory strategy:
- **Option A (recommended):** Consolidate all group_vars into the root `inventory/group_vars/`. Remove `ansible_collections/homelab/common/inventory/` — it serves no purpose since the common collection has no playbooks that use it independently.
- **Option B:** Document explicitly which inventory to use for each playbook and add `-i` flags in all Makefile targets.

---

### Finding 14 — Low: Legacy playbooks still wired into CI reference nonexistent hostnames

**Files:**
- `/home/pbs/ansible/homelab/security-deploy.yml` — references `proxmox_hosts`, runs `homelab.proxmox_lxc.bastion` on Proxmox hosts (wrong target)
- `/home/pbs/ansible/homelab/phase2-security.yml` — references `unbound-lxc`, `adguard-lxc`, `wireguard-lxc`, `traefik-lxc` — none of which exist in the current inventory (actual hostnames are `unbound`, `adguard`, etc.)

Both files use `gather_facts: yes` and `become: yes` (deprecated `yes`/`no` truthy values) and pass syntax check only because syntax check does not validate host existence.

The CI workflow (`.github/workflows/ci.yml`) runs `ansible-playbook --syntax-check security-deploy.yml` and `phase2-security.yml` on every push, meaning these broken playbooks are blessed by CI.

**Recommendation:**
1. Either delete these files (the CLAUDE.md already says "legacy" and recommends `playbooks/infrastructure.yml`).
2. Or fix the hostname references and truthy values so they actually work.

Replace `gather_facts: yes` → `gather_facts: true` and `become: yes` → `become: true` throughout.

---

### Finding 15 — Low: `ansible.builtin.pip` without `virtualenv` installs packages into system Python

**Files:**
- `proxmox_lxc/roles/homeassistant/tasks/main.yml` — line 22 (docker, requests)
- `proxmox_lxc/roles/pve_exporter/tasks/main.yml` — line 50 (prometheus-pve-exporter)
- `proxmox_lxc/roles/bastion/tasks/main.yml` — line 16 (whatever `bastion_pip_packages` contains)
- `proxmox_lxc/roles/secure_enclave/tasks/attacker_vm.yml` — line 178
- `common/roles/monitoring_agent/tasks/main.yml` — line 15

**Problem:** System Python pip installations conflict with the OS package manager, can be overwritten by `apt` upgrades, and are not isolated. Python 3.11+ on Debian/Ubuntu enforces `--break-system-packages` to prevent this.

**Recommendation:** Use either `virtualenv_command` or `executable` to target a dedicated venv, or prefer `apt` packages (e.g., `python3-docker`) when available:
```yaml
- name: Install Python packages in virtualenv
  ansible.builtin.pip:
    name:
      - docker
      - requests
    state: present
    virtualenv: /opt/homeassistant-venv
    virtualenv_python: python3
```

---

### Finding 16 — Low: Iptables restore service duplicated verbatim across 7 roles

**Files containing identical inline iptables-restore systemd service unit:**
- `proxmox_lxc/roles/traefik/tasks/main.yml`
- `proxmox_lxc/roles/wireguard/tasks/main.yml`
- `proxmox_lxc/roles/unbound/tasks/main.yml`
- `proxmox_lxc/roles/bastion/tasks/main.yml`
- `proxmox_lxc/roles/adguard/tasks/main.yml`
- `proxmox_lxc/roles/security_hardening/tasks/configure_iptables.yml`
- `proxmox_lxc/roles/secure_enclave/tasks/router.yml`

All contain an identical `ansible.builtin.copy:` task inlining the full `[Unit]/[Service]/[Install]` systemd unit for `iptables-restore.service`. A change to the unit definition requires updating 7+ files.

**Recommendation:** Move the iptables persistence logic into `proxmox_lxc/roles/security_hardening/` as a single callable task file, or better, add a `files/iptables-restore.service` to the security_hardening role and use `ansible.builtin.copy: src:` rather than inline content. Service roles should call `security_hardening` which handles persistence, rather than each duplicating the persistence block.

---

### Finding 17 — Low: 50 occurrences of `failed_when: false` suppress genuine errors

**Pattern observed:** Many connectivity checks, module checks, and service starts use `failed_when: false` unconditionally:
```yaml
- name: Load WireGuard kernel module on Proxmox host
  community.general.modprobe:
    name: wireguard
    state: present
  failed_when: false
```

While suppressing failures on "best effort" tasks is valid, the current pattern makes every failure invisible. Some of these tasks have subsequent logic that checks `result.rc` or `result.failed`, but others simply silently swallow errors.

**Recommendation:** Replace `failed_when: false` with more specific conditions:
```yaml
failed_when:
  - wireguard_module_result.rc not in [0, 1]  # 0=loaded, 1=already loaded
```
Or register the result and only warn rather than silently ignore.

---

### Finding 18 — Low: Config templates missing `validate:` parameter

**Observed:** The `validate:` parameter (which runs a command to validate the rendered file before replacing it) is used in:
- `common_setup/tasks/main.yml` for `sshd_config.j2`  ✓
- `bastion/tasks/main.yml` for `sshd_config.j2`  ✓
- `unbound/tasks/main.yml` for `unbound.conf.j2` (uses `unbound-checkconf`)  ✓

**Missing `validate:` on:**
- All Prometheus config (`prometheus.yml.j2`) — `promtool check config` is available
- All Traefik configs (`traefik.yml.j2`, `dynamic.yml.j2`) — `traefik healthcheck` available
- Loki config (`loki.yml.j2`) — Loki supports `-config.verify`
- Grafana config (`grafana.ini.j2`) — no standard validate tool, but a syntax check is possible

**Recommendation:** Add `validate:` to the prometheus template at minimum:
```yaml
- name: Create Prometheus configuration
  ansible.builtin.template:
    src: prometheus.yml.j2
    dest: /etc/prometheus/prometheus.yml
    owner: prometheus
    group: prometheus
    mode: "0644"
    validate: /usr/local/bin/promtool check config %s
  notify: Restart prometheus
```

---

### Finding 19 — Low: `common` collection `galaxy.yml` declares `kubernetes.core` dependency unnecessarily

**File:** `ansible_collections/homelab/common/galaxy.yml`, line 28

```yaml
dependencies:
  community.general: ">=7.0.0"
  ansible.posix: ">=1.5.0"
  community.crypto: ">=2.0.0"
  kubernetes.core: ">=2.4.0"    # <-- not used in common roles
  community.proxmox: ">=1.3.0"
```

`kubernetes.core` is only used in the K3s collection. The `common` collection roles (`common_setup`, `container_base`, `security_hardening`, `vm_base`, `docker`, `monitoring_agent`) contain no Kubernetes module calls. This forces anyone installing just `homelab.common` to also pull down `kubernetes.core` (a large collection).

**Recommendation:** Move `kubernetes.core` dependency to `ansible_collections/homelab/k3s/galaxy.yml`.

---

### Finding 20 — Low: `secrets` detection pattern in pre-commit is incomplete

**File:** `/home/pbs/ansible/homelab/.pre-commit-config.yaml`, lines 64–73

**Current regex:**
```
pattern="(password|secret|preshared_key|private_key|api_key|token|credential):\s*['\"][^'\"]{8,}"
```

This pattern:
1. Requires the value to be in single or double quotes — a bare YAML value like `password: mysecret` would not match.
2. Uses `grep -v "{{"`  to exclude Jinja2 templated values, but this exclusion is not anchored, so a line like `password: "mypassword # see {{ vault_example }}"` would be excluded.
3. Does not scan `.env` files, `*.sh` scripts, or configuration files in `scripts/`.

The existing pattern would miss a bare value like:
```yaml
wireguard_public_endpoint: "81.108.204.223"  # real IP
vault_proxmox_passwords:
  pve_mac: myrealpassword     # bare value, no quotes
```

Note: A real public IP (`81.108.204.223`) is committed in `ansible_collections/homelab/proxmox_lxc/inventory/group_vars/networking.yml` line 6. This is not a secret per se, but illustrates the pattern of concrete network data in version control.

**Recommendation:** Use `detect-secrets` or `trufflehog` as the primary scanner rather than a custom regex. Both are already mentioned in the Makefile's `security-scan` target. Add them to the pre-commit pipeline.

---

## Cross-Cutting Patterns

### Idempotency Anti-patterns (aggregated)

Three separate patterns each individually break idempotency:
1. `changed_when: true` (34 occurrences) — task always reports changed
2. `apt: upgrade: true` (5 roles) — always upgrades packages
3. `changed_when: false` on tasks with side effects (prometheus cert extraction, blocklist conversion)

Together they mean that a second run of the full playbook against an already-provisioned environment will report hundreds of spurious changes, making legitimate drift impossible to detect.

### Firewall Backend Inconsistency

Three different firewall backends are used across the codebase:
- `community.general.ufw` — K3s nodes (`common/roles/security_hardening`), HomeAssistant, media services
- `ansible.builtin.iptables` — LXC service roles (Traefik, WireGuard, AdGuard, Unbound, Bastion), `proxmox_lxc/roles/security_hardening`
- Direct `pct` config for Proxmox-level firewall rules (`container_base`)

No single role or variable controls which backend is active. The `security_hardening.ufw_enabled` default variable exists in `proxmox_lxc/roles/security_hardening/defaults/main.yml` but the task file unconditionally uses `configure_iptables.yml` — the `ufw_enabled` flag is effectively dead code in the LXC security_hardening role.

### Iptables Persistence: Dead Code in `netfilter-persistent`

Every service role that uses iptables manually re-creates the same `iptables-restore.service` systemd unit. However, Debian/Ubuntu ships `iptables-persistent` and `netfilter-persistent` which provide this functionality as an apt package. Using the packaged solution would eliminate 7 code duplications and integrate with the OS update cycle.

```yaml
# Replace all manual iptables-restore.service creation with:
- name: Install netfilter-persistent for iptables rule persistence
  ansible.builtin.apt:
    name: netfilter-persistent
    state: present

- name: Save iptables rules via netfilter-persistent
  ansible.builtin.command: netfilter-persistent save
  changed_when: true  # This one is legitimately always-changed
```

---

## Prioritised Remediation Plan

### Immediate (blocking correctness)

1. **Fix `when:` on `import_playbook`** — The skip_networking/skip_monitoring/skip_k3s variables have never worked. Either document this or switch to `include_playbook`.
2. **Remove `apt: upgrade: true`** from the 5 service roles — this is causing non-idempotent runs on every deployment.
3. **Fix `when:` in meta/dependencies** — The `use_container_base` and `use_security_hardening` variables are advertising a feature that doesn't exist.

### Short-term (technical debt)

4. **Consolidate duplicate roles** — Delete the 7 duplicate roles from `proxmox_lxc` that belong in `k3s`.
5. **Apply FQCN to `promtail` role** and remove `fqcn[action-core]` suppression from `.ansible-lint`.
6. **Standardise iptables persistence** — Use `netfilter-persistent` package instead of 7 duplicate systemd unit definitions.
7. **Fix `changed_when: true`** — Start with the iptables-save tasks (identical fix across 6+ roles).

### Medium-term (quality improvements)

8. **Migrate `community.general.proxmox`** to `community.proxmox.proxmox` in the 10 remaining task files.
9. **Consolidate inventory** — Choose one strategy and eliminate the three-inventory ambiguity.
10. **Add `validate:` to Prometheus template** — Use `promtool check config`.
11. **Re-enable `deprecation_warnings`** and work through the warnings.
12. **Standardise `min_ansible_version: "2.17"`** across all role meta.
