#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

if command -v dnf >/dev/null 2>&1; then
  PKG="dnf"
elif command -v apt >/dev/null 2>&1; then
  PKG="apt"
else
  echo "No supported package manager found."
  exit 1
fi

if systemctl list-unit-files 2>/dev/null | grep -q '^named.service'; then
  DNS_SERVICE="named"
  MAIN_CONF="/etc/named.conf"
  LOCAL_CONF="/etc/named.unlv.zones"
  ZONE_DIR="/var/named/unlv"
  DNS_GROUP="named"
elif systemctl list-unit-files 2>/dev/null | grep -q '^bind9.service'; then
  DNS_SERVICE="bind9"
  MAIN_CONF="/etc/bind/named.conf"
  LOCAL_CONF="/etc/bind/named.conf.local"
  ZONE_DIR="/etc/bind/zones"
  DNS_GROUP="bind"
else
  if [ "$PKG" = "dnf" ]; then
    dnf install -y bind bind-utils
    DNS_SERVICE="named"
    MAIN_CONF="/etc/named.conf"
    LOCAL_CONF="/etc/named.unlv.zones"
    ZONE_DIR="/var/named/unlv"
    DNS_GROUP="named"
  else
    apt update
    apt install -y bind9 bind9-utils dnsutils
    DNS_SERVICE="bind9"
    MAIN_CONF="/etc/bind/named.conf"
    LOCAL_CONF="/etc/bind/named.conf.local"
    ZONE_DIR="/etc/bind/zones"
    DNS_GROUP="bind"
  fi
fi

if [ -z "$TEAM_NUMBER" ]; then
  read -p "Enter team number: " TEAM_NUMBER
fi

if [ -z "$INT_DOMAIN" ]; then
  INT_DOMAIN="team${TEAM_NUMBER}.net"
fi

if [ -z "$EXT_DOMAIN" ]; then
  EXT_DOMAIN="team${TEAM_NUMBER}.ncaecybergames.org"
fi

if [ -z "$INT_NS_IP" ]; then
  INT_NS_IP="192.168.${TEAM_NUMBER}.12"
fi

if [ -z "$INT_WWW_IP" ]; then
  INT_WWW_IP="192.168.${TEAM_NUMBER}.5"
fi

if [ -z "$INT_DB_IP" ]; then
  INT_DB_IP="192.168.${TEAM_NUMBER}.7"
fi

if [ -z "$EXT_NS_IP" ]; then
  EXT_NS_IP="172.18.13.${TEAM_NUMBER}"
fi

if [ -z "$EXT_WWW_IP" ]; then
  EXT_WWW_IP="172.18.13.${TEAM_NUMBER}"
fi

if [ -z "$EXT_SHELL_IP" ]; then
  EXT_SHELL_IP="172.18.14.${TEAM_NUMBER}"
fi

if [ -z "$EXT_FILES_IP" ]; then
  EXT_FILES_IP="172.18.14.${TEAM_NUMBER}"
fi

if [ -z "$INT_REVERSE_ZONE" ]; then
  INT_REVERSE_ZONE="$(echo "$INT_NS_IP" | awk -F. '{print $3 "." $2 "." $1 ".in-addr.arpa"}')"
fi

if [ -z "$EXT_REVERSE_ZONE" ]; then
  EXT_REVERSE_ZONE="$(echo "$EXT_NS_IP" | awk -F. '{print $2 "." $1 ".in-addr.arpa"}')"
fi

if [ -z "$INT_NS_PTR" ]; then
  INT_NS_PTR="$(echo "$INT_NS_IP" | awk -F. '{print $4}')"
fi

if [ -z "$INT_WWW_PTR" ]; then
  INT_WWW_PTR="$(echo "$INT_WWW_IP" | awk -F. '{print $4}')"
fi

if [ -z "$INT_DB_PTR" ]; then
  INT_DB_PTR="$(echo "$INT_DB_IP" | awk -F. '{print $4}')"
