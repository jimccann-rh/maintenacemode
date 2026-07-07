# VMware Host Maintenance Mode Automation

Ansible playbook for scheduled VMware ESXi host maintenance mode management with VSAN-aware evacuation.

## Features

- ✅ **Prerequisite checks** - Verifies vCenter API and SSH connectivity before starting (in that order)
- ✅ **Auto IP lookup** - Optionally retrieves vmk0 IP from vCenter for SSH connections
- ✅ Scheduled maintenance mode entry via vCenter API
- ✅ VSAN data evacuation modes: `ensureAccessibility` (default) or `evacuateAllData`
- ✅ **Optional host reboot/shutdown** - Automatically reboot or shutdown after entering maintenance mode
- ✅ Configurable delay after entering maintenance mode
- ✅ SSH connectivity verification after reboot
- ✅ vCenter reconnection monitoring
- ✅ 15-minute stabilization delay before exit
- ✅ **Automated maintenance mode exit with retry** - Retries for up to 1 hour if exit fails

## Prerequisites

### Required Packages

```bash
# Install Ansible
pip install ansible

# Install VMware collections
ansible-galaxy collection install community.vmware
ansible-galaxy collection install vmware.vmware
```

### Known Issues

- **Ansible 2.18.x RC Warning**: If using Ansible 2.18.18rc1 or newer, you may see a warning about `community.vmware` collection compatibility. This is safe to ignore - the playbook uses the newer `vmware.vmware` collection for all operations.

### SSL Certificate Validation

**Default:** SSL certificate validation is **disabled** (`vcenter_validate_certs: false`)

This is the default because most vCenter environments use self-signed certificates.

**To enable certificate validation:**
```yaml
vcenter_validate_certs: true
```

Or via command line:
```bash
--extra-vars "vcenter_validate_certs=true"
```

**Note:** Only enable if your vCenter has a valid, trusted SSL certificate.

### Python Dependencies

**Check dependencies:**
```bash
./check_dependencies.sh
```

**Install manually:**
```bash
# For your Python 3.11
pip3.11 install requests pyVmomi pyvim

# OR for Python 3.13
pip3.13 install requests pyVmomi pyvim

# OR using pip3
pip3 install requests pyVmomi pyvim
```

**System packages (alternative):**
```bash
# RHEL/Fedora/CentOS
sudo dnf install python3-requests python3-pyvmomi

# Ubuntu/Debian
sudo apt install python3-requests python3-pyvmomi
```

## Configuration

Edit the variables in `vmware_maintenance_mode.yml`:

### Required Variables

```yaml
# ESXi Host
esxi_hostname: "esxi-host.example.com"
autolookupip: false  # Set to true to lookup vmk0 IP from vCenter for SSH
debug_mode: false    # Set to true to show detailed vmkernel info (for troubleshooting)

# vCenter
vcenter_hostname: "vcenter.example.com"
vcenter_username: "administrator@vsphere.local"
vcenter_password: "{{ vault_vcenter_password }}"
vcenter_datacenter: "Datacenter"
vcenter_cluster: "Cluster"  # Optional
vcenter_validate_certs: false  # Set to true if using valid SSL certificates

# Scheduling
enter_maintenance_datetime: "2026-07-06 22:00:00"  # When to enter maintenance
post_maintenance_delay_hours: 4                     # Hours to wait after entering
exit_maintenance_datetime: "2026-07-07 03:00:00"   # When to check for exit
```

### Auto IP Lookup Feature

By default, the playbook uses the configured `esxi_hostname` for SSH connectivity checks. However, in some environments the hostname may not be resolvable or you want to ensure SSH checks use the management IP.

**Enable auto IP lookup:**
```yaml
autolookupip: true
```

**CLI:**
```bash
--extra-vars "autolookupip=true"
```

**How it works:**
1. Connects to vCenter API
2. Queries vmkernel adapter information for the host
3. Extracts the IP address from vmk0 (management interface)
4. Uses this IP for all SSH connectivity checks

**Use cases:**
- ESXi hostname not in DNS
- Multiple network interfaces, want to ensure management IP is used
- Hostname resolves to wrong IP
- Testing connectivity to specific management interface

**Example output with autolookupip enabled:**
```
✓ vCenter API connection is working
✓ ESXi host esxi01.example.com is visible in vCenter

SSH Target: 192.168.1.100
Auto-lookup enabled: Using vmk0 IP (192.168.1.100) from vCenter

✓ SSH connection to 192.168.1.100:22 is working
```

**Debug mode:**

Enable detailed vmkernel adapter output for troubleshooting:
```bash
--extra-vars "autolookupip=true" \
--extra-vars "debug_mode=true"
```

This will display the full vmkernel info structure, useful if vmk0 lookup fails.

**Note:** Requires vCenter API access before SSH check (checks are now ordered: vCenter first, then SSH).

