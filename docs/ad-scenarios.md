# KingSecure Homelab - AD Troubleshooting Scenarios

## Scenario 1 — Account Lockout

### Setup
Configure lockout policy via GPO:
- GPO Name: `Account Lockout Policy`
- Linked to: `kingsecure.bj` (domain root — NOT an OU)
- Path: Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Account Lockout Policy

| Setting | Value |
|---------|-------|
| Account lockout threshold | 3 invalid attempts |
| Account lockout duration | 15 minutes |
| Reset account lockout counter after | 15 minutes |

### Simulate
On a domain-joined client, enter wrong password 3 times.

### Verify Lockout
```powershell
# Check specific user
Get-ADUser -Identity johndoe -Properties LockedOut | Select Name, LockedOut

# Check all locked accounts
Search-ADAccount -LockedOut | Select Name, SamAccountName
```

### Find Source (Event Viewer)
On DC: Event Viewer → Windows Logs → Security → Filter for Event ID **4740**
This shows which machine caused the lockout.

### Resolution
```powershell
# Unlock only
Unlock-ADAccount -Identity johndoe

# Unlock + reset password
Set-ADAccountPassword -Identity johndoe -Reset -NewPassword (ConvertTo-SecureString "NewPass@123" -AsPlainText -Force)
Set-ADUser -Identity johndoe -ChangePasswordAtLogon $true
```

---

## Scenario 2 — Trust Relationship Failure

### What It Is
The secure channel between a domain-joined computer and the DC breaks.
Common causes:
- VM snapshot restored to old state
- Cloned VM with duplicate machine account
- Machine offline for extended period

### Error Message
```
"The trust relationship between this workstation and the primary domain failed"
```

### Simulate
On a domain-joined Windows VM (local admin account):
```powershell
# Break the secure channel
netdom resetpwd /server:WinServer25-01 /userd:kingsecure\administrator /passwordd:*
```

### Diagnose
```powershell
Test-ComputerSecureChannel -Verbose
```

### Fix — Method 1 (PowerShell)
```powershell
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
```

### Fix — Method 2 (From DC)
```powershell
# On DC, reset machine account
Get-ADComputer Win10-C1 | Set-ADComputer -Replace @{pwdLastSet=0}
```

### Fix — Method 3 (Disjoin/Rejoin)
1. System Properties → Computer Name → Change → Workgroup
2. Reboot
3. Rejoin `kingsecure.bj`

---

## Scenario 3 — Permission Denied on Shared Drive

### Setup
1. Create a shared folder on the DC
2. Create a security group (e.g., `HR-Users`)
3. Grant the group access to the share
4. Map drive via GPO

### Simulate
Remove a user from the `HR-Users` security group:
```powershell
Remove-ADGroupMember -Identity "HR-Users" -Members johndoe
```

### Test
Log in as johndoe and try accessing the mapped drive → Access Denied

### Resolution
```powershell
Add-ADGroupMember -Identity "HR-Users" -Members johndoe
gpupdate /force  # Run on client
```

---

## Scenario 4 — GPO Not Applying

### Simulate
Move a computer to the wrong OU:
```powershell
Get-ADComputer Win10-C1 | Move-ADObject -TargetPath "OU=Computers,OU=IT Department,DC=kingsecure,DC=bj"
```

### Diagnose
On the client:
```cmd
gpresult /r
gpresult /h C:\gpresult.html
```

### Fix
```powershell
# Move computer back to correct OU
Get-ADComputer Win10-C1 | Move-ADObject -TargetPath "OU=Computers,OU=HR Department,DC=kingsecure,DC=bj"
```
Then on client:
```cmd
gpupdate /force
```

---

## Scenario 5 — Disabled Account

### Simulate
```powershell
Disable-ADAccount -Identity johndoe
```

### Error Message
```
"Your account has been disabled. Please see your system administrator."
```

### Resolution
```powershell
Enable-ADAccount -Identity johndoe
```

---

## Helpdesk Identity Verification Process

Before resetting any account, verify user identity:

1. **Employee ID** — ask for badge/employee number, verify against HR records
2. **Security questions** — department, manager name, start date
3. **Manager confirmation** — email/call manager to confirm
4. **Out-of-band callback** — call user back on their office number on record
5. **Multi-factor** — use authenticator app or personal email on file

> ⚠️ Social engineering attacks often target helpdesk. Always verify before resetting.
