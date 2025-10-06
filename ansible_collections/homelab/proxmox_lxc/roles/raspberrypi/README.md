# Raspberry Pi Role

Detects and configures Raspberry Pi hardware for K3s cluster deployment. Handles hardware detection, distribution identification, and applies Raspberry Pi-specific prerequisites and optimizations for Kubernetes operation.

## Features

- **Automatic Detection** - Identifies Raspberry Pi hardware via /proc/cpuinfo and device tree
- **Multi-Model Support** - Supports Pi 3, Pi 4, and newer models
- **Distribution Handling** - Detects Raspbian, Debian, and Arch Linux ARM distributions
- **Hardware Optimization** - Applies Raspberry Pi-specific system configurations
- **Prerequisite Management** - Loads distribution-specific prerequisite tasks
- **Architecture Support** - Handles ARM (32-bit) and ARM64 (64-bit) architectures
- **Graceful Fallback** - Uses default configuration if Raspberry Pi is not detected
- **Fact Registration** - Sets ansible facts for conditional task execution

## Requirements

- Raspberry Pi 3 or newer (recommended: Pi 4 with 4GB+ RAM)
- Supported OS:
  - Raspberry Pi OS (Raspbian) 11+ (Bullseye)
  - Debian 11+ (Bullseye)
  - Arch Linux ARM
- 32GB+ SD card or SSD (recommended: SSD for production)
- Network connectivity
- Root or sudo access

## Role Variables

This role sets the following facts:

```yaml
# Set when Raspberry Pi hardware is detected
raspberry_pi: true

# Detected distribution (one of):
detected_distribution: "Raspbian"  # or "Debian" or "Archlinux"
```

## Hardware Detection

### Detection Methods

The role uses two methods to detect Raspberry Pi hardware:

1. **CPU Information** - Checks /proc/cpuinfo for:
   - "Raspberry Pi"
   - BCM2708 (Pi 1)
   - BCM2709 (Pi 2)
   - BCM2835 (Pi 1)
   - BCM2836 (Pi 2)

2. **Device Tree** - Checks /proc/device-tree/model for:
   - "Raspberry Pi" string

### Supported Models

- **Raspberry Pi 3 Model B/B+** - Minimum for K3s agent nodes
- **Raspberry Pi 4 Model B** - Recommended for K3s server nodes
- **Raspberry Pi 5** - Latest model with optimal performance
- **Compute Module 3/4** - Supported for embedded deployments

## Usage

### Basic Raspberry Pi Detection

```yaml
- name: Configure Raspberry Pi for K3s
  hosts: k3s_cluster
  become: yes
  roles:
    - homelab.proxmox_lxc.raspberrypi
    - homelab.proxmox_lxc.prereq
```

### Conditional K3s Role Selection

```yaml
- name: Deploy K3s with Raspberry Pi optimization
  hosts: k3s_cluster
  become: yes
  roles:
    - homelab.proxmox_lxc.raspberrypi

  tasks:
    - name: Apply Raspberry Pi optimizations
      include_tasks: rpi_optimizations.yml
      when: raspberry_pi | default(false)

    - name: Install K3s server
      include_role:
        name: homelab.proxmox_lxc.k3s_server
      when:
        - inventory_hostname in groups['k3s_servers']
        - raspberry_pi | default(false)
```

### Distribution-Specific Tasks

```yaml
- name: Configure based on detected distribution
  hosts: raspberrypi_nodes
  become: yes
  roles:
    - homelab.proxmox_lxc.raspberrypi

  tasks:
    - name: Configure Raspbian-specific settings
      debug:
        msg: "Configuring for {{ detected_distribution }}"
      when: detected_distribution is defined
```

## Distribution Detection

### Raspbian

Detected when:
- raspberry_pi fact is true
- lsb.id == "Raspbian" OR
- lsb.description matches "[Rr]aspbian.*"

### Debian on Raspberry Pi

Detected when:
- raspberry_pi fact is true
- lsb.id == "Debian" OR
- lsb.description matches "Debian"

### Arch Linux ARM

Detected when:
- raspberry_pi fact is true
- Architecture is aarch64 (ARM64)
- OS family is Archlinux

