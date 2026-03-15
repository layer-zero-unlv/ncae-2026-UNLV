# UNLV Scripts

Scripts for auditing, backup, restore, SSH review, package checking, and persistence hunting.

## Setup

Make sure you have:

- `vars.sh` in the same directory
- `users.txt` in your home directory if you want user-based checks
- `sudo` access for scripts that modify the system

Example `vars.sh`:

```bash
#!/bin/bash

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
REAL_HOME="${REAL_HOME:-$HOME}"

BACKUP_IP="${BACKUP_IP:-}"
BACKUP_USER="${BACKUP_USER:-backup}"
TEAM_SUBNET="${TEAM_SUBNET:-192.168.0.0/24}"
USERS_FILE="${USERS_FILE:-$REAL_HOME/users.txt}"
SCORING_KEY="${SCORING_KEY:-}"
LOG="${LOG:-$REAL_HOME/hardening_log.txt}"
BACKUP_DIR="${BACKUP_DIR:-/.backup}"
RECENT_MINUTES="${RECENT_MINUTES:-60}"
```

Example `users.txt`:

```text
Austin
John
Sarah
```

Make scripts executable:

```bash
chmod +x *.sh
```

## Scripts

### `vars.sh`

Shared variables file used by the other scripts.

Run:

```bash
source ./vars.sh
```

### `antipwn.sh`

Main menu script that ties the other scripts together and gives you one place to launch audits, backup, restore, and review tasks.

Run:

```bash
sudo ./antipwn.sh
```

### `users.sh`

Audits login-capable users, UID 0 accounts, sudo/wheel membership, and checks who is not in `users.txt`.

Run:

```bash
sudo ./users.sh
```

### `ssh.sh`

Reviews `authorized_keys`, quarantines keys for unauthorized users, hardens `sshd_config`, and can restart SSH safely after validation.

Run:

```bash
sudo ./ssh.sh
```

### `alias.sh`

Scans user and global shell startup files for suspicious aliases that may hijack commands like `rm`, `curl`, or `bash`.

Run:

```bash
sudo ./alias.sh
```

### `suid.sh`

Lists SUID and SGID binaries and flags unusual or unpackaged ones for review.

Run:

```bash
sudo ./suid.sh
```

### `hunt.sh`

Looks for suspicious files, recent file changes, orphaned files, bad cron entries, odd outbound connections, and other common persistence clues.

Run:

```bash
sudo ./hunt.sh
```

### `payload.sh`

Searches for suspicious executables, implants, strange binaries in writable directories, and running processes with no package owner.

Run:

```bash
sudo ./payload.sh
```

### `backup.sh`

Creates a local backup of common config and service directories into `BACKUP_DIR`.

Run:

```bash
sudo ./backup.sh
```

### `backupCmp.sh`

Compares live system files against the backup directory and shows differences.

Run:

```bash
sudo ./backupCmp.sh
```

### `restore.sh`

Interactively restores selected directories from `BACKUP_DIR` and restarts affected services when appropriate.

Run:

```bash
sudo ./restore.sh
```

### `pkgUpdate.sh`

Checks for package updates and verifies package integrity using the system package manager.

Run:

```bash
sudo ./pkgUpdate.sh
```

### `killAll.sh`

Reviews cron jobs, anacron files, at jobs, and systemd timers, then lets you quarantine or disable suspicious jobs.

Run:

```bash
sudo ./killAll.sh
```

## Recommended Use Order

### Fastest way

```bash
sudo ./antipwn.sh
```

### First pass audit

```bash
sudo ./users.sh
sudo ./ssh.sh
sudo ./alias.sh
sudo ./suid.sh
sudo ./hunt.sh
sudo ./payload.sh
```

### Backup after you have a known good state

```bash
sudo ./backup.sh
```

### Compare later if you suspect tampering

```bash
sudo ./backupCmp.sh
```

### Restore if needed

```bash
sudo ./restore.sh
```

### Package and scheduler review

```bash
sudo ./pkgUpdate.sh
sudo ./killAll.sh
```

## Notes

- `users.txt` should contain one username per line.
- `ssh.sh` uses `SCORING_KEY` from `vars.sh` if you want to preserve a required SSH public key.
- `restore.sh` is interactive so you can avoid restoring something that would break a live service.

## Scripts and descriptions

- `antipwn.sh` — launch the other tools from one place
- `users.sh` — check accounts, sudo users, and unauthorized logins
- `ssh.sh` — clean up SSH keys and harden SSH config
- `alias.sh` — catch malicious shell aliases
- `suid.sh` — find suspicious privilege-escalation binaries
- `hunt.sh` — sweep the box for common persistence and tampering clues
- `payload.sh` — hunt suspicious payloads and unpackaged executables
- `backup.sh` — save a known-good copy of important files
- `backupCmp.sh` — diff live files against backup
- `restore.sh` — restore selected paths from backup
- `pkgUpdate.sh` — check updates and package integrity
- `killAll.sh` — review and disable suspicious scheduled tasks
- `vars.sh` — shared defaults for the rest of the scripts
