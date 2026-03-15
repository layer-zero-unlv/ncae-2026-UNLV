#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/vars.sh"

echo "=== RECENT FILES ==="
find / \
  -not \( -path /proc -prune \) \
  -not \( -path /sys -prune \) \
  -not \( -path /run -prune \) \
  -mmin "-$RECENT_MINUTES" -type f 2>/dev/null
echo ""

echo "=== ORPHANED FILES ==="
find / \
  -not \( -path /proc -prune \) \
  -not \( -path /sys -prune \) \
  \( -nouser -o -nogroup \) 2>/dev/null
echo ""

echo "=== TMP AREAS ==="
ls -la /tmp 2>/dev/null
echo ""
ls -la /var/tmp 2>/dev/null
echo ""
ls -la /dev/shm 2>/dev/null
echo ""

echo "=== SUSPICIOUS CONNECTIONS ==="
ss -pantup 2>/dev/null | grep -Ei 'bash|nc |ncat|python|perl|ruby|php|curl|wget|/tmp|/dev/shm' || echo "None"
echo ""

echo "=== WORLD WRITABLE FILES OUTSIDE TEMP ==="
find / \
  -not \( -path /proc -prune \) \
  -not \( -path /sys -prune \) \
  -not \( -path /dev -prune \) \
  -perm -o+w -type f 2>/dev/null | grep -Ev '^/tmp|^/var/tmp|^/dev/shm'
echo ""

echo "=== SUSPICIOUS CRON LINES ==="
grep -RniE 'curl|wget|nc |ncat|netcat|/dev/tcp|bash -i|python.*socket|perl.*socket|php.*socket' \
  /etc/crontab /etc/cron.* /var/spool/cron /var/spool/cron/crontabs 2>/dev/null || echo "None"
echo ""

echo "=== PROMISCUOUS INTERFACES ==="
ip link | grep PROMISC || echo "None"
echo ""

echo "=== /etc/ld.so.preload ==="
if [ -f /etc/ld.so.preload ]; then
  cat /etc/ld.so.preload
else
  echo "Not found"
fi
