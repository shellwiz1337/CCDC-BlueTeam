#!/bin/bash

# Checking root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Check iptables
if ! command -v iptables >/dev/null 2>&1; then
  echo "iptables not found! Install first." >&2
  exit 1
fi

# Initialize firewall
iptables -F
iptables -X
iptables -Z

# Connection tracking
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ICMP handling
read -p "Allow ICMP/ping? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
  iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
fi

# Port configuration function
configure_ports() {
  read -p "Enter space-separated $1 $2 ports to allow (both directions): " ports
  for port in ${ports[@]}; do
    [[ $port =~ ^[0-9]+$ ]] || continue
    
    # Inbound rules
    iptables -A INPUT -p $2 --dport $port -j ACCEPT
    
    # Outbound rules
    iptables -A OUTPUT -p $2 --dport $port -j ACCEPT
    
    echo "  - Enabled $2 port $port for both inbound and outbound"
  done
}

# Configure TCP ports
echo
read -p "Configure TCP ports? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  configure_ports "TCP" "tcp"
fi

# Configure UDP ports
echo
read -p "Configure UDP ports? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  configure_ports "UDP" "udp"
fi

# Special cases
echo
read -p "Allow DNS (UDP 53)? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  iptables -A INPUT -p udp --dport 53 -j ACCEPT
  iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
  echo "  - Enabled DNS (UDP 53) for both directions"
fi

# Final default DROP rules (executed last)
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Save rules
if command -v iptables-save >/dev/null 2>&1; then
  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4
  echo "Rules saved to /etc/iptables/rules.v4"
else
  echo "Warning: iptables-save not found - rules not persisted"
fi

echo
echo "Final firewall configuration:"
echo "----------------------------"
iptables -L -v -n