## Tasks Overview

The role performs the following operations:

1. **CPU Info Check** - Searches /proc/cpuinfo for Raspberry Pi identifiers
2. **Device Tree Check** - Searches /proc/device-tree/model for Raspberry Pi
3. **Fact Setting** - Sets raspberry_pi fact if detected
4. **Distribution Detection** - Identifies specific distribution
5. **Prerequisite Loading** - Includes distribution-specific prerequisite tasks

## Prerequisite Task Loading

The role loads distribution-specific tasks in priority order:

```yaml
# Search paths (first found wins):
1. prereq/{{ detected_distribution }}.yml       # e.g., prereq/Raspbian.yml
2. prereq/{{ ansible_distribution }}-{{ ansible_distribution_major_version }}.yml
3. prereq/{{ ansible_distribution }}.yml
4. prereq/default.yml
```

## Dependencies

This role requires:

- ansible.builtin modules (command, set_fact, include_tasks)

## Files and Templates

### Prerequisite Task Files

Expected prerequisite files (examples):

```bash
tasks/prereq/Raspbian.yml    # Raspbian-specific configuration
tasks/prereq/Debian.yml      # Debian-specific configuration
tasks/prereq/Archlinux.yml   # Arch Linux ARM-specific configuration
tasks/prereq/default.yml     # Fallback configuration
```

## Examples

### Complete Raspberry Pi K3s Cluster

```yaml
- name: Deploy K3s cluster on Raspberry Pi hardware
  hosts: k3s_cluster
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"

  roles:
    - homelab.proxmox_lxc.raspberrypi
    - homelab.proxmox_lxc.prereq

  tasks:
    - name: Verify Raspberry Pi detection
      assert:
        that:
          - raspberry_pi | default(false)
        fail_msg: "This playbook requires Raspberry Pi hardware"
        success_msg: "Raspberry Pi detected: {{ detected_distribution }}"

    - name: Display hardware information
      debug:
        msg:
          - "Model: {{ ansible_lsb.description | default('Unknown') }}"
          - "Architecture: {{ ansible_architecture }}"
          - "Distribution: {{ detected_distribution | default('Not detected') }}"

- name: Install K3s server nodes
  hosts: k3s_servers
  become: yes
  roles:
    - homelab.proxmox_lxc.k3s_server

- name: Install K3s agent nodes
  hosts: k3s_agents
  become: yes
  roles:
    - homelab.proxmox_lxc.k3s_agent
```

### Mixed Architecture Deployment

```yaml
- name: Deploy on mixed x86_64 and ARM cluster
  hosts: k3s_cluster
  become: yes
  roles:
    - homelab.proxmox_lxc.raspberrypi

  tasks:
    - name: Set architecture-specific variables
      set_fact:
        k3s_arch: "{{ 'arm64' if ansible_architecture == 'aarch64' else 'arm' if ansible_architecture == 'armv7l' else 'amd64' }}"

    - name: Configure ARM-specific optimizations
      include_tasks: arm_optimizations.yml
      when: raspberry_pi | default(false)

    - name: Configure x86_64 optimizations
      include_tasks: x86_optimizations.yml
      when: not raspberry_pi | default(false)
```

### Conditional Task Execution

```yaml
- name: Apply hardware-specific configurations
  hosts: all
  become: yes
  roles:
    - homelab.proxmox_lxc.raspberrypi

  tasks:
    - name: Tasks for Raspberry Pi only
      block:
        - name: Optimize SD card performance
          sysctl:
            name: vm.dirty_ratio
            value: 10
            state: present

        - name: Reduce swap usage
          sysctl:
            name: vm.swappiness
            value: 10
            state: present

        - name: Enable cgroup memory
          lineinfile:
            path: /boot/cmdline.txt
            regexp: '^(.*rootwait)(.*)$'
            line: '\1 cgroup_enable=memory cgroup_memory=1\2'
            backrefs: yes
          when: detected_distribution == "Raspbian"
      when: raspberry_pi | default(false)
```

## Troubleshooting

### Detection Not Working

