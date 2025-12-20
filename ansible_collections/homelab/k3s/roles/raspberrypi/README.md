# Raspberry Pi Role

Detects and configures Raspberry Pi-specific settings for K3s deployment. Handles hardware detection, distribution identification, and OS-specific prerequisites for Raspberry Pi nodes.

## Features

- **Automatic Pi Detection** - Detects Raspberry Pi hardware via /proc/cpuinfo and device-tree
- **Multi-Distribution Support** - Handles Raspbian, Debian, Ubuntu, and Arch Linux ARM
- **OS-Specific Configuration** - Applies distribution-specific prerequisites
- **Hardware Compatibility** - Supports all Raspberry Pi models (Pi 2, 3, 4, 5)
- **ARM Architecture** - Handles both ARMv7 and ARM64 architectures
- **Graceful Fallback** - Skips configuration on non-Pi hardware without errors
- **Distribution Detection** - Identifies OS distribution automatically

## Requirements

- Raspberry Pi hardware (any model) or compatible SBC
- Raspbian, Ubuntu, Debian, or Arch Linux ARM operating system
- Root or sudo access
- homelab.common collection installed

## Role Variables

### Detection Variables (Set Automatically)

```yaml
# Raspberry Pi detection flag (set by role)
raspberry_pi: false  # Set to true if Pi hardware detected

# Detected distribution (set by role)
detected_distribution: ""  # Set to Raspbian, Debian, Ubuntu, or Archlinux
```

### Configuration Variables

This role does not require user-defined variables. All configuration is automatic based on hardware and OS detection.

## Usage

### Basic Raspberry Pi Setup

```yaml
- hosts: k3s_cluster
  become: yes
  roles:
    - homelab.k3s.raspberrypi
    - homelab.k3s.prereq
    - homelab.k3s.k3s_server
```

### Combined with Other Roles

```yaml
- hosts: all
  become: yes
  roles:
    - homelab.k3s.raspberrypi  # Auto-detects and configures Pi nodes
    - homelab.k3s.prereq
    - homelab.k3s.k3s_server
```

### Conditional Tasks Based on Pi Detection

```yaml
- hosts: all
  become: yes
  roles:
    - homelab.k3s.raspberrypi

  tasks:
    - name: Pi-specific configuration
      when: raspberry_pi | default(false)
      debug:
        msg: "Running on Raspberry Pi"

    - name: Non-Pi configuration
      when: not (raspberry_pi | default(false))
      debug:
        msg: "Running on standard x86_64 hardware"
```

## Detection Process

### Hardware Detection

1. **Check /proc/cpuinfo** - Searches for Raspberry Pi identifiers:
   - "Raspberry Pi"
   - "BCM2708" (Pi 1)
   - "BCM2709" (Pi 2)
   - "BCM2835" (Pi 1/Zero)
   - "BCM2836" (Pi 2)

2. **Check Device Tree** - Searches /proc/device-tree/model for "Raspberry Pi"

3. **Set Pi Flag** - Sets raspberry_pi=true if either check succeeds

### Distribution Detection

1. **Detect Raspbian** - Checks ansible_facts.lsb.id and description
2. **Detect Debian** - Identifies Debian on Raspberry Pi
3. **Detect Arch Linux ARM** - Identifies ARM64 Arch Linux
4. **Set Distribution** - Sets detected_distribution variable

### Prerequisite Execution

1. **Find Prerequisites** - Locates appropriate prereq file:
   - prereq/{{ detected_distribution }}.yml
   - prereq/{{ ansible_distribution }}-{{ ansible_distribution_major_version }}.yml
   - prereq/{{ ansible_distribution }}.yml
   - prereq/default.yml

2. **Execute Tasks** - Runs distribution-specific tasks only on Pi hardware

## Tasks Overview

### Detection Tasks

