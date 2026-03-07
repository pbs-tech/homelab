#!/usr/bin/env bash
# recovery.sh - SSH key recovery for K3s Raspberry Pi nodes via SD card mounting
#
# Use when: control machine has been migrated/rebuilt and SSH keys no longer
# match what is on the Pi nodes. Requires physical access to SD cards.
#
# Usage: ./scripts/recovery.sh

set -euo pipefail

MOUNT_POINT="/mnt/pi"
PUB_KEY_FILE="$HOME/.ssh/homelab_ed25519.pub"

# Pi nodes in order (server first, then agents)
PI_NODES=("k3-01 (192.168.0.111)" "k3-02 (192.168.0.112)" "k3-03 (192.168.0.113)" "k3-04 (192.168.0.114)")

echo "================================================"
echo "  K3s Raspberry Pi SSH Key Recovery"
echo "================================================"
echo ""

# Check public key exists
if [[ ! -f "$PUB_KEY_FILE" ]]; then
  echo "ERROR: Public key not found at $PUB_KEY_FILE"
  echo "Generate one with: ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519 -C homelab-ansible"
  exit 1
fi

echo "Using public key: $PUB_KEY_FILE"
echo "Key contents:"
cat "$PUB_KEY_FILE"
echo ""

# Create mount point if needed
sudo mkdir -p "$MOUNT_POINT"

for node in "${PI_NODES[@]}"; do
  echo "----------------------------------------"
  echo "Node: $node"
  echo "----------------------------------------"
  echo "1. Insert the SD card for $node into your reader"
  echo "2. Wait for it to appear as a block device"
  echo ""

  # Show available block devices to help identify the card
  echo "Current block devices:"
  lsblk -d -o NAME,SIZE,TYPE | grep disk
  echo ""

  read -rp "Enter the device name for the root partition (e.g. sdb2): " partition

  if [[ -z "$partition" ]]; then
    echo "Skipping $node"
    continue
  fi

  device="/dev/$partition"

  if [[ ! -b "$device" ]]; then
    echo "ERROR: $device is not a valid block device, skipping $node"
    continue
  fi

  echo "Mounting $device at $MOUNT_POINT..."
  sudo mount "$device" "$MOUNT_POINT"

  # Detect pbs user UID from the card's passwd file
  PBS_UID=$(grep "^pbs:" "$MOUNT_POINT/etc/passwd" | cut -d: -f3 || echo "1000")
  PBS_GID=$(grep "^pbs:" "$MOUNT_POINT/etc/passwd" | cut -d: -f4 || echo "1000")
  echo "Detected pbs UID:GID as $PBS_UID:$PBS_GID"

  SSH_DIR="$MOUNT_POINT/home/pbs/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"

  sudo mkdir -p "$SSH_DIR"

  # Check if key already present
  if sudo grep -qF "$(cat "$PUB_KEY_FILE")" "$AUTH_KEYS" 2>/dev/null; then
    echo "Key already present in authorized_keys, skipping write"
  else
    cat "$PUB_KEY_FILE" | sudo tee -a "$AUTH_KEYS" > /dev/null
    echo "Key added to $AUTH_KEYS"
  fi

  # Fix ownership and permissions
  sudo chown -R "$PBS_UID:$PBS_GID" "$SSH_DIR"
  sudo chmod 700 "$SSH_DIR"
  sudo chmod 600 "$AUTH_KEYS"
  echo "Permissions set correctly"

  sudo umount "$MOUNT_POINT"
  echo "Unmounted cleanly"
  echo ""

  if [[ "$node" != "${PI_NODES[-1]}" ]]; then
    read -rp "Remove SD card and press enter when ready for next node..."
    echo ""
  fi
done

echo "================================================"
echo "  Recovery complete"
echo "================================================"
echo ""
echo "Reinstall all SD cards and boot the Pi nodes, then verify:"
echo ""
echo "  ansible k3s_cluster -m ping -i inventory/hosts.yml"
echo ""
