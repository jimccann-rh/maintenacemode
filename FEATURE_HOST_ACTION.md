# Host Reboot/Shutdown Feature

## Overview

After entering maintenance mode, the playbook can automatically reboot or shutdown the ESXi host via vCenter API.

## Configuration

### Via Playbook Variables

```yaml
host_action: "none"      # DEFAULT - No action, just wait
host_action: "reboot"    # Reboot after 15 minutes
host_action: "shutdown"  # Shutdown after 15 minutes
```

### Via Command Line

```bash
--extra-vars "host_action=reboot"
--extra-vars "host_action=shutdown"
--extra-vars "host_action=none"
```

## How It Works

1. **Enter Maintenance Mode** - Host placed in maintenance mode with VSAN evacuation
2. **Wait 15 Minutes** - Configurable delay (`host_action_delay: 900` seconds)
3. **Perform Action** - Reboot or shutdown via vCenter API
4. **Continue Workflow** - Playbook waits for scheduled exit check time
5. **Monitor Reconnection** - Checks SSH and vCenter connectivity
6. **Exit Maintenance Mode** - Takes host out of maintenance mode

## Workflow Logic

### With `host_action: "reboot"`
```
Enter Maintenance → Wait 15 min → Reboot → Wait for exit time → 
Check SSH → Check vCenter → Wait 15 min → Exit Maintenance
```

### With `host_action: "shutdown"`
```
Enter Maintenance → Wait 15 min → Shutdown → Wait for exit time → 
Check SSH → Check vCenter → Wait 15 min → Exit Maintenance
```

**Note:** With shutdown, you must manually power on the host before the `exit_maintenance_datetime`.

### With `host_action: "none"` (Default)
```
Enter Maintenance → Wait (post_maintenance_delay_hours) → Wait for exit time → 
Check SSH → Check vCenter → Wait 15 min → Exit Maintenance
```

## Use Cases

### Firmware Update (Reboot)
```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "host_action=reboot" \
  --extra-vars "enter_maintenance_datetime='2026-07-07 02:00:00'" \
  --extra-vars "exit_maintenance_datetime='2026-07-07 06:00:00'" \
  --ask-vault-pass
```

**Timeline:**
- 02:00 - Enter maintenance mode
- 02:15 - Reboot host
- 02:20 - Host boots up
- 06:00 - Check connectivity
- 06:15 - Exit maintenance mode

### Hardware Replacement (Shutdown)
```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "host_action=shutdown" \
  --extra-vars "vsan_evacuation_mode=evacuateAllData" \
  --extra-vars "enter_maintenance_datetime='2026-07-07 20:00:00'" \
  --extra-vars "exit_maintenance_datetime='2026-07-08 06:00:00'" \
  --ask-vault-pass
```

**Timeline:**
- 20:00 - Enter maintenance mode (full VSAN evacuation)
- 20:15 - Shutdown host
- *[Perform hardware replacement]*
- *[Manually power on host before 06:00]*
- 06:00 - Check connectivity
- 06:15 - Exit maintenance mode

### No Action (Testing/DRS)
```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "host_action=none" \
  --extra-vars "post_maintenance_delay_hours=2" \
  --extra-vars "enter_maintenance_datetime='2026-07-07 23:00:00'" \
  --extra-vars "exit_maintenance_datetime='2026-07-08 01:00:00'" \
  --ask-vault-pass
```

**Timeline:**
- 23:00 - Enter maintenance mode
- 23:00 to 01:00 - Wait 2 hours
- 01:00 - Check connectivity
- 01:15 - Exit maintenance mode

## Configuration Options

### Adjust Wait Time Before Action

```yaml
host_action_delay: 1800  # 30 minutes (in seconds)
```

```bash
--extra-vars "host_action_delay=1800"
```

### Configure Post-Action Wait (only for host_action=none)

```yaml
post_maintenance_delay_hours: 6  # 6 hours
```

```bash
--extra-vars "post_maintenance_delay_hours=6"
```

## Important Notes

⚠️ **Shutdown Action**: Requires manual power-on before `exit_maintenance_datetime`

⚠️ **VSAN Evacuation**: Ensure sufficient time for data evacuation before reboot/shutdown

⚠️ **Exit Time**: Set `exit_maintenance_datetime` with enough buffer for host to boot and reconnect

✅ **Default Behavior**: `host_action: "none"` maintains backward compatibility

## Example Scripts

- `example_run.sh` - General example with reboot
- `example_firmware_update.sh` - Firmware update with reboot
- `example_hardware_replacement.sh` - Hardware replacement with shutdown

## Troubleshooting

### Host doesn't reboot
- Check vCenter permissions for power operations
- Verify host is in maintenance mode before reboot attempt
- Check vCenter task history for errors

### Playbook times out waiting for reconnection
- Increase `ssh_check_timeout` (default 300 seconds)
- Increase `vcenter_check_timeout` (default 600 seconds)
- Manually verify host is powered on

### Host action skipped
- Verify `host_action` variable is set correctly (not "None" or empty)
- Check playbook output for conditional skip messages
