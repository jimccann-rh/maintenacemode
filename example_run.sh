#!/bin/bash
# Example: Run VMware maintenance mode playbook with all parameters specified
# This shows a complete working example with all configuration options

# IMPORTANT: Make sure you created vault.yml first!
# Run: ./create_vault.sh OR: ansible-vault create vault.yml

ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --ask-vault-pass \
  --extra-vars "esxi_hostname=esxi01.production.local" \
  --extra-vars "vcenter_hostname=vcenter.production.local" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --extra-vars "vcenter_datacenter=DC-Production" \
  --extra-vars "vcenter_cluster=Cluster-01" \
  --extra-vars "enter_maintenance_datetime='2026-07-06 22:00:00'" \
  --extra-vars "vsan_evacuation_mode=ensureObjectAccessibility" \
  --extra-vars "host_action=reboot" \
  --extra-vars "exit_maintenance_datetime='2026-07-07 03:00:00'"

# Alternative host_action options:
# --extra-vars "host_action=none"      # No reboot/shutdown (use post_maintenance_delay_hours)
# --extra-vars "host_action=reboot"    # Reboot host after 15 minutes in maintenance mode
# --extra-vars "host_action=shutdown"  # Shutdown host after 15 minutes in maintenance mode
