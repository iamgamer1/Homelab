# Wazuh IT Hygiene — Configuration & Troubleshooting

**Environment:** Wazuh-S1 (Ubuntu 22.04 LTS, single-node/all-in-one), Wazuh 4.14.7
**Symptom:** IT Hygiene dashboard showed no data at all.
**Root cause:** three separate misconfigurations stacked on top of each other, found one layer at a time.

---

## What Is IT Hygiene?

IT Hygiene is basically an inventory of everything running on every machine you're monitoring — what software's installed, who has accounts, what services are running, what network ports are open, even what browser extensions people have added. Instead of having to log into each computer and check manually, Wazuh collects all of it automatically and puts it in one dashboard.

---

## Layer 1 — Syscollector wasn't collecting the new inventory fields

Cause: the agent's `ossec.conf` predated Wazuh's newer syscollector options (`<users>`, `<groups>`, `<services>`, `<browser_extensions>`). These fields didn't exist in older syscollector schemas, and upgrading the agent binary doesn't retroactively add new default config options to an existing config file.

Fix — push via centralized config rather than editing every agent individually:

```bash
sudo nano /var/ossec/etc/shared/default/agent.conf
```

```xml
<agent_config>
  <wodle name="syscollector">
    <disabled>no</disabled>
    <users>yes</users>
    <groups>yes</groups>
    <services>yes</services>
    <browser_extensions>yes</browser_extensions>
  </wodle>
</agent_config>
```

```bash
sudo systemctl restart wazuh-manager
```

Note: `agent.conf` for the `default` group ships essentially empty by default — that's normal. It's meant to hold only your overrides, not a full config template.

Verify the push actually reached the agent before assuming it worked:

```bash
sudo cat /var/ossec/etc/shared/default/merged.mg | grep -A 10 syscollector
```

If your new lines show up here, the manager built and is serving the merged config correctly.

Force an immediate rescan rather than waiting for the next hourly cycle:

```bash
sudo /var/ossec/bin/agent_control -R -a
```

`-R -a` restarts all agents; `-R -u <id>` targets one specific agent. Restarting forces `scan_on_start` to fire immediately.

Known caveat: older Wazuh versions had a bug where remote restart didn't reliably reach Windows agents (logged as "Active response command not present: restart-ossec.sh"). Confirmed a non-issue on 4.14.7, but if a Linux agent restarts and a Windows one doesn't, that's the historical reason — fall back to `Restart-Service -Name WazuhSvc` on the Windows box directly.

Even with this fixed and confirmed in `merged.mg`, IT Hygiene still showed nothing — meaning the problem was further downstream, in how the manager forwards data to the indexer.

---

## Layer 2 — The indexer connector destination was invalid

Checking the manager's `<indexer>` block in `ossec.conf`:

```xml
<host>https://0.0.0.0:9200</host>
```

Why this is wrong: `0.0.0.0` is a bind address — what a service uses to mean "listen on all interfaces." It is not a valid destination address for a client trying to connect out. The manager's indexer-connector was trying to dial a nonsensical target and failing, silently, while syscollector kept collecting data on the agent side with nowhere for it to go.

Important context: this is actually Wazuh's own documented installer default — official docs state that "by default, the indexer settings have one host configured. It's set to 0.0.0.0" and expect you to replace it manually post-install. This had likely been broken since initial install and simply never surfaced until a feature that depends on the indexer connector (IT Hygiene) was checked closely.

Fix:

```xml
<host>https://127.0.0.1:9200</host>
```

(see Layer 3 for why `127.0.0.1` specifically, not `localhost`)

---

## Layer 3 — Wrong certificate files, then wrong hostname vs IP

After fixing the host address, the indexer-connector logs still showed:

```
IndexerConnector initialization failed for index 'wazuh-states-inventory-users-...', retrying until the connection is successful.
```

### Sub-problem A — wrong cert filenames

The `<ssl>` block referenced `/etc/filebeat/certs/filebeat.pem` and `filebeat-key.pem`. Checking what actually existed on disk:

```bash
ls -la /etc/filebeat/certs/
```

revealed the real files were named `wazuh-server.pem` / `wazuh-server-key.pem` — a different naming convention than assumed.

Lesson: don't assume filenames from documentation or an old config match your actual install — always verify with `ls` before trusting a path in a config file.

### Sub-problem B — wrong certificate entirely

