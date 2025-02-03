#!/bin/bash
# Interactive firewall with separate inbound/outbound controls

# Check root
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

# Inbound port configuration
configure_inbound() {
  read -p "Enter space-separated $1 $2 ports to allow INBOUND: " ports
  for port in ${ports[@]}; do
    [[ $port =~ ^[0-9]+$ ]] || continue
    iptables -A INPUT -p $2 --dport $port -j ACCEPT
    echo "  - Enabled INBOUND $2 port $port"
  done
}

# Outbound port configuration
configure_outbound() {
  read -p "Enter space-separated $1 $2 ports to allow OUTBOUND: " ports
  for port in ${ports[@]}; do
    [[ $port =~ ^[0-9]+$ ]] || continue
    iptables -A OUTPUT -p $2 --dport $port -j ACCEPT
    echo "  - Enabled OUTBOUND $2 port $port"
  done
}

# Configure inbound TCP
echo
read -p "Configure INBOUND TCP ports? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  configure_inbound "TCP" "tcp"
fi

# Configure inbound UDP
echo
read -p "Configure INBOUND UDP ports? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  configure_inbound "UDP" "udp"
fi

# Configure outbound TCP
echo
read -p "Configure OUTBOUND TCP ports? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  configure_outbound "TCP" "tcp"
fi

# Configure outbound UDP
echo
read -p "Configure OUTBOUND UDP ports? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  configure_outbound "UDP" "udp"
fi

# Special cases - DNS
echo
read -p "Allow INBOUND DNS (UDP 53)? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  iptables -A INPUT -p udp --dport 53 -j ACCEPT
  echo "  - Enabled INBOUND DNS (UDP 53)"
fi

echo
read -p "Allow OUTBOUND DNS (UDP 53)? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
  iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
  echo "  - Enabled OUTBOUND DNS (UDP 53)"
fi

# Final default DROP rules
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
echo "INBOUND RULES:"
iptables -L INPUT -v -n
echo
echo "OUTBOUND RULES:"
iptables -L OUTPUT -v -n
