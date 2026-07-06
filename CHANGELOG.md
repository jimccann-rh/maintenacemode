# Changelog

## Latest Version - 2026-07-06

### ✅ Auto IP Lookup Feature & Improved SSH Checks

**New Feature**: Automatically lookup vmk0 IP address from vCenter for SSH connectivity checks.

**Configuration:**
```yaml
autolookupip: true  # Enable auto lookup of vmk0 IP from vCenter
```

**CLI:**
```bash
--extra-vars "autolookupip=true"
```

**How it works:**
1. Connects to vCenter API (prerequisite check 1)
2. Queries vmkernel adapter info for the ESXi host
3. Extracts vmk0 (management interface) IP address
4. Uses this IP for all SSH connectivity checks

**Use cases:**
- ESXi hostname not resolvable in DNS
- Multiple NICs, need to ensure management IP is used
- Hostname points to wrong IP address
- Testing specific management interface connectivity

**SSH Check Improvements:**
- ✅ **Proper failure detection** - SSH checks now correctly fail when port is unreachable
- ✅ **Order changed** - vCenter API checked FIRST, then SSH (was reversed before)
- ✅ **Better timeout handling** - Uses shell TCP check instead of wait_for for reliability
- ✅ **Retry logic** - Post-reboot SSH check retries every 30 seconds for up to 5 minutes

**Example output:**
```
PREREQUISITE CHECK 1: Verify vCenter API connectivity
✓ vCenter API connection is working
✓ ESXi host esxi01.example.com is visible in vCenter

SSH Target: 192.168.1.100
Auto-lookup enabled: Using vmk0 IP from vCenter

PREREQUISITE CHECK 2: Verify SSH connectivity to ESXi host
✓ SSH connection to 192.168.1.100:22 is working
```

### ✅ Exit Maintenance Mode Retry Logic Added

**New Feature**: Automatically retries exiting maintenance mode for up to 1 hour if the initial attempt fails.

**Why this is needed:**
- VMs may still be migrating back to the host
- VSAN data rebalancing may be in progress
- Host services may not be fully ready
- DRS operations may still be running

**How it works:**
1. After the 15-minute stabilization delay, attempts to exit maintenance mode
2. If exit fails, retries every 60 seconds
3. Continues retrying for up to 1 hour (default: 60 attempts)
4. Displays attempt count and time elapsed
5. Fails the playbook if unable to exit after retry window expires

**Configuration:**
```yaml
exit_maintenance_retry_timeout: 3600  # 1 hour retry window (in seconds)
exit_maintenance_retry_delay: 60      # Retry every 60 seconds
```

**CLI Override:**
```bash
--extra-vars "exit_maintenance_retry_timeout=7200"  # 2 hours
--extra-vars "exit_maintenance_retry_delay=120"     # Every 2 minutes
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

### ✅ Host Reboot/Shutdown Option Added

**New Feature**: Automatically reboot or shutdown the host after entering maintenance mode.

**Configuration:**
```yaml
host_action: "none"      # DEFAULT - No action
host_action: "reboot"    # Reboot after 15 minutes in maintenance mode
host_action: "shutdown"  # Shutdown after 15 minutes in maintenance mode
```

**CLI Usage:**
```bash
--extra-vars "host_action=reboot"
--extra-vars "host_action=shutdown"
--extra-vars "host_action=none"
```

**Use Cases:**
- `reboot`: Firmware updates, BIOS updates, kernel patches
- `shutdown`: Hardware replacement, physical maintenance
- `none`: DRS rebalancing, testing (default behavior)

**Delay:** Waits 15 minutes after entering maintenance mode before performing the action (configurable via `host_action_delay`).

**New Example Scripts:**
- `example_firmware_update.sh` - Firmware update with reboot
- `example_hardware_replacement.sh` - Hardware replacement with shutdown

## Previous Updates - 2026-07-06

### ✅ DateTime Calculation Fixed

**Issue**: Ansible's Jinja2 datetime filters don't support `strftime('%s')` for epoch conversion.

**Solution**: Use shell `date` command to convert datetime strings to epoch time:
```yaml
- name: Convert maintenance start time to epoch
  shell: date -d "{{ enter_maintenance_datetime }}" +%s
  register: maintenance_start_epoch

- name: Calculate seconds until maintenance mode entry
  set_fact:
    seconds_until_maintenance: "{{ (maintenance_start_epoch.stdout | int) - (ansible_date_time.epoch | int) }}"
```

**Benefits**:
- ✅ Reliable cross-platform datetime handling
- ✅ No timezone confusion
- ✅ Simple integer math for time calculations

**Test it**: Run `ansible-playbook test_datetime.yml` to verify calculations

### ✅ Deprecation Warnings Fixed

**Updated to use `vmware.vmware` collection** - Eliminated all deprecation warnings by migrating from deprecated `community.vmware` modules to the newer `vmware.vmware` collection.

#### Module Changes:
- `community.vmware.vmware_maintenancemode` → `vmware.vmware.esxi_maintenance_mode`
- `community.vmware.vmware_cluster_info` → `vmware.vmware.cluster_info`
- Updated parameter names to match new modules:
  - `esxi_hostname` → `esxi_host_name`
  - `state: present/absent` → `enable_maintenance_mode: true/false`
  - `vsan` → `vsan_compliance_mode`

#### VSAN Mode Changes:
- `ensureAccessibility` → `ensureObjectAccessibility` (default)
- `evacuateAllData` → `evacuateAllData` (unchanged)
- Added: `noAction` (no data evacuation)

### Features Added

- ✅ **Prerequisite connectivity checks** (SSH and vCenter) before timers start
- ✅ **Vault-based password management** with helper script
- ✅ **Complete example script** with all parameters
- ✅ **Detailed documentation** (README.md, VAULT_SETUP.md)

### Requirements

**Both collections needed:**
```bash
ansible-galaxy collection install community.vmware
ansible-galaxy collection install vmware.vmware
```

**Note**: `community.vmware` is still used for `vmware_host_config_info` as `vmware.vmware` doesn't have an equivalent module yet.

### Breaking Changes

⚠️ **VSAN evacuation mode values changed:**
- Old: `ensureAccessibility`
- New: `ensureObjectAccessibility`

**Action Required**: Update any existing variable files or command-line parameters to use the new value.

### Migration Guide

If you have existing scripts or configurations:

**Old:**
```yaml
vsan_evacuation_mode: "ensureAccessibility"
```

**New:**
```yaml
vsan_evacuation_mode: "ensureObjectAccessibility"
```

**Command Line Old:**
```bash
--extra-vars "vsan_evacuation_mode=ensureAccessibility"
```

**Command Line New:**
```bash
--extra-vars "vsan_evacuation_mode=ensureObjectAccessibility"
```
