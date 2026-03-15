#!/bin/bash

owned_by_pkg() {
  local f="$1"

  if command -v rpm >/dev/null 2>&1; then
    rpm -qf "$f" >/dev/null 2>&1
    return $?
  fi

  if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -S "$f" >/dev/null 2>&1
    return $?
  fi

  return 1
}

echo "=== EXECUTABLES IN WRITABLE PLACES ==="
find /tmp /var/tmp /dev/shm /home /opt -type f 2>/dev/null | while IFS= read -r f; do
  if file "$f" 2>/dev/null | grep -Eqi 'ELF|script|executable|Go'; then
    echo "$f"
  fi
done
echo ""

echo "=== STRINGS THAT LOOK WEIRD ==="
find /tmp /var/tmp /dev/shm /home /opt -type f 2>/dev/null | while IFS= read -r f; do
  if file "$f" 2>/dev/null | grep -Eqi 'ELF|script|executable'; then
    if strings "$f" 2>/dev/null | grep -Eqi 'sliver|beacon|implant|meterpreter|/dev/tcp|grpc'; then
      echo "$f"
    fi
  fi
done
echo ""

echo "=== RUNNING BINARIES WITH NO PACKAGE OWNER ==="
for pid in /proc/[0-9]*; do
  exe="$(readlink "$pid/exe" 2>/dev/null)"
  [ -z "$exe" ] && continue
  if ! owned_by_pkg "$exe"; then
    echo "$(basename "$pid") -> $exe"
  fi
done
echo ""

echo "=== DELETED BUT STILL RUNNING ==="
ls -l /proc/*/exe 2>/dev/null | grep "(deleted)" || echo "None"
