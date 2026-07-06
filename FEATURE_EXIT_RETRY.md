# Exit Maintenance Mode Retry Feature

## Overview

The playbook automatically retries exiting maintenance mode for up to 1 hour if the initial attempt fails. This handles common scenarios where the host isn't immediately ready to exit maintenance mode.

## Why Is This Needed?

When attempting to exit maintenance mode, several operations may still be in progress:

### Common Blocking Conditions

1. **VM Migration (DRS)**
   - VMs are being migrated back to the host
   - vMotion operations in progress
   - Can take 5-30 minutes depending on VM count and size

2. **VSAN Rebalancing**
   - Storage objects being reprotected
   - Data replication in progress
   - Can take 10-60+ minutes depending on data volume

3. **Host Services Starting**
   - ESXi services still initializing after reboot
   - vSAN services coming online
   - Can take 2-10 minutes

4. **vCenter Synchronization**
   - vCenter updating host inventory
   - Performance metrics collection resuming
   - Can take 1-5 minutes

## How It Works

### Default Behavior

```
Wait 15 min → Attempt Exit → Failed → Wait 60s → Retry → ... → Success/Timeout
```

**Timeline Example:**
- 06:00 - 15-minute stabilization delay starts
- 06:15 - First exit attempt (FAIL - VMs still migrating)
- 06:16 - Retry attempt 1 (FAIL)
- 06:17 - Retry attempt 2 (FAIL)
- ...
- 06:27 - Retry attempt 12 (SUCCESS)
- Total time: 27 minutes
- Total attempts: 13

### Configuration

```yaml
exit_maintenance_retry_timeout: 3600  # 1 hour retry window (seconds)
exit_maintenance_retry_delay: 60      # Retry every 60 seconds
```

**Calculations:**
- Maximum attempts = `exit_maintenance_retry_timeout / exit_maintenance_retry_delay`
- Default: 3600 / 60 = 60 attempts
- Total maximum time = 15 min stabilization + 60 min retries = 75 minutes

### CLI Override

Increase retry window for large VSAN clusters:
```bash
--extra-vars "exit_maintenance_retry_timeout=7200"  # 2 hours
```

Retry less frequently to reduce vCenter load:
```bash
--extra-vars "exit_maintenance_retry_delay=120"  # Every 2 minutes
```

Decrease for testing environments:
```bash
--extra-vars "exit_maintenance_retry_timeout=600"  # 10 minutes
--extra-vars "exit_maintenance_retry_delay=30"     # Every 30 seconds
```

## Output Example

### Success After Retries

```
========================================
Attempting to Exit Maintenance Mode
========================================
Retry Window: 3600 seconds (60 minutes)
Retry Interval: 60 seconds
Deadline: 1783410000
========================================

TASK [Exit maintenance mode via vCenter API with retries]
FAILED - RETRYING: [localhost]: Exit maintenance mode (59 retries left)
FAILED - RETRYING: [localhost]: Exit maintenance mode (58 retries left)
FAILED - RETRYING: [localhost]: Exit maintenance mode (57 retries left)
...
FAILED - RETRYING: [localhost]: Exit maintenance mode (48 retries left)
ok: [localhost] (retry 12)

TASK [Display exit maintenance result]
ok: [localhost] => {
    "msg": [
        "Exit Maintenance Result: SUCCESS",
        "Attempts Made: 12",
        "Time Elapsed: 720 seconds"
    ]
}
```

### Failure After Timeout

```
========================================
Attempting to Exit Maintenance Mode
========================================
Retry Window: 3600 seconds (60 minutes)
Retry Interval: 60 seconds
========================================

TASK [Exit maintenance mode via vCenter API with retries]
FAILED - RETRYING: [localhost]: Exit maintenance mode (59 retries left)
FAILED - RETRYING: [localhost]: Exit maintenance mode (58 retries left)
...
FAILED - RETRYING: [localhost]: Exit maintenance mode (1 retries left)
fatal: [localhost]: FAILED!

TASK [Fail if unable to exit maintenance mode]
fatal: [localhost]: FAILED! => {
    "msg": "FAILED: Unable to exit maintenance mode after 3600 seconds (60 minutes) of retrying."
}
```

## Use Cases

### Large VSAN Cluster
```bash
# Host has 50+ VMs and 10TB of VSAN data
--extra-vars "exit_maintenance_retry_timeout=10800"  # 3 hours
--extra-vars "exit_maintenance_retry_delay=120"      # Every 2 minutes
```

