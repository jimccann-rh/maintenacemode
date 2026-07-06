# Auto IP Lookup Feature

## Overview

The `autolookupip` feature automatically retrieves the ESXi host's management IP address (vmk0) from vCenter and uses it for all SSH connectivity checks instead of relying on hostname resolution.

## Why Is This Needed?

### Common Issues with Hostname-Based SSH Checks

1. **DNS Resolution Failures**
   - ESXi hostname not in DNS
   - DNS server unreachable during maintenance window
   - Stale DNS entries pointing to old IP

2. **Multiple Network Interfaces**
   - Hostname resolves to vMotion network instead of management
   - Round-robin DNS returning wrong IP
   - Load balancer IP instead of actual host IP

3. **Name Resolution Inconsistencies**
   - Short name vs FQDN resolution differences
   - Different DNS results from different networks
   - Split DNS configurations

4. **Testing Scenarios**
   - Want to verify specific management interface connectivity
   - Testing IP-based access independent of DNS
   - Validating vmk0 configuration

## How It Works

### Workflow

```
1. Connect to vCenter API
2. Query vmkernel adapter information
3. Find vmk0 adapter
4. Extract IPv4 address
5. Use this IP for all SSH checks
```

### Technical Details

**vCenter API Call:**
```yaml
community.vmware.vmware_vmkernel_info:
  hostname: "{{ vcenter_hostname }}"
  username: "{{ vcenter_username }}"
  password: "{{ vcenter_password }}"
  esxi_hostname: "{{ esxi_hostname }}"
```

**IP Extraction:**
```yaml
# Loop through vmkernel adapters to find vmk0
loop: "{{ vmkernel_info.host_vmk_info[esxi_hostname] }}"
when: item.device == 'vmk0'
set_fact:
  esxi_ssh_ip: "{{ item.ipv4_address }}"
```

**Example vmkernel data structure:**
```json
{
  "host_vmk_info": {
    "esxi01.example.com": [
      {
        "device": "vmk0",
        "ipv4_address": "192.168.1.100",
        "ipv4_subnet_mask": "255.255.255.0",
        "enable_management": true,
        "mac": "00:50:56:xx:xx:xx"
      }
    ]
  }
}
```

**SSH Check:**
```bash
timeout 30 bash -c "</dev/tcp/192.168.1.100/22"
```

## Configuration

### Enable Auto Lookup

**In playbook variables:**
```yaml
autolookupip: true
```

**Via command line:**
```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars "autolookupip=true" \
  --extra-vars '@vault.yml' \
  --ask-vault-pass
```

### Default Behavior

When `autolookupip: false` (default):
- Uses `esxi_hostname` directly for SSH checks
- No vCenter API call for vmkernel info
- Faster prerequisite checks
- Requires hostname to be resolvable

When `autolookupip: true`:
- Queries vCenter for vmk0 IP
- Uses IP address for SSH checks
- Adds ~2-5 seconds to prerequisite checks
- Works regardless of DNS status

## Use Cases

### 1. DNS Issues

**Scenario:** ESXi hosts not in DNS

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars "esxi_hostname=esxi01.production.local" \
  --extra-vars "autolookupip=true" \
  --extra-vars '@vault.yml' \
  --ask-vault-pass
```

Even though `esxi01.production.local` doesn't resolve, the playbook:
1. Connects to vCenter using the hostname (vCenter knows it)
2. Retrieves vmk0 IP (e.g., 192.168.1.100)
3. SSH checks use 192.168.1.100

### 2. Multiple NICs

**Scenario:** Hostname resolves to vMotion network (192.168.10.x) but SSH is only on management (192.168.1.x)

```bash
# Without autolookupip
# SSH to esxi01 → 192.168.10.100 (vMotion) → FAILS

# With autolookupip
# SSH to vmk0 IP → 192.168.1.100 (Management) → SUCCESS
```

### 3. Load Balanced Environment

**Scenario:** DNS returns load balancer VIP, not actual host IP

```bash
# hostname resolves to → 10.0.0.50 (load balancer)
# vmk0 actual IP → 192.168.1.100

