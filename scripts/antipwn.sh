#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run this with sudo."
  exit 1
fi

touch "$LOG"

pause() {
  echo ""
  read -p "Press Enter to continue..."
}

banner() {
  clear
  echo "========================================="
  echo "          UNLV Linux Hardening
  echo "========================================="
  echo ""
  echo "Users file: $USERS_FILE"
  echo "Log file:   $LOG"
  echo "Backup dir: $BACKUP_DIR"
  echo ""
}

run_script() {
  local f="$1"
  if [ -f "$SCRIPT_DIR/$f" ]; then
    echo "$(date) - Ran $f" >> "$LOG"
    bash "$SCRIPT_DIR/$f"
  else
    echo "Missing script: $f"
  fi
}

system_info() {
  echo ""
  echo "Hostname: $(hostname)"
  echo "Kernel:   $(uname -r)"
  echo "Uptime:   $(uptime -p 2>/dev/null || uptime)"
  echo ""
  echo "--- Interfaces ---"
  ip addr show
  echo ""
  echo "--- Routes ---"
  ip route
  echo ""
  echo "--- DNS ---"
  cat /etc/resolv.conf 2>/dev/null
  pause
}

run_common() {
  run_script "users.sh"
  run_script "ssh.sh"
  run_script "alias.sh"
  run_script "suid.sh"
  run_script "hunt.sh"
  run_script "payload.sh"
  pause
}

while true; do
  banner
  echo "  1)  System Info"
  echo "  2)  users.sh"
  echo "  3)  ssh.sh"
  echo "  4)  alias.sh"
  echo "  5)  suid.sh"
  echo "  6)  hunt.sh"
  echo "  7)  payload.sh"
  echo "  8)  backup.sh"
  echo "  9)  backupCmp.sh"
  echo "  10) restore.sh"
  echo "  11) pkgUpdate.sh"
  echo "  12) killAll.sh"
  echo "  13) dns_setup.sh"
  echo "  14) db_setup.sh"
  echo "  15) backup_setup.sh"
  echo "  16) View log"
  echo "  17) Run common audit set"
  echo "  0)  Exit"
  echo ""
  read -p "Choice: " choice

  case "$choice" in
    1) system_info ;;
    2) run_script "users.sh"; pause ;;
    3) run_script "ssh.sh"; pause ;;
    4) run_script "alias.sh"; pause ;;
    5) run_script "suid.sh"; pause ;;
    6) run_script "hunt.sh"; pause ;;
    7) run_script "payload.sh"; pause ;;
    8) run_script "backup.sh"; pause ;;
    9) run_script "backupCmp.sh"; pause ;;
    10) run_script "restore.sh"; pause ;;
    11) run_script "pkgUpdate.sh"; pause ;;
    12) run_script "killAll.sh"; pause ;;
    13) run_script "dns_setup.sh"; pause ;;
    14) run_script "db_setup.sh"; pause ;;
    15) run_script "backup_setup.sh"; pause ;;
    16) cat "$LOG"; pause ;;
    17) run_common ;;
    0) exit 0 ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac
done
