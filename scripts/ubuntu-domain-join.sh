#!/bin/bash
# ============================================================
# KingSecure Homelab - Ubuntu Domain Join Script
# Domain: kingsecure.bj
# DC/DNS: 10.10.20
# ============================================================

DOMAIN="kingsecure.bj"
REALM="KINGSECURE.BJ"
DC_IP="10.10.10.20"
DC_HOSTNAME="winserver25-01"

echo "=== KingSecure Ubuntu Domain Join Script ==="
echo "Domain: $DOMAIN"
echo "DC IP:  $DC_IP"

# Step 1: Install required packages
echo "[1/6] Installing required packages..."
apt-get update -q
apt-get install -y realmd sssd sssd-tools samba-common samba-common-bin \
    samba-libs krb5-user adcli packagekit

# Step 2: Configure DNS to point to DC
echo "[2/6] Configuring DNS..."
cat > /etc/systemd/resolved.conf << EOF
[Resolve]
DNS=$DC_IP
FallbackDNS=8.8.8.8
Domains=$DOMAIN
EOF
systemctl restart systemd-resolved

# Step 3: Configure Kerberos
echo "[3/6] Configuring Kerberos..."
# Comment out default MIT entries
sed -i '/^[^#]/ s/^/#/' /etc/krb5.conf

# Append domain config
cat >> /etc/krb5.conf << EOF

[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true

[realms]
    $REALM = {
        kdc = $DC_HOSTNAME.$DOMAIN
        admin_server = $DC_HOSTNAME.$DOMAIN
    }

[domain_realm]
    .$DOMAIN = $REALM
    $DOMAIN = $REALM
EOF

# Step 4: Join the domain
echo "[4/6] Joining domain $DOMAIN..."
echo "Enter domain admin password when prompted:"
realm join --user=administrator $DOMAIN

# Step 5: Configure SSSD
echo "[5/6] Configuring SSSD..."
cat > /etc/sssd/sssd.conf << EOF
[sssd]
domains = $DOMAIN
config_file_version = 2
services = nss, pam

[domain/$DOMAIN]
ad_domain = $DOMAIN
krb5_realm = $REALM
realmd_tags = manages-system joined-with-adcli
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = False
fallback_homedir = /home/%u
access_provider = ad
override_homedir = /home/%u
EOF

chmod 600 /etc/sssd/sssd.conf
systemctl restart sssd
systemctl enable sssd

# Step 6: Enable home directory creation
echo "[6/6] Enabling automatic home directory creation..."
pam-auth-update --enable mkhomedir

echo ""
echo "=== Domain join complete! ==="
echo "Test with: id administrator@$DOMAIN"
echo "Login with: su - username (domain user)"
