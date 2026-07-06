#!/bin/bash
# Helper script to create encrypted vault file

echo "This will create an encrypted vault file for your vCenter password"
echo ""
read -p "Enter your vCenter password: " -s VCENTER_PASS
echo ""

# Create vault file
cat > /tmp/vault_temp.yml << VAULTEOF
---
vault_vcenter_password: "$VCENTER_PASS"
VAULTEOF

# Encrypt it
ansible-vault encrypt /tmp/vault_temp.yml --output vault.yml

# Clean up
rm -f /tmp/vault_temp.yml

echo ""
echo "✓ Vault file created: vault.yml"
echo ""
echo "Run playbook with:"
echo "ansible-playbook vmware_maintenance_mode.yml --extra-vars '@vault.yml' --ask-vault-pass"