fi

if [ -z "$EXT_NS_PTR" ]; then
  EXT_NS_PTR="$(echo "$EXT_NS_IP" | awk -F. '{print $4 "." $3}')"
fi

if [ -z "$EXT_WWW_PTR" ]; then
  EXT_WWW_PTR="$(echo "$EXT_WWW_IP" | awk -F. '{print $4 "." $3}')"
fi

if [ -z "$EXT_SHELL_PTR" ]; then
  EXT_SHELL_PTR="$(echo "$EXT_SHELL_IP" | awk -F. '{print $4 "." $3}')"
fi

if [ -z "$EXT_FILES_PTR" ]; then
  EXT_FILES_PTR="$(echo "$EXT_FILES_IP" | awk -F. '{print $4 "." $3}')"
fi

STAMP="$(date +%F_%H%M%S)"
SERIAL="$(date +%Y%m%d%H)"
SAVE_DIR="$BACKUP_DIR/dns_$STAMP"

mkdir -p "$SAVE_DIR"
[ -f "$MAIN_CONF" ] && cp -a "$MAIN_CONF" "$SAVE_DIR/"
[ -f "$LOCAL_CONF" ] && cp -a "$LOCAL_CONF" "$SAVE_DIR/"
[ -d "$ZONE_DIR" ] && cp -a "$ZONE_DIR" "$SAVE_DIR/" 2>/dev/null

mkdir -p "$ZONE_DIR"
chown root:"$DNS_GROUP" "$ZONE_DIR"
chmod 755 "$ZONE_DIR"

if [ "$DNS_SERVICE" = "named" ]; then
  if ! grep -qF "include \"$LOCAL_CONF\";" "$MAIN_CONF"; then
    echo "" >>"$MAIN_CONF"
    echo "include \"$LOCAL_CONF\";" >>"$MAIN_CONF"
  fi
fi

cat >"$LOCAL_CONF" <<EOF
zone "$INT_DOMAIN" IN {
    type master;
    file "$ZONE_DIR/forward.$INT_DOMAIN";
    allow-update { none; };
};

zone "$INT_REVERSE_ZONE" IN {
    type master;
    file "$ZONE_DIR/reverse.$INT_DOMAIN";
    allow-update { none; };
};

zone "$EXT_DOMAIN" IN {
    type master;
    file "$ZONE_DIR/forward.$EXT_DOMAIN";
    allow-update { none; };
};

zone "$EXT_REVERSE_ZONE" IN {
    type master;
    file "$ZONE_DIR/reverse.$EXT_DOMAIN";
    allow-update { none; };
};
EOF

cat >"$ZONE_DIR/forward.$INT_DOMAIN" <<EOF
\$TTL 86400
@   IN  SOA $INT_DOMAIN. root.$INT_DOMAIN. (
            $SERIAL
            604800
            86400
            2419200
            86400 )

@            IN  NS    $INT_NS_HOST.$INT_DOMAIN.
$INT_NS_HOST IN  A     $INT_NS_IP
dns          IN  A     $INT_NS_IP
@            IN  A     $INT_WWW_IP
$INT_WWW_HOST IN CNAME @
$INT_DB_HOST IN  A     $INT_DB_IP
EOF

cat >"$ZONE_DIR/reverse.$INT_DOMAIN" <<EOF
\$TTL 86400
@   IN  SOA $INT_DOMAIN. root.$INT_DOMAIN. (
            $SERIAL
            604800
            86400
            2419200
            86400 )

@           IN  NS   $INT_NS_HOST.$INT_DOMAIN.
$INT_NS_PTR IN  PTR  $INT_NS_HOST.$INT_DOMAIN.
$INT_WWW_PTR IN PTR  $INT_WWW_HOST.$INT_DOMAIN.
$INT_DB_PTR IN  PTR  $INT_DB_HOST.$INT_DOMAIN.
EOF

