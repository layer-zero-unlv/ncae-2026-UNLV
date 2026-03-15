#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

echo "=== CURRENT INTERFACES ==="
ip -br addr
echo ""

echo "=== CURRENT CONNECTIONS ==="
nmcli con show 2>/dev/null || echo "NetworkManager not available"
echo ""

if ! command -v nmcli >/dev/null 2>&1; then
  echo "nmcli not found. Install NetworkManager."
  exit 1
fi

systemctl enable --now NetworkManager 2>/dev/null

CONNECTIONS="$(nmcli -t -f NAME con show)"
echo "Available connections:"
echo "$CONNECTIONS"
echo ""

read -p "Enter connection name: " CONN_NAME
if ! nmcli con show "$CONN_NAME" >/dev/null 2>&1; then
  echo "Connection $CONN_NAME not found."
  exit 1
fi

read -p "Enter IP address with CIDR (e.g. 192.168.1.10/24): " IP_ADDR
read -p "Enter gateway: " GATEWAY
read -p "Enter DNS servers (comma-separated) [1.1.1.1,8.8.8.8]: " DNS_SERVERS
DNS_SERVERS="${DNS_SERVERS:-1.1.1.1,8.8.8.8}"

echo ""
echo "Connection: $CONN_NAME"
echo "IP:         $IP_ADDR"
echo "Gateway:    $GATEWAY"
echo "DNS:        $DNS_SERVERS"
echo ""
read -p "Apply these settings? (y/n): " ans
[ "$ans" != "y" ] && exit 0

nmcli con mod "$CONN_NAME" ipv4.addresses "$IP_ADDR"
nmcli con mod "$CONN_NAME" ipv4.gateway "$GATEWAY"
nmcli con mod "$CONN_NAME" ipv4.dns "$DNS_SERVERS"
nmcli con mod "$CONN_NAME" ipv4.method manual
nmcli con mod "$CONN_NAME" ipv6.method ignore

nmcli con down "$CONN_NAME" 2>/dev/null
nmcli con up "$CONN_NAME"

echo "$(date) - Configured $CONN_NAME: $IP_ADDR gw $GATEWAY dns $DNS_SERVERS" >>"$LOG"

echo ""
echo "=== UPDATED INTERFACE ==="
ip -br addr
echo ""
