# Home Assistant Role

Deploys and configures Home Assistant in an LXC container, providing a comprehensive home automation platform for controlling smart home devices, sensors, and creating advanced automation workflows.

## Features

- **Device Integration** - Supports 2000+ integrations for smart home devices and services
- **Automation Engine** - Visual automation editor and YAML-based automation rules
- **Energy Management** - Track energy consumption and production (solar, battery, etc.)
- **Voice Control** - Integration with Google Assistant, Alexa, and local voice assistants
- **Mobile Apps** - Native iOS and Android apps with push notifications
- **Dashboard UI** - Highly customizable Lovelace dashboard interface
- **Add-on Ecosystem** - Extend functionality with community add-ons
- **Local Control** - Works without cloud dependency for privacy and reliability

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Network access to smart home devices
- Sufficient resources for device integrations (varies by number of devices)
- Optional: MQTT broker for device communication
- Optional: Zigbee/Z-Wave USB dongle for direct device control

## Role Variables

### Container Configuration

```yaml
# Container resource allocation
homeassistant_resources:
  memory: 2048          # Memory in MB (increase with more integrations)
  cores: 2              # CPU cores
  disk_size: "30"       # Disk size in GB

# Network configuration
homeassistant_ip: "192.168.0.208"
homeassistant_container_id: 208
homeassistant_node: "pve-mac"  # Proxmox node name
```

### Home Assistant Configuration

```yaml
# Version configuration
homeassistant_version: "latest"  # Or specific version like "2024.1.0"

# Network settings
homeassistant_port: 8123
homeassistant_ssl_enabled: false  # Enable if not using reverse proxy SSL

# Directory configuration
homeassistant_config_dir: /var/lib/homeassistant/config
homeassistant_data_dir: /var/lib/homeassistant

# User configuration
homeassistant_user: homeassistant
homeassistant_group: homeassistant
```

### Installation Method

```yaml
# Installation method: docker, venv, or supervised
homeassistant_install_method: "docker"  # Recommended for LXC

# Docker configuration (when using Docker method)
homeassistant_docker_image: "ghcr.io/home-assistant/home-assistant"
homeassistant_docker_network: "bridge"
homeassistant_docker_restart_policy: "unless-stopped"
```

### Device Integration

```yaml
# USB device passthrough for Zigbee/Z-Wave dongles
homeassistant_usb_devices:
  - /dev/ttyACM0  # Example: Zigbee coordinator
  - /dev/ttyUSB0  # Example: Z-Wave stick

# Network discovery
homeassistant_enable_mdns: true
homeassistant_enable_upnp: true
```

### Database Configuration

```yaml
# Database backend (SQLite by default, PostgreSQL for high-load)
homeassistant_db_type: "sqlite"  # Or "postgresql"
homeassistant_db_purge_keep_days: 10  # History retention

# PostgreSQL configuration (if using external DB)
homeassistant_db_host: "192.168.0.220"
homeassistant_db_port: 5432
homeassistant_db_name: "homeassistant"
homeassistant_db_user: "homeassistant"
homeassistant_db_password: "{{ vault_homeassistant_db_password }}"
```

### Reverse Proxy Integration

```yaml
# Traefik integration
homeassistant_traefik_enabled: true
homeassistant_domain: "ha.{{ homelab_domain }}"
homeassistant_external_url: "https://ha.{{ homelab_domain }}"

# Trusted proxies
homeassistant_trusted_proxies:
  - "192.168.0.205"  # Traefik IP
  - "172.17.0.0/16"  # Docker network
```

### MQTT Integration

```yaml
# MQTT broker configuration
homeassistant_mqtt_enabled: true
homeassistant_mqtt_broker: "192.168.0.215"
homeassistant_mqtt_port: 1883
homeassistant_mqtt_user: "homeassistant"
homeassistant_mqtt_password: "{{ vault_mqtt_password }}"
homeassistant_mqtt_discovery: true  # Enable MQTT discovery
```

### Backup Configuration

```yaml
# Automated backups
homeassistant_backup_enabled: true
homeassistant_backup_dir: "/mnt/backups/homeassistant"
homeassistant_backup_retention_days: 7
homeassistant_backup_schedule: "0 2 * * *"  # Daily at 2 AM
```

## Usage

### Basic Deployment

```yaml
- hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.homeassistant
```

### With Custom Resources

```yaml
- hosts: proxmox_hosts
  vars:
    homeassistant_resources:
      memory: 4096  # Increased for many integrations
      cores: 4
      disk_size: "50"
    homeassistant_usb_devices:
      - /dev/ttyACM0  # Zigbee coordinator
  roles:
    - homelab.proxmox_lxc.homeassistant
```

