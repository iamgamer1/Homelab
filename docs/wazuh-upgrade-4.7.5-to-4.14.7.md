# Wazuh Upgrade: 4.7.5 → 4.14.7

**Host:** Wazuh-S1 (Ubuntu 22.04 LTS, single-node/all-in-one)
**Snapshot taken:** 8/15/2026 12:12:38 PM — "Before going to wazuh 4.14" (includes VM memory)
**Free datastore space at time of upgrade:** ~100 GB

Run all commands via SSH directly on the Wazuh-S1 VM (not remotely — see note on `localhost` below).

---

## 1. Stop services and back up configs

```bash
sudo systemctl stop wazuh-dashboard wazuh-manager wazuh-indexer filebeat
sudo cp /etc/wazuh-indexer/opensearch.yml /etc/wazuh-indexer/opensearch.yml.bak
sudo cp /etc/wazuh-dashboard/opensearch_dashboards.yml /etc/wazuh-dashboard/opensearch_dashboards.yml.bak
```

## 2. Upgrade the indexer (first)

```bash
sudo apt-get install wazuh-indexer=4.14.7-1
sudo systemctl daemon-reload
sudo systemctl start wazuh-indexer
sudo systemctl status wazuh-indexer
```

Verify cluster health (run locally on Wazuh-S1, hence `localhost`):

```bash
curl -k -u admin:<password> https://localhost:9200/_cluster/health?pretty
```

## 3. Upgrade the manager

```bash
sudo apt-get install wazuh-manager=4.14.7-1
sudo systemctl daemon-reload
sudo systemctl start wazuh-manager
sudo systemctl status wazuh-manager
```

## 4. Upgrade the dashboard

```bash
sudo apt-get install wazuh-dashboard=4.14.7-1
sudo systemctl daemon-reload
sudo systemctl start wazuh-dashboard
sudo systemctl status wazuh-dashboard
```

⚠️ If the dashboard throws SSL/connection errors here, check certificate paths in
`/etc/wazuh-dashboard/opensearch_dashboards.yml` against actual cert file locations —
common snag when upgrading from a pre-4.8 install.

## 5. Upgrade filebeat and refresh templates

```bash
sudo apt-get install filebeat=7.10.2
sudo curl -so /etc/filebeat/wazuh-template.json \
  https://raw.githubusercontent.com/wazuh/wazuh/v4.14.7/extensions/elasticsearch/7.x/wazuh-template.json
sudo systemctl daemon-reload
sudo systemctl start filebeat
filebeat setup --pipelines
filebeat setup --index-management
```

## 6. Verify

- Log into the dashboard UI, confirm version shows **4.14.7**
- Confirm agents (WinServer25-01, Win10-C1, Win10-C2, Win11-C3, Win11-C4) still show **Active**
  - Agent version may lag behind server version — that's fine, just don't let agents exceed server version
- Spot-check that events are still flowing (e.g. a fresh Event ID 4673 from WinServer25-01)

---

## Rollback

If anything breaks badly, revert to the "Before going to wazuh 4.14" snapshot in vCenter
(Wazuh-S1 → Snapshots → Revert). Memory state will be restored too, so no reboot needed after revert.
