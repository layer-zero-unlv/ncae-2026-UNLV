#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

STAMP="$(date +%F_%H%M%S)"
QDIR="/root/sched_quarantine_$STAMP"

mkdir -p "$QDIR"

move_file() {
  local f="$1"

  [ -f "$f" ] || return

  echo "=== $f ==="
  cat "$f"
  echo ""
  read -p "Move this file to quarantine? (y/n): " ans
  if [ "$ans" = "y" ]; then
    mv "$f" "$QDIR/"
    echo "Moved $f"
    echo "$(date) - Quarantined $f" >>"$LOG"
  fi
  echo ""
}

echo "=== ROOT CRONTAB ==="
crontab -l 2>/dev/null || echo "Empty"
echo ""

for f in /etc/crontab /etc/anacrontab; do
  move_file "$f"
done

for f in /etc/cron.d/* /etc/cron.hourly/* /etc/cron.daily/* /etc/cron.weekly/* /etc/cron.monthly/*; do
  move_file "$f"
done

for d in /var/spool/cron /var/spool/cron/crontabs; do
  if [ -d "$d" ]; then
    for f in "$d"/*; do
      move_file "$f"
    done
  fi
done

echo "=== AT JOBS ==="
if command -v atq >/dev/null 2>&1; then
  atq
  while true; do
    read -p "Enter at job id to remove or press Enter to stop: " jid
    [ -z "$jid" ] && break
    atrm "$jid"
    echo "$(date) - Removed at job $jid" >>"$LOG"
  done
else
  echo "atq not installed"
fi
echo ""

echo "=== SYSTEMD TIMERS ==="
systemctl list-timers --all 2>/dev/null
echo ""

while true; do
  read -p "Enter timer unit to disable or press Enter to stop: " t
  [ -z "$t" ] && break
  systemctl disable --now "$t" 2>/dev/null
  echo "$(date) - Disabled timer $t" >>"$LOG"
done

read -p "Stop cron/crond service? (y/n): " ans
if [ "$ans" = "y" ]; then
  systemctl stop cron 2>/dev/null
  systemctl disable cron 2>/dev/null
  systemctl stop crond 2>/dev/null
  systemctl disable crond 2>/dev/null
fi

read -p "Stop atd service? (y/n): " ans
if [ "$ans" = "y" ]; then
  systemctl stop atd 2>/dev/null
  systemctl disable atd 2>/dev/null
fi
