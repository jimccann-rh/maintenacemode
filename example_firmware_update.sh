#!/bin/bash
# Example: Firmware Update with Automatic Reboot
# Use case: Apply firmware update, reboot to activate, then exit maintenance mode

ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --ask-vault-pass \
  --extra-vars "esxi_hostname=esxi01.production.local" \
  --extra-vars "vcenter_hostname=vcenter.production.local" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --extra-vars "vcenter_datacenter=DC-Production" \
  --extra-vars "vcenter_cluster=Cluster-01" \
  --extra-vars "enter_maintenance_datetime='2026-07-07 02:00:00'" \
  --extra-vars "vsan_evacuation_mode=ensureObjectAccessibility" \
  --extra-vars "host_action=reboot" \
  --extra-vars "exit_maintenance_datetime='2026-07-07 06:00:00'"
