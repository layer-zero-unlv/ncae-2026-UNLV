#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

STAMP="$(date +%F_%H%M%S)"
FTP_CONF=""
FTP_SERVICE=""
FTP_USERLIST=""

if command -v apt >/dev/null 2>&1; then
  apt update
  apt install -y vsftpd
  FTP_CONF="/etc/vsftpd.conf"
  FTP_SERVICE="vsftpd"
  FTP_USERLIST="/etc/vsftpd.userlist"
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y vsftpd
  FTP_CONF="/etc/vsftpd/vsftpd.conf"
  FTP_SERVICE="vsftpd"
  FTP_USERLIST="/etc/vsftpd/user_list"
  mkdir -p /etc/vsftpd
else
  echo "No supported package manager found."
  exit 1
fi

if [ -f "$FTP_CONF" ]; then
  cp "$FTP_CONF" "$FTP_CONF.bak.$STAMP"
  echo "Backed up $FTP_CONF"
  echo "$(date) - Backed up $FTP_CONF" >>"$LOG"
fi

read -p "Enter FTP local_root directory [/mnt/files]: " FTP_ROOT
FTP_ROOT="${FTP_ROOT:-/mnt/files}"
mkdir -p "$FTP_ROOT"

read -p "Enter passive port range min [10000]: " PASV_MIN
PASV_MIN="${PASV_MIN:-10000}"
read -p "Enter passive port range max [10100]: " PASV_MAX
PASV_MAX="${PASV_MAX:-10100}"

cat >"$FTP_CONF" <<EOF
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
pam_service_name=vsftpd
ssl_enable=NO
local_root=$FTP_ROOT
pasv_enable=YES
pasv_min_port=$PASV_MIN
pasv_max_port=$PASV_MAX
userlist_enable=YES
userlist_deny=NO
userlist_file=$FTP_USERLIST
EOF

echo "$(date) - Wrote vsftpd config to $FTP_CONF" >>"$LOG"

if [ -f "$USERS_FILE" ]; then
  cp "$USERS_FILE" "$FTP_USERLIST"
  echo "Populated FTP userlist from $USERS_FILE"
else
  touch "$FTP_USERLIST"
  echo "Created empty FTP userlist at $FTP_USERLIST"
  echo "Add allowed usernames one per line."
fi

systemctl enable --now "$FTP_SERVICE"
systemctl restart "$FTP_SERVICE"
echo "$(date) - Started $FTP_SERVICE" >>"$LOG"

echo ""
echo "=== VSFTPD CONFIG ==="
cat "$FTP_CONF"
echo ""
echo "=== FTP USERLIST ==="
cat "$FTP_USERLIST"
echo ""
echo "Checks:"
echo "  systemctl status $FTP_SERVICE"
echo "  ss -tlnp | grep 21"
echo ""
