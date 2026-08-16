# 🏰 KingSecure Homelab

> Enterprise-grade homelab built to support hands-on learning toward a **Cloud Computing & Network Engineering** degree.

![ESXi](https://img.shields.io/badge/VMware_ESXi-8.0.3-blue?logo=vmware)
![vCenter](https://img.shields.io/badge/vCenter-8.0.3-blue?logo=vmware)
![Windows Server](https://img.shields.io/badge/Windows_Server-2025_Datacenter-0078D4?logo=windows)
![Wazuh](https://img.shields.io/badge/Wazuh-SIEM-red)
![Domain](https://img.shields.io/badge/Domain-kingsecure.bj-green)

---

## 📋 Overview

This homelab simulates a real enterprise IT environment covering:

- ✅ **Identity Management** — Active Directory, GPO, OU structure
- ✅ **Endpoint Management** — Domain-joined Windows & Linux endpoints
- ✅ **Security Monitoring** — Wazuh SIEM with agent-based telemetry
- ✅ **Virtualization** — VMware ESXi 8 on two hosts managed by vCenter
- ✅ **High Availability** — vSphere HA + DRS cluster with live vMotion
- ✅ **Remote Management** — iDRAC 7 on Dell PowerEdge T620
- 🔜 **Network Segmentation** — pfSense VM (planned)
- 🔜 **Mass Deployment** — MDT + SCCM (planned)

---

## 🖥️ Hardware

| Device | CPU | RAM | Storage | Role |
|--------|-----|-----|---------|------|
| Dell OptiPlex 7040 | Intel i5-6600 | 48GB | 500GB SSD | ESXi Host 1 (Primary VMs) |
| Dell PowerEdge T620 | Intel Xeon E5-2660 | 64GB | 2.2TB RAID 5 SAS | ESXi Host 2 (vCenter + Storage) |

### Additional Hardware
- **Intel I350-T2** dual-port NIC installed in OptiPlex for network segmentation
- **Dell PERC H710** RAID controller on T620 (8x SAS drives, RAID 5)
- **Dual 750W redundant PSUs** on T620 for hardware-level fault tolerance
- **iDRAC 7** on T620 for remote server management

---

## 🌐 Network Architecture

```
Internet (Spectrum ISP)
        │
   Home Router
        │
   Lab Router (10.10.10.1) ── Double NAT
        │
   10.10.10.0/24 Lab Subnet
        │
   ┌────┴────────────────────────────────┐
   │                                     │
10.10.10.10              10.10.10.9
ESXi Host 1              ESXi Host 2
(OptiPlex)               (T620)
```

### IP Address Table

| Device | IP Address | Role |
|--------|-----------|------|
| Lab Router | 10.10.10.1 | Default Gateway |
| ESXi Host 1 (OptiPlex) | 10.10.10.10 | Primary ESXi Host |
| ESXi Host 2 (T620) | 10.10.10.9 | Secondary ESXi Host |
| Windows Server 2025 DC | 10.10.10.20 | Domain Controller / DNS |
| vCenter Server | 10.10.10.30 | Centralized ESXi Management |
| Wazuh SIEM | 10.10.10.50 | Security Monitoring |
| vMotion (OptiPlex) | 10.10.10.60 | vMotion VMkernel |
| vMotion (T620) | 10.10.10.61 | vMotion VMkernel |
| iDRAC (T620) | 10.10.10.197 | Remote Server Management |

---

## 🏗️ Infrastructure

### Active Directory (Windows Server 2025 Datacenter)
- **Domain:** `kingsecure.bj`
- **DC IP:** `10.10.10.20`
- **OU Structure:**
  ```
  kingsecure.bj
  ├── IT Department
  │   ├── Users
  │   └── Computers
  ├── HR Department
  │   ├── Users
  │   └── Computers
  └── Management
      ├── Users
      └── Computers
  ```

### Domain-Joined Endpoints
| VM | OS | OU | Status |
|----|----|----|--------|
| Win10-C1 | Windows 10 | HR/Computers | ✅ Online |
| Win10-C2 | Windows 10 | Management/Computers | ✅ Online |
| Win11-C3 | Windows 11 | Management/Computers | ✅ Online |
| Ubuntu VM | Ubuntu 22.04 | IT/Computers | ✅ Online |

### Cloud-Managed Endpoints (Intune)
| VM | OS | Management | Status |
|----|----|-----------|--------|
| Win11-C4 | Windows 11 | Intune-enrolled (not domain-joined) | ✅ Online — Wazuh agent deployed via Intune Win32 app |

### Group Policy Objects
| GPO | Scope | Description |
|-----|-------|-------------|
| WinRM Enablement | Domain | Enables remote management on all endpoints |
| Control Panel Restriction | HR OU | Whitelist-based Control Panel lockdown |
| Desktop Wallpaper | Domain | Corporate wallpaper enforcement |
| AUP Login Banner | Domain | Acceptable Use Policy at login |
| Shared Drive Mapping | Domain | Maps department shared drives |
| Account Lockout Policy | Domain | Locks after 3 failed attempts, 15 min duration |

### VMware vSphere
- **vCenter:** `vcenter.kingsecure.bj` (10.10.10.30)
- **SSO Domain:** `vsphere.local`
- **Cluster:** `KingSecure-Cluster`
  - vSphere HA: **Enabled**
  - vSphere DRS: **Enabled** (Score: 91%)
  - EVC Mode: **Intel Sandy Bridge Generation**
- **Licensing:** vSphere 8 Standard (never expires)

### Wazuh SIEM
- **Version:** Latest stable
- **Deployment:** All-in-one on Ubuntu 22.04 LTS
- **Agents:** Win10-C1, Win10-C2, Win11-C3, WinServer25-01 (GPO/manual install), Win11-C4 (Intune Win32 app — cloud-native, non-domain-joined)
- **IT Hygiene:** Enabled (users/groups/services/browser-extensions inventory) — see [wazuh-it-hygiene-troubleshooting.md](docs/wazuh-it-hygiene-troubleshooting.md)
- **Note:** Ubuntu 24.04 incompatible due to Java/OpenSearch conflicts

---

## 📁 Repository Structure

```
KingSecure-Homelab/
├── README.md                    # This file
├── docs/
│   ├── setup-guide.md           # Step-by-step setup documentation
│   ├── troubleshooting.md       # Common issues and fixes
│   ├── vmotion-guide.md         # vMotion configuration guide
│   ├── ad-scenarios.md          # AD troubleshooting scenarios
│   ├── wazuh-intune-deployment.md # Wazuh agent deployment via Intune Win32 app
│   └── wazuh-it-hygiene-troubleshooting.md # IT Hygiene indexer-connector config & TLS troubleshooting
├── scripts/
│   ├── wazuh-agent-install.ps1  # Wazuh agent deployment script
│   ├── domain-join.ps1          # Domain join automation
│   ├── ad-user-management.ps1   # AD user management scripts
│   └── ubuntu-domain-join.sh    # Ubuntu AD join script
├── configs/
│   ├── ad/                      # Active Directory configurations
│   ├── esxi/                    # ESXi host configurations
│   ├── gpo/                     # GPO documentation
│   └── wazuh/                   # Wazuh configuration files
└── diagrams/                    # Network and architecture diagrams
```

---

## 🔑 Key Technical Learnings

| Topic | Learning |
|-------|---------|
| Ubuntu DNS | Must use `systemd-resolved` — never edit `/etc/resolv.conf` directly |
| Kerberos | Realm must be ALL CAPS (`KINGSECURE.BJ`) in `/etc/krb5.conf` |
| Wazuh | Ubuntu 22.04 LTS only — 24.04 has Java/OpenSearch conflicts |
| Windows Spotlight | Blocks lock screen GPOs even when registry shows policy applied |
| ESXi Licensing | Free tier has API restrictions — Standard required for vMotion/HA/DRS |
| vMotion | Requires EVC, VMkernel adapters, and shared/migrated storage |
| RAID 5 | 5x 558GB SAS = ~2.2TB usable with single-drive fault tolerance |
| iDRAC | Express license limits dedicated NIC and virtual disk creation |
| vCenter SSO | Uses `vsphere.local` — separate from AD domain |
| EVC | Required for vMotion between hosts with different CPU generations |
| Windows 11 TPM | T620 has no physical TPM 2.0, so vTPM is unavailable; registry bypass (`LabConfig` keys) required to install — lab use only |
| Printer Deployment | "List in the directory" must be checked in the printer's Sharing tab or GPO deployment silently fails; Error 740 = driver install needs elevation |
| RDP via GPO | Enabling RDP requires both the Allow Remote Connections policy and adding Domain Users to the Remote Desktop Users group (Restricted Groups); Error 0x3 = not in group, Error 0x9 = firewall blocking TCP 3389 |
| Intune Win32 Apps | Handled by the separate Intune Management Extension (IME) agent, which has its own check-in cycle — a device "Sync now" does not force IME to re-evaluate new app assignments |
| Intune vs Wazuh | "Installed" in Intune only confirms the software landed and the service started; the Wazuh dashboard must separately confirm the agent enrolled and is reporting as Active |
| Wazuh Indexer Connector | Installer default `<host>0.0.0.0:9200</host>` is a bind address, not a valid connect-out target — must be replaced (e.g. `127.0.0.1`) post-install |
| Wazuh TLS Certs | Three different cert-naming conventions exist in one install (`filebeat.*`, `wazuh-server.*`, `wazuh-indexer.*`) — the indexer-connector needs the indexer's own cert, not the manager's |
| TLS Hostname Matching | `localhost` and `127.0.0.1` are not interchangeable for TLS — must match exactly what's in the cert's Subject Alternative Name |
| Wazuh Indexer Credentials | Indexer username/password live in the manager's encrypted keystore (`wazuh-keystore`), never in the `<indexer>` XML block |

---

## 🔜 Roadmap

### Short Term
- [ ] Configure iSCSI shared storage between both ESXi hosts
- [ ] Set up HA heartbeat datastores
- [ ] Complete department-specific GPOs (HR, IT, Management shared folders)
- [ ] Deploy pfSense VM for network segmentation

### Medium Term
- [ ] MDT + SCCM 180-day trial for mass deployment practice
- [ ] Configure VLANs with pfSense for department isolation

### Long Term
- [ ] Expand Wazuh with custom detection rules
- [ ] Three-host vCenter cluster for full HA testing
- [ ] Ansible/Puppet for Linux endpoint management

---

## 📚 Purpose

This lab is built as a hands-on learning environment for a **Cloud Computing and Network Engineering** degree. Every component mirrors real enterprise infrastructure:

- AD/GPO → Enterprise identity and policy management
- vCenter/vSphere → Enterprise virtualization platform
- Wazuh SIEM → Enterprise security monitoring
- iDRAC → Datacenter remote management
- vMotion/HA/DRS → Enterprise high availability

---

## 🛠️ Technologies Used

![VMware](https://img.shields.io/badge/VMware-vSphere_8-607078?logo=vmware)
![Windows Server](https://img.shields.io/badge/Windows_Server-2025-0078D4?logo=microsoft)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04_LTS-E95420?logo=ubuntu)
![Wazuh](https://img.shields.io/badge/Wazuh-4.x-005571)
![Dell](https://img.shields.io/badge/Dell-PowerEdge_T620-007DB8?logo=dell)
![Active Directory](https://img.shields.io/badge/Active_Directory-kingsecure.bj-0078D4?logo=microsoft)

---

*Built and maintained as part of a Cloud Computing & Network Engineering degree program.*