Even after correcting the filenames to `wazuh-server.pem`, the connection still failed. Reason: `wazuh-server.pem` is the manager's own certificate, not the indexer's. The indexer-connector needs to present/validate against the cert the indexer is actually serving on port 9200 — a completely different file, discoverable from the indexer's own config:

```bash
sudo grep -i "certificate\|pemcert\|pem" /etc/wazuh-indexer/opensearch.yml
```

which pointed to `/etc/wazuh-indexer/certs/wazuh-indexer.pem` and `wazuh-indexer-key.pem`.

### Sub-problem C — hostname vs IP in the certificate's SAN

After correcting the cert paths, testing directly with curl (isolating the test from the manager entirely):

```bash
curl --cacert /etc/filebeat/certs/root-ca.pem \
  --cert /etc/wazuh-indexer/certs/wazuh-indexer.pem \
  --key /etc/wazuh-indexer/certs/wazuh-indexer-key.pem \
  -u admin -XGET https://localhost:9200/_cluster/health
```

still failed with:

```
curl: (60) SSL: no alternative certificate subject name matches target host name 'localhost'
```

Checking the cert's actual Subject Alternative Name:

```bash
sudo openssl x509 -in /etc/wazuh-indexer/certs/wazuh-indexer.pem -noout -text | grep -A2 "Subject Alternative Name"
```

showed only `IP Address:127.0.0.1` — no `localhost` entry. TLS validation does exact string matching; `127.0.0.1` and `localhost` resolve to the same machine at the network level but are not interchangeable for certificate validation. The cert was only ever issued for the IP form.

### Final working `<indexer>` block

```xml
<indexer>
  <enabled>yes</enabled>
  <hosts>
    <host>https://127.0.0.1:9200</host>
  </hosts>
  <ssl>
    <certificate_authorities>
      <ca>/etc/filebeat/certs/root-ca.pem</ca>
    </certificate_authorities>
    <certificate>/etc/wazuh-indexer/certs/wazuh-indexer.pem</certificate>
    <key>/etc/wazuh-indexer/certs/wazuh-indexer-key.pem</key>
  </ssl>
</indexer>
```

Once the paths were confirmed correct via curl (returning a real `_cluster/health` JSON response with `"status":"green"`), the same host/cert values were applied to `ossec.conf` with confidence.

---

## Layer 4 — Missing keystore credentials

Per official Wazuh documentation, the `<indexer>` XML block never holds authentication credentials — those live separately in an encrypted keystore, independent of `ossec.conf` entirely. This is easy to miss because nothing in the XML schema hints that credentials belong somewhere else.

```bash
echo 'admin' | sudo /var/ossec/bin/wazuh-keystore -f indexer -k username
echo '<your_actual_admin_password>' | sudo /var/ossec/bin/wazuh-keystore -f indexer -k password
sudo systemctl restart wazuh-manager
```

Don't do: assume a `<username>`/`<password>` tag exists or should exist inside the `<indexer>` XML block — it doesn't. Don't waste time trying to add one there.

---

## Confirming the Fix

```bash
sudo tail -f /var/ossec/logs/ossec.log | grep -i indexer
```

Expected result — every inventory index initializing successfully:

```
indexer-connector: INFO: IndexerConnector initialized successfully for index: wazuh-states-inventory-ports-...
indexer-connector: INFO: IndexerConnector initialized successfully for index: wazuh-states-inventory-users-...
indexer-connector: INFO: IndexerConnector initialized successfully for index: wazuh-states-inventory-groups-...
indexer-connector: INFO: IndexerConnector initialized successfully for index: wazuh-states-inventory-interfaces-...
indexer-connector: INFO: IndexerConnector initialized successfully for index: wazuh-states-inventory-networks-...
indexer-connector: INFO: IndexerConnector initialized successfully for index: wazuh-states-inventory-browser-extensions-...
indexer-connector: INFO: IndexerConnector initialized successfully for index: wazuh-states-inventory-services-...
```

Give the next syscollector sync cycle a few minutes (or force one via `agent_control -R -a` again), then check the IT Hygiene dashboard — data should populate across users, groups, services, and browser extensions.

---

## Summary — Root Causes, in the Order They Were Found

