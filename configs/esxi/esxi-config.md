# KingSecure Homelab - ESXi Configuration

## Host 1 — Dell OptiPlex 7040

| Property | Value |
|----------|-------|
| IP Address | 10.10.10.10 |
| Hostname | esxi-01.kingsecure.bj |
| ESXi Version | 8.0 Update 3 |
| CPU | Intel i5-6600 (Skylake, 4C/4T) |
| RAM | 48GB |
| Storage | 500GB SSD (datastore1) |
| License | vSphere 8 Standard |
| AD Domain | kingsecure.bj |
| vMotion IP | 10.10.10.60 |
| HA Role | Primary |

---

## Host 2 — Dell PowerEdge T620

| Property | Value |
|----------|-------|
| IP Address | 10.10.10.9 |
| Hostname | localhost.localdomain |
| ESXi Version | 8.0 Update 3 |
| CPU | Intel Xeon E5-2660 (Sandy Bridge, 8C/16T) |
| RAM | 64GB |
| Storage | 2.2TB RAID 5 (datastore1) |
| License | vSphere 8 Standard |
| iDRAC IP | 10.10.10.197 |
| vMotion IP | 10.10.10.61 |
| HA Role | Secondary |
| Service Tag | D9VMBY1 |

### T620 Storage Details
| Slot | Size | State | Role |
|------|------|-------|------|
| 0 | 136GB | Ready | Unassigned |
| 1 | 136GB | Ready | Unassigned |
| 2 | 558GB | Online | RAID 5 |
| 3 | 558GB | Online | RAID 5 |
| 4 | 558GB | Online | RAID 5 |
| 5 | 558GB | Online | RAID 5 |
| 6 | 558GB | Online | RAID 5 |
| 7 | 837GB | Ready | Unassigned |

RAID Controller: **PERC H710** (512MB cache, Security Capable)
Virtual Disk: **"James"** — RAID 5, 2233.5GB, Online

---

## vCenter Server

| Property | Value |
|----------|-------|
| IP Address | 10.10.10.30 |
| FQDN | vcenter.kingsecure.bj |
| Version | 8.0.3.00400 (Build 24322831) |
| SSO Domain | vsphere.local |
| SSO Admin | administrator@vsphere.local |
| Deployment Size | Tiny (2 vCPU, 14GB RAM) |
| Datastore | datastore1 on T620 |
| SSH | Enabled |

---

## KingSecure-Cluster

| Property | Value |
|----------|-------|
| Name | KingSecure-Cluster |
| Datacenter | King-DC |
| Hosts | 2 |
| vSphere HA | Enabled |
| vSphere DRS | Enabled |
| EVC Mode | Intel Sandy Bridge Generation |
| vSAN | Disabled |
| DRS Score | 91% |
| Total CPU | 30.85 GHz |
| Total Memory | 111.84 GB |
| Total Storage | 2,454 GB |

---

## VM Inventory

| VM | OS | Host | RAM | Storage | Status |
|----|----|------|-----|---------|--------|
| WinServer25-01 | Windows Server 2025 | 10.10.10.10 | 4GB | 74GB | Running |
| Win10-C1 | Windows 10 | 10.10.10.9 | 4GB | 39GB | Running |
| Win10-C2 | Windows 10 | 10.10.10.10 | 4GB | 39GB | Running |
| Ubuntu | Ubuntu 22.04 | 10.10.10.10 | 2.72GB | 34GB | Running |
| Wazuh-S1 | Ubuntu 22.04 | 10.10.10.10 | 7.97GB | 58GB | Running |
| VMwarevCenter-kingsecure | Photon OS | 10.10.10.9 | 17.91GB | 606GB | Running |

---

## Networking

### VMkernel Adapters
| Host | Adapter | IP | Services |
|------|---------|-----|---------|
| 10.10.10.10 | vmk0 | 10.10.10.10 | Management |
| 10.10.10.10 | vmk1 | 10.10.10.60 | vMotion |
| 10.10.10.9 | vmk0 | 10.10.10.9 | Management |
| 10.10.10.9 | vmk1 | 10.10.10.61 | vMotion |
