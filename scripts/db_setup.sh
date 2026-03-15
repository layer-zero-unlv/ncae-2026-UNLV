#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  echo "This script is meant for Ubuntu or Debian."
  exit 1
fi

SSH_SERVICE="sshd"
if systemctl list-unit-files 2>/dev/null | grep -q '^ssh.service'; then
  SSH_SERVICE="ssh"
fi

POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_LISTEN_ADDRESSES="${POSTGRES_LISTEN_ADDRESSES:-*}"
POSTGRES_ALLOWED_SUBNET="${POSTGRES_ALLOWED_SUBNET:-$TEAM_SUBNET}"

STAMP="$(date +%F_%H%M%S)"
SAVE_DIR="$BACKUP_DIR/db_$STAMP"

mkdir -p "$SAVE_DIR"

[ -d /etc/ssh ] && cp -a /etc/ssh "$SAVE_DIR/" 2>/dev/null
[ -d /etc/postgresql ] && cp -a /etc/postgresql "$SAVE_DIR/" 2>/dev/null
[ -d /var/lib/postgresql ] && cp -a /var/lib/postgresql "$SAVE_DIR/" 2>/dev/null

if id postgres >/dev/null 2>&1; then
  sudo -u postgres pg_dumpall >"$SAVE_DIR/pg_dumpall.sql" 2>/dev/null
fi

echo "$(date) - Saved DB backup to $SAVE_DIR" >>"$LOG"

read -p "Change root and users in users.txt passwords? (y/n): " ans
if [ "$ans" = "y" ]; then
  read -sp "Enter new password: " NEW_PASS
  echo ""

  echo "root:$NEW_PASS" | chpasswd
  echo "$(date) - Changed root password from db_setup" >>"$LOG"

  if [ -f "$USERS_FILE" ]; then
    while IFS= read -r user; do
      [ -z "$user" ] && continue
      if id "$user" >/dev/null 2>&1; then
        echo "$user:$NEW_PASS" | chpasswd
        echo "$(date) - Changed password for $user from db_setup" >>"$LOG"
      fi
    done <"$USERS_FILE"
  fi
fi

set_ssh_line() {
  key="$1"
  value="$2"

  if grep -qE "^[#[:space:]]*$key " /etc/ssh/sshd_config; then
    sed -i "s|^[#[:space:]]*$key .*|$key $value|" /etc/ssh/sshd_config
  else
    echo "$key $value" >>/etc/ssh/sshd_config
  fi
}

cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$STAMP"

set_ssh_line "PermitRootLogin" "no"
set_ssh_line "PasswordAuthentication" "yes"
set_ssh_line "PubkeyAuthentication" "yes"
set_ssh_line "ChallengeResponseAuthentication" "no"
set_ssh_line "UsePAM" "yes"
set_ssh_line "MaxAuthTries" "3"
set_ssh_line "X11Forwarding" "no"
set_ssh_line "AllowTcpForwarding" "no"

if [ -f "$USERS_FILE" ]; then
  ALLOWED_USERS="$(tr '\n' ' ' <"$USERS_FILE" | xargs)"
  if [ -n "$ALLOWED_USERS" ]; then
    if grep -qE "^[#[:space:]]*AllowUsers " /etc/ssh/sshd_config; then
      sed -i "s|^[#[:space:]]*AllowUsers .*|AllowUsers $ALLOWED_USERS|" /etc/ssh/sshd_config
    else
      echo "AllowUsers $ALLOWED_USERS" >>/etc/ssh/sshd_config
    fi
  fi
fi

if sshd -t 2>/dev/null; then
  systemctl restart "$SSH_SERVICE"
  echo "$(date) - Restarted $SSH_SERVICE from db_setup" >>"$LOG"
else
  echo "SSH config test failed. Fix /etc/ssh/sshd_config before continuing."
fi

apt update
apt install -y postgresql postgresql-contrib fail2ban tmux rkhunter lsof
systemctl enable --now postgresql
systemctl enable --now fail2ban 2>/dev/null

if ! id postgres >/dev/null 2>&1; then
  echo "Postgres user not found."
  exit 1
fi

read -sp "Enter new PostgreSQL password for postgres user: " PG_PASS
echo ""

ESCAPED_PASS="${PG_PASS//\'/''}"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$ESCAPED_PASS';"

PG_CONF="$(sudo -u postgres psql -tAc "SHOW config_file;")"
PG_HBA="$(sudo -u postgres psql -tAc "SHOW hba_file;")"

set_pg_line() {
  key="$1"
  value="$2"

  if grep -qE "^[#[:space:]]*$key[[:space:]]*=" "$PG_CONF"; then
    sed -i "s|^[#[:space:]]*$key[[:space:]]*=.*|$key = $value|" "$PG_CONF"
  else
    echo "$key = $value" >>"$PG_CONF"
  fi
}

set_pg_line "listen_addresses" "'$POSTGRES_LISTEN_ADDRESSES'"
set_pg_line "port" "$POSTGRES_PORT"
set_pg_line "max_connections" "20"
set_pg_line "superuser_reserved_connections" "2"
set_pg_line "password_encryption" "'scram-sha-256'"
set_pg_line "logging_collector" "on"
set_pg_line "log_destination" "'stderr'"

if [ -n "$POSTGRES_ALLOWED_SUBNET" ]; then
  if ! grep -q "$POSTGRES_ALLOWED_SUBNET" "$PG_HBA"; then
    echo "host    all    all    $POSTGRES_ALLOWED_SUBNET    scram-sha-256" >>"$PG_HBA"
  fi
fi

systemctl restart postgresql

if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp >/dev/null 2>&1
  ufw allow "$POSTGRES_PORT"/tcp >/dev/null 2>&1
elif command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1
  firewall-cmd --permanent --add-port="$POSTGRES_PORT"/tcp >/dev/null 2>&1
  firewall-cmd --reload >/dev/null 2>&1
else
  echo "No ufw or firewalld found. Open port $POSTGRES_PORT manually if needed."
fi

rkhunter --update 2>/dev/null
rkhunter --propupd 2>/dev/null

echo "$(date) - Finished db_setup" >>"$LOG"

echo ""
echo "DB setup complete."
echo "Postgres config: $PG_CONF"
echo "pg_hba.conf:     $PG_HBA"
echo "Port:            $POSTGRES_PORT"
echo "Listen addr:     $POSTGRES_LISTEN_ADDRESSES"
echo "Allowed subnet:  $POSTGRES_ALLOWED_SUBNET"
echo ""
echo "Checks:"
echo "  systemctl status postgresql"
echo "  ss -tlnp | grep $POSTGRES_PORT"
echo "  sudo -u postgres psql -c '\du'"
echo ""
