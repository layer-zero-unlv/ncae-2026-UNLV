#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

for p in /etc /root /home /etc/ssh /etc/samba /etc/postgresql /etc/mysql /etc/bind /var/named /var/www /var/www/html /srv/www; do
  if [ -e "$p" ]; then
    mkdir -p "$BACKUP_DIR$(dirname "$p")"
    rsync -a "$p" "$BACKUP_DIR$(dirname "$p")/"
    echo "Backed up $p"
  fi
done

echo "$(date) - Backup saved to $BACKUP_DIR" >>"$LOG"
echo "Done"
