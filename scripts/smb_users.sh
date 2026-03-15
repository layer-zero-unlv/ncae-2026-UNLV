#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

if [ ! -f "$USERS_FILE" ]; then
  echo "users.txt not found at $USERS_FILE"
  exit 1
fi

if ! command -v smbpasswd >/dev/null 2>&1; then
  if command -v apt >/dev/null 2>&1; then
    apt install -y samba
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y samba
  fi
fi

echo "=== CURRENT SMB USERS ==="
pdbedit -L 2>/dev/null || echo "None"
echo ""

read -p "Remove all existing SMB users first? (y/n): " ans
if [ "$ans" = "y" ]; then
  for user in $(pdbedit -L 2>/dev/null | cut -d: -f1); do
    pdbedit -x "$user" 2>/dev/null
    echo "Removed $user"
    echo "$(date) - Removed SMB user $user" >>"$LOG"
  done
fi

read -sp "Enter SMB password for all users: " SMB_PASS
echo ""

ADDED=0
while IFS= read -r username; do
  [ -z "$username" ] && continue

  if ! id "$username" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$username"
    echo "Created system user $username"
    echo "$(date) - Created system user $username for SMB" >>"$LOG"
  fi

  echo -e "$SMB_PASS\n$SMB_PASS" | smbpasswd -a -s "$username"
  echo "Added SMB user $username"
  echo "$(date) - Added SMB user $username" >>"$LOG"
  ADDED=$((ADDED + 1))
done <"$USERS_FILE"

echo ""
echo "Added $ADDED SMB users."
echo ""
echo "=== CURRENT SMB USERS ==="
pdbedit -L 2>/dev/null
echo ""