### VSAN Evacuation Modes

```yaml
vsan_evacuation_mode: "ensureObjectAccessibility"  # DEFAULT - Minimal data movement
# OR
vsan_evacuation_mode: "evacuateAllData"           # Full data migration
# OR
vsan_evacuation_mode: "noAction"                  # No data evacuation
```

**ensureObjectAccessibility** (Default):
- Fastest option
- Keeps at least one accessible copy of data
- Suitable for short maintenance windows
- Minimal cluster impact

**evacuateAllData**:
- Slower, comprehensive migration
- All data moved off the host
- Use for: hardware replacement, decommissioning
- Requires sufficient cluster capacity

**noAction**:
- No data evacuation
- Fastest entry to maintenance mode
- Only use if VSAN is not in use or data availability is not critical during maintenance

### Host Action Options

After entering maintenance mode, you can optionally reboot or shutdown the host.

```yaml
host_action: "none"      # DEFAULT - No action, just wait
# OR
host_action: "reboot"    # Reboot the host after 15 minutes
# OR
host_action: "shutdown"  # Shutdown the host after 15 minutes
```

**none** (Default):
- Host stays powered on in maintenance mode
- Waits for `post_maintenance_delay_hours`
- Suitable for: DRS rebalancing, storage evacuation testing

**reboot**:
- Waits 15 minutes after entering maintenance mode
- Reboots the host via vCenter
- Playbook continues to monitor reconnection
- Suitable for: firmware updates, kernel patches, BIOS updates

**shutdown**:
- Waits 15 minutes after entering maintenance mode
- Shuts down the host via vCenter
- Playbook continues to monitor for power-on and reconnection
- Suitable for: hardware replacement, physical maintenance

**Delay Configuration:**
```yaml
host_action_delay: 900  # 15 minutes (in seconds)
```

### Exit Maintenance Mode Retry Logic

The playbook automatically retries exiting maintenance mode for up to 1 hour after the scheduled exit window.

**Why is this needed?**
- VMs may still be migrating back to the host
- VSAN might still be rebalancing data
- Host services may not be fully ready
- DRS operations may be in progress

**Configuration:**
```yaml
exit_maintenance_retry_timeout: 3600  # 1 hour (in seconds)
exit_maintenance_retry_delay: 60      # Retry every 60 seconds
```

**Behavior:**
- After the 15-minute stabilization delay, playbook attempts to exit maintenance mode
- If exit fails, it retries every 60 seconds
- Continues retrying for up to 1 hour (60 attempts)
- Displays attempt count and time elapsed
- Fails the playbook if unable to exit after 1 hour

**CLI Override:**
```bash
--extra-vars "exit_maintenance_retry_timeout=7200"  # 2 hours
--extra-vars "exit_maintenance_retry_delay=120"     # Retry every 2 minutes
```

**Example Output:**
```
Attempting to Exit Maintenance Mode
Retry Window: 3600 seconds (60 minutes)
Retry Interval: 60 seconds

Exit Maintenance Result: SUCCESS
Attempts Made: 12
Time Elapsed: 720 seconds
```

## Security - Using Ansible Vault

**Never store passwords in plain text!**

### Quick Vault Setup

```bash
# Use the helper script
./create_vault.sh

# OR manually create vault
ansible-vault create vault.yml
```

Add this content:

```yaml
---
vault_vcenter_password: "your-vcenter-password"
```

**See [VAULT_SETUP.md](VAULT_SETUP.md) for detailed instructions**

### Run Playbook with Vault

**IMPORTANT**: You must include `--extra-vars '@vault.yml'` to load the vault file!

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --ask-vault-pass
```

## Usage

### Complete Example with All Parameters

```bash
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
```

**Example Output:**
```
PLAY [VMware Host Maintenance Mode Management] *********************************

TASK [Display configuration] ***************************************************
ok: [localhost] => {
    "msg": [
        "==========================================",
        "VMware Maintenance Mode Configuration",
        "==========================================",
        "ESXi Host: esxi01.production.local",
        "vCenter: vcenter.production.local",
        "Datacenter: DC-Production",
        "Cluster: Cluster-01",
        "Enter Maintenance: 2026-07-06 22:00:00",
        "VSAN Evacuation Mode: ensureAccessibility",
        "Post-Maintenance Delay: 4 hours",
        "Exit Maintenance Check: 2026-07-07 03:00:00",
        "=========================================="
    ]
}

TASK [PREREQUISITE CHECK: Verify SSH connectivity to ESXi host] ***************
ok: [localhost]

TASK [Display SSH connectivity status] *****************************************
ok: [localhost] => {
    "msg": "✓ SSH connection to esxi01.production.local:22 is working"
}

TASK [PREREQUISITE CHECK: Verify vCenter API connectivity] ********************
ok: [localhost]

