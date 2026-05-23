# KingSecure Homelab - vMotion Configuration Guide

## Prerequisites

Before vMotion will work in a mixed-CPU environment, you need:

1. ✅ Both ESXi hosts in a vCenter cluster
2. ✅ EVC (Enhanced vMotion Compatibility) enabled
3. ✅ VMkernel adapters with vMotion service on both hosts
4. ✅ VMs not connected to host-specific hardware (physical CD/DVD, etc.)

---

## Step 1 — Create vCenter Cluster

1. vSphere Client → King-DC → New Cluster
2. Name: `KingSecure-Cluster`
3. Enable vSphere DRS: **ON**
4. Enable vSphere HA: **ON**
5. Disable vSAN (not needed for 2-host homelab)

---

## Step 2 — Enable EVC

> **Why:** OptiPlex has Intel i5-6600 (Skylake), T620 has Xeon E5-2660 (Sandy Bridge).
> Different CPU generations expose different features to VMs.
> EVC masks both to Sandy Bridge baseline so VMs can move freely.

1. Power off all VMs (except vCenter)
2. KingSecure-Cluster → Configure → VMware EVC → Edit
3. Select: **Enable EVC for Intel Hosts**
4. CPU Mode: **Intel "Sandy Bridge" Generation**
5. Verify: **Validation succeeded** ✅
6. Click OK
7. Power VMs back on

---

## Step 3 — Configure VMkernel Adapters

### On OptiPlex (10.10.10.10):
1. Host → Configure → Networking → VMkernel Adapters → Add Networking
2. Connection type: **VMkernel Network Adapter**
3. Target device: Select existing standard switch (vSwitch0)
4. Port properties:
   - Label: `VMmotion`
   - Enable: **vMotion** ✅
5. IPv4 settings:
   - Static IP: `10.10.10.60`
   - Subnet: `255.255.255.0`

### On T620 (10.10.10.9):
Same steps with IP: `10.10.10.61`

---

## Step 4 — Perform vMotion Migration

### Compute + Storage vMotion (recommended for local datastores):

1. Right click VM → **Migrate**
2. Migration type: **Change both compute resource and storage**
3. Compute resource: Select destination host
4. Storage: Select destination datastore
5. Networks: Keep as VM Network
6. vMotion priority: **High**
7. Click **Finish**

### Watch progress:
- Recent Tasks panel at bottom of vSphere
- Look for: "Relocate virtual machine" task with progress %

---

## Troubleshooting vMotion

| Error | Cause | Fix |
|-------|-------|-----|
| CPU incompatibility | Different CPU generations | Enable EVC at Sandy Bridge |
| vMotion interface not configured | Missing VMkernel adapter | Add VMkernel with vMotion enabled |
| CD/DVD not accessible | Physical drive connected | Disconnect CD/DVD in VM settings |
| Cannot access datastore | Local storage | Use Storage vMotion (migrate compute + storage) |
| HA heartbeat warning | No shared datastore | Informational only — set up iSCSI later |

---

## IP Reference

| Host | Management IP | vMotion IP |
|------|--------------|-----------|
| OptiPlex (Host 1) | 10.10.10.10 | 10.10.10.60 |
| T620 (Host 2) | 10.10.10.9 | 10.10.10.61 |
