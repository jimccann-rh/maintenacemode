# Quick Reference: Configurable Delays

## Overview

The playbook has several configurable delay periods. Here's a quick reference for adjusting them.

## All Delay Variables

| Variable | Default | Purpose | When to Change |
|----------|---------|---------|----------------|
| `host_action_delay` | 900s (15min) | Wait after entering maintenance before reboot/shutdown AND wait after reboot for services to stabilize | Reduce for testing |
| `vcenter_reconnect_delay` | 900s (15min) | Wait after reconnection before exiting maintenance | Reduce for small environments |
| `post_maintenance_delay` | 300s (5min) | When `host_action=none`: stay in maintenance. When `host_action=reboot/shutdown`: wait after action before checking exit time | Adjust based on reboot duration or maintenance window |
| `ssh_check_timeout` | 900s (15min) | How long to wait for SSH connection | Increase for very slow boots |
| `exit_maintenance_retry_timeout` | 3600s (60min) | How long to retry exiting maintenance | Increase for large VSAN clusters |
| `exit_maintenance_retry_delay` | 60s | Time between exit retry attempts | Reduce for faster retries |

## Common Scenarios

### Quick Test/Lab Environment (5 minute delays)

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "host_action_delay=300" \
  --extra-vars "vcenter_reconnect_delay=300" \
  --extra-vars "post_maintenance_delay=300" \
  --ask-vault-pass
```

**Result:**
- 5 minutes before reboot/shutdown
- 5 minutes after reboot/shutdown
- 5 minutes stabilization before exit

### Standard Production (15 minute delays - DEFAULT)

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --ask-vault-pass
```

**Result:**
- 15 minutes before reboot/shutdown
- 15 minutes stabilization before exit

### Conservative/Large Environment (30 minute delays)

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "host_action_delay=1800" \
  --extra-vars "vcenter_reconnect_delay=1800" \
  --ask-vault-pass
```

**Result:**
- 30 minutes before reboot/shutdown
- 30 minutes stabilization before exit

### Large VSAN Cluster (longer exit retries)

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "exit_maintenance_retry_timeout=7200" \
  --extra-vars "vcenter_reconnect_delay=1800" \
  --extra-vars "post_maintenance_delay=1800" \
  --ask-vault-pass
```

**Result:**
- 30 minutes post-reboot delay
- 30 minutes stabilization
- 2 hours of retries for exit maintenance

## Delay Timeline Example

**Scenario:** Firmware update with reboot, default delays

```
Time  | Event
------|-------------------------------------------------------
00:00 | Enter maintenance mode
00:15 | Wait complete (host_action_delay=900s = 15min)
00:15 | Reboot host
00:15 | Post-reboot delay starts (post_maintenance_delay=300s = 5min)
00:20 | Post-reboot delay complete
00:20 | Check if exit_maintenance_datetime arrived (wait if needed)
00:20 | Start checking for SSH
00:22 | SSH available
00:22 | Post-SSH stabilization wait starts
00:37 | Wait complete (host_action_delay=900s = 15min again)
00:37 | Verify vCenter connection
00:52 | Wait complete (vcenter_reconnect_delay=900s = 15min)
00:52 | Exit maintenance mode
00:53 | COMPLETE
```

**Note:** Multiple delays work together:
1. `host_action_delay` (900s = 15min) - Before reboot (VMs settle after migration)
2. `post_maintenance_delay` (300s = 5min) - After reboot command (allow reboot to complete)
3. `ssh_check_timeout` (900s = 15min max) - Retry SSH until host responds
4. `host_action_delay` (900s = 15min) - After SSH (VMware services fully start)
5. `vcenter_reconnect_delay` (900s = 15min) - Before exit (final stabilization)

## Configuration Display

When you run the playbook, you'll see:

```
==========================================
VMware Maintenance Mode Configuration
==========================================
ESXi Host: esxi01.lab.local
vCenter: vcenter.lab.local
Host Action: REBOOT
Host Action Delay: 300 seconds (5 minutes)
Exit Maintenance Check: 2026-07-07 04:00:00
Stabilization Delay Before Exit: 300 seconds (5 minutes)
==========================================
```

## Converting Time Units

| Seconds | Minutes |
|---------|---------|
| 60      | 1       |
| 300     | 5       |
| 600     | 10      |
| 900     | 15      |
| 1800    | 30      |
| 3600    | 60      |
| 7200    | 120     |

## Quick Calculation

```bash
# Minutes to seconds (for host_action_delay, vcenter_reconnect_delay, etc.)
5 minutes = 5 × 60 = 300 seconds
10 minutes = 10 × 60 = 600 seconds
15 minutes = 15 × 60 = 900 seconds
30 minutes = 30 × 60 = 1800 seconds

# post_maintenance_delay uses seconds (like other delay variables)
post_maintenance_delay=600    # 10 minutes
post_maintenance_delay=1800   # 30 minutes
post_maintenance_delay=3600   # 1 hour
```

## Testing Your Configuration

Use the test playbook to verify time calculations:

```bash
ansible-playbook test_datetime.yml
```

This shows how long until your scheduled times without actually doing anything.

## Recommendations by Environment Type

### Lab/Development
```bash
host_action_delay=60              # 1 minute
vcenter_reconnect_delay=180       # 3 minutes
post_maintenance_delay=300        # 5 minutes
```

### Small Production (< 10 hosts)
```bash
host_action_delay=300             # 5 minutes
vcenter_reconnect_delay=300       # 5 minutes
post_maintenance_delay=600        # 10 minutes
```

### Medium Production (10-50 hosts)
```bash
host_action_delay=900             # 15 minutes (DEFAULT)
vcenter_reconnect_delay=900       # 15 minutes (DEFAULT)
post_maintenance_delay=900        # 15 minutes
```

### Large Production (50+ hosts, VSAN)
```bash
host_action_delay=1800            # 30 minutes
vcenter_reconnect_delay=1800      # 30 minutes
post_maintenance_delay=1800       # 30 minutes
exit_maintenance_retry_timeout=10800  # 3 hours
```

### After Firmware/BIOS Update
```bash
host_action_delay=900             # 15 minutes
vcenter_reconnect_delay=1800      # 30 minutes (longer for services)
post_maintenance_delay=3600       # 60 minutes (firmware can take time)
ssh_check_timeout=900             # 15 minutes (DEFAULT - slower boot)
```

## All Variables in One Command

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "host_action_delay=300" \
  --extra-vars "vcenter_reconnect_delay=300" \
  --extra-vars "post_maintenance_delay=300" \
  --extra-vars "ssh_check_timeout=300" \
  --extra-vars "exit_maintenance_retry_timeout=3600" \
  --extra-vars "exit_maintenance_retry_delay=60" \
  --ask-vault-pass
```
