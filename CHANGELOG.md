# Changelog

## Latest Version - 2026-07-06

### ✨ Improved: Dynamic Task Names

**Enhancement**: Task names now show actual configured values instead of hardcoded text.

**Before:**
```
TASK [Wait 15 minutes before exiting maintenance mode]
```

**After:**
```
TASK [Wait 15 minutes before exiting maintenance mode]  # Shows actual vcenter_reconnect_delay value
TASK [Wait 10 minutes before exiting maintenance mode]  # If you set vcenter_reconnect_delay=600
TASK [Wait 30 minutes before exiting maintenance mode]  # If you set vcenter_reconnect_delay=1800
```

**Implementation:**
```yaml
# Dynamic task name based on actual variable
- name: "Wait {{ (vcenter_reconnect_delay | int / 60) | int }} minutes before exiting maintenance mode"
```

**CLI override:**
```bash
--extra-vars "vcenter_reconnect_delay=1800"  # 30 minutes
```

### 🐛 Fixed: SSH Check False Positive (CRITICAL)

**Critical Bug Fix**: SSH check was showing success even when host was powered off.

**Problem #1 - No failure handling:**
- Task had `retries` and `until` but no `failed_when`
- When all retries exhausted, task showed "ok" instead of failing

**Problem #2 - TCP check not sufficient:**
- TCP port check (`</dev/tcp/IP/22`) only verifies something is listening
- Doesn't verify it's actually SSH from the ESXi host
- Could be a firewall, load balancer, or proxy responding
- Host could be powered off but network device responds on port 22

**OLD (BROKEN) CHECK:**
```bash
timeout 10 bash -c "</dev/tcp/10.184.15.207/22"
# Returns SUCCESS even if host is OFF but firewall responds!
```

**NEW (FIXED) CHECK - Uses Ansible Native Module:**
```yaml
# Add ESXi host to inventory dynamically
- name: Add ESXi host to inventory for SSH check
  ansible.builtin.add_host:
    name: esxi_temp_host
    ansible_host: "{{ esxi_ssh_target }}"
    ansible_user: root

# Check SSH connection using wait_for_connection
- name: Wait for SSH connection to ESXi host
  ansible.builtin.wait_for_connection:
    delay: 30              # Wait 30s before first attempt
    timeout: 900           # Total timeout: 15 minutes (configurable via ssh_check_timeout)
    sleep: 30              # Wait 30s between attempts
    connect_timeout: 10    # 10s timeout per connection attempt
  delegate_to: esxi_temp_host
```

**Why wait_for_connection is better:**
- ✅ Uses Ansible's actual SSH connection mechanism (not just port checks)
- ✅ Tests full SSH handshake, not just port availability
- ✅ Built-in retry logic with configurable delays
- ✅ No shell scripting required
- ✅ Standard Ansible best practice for SSH checks after reboots
- ✅ Properly fails if host is unreachable (unlike TCP port checks)
- ✅ Default 15 minute timeout allows for slow ESXi boots

**Reference:** [Ansible wait_for_connection documentation](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/wait_for_connection_module.html)

**Real-world test results:**
```bash
# Host powered OFF:
$ ssh -o ConnectTimeout=10 -o BatchMode=yes 10.184.15.207 exit
Connection timed out during banner exchange
→ Check returns: FAILED ✓

# Host powered ON:
$ ssh -o ConnectTimeout=10 -o BatchMode=yes 10.184.15.164 exit  
Host key verification failed
→ Check returns: SUCCESS ✓
```

**Problem:**
- Task had `retries` and `until` but no `failed_when`
- When all retries exhausted, task showed "ok" instead of failing
- Playbook continued even though host was unreachable

**Solution:**
```yaml
- name: Check SSH connectivity (with retries)
  until: "'SUCCESS' in ssh_check.stdout"
  ignore_errors: yes

- name: Fail if SSH never became available
  fail:
    msg: "SSH did not become available after 10 attempts"
  when: "'SUCCESS' not in ssh_check.stdout"
```

**Now shows:**
- Number of attempts made
- Clear failure if host never responds
- Helpful message if host is still powered off

### 🐛 Fixed: String to Int Conversion in Templates

**Bug Fix**: Templates failed when numeric variables were passed via `--extra-vars` as strings.

**Problem:**
```bash
--extra-vars "host_action_delay=60"  # Comes in as string "60"
Template: {{ host_action_delay / 60 }}  # FAILS: str / int
Error: unsupported operand type(s) for /: 'str' and 'int'
```

**Solution:**
Convert to int before division:
```yaml
# OLD (BROKEN)
{{ host_action_delay / 60 }}

# NEW (FIXED)
{{ host_action_delay | int / 60 }}
```

**Fixed templates:**
- ✅ Host action delay display
- ✅ Exit maintenance retry timeout display
- ✅ Exit maintenance retry failure message

### 🐛 Fixed: Stale Time Calculation Bug

**Critical Bug Fix**: Wait time calculations were using stale timestamps from the beginning of playbook execution.

**Problem:**
- `ansible_date_time` is captured when `gather_facts` runs at playbook start
- After hours of running (entering maintenance, delays, etc.), the cached time was stale
- Exit check would calculate wait time based on old timestamp
- Resulted in waiting for already-passed times or incorrect durations

**Example of the bug:**
```
Playbook started: 2026-07-06 16:00:00
Enter maintenance: 2026-07-06 18:00:00 (2 hour wait)
Post-maintenance delay: 4 hours
Exit check scheduled: 2026-07-07 04:00:00

Current actual time: 2026-07-07 09:00:00 (5 hours past exit time!)
But ansible_date_time.epoch still says: 2026-07-06 16:00:00
Calculated wait: 11.78 hours (WRONG!)
```

**Solution:**
- Get fresh current time with `date +%s` before each wait calculation
- Use `lookup('pipe', 'date')` for display timestamps
- Added warning when scheduled time has already passed
- Skip wait if time is in the past

**Changes made:**
```yaml
# OLD (BROKEN)
seconds_until_exit_check: "{{ target_epoch - ansible_date_time.epoch }}"

# NEW (FIXED)
- name: Get current epoch time (refresh for accurate calculation)
  shell: date +%s
  register: current_epoch_exit

- name: Calculate seconds until exit check time
  set_fact:
    seconds_until_exit_check: "{{ target_epoch - current_epoch_exit.stdout }}"
```

**Affected wait points:**
1. ✅ Wait for scheduled maintenance entry time
2. ✅ Wait for scheduled exit check time

**New behavior:**
- Shows warning if scheduled time has already passed
- Skips wait and proceeds immediately if time is past
- Always uses fresh current time for calculations

## Previous Updates - 2026-07-06

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
