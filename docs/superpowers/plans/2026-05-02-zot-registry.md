# Zot OCI Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a Zot OCI registry LXC container on pve-mac that serves Docker images and Helm charts, fronted by Traefik, with a web UI.

**Architecture:** Single Ubuntu 22.04 LXC (`registry`, 192.168.0.211, container_id 211) running Zot v2.1.2 as a systemd service on HTTP port 5000. Traefik handles TLS termination for `registry.homelab.lan` and proxies to Zot (consistent with all other homelab services). K3s nodes get a `registries.yaml` pointing to `https://registry.homelab.lan` with the step-ca root cert in the system trust store.

**Tech Stack:** Zot v2.1.2, Ansible (community.general.ufw, ansible.builtin.*), htpasswd (apache2-utils), systemd

> **Design deviation:** The spec proposed Zot handling its own TLS with a step-ca cert + renewal timer. This plan uses Traefik for TLS termination instead — consistent with every other homelab service, and removes the need for cert issuance/renewal tasks in the role. Clients (Docker, Helm, K3s containerd) talk to `https://registry.homelab.lan` (Traefik), which proxies over plain HTTP to Zot at port 5000.

---

## File Map

**Create:**
- `ansible_collections/homelab/proxmox_lxc/roles/zot/defaults/main.yml`
- `ansible_collections/homelab/proxmox_lxc/roles/zot/tasks/main.yml`
- `ansible_collections/homelab/proxmox_lxc/roles/zot/handlers/main.yml`
- `ansible_collections/homelab/proxmox_lxc/roles/zot/meta/main.yml`
- `ansible_collections/homelab/proxmox_lxc/roles/zot/templates/config.json.j2`
- `ansible_collections/homelab/proxmox_lxc/roles/zot/templates/zot.service.j2`
- `inventory/group_vars/registry.yml`

**Modify:**
- `inventory/hosts.yml` — add `registry` group + host, add `registry` to `lxc_containers` children
- `ansible_collections/homelab/proxmox_lxc/inventory/proxmox.yml` — add `registry` group pattern
- `ansible_collections/homelab/proxmox_lxc/roles/traefik/defaults/main.yml` — add registry service entry
- `playbooks/applications.yml` — add registry play + K3s registry config play
- `inventory/group_vars/all/vault.yml.example` — add zot vault variable declarations

**Delete (after implementation):**
- `docs/superpowers/specs/2026-05-02-zot-registry-design.md`

---

## Task 1: Add vault variable declarations

**Files:**
- Modify: `inventory/group_vars/all/vault.yml.example`

- [ ] **Step 1: Open vault.yml.example**

```bash
cat inventory/group_vars/all/vault.yml.example
```

- [ ] **Step 2: Add Zot vault variables**

Add the following block to `inventory/group_vars/all/vault.yml.example` alongside the other service credentials:

```yaml
# Zot OCI Registry credentials
vault_zot_admin_user: "admin"
vault_zot_admin_password: "CHANGEME_min12chars"
```

- [ ] **Step 3: Add the same keys to your encrypted vault.yml**

```bash
ansible-vault edit inventory/group_vars/all/vault.yml
```

Add (choose a strong password, minimum 12 characters):

```yaml
vault_zot_admin_user: "admin"
vault_zot_admin_password: "your-strong-password-here"
```

- [ ] **Step 4: Commit**

```bash
git add inventory/group_vars/all/vault.yml.example
git commit -m "feat(registry): add zot vault variable declarations"
```

---

## Task 2: Add registry to inventory

**Files:**
- Modify: `inventory/hosts.yml`
- Create: `inventory/group_vars/registry.yml`
- Modify: `ansible_collections/homelab/proxmox_lxc/inventory/proxmox.yml`

- [ ] **Step 1: Add registry group to inventory/hosts.yml**

In `inventory/hosts.yml`, add after the `automation:` block (before `nas_services:`):

```yaml
    # OCI Registry (Docker images + Helm charts)
    registry:
      hosts:
        registry:
          ansible_host: 192.168.0.211
          container_id: 211
          proxmox_node: pve-mac
          service_port: 5000
```

- [ ] **Step 2: Add registry to lxc_containers children**

