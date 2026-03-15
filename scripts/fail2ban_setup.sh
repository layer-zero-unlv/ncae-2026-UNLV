#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

if command -v apt >/dev/null 2>&1; then
  apt update
  apt install -y fail2ban
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y epel-release
  dnf install -y fail2ban
else
  echo "No supported package manager found."
  exit 1
fi

STAMP="$(date +%F_%H%M%S)"
[ -f /etc/fail2ban/jail.local ] && cp /etc/fail2ban/jail.local "/etc/fail2ban/jail.local.bak.$STAMP"

SSH_SERVICE="sshd"
if systemctl list-unit-files 2>/dev/null | grep -q '^ssh.service'; then
  SSH_SERVICE="ssh"
fi

cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
banaction = iptables-multiport

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
backend = auto
EOF

if [ -f /var/log/secure ] && [ ! -f /var/log/auth.log ]; then
  sed -i 's|logpath = /var/log/auth.log|logpath = /var/log/secure|' /etc/fail2ban/jail.local
fi

read -p "Enable MySQL/MariaDB jail? (y/n): " ans
if [ "$ans" = "y" ]; then
  cat >>/etc/fail2ban/jail.local <<EOF

[mysqld-auth]
enabled = true
port = 3306
logpath = /var/log/mysql/error.log
maxretry = 3
EOF
fi

read -p "Enable PostgreSQL jail? (y/n): " ans
if [ "$ans" = "y" ]; then
  PG_LOG="$(find /var/log/postgresql /var/lib/pgsql -name "*.log" -type f 2>/dev/null | head -1)"
  PG_LOG="${PG_LOG:-/var/log/postgresql/postgresql-main.log}"
  cat >>/etc/fail2ban/jail.local <<EOF

[postgresql]
enabled = true
port = 5432
logpath = $PG_LOG
maxretry = 3
EOF
fi

systemctl enable --now fail2ban
systemctl restart fail2ban

echo ""
echo "=== FAIL2BAN STATUS ==="
fail2ban-client status
echo ""

echo "$(date) - Configured and started fail2ban" >>"$LOG"

echo ""
echo "Checks:"
echo "  fail2ban-client status sshd"
echo "  fail2ban-client get sshd banip"
echo "  tail -f /var/log/fail2ban.log"
echo ""