```bash
# Manually check CPU info
cat /proc/cpuinfo | grep -i raspberry

# Check device tree model
cat /proc/device-tree/model

# Verify LSB information
lsb_release -a

# Check facts
ansible localhost -m setup | grep -E 'lsb|architecture'
```

### Distribution Not Detected

```bash
# Check LSB information
cat /etc/lsb-release
cat /etc/os-release

# Verify detected facts
ansible raspberrypi_host -m setup -a 'filter=ansible_lsb'

# Check distribution files
ls -la /etc/*release*
```

### Architecture Issues

```bash
# Verify architecture
uname -m

# Check kernel version
uname -r

# Verify 64-bit support
getconf LONG_BIT
```

## Raspberry Pi Optimizations

### Memory Configuration

For K3s on Raspberry Pi, enable cgroup memory:

```bash
# Raspbian/Raspberry Pi OS
# Edit /boot/cmdline.txt and add:
cgroup_enable=memory cgroup_memory=1
```

### Storage Optimization

Recommended storage configurations:

1. **SD Card** (Development)
   - Use Class 10 or UHS cards
   - 32GB minimum, 64GB recommended
   - Enable log2ram to reduce writes

2. **USB SSD** (Production)
   - Connect via USB 3.0
   - Much better performance and reliability
   - Required for K3s server nodes

### Resource Requirements

**K3s Server Node:**
- Raspberry Pi 4 (4GB+ RAM)
- SSD storage
- Gigabit Ethernet

**K3s Agent Node:**
- Raspberry Pi 3B+ or newer
- 32GB+ storage
- Fast network connection

### Network Configuration

```yaml
# Optimize network for K3s
- name: Configure network parameters
  sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    state: present
  loop:
    - { key: 'net.ipv4.ip_forward', value: 1 }
    - { key: 'net.bridge.bridge-nf-call-iptables', value: 1 }
    - { key: 'net.ipv4.conf.all.forwarding', value: 1 }
  when: raspberry_pi | default(false)
```

## Security Considerations

- **Firmware Updates** - Keep Raspberry Pi firmware updated
- **Boot Security** - Secure /boot partition
- **SSH Hardening** - Disable password authentication
- **Firewall** - Enable UFW with restrictive rules
- **User Security** - Disable default pi user (Raspbian)
- **Network Security** - Use dedicated VLAN for cluster

## Performance Tuning

- **Overclocking** - Consider modest overclocking for Pi 4
- **Cooling** - Ensure adequate cooling (heatsinks/fans)
- **Power Supply** - Use official power supply (5V 3A for Pi 4)
- **Storage** - Use SSD over SD card for production
- **Network** - Use Gigabit Ethernet, avoid WiFi for K3s

## Known Limitations

- **Raspberry Pi 3** - Limited to agent nodes (memory constraints)
- **32-bit OS** - Some container images only support 64-bit
- **Storage I/O** - SD cards can bottleneck performance
- **Memory** - Ensure sufficient RAM for workloads
- **USB Boot** - May require firmware update on older models

## Integration Example

```yaml
- name: Complete Raspberry Pi K3s deployment
  hosts: raspberrypi_cluster
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
    cluster_cidr: "10.42.0.0/16"
    service_cidr: "10.43.0.0/16"

  pre_tasks:
    - name: Update package cache
      apt:
        update_cache: yes
      when: ansible_os_family == "Debian"

  roles:
    - role: homelab.proxmox_lxc.raspberrypi
    - role: homelab.proxmox_lxc.prereq
    - role: homelab.proxmox_lxc.k3s_server
      when: inventory_hostname in groups['k3s_servers']
    - role: homelab.proxmox_lxc.k3s_agent
      when: inventory_hostname in groups['k3s_agents']

  post_tasks:
    - name: Verify cluster status
      command: kubectl get nodes
      register: nodes
      changed_when: false
      run_once: true
      when: inventory_hostname == groups['k3s_servers'][0]

    - name: Display cluster nodes
      debug:
        var: nodes.stdout_lines
      run_once: true
      when: inventory_hostname == groups['k3s_servers'][0]
```

## License

Apache License 2.0 - See collection LICENSE file for details.
