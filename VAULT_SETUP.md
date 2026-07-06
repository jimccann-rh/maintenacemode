# Vault Setup Instructions

You need to create an encrypted vault file with your vCenter password.

## Option 1: Quick Setup (Recommended)

Run the helper script:

```bash
./create_vault.sh
```

This will:
1. Prompt for your vCenter password
2. Create an encrypted `vault.yml` file
3. Tell you how to run the playbook

## Option 2: Manual Setup

### Step 1: Create vault file

```bash
ansible-vault create vault.yml
```

You'll be prompted for:
1. **Vault password** (to encrypt the file - remember this!)
2. Then an editor opens

### Step 2: Add this content in the editor

```yaml
---
vault_vcenter_password: "your-actual-vcenter-password-here"
```

Save and exit (`:wq` in vim, or `Ctrl+X` then `Y` in nano)

## Option 3: One-Line Command

```bash
echo "vault_vcenter_password: YourPasswordHere" | ansible-vault encrypt_string --stdin-name 'vault_vcenter_password' > vault.yml
```

## Running the Playbook

### With vault file:

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --ask-vault-pass
```

### Without vault file (password on command line - NOT RECOMMENDED):

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars "vcenter_password=YourPasswordHere"
```

⚠️ **Security Warning**: Option 3 exposes your password in shell history!

## Verifying Your Vault File

Test that it decrypts properly:

```bash
ansible-vault view vault.yml
```

You should see:
```yaml
---
vault_vcenter_password: "your-password"
```

## Example Full Command

```bash
ansible-playbook vmware_maintenance_mode.yml \
  --extra-vars '@vault.yml' \
  --extra-vars "esxi_hostname=esxi01.lab.local" \
  --extra-vars "vcenter_hostname=vcenter.lab.local" \
  --extra-vars "vcenter_username=administrator@vsphere.local" \
  --extra-vars "vcenter_datacenter=DC1" \
  --extra-vars "vcenter_cluster=Cluster1" \
  --extra-vars "enter_maintenance_datetime='2026-07-07 02:00:00'" \
  --extra-vars "post_maintenance_delay_hours=4" \
  --extra-vars "exit_maintenance_datetime='2026-07-07 07:00:00'" \
  --ask-vault-pass
```

## Troubleshooting

### Error: "vault_vcenter_password is undefined"
- You didn't include `--extra-vars '@vault.yml'` in your command
- Or the vault.yml file doesn't exist

### Error: "Decryption failed"
- Wrong vault password entered
- Vault file is corrupted

### Error: "vault.yml not found"
- Run the command from the `/home/jimccann/maintenancemode/` directory
- Or use full path: `--extra-vars '@/home/jimccann/maintenancemode/vault.yml'`