### With External Database

```yaml
- hosts: proxmox_hosts
  vars:
    homeassistant_db_type: "postgresql"
    homeassistant_db_host: "192.168.0.220"
    homeassistant_db_name: "homeassistant"
    homeassistant_db_user: "homeassistant"
    homeassistant_db_password: "{{ vault_homeassistant_db_password }}"
  roles:
    - homelab.proxmox_lxc.homeassistant
```

## Initial Setup

### First-Time Configuration

1. Access Home Assistant at `http://192.168.0.208:8123`
2. Create initial admin account
3. Configure location and units
4. Set up first integrations through UI

### Onboarding Checklist

- [ ] Create admin user account
- [ ] Set up location for local weather and sun
- [ ] Configure device trackers for presence detection
- [ ] Add smart home devices and integrations
- [ ] Create first automation
- [ ] Configure mobile app
- [ ] Set up MQTT broker (if using MQTT devices)
- [ ] Configure backup automation

## Integration Examples

### Popular Integrations

```yaml
# Example configuration.yaml additions
homeassistant:
  name: Home
  latitude: !secret latitude
  longitude: !secret longitude
  elevation: 100
  unit_system: metric
  time_zone: America/New_York

# MQTT
mqtt:
  broker: 192.168.0.215
  username: homeassistant
  password: !secret mqtt_password
  discovery: true

# Weather
weather:
  - platform: met
    name: Home Weather

# Zigbee (via Zigbee2MQTT)
mqtt:
  sensor:
    - name: "Living Room Temperature"
      state_topic: "zigbee2mqtt/living_room_sensor"
      value_template: "{{ value_json.temperature }}"
      unit_of_measurement: "°C"
```

### Automation Example

```yaml
# Example automation in automations.yaml
automation:
  - alias: "Turn on lights at sunset"
    trigger:
      platform: sun
      event: sunset
      offset: "-00:30:00"
    action:
      service: light.turn_on
      entity_id: light.living_room

  - alias: "Notify when door opens"
    trigger:
      platform: state
      entity_id: binary_sensor.front_door
      to: 'on'
    action:
      service: notify.mobile_app
      data:
        title: "Front Door"
        message: "Front door opened"
```

## Files and Templates

### Configuration Files

- **configuration.yaml** - Main Home Assistant configuration
- **automations.yaml** - Automation rules
- **scripts.yaml** - Reusable scripts
- **scenes.yaml** - Scene definitions
- **secrets.yaml** - Sensitive credentials (excluded from backups)

### Docker Configuration

