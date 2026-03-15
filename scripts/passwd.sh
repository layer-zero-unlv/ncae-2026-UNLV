#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

echo "=== SHELL USERS ==="
awk -F: '($7 !~ /nologin|false|sync|shutdown|halt/) {print $1}' /etc/passwd
echo ""

read -sp "Enter new password for all shell users: " NEW_PASS
echo ""
read -sp "Confirm: " CONFIRM
echo ""

if [ "$NEW_PASS" != "$CONFIRM" ]; then
  echo "Passwords do not match."
  exit 1
fi

CHANGED=0
while IFS=: read -r user x uid gid desc home shell; do
  echo "$shell" | grep -Eq "nologin|false|sync|shutdown|halt" && continue
  echo "$user:$NEW_PASS" | chpasswd
  echo "Changed $user"
  echo "$(date) - Changed password for $user" >>"$LOG"
  CHANGED=$((CHANGED + 1))
done </etc/passwd

echo ""
echo "Changed $CHANGED passwords."

read -p "Also reset root password to the same? (y/n): " ans
if [ "$ans" = "y" ]; then
  echo "root:$NEW_PASS" | chpasswd
  echo "$(date) - Changed root password" >>"$LOG"
  echo "Root password changed."
fi
