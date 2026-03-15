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

echo "=== CURRENT LOGIN USERS (UID >= 1000) ==="
awk -F: '($3>=1000)&&($1!="nobody"){print $1 " (UID " $3 ")"}' /etc/passwd
echo ""

echo "=== USERS IN users.txt ==="
cat "$USERS_FILE"
echo ""

echo "This will DELETE all UID >= 1000 users and recreate only those in users.txt."
read -p "Are you sure? (yes/no): " ans
[ "$ans" != "yes" ] && exit 0

read -sp "Enter password for all new users: " NEW_PASS
echo ""

echo ""
echo "=== REMOVING EXISTING USERS ==="
for user in $(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd); do
  pkill -9 -u "$user" 2>/dev/null
  userdel -r "$user" 2>/dev/null
  echo "Removed $user"
  echo "$(date) - Removed user $user" >>"$LOG"
done

echo ""
echo "=== CREATING USERS ==="
while IFS= read -r username; do
  [ -z "$username" ] && continue

  useradd -m -s /bin/bash "$username"
  echo "$username:$NEW_PASS" | chpasswd
  echo "Created $username"
  echo "$(date) - Created user $username" >>"$LOG"

  SSH_DIR="/home/$username/.ssh"
  mkdir -p "$SSH_DIR"

  if [ -n "$SCORING_KEY" ]; then
    echo "$SCORING_KEY" >"$SSH_DIR/authorized_keys"
    chmod 600 "$SSH_DIR/authorized_keys"
  fi

  chmod 700 "$SSH_DIR"
  chown -R "$username:$username" "$SSH_DIR"
done <"$USERS_FILE"

echo ""
echo "=== RESULT ==="
awk -F: '($3>=1000)&&($1!="nobody"){print $1 " (UID " $3 ")"}' /etc/passwd
echo ""
echo "$(date) - User reset complete" >>"$LOG"