TASK [Display vCenter connectivity status] *************************************
ok: [localhost] => {
    "msg": [
        "✓ vCenter API connection to vcenter.production.local is working",
        "✓ ESXi host esxi01.production.local is visible in vCenter",
        "  Connection State: connected",
        "  Current Maintenance Mode: False"
    ]
}

TASK [Display prerequisite check summary] **************************************
ok: [localhost] => {
    "msg": [
        "==========================================",
        "✓ All prerequisite checks passed",
        "✓ Ready to begin scheduled maintenance",
        "=========================================="
    ]
}

TASK [Display wait information] ************************************************
ok: [localhost] => {
    "msg": [
        "==========================================",
        "Waiting for Scheduled Maintenance Time",
        "==========================================",
        "Current Time: 2026-07-06 18:00:00",
        "Scheduled Start: 2026-07-06 22:00:00",
        "Seconds to Wait: 14400",
        "Hours to Wait: 4.0",
        "Minutes to Wait: 240",
        "=========================================="
    ]
}

TASK [Wait until scheduled maintenance time] ***********************************
⏳ Pausing for 14400 seconds...
...
```

### Basic Execution (Using Playbook Defaults)

```bash
ansible-playbook vmware_maintenance_mode.yml --ask-vault-pass
```

### Test Configuration (Dry Run)

```bash
ansible-playbook vmware_maintenance_mode.yml --check --ask-vault-pass
```

### Override Individual Variables

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --ask-vault-pass \
  --extra-vars "esxi_hostname=esxi02.lab.local" \
  --extra-vars "vsan_evacuation_mode=evacuateAllData"
```

## Workflow Timeline

**Pre-flight Checks (before timers start):**
1. **vCenter API connectivity test** (verify credentials, get vCenter version)
2. **ESXi host exists in vCenter** (verify host is in inventory)
3. **Auto IP lookup** (if enabled, retrieves vmk0 IP from vCenter)
4. **SSH connectivity test** to ESXi host (30 sec timeout, uses vmk0 IP if autolookupip enabled)

**Scheduled Operations:**
4. **Display wait information** (current time refreshed, scheduled start, hours/minutes to wait)
5. **Wait for scheduled start time** → Enter maintenance mode (skips if time passed)
6. **15-minute delay** (if host_action is set)
7. **Reboot or Shutdown host** (if host_action is "reboot" or "shutdown")
8. **Post-maintenance delay** (configurable hours, only if host_action is "none")
9. **Display exit wait information** (current time, scheduled exit check, hours/minutes to wait)
10. **Wait for exit check time**
11. **SSH connectivity check** (5 min timeout)
12. **vCenter reconnection check** (10 min timeout with retries)
13. **15-minute stabilization delay**
14. **Exit maintenance mode with retry** (up to 1 hour, 60-second intervals)
15. **Display final status** (attempts made, time elapsed)

## Monitoring

The playbook provides debug output at each stage:

```
TASK [Display configuration]
TASK [Wait until scheduled maintenance time]
TASK [Display maintenance mode status]
TASK [Display SSH connectivity status]
TASK [Display vCenter connection status]
TASK [Display final status]
```

## Troubleshooting

### Python Dependencies Missing

**Error:** "Failed to import the required Python library (requests)"

**Cause:** VMware modules require `requests`, `pyVmomi`, and `pyvim` libraries, but they're not installed for the Python version Ansible is using.

**Check dependencies:**
```bash
./check_dependencies.sh
```

**Quick fix:**
```bash
# Find which Python Ansible is using
ansible --version | grep "python version"

# Install for that Python version (e.g., Python 3.13)
python3.13 -m pip install requests pyVmomi pyvim

# OR force Ansible to use a different Python
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars "ansible_python_interpreter=/usr/bin/python3.11" \
  --extra-vars '@vault.yml' \
  --ask-vault-pass
```

**Permanent fix - set environment variable:**
```bash
export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3.11
ansible-playbook vmware_maintenance_mode.yml ...
```

### vCenter Authentication Issues

**Error:** "Unable to log in" or "Authentication failed"

See **[TROUBLESHOOTING_AUTH.md](TROUBLESHOOTING_AUTH.md)** for complete authentication troubleshooting guide.

**Quick fixes:**
1. Verify vault.yml exists: `ansible-vault view vault.yml`
2. Check username format: `administrator@vsphere.local` (not just `administrator`)
3. Test credentials: `ansible-playbook test_vcenter_auth.yml --extra-vars '@vault.yml' --ask-vault-pass`
4. Ensure using: `--extra-vars '@vault.yml'` in command

### DateTime Calculation Errors

The playbook uses the system `date` command to convert datetime strings to epoch time for reliable calculations.

**Required datetime format:**
```
YYYY-MM-DD HH:MM:SS
```

