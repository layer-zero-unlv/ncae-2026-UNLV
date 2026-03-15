#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

SUDO_GROUP="sudo"
if getent group wheel >/dev/null 2>&1; then
  SUDO_GROUP="wheel"
fi

echo "=== LOGGED IN USERS ==="
w
echo ""

echo "=== LOGIN-CAPABLE USERS ==="
awk -F: '($7 !~ /nologin|false|sync|shutdown|halt/) {print $1 ":" $3 ":" $6 ":" $7}' /etc/passwd
echo ""

echo "=== UID 0 USERS ==="
awk -F: '($3 == 0) {print $1}' /etc/passwd
echo ""

echo "=== SUDO GROUP ==="
getent group "$SUDO_GROUP"
echo ""

if [ ! -f "$USERS_FILE" ]; then
  echo "No users.txt found at $USERS_FILE"
  exit 0
fi

echo "=== USERS.TXT ==="
cat "$USERS_FILE"
echo ""

echo "=== USERS NOT IN users.txt ==="
BAD_USERS=""
while IFS=: read -r user x uid gid desc home shell; do
  if echo "$shell" | grep -Eq "nologin|false|sync|shutdown|halt"; then
    continue
  fi
  if [ "$user" = "root" ]; then
    continue
  fi
  if ! grep -qx "$user" "$USERS_FILE"; then
    echo "$user"
    BAD_USERS="$BAD_USERS $user"
  fi
done </etc/passwd
echo ""

read -p "Lock unauthorized login users? (y/n): " ans
if [ "$ans" = "y" ]; then
  for user in $BAD_USERS; do
    usermod -L "$user" 2>/dev/null
    if [ -x /usr/sbin/nologin ]; then
      usermod -s /usr/sbin/nologin "$user" 2>/dev/null
    elif [ -x /sbin/nologin ]; then
      usermod -s /sbin/nologin "$user" 2>/dev/null
    fi
    echo "Locked $user"
    echo "$(date) - Locked user $user" >>"$LOG"
  done
fi

echo ""
echo "=== USERS IN users.txt BUT NOT ON SYSTEM ==="
while IFS= read -r user; do
  [ -z "$user" ] && continue
  if ! id "$user" >/dev/null 2>&1; then
    echo "$user"
  fi
done <"$USERS_FILE"