# autolookupip=true uses 192.168.1.100
```

### 4. Testing/Validation

**Scenario:** Validate management interface is accessible

```bash
# Explicitly test vmk0 connectivity
--extra-vars "autolookupip=true"
```

## Output Examples

### With autolookupip enabled

```
TASK [PREREQUISITE CHECK 1: Verify vCenter API connectivity]
ok: [localhost]

TASK [Display vCenter connectivity status]
ok: [localhost] => {
    "msg": [
        "✓ vCenter API connection to vcenter.local is working",
        "✓ ESXi host esxi01.production.local is visible in vCenter",
        "  Host info retrieved successfully"
    ]
}

TASK [Get vmk0 IP address from vCenter]
ok: [localhost]

TASK [Display SSH target information]
ok: [localhost] => {
    "msg": [
        "SSH Target: 192.168.1.100",
        "Auto-lookup enabled: Using vmk0 IP from vCenter"
    ]
}

TASK [PREREQUISITE CHECK 2: Verify SSH connectivity to ESXi host]
ok: [localhost]

TASK [Display SSH connectivity status]
ok: [localhost] => {
    "msg": "✓ SSH connection to 192.168.1.100:22 is working"
}
```

### With autolookupip disabled (default)

```
TASK [PREREQUISITE CHECK 1: Verify vCenter API connectivity]
ok: [localhost]

TASK [PREREQUISITE CHECK 2: Verify SSH connectivity to ESXi host]
ok: [localhost]

TASK [Display SSH connectivity status]
ok: [localhost] => {
    "msg": "✓ SSH connection to esxi01.production.local:22 is working"
}
```

## Check Order Change

### Previous Behavior (INCORRECT)

```
1. SSH check to hostname
2. vCenter API check
```

**Problem:** If SSH failed due to DNS issue, you'd never know if vCenter was accessible.

### New Behavior (CORRECT)

```
1. vCenter API check (REQUIRED)
2. Auto IP lookup (if enabled)
3. SSH check (uses IP if autolookupip, otherwise hostname)
```

**Benefits:**
- Validates vCenter access first (most critical)
- Can retrieve IP even if DNS is broken
- Logical dependency order (need vCenter to get IP)

## SSH Check Improvements

### Old SSH Check (wait_for)

```yaml
wait_for:
  host: "{{ esxi_hostname }}"
  port: 22
  timeout: 30
  state: started
```

**Issues:**
- Sometimes didn't properly fail on unreachable hosts
- Timeout behavior inconsistent
- Less reliable failure detection

### New SSH Check (shell TCP)

```yaml
shell: |
  timeout 30 bash -c "</dev/tcp/{{ esxi_ssh_target }}/22" && echo "SUCCESS" || echo "FAILED"
```

**Improvements:**
- ✅ Reliable failure detection
- ✅ Consistent timeout behavior
- ✅ Clear SUCCESS/FAILED output
- ✅ Works with IP or hostname

### Post-Reboot SSH Check

After host reboot, SSH check now includes retries:

```yaml
shell: |
  timeout {{ ssh_check_timeout }} bash -c "</dev/tcp/{{ esxi_ssh_target }}/22"
retries: 10
delay: 30
until: "'SUCCESS' in ssh_check.stdout"
```

**Benefits:**
- Retries every 30 seconds
- Up to 10 attempts (5 minutes)
- Handles gradual service startup after reboot

## Debug Mode

Enable detailed output to see the full vmkernel adapter structure:

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars "autolookupip=true" \
  --extra-vars "debug_mode=true" \
  --extra-vars '@vault.yml' \
  --ask-vault-pass
```

**Output with debug_mode enabled:**
```
TASK [Debug vmkernel info structure]
ok: [localhost] => {
    "vmkernel_info": {
        "changed": false,
        "failed": false,
        "host_vmk_info": {
            "esxi01.example.com": [
                {
                    "device": "vmk0",
                    "dhcp": false,
                    "enable_management": true,
                    "ipv4_address": "192.168.1.100",
                    "ipv4_subnet_mask": "255.255.255.0",
                    "mac": "00:50:56:xx:xx:xx",
                    "mtu": 1500
                },
                {
                    "device": "vmk1",
                    "enable_vmotion": true,
                    "ipv4_address": "192.168.10.100",
                    ...
                }
            ]
        }
    }
}
```