In `inventory/hosts.yml`, the `lxc_containers` children block (around line 204) currently reads:

```yaml
    lxc_containers:
      children:
        bastion_hosts:
        monitoring:
        networking:
        automation:
        nas_services:
```

Add `registry:` to it:

```yaml
    lxc_containers:
      children:
        bastion_hosts:
        monitoring:
        networking:
        automation:
        registry:
        nas_services:
```

- [ ] **Step 3: Create inventory/group_vars/registry.yml**

```yaml
---
# OCI registry container resources
lxc_cores: 1
lxc_memory: 512
lxc_swap: 0
lxc_disk_size: 20
```

- [ ] **Step 4: Add registry group pattern to proxmox.yml**

In `ansible_collections/homelab/proxmox_lxc/inventory/proxmox.yml`, add `registry:` inside the `groups:` block, after `logging:`:

```yaml
  registry: >-
    inventory_hostname.startswith('registry')
```

Also add the `service_port` compose entry for registry. In the `compose.service_port` block, add before the final `else 22`:

```yaml
    5000 if inventory_hostname.startswith('registry') else
    22
```

(Replace the existing trailing `22` line with these two lines.)

- [ ] **Step 5: Commit**

```bash
git add inventory/hosts.yml inventory/group_vars/registry.yml \
  ansible_collections/homelab/proxmox_lxc/inventory/proxmox.yml
git commit -m "feat(registry): add registry host to inventory"
```

---

## Task 3: Create Zot role scaffold (meta, defaults, handlers)

**Files:**
- Create: `ansible_collections/homelab/proxmox_lxc/roles/zot/meta/main.yml`
- Create: `ansible_collections/homelab/proxmox_lxc/roles/zot/defaults/main.yml`
- Create: `ansible_collections/homelab/proxmox_lxc/roles/zot/handlers/main.yml`

- [ ] **Step 1: Create meta/main.yml**

```yaml
---
galaxy_info:
  role_name: zot
  author: homelab
  description: Zot OCI registry for Docker images and Helm charts
  min_ansible_version: "2.17"
dependencies: []
```

- [ ] **Step 2: Create defaults/main.yml**

```yaml
---
zot_version: "2.1.2"
zot_port: 5000
zot_user: zot
zot_group: zot
zot_config_dir: /etc/zot
zot_storage_dir: /var/lib/zot
zot_log_dir: /var/log/zot

zot_admin_user: "{{ vault_zot_admin_user }}"
zot_admin_password: "{{ vault_zot_admin_password }}"

zot_configure_firewall: true
```

- [ ] **Step 3: Create handlers/main.yml**

```yaml
---
- name: Reload systemd
  ansible.builtin.systemd:
    daemon_reload: true

- name: Restart zot
  ansible.builtin.systemd:
    name: zot
    state: restarted
```

- [ ] **Step 4: Commit**

```bash
git add ansible_collections/homelab/proxmox_lxc/roles/zot/
git commit -m "feat(registry): add zot role scaffold"
```

---

## Task 4: Create Zot templates

**Files:**
- Create: `ansible_collections/homelab/proxmox_lxc/roles/zot/templates/config.json.j2`
- Create: `ansible_collections/homelab/proxmox_lxc/roles/zot/templates/zot.service.j2`

- [ ] **Step 1: Create templates/config.json.j2**

```json
{
  "distSpecVersion": "1.1.0",
  "storage": {
    "rootDirectory": "{{ zot_storage_dir }}"
  },
  "http": {
    "address": "0.0.0.0",
    "port": "{{ zot_port }}",
    "auth": {
      "htpasswd": {
        "path": "{{ zot_config_dir }}/htpasswd"
      }
    }
  },
  "log": {
    "level": "info",
    "output": "{{ zot_log_dir }}/zot.log"
  },
  "extensions": {
    "search": {
      "enable": true
    },
    "ui": {
      "enable": true
    }
  }
}
```

- [ ] **Step 2: Create templates/zot.service.j2**

