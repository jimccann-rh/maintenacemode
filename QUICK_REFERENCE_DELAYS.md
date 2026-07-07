# Quick Reference: Configurable Delays

## Overview

The playbook has several configurable delay periods. Here's a quick reference for adjusting them.

## All Delay Variables

| Variable | Default | Purpose | When to Change |
|----------|---------|---------|----------------|
| `host_action_delay` | 900s (15min) | Wait after entering maintenance before reboot/shutdown | Reduce for testing |
| `vcenter_reconnect_delay` | 900s (15min) | Wait after reconnection before exiting maintenance | Reduce for small environments |
| `post_maintenance_delay_hours` | 4 hours | Wait in maintenance (when `host_action=none`) | Adjust based on maintenance window |
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
  --ask-vault-pass
```

**Result:**
- 5 minutes before reboot/shutdown
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
  --ask-vault-pass
```

**Result:**
- 30 minutes stabilization
- 2 hours of retries for exit maintenance

## Delay Timeline Example

**Scenario:** Firmware update with reboot, 5-minute delays

```
Time  | Event
------|-------------------------------------------------------
00:00 | Enter maintenance mode
00:05 | Wait complete (host_action_delay=300)
00:05 | Reboot host
00:08 | Host boots up
00:12 | SSH available
00:15 | vCenter shows connected
00:20 | Wait complete (vcenter_reconnect_delay=300)
00:20 | Exit maintenance mode
00:21 | COMPLETE
```

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

| Seconds | Minutes | Hours |
|---------|---------|-------|
| 60      | 1       | -     |
| 300     | 5       | -     |
| 600     | 10      | -     |
| 900     | 15      | -     |
| 1800    | 30      | -     |
| 3600    | 60      | 1     |
| 7200    | 120     | 2     |
| 10800   | 180     | 3     |

## Quick Calculation

```bash
# Minutes to seconds
5 minutes = 5 × 60 = 300 seconds
15 minutes = 15 × 60 = 900 seconds
30 minutes = 30 × 60 = 1800 seconds

# Hours to seconds
1 hour = 1 × 3600 = 3600 seconds
2 hours = 2 × 3600 = 7200 seconds
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
```

### Small Production (< 10 hosts)
```bash
host_action_delay=300             # 5 minutes
vcenter_reconnect_delay=300       # 5 minutes
```

### Medium Production (10-50 hosts)
```bash
host_action_delay=900             # 15 minutes (DEFAULT)
vcenter_reconnect_delay=900       # 15 minutes (DEFAULT)
```

### Large Production (50+ hosts, VSAN)
```bash
host_action_delay=1800            # 30 minutes
vcenter_reconnect_delay=1800      # 30 minutes
exit_maintenance_retry_timeout=10800  # 3 hours
```

### After Firmware/BIOS Update
```bash
host_action_delay=900             # 15 minutes
vcenter_reconnect_delay=1800      # 30 minutes (longer for services)
ssh_check_timeout=900             # 15 minutes (DEFAULT - slower boot)
```

## All Variables in One Command

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "host_action_delay=300" \
  --extra-vars "vcenter_reconnect_delay=300" \
  --extra-vars "ssh_check_timeout=300" \
  --extra-vars "exit_maintenance_retry_timeout=3600" \
  --extra-vars "exit_maintenance_retry_delay=60" \
  --ask-vault-pass
```