**When to use debug mode:**
- vmk0 lookup fails
- Wrong IP being extracted
- Multiple management interfaces
- Troubleshooting vmkernel configuration

**Default:** Debug mode is **disabled** to keep output clean.

## Troubleshooting

### vmk0 Not Found

**Error:** "No vmk0 adapter found"

**Causes:**
- Non-standard management interface name
- vmk0 disabled or removed
- Permissions issue querying vmkernel info

**Solution:**
1. Check vmkernel adapters in ESXi:
   ```bash
   esxcli network ip interface list
   ```

2. Verify management interface name

3. Disable autolookupip and use hostname:
   ```bash
   --extra-vars "autolookupip=false"
   ```

### vCenter API Call Fails

**Error:** "Unable to retrieve vmkernel info"

**Causes:**
- Insufficient vCenter permissions
- Host not visible in vCenter
- Network connectivity issue

**Solution:**
1. Verify vCenter permissions include:
   - Host.Config.Network (read)
   - System.View

2. Check host is in vCenter inventory

3. Test API access:
   ```bash
   ansible localhost -m community.vmware.vmware_vmkernel_info \
     -a "hostname=vcenter esxi_hostname=esxi01 ..."
   ```

### SSH Still Fails with Correct IP

**Symptom:** IP lookup succeeds but SSH fails

**Causes:**
- Firewall blocking management IP
- SSH service not running
- vmk0 interface down
- Network routing issue

**Debug:**
```bash
# Test SSH manually
ssh root@192.168.1.100

# Check from ESXi console
esxcli network ip interface ipv4 get
esxcli network firewall ruleset rule list | grep ssh

# Check if interface is up
esxcli network ip interface list
```

## Performance Impact

### autolookupip=false (default)
- Prerequisite checks: ~5-10 seconds
- 1 vCenter API call (host config info)
- 1 SSH TCP check

### autolookupip=true
- Prerequisite checks: ~7-15 seconds
- 2 vCenter API calls (host config info + vmkernel info)
- 1 SSH TCP check

**Additional time:** ~2-5 seconds

## Best Practices

### When to Enable

✅ **Enable autolookupip when:**
- ESXi hosts not in DNS
- DNS reliability concerns
- Multiple network interfaces on hosts
- Testing management interface specifically
- Hostname resolution points to wrong IP
- Operating in split DNS environment

### When to Disable (Default)

✅ **Disable autolookupip when:**
- DNS is reliable and working
- Hostname correctly resolves to management IP
- Minimizing vCenter API calls
- Faster prerequisite checks desired
- Standard environment with good DNS

### General Recommendations

1. **Test first** - Try without autolookupip, enable if SSH checks fail
2. **Document** - Note in runbook if autolookupip required for your environment
3. **Monitor** - Watch for vmkernel info query failures
4. **Permissions** - Ensure vCenter account has Host.Config.Network read access

## Security Considerations

### Information Disclosure

Auto IP lookup reveals management IP address in playbook output.

**Mitigation:**
- Output shown only to playbook executor
- No sensitive data stored
- Use vault for credentials

### API Permissions

Requires additional vCenter permission: `Host.Config.Network` (read)

**Recommendation:**
- Use dedicated service account
- Grant minimum required permissions
- Audit vCenter API access logs

## Examples

### Standard Production Environment
```bash
# DNS works, use hostname
--extra-vars "autolookupip=false"
```

### Lab/Test Environment without DNS
```bash
# No DNS, lookup IP from vCenter
--extra-vars "autolookupip=true"
```

### Mixed Environment
```bash
# Use IP lookup only when needed
if ! nslookup esxi01; then
  AUTOLOOKUP=true
else
  AUTOLOOKUP=false
fi

ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars "autolookupip=$AUTOLOOKUP" \
  --extra-vars '@vault.yml' \
  --ask-vault-pass
```
