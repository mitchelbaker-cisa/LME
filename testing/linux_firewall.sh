#!/bin/bash

# This script checks if the linux deployment is using ufw, firewalld, or just straight ipables. 
# It then adds inbound allows for ports 22 (ssh) 443 (web gui) and 5044 (winlogbeat)
# Keep in mind once these inbound rules are active it is likely that all other ports are then disallowed. Add more as needed.

PORTS=(22 443 5044)

setup_ufw() {
    for port in "${PORTS[@]}"; do
        echo "Setting up rule with ufw for port $port..."
        sudo ufw allow "$port"/tcp
    done
    sudo ufw reload
}

setup_firewalld() {
    for port in "${PORTS[@]}"; do
        echo "Setting up rule with firewalld for port $port..."
        sudo firewall-cmd --zone=public --add-port="$port"/tcp --permanent
    done
    sudo firewall-cmd --reload
}

setup_iptables() {
    for port in "${PORTS[@]}"; do
        echo "Setting up rule with iptables for port $port..."
        sudo iptables -A INPUT -p tcp --dport "$port" -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
    done
    sudo netfilter-persistent save
    sudo netfilter-persistent reload
}

if command -v ufw >/dev/null && sudo ufw status | grep -qw active; then
    setup_ufw
elif command -v firewall-cmd >/dev/null && sudo firewall-cmd --state | grep -qw running; then
    setup_firewalld
else
    if ! dpkg -s iptables-persistent >/dev/null 2>&1; then
        echo "iptables-persistent not found, installing..."
        sudo apt update
        sudo apt install -y iptables-persistent
    fi
    setup_iptables
fi

echo "Firewall rules for inbound TCP on ports ${PORTS[*]} have been added."
