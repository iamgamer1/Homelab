# Printer Deployment via GPO

## Overview

This document covers installing the Print and Document Services role on the domain controller, creating a shared virtual printer, and deploying it to all domain users via Group Policy.

---

## Step 1 — Install Print and Document Services Role

On **WinServer25-01** (10.10.10.20):

1. Open **Server Manager → Add Roles and Features**
2. Select **Role-based or feature-based installation**
3. Check **Print and Document Services**
4. Accept defaults and complete the installation
5. Reboot if prompted

---

## Step 2 — Create the Virtual Printer in Print Management

1. Open **Print Management** (from Server Manager → Tools, or `printmanagement.msc`)
2. Expand **Print Servers → WinServer25-01 → Printers**
3. Right-click **Printers → Add Printer**
4. Choose **Add a new printer using an existing port**

### Printer Configuration

| Setting | Value |
|---------|-------|
| Printer Name | Printer-01 |
| Driver | Generic / Text Only |
| Port | LPT1 |
| Location | Lobby |
| Share Name | Printer-01 |

5. In the printer properties, go to the **Sharing** tab:
   - Check **Share this printer**
   - Set share name: `Printer-01`
   - ⚠️ **Check "List in the directory"**

> **Critical:** If "List in the directory" is not checked, Active Directory cannot see the printer object and GPO-based deployment will silently fail — the printer will not appear on endpoints even if the GPO applies correctly.

---

## Step 3 — Deploy via Group Policy

### GPO Details

| Setting | Value |
|---------|-------|
| GPO Name | Printer All floor department |
| Linked To | `kingsecure.bj` (domain root) |
| Scope | All domain users |

### Configuration Path

```
User Configuration
  └── Policies
        └── Windows Settings
              └── Deployed Printers
```

1. Open **Group Policy Management** (`gpmc.msc`)
2. Right-click `kingsecure.bj` → **Create a GPO in this domain and Link it here**
3. Name it: `Printer All floor department`
4. Edit the GPO and navigate to the path above
5. Right-click → **Deploy Printer**
6. Enter the UNC path:
   ```
   \\WinServer25-01\Printer-01
   ```
7. Click **OK** and close the editor

### Apply the GPO

On a client machine, force a policy refresh:
```
gpupdate /force
```

Or wait for the next Group Policy refresh cycle (~90 minutes).

---

## Troubleshooting

### Error 740 — Elevation Required

**Symptom:** Printer fails to install on the endpoint with error code `0x740`.

**Cause:** Windows requires administrator elevation to install a printer driver. Standard domain users do not have this permission by default.

**Fix:** Use **Point and Print Restrictions** GPO to allow driver installation without elevation:

```
Computer Configuration → Policies → Administrative Templates
→ Printers → Point and Print Restrictions
  → Enabled
  → Users can only point and print to these servers: WinServer25-01
  → Do not show warning or elevation prompt (for security prompt settings)
```

Alternatively, pre-install the driver on endpoints via a separate GPO or script before deploying the printer.

---

## Expected Result

After GPO applies, the printer appears on endpoints as:

```
Printer-01 on WINSERVER25-01
```

Visible under **Settings → Bluetooth & devices → Printers & scanners**.

---

*Printer deployed on domain: `kingsecure.bj` | Server: WinServer25-01 (10.10.10.20)*
