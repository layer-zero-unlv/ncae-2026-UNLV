#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

SSH_SERVICE="sshd"
if systemctl list-unit-files 2>/dev/null | grep -q '^ssh.service'; then
  SSH_SERVICE="ssh"
fi

STAMP="$(date +%F_%H%M%S)"

set_line() {
  key="$1"
  value="$2"

  if grep -qE "^[#[:space:]]*$key " /etc/ssh/sshd_config; then
    sed -i "s|^[#[:space:]]*$key .*|$key $value|" /etc/ssh/sshd_config
  else
    echo "$key $value" >>/etc/ssh/sshd_config
  fi
}

allowed_user() {
  local u="$1"
  [ -f "$USERS_FILE" ] || return 1
  grep -qx "$u" "$USERS_FILE"
}

echo "=== AUTHORIZED KEYS ==="

for home in /home/*; do
  [ -d "$home" ] || continue
  user="$(basename "$home")"
  keydir="$home/.ssh"
  keyfile="$keydir/authorized_keys"

  mkdir -p "$keydir"
  chmod 700 "$keydir"
  chown "$user:$user" "$keydir"

  if [ -f "$keyfile" ]; then
    echo "--- $user ---"
    cat "$keyfile"
    echo ""
  fi

  if allowed_user "$user"; then
    if [ -n "$SCORING_KEY" ]; then
      touch "$keyfile"
      grep -qxF "$SCORING_KEY" "$keyfile" 2>/dev/null || echo "$SCORING_KEY" >>"$keyfile"
      chmod 600 "$keyfile"
      chown "$user:$user" "$keyfile"
    fi
  else
    if [ -f "$keyfile" ]; then
      mv "$keyfile" "$keyfile.disabled.$STAMP"
      echo "Moved $user authorized_keys"
      echo "$(date) - Moved $user authorized_keys" >>"$LOG"
    fi
  fi

  rm -f "$keydir/known_hosts" 2>/dev/null
done

mkdir -p /root/.ssh
chmod 700 /root/.ssh
if [ -f /root/.ssh/authorized_keys ]; then
  mv /root/.ssh/authorized_keys "/root/.ssh/authorized_keys.disabled.$STAMP"
  echo "Moved root authorized_keys"
  echo "$(date) - Moved root authorized_keys" >>"$LOG"
fi
rm -f /root/.ssh/known_hosts 2>/dev/null

cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$STAMP"

set_line "PermitRootLogin" "no"
set_line "PermitEmptyPasswords" "no"
set_line "PasswordAuthentication" "yes"
set_line "PubkeyAuthentication" "yes"
set_line "ChallengeResponseAuthentication" "no"
set_line "X11Forwarding" "no"
set_line "AllowTcpForwarding" "no"
set_line "MaxAuthTries" "3"
set_line "AuthorizedKeysFile" ".ssh/authorized_keys"
set_line "UsePAM" "yes"

if [ -f "$USERS_FILE" ]; then
  ALLOWED="$(tr '\n' ' ' <"$USERS_FILE" | xargs)"
  if [ -n "$ALLOWED" ]; then
    set_line "AllowUsers" "$ALLOWED"
  fi
fi

echo ""
echo "=== SSH SETTINGS ==="
grep -E "PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AllowUsers|AuthorizedKeysFile|MaxAuthTries|X11Forwarding|AllowTcpForwarding" /etc/ssh/sshd_config
echo ""

if sshd -t 2>/dev/null; then
  read -p "Restart $SSH_SERVICE now? (y/n): " ans
  if [ "$ans" = "y" ]; then
    systemctl restart "$SSH_SERVICE"
    echo "$(date) - Restarted $SSH_SERVICE" >>"$LOG"
  fi
else
  echo "sshd config test failed. Fix before restarting."
fi
