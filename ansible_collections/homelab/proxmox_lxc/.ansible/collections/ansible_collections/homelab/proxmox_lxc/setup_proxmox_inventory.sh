#!/bin/bash

echo "Setting up Proxmox Dynamic Inventory"
echo "======================================"

# Check if vault password file exists
if [ ! -f ~/.ansible_vault_pass ]; then
    echo "Creating vault password file..."
    echo "Please enter a vault password (this will be stored in ~/.ansible_vault_pass):"
    read -s vault_password
    echo "$vault_password" > ~/.ansible_vault_pass
    chmod 600 ~/.ansible_vault_pass
    echo "Vault password file created at ~/.ansible_vault_pass"
else
    echo "Vault password file already exists at ~/.ansible_vault_pass"
fi

# Encrypt Proxmox password
echo ""
echo "Now we need to encrypt your Proxmox password..."
echo "Please enter your Proxmox root password:"
read -s proxmox_password

echo ""
echo "Encrypting password..."
encrypted_password=$(ansible-vault encrypt_string "$proxmox_password" --name 'password' --vault-password-file ~/.ansible_vault_pass)

echo ""
echo "Replace the password section in inventory/proxmox.yml with:"
echo "password: |"
echo "$encrypted_password" | sed 's/^password: /  /'

echo ""
echo "Setup complete! You can now test the dynamic inventory with:"
echo "ansible-inventory --vault-password-file ~/.ansible_vault_pass --list"