cat >"$ZONE_DIR/forward.$EXT_DOMAIN" <<EOF
\$TTL 86400
@   IN  SOA $EXT_DOMAIN. root.$EXT_DOMAIN. (
            $SERIAL
            604800
            86400
            2419200
            86400 )

@              IN  NS    $EXT_NS_HOST.$EXT_DOMAIN.
$EXT_NS_HOST   IN  A     $EXT_NS_IP
dns            IN  A     $EXT_NS_IP
@              IN  A     $EXT_WWW_IP
$EXT_WWW_HOST  IN  CNAME @
$EXT_SHELL_HOST IN A     $EXT_SHELL_IP
$EXT_FILES_HOST IN A     $EXT_FILES_IP
EOF

cat >"$ZONE_DIR/reverse.$EXT_DOMAIN" <<EOF
\$TTL 86400
@   IN  SOA $EXT_DOMAIN. root.$EXT_DOMAIN. (
            $SERIAL
            604800
            86400
            2419200
            86400 )

@             IN  NS   $EXT_NS_HOST.$EXT_DOMAIN.
$EXT_NS_PTR   IN  PTR  $EXT_NS_HOST.$EXT_DOMAIN.
$EXT_WWW_PTR  IN  PTR  $EXT_WWW_HOST.$EXT_DOMAIN.
$EXT_SHELL_PTR IN PTR  $EXT_SHELL_HOST.$EXT_DOMAIN.
$EXT_FILES_PTR IN PTR  $EXT_FILES_HOST.$EXT_DOMAIN.
EOF

chown root:"$DNS_GROUP" "$ZONE_DIR"/forward.* "$ZONE_DIR"/reverse.*
if [ "$DNS_SERVICE" = "named" ]; then
  chmod 640 "$ZONE_DIR"/forward.* "$ZONE_DIR"/reverse.*
  restorecon -Rv "$ZONE_DIR" 2>/dev/null || true
else
  chmod 644 "$ZONE_DIR"/forward.* "$ZONE_DIR"/reverse.*
fi

if grep -q "options" "$MAIN_CONF"; then
  grep -q 'version "none"' "$MAIN_CONF" || sed -i '/options[[:space:]]*{/a\        version "none";' "$MAIN_CONF"
  if grep -q 'allow-transfer' "$MAIN_CONF"; then
    sed -i 's/^[[:space:]]*allow-transfer.*/        allow-transfer { none; };/' "$MAIN_CONF"
  else
    sed -i '/options[[:space:]]*{/a\        allow-transfer { none; };' "$MAIN_CONF"
  fi
fi

named-checkconf || exit 1
named-checkzone "$INT_DOMAIN" "$ZONE_DIR/forward.$INT_DOMAIN" || exit 1
named-checkzone "$INT_REVERSE_ZONE" "$ZONE_DIR/reverse.$INT_DOMAIN" || exit 1
named-checkzone "$EXT_DOMAIN" "$ZONE_DIR/forward.$EXT_DOMAIN" || exit 1
named-checkzone "$EXT_REVERSE_ZONE" "$ZONE_DIR/reverse.$EXT_DOMAIN" || exit 1

systemctl enable --now "$DNS_SERVICE"
systemctl restart "$DNS_SERVICE"

if command -v ufw >/dev/null 2>&1; then
  ufw allow 53/tcp >/dev/null 2>&1
  ufw allow 53/udp >/dev/null 2>&1
elif command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-service=dns >/dev/null 2>&1
  firewall-cmd --reload >/dev/null 2>&1
fi

echo "$(date) - Configured DNS for team $TEAM_NUMBER" >>"$LOG"

echo ""
echo "Done"
echo "Internal domain: $INT_DOMAIN"
echo "External domain: $EXT_DOMAIN"
echo "Internal reverse: $INT_REVERSE_ZONE"
echo "External reverse: $EXT_REVERSE_ZONE"
