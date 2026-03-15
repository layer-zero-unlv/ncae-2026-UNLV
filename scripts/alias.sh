#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

check_file() {
  local f="$1"

  [ -f "$f" ] || return

  echo "Checking $f"
  while IFS= read -r line; do
    if echo "$line" | grep -Eqi '^[[:space:]]*alias[[:space:]]+[A-Za-z0-9_-]+=.*(rm|mv|cp|curl|wget|nc|ncat|netcat|bash|sh|python|perl|ruby|php|/dev/tcp)'; then
      echo "[!] $line"
    fi
  done <"$f"
  echo ""
}

echo "=== USER FILES ==="

check_file /root/.bashrc
check_file /root/.bash_profile
check_file /root/.bash_aliases
check_file /root/.profile
check_file /root/.zshrc

for home in /home/*; do
  [ -d "$home" ] || continue
  check_file "$home/.bashrc"
  check_file "$home/.bash_profile"
  check_file "$home/.bash_aliases"
  check_file "$home/.profile"
  check_file "$home/.zshrc"
done

echo "=== GLOBAL FILES ==="

check_file /etc/profile
check_file /etc/bashrc
check_file /etc/bash.bashrc
check_file /etc/zshrc

for f in /etc/profile.d/*.sh; do
  [ -f "$f" ] && check_file "$f"
done
