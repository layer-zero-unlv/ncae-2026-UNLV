#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "No backup directory: $BACKUP_DIR"
  exit 1
fi

for p in /etc /root /home /etc/ssh /etc/samba /etc/postgresql /etc/mysql /etc/bind /var/named /var/www /var/www/html /srv/www; do
  if [ -e "$p" ] && [ -e "$BACKUP_DIR$p" ]; then
    echo "=== $p ==="
    diff -qr "$p" "$BACKUP_DIR$p" 2>/dev/null
    echo ""
  fi
done
