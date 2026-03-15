#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

MYSQL_PORT="${MYSQL_PORT:-3306}"
STAMP="$(date +%F_%H%M%S)"
SAVE_DIR="$BACKUP_DIR/mysql_$STAMP"

mkdir -p "$SAVE_DIR"

[ -d /etc/ssh ] && cp -a /etc/ssh "$SAVE_DIR/" 2>/dev/null
[ -d /etc/mysql ] && cp -a /etc/mysql "$SAVE_DIR/" 2>/dev/null
[ -f /etc/my.cnf ] && cp -a /etc/my.cnf "$SAVE_DIR/" 2>/dev/null

MYSQL_CMD=""
if command -v mysql >/dev/null 2>&1; then
  mysqldump -u root --all-databases >"$SAVE_DIR/all_databases.sql" 2>/dev/null
  chmod 600 "$SAVE_DIR/all_databases.sql"
  MYSQL_CMD="mysql"
elif command -v mariadb >/dev/null 2>&1; then
  mariadb-dump -u root --all-databases >"$SAVE_DIR/all_databases.sql" 2>/dev/null
  chmod 600 "$SAVE_DIR/all_databases.sql"
  MYSQL_CMD="mariadb"
fi

echo "$(date) - Saved MySQL backup to $SAVE_DIR" >>"$LOG"

if command -v apt >/dev/null 2>&1; then
  apt update
  apt install -y mysql-server fail2ban tmux rkhunter lsof 2>/dev/null || apt install -y mariadb-server fail2ban tmux rkhunter lsof
  MYSQL_SERVICE="mysql"
  systemctl list-unit-files 2>/dev/null | grep -q '^mariadb.service' && MYSQL_SERVICE="mariadb"
  MYSQL_CONF="/etc/mysql/my.cnf"
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y epel-release
  dnf install -y mariadb-server fail2ban tmux rkhunter lsof 2>/dev/null || dnf install -y mysql-server fail2ban tmux rkhunter lsof
  MYSQL_SERVICE="mariadb"
  systemctl list-unit-files 2>/dev/null | grep -q '^mysqld.service' && MYSQL_SERVICE="mysqld"
  MYSQL_CONF="/etc/my.cnf"
else
  echo "No supported package manager found."
  exit 1
fi

systemctl enable --now "$MYSQL_SERVICE"
systemctl enable --now fail2ban 2>/dev/null

[ -z "$MYSQL_CMD" ] && command -v mysql >/dev/null 2>&1 && MYSQL_CMD="mysql"
[ -z "$MYSQL_CMD" ] && command -v mariadb >/dev/null 2>&1 && MYSQL_CMD="mariadb"

if [ -z "$MYSQL_CMD" ]; then
  echo "No mysql/mariadb client found."
  exit 1
fi

read -sp "Enter new MySQL root password: " MYSQL_PASS
echo ""

$MYSQL_CMD -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASS';" 2>/dev/null || \
  $MYSQL_CMD -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_PASS');" 2>/dev/null

echo "$(date) - Changed MySQL root password" >>"$LOG"

echo ""
echo "=== REVOKING NON-ROOT PRIVILEGES ==="
$MYSQL_CMD -u root -p"$MYSQL_PASS" -e "
SELECT CONCAT('REVOKE ALL PRIVILEGES ON *.* FROM ''', user, '''@''', host, ''';')
FROM mysql.user
WHERE user != 'root' AND user != '';
" 2>/dev/null | while IFS= read -r query; do
  echo "$query" | grep -q "^REVOKE" || continue
  $MYSQL_CMD -u root -p"$MYSQL_PASS" -e "$query" 2>/dev/null
  echo "Executed: $query"
done

$MYSQL_CMD -u root -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null
echo "$(date) - Revoked non-root MySQL privileges" >>"$LOG"

mkdir -p /var/log/mysql
if id mysql >/dev/null 2>&1; then
  chown mysql:mysql /var/log/mysql
fi

cp "$MYSQL_CONF" "$MYSQL_CONF.bak.$STAMP" 2>/dev/null

cat >"$MYSQL_CONF" <<EOF
[mysqld]
port = $MYSQL_PORT
bind-address = 0.0.0.0
max_connections = 20
secure_file_priv = /var/lib/mysql
general_log_file = /var/log/mysql/query.log
general_log = 1
local_infile = 0
symbolic-links = 0
max_allowed_packet = 16M
EOF

systemctl restart "$MYSQL_SERVICE"
echo "$(date) - Configured and restarted $MYSQL_SERVICE" >>"$LOG"

rkhunter --update 2>/dev/null
rkhunter --propupd 2>/dev/null

echo ""
echo "MySQL setup complete."
echo "Service:    $MYSQL_SERVICE"
echo "Config:     $MYSQL_CONF"
echo "Port:       $MYSQL_PORT"
echo ""
echo "Checks:"
echo "  systemctl status $MYSQL_SERVICE"
echo "  ss -tlnp | grep $MYSQL_PORT"
echo "  $MYSQL_CMD -u root -p -e 'SELECT user,host FROM mysql.user;'"
echo ""
