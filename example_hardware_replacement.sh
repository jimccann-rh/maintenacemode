#!/bin/bash
# Example: Hardware Replacement with Automatic Shutdown
# Use case: Full data evacuation, automatic shutdown, replace hardware, manually power on

ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --ask-vault-pass \
  --extra-vars "esxi_hostname=esxi01.production.local" \
  --extra-vars "vcenter_hostname=vcenter.production.local" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --extra-vars "vcenter_datacenter=DC-Production" \
  --extra-vars "vcenter_cluster=Cluster-01" \
  --extra-vars "enter_maintenance_datetime='2026-07-07 20:00:00'" \
  --extra-vars "vsan_evacuation_mode=evacuateAllData" \
  --extra-vars "host_action=shutdown" \
  --extra-vars "exit_maintenance_datetime='2026-07-08 06:00:00'"