- **Test /proc/cpuinfo** - Grep for Raspberry Pi hardware identifiers
- **Test Device Tree** - Grep /proc/device-tree/model for Pi identifier
- **Set Pi Fact** - Sets raspberry_pi=true if detection succeeds

### Distribution Detection Tasks

- **Raspbian Detection** - Identifies Raspbian OS
- **Debian Detection** - Identifies Debian on Pi
- **Arch Linux Detection** - Identifies ARM64 Arch Linux on Pi

### Prerequisite Tasks

- **Include Distribution Tasks** - Executes OS-specific configuration
- **Conditional Execution** - Only runs on detected Raspberry Pi hardware

## Supported Distributions

### Raspbian

- Raspberry Pi OS (32-bit)
- Raspberry Pi OS Lite
- Based on Debian Bullseye/Bookworm
- Tasks: prereq/Raspbian.yml

### Debian

- Debian 11 (Bullseye)
- Debian 12 (Bookworm)
- ARM64 or ARMv7 architecture
- Tasks: prereq/Debian.yml

### Ubuntu

- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 20.04 LTS (Focal)
- Ubuntu Server for Raspberry Pi
- Tasks: prereq/Ubuntu.yml

### Arch Linux ARM

- Arch Linux ARM (aarch64)
- Latest rolling release
- Tasks: prereq/Archlinux.yml

### CentOS/RHEL

- CentOS Stream
- RHEL for ARM
- Tasks: prereq/CentOS.yml

### Fallback

- Any other distribution
- Generic configuration
- Tasks: prereq/default.yml

## Hardware Support

### Raspberry Pi Models

- **Raspberry Pi 5** - Broadcom BCM2712 (ARM Cortex-A76)
- **Raspberry Pi 4** - Broadcom BCM2711 (ARM Cortex-A72)
- **Raspberry Pi 3** - Broadcom BCM2837 (ARM Cortex-A53)
- **Raspberry Pi 2** - Broadcom BCM2836/2837 (ARM Cortex-A7/A53)
- **Raspberry Pi 1/Zero** - Broadcom BCM2835 (ARM1176JZF-S)

### Architecture Support

- **ARM64 (aarch64)** - 64-bit ARM (Pi 3, 4, 5)
- **ARMv7l** - 32-bit ARM (Pi 2, 3)
- **ARMv6l** - 32-bit ARM (Pi 1, Zero)

## Distribution-Specific Prerequisites

Each distribution has its own prerequisite tasks file that handles:

- Package manager configuration
- Required package installation
- Kernel module setup
- System service configuration
- Boot configuration
- Memory/swap settings

## Files and Templates

### Detection Files

- **/proc/cpuinfo** - CPU and hardware information
- **/proc/device-tree/model** - Device tree model string

### Prerequisite Task Files

- **prereq/Raspbian.yml** - Raspbian-specific configuration
- **prereq/Debian.yml** - Debian-specific configuration
- **prereq/Ubuntu.yml** - Ubuntu-specific configuration
- **prereq/Archlinux.yml** - Arch Linux-specific configuration
- **prereq/CentOS.yml** - CentOS/RHEL-specific configuration
- **prereq/default.yml** - Generic fallback configuration

## Handlers

This role does not define handlers. Any required service restarts are handled in the distribution-specific task files.

## Dependencies

None. This role is designed to run before other roles in the deployment sequence.

## Integration Points

### With prereq Role

- Should run before prereq role
- Sets raspberry_pi fact used by other roles
- Configures OS-specific settings before general prerequisites

### With Security Hardening

- Detection facts used by security_hardening role
- Pi-specific security settings applied when raspberry_pi=true

### With K3s Roles

- Ensures proper OS configuration before K3s installation
- ARM architecture detection for correct binary selection

## Validation

### Verify Pi Detection

```bash
# On Raspberry Pi, check hardware
cat /proc/cpuinfo | grep -i raspberry

# Check device tree model
cat /proc/device-tree/model

# Verify architecture
uname -m
```

### Check Distribution

