#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

STAMP="$(date +%F_%H%M%S)"
RULES_BACKUP="$BACKUP_DIR/iptables_$STAMP.rules"

mkdir -p "$BACKUP_DIR"

if command -v iptables >/dev/null 2>&1; then
  iptables-save >"$RULES_BACKUP" 2>/dev/null
  echo "Saved existing rules to $RULES_BACKUP"
  echo "$(date) - Saved iptables rules to $RULES_BACKUP" >>"$LOG"
fi

if ! command -v iptables >/dev/null 2>&1; then
  if command -v apt >/dev/null 2>&1; then
    apt install -y iptables
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y iptables
  fi
fi

echo "Select service ports to allow (space-separated):"
echo "  1) SSH (22)"
echo "  2) DNS (53)"
echo "  3) HTTP (80)"
echo "  4) HTTPS (443)"
echo "  5) PostgreSQL (5432)"
echo "  6) MySQL (3306)"
echo "  7) SMB (139,445)"
echo "  8) Custom"
echo ""
read -p "Choices: " CHOICES

PORTS=""
for c in $CHOICES; do
  case "$c" in
    1) PORTS="$PORTS 22/tcp" ;;
    2) PORTS="$PORTS 53/tcp 53/udp" ;;
    3) PORTS="$PORTS 80/tcp" ;;
    4) PORTS="$PORTS 443/tcp" ;;
    5) PORTS="$PORTS 5432/tcp" ;;
    6) PORTS="$PORTS 3306/tcp" ;;
    7) PORTS="$PORTS 139/tcp 445/tcp 137/udp 138/udp" ;;
    8)
      read -p "Enter port/proto (e.g. 8080/tcp): " CUSTOM
      PORTS="$PORTS $CUSTOM"
      ;;
  esac
done

echo ""
echo "Ports to allow: $PORTS"
read -p "Apply firewall rules? (y/n): " ans
[ "$ans" != "y" ] && exit 0

iptables -F
iptables -X

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT

for entry in $PORTS; do
  port="$(echo "$entry" | cut -d/ -f1)"
  proto="$(echo "$entry" | cut -d/ -f2)"
  iptables -A INPUT -p "$proto" --dport "$port" -j ACCEPT
  echo "$(date) - Allowed INPUT $proto/$port" >>"$LOG"
done

iptables -A INPUT -j LOG --log-prefix "IPT_DROP_IN: "
iptables -A INPUT -j DROP

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type 0 -j ACCEPT

for entry in $PORTS; do
  port="$(echo "$entry" | cut -d/ -f1)"
  proto="$(echo "$entry" | cut -d/ -f2)"
  iptables -A OUTPUT -p "$proto" --sport "$port" -j ACCEPT
done

iptables -A OUTPUT -j LOG --log-prefix "IPT_DROP_OUT: "
iptables -A OUTPUT -j DROP

ip6tables -P INPUT DROP
ip6tables -P OUTPUT DROP
ip6tables -P FORWARD DROP

echo ""
echo "=== CURRENT RULES ==="
iptables -L -n --line-numbers
echo ""

read -p "Save rules persistently? (y/n): " ans
if [ "$ans" = "y" ]; then
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save
  elif [ -d /etc/iptables ]; then
    iptables-save >/etc/iptables/rules.v4
  else
    iptables-save >/etc/sysconfig/iptables 2>/dev/null || iptables-save >"$BACKUP_DIR/rules.active"
  fi
  echo "$(date) - Saved persistent iptables rules" >>"$LOG"
fi

echo "$(date) - Firewall configured" >>"$LOG"
echo "Done"
