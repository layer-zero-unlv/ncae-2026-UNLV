#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

lock_bin() {
  local f="$1"

  [ -f "$f" ] || return
  chattr +i "$f" 2>/dev/null && echo "Locked $f"
}

lock_resolved() {
  local f="$1"

  resolved="$(readlink -f "$f" 2>/dev/null)"
  [ -z "$resolved" ] && return
  [ -f "$resolved" ] || return
  chattr +i "$resolved" 2>/dev/null && echo "Locked $resolved"
}

echo "=== LOCKING CRITICAL BINARIES ==="

for bin in \
  /bin/sudo /usr/bin/sudo \
  /bin/ls /usr/bin/ls \
  /bin/chmod /usr/bin/chmod \
  /bin/chown /usr/bin/chown \
  /bin/rm /usr/bin/rm \
  /bin/mv /usr/bin/mv \
  /bin/cp /usr/bin/cp \
  /bin/cat /usr/bin/cat \
  /bin/grep /usr/bin/grep \
  /bin/find /usr/bin/find \
  /bin/ps /usr/bin/ps \
  /bin/kill /usr/bin/kill \
  /bin/su /usr/bin/su \
  /bin/tar /usr/bin/tar \
  /bin/systemctl /usr/bin/systemctl \
  /bin/ss /usr/bin/ss \
  /bin/ip /usr/bin/ip /sbin/ip \
  /bin/ping /usr/bin/ping \
  /bin/echo /usr/bin/echo \
  /bin/ln /usr/bin/ln \
  /bin/touch /usr/bin/touch \
  /bin/stat /usr/bin/stat \
  /bin/hostname /usr/bin/hostname \
  /bin/hostnamectl /usr/bin/hostnamectl \
  /usr/sbin/userdel /sbin/userdel \
  /bin/tail /usr/bin/tail \
  /bin/pwd /usr/bin/pwd; do
  lock_bin "$bin"
done
echo ""

echo "=== LOCKING PACKAGE MANAGER ==="
if command -v apt >/dev/null 2>&1; then
  lock_resolved "$(command -v apt)"
  lock_resolved "$(command -v apt-get)"
  lock_resolved "$(command -v dpkg)"
elif command -v dnf >/dev/null 2>&1; then
  lock_resolved "$(command -v dnf)"
  lock_resolved "$(command -v yum)"
  lock_resolved "$(command -v rpm)"
fi
echo ""

echo "=== LOCKING IPTABLES ==="
lock_resolved "$(command -v iptables)"
lock_resolved "$(command -v iptables-save)"
lock_resolved "$(command -v iptables-restore)"
echo ""

echo "=== LOCKING EDITORS ==="
lock_resolved "$(command -v vi)"
lock_resolved "$(command -v vim)"
lock_resolved "$(command -v nano)"
echo ""

read -p "Also lock network tools (wget, curl, dig, ssh)? (y/n): " ans
if [ "$ans" = "y" ]; then
  for bin in wget curl dig ssh; do
    lock_resolved "$(command -v "$bin")"
  done
fi

echo "$(date) - Locked critical binaries with chattr +i" >>"$LOG"
echo ""
echo "Done. To unlock a binary: chattr -i /path/to/binary"