```ini
[Unit]
Description=Zot OCI Registry
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User={{ zot_user }}
Group={{ zot_group }}
ExecStart=/usr/local/bin/zot serve {{ zot_config_dir }}/config.json
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 3: Commit**

```bash
git add ansible_collections/homelab/proxmox_lxc/roles/zot/templates/
git commit -m "feat(registry): add zot config and service templates"
```

---

## Task 5: Create Zot tasks

**Files:**
- Create: `ansible_collections/homelab/proxmox_lxc/roles/zot/tasks/main.yml`

- [ ] **Step 1: Create tasks/main.yml**

```yaml
---
- name: Validate required Zot variables
  ansible.builtin.assert:
    that:
      - zot_admin_user is defined
      - zot_admin_user | length > 0
      - zot_admin_password is defined
      - zot_admin_password | length >= 12
    fail_msg: "vault_zot_admin_user and vault_zot_admin_password (min 12 chars) must be set in vault"
  tags: validate

- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true

- name: Install required packages
  ansible.builtin.apt:
    name:
      - apache2-utils
    state: present

- name: Create zot group
  ansible.builtin.group:
    name: "{{ zot_group }}"
    system: true
    state: present

- name: Create zot user
  ansible.builtin.user:
    name: "{{ zot_user }}"
    group: "{{ zot_group }}"
    system: true
    shell: /usr/sbin/nologin
    home: "{{ zot_storage_dir }}"
    create_home: false

- name: Create zot directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ zot_user }}"
    group: "{{ zot_group }}"
    mode: "0755"
  loop:
    - "{{ zot_config_dir }}"
    - "{{ zot_storage_dir }}"
    - "{{ zot_log_dir }}"

- name: Check if zot binary is installed
  ansible.builtin.stat:
    path: /usr/local/bin/zot
  register: zot_binary

- name: Download zot binary
  ansible.builtin.get_url:
    url: "https://github.com/project-zot/zot/releases/download/v{{ zot_version }}/zot-linux-amd64"
    dest: /usr/local/bin/zot
    mode: "0755"
    owner: root
    group: root
  when: not zot_binary.stat.exists

- name: Create htpasswd file for admin user
  ansible.builtin.command:
    cmd: "htpasswd -cbB -C 10 {{ zot_config_dir }}/htpasswd {{ zot_admin_user }} {{ zot_admin_password }}"
    creates: "{{ zot_config_dir }}/htpasswd"
  no_log: true
  notify: Restart zot

- name: Set htpasswd file permissions
  ansible.builtin.file:
    path: "{{ zot_config_dir }}/htpasswd"
    owner: "{{ zot_user }}"
    group: "{{ zot_group }}"
    mode: "0640"

- name: Deploy zot configuration
  ansible.builtin.template:
    src: config.json.j2
    dest: "{{ zot_config_dir }}/config.json"
    owner: "{{ zot_user }}"
    group: "{{ zot_group }}"
    mode: "0644"
  notify: Restart zot

- name: Deploy zot systemd service
  ansible.builtin.template:
    src: zot.service.j2
    dest: /etc/systemd/system/zot.service
    owner: root
    group: root
    mode: "0644"
  notify:
    - Reload systemd
    - Restart zot

- name: Configure UFW firewall for Zot
  community.general.ufw:
    rule: allow
    port: "{{ zot_port }}"
    proto: tcp
    comment: "Zot OCI Registry"
  when: zot_configure_firewall

- name: Enable and start zot
  ansible.builtin.systemd:
    name: zot
    enabled: true
    state: started
    daemon_reload: true

- name: Wait for Zot to be ready
  ansible.builtin.wait_for:
    host: 127.0.0.1
    port: "{{ zot_port }}"
    delay: 2
    timeout: 30
```

- [ ] **Step 2: Run YAML lint**

```bash
yamllint ansible_collections/homelab/proxmox_lxc/roles/zot/
```

Expected: no errors

- [ ] **Step 3: Run Ansible lint**

```bash
ansible-lint ansible_collections/homelab/proxmox_lxc/roles/zot/
```

Expected: no errors (or only warnings about untested modules)

- [ ] **Step 4: Commit**

```bash
git add ansible_collections/homelab/proxmox_lxc/roles/zot/tasks/
git commit -m "feat(registry): add zot role tasks"
```

---

## Task 6: Update Traefik to route registry.homelab.lan

**Files:**
- Modify: `ansible_collections/homelab/proxmox_lxc/roles/traefik/defaults/main.yml`

- [ ] **Step 1: Add registry entry to the services dict**

In `ansible_collections/homelab/proxmox_lxc/roles/traefik/defaults/main.yml`, add inside the `services:` dict after the `truenas:` block:

```yaml
  registry:
    ip: 192.168.0.211
    port: 5000
    domain: registry.{{ homelab_domain }}
