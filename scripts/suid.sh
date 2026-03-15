#!/bin/bash

SAFE="/usr/bin/passwd /usr/bin/su /usr/bin/sudo /usr/bin/newgrp /usr/bin/chsh /usr/bin/chfn /usr/bin/gpasswd /usr/bin/pkexec /usr/bin/crontab /usr/bin/mount /usr/bin/umount /usr/bin/ssh-agent /usr/lib/openssh/ssh-keysign /usr/libexec/openssh/ssh-keysign /usr/sbin/unix_chkpwd /bin/ping /usr/bin/ping"

echo "=== SUID FILES ==="
find / -perm -4000 -type f 2>/dev/null | while IFS= read -r f; do
  if echo "$SAFE" | grep -qw "$f"; then
    echo "[ok] $f"
  else
    echo "[review] $f"
  fi
done

echo ""
echo "=== SGID FILES ==="
find / -perm -2000 -type f 2>/dev/null