```bash
# View OS information
cat /etc/os-release

# Check LSB information
lsb_release -a
```

## Troubleshooting

### Pi Not Detected

```bash
# Manually check hardware identifiers
grep -E "Raspberry Pi|BCM" /proc/cpuinfo

# Check device tree
cat /proc/device-tree/model

# Verify it's actually a Raspberry Pi
# If detection fails on real Pi, file an issue
```

### Wrong Distribution Detected

```bash
# Check Ansible facts
ansible localhost -m setup -a 'filter=ansible_lsb'

# Verify OS information
cat /etc/os-release
lsb_release -a

# Check detected_distribution variable in playbook output
```

### Prerequisite Tasks Not Running

```bash
# Verify role is included in playbook
# Check that raspberry_pi fact is set:
ansible-playbook playbook.yml -e "debug=true" -v

# Look for "raspberry_pi: true" in output
```

## Security Considerations

- **Hardware Detection** - Read-only operations, no security impact
- **OS Detection** - Uses standard Ansible facts
- **Prerequisite Tasks** - Distribution-specific security depends on prereq files
- **No Credentials** - Does not handle sensitive information

## Performance Considerations

- **Detection Speed** - Hardware detection is very fast (< 1 second)
- **Minimal Overhead** - Only runs on detected Pi hardware
- **Conditional Execution** - Skips unnecessary tasks on non-Pi systems
- **No Network Access** - All detection is local

## Best Practices

### Playbook Structure

```yaml
# Recommended role order
- hosts: all
  become: yes
  roles:
    - homelab.k3s.raspberrypi      # 1. Detect hardware/OS
    - homelab.k3s.prereq           # 2. Configure prerequisites
    - homelab.k3s.security_hardening  # 3. Apply security
    - homelab.k3s.k3s_server       # 4. Deploy K3s
```

### Mixed Environment

```yaml
# When deploying to both Pi and x86_64 nodes
- hosts: all
  become: yes
  roles:
    - homelab.k3s.raspberrypi  # Safe to run on all hosts
    - homelab.k3s.prereq

  tasks:
    - name: Pi-specific configuration
      when: raspberry_pi | default(false)
      include_role:
        name: pi_specific_role

    - name: x86_64 configuration
      when: not (raspberry_pi | default(false))
      include_role:
        name: x86_64_specific_role
```

### Inventory Organization

```ini
# Group Raspberry Pi nodes separately
[pi_nodes]
k3-01 ansible_host=192.168.0.111
k3-02 ansible_host=192.168.0.112

[x86_nodes]
k3s-server ansible_host=192.168.0.100

[k3s_cluster:children]
pi_nodes
x86_nodes
```

## Common Use Cases

### Raspberry Pi K3s Cluster

```yaml
- hosts: pi_nodes
  become: yes
  roles:
    - homelab.k3s.raspberrypi
    - homelab.k3s.prereq
    - homelab.k3s.k3s_server
```

### Mixed Architecture Cluster

```yaml
- hosts: k3s_cluster
  become: yes
  roles:
    - homelab.k3s.raspberrypi  # Detects and configures Pi nodes only
    - homelab.k3s.prereq       # Configures all nodes
    - homelab.k3s.k3s_server
```

### Development Testing

```yaml
- hosts: localhost
  connection: local
  roles:
    - homelab.k3s.raspberrypi

  tasks:
    - name: Show detection results
      debug:
        msg: |
          Raspberry Pi: {{ raspberry_pi | default(false) }}
          Distribution: {{ detected_distribution | default('not detected') }}
          Architecture: {{ ansible_architecture }}
```

## Known Issues

### Generic SBCs

Some non-Raspberry Pi single-board computers may not be detected even if they use similar chipsets. This is intentional to avoid false positives.

### Custom Kernels

Modified kernels that change /proc/cpuinfo or device-tree may affect detection. The role uses multiple detection methods to improve reliability.

## License

Apache License 2.0 - See collection LICENSE file for details.
