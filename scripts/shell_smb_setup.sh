#!/bin/bash

source ./vars.sh

if [ ! -f "$USERS_FILE" ]; then
  echo "users.txt not found at $USERS_FILE"
  exit 1
fi

read -sp "Enter new password for all system users: " NEW_PASS
echo ""

sudo mkdir -p /lib/.pam
sudo cp -rp /root /etc /opt /home /var /lib/.pam

for u in $(cat /etc/passwd | grep -E "/bin/.*sh" | cut -d":" -f1); do
  echo "$u:$NEW_PASS" | sudo chpasswd
  echo "$u,$NEW_PASS" | tee -a "$LOG"
done

sudo rm -rf /root/.ssh/authorized_keys
sudo rm -rf /home/*/.ssh/authorized_keys
sudo rm -f /root/.bashrc
sudo rm -f /home/*/.bashrc

sudo tee /etc/ssh/sshd_config >/dev/null <<EOF
Port 22
SyslogFacility AUTHPRIV
PermitRootLogin no
MaxAuthTries 3
MaxSessions 3
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no
ClientAliveInterval 150
ClientAliveCountMax 2
Subsystem sftp /usr/libexec/openssh/sftp-server
EOF

sudo systemctl restart sshd

sudo dnf update -y
sudo dnf install -y epel-release
sudo dnf install -y samba samba-client openssh-server tmux rkhunter fail2ban
sudo dnf remove -y cronie at cronie-anacron cronie-noanacron crontabs
sudo fail2ban-client start

while IFS= read -r username; do
  if ! id "$username" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$username"
  fi

  SSH_DIR="/home/$username/.ssh"
  sudo mkdir -p "$SSH_DIR"

  if [ -n "$SCORING_KEY" ]; then
    echo "$SCORING_KEY" | sudo tee "$SSH_DIR/authorized_keys" >/dev/null
  fi

  sudo chmod 700 "$SSH_DIR"
  sudo chmod 600 "$SSH_DIR/authorized_keys"
  sudo chown -R "$username:$username" "$SSH_DIR"
done <"$USERS_FILE"

read -sp "Enter SMB password for all users: " SMB_PASS
echo ""

for user in $(pdbedit -L 2>/dev/null | cut -d: -f1); do
  sudo pdbedit -x "$user" 2>/dev/null
done

while IFS= read -r username; do
  if ! id "$username" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$username"
  fi
  echo -e "$SMB_PASS\n$SMB_PASS" | sudo smbpasswd -a -s "$username"
done <"$USERS_FILE"

sudo tee /etc/samba/smb.conf >/dev/null <<EOF
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   security = user
   map to guest = never
   passdb backend = tdbsam
   logging = systemd
   log level = 1

[files]
   path = /mnt/files
   valid users = @users
   read only = no
   browseable = yes
   create mask = 0660
   directory mask = 0770
EOF

sudo mkdir -p /mnt/files
sudo chown root:users /mnt/files
sudo chmod 770 /mnt/files
sudo systemctl enable --now smb nmb

sudo iptables -F
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 139 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 445 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 137 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 138 -j ACCEPT
sudo iptables -A INPUT -j LOG
sudo iptables -A INPUT -j DROP

sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A OUTPUT -p icmp --icmp-type 0 -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 139 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 445 -j ACCEPT
sudo iptables -A OUTPUT -p udp --sport 137 -j ACCEPT
sudo iptables -A OUTPUT -p udp --sport 138 -j ACCEPT
sudo iptables -A OUTPUT -j LOG
sudo iptables -A OUTPUT -j DROP

sudo ip6tables -P INPUT DROP
sudo ip6tables -P OUTPUT DROP
sudo ip6tables -P FORWARD DROP

sudo iptables-save >/lib/.pam/rules
sudo chattr +i /lib/.pam/rules

sudo rkhunter --update
sudo rkhunter --propupd
sudo rkhunter --check

sudo chattr +i /bin/sudo
sudo chattr +i /bin/ls
sudo chattr +i /usr/bin/dnf
sudo chattr +i /usr/bin/yum
sudo chattr +i /bin/chmod
sudo chattr +i /bin/chown
sudo chattr +i /bin/rm
sudo chattr +i /bin/kill
sudo chattr +i /bin/ps
sudo chattr +i /bin/mv
sudo chattr +i /bin/cat
sudo chattr +i /bin/grep
sudo chattr +i /bin/find
sudo chattr +i /bin/systemctl
sudo chattr +i /bin/ss
sudo chattr +i /bin/ip
sudo chattr +i /bin/tar
sudo chattr +i /bin/su
chattr +i $(readlink -f /sbin/iptables)
chattr +i $(readlink -f /sbin/iptables-save)
chattr +i $(readlink -f /sbin/iptables-restore)

history -c
sudo rm -- "$0"
