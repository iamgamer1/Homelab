# Deploying the Wazuh Agent to a Cloud-Native Device via Intune (Win32 App)

**Environment:** kingsecure.bj homelab
**Target device:** Win11-C4 (Intune-enrolled, not domain-joined)
**Wazuh manager:** 10.10.10.50
**Deployment method:** Intune Win32 app (PowerShell wrapped install/uninstall)
**Result:** Verified agent install (Intune) + verified agent enrollment (Wazuh dashboard, Active status)

---

## Why This Deployment Method

`Win10-C1`, `Win10-C2`, and `Win11-C3` are domain-joined and could have used a GPO-based deployment (startup script from `WinServer25-01`, running in SYSTEM context before login). Win11-C4 is a **pure Intune-managed device** — it never touches the `kingsecure.bj` domain, so GPO is not an option. Intune's Win32 app feature is the cloud-native equivalent: it pushes software silently to the device with no console access required, mirroring how a real hybrid enterprise handles devices that are cloud-only (remote workers, BYOD-adjacent corporate devices, etc.).

This exercise deliberately kept the two deployment paths separate (GPO for on-prem, Intune for cloud-only) to demonstrate both patterns working side by side in the same environment.

---

## Step 1 — Validate the Install Command Manually First

Before packaging anything, the install command was tested directly on Win11-C4 via an elevated PowerShell session to confirm it worked before wrapping it in automation. Debugging a packaging pipeline and a broken install command at the same time makes it hard to isolate the source of a failure.

```powershell
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.7.5-1.msi" -OutFile "$env:tmp\wazuh-agent.msi"
msiexec.exe /i "$env:tmp\wazuh-agent.msi" /q WAZUH_MANAGER="10.10.10.50" WAZUH_REGISTRATION_SERVER="10.10.10.50"
NET START WazuhSvc
```

Two corrections were made to the original dashboard-generated command:
- `${env.tmp}` → `$env:tmp` (correct PowerShell environment variable syntax; the dot-notation form is invalid)
- Added the `.msi` extension to the downloaded file, since `msiexec` expects a file extension it can associate with the installer

Verification after running it:
- `Get-Service -Name WazuhSvc` → confirmed `Running`
- `ossec.log` (`C:\Program Files (x86)\ossec-agent\ossec.log`) → confirmed successful connection/enrollment message
- Wazuh dashboard → Agents → confirmed the agent appeared as Active

Only after this worked standalone did the same logic get wrapped into a package.

---

## Step 2 — Build the Package Folder Locally

Packaging for Intune has no dependency on the domain, `WinServer25-01`, or the on-prem network — it's purely a local content-prep step. This was done on a personal laptop, not a domain-joined machine, which is consistent with the cloud-native model Intune is built around: **build anywhere, upload to the cloud portal, let Intune push it to the target device over the internet.**

A folder was created:
```
C:\WazuhPackage\
```

### install.ps1
```powershell
$msiPath = "$env:tmp\wazuh-agent.msi"
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.7.5-1.msi" -OutFile $msiPath
Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /q WAZUH_MANAGER=`"10.10.10.50`" WAZUH_REGISTRATION_SERVER=`"10.10.10.50`"" -Wait -NoNewWindow
Start-Service -Name WazuhSvc
```

The Wazuh manager IP (`10.10.10.50`) is hardcoded into the `msiexec` argument string here — this is the single point of edit if the manager's IP ever changes, and would require repackaging.

### uninstall.ps1
```powershell
$product = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Wazuh*" }
if ($product) {
    $product.Uninstall()
}
Stop-Service -Name WazuhSvc -ErrorAction SilentlyContinue
```

Intune requires an uninstall command for every Win32 app, even if it's never triggered — this ensures the app can be cleanly retired later without manual cleanup on the endpoint.

---

## Step 3 — Package into .intunewin Format

Using Microsoft's official content prep tool (`IntuneWinAppUtil.exe`, from the [Microsoft-Win32-Content-Prep-Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool) repo):

```
IntuneWinAppUtil.exe -c C:\WazuhPackage -s install.ps1 -o C:\WazuhPackage\Output
```

- `-c` — source folder containing both scripts
- `-s` — the entry/setup file Intune will execute
- `-o` — output location for the packaged file

This produced `install.intunewin` — a single compressed file containing both scripts, ready for upload.

---

## Step 4 — Upload and Configure the Win32 App in Intune

**Intune admin center → Apps → Windows → Add → Windows app (Win32)** → uploaded `install.intunewin`.

### App information
| Field | Value |
|---|---|
| Name | Wazuh Agent 4.7.5 |
| Publisher | Wazuh |

### Program
| Field | Value | Why |
|---|---|---|
| Install command | `powershell.exe -ExecutionPolicy Bypass -File install.ps1` | Runs the install script; bypass avoids execution policy blocking an unsigned script |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -File uninstall.ps1` | Required field, enables clean future removal |
| Install behavior | **System** | Installs in SYSTEM context — no user needs to be logged in, and no admin credentials need to be entered on the device |

