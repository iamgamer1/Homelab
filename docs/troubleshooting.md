# KingSecure Homelab - Troubleshooting Guide

## Active Directory Issues

### Account Lockout
**Symptoms:** "The referenced account is currently locked out and may not be logged on to."

**Check lockout status:**
```powershell
Get-ADUser -Identity username -Properties LockedOut | Select Name, LockedOut
Search-ADAccount -LockedOut | Select Name, SamAccountName
```

**Find lockout source (Event Viewer):**
- Open Event Viewer → Windows Logs → Security
- Filter for Event ID **4740** (account locked out)
- Event ID **4625** (failed login attempt)

**Unlock account:**
```powershell
Unlock-ADAccount -Identity username
```

---

### Trust Relationship Failed
**Symptoms:** "The trust relationship between this workstation and the primary domain failed"

**Test the secure channel:**
```powershell
Test-ComputerSecureChannel -Verbose
```

**Repair from the client:**
```powershell
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
```

**Reset from DC:**
```powershell
# Run on DC
Reset-ComputerMachinePassword -Server WinServer25-01 -Credential (Get-Credential)
```

**Nuclear option — disjoin and rejoin:**
1. Remove from domain → reboot
2. Rejoin `kingsecure.bj`

---

### GPO Not Applying
**Check applied GPOs on client:**
```cmd
gpresult /r
gpresult /h C:\gpresult.html
```

**Force GPO update:**
```cmd
gpupdate /force
gpupdate /force /boot
```

**Common causes:**
- GPO linked to OU instead of domain root (Account Lockout must be domain-level)
- Client DNS not pointing to `10.10.10.20`
- Client not in correct OU

---

### Ubuntu DNS Resolution Issues
**Symptoms:** Cannot resolve `kingsecure.bj` domains

**Fix — edit systemd-resolved (NOT /etc/resolv.conf):**
```bash
sudo nano /etc/systemd/resolved.conf
```
Add:
```ini
[Resolve]
DNS=10.10.10.20
Domains=kingsecure.bj
```
```bash
sudo systemctl restart systemd-resolved
```

**Verify:**
```bash
resolvectl status
nslookup kingsecure.bj
```

---

### Ubuntu Kerberos Issues
**Symptoms:** `kinit: Cannot find KDC for realm`

**Fix — ensure realm is ALL CAPS in /etc/krb5.conf:**
```bash
# Comment out default entries first
sudo sed -i '/^[^#]/ s/^/#/' /etc/krb5.conf
```

Then add:
```ini
[libdefaults]
    default_realm = KINGSECURE.BJ
```

---

## VMware vSphere Issues

### vMotion — CPU Compatibility Error
**Symptoms:** "The target host does not support the virtual machine's current hardware requirements"

**Fix — Enable EVC:**
1. Power off all VMs on both hosts
2. Cluster → Configure → VMware EVC → Edit
3. Enable EVC for Intel Hosts → Sandy Bridge Generation
4. Power VMs back on

---

### vMotion — Network Not Configured
**Symptoms:** "The vMotion interface is not configured on the Source/Destination host"

**Fix — Create VMkernel adapter on each host:**
1. Host → Configure → Networking → VMkernel Adapters → Add Networking
2. VMkernel Network Adapter → existing vSwitch
3. Enable **vMotion** service
4. Set static IP:
   - OptiPlex: `10.10.10.60`
   - T620: `10.10.10.61`

---

### vMotion — CD/DVD Drive Error
**Symptoms:** "Currently connected device CD/DVD drive uses backing which is not accessible"

**Fix:**
1. Edit VM Settings
2. CD/DVD Drive → change to "Client Device" or uncheck "Connected"

---

### vMotion — Storage Not Accessible
**Symptoms:** "Unable to access file [ESXI-01] VM.vmx"

**Fix — Use Storage vMotion:**
- Select "Change both compute resource AND storage" during migration
- This migrates VM files to destination datastore simultaneously

---

### iDRAC Not Accessible
**Symptoms:** Cannot reach iDRAC web interface

**Check 1 — Previous owner's static IP:**
- Boot server → F2 → iDRAC Settings → Network
- Check if static IP is set to a different subnet
- Enable DHCP or set IP to `10.10.10.197`

**Check 2 — SSL cipher mismatch in Chrome:**
- Use Firefox instead
- Go to `about:config` → `security.tls.version.min` → set to `1`

**Default credentials:**
```
Username: root
Password: calvin
```

---

### ESXi Web UI Password Not Working
**Reset from physical console:**
1. Press F2 at ESXi DCUI
2. Configure Password

**Reset via SSH:**
```bash
ssh root@10.10.10.X
passwd
```

---

## Wazuh SIEM Issues

### Dashboard Not Loading After Reboot
**Symptoms:** Wazuh dashboard times out or shows connection error

**Check service status:**
```bash
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-indexer
sudo systemctl status wazuh-dashboard
```

**Restart services in order:**
```bash
sudo systemctl restart wazuh-indexer
sleep 30
sudo systemctl restart wazuh-manager
sleep 10
sudo systemctl restart wazuh-dashboard
```

**Note:** Allow 10-15 minutes after cold boot for all services to start.

---

## Network Issues

### vCenter SSO Redirect Failing
**Symptoms:** Browser redirects to `vcenter.kingsecure.bj` but can't resolve

**Fix 1 — Use IP directly:**
```
https://10.10.10.30
```

**Fix 2 — Set management machine DNS to DC:**
- Network Settings → IPv4 → Preferred DNS: `10.10.10.20`

**Fix 3 — Add DNS A record on DC:**
- DNS Manager → Forward Lookup Zones → kingsecure.bj
- New Host (A): `vcenter` → `10.10.10.30`
