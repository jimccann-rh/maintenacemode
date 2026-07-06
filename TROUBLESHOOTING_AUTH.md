# vCenter Authentication Troubleshooting

## Quick Diagnostics

### 1. Test Your vCenter Credentials

```bash
ansible-playbook test_vcenter_auth.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "vcenter_hostname=vcenter.example.com" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --ask-vault-pass
```

This will tell you immediately if your credentials work.

### 2. Common Issues

#### Issue: "vault_vcenter_password is undefined"

**Cause:** Vault file not loaded or doesn't exist

**Solutions:**

**Check if vault.yml exists:**
```bash
ls -la vault.yml
```

**If missing, create it:**
```bash
./create_vault.sh
```

**Or manually:**
```bash
ansible-vault create vault.yml
```

Add this content:
```yaml
---
vault_vcenter_password: "YourActualPasswordHere"
```

**Verify vault content:**
```bash
ansible-vault view vault.yml
```

Should show:
```yaml
---
vault_vcenter_password: "YourPassword"
```

**Make sure to include vault in command:**
```bash
--extra-vars '@vault.yml'  # <-- REQUIRED!
```

#### Issue: "Unable to log in" or "Authentication failed"

**Cause:** Wrong password, wrong username format, or account locked

**Solutions:**

**1. Verify username format:**
```bash
# SSO user (most common)
administrator@vsphere.local

# AD user
DOMAIN\username
# OR
username@domain.com

# Local ESXi user (won't work for vCenter!)
root  # WRONG - don't use for vCenter
```

**2. Test credentials manually:**
```bash
# Try logging into vCenter UI with same credentials
# Or use PowerCLI:
Connect-VIServer -Server vcenter.example.com -User administrator@vsphere.local -Password 'YourPassword'
```

**3. Check for special characters in password:**

If your password contains special characters, they may need escaping in YAML:

**Characters that need quotes:**
- `@` `#` `$` `%` `&` `*` `!` `\` `'` `"`

**Example vault.yml:**
```yaml
---
# Password with special chars - use double quotes
vault_vcenter_password: "P@ssw0rd!#$%"

# OR single quotes
vault_vcenter_password: 'P@ssw0rd!#$%'
```

**4. Check account status:**
```bash
# In vCenter UI: Administration → Users and Groups → Users
# Verify:
# - Account not locked
# - Account not expired
# - Password not expired
```

#### Issue: "Connection refused" or "Connection timeout"

**Cause:** Network connectivity or vCenter not reachable

**Solutions:**

**1. Test network connectivity:**
```bash
ping vcenter.example.com
telnet vcenter.example.com 443
# OR
curl -k https://vcenter.example.com
```

**2. Check hostname resolution:**
```bash
nslookup vcenter.example.com
host vcenter.example.com
```

**3. Try IP address instead:**
```bash
--extra-vars "vcenter_hostname=192.168.1.10"
```

#### Issue: "SSL certificate verification failed"

**Cause:** Self-signed certificate or cert validation issue

**Solution:** Already handled in playbook with `validate_certs: no`

If still issues:
```bash
# Verify in playbook:
vcenter_validate_certs: no
```

### 3. Step-by-Step Password Test

**Step 1: Create a simple test vault**
```bash
echo "vault_vcenter_password: TestPassword123" > test_vault.yml
ansible-vault encrypt test_vault.yml
# Enter vault password when prompted
```

**Step 2: Verify you can decrypt it**
```bash
ansible-vault view test_vault.yml
# Should show: vault_vcenter_password: TestPassword123
```

**Step 3: Test with your real password**
```bash
ansible-vault edit vault.yml
```

Change to:
```yaml
---
vault_vcenter_password: "YourRealPasswordHere"
```

Save and exit (`:wq` in vim, `Ctrl+X` then `Y` in nano)

**Step 4: Test authentication**
```bash
ansible-playbook test_vcenter_auth.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "vcenter_hostname=your-vcenter" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --ask-vault-pass
```

### 4. Debug Mode

Run playbook with verbose output:

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "vcenter_hostname=vcenter.example.com" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --ask-vault-pass \
  -vvv  # <-- Add verbose mode
```

Look for:
- Actual username being used
- vCenter hostname being connected to
- SSL/TLS errors
- Network errors

### 5. Test Without Vault (NOT RECOMMENDED FOR PRODUCTION)

To isolate if issue is with vault or credentials:

```bash
ansible-playbook test_vcenter_auth.yml \
  --extra-vars "vcenter_hostname=vcenter.example.com" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --extra-vars "vcenter_password=YourPasswordHere"
```

⚠️ **WARNING:** This exposes password in command history! Only for testing.

If this works, your credentials are correct but vault setup has an issue.

### 6. Common Username Mistakes

❌ **WRONG:**
```bash
--extra-vars "vcenter_username=administrator"  # Missing @vsphere.local
--extra-vars "vcenter_username=root"           # ESXi user, not vCenter
--extra-vars "vcenter_username=admin"          # Not valid SSO user
```

✅ **CORRECT:**
```bash
--extra-vars "vcenter_username=administrator@vsphere.local"
--extra-vars "vcenter_username=myuser@vsphere.local"
--extra-vars "vcenter_username=DOMAIN\\username"  # Note double backslash
```

### 7. Vault Password Issues

#### "Decryption failed"

**Cause:** Wrong vault password entered

**Solution:**
- Re-enter correct vault password
- Or reset vault:
  ```bash
  mv vault.yml vault.yml.old
  ./create_vault.sh
  ```

#### "vault.yml not found"

**Cause:** Running from wrong directory

**Solution:**
```bash
cd /home/jimccann/maintenancemode
ls -la vault.yml  # Should exist
```

**Or use full path:**
```bash
--extra-vars '@/home/jimccann/maintenancemode/vault.yml'
```

### 8. Quick Checklist

Before running the main playbook, verify:

- [ ] vault.yml file exists
- [ ] Can decrypt vault: `ansible-vault view vault.yml`
- [ ] vCenter hostname correct
- [ ] vCenter reachable: `ping vcenter.example.com`
- [ ] Username includes @vsphere.local
- [ ] Password doesn't have typos
- [ ] Using `--extra-vars '@vault.yml'` in command
- [ ] Vault password entered correctly

### 9. Example Working Command

```bash
cd /home/jimccann/maintenancemode

ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --ask-vault-pass \
  --extra-vars "esxi_hostname=esxi01.lab.local" \
  --extra-vars "vcenter_hostname=vcenter.lab.local" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --extra-vars "vcenter_datacenter=DC1" \
  --extra-vars "vcenter_cluster=Cluster1" \
  --extra-vars "enter_maintenance_datetime='2026-07-08 02:00:00'" \
  --extra-vars "exit_maintenance_datetime='2026-07-08 06:00:00'"
```

## Still Not Working?

### Collect Debug Information

```bash
# Test vCenter connectivity
curl -k https://vcenter.example.com/ui/

# Test PowerCLI (if available)
Connect-VIServer -Server vcenter.example.com -User administrator@vsphere.local

# Check Ansible version
ansible --version

# Check VMware collection
ansible-galaxy collection list | grep vmware

# Run auth test with max verbosity
ansible-playbook test_vcenter_auth.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "vcenter_hostname=vcenter.example.com" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --ask-vault-pass \
  -vvvv > debug.log 2>&1
```

Share `debug.log` contents (remove any passwords first!)

## Password Reset

If you need to change the vault password:

```bash
ansible-vault rekey vault.yml
```

Or change the vCenter password inside:

```bash
ansible-vault edit vault.yml
```
