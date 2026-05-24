# RDP Setup via Group Policy

## Overview

This document covers enabling Remote Desktop Protocol (RDP) domain-wide via GPO, granting Domain Users remote access, and configuring the firewall to allow inbound RDP connections.

---

## Step 1 — Create and Link the GPO

1. Open **Group Policy Management** (`gpmc.msc`)
2. Right-click `kingsecure.bj` → **Create a GPO in this domain and Link it here**
3. Name it: `Enable RDP Policy`
4. Right-click the GPO → **Edit**

---

## Step 2 — Enable Remote Desktop via GPO

### Configuration Path

```
Computer Configuration
  └── Policies
        └── Administrative Templates
              └── Windows Components
                    └── Remote Desktop Services
                          └── Remote Desktop Session Host
                                └── Connections
                                      └── Allow users to connect remotely using Remote Desktop Services
```

- Set to: **Enabled**

This enables the RDP listener on all machines the GPO applies to.

---

## Step 3 — Add Domain Users to Remote Desktop Users Group

Without this step, users will authenticate but be denied the RDP session.

### Option A — Via GPO Restricted Groups (Recommended)

### Configuration Path

```
Computer Configuration
  └── Policies
        └── Windows Settings
              └── Security Settings
                    └── Restricted Groups
```

1. Right-click **Restricted Groups → Add Group**
2. Group name: `Remote Desktop Users`
3. In the group properties, under **Members of this group**, add:
   ```
   kingsecure\Domain Users
   ```
4. Click **OK**

This ensures every domain-joined machine in scope automatically grants all domain users RDP access.

### Option B — Manual (Per-Machine Fallback)

If the GPO has not yet applied or you need immediate access, run on the target machine:

```cmd
net localgroup "Remote Desktop Users" "kingsecure\Domain Users" /add
```

---

## Step 4 — Configure the Firewall

RDP requires **TCP port 3389** to be open on the endpoint.

### Option A — Via GPO (Recommended)

```
Computer Configuration
  └── Policies
        └── Windows Settings
              └── Security Settings
                    └── Windows Defender Firewall with Advanced Security
                          └── Inbound Rules
```

Enable the built-in rule: **Remote Desktop - User Mode (TCP-In)**

### Option B — Via Windows Firewall UI

1. Open **Windows Defender Firewall with Advanced Security**
2. Inbound Rules → Find **Remote Desktop - User Mode (TCP-In)**
3. Right-click → **Enable Rule**

### Option C — Quick Command

```powershell
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

---

## Applying the Policy

Force an immediate refresh on the target machine:

```cmd
gpupdate /force
```

Then confirm the policy applied:

```cmd
gpresult /r
```

---

## Troubleshooting

### Error 0x3 — Access Denied / Not in Remote Desktop Users

**Cause:** The user account is not a member of the **Remote Desktop Users** local group on the target machine.

**Fix:**
- Verify the Restricted Groups GPO is applied: `gpresult /r`
- Or manually add: `net localgroup "Remote Desktop Users" "kingsecure\Domain Users" /add`

---

### Error 0x9 — Firewall Blocking Port 3389

**Cause:** The Windows Defender Firewall is blocking inbound RDP connections on TCP 3389.

**Fix:**
- Enable the firewall rule via GPO (see Step 4)
- Or run: `Enable-NetFirewallRule -DisplayGroup "Remote Desktop"`
- Confirm port is open: `Test-NetConnection -ComputerName <target-ip> -Port 3389`

---

## Summary

| GPO Name | Link | Purpose |
|----------|------|---------|
| Enable RDP Policy | `kingsecure.bj` | Enables RDP listener + grants Domain Users access + opens firewall |

| Error Code | Meaning | Fix |
|------------|---------|-----|
| 0x3 | User not in Remote Desktop Users group | Add via Restricted Groups GPO or `net localgroup` |
| 0x9 | Firewall blocking TCP 3389 | Enable Remote Desktop firewall rule |

---

*RDP deployed on domain: `kingsecure.bj` | Scope: all domain-joined endpoints*
