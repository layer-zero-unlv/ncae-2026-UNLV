#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
  echo "No backup directory: $BACKUP_DIR"
  exit 1
fi

for p in /etc /root /home /etc/ssh /etc/samba /etc/postgresql /etc/mysql /etc/bind /var/named /var/www /var/www/html /srv/www; do
  if [ -e "$BACKUP_DIR$p" ]; then
    read -p "Restore $p ? (y/n): " ans
    if [ "$ans" = "y" ]; then
      rsync -a "$BACKUP_DIR$p" "$(dirname "$p")/"
      echo "Restored $p"
      echo "$(date) - Restored $p" >>"$LOG"
    fi
  fi
done

sshd -t 2>/dev/null && systemctl restart sshd 2>/dev/null
sshd -t 2>/dev/null && systemctl restart ssh 2>/dev/null
named-checkconf >/dev/null 2>&1 && systemctl restart named 2>/dev/null
named-checkconf >/dev/null 2>&1 && systemctl restart bind9 2>/dev/null
systemctl restart smbd 2>/dev/null
systemctl restart smb 2>/dev/null
systemctl restart nmbd 2>/dev/null
systemctl restart nmb 2>/dev/null
systemctl restart postgresql 2>/dev/null
systemctl restart mysql 2>/dev/null
systemctl restart mariadb 2>/dev/null
systemctl restart nginx 2>/dev/null
systemctl restart apache2 2>/dev/null
systemctl restart httpd 2>/dev/null

echo "Done"
