#!/bin/bash

### Will harden critical services
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
BACKUP_DIR="/var/backups/hardening_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

harden_ssh() {
    SSHD_CONFIG="/etc/ssh/sshd_config"
    cp "$SSHD_CONFIG" "$BACKUP_DIR/sshd_config.bak"
    
    declare -A SSH_SETTINGS=(
        ["Protocol"]="2"
        ["PermitRootLogin"]="no"
        ["PubkeyAuthentication"]="no"
        ["IgnoreRhosts"]="yes"
        ["PermitEmptyPasswords"]="no"
        ["PasswordAuthentication"]="no"
        ["ClientAliveInterval"]="300"
        ["MaxAuthTries"]="3"
        ["X11Forwarding"]="no"
    )

    for key in "${!SSH_SETTINGS[@]}"; do
        sed -i "s/^#*${key}.*/${key} ${SSH_SETTINGS[$key]}/" "$SSHD_CONFIG"
    done

    systemctl restart ssh sshd
}

harden_network() {
    SYSCTL_CONF="/etc/sysctl.conf"
    cp "$SYSCTL_CONF" "$BACKUP_DIR/sysctl.bak"
    
    declare -A SYSCTL_SETTINGS=(
        ["net.ipv4.conf.all.send_redirects"]="0"
        ["net.ipv4.conf.default.send_redirects"]="0"
        ["net.ipv4.icmp_echo_ignore_broadcasts"]="1"
        ["net.ipv4.conf.all.rp_filter"]="1"
        ["net.ipv4.conf.default.rp_filter"]="1"
        ["net.ipv4.tcp_syncookies"]="1"
    )

    for setting in "${!SYSCTL_SETTINGS[@]}"; do
        sysctl -w "$setting=${SYSCTL_SETTINGS[$setting]}"
        grep -q "$setting" "$SYSCTL_CONF" || echo "$setting = ${SYSCTL_SETTINGS[$setting]}" >> "$SYSCTL_CONF"
    done
}

harden_php() {
    find / -name php.ini 2>/dev/null | while read -r ini; do
        cp "$ini" "$BACKUP_DIR/php_$(basename "$ini").bak"
        declare -A PHP_SETTINGS=(
            ["display_errors"]="Off"
            ["short_open_tag"]="Off"
            ["disable_functions"]="shell_exec,exec,passthru,proc_open,popen,system,phpinfo"
            ["max_execution_time"]="30"
            ["allow_url_fopen"]="Off"
            ["allow_url_include"]="Off"
        )
        for key in "${!PHP_SETTINGS[@]}"; do
            sed -i "s/^;*${key}.*/${key} = ${PHP_SETTINGS[$key]}/" "$ini"
        done
    done
}

harden_samba() {
    [ -f /etc/samba/smb.conf ] && {
        cp /etc/samba/smb.conf "$BACKUP_DIR/smb.conf.bak"
        sed -i 's/^[ \t]*unix password sync[ \t]*=.*/unix password sync = no/
                s/^[ \t]*guest ok[ \t]*=.*/guest ok = no/' /etc/samba/smb.conf
        grep -q "invalid users" /etc/samba/smb.conf || echo "invalid users = root" >> /etc/samba/smb.conf
        systemctl restart smbd
    }
}

harden_postfix() {
    [ -x "$(command -v postfix)" ] && {
        cp /etc/postfix/main.cf "$BACKUP_DIR/postfix_main.cf.bak"
        postconf -e "smtpd_banner = \$myhostname ESMTP
                     disable_vrfy_command = yes
                     smtpd_helo_required = yes"
        systemctl restart postfix
    }
}

harden_dovecot() {
    [ -x "$(command -v dovecot)" ] && {
        find /etc/dovecot -name '*.conf' | while read -r conf; do
            sed -i 's/^#*disable_plaintext_auth.*/disable_plaintext_auth = yes/
                    s/^#*ssl[ \t]*=.*/ssl = required/' "$conf"
        done
        systemctl restart dovecot
    }
}

harden_ssh
harden_network
harden_php
harden_samba
harden_postfix
harden_dovecot

echo "Hardening complete. Backup files stored in: $BACKUP_DIR"