**Example:** `2026-07-07 02:00:00` (24-hour format, no timezone)

**Test datetime calculations:**
```bash
ansible-playbook test_datetime.yml
```

This will show you how many hours/minutes until your scheduled times.

### SSH Connection Check Fails

```bash
# Test SSH port manually
nc -zv esxi-host.example.com 22

# Or use telnet
telnet esxi-host.example.com 22
```

### VMware Collection Not Found

```bash
ansible-galaxy collection install community.vmware --force
```

### vCenter API Connection Issues

```bash
# Test with a simple query
ansible localhost -m community.vmware.vmware_host_info \
  -a "hostname=vcenter.example.com username=admin password=pass esxi_hostname=esxi01 validate_certs=no"
```

### Exit Maintenance Mode Fails After Retries

**Error:** "FAILED: Unable to exit maintenance mode after 3600 seconds (60 minutes) of retrying."

**Common Causes:**
1. **VMs still migrating** - DRS is still moving VMs back to the host
2. **VSAN rebalancing** - Storage objects are still being reprotected
3. **Host not ready** - Services haven't fully started after reboot
4. **Stuck tasks** - vCenter tasks are hung

**Solutions:**

Check vCenter tasks:
```powershell
# PowerCLI - Check running tasks on host
Get-VMHost esxi-host.example.com | Get-Task | Where {$_.State -eq "Running"}
```

Check DRS status:
```powershell
# PowerCLI - Check if DRS is moving VMs
Get-VMHost esxi-host.example.com | Get-VM | Where {$_.PowerState -eq "PoweredOn"} | Select Name, VMHost
```

Manually exit maintenance mode:
```powershell
# PowerCLI - Force exit
Get-VMHost esxi-host.example.com | Set-VMHost -State Connected
```

**Increase retry window:**
```bash
--extra-vars "exit_maintenance_retry_timeout=7200"  # 2 hours
```

### Check Current Maintenance Status Manually

Use vCenter UI or PowerCLI:

```powershell
# PowerCLI
Get-VMHost esxi-host.example.com | Select Name, ConnectionState, @{N="Maintenance";E={$_.State}}
```

## Quick Start Script

A ready-to-use example script is provided:

```bash
# Edit the script with your environment details
nano example_run.sh

# Run it
./example_run.sh
```

The script contains:
- **Start Time/Date**: 2026-07-06 22:00:00
- **Hostname**: esxi01.production.local
- **vCenter**: vcenter.production.local
- **Datacenter**: DC-Production
- **Cluster**: Cluster-01
- **Evacuation Mode**: ensureAccessibility
- **Delay**: 4 hours
- **Exit Check Time**: 2026-07-07 03:00:00

## Example Scenarios

### Scenario 1: Firmware Update with Reboot

```yaml
enter_maintenance_datetime: "2026-07-06 22:00:00"
vsan_evacuation_mode: "ensureObjectAccessibility"
host_action: "reboot"
exit_maintenance_datetime: "2026-07-07 02:00:00"
```

**Use case:** Apply firmware update, reboot to activate, then exit maintenance mode.

### Scenario 2: Hardware Replacement (manual shutdown)

```yaml
enter_maintenance_datetime: "2026-07-06 20:00:00"
vsan_evacuation_mode: "evacuateAllData"
host_action: "shutdown"
exit_maintenance_datetime: "2026-07-07 06:00:00"
```

**Use case:** Full data evacuation, automatic shutdown, replace hardware, manually power on.

### Scenario 3: BIOS Update with Reboot

```yaml
enter_maintenance_datetime: "2026-07-07 01:00:00"
vsan_evacuation_mode: "ensureObjectAccessibility"
host_action: "reboot"
exit_maintenance_datetime: "2026-07-07 04:00:00"
```

**Use case:** Quick BIOS update requiring reboot, minimal data movement.

### Scenario 4: Non-VSAN Host Maintenance (no action)

```yaml
enter_maintenance_datetime: "2026-07-06 23:00:00"
vsan_evacuation_mode: "noAction"
host_action: "none"
post_maintenance_delay_hours: 2
exit_maintenance_datetime: "2026-07-07 01:30:00"
```

**Use case:** DRS rebalancing or testing, no host power changes.

## Safety Features

- ✅ Password masking in logs (`no_log: true`)
- ✅ Retries with delays for state verification
- ✅ Connection state validation before proceeding
- ✅ 15-minute stabilization before exit
- ✅ Comprehensive status reporting

## Notes

- Playbook runs on `localhost` and connects remotely to ESXi/vCenter
- All times are in 24-hour format
- Ensure sufficient VSAN capacity before using `evacuateAllData`
- Monitor vCenter during execution for any warnings
- Consider running in a `screen` or `tmux` session for long delays

## License

MIT