```

- [ ] **Step 2: Verify the services dict is valid YAML**

```bash
yamllint ansible_collections/homelab/proxmox_lxc/roles/traefik/defaults/main.yml
```

Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add ansible_collections/homelab/proxmox_lxc/roles/traefik/defaults/main.yml
git commit -m "feat(registry): add registry route to traefik"
```

---

## Task 7: Add registry play to applications.yml

**Files:**
- Modify: `playbooks/applications.yml`

- [ ] **Step 1: Add the registry deployment play**

Append to `playbooks/applications.yml`:

```yaml
- name: Deploy OCI registry
  hosts: registry
  become: true
  gather_facts: false
  pre_tasks:
    - name: Ensure registry container exists
      ansible.builtin.include_role:
        name: homelab.common.container_base
      vars:
        container_resources:
          cores: "{{ lxc_cores | default(1) }}"
          memory: "{{ lxc_memory | default(512) }}"
          swap: "{{ lxc_swap | default(0) }}"
          disk_size: "{{ lxc_disk_size | default(20) }}"
      when: container_id is defined

    - name: Gather facts after container is available
      ansible.builtin.setup:

  roles:
    - role: homelab.common.common_setup
      tags: [common_setup]
    - role: homelab.proxmox_lxc.zot
      tags: [zot, registry]
  tags: [registry, applications]
```

- [ ] **Step 2: Lint the playbook**

```bash
yamllint playbooks/applications.yml
ansible-lint playbooks/applications.yml
```

Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add playbooks/applications.yml
git commit -m "feat(registry): add registry play to applications.yml"
```

---

## Task 8: Add K3s registry configuration play

**Files:**
- Modify: `playbooks/applications.yml`

- [ ] **Step 1: Append the K3s registry config play to applications.yml**

```yaml
- name: Configure K3s nodes for registry access
  hosts: k3s_cluster
  become: true
  gather_facts: false
  tasks:
    - name: Fetch step-ca root certificate from step-ca host
      ansible.builtin.slurp:
        src: /etc/step-ca/certs/root_ca.crt
      delegate_to: step-ca
      register: step_ca_root_cert_raw

    - name: Install step-ca root cert in system trust store
      ansible.builtin.copy:
        content: "{{ step_ca_root_cert_raw.content | b64decode }}"
        dest: /usr/local/share/ca-certificates/homelab-ca.crt
        owner: root
        group: root
        mode: "0644"
      register: ca_cert_installed

    - name: Update CA certificates
      ansible.builtin.command: update-ca-certificates
      when: ca_cert_installed.changed
      changed_when: true

    - name: Ensure /etc/rancher/k3s directory exists
      ansible.builtin.file:
        path: /etc/rancher/k3s
        state: directory
        owner: root
        group: root
        mode: "0755"

    - name: Deploy K3s registry configuration
      ansible.builtin.copy:
        content: |
          mirrors:
            "registry.homelab.lan":
              endpoint:
                - "https://registry.homelab.lan"
          configs:
            "registry.homelab.lan":
              auth:
                username: "{{ vault_zot_admin_user }}"
                password: "{{ vault_zot_admin_password }}"
        dest: /etc/rancher/k3s/registries.yaml
        owner: root
        group: root
        mode: "0600"
      notify: Restart k3s

  handlers:
    - name: Restart k3s
      ansible.builtin.systemd:
        name: "{{ 'k3s' if inventory_hostname == 'k3-01' else 'k3s-agent' }}"
        state: restarted
  tags: [registry, k3s-registry, applications]
```

- [ ] **Step 2: Lint**

```bash
yamllint playbooks/applications.yml
ansible-lint playbooks/applications.yml
```

Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add playbooks/applications.yml
git commit -m "feat(registry): add k3s registry configuration play"
```

---

