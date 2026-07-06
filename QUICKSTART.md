# Quick Start Guide

## 1. Install Requirements

```bash
pip install -r requirements.txt
ansible-galaxy collection install community.vmware
ansible-galaxy collection install vmware.vmware
```

## 2. Create Vault File

```bash
./create_vault.sh
```

Enter your vCenter password when prompted.

## 3. Test DateTime Calculations (Optional)

```bash
# Edit test_datetime.yml with your target times
ansible-playbook test_datetime.yml
```

This shows how many hours/minutes until your scheduled maintenance times.

## 4. Edit Configuration

Edit `example_run.sh` or use command line variables:

```bash
esxi_hostname=esxi01.lab.local
vcenter_hostname=vcenter.lab.local
vcenter_username=administrator@vsphere.local
vcenter_datacenter=DC1
vcenter_cluster=Cluster1
enter_maintenance_datetime='2026-07-07 02:00:00'
vsan_evacuation_mode=ensureObjectAccessibility
host_action=reboot  # Options: none, reboot, shutdown
exit_maintenance_datetime='2026-07-07 08:00:00'
```

## 5. Run Playbook

### Using example script:
```bash
./example_run.sh
```

### Using ansible-playbook directly:
```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "esxi_hostname=esxi01.lab.local" \
  --extra-vars "vcenter_hostname=vcenter.lab.local" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --extra-vars "vcenter_datacenter=DC1" \
  --extra-vars "vcenter_cluster=Cluster1" \
  --extra-vars "enter_maintenance_datetime='2026-07-07 02:00:00'" \
  --extra-vars "vsan_evacuation_mode=ensureObjectAccessibility" \
  --extra-vars "post_maintenance_delay_hours=4" \
  --extra-vars "exit_maintenance_datetime='2026-07-07 08:00:00'" \
  --ask-vault-pass
```

## Expected Output

```
TASK [Display configuration] 
✓ Shows all your settings

TASK [PREREQUISITE CHECK: Verify SSH connectivity to ESXi host]
✓ SSH connection to esxi01.lab.local:22 is working

TASK [PREREQUISITE CHECK: Verify vCenter API connectivity]
✓ vCenter API connection is working
✓ ESXi host is visible in vCenter

TASK [Calculate seconds until maintenance mode entry]
✓ Calculates wait time

TASK [Wait until scheduled maintenance time]
⏳ Waiting until 2026-07-07 02:00:00...
```

## Important Notes

- **DateTime Format**: Must be `YYYY-MM-DD HH:MM:SS` (24-hour, no timezone)
- **VSAN Mode**: Use `ensureObjectAccessibility` (default), `evacuateAllData`, or `noAction`
- **Vault Required**: Must include `--extra-vars '@vault.yml'` to load password
- **Long Running**: Playbook may run for hours - use screen/tmux or run in background

## Run in Background (Optional)

```bash
# Start in screen session
screen -S maintenance
./example_run.sh

# Detach: Ctrl+A then D
# Reattach: screen -r maintenance
```

## Troubleshooting

### "vault_vcenter_password is undefined"
- Missing `--extra-vars '@vault.yml'`
- vault.yml file doesn't exist - run `./create_vault.sh`

### "Cannot connect to SSH port 22"
- ESXi host unreachable
- Firewall blocking port 22
- Wrong hostname

### "Cannot connect to vCenter"
- Wrong vCenter hostname
- Wrong username/password
- Network connectivity issue

### "Invalid value for epoch"
- Fixed in latest version - uses shell `date` command now

## Files

- `vmware_maintenance_mode.yml` - Main playbook
- `vault.yml` - Encrypted vCenter password (you create this)
- `example_run.sh` - Example with all parameters
- `test_datetime.yml` - Test time calculations
- `create_vault.sh` - Helper to create vault.yml
- `README.md` - Full documentation
- `VAULT_SETUP.md` - Detailed vault instructions
