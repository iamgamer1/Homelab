# Windows 11 VM Installation on VMware vSphere

## VM Specifications

| Setting | Value |
|---------|-------|
| VM Name | Win11-C3 |
| Guest OS | Windows 11 (64-bit) |
| vCPUs | 2 |
| RAM | 8 GB |
| Disk | 96 GB |
| Host | ESXi Host 1 (OptiPlex, 10.10.10.10) |
| OU | Management/Computers |

---

## Installation Overview

Windows 11 enforces hardware requirements at install time: TPM 2.0, Secure Boot, and a compatible CPU. In a virtual environment these requirements must be satisfied either via virtual hardware or bypassed via registry.

---

## vTPM Attempt — Why It Failed

VMware vSphere supports a Virtual Trusted Platform Module (vTPM), which presents a software-emulated TPM 2.0 chip to the guest VM — satisfying Windows 11's TPM requirement without physical hardware.

### Requirement for vTPM

vTPM in vSphere requires the host to have a **physical TPM 2.0 chip** on the motherboard. vCenter uses it to encrypt the VM's private keys via the Native Key Provider.

### Problem: Dell PowerEdge T620 Has No Physical TPM 2.0

The T620 is a generation 12 Dell PowerEdge server (released ~2012). It does not include a TPM 2.0 chip. As a result:

- The **vCenter Native Key Provider** cannot be configured on this host.
- The option to add a vTPM device to a VM is **greyed out** in the vSphere UI.
- Any attempt to enable vTPM fails with: *"No key provider configured."*

**Conclusion:** vTPM is not viable on this hardware. A registry bypass is required to install Windows 11.

---

## Registry Bypass Method

This method tricks the Windows 11 installer into skipping TPM and Secure Boot checks.

### Steps

1. Boot the VM from the Windows 11 ISO.
2. When the installer starts and displays *"This PC can't run Windows 11"*, press **Shift + F10** to open a Command Prompt.
3. Open the Registry Editor:
   ```
   regedit
   ```
4. Navigate to:
   ```
   HKEY_LOCAL_MACHINE\SYSTEM\Setup
   ```
5. Create a new key named **LabConfig** under `Setup`.
6. Inside `LabConfig`, create the following `DWORD (32-bit)` values:

   | Value Name | Type | Data |
   |------------|------|------|
   | BypassTPMCheck | DWORD | 1 |
   | BypassSecureBootCheck | DWORD | 1 |

7. Close regedit and the Command Prompt, then click **Refresh** or go back and retry the installation.

The installer will proceed without TPM or Secure Boot validation.

---

## Consequences of Bypassing TPM and Secure Boot

| Consequence | Detail |
|-------------|--------|
| No Windows Update guarantee | Microsoft may block feature updates on non-compliant installs in the future |
| No BitLocker TPM binding | BitLocker cannot use TPM-backed key storage; password-only mode required |
| No Secure Boot protection | Bootkit/rootkit attacks are not mitigated at firmware level |
| Unsupported configuration | Microsoft officially considers this unsupported for production use |
| Lab use only | Acceptable for a learning environment; not suitable for production endpoints |

---

## Post-Install Steps

- Join to domain: `kingsecure.bj`
- Install Wazuh agent (see [wazuh-agent-install.ps1](../scripts/wazuh-agent-install.ps1))
- Apply domain GPOs (WinRM, wallpaper, AUP banner, shared drives, account lockout)
- Move computer object to `Management/Computers` OU in Active Directory

---

*This bypass is documented for lab/educational use only. Do not use in production environments.*