- **docker-compose.yml** - Container orchestration (when using Docker)
- **.storage/** - Internal Home Assistant storage (do not edit manually)

### Systemd Service

- **homeassistant.service** - Systemd service unit file (for venv installation)

## Dependencies

- homelab.common.container_base
- homelab.common.security_hardening

## Handlers

- `restart homeassistant` - Restart Home Assistant service
- `reload homeassistant` - Reload configuration without full restart
- `check homeassistant config` - Validate configuration before restart

## Examples

### Complete Docker Deployment

```yaml
- name: Deploy Home Assistant with Docker
  hosts: proxmox_hosts
  vars:
    homeassistant_install_method: "docker"
    homeassistant_resources:
      memory: 4096
      cores: 2
      disk_size: "40"

    homeassistant_traefik_enabled: true
    homeassistant_domain: "homeassistant.homelab.lan"
    homeassistant_external_url: "https://homeassistant.homelab.lan"

    homeassistant_mqtt_enabled: true
    homeassistant_mqtt_broker: "192.168.0.215"

    homeassistant_usb_devices:
      - /dev/ttyACM0  # Zigbee coordinator

    homeassistant_backup_enabled: true
    homeassistant_backup_dir: "/mnt/nas/backups/homeassistant"

  roles:
    - homelab.proxmox_lxc.homeassistant
```

### High-Performance Configuration

```yaml
- name: Deploy Home Assistant with PostgreSQL
  hosts: proxmox_hosts
  vars:
    homeassistant_resources:
      memory: 8192  # High memory for large deployments
      cores: 4
      disk_size: "100"

    homeassistant_db_type: "postgresql"
    homeassistant_db_host: "192.168.0.220"
    homeassistant_db_purge_keep_days: 30

    homeassistant_backup_enabled: true
    homeassistant_backup_retention_days: 14

  roles:
    - homelab.proxmox_lxc.homeassistant
```

## Troubleshooting

### Service Issues

```bash
# Check Home Assistant status
pct exec 208 -- systemctl status homeassistant

# View logs
pct exec 208 -- journalctl -u homeassistant -f

# For Docker installation
pct exec 208 -- docker logs -f homeassistant

# Check configuration
pct exec 208 -- docker exec homeassistant hass --script check_config
```

### Integration Problems

```bash
# Check specific integration logs
pct exec 208 -- grep "ERROR.*mqtt" /var/lib/homeassistant/config/home-assistant.log

# Test MQTT connectivity
pct exec 208 -- mosquitto_sub -h 192.168.0.215 -t '#' -v

# Verify USB device passthrough
pct exec 208 -- ls -la /dev/ttyACM0
```

### Database Issues

```bash
# Check database size
pct exec 208 -- du -sh /var/lib/homeassistant/config/home-assistant_v2.db

# Purge old data
pct exec 208 -- docker exec homeassistant hass --script db purge --days 10

# For PostgreSQL
pct exec 208 -- psql -h 192.168.0.220 -U homeassistant -c "SELECT COUNT(*) FROM states;"
```

### Performance Optimization

```bash
# Monitor resource usage
pct exec 208 -- htop

# Check recorder statistics
# View in Home Assistant UI: Developer Tools -> Statistics

# Optimize database
pct exec 208 -- sqlite3 /var/lib/homeassistant/config/home-assistant_v2.db "VACUUM;"

# Review slow integrations
# View in Home Assistant UI: System -> Logs
```

### USB Device Passthrough Issues

```bash
# Verify device on host
lsusb
ls -la /dev/ttyACM*

# Check LXC container config
pct config 208 | grep lxc.cgroup2.devices.allow

# Add device to container (on Proxmox host)
pct set 208 -dev0 /dev/ttyACM0
```

## Security Considerations

- **Authentication** - Always use strong passwords and enable 2FA
- **Network Exposure** - Use reverse proxy with SSL, avoid direct internet exposure
- **Secrets Management** - Store credentials in secrets.yaml, exclude from backups
- **API Security** - Use long-lived access tokens, rotate regularly
- **USB Security** - Be cautious with USB device passthrough, validate device integrity
- **Backup Security** - Encrypt backups containing sensitive data
- **Integration Permissions** - Grant minimum necessary permissions to integrations
- **Update Policy** - Keep Home Assistant updated for security patches

## Performance Tuning

- **Database Optimization** - Use PostgreSQL for large deployments (>100 entities)
- **Recorder Filters** - Exclude unnecessary entities from history
- **Resource Allocation** - 2GB RAM for basic setup, 4-8GB for 100+ integrations
- **History Retention** - Reduce purge_keep_days for better performance
- **Integration Polling** - Use push updates (MQTT, webhooks) instead of polling when possible
- **Cache Configuration** - Adjust recorder commit interval for write optimization

## Backup and Recovery

### Manual Backup

```bash
# Create backup via UI
# Settings -> System -> Backups -> Create Backup

# Or via CLI
pct exec 208 -- docker exec homeassistant hass --script backup

# Copy backup to external storage
pct exec 208 -- cp /var/lib/homeassistant/config/backups/*.tar /mnt/nas/backups/
```

### Restore from Backup

```bash
# Copy backup to container
pct push 208 backup.tar /var/lib/homeassistant/config/backups/backup.tar

# Restore via UI
# Settings -> System -> Backups -> Select backup -> Restore

# Or restore specific components manually
pct exec 208 -- tar -xvf /var/lib/homeassistant/config/backups/backup.tar -C /restore_temp/
```

## Advanced Configuration

### Custom Components

```yaml
# Install custom components via HACS (Home Assistant Community Store)
homeassistant_hacs_enabled: true
homeassistant_custom_components:
  - "browser_mod"
  - "lovelace-mushroom"
```

### Multi-Instance Setup

```yaml
# Run multiple Home Assistant instances (development, testing)
homeassistant_instances:
  - name: "production"
    port: 8123
    config_dir: "/var/lib/homeassistant/production"
  - name: "testing"
    port: 8124
    config_dir: "/var/lib/homeassistant/testing"
```

## Integration with Homelab Services

- **Traefik** - Reverse proxy with SSL termination
- **Prometheus** - Metrics collection for monitoring
- **Grafana** - Dashboard visualization for sensor data
- **MQTT Broker** - Device communication (Mosquitto)
- **Jellyfin** - Media control integration
- **Unbound/AdGuard** - DNS resolution for device discovery

## License

MIT License - See collection LICENSE file for details.
