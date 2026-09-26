# Windows Autopilot – Hardware Hash Upload (Cheat Sheet)

Run these at the **first OOBE screen** (country/region), *before* creating any account.

---

## 1. Open a command prompt

Press **Shift + F10**.

> Check the prompt shows `C:\Windows\system32`.
> If it shows `X:\`, you're still in Windows Setup (no PowerShell there). Finish the install first.

## 2. Start PowerShell

```
powershell
```

## 3. Upload the hash directly to Intune

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Install-Script -Name Get-WindowsAutopilotInfo -Force
& "C:\Program Files\WindowsPowerShell\Scripts\Get-WindowsAutopilotInfo.ps1" -Online
```

## 4. Finish

- Answer **Y** to any prompts (NuGet, untrusted repository, modules).
- Sign in with an **Intune Administrator** or **Global Administrator** account.
- On first use, accept **"Consent on behalf of your organization"**.
- Wait for `All devices imported` (2–10 minutes).

---

## Optional: group tag + wait for profile assignment

```powershell
& "C:\Program Files\WindowsPowerShell\Scripts\Get-WindowsAutopilotInfo.ps1" -Online -GroupTag "Lab" -Assign
```

Dynamic group rule for the tag:

```
(device.devicePhysicalIds -any (_ -eq "[OrderID]:Lab"))
```

## Offline option: save the hash to a CSV (USB)

```powershell
New-Item -Type Directory -Path C:\HWID
& "C:\Program Files\WindowsPowerShell\Scripts\Get-WindowsAutopilotInfo.ps1" -OutputFile C:\HWID\AutopilotHWID.csv
Get-Volume
Copy-Item C:\HWID\AutopilotHWID.csv E:\
```

Replace `E:` with the USB drive letter from `Get-Volume`.
Import in **Intune → Devices → Enrollment → Windows → Devices → Import**.

---

## After upload

1. Check the device in **Intune → Devices → Enrollment → Windows → Devices** (click **Sync** if needed).
2. Assign an **Autopilot deployment profile** (directly or through a group).
3. Stay at OOBE. Wait until **Profile status = Assigned**.
4. Reboot. The device enters Autopilot.

---

## Common mistakes

| Mistake | Correct |
|---|---|
| `Get-WindowsAutopilot` | `Get-WindowsAutopilotInfo` (ends in **Info**) |
| `C"\HWID` | `C:\HWID` (colon, not quote) |
| `>>` prompt appears | Unclosed quote. Press **Ctrl + C** and retype |
| "not recognized" error | New session. Rerun all 3 lines in step 3 |

## Notes

- **TPM:** User-driven Autopilot works without TPM. Self-deploying and pre-provisioning modes need **TPM 2.0**.
- **VMware VMs:** serial numbers with spaces can break import. Set a clean serial in the `.vmx`:
  ```
  serialNumber.reflectHost = "FALSE"
  serialNumber = "LAB-W11-001"
  ```
- **Hardware changes** (like adding a vTPM) change the hash. Capture it again.

## TPM bypass during Windows 11 setup (lab only)

At the "doesn't meet requirements" screen, press **Shift + F10**:

```
reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f
```

Values must be **1**, not 0. Then click **Back** and continue.