### Requirements
- OS architecture: x64
- Minimum OS: matched to the lab's Windows 10/11 baseline

### Detection rules

A manual detection rule was used instead of relying on the MSI's built-in product code, since a custom file-path check proved more reliable for this package:

| Field | Value |
|---|---|
| Rule type | File |
| Path | `C:\Program Files (x86)\ossec-agent` |
| File | `wazuh-agent.exe` |
| Detection method | File or folder exists |

This is how Intune determines whether the install actually succeeded on the device — without it, Intune has no way to distinguish a completed install from a failed one.

---

## Step 5 — Scope the Assignment to Win11-C4 Only

Since this was the first test of the cloud deployment path, it was scoped to a single device rather than a broad group — matching how real enterprises pilot new software pushes before wide rollout.

1. **Entra admin center → Groups → New group**
   - Type: Security
   - Membership type: **Assigned** (static — not dynamic, since the goal was exactly one device)
   - Name: `Wazuh Agent win 11`
   - Member added: Win11-C4
2. **Intune → Wazuh Agent 4.7.5 → Properties → Assignments**
   - Added `Wazuh Agent win 11` under **Required**

### Assignment sections explained
| Section | Behavior |
|---|---|
| **Required** | Installs automatically, no user interaction — correct choice for a background security agent |
| **Available for enrolled devices** | Appears in Company Portal as optional, user-triggered install — meant for user-facing apps, not agents |
| **Uninstall** | Actively removes the app from devices/groups placed here |
| **Group mode: Included/Excluded** | Included = target this group; Excluded = carve this group out of a broader assignment |
| **Filter mode** | Narrows a group assignment further by device property (OS version, manufacturer, etc.) without needing a separate group — not needed for a single static-group test |

---

## Step 6 — Trigger, Troubleshoot, and Verify

### Initial state: "Total: 0" on Device install status

Right after creation, the app's device status donut showed 0 across every category (Installed, Failed, Pending, Not Applicable) — not just "pending," but no attribution at all. This was diagnosed as a **propagation/timing issue**, not a configuration error, since:
- Group membership was confirmed correct (Win11-C4 present in `Wazuh Agent win 11`)
- Assignment was confirmed correct (Required, Active status, correct group)
- Content upload had completed

### Root cause of the delay: Intune Management Extension (IME) check-in cycle

Win32 apps are handled by a separate agent on the device — the **Intune Management Extension** — which has its own check-in cycle apart from the general MDM/compliance sync. A manual device sync (`Settings → Accounts → Access work or school → Info → Sync`) does not automatically force IME to re-evaluate new app assignments; IME polls on a longer interval independently.

### Verification steps used

1. Confirmed the `IntuneManagementExtension` service was installed and running on Win11-C4:
   ```powershell
   Get-Service -Name IntuneManagementExtension
   ```
2. Checked the IME log directly for any mention of the app:
   ```powershell
   Get-Content "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" -Tail 200 | Select-String "Wazuh"
   ```
3. Once IME picked up the assignment on its next cycle, the install ran automatically in SYSTEM context — no login, no manual interaction on the VM.

### Final confirmation (two separate checks, matching the install-vs-enrollment distinction from earlier troubleshooting)

- **Intune → Apps → Wazuh Agent 4.7.5 → Device install status** → Win11-C4 showed **Installed**
- **Wazuh dashboard → Agents** → Win11-C4 appeared as a registered agent with **Active** status

Both checks were necessary — a successful Intune install only confirms the software landed on disk and the service started; it does not by itself confirm the agent actually enrolled and is sending data to the manager. Both had to be true for the deployment to be considered complete.

---

## Key Takeaways

- **Packaging is fully decoupled from the domain.** The `.intunewin` package was built on a personal laptop with no AD/network dependency — packaging is a local content-prep step; distribution is entirely cloud-mediated.
- **SYSTEM install behavior removes the need for on-device credentials.** No admin password was ever entered on Win11-C4 for this deployment, unlike the manual PsExec/console-based approaches some organizations fall back to without AD.
- **Win32 app installs are not driven by the same sync as compliance/device policy.** IME has an independent check-in cadence; a "Sync now" on the device doesn't guarantee an immediate app push.
- **"Installed" in Intune ≠ "enrolled" in Wazuh.** These are two separate systems and two separate success conditions — Intune confirms the software is present and running; the Wazuh dashboard confirms it's actually authenticated and reporting to the manager.
- **Static groups are the right scoping tool for a pilot.** Using a dedicated single-device security group avoided any risk of accidentally pushing an untested package to `Win10-C1`, `Win10-C2`, or `Win11-C3`.

---

## Result

All four client VMs (`Win10-C1`, `Win10-C2`, `Win11-C3`, `Win11-C4`) are now reporting into the Wazuh SIEM — three via local/manual install on domain-joined machines, and Win11-C4 via a fully cloud-native Intune Win32 app push, demonstrating both deployment patterns within the same hybrid lab environment.
