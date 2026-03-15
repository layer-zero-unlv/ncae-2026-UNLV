#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

if command -v dnf >/dev/null 2>&1; then
  PKG="dnf"
elif command -v apt >/dev/null 2>&1; then
  PKG="apt"
else
  echo "No supported package manager found."
  exit 1
fi

SSH_SERVICE="sshd"
if systemctl list-unit-files 2>/dev/null | grep -q '^ssh.service'; then
  SSH_SERVICE="ssh"
fi

if [ "$PKG" = "dnf" ]; then
  dnf install -y openssh-server rsync curl
else
  apt update
  apt install -y openssh-server rsync curl
fi

systemctl enable --now "$SSH_SERVICE"

if ! id "$BACKUP_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$BACKUP_USER"
fi

if [ ! -f /usr/local/bin/rrsync ]; then
  curl -s -o /usr/local/bin/rrsync https://raw.githubusercontent.com/WayneD/rsync/master/support/rrsync
  chmod +x /usr/local/bin/rrsync
fi

for dir in $BACKUP_FOLDERS; do
  mkdir -p "/home/$BACKUP_USER/$dir"
done

chown -R "$BACKUP_USER:$BACKUP_USER" "/home/$BACKUP_USER"

read -p "Set or change password for $BACKUP_USER? (y/n): " ans
if [ "$ans" = "y" ]; then
  passwd "$BACKUP_USER"
  echo "$(date) - Set password for $BACKUP_USER from backup_setup" >>"$LOG"
fi

SSHD_CONF="/etc/ssh/sshd_config"
STAMP="$(date +%F_%H%M%S)"
cp "$SSHD_CONF" "$SSHD_CONF.bak.$STAMP"

set_line() {
  key="$1"
  value="$2"

  if grep -qE "^[#[:space:]]*$key " "$SSHD_CONF"; then
    sed -i "s|^[#[:space:]]*$key .*|$key $value|" "$SSHD_CONF"
  else
    echo "$key $value" >>"$SSHD_CONF"
  fi
}

set_line "PermitRootLogin" "no"
set_line "PasswordAuthentication" "yes"
set_line "PubkeyAuthentication" "yes"
set_line "ChallengeResponseAuthentication" "no"
set_line "X11Forwarding" "no"
set_line "AllowTcpForwarding" "no"
set_line "UsePAM" "yes"

if ! grep -q "Match User $BACKUP_USER" "$SSHD_CONF"; then
  cat >>"$SSHD_CONF" <<EOF

Match User $BACKUP_USER
    ForceCommand /usr/local/bin/rrsync /home/$BACKUP_USER
    PermitTTY no
    AllowTcpForwarding no
    X11Forwarding no
EOF
fi

if sshd -t 2>/dev/null; then
  systemctl restart "$SSH_SERVICE"
  echo "$(date) - Restarted $SSH_SERVICE from backup_setup" >>"$LOG"
else
  echo "SSH config test failed. Fix $SSHD_CONF before restarting."
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp >/dev/null 2>&1
elif command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1
  firewall-cmd --reload >/dev/null 2>&1
else
  echo "No ufw or firewalld found. Open SSH manually if needed."
fi

echo "$(date) - Finished backup_setup" >>"$LOG"

echo ""
echo "Backup setup complete."
echo "Backup user: $BACKUP_USER"
echo "Home: /home/$BACKUP_USER"
echo "Folders: $BACKUP_FOLDERS"
echo ""
echo "Checks:"
echo "  systemctl status $SSH_SERVICE"
echo "  ls -la /home/$BACKUP_USER"
echo "  ssh $BACKUP_USER@host"
echo ""
