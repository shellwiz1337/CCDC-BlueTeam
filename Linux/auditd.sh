#!/bin/bash

# Check root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root!"
  exit 1
fi

install_auditd() {
  if command -v apt-get &> /dev/null; then
    apt-get update && apt-get install -y auditd || { echo "APT failed"; exit 1; }
  elif command -v yum &> /dev/null; then
    yum install -y audit || { echo "YUM failed"; exit 1; }
  elif command -v dnf &> /dev/null; then
    dnf install -y audit || { echo "DNF failed"; exit 1; }
  else
    echo "Unsupported package manager!"
    exit 1
  fi
  systemctl enable --now auditd
}

! command -v auditctl &> /dev/null && install_auditd

# Backup existing rules with timestamp
cp /etc/audit/rules.d/audit.rules /etc/audit/rules.d/audit.rules.bak.$(date +%s) 2>/dev/null

# Base configuration with critical fixes
cat << EOF > /etc/audit/rules.d/security.rules
## Core Parameters
-b 8192
-f 1

## Audit infrastructure monitoring
-w /var/log/audit/ -p rwa -k auditlog
-w /etc/audit/ -p wa -k auditconfig
-w /etc/libaudit.conf -p wa -k auditconfig
-w /etc/audisp/ -p wa -k audispconfig
-w /sbin/auditctl -p x -k audittools
-w /sbin/auditd -p x -k audittools

## Cron monitoring
-w /etc/cron.allow -p wa -k cron_config
-w /etc/cron.deny -p wa -k cron_config
-w /etc/cron.d/ -p wa -k cron_config
-w /etc/cron.daily/ -p wa -k cron_config
-w /etc/cron.hourly/ -p wa -k cron_config
-w /etc/cron.monthly/ -p wa -k cron_config
-w /etc/cron.weekly/ -p wa -k cron_config
-w /var/spool/cron/ -p wa -k cron_user

## Identity & Authentication
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-w /etc/sudoers -p wa -k priv_esc
-w /etc/sudoers.d/ -p wa -k priv_esc
-a always,exit -F arch=b64 -S setuid,setgid -k priv_esc

# Password/Group Tools
-w /usr/sbin/groupadd -p x -k group_modification 
-w /usr/sbin/groupmod -p x -k group_modification 
-w /usr/sbin/addgroup -p x -k group_modification 
-w /usr/sbin/useradd -p x -k user_modification 
-w /usr/sbin/usermod -p x -k user_modification 
-w /usr/sbin/adduser -p x -k user_modification

#SUID binaries
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F a2=0x4000 -k setuid_mod

# Login Tracking
-w /var/log/faillog -p wa -k auth_fail
-w /var/log/lastlog -p wa -k auth_track
-w /etc/login.defs -p wa -k login 
-w /etc/securetty -p wa -k login
-w /var/log/tallylog -p wa -k login

## Configuration Directories
-w /etc/pam.d/ -p wa -k pam_config
-w /etc/security/ -p wa -k pam_config

## Network Recon
-a always,exit -F arch=b64 -S connect -k net_conn
-w /usr/bin/nmap -p x -k recon_tool
-w /usr/bin/netcat -p x -k recon_tool
-w /usr/bin/ncat -p x -k recon_tool
-w /usr/bin/nc -p x -k recon_tool

## Remote Access Tools
-w /usr/bin/ssh -p x -k remote_access
-w /usr/bin/scp -p x -k remote_access
-w /usr/bin/wget -p x -k remote_transfer
-w /usr/bin/sftp -p x -k remote_transfer
-w /usr/bin/ftp -p x -k remote_transfer
-w /usr/bin/socat -p x -k remote_transfer
-w /usr/bin/curl -p x -k remote_access

## Unauthorized tty access
-w /dev/pts/ -p rwxa -k tty_access


## Authentication tools (pattern-based)
-w /usr/bin/passwd -p x -k auth_tool
-a always,exit -F arch=b64 -S chown,fchown,fchownat -F auid>=1000 -F auid!=-1 -k auth_change

## Session monitoring
-w /bin/su -p x -k session
-w /usr/bin/sudo -p x -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
-w /var/run/utmp -p wa -k session

## Service configurations
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /root/.ssh/ -p wa -k ssh_keys
-w /etc/apache2/ -p wa -k web_config
-w /etc/nginx/ -p wa -k web_config
-w /etc/mysql/ -p wa -k db_config
-w /etc/postgresql/ -p wa -k db_config
-w /etc/postfix/ -p wa -k mail_config
-w /etc/dovecot/ -p wa -k mail_config

# Credential dumping (Mimikatz-style)
-a always,exit -F arch=b64 -S open -F path=/etc/shadow -F perm=wa -k cred_dump
-a always,exit -F arch=b64 -S ptrace -F a0=0x10 -k process_injection  

# Lateral movement detection
-a always,exit -F arch=b64 -S connect -F exe=/usr/bin/ssh -F success=1 -k ssh_connection
-a always,exit -F arch=b64 -S connect -F exe=/usr/bin/scp -F success=1 -k scp_transfer

# Reverse shell detection
-a always,exit -F arch=b64 -S socket -F a0=2 -F exe=/bin/bash -k reverse_shell
-a always,exit -F arch=b64 -S socket -F a0=2 -F exe=/bin/sh -k reverse_shell

# Fileless attack detection
-a always,exit -F arch=b64 -S memfd_create -k fileless_mem
-a always,exit -F arch=b64 -S execveat -F dir=/proc/self/fd -k fileless_exec


## Capture all failures to access on critical elements 
-a always,exit -F arch=b64 -S open -F dir=/etc -F success=0 -k unauthedfileaccess 
#-a always,exit -F arch=b64 -S open -F dir=/bin -F success=0 -k unauthedfileaccess 
#-a always,exit -F arch=b64 -S open -F dir=/sbin -F success=0 -k unauthedfileaccess 
#-a always,exit -F arch=b64 -S open -F dir=/usr/bin -F success=0 -k unauthedfileaccess
#-a always,exit -F arch=b64 -S open -F dir=/usr/sbin -F success=0 -k unauthedfileaccess 
#-a always,exit -F arch=b64 -S open -F dir=/var -F success=0 -k unauthedfileaccess 
#-a always,exit -F arch=b64 -S open -F dir=/home -F success=0 -k unauthedfileaccess 
#-a always,exit -F arch=b64 -S open -F dir=/srv -F success=0 -k unauthedfileaccess

## File Deletion
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rmdir -S rename -S renameat -k file_deletion


## System integrity
# Kernel module protection
-w /sbin/insmod -p x -k kernel_mod
-w /sbin/rmmod -p x -k kernel_mod

# Critical binary protection
#-w /bin/ -p x -k bin_exec
#-w /usr/bin/ -p x -k bin_exec

# Configuration file integrity
-w /etc/ -p wa -k etc_mod
EOF

# Apply rules safely
if ! auditctl -R /etc/audit/rules.d/security.rules; then
  echo "Error loading audit rules! Check syntax."
  exit 1
fi

systemctl restart auditd

echo "Audit Rules Successfully Applied!"
echo "Critical Monitoring Keys:"
echo "  cred_dump       - Credential dumping attempts"
echo "  reverse_shell   - Reverse shell detection"
echo "  fileless_*      - Fileless attack patterns"
echo "  webshell_write  - Web shell deployment"
echo ""
echo "View logs: ausearch -k [key] | aureport -f -i"