### Small Test Environment
```bash
# Host has 5 VMs, no VSAN
--extra-vars "exit_maintenance_retry_timeout=600"   # 10 minutes
--extra-vars "exit_maintenance_retry_delay=30"      # Every 30 seconds
```

### Standard Production Host
```bash
# Default settings work well
# 1 hour retry window, 60 second intervals
# No extra-vars needed
```

## Monitoring & Debugging

### Check Why Exit Is Failing

**During playbook execution, in another terminal:**

```bash
# Check vCenter tasks
ssh vcenter.local "vim-cmd vimsvc/task_list" | grep -i maintenance

# Check DRS activity
# PowerCLI
Get-VMHost esxi01 | Get-VM | Select Name, VMHost, PowerState

# Check VSAN health
esxcli vsan cluster get

# Check host connection state
vim-cmd hostsvc/hostsummary | grep -i state
```

### Common Error Messages

**"Cannot exit maintenance mode - VMs still migrating"**
- DRS is moving VMs back
- Wait for DRS operations to complete
- Check: `Get-Task | Where {$_.Name -like "*relocate*"}`

**"Cannot exit maintenance mode - VSAN not ready"**
- Storage objects reprotecting
- Check VSAN health in vCenter
- May need to increase timeout for large datastores

**"Cannot exit maintenance mode - Host not responding"**
- Host services still starting
- Common after firmware updates
- Usually resolves within 5-10 minutes

## Best Practices

### Sizing the Retry Window

**Small environments (< 10 VMs):**
- 10-15 minutes usually sufficient
- Set: `exit_maintenance_retry_timeout=900`

**Medium environments (10-50 VMs):**
- 30-60 minutes recommended (default)
- Default settings work well

**Large environments (50+ VMs, VSAN):**
- 2-3 hours may be needed
- Set: `exit_maintenance_retry_timeout=10800`

**After full data evacuation:**
- Add extra time for data reprotection
- Multiply retry window by 1.5-2x

### Retry Interval Considerations

**Fast retries (30 seconds):**
- ✅ Exits maintenance mode as soon as possible
- ❌ Creates more vCenter API calls
- Use: Test environments, small clusters

**Standard retries (60 seconds - DEFAULT):**
- ✅ Balanced approach
- ✅ Reasonable vCenter load
- Use: Most production environments

**Slow retries (120+ seconds):**
- ✅ Minimal vCenter load
- ❌ Slower to detect when ready
- Use: Very large environments, rate-limited vCenter

## Failure Handling

If the playbook fails after exhausting retries:

### 1. Check Why It's Failing
```bash
# vCenter UI: Check active tasks on host
# Look for: vMotion, Storage vMotion, VSAN rebalancing
```

### 2. Manually Complete Blocking Operations
```bash
# Cancel stuck tasks in vCenter
# Or wait for operations to complete
```

### 3. Manually Exit Maintenance Mode
```bash
# PowerCLI
Set-VMHost -VMHost esxi01 -State Connected

# Or vCenter UI
# Right-click host → Exit Maintenance Mode
```

### 4. Re-run Playbook (Optional)
```bash
# If you want the playbook to complete the workflow
# It will skip already-completed steps
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "enter_maintenance_datetime='2026-01-01 00:00:00'" \
  --ask-vault-pass
```

## Integration with Other Features

### With Host Reboot
```yaml
host_action: "reboot"
exit_maintenance_retry_timeout: 3600  # Extra time for services to start
```
Reboot adds boot time (~5-10 min) before exit attempts begin.

### With VSAN Evacuation
```yaml
vsan_evacuation_mode: "evacuateAllData"
exit_maintenance_retry_timeout: 7200  # 2 hours for data reprotection
```
Full evacuation needs longer for data to migrate back.

### With Multiple Hosts
When running against multiple hosts in parallel, each gets its own retry window independently.

## Technical Details

**Implementation:**
- Uses Ansible's built-in `retries` and `delay` parameters
- Tracks attempts in `exit_maintenance_result.attempts`
- Calculates time elapsed using epoch timestamps
- Fails with `failed_when: false` to allow custom error handling

**vCenter API Calls:**
- Each retry calls `vmware.vmware.esxi_maintenance_mode`
- API timeout per attempt: 3600 seconds (1 hour)
- Total possible time: stabilization + (retries × delay) + api_timeout

**Resource Impact:**
- Minimal - only API calls during retry
- No continuous polling
- vCenter load proportional to retry frequency