1. Agent `ossec.conf` predated new syscollector fields → users/groups/services/browser-extensions were never being collected at all.
2. `<indexer><hosts><host>` was set to `0.0.0.0` → not a valid destination address; the manager couldn't reach the indexer.
3. Wrong certificate files referenced (`filebeat.pem`/`wazuh-server.pem` instead of the indexer's own `wazuh-indexer.pem`) → TLS handshake never got as far as hostname validation.
4. Certificate SAN only covered `127.0.0.1`, config used `localhost` → TLS validation failed on hostname mismatch even with the right cert.
5. Indexer credentials were never stored in the manager's keystore → separate from the XML config entirely, easy to overlook.

## General Lessons

- When a connector or integration silently fails, verify each hop independently (host reachability → cert file existence → cert validity for that host → credentials) rather than restarting the whole service repeatedly and hoping. Testing with `curl` in isolation from the manager was what actually cut through the ambiguity here.
- Never trust a filename in documentation or an old config — verify with `ls`. Three different cert-naming conventions existed in the same install (`filebeat.*`, `wazuh-server.*`, `wazuh-indexer.*`).
- `localhost` and `127.0.0.1` are not interchangeable for TLS. Match whatever the certificate's SAN actually contains.
- Some credentials live outside the config file entirely (Wazuh's keystore). If a documented feature requires "credentials" and there's no obvious config field for them, check whether the tool has a separate secret store before assuming misconfiguration.

---

## Quick-Start Walkthrough (Clean Setup, No Troubleshooting)

Use this section if you're configuring IT Hygiene on a fresh install or another environment and want to just get it working, without repeating the debugging above. Do these steps in order.

### Step 1 — Find your indexer's actual certificate paths

Don't assume filenames — pull them directly from the indexer's own config:

```bash
sudo grep -i "certificate\|pemcert\|pem" /etc/wazuh-indexer/opensearch.yml
```

Note the `pemcert_filepath`, `pemkey_filepath`, and `pemtrustedcas_filepath` values under `plugins.security.ssl.http.*` — you'll need these in Step 3.

### Step 2 — Check what hostname/IP the indexer's certificate is actually valid for

```bash
sudo openssl x509 -in <pemcert_filepath from Step 1> -noout -text | grep -A2 "Subject Alternative Name"
```

Use exactly what this shows (commonly `127.0.0.1`, sometimes a hostname) as your host value in Step 3 — don't default to `localhost` unless it's explicitly listed here.

### Step 3 — Configure the indexer connector on the manager

Edit `/var/ossec/etc/ossec.conf` and set (or add) the `<indexer>` block, using the values confirmed in Steps 1–2:

```xml
<indexer>
  <enabled>yes</enabled>
  <hosts>
    <host>https://<SAN_VALUE_FROM_STEP_2>:9200</host>
  </hosts>
  <ssl>
    <certificate_authorities>
      <ca><pemtrustedcas_filepath from Step 1></ca>
    </certificate_authorities>
    <certificate><pemcert_filepath from Step 1></certificate>
    <key><pemkey_filepath from Step 1></key>
  </ssl>
</indexer>
```

### Step 4 — Store indexer credentials in the manager's keystore

These do not go in `ossec.conf` — they live in an encrypted keystore:

```bash
echo 'admin' | sudo /var/ossec/bin/wazuh-keystore -f indexer -k username
echo '<your_indexer_admin_password>' | sudo /var/ossec/bin/wazuh-keystore -f indexer -k password
```

### Step 5 — Enable the full syscollector inventory on your agents

Push this via centralized config so it applies to every agent in the group at once, rather than editing each agent individually:

```bash
sudo nano /var/ossec/etc/shared/default/agent.conf
```

```xml
<agent_config>
  <wodle name="syscollector">
    <disabled>no</disabled>
    <users>yes</users>
    <groups>yes</groups>
    <services>yes</services>
    <browser_extensions>yes</browser_extensions>
  </wodle>
</agent_config>
```

Note: if you have agents split across multiple groups (check with `sudo /var/ossec/bin/agent_control -l` and `sudo /var/ossec/bin/agent_groups -l`), repeat this in each group's own `agent.conf` — a `default`-group edit only reaches agents actually in `default`.

### Step 6 — Restart and verify

```bash
sudo systemctl restart wazuh-manager
sudo tail -f /var/ossec/logs/ossec.log | grep -i indexer
```

You should see `IndexerConnector initialized successfully` for each inventory index (ports, users, groups, interfaces, networks, browser-extensions, services) with no warnings or retries.

### Step 7 — Force an immediate scan (optional, otherwise wait for the next hourly cycle)

```bash
sudo /var/ossec/bin/agent_control -R -a
```

Then check the IT Hygiene dashboard — data should populate within a few minutes. Disconnected agents (powered-off VMs) won't report until they're back online and reconnect, but the config is already waiting for them once they do.