## Task 9: Smoke-test and validate

- [ ] **Step 1: Run molecule smoke test**

```bash
make test-molecule-smoke
```

Expected: passes (or warns only — the smoke tests don't provision real infrastructure)

- [ ] **Step 2: Dry-run the registry play**

```bash
ansible-playbook playbooks/applications.yml --tags registry \
  --limit registry --check --ask-vault-pass
```

Expected: no errors (some tasks will show "skipped" because the container doesn't exist yet — that's fine)

- [ ] **Step 3: Dry-run K3s registry config play**

```bash
ansible-playbook playbooks/applications.yml --tags k3s-registry \
  --check --ask-vault-pass
```

Expected: shows planned changes to K3s nodes, no errors

- [ ] **Step 4: Deploy for real**

```bash
# Deploy Zot LXC (creates container + installs Zot)
ansible-playbook playbooks/applications.yml --tags registry \
  --limit registry --ask-vault-pass

# Redeploy Traefik to pick up the new route
ansible-playbook playbooks/networking.yml --tags traefik --ask-vault-pass

# Configure K3s nodes
ansible-playbook playbooks/applications.yml --tags k3s-registry --ask-vault-pass
```

- [ ] **Step 5: Verify Zot is reachable**

```bash
# From your local machine — should return 200 with auth challenge
curl -I https://registry.homelab.lan/v2/

# Login
docker login registry.homelab.lan

# Push a test image
docker pull hello-world
docker tag hello-world registry.homelab.lan/hello-world:latest
docker push registry.homelab.lan/hello-world:latest

# Verify web UI is accessible
curl -s -o /dev/null -w "%{http_code}" https://registry.homelab.lan/
# Expected: 200
```

- [ ] **Step 6: Verify K3s can pull from registry**

```bash
# On k3-01 — pull a test image via K3s's bundled crictl
ssh pbs@192.168.0.111 'sudo k3s crictl pull registry.homelab.lan/hello-world:latest'
```

Expected: image pulls successfully

---

## Task 10: Cleanup and docs

**Files:**
- Delete: `docs/superpowers/specs/2026-05-02-zot-registry-design.md`
- Modify: `README.md` (if registry service is listed)
- Modify: `CLAUDE.md` (architecture section)

- [ ] **Step 1: Delete design spec**

```bash
git rm docs/superpowers/specs/2026-05-02-zot-registry-design.md
```

- [ ] **Step 2: Update CLAUDE.md**

In the **Core Services Deployed** section under **Security & Networking**, add:

```markdown
- **Zot OCI Registry** (192.168.0.211) - Docker image and Helm chart registry with web UI
```

In the **Network Layout** section, add `registry: 192.168.0.211` to the LXC container networks list.

In the **Directory Structure** roles list for `proxmox_lxc`, add `zot` to the roles list comment.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "feat(registry): deploy zot oci registry

- New LXC container at 192.168.0.211
- Handles Docker images and Helm charts (OCI mode)
- Web UI at https://registry.homelab.lan/
- K3s nodes configured to pull from registry
- Traefik routes registry.homelab.lan to Zot

Usage:
  docker push registry.homelab.lan/image:tag
  helm push chart.tgz oci://registry.homelab.lan/charts
  https://registry.homelab.lan/"
```

---

## Usage Reference

```bash
# Push Docker image
docker login registry.homelab.lan
docker tag myimage:latest registry.homelab.lan/myimage:latest
docker push registry.homelab.lan/myimage:latest

# Push Helm chart (OCI mode, Helm 3.8+)
helm registry login registry.homelab.lan
helm push mychart-1.0.0.tgz oci://registry.homelab.lan/charts

# Pull in K3s pod spec
# image: registry.homelab.lan/myimage:latest

# Web UI
# https://registry.homelab.lan/

# Re-deploy or update Zot
ansible-playbook playbooks/applications.yml --tags registry --ask-vault-pass

# Update Traefik route only
ansible-playbook playbooks/networking.yml --tags traefik --ask-vault-pass
```

> **Note:** The htpasswd file is created once and not overwritten on re-runs (idempotent via `creates:`). To change the admin password, delete `/etc/zot/htpasswd` on the registry LXC and re-run the playbook.
