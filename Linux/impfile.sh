#!/bin/bash


# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo or switch to root user."
    exit 1
fi

# Create output directory for findings
REPORT_DIR="/tmp/security_audit_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"

# Critical files to make immutable
CRITICAL_FILES=(
    /etc/passwd
    /etc/shadow
    /etc/group
    /etc/gshadow
    /etc/sudoers
    /etc/ssh/sshd_config
    /etc/pam.d/su
    /etc/pam.d/passwd
)

# Critical directories to verify ownership/permissions
CRITICAL_DIRS=(
    /etc
    /boot
    /usr
    /var
    /root
    /home
)

# Function: Set secure permissions and ownership
secure_critical_files() {
    echo "Securing critical file permissions..."
    
    # System files
    chmod 644 /etc/passwd
    chmod 600 /etc/shadow
    chmod 644 /etc/group
    chmod 600 /etc/gshadow
    chmod 600 /etc/sudoers
    chmod 600 /etc/ssh/sshd_config
    
    # Directory permissions
    for dir in "${CRITICAL_DIRS[@]}"; do
        chown root:root "$dir"
        chmod 0755 "$dir"
    done
    
    # Root home directory
    chmod 700 /root
}

# Function: Set immutable attributes
set_immutable() {
    echo "Setting immutable attributes..."
    for file in "${CRITICAL_FILES[@]}"; do
        if [ -f "$file" ]; then
            lsattr "$file" | grep -q "\-i-" || chattr +i "$file"
        fi
    done
    echo "Immutable attributes set. To modify these files later:"
    echo "Use 'chattr -i <file>' as root to remove immutable flag."
}

# Security checks
find_world_writable() {
    echo "Scanning for world-writable files..."
    find / -xdev -type f -perm -o+w -not -path "/proc/*" -not -path "/sys/*" \
        -not -path "/dev/*" -not -path "/run/*" > "$REPORT_DIR/world_writable_files.txt"
}

find_suid_sgid() {
    echo "Finding SUID/SGID binaries..."
    find / -xdev -type f \( -perm -4000 -o -perm -2000 \) \
        -not -path "/proc/*" -not -path "/sys/*" \
        > "$REPORT_DIR/suid_sgid_binaries.txt"
}

find_unowned_files() {
    echo "Searching for unowned files..."
    find / -xdev \( -nouser -o -nogroup \) \
        -not -path "/proc/*" -not -path "/sys/*" \
        > "$REPORT_DIR/unowned_files.txt"
}

# Main execution
echo "Starting system hardening..."
secure_critical_files
set_immutable
find_world_writable
find_suid_sgid
find_unowned_files

echo -e "\nHardening complete. Security findings saved to: $REPORT_DIR"
echo -e "\nNext steps:"
echo "1. Review all files in the report directory"
echo "2. Remove unnecessary SUID/SGID permissions with 'chmod -s <file>'"


exit 0
