#!/bin/bash


set -eou pipefail

### Variables ###
while getopts ":p:l" opt; do
  case $opt in
    p) WG_PORT="${OPTARG}"
    ;;
    l) LOCAL_INSTALL="true"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

WG_PORT="${WG_PORT:-"65443"}"
RUNNING_USER=$(who am i | awk '{print $1}')
SERVER_IF=$(ip route | grep default | awk '{print $5}')
WG_IF=wg0

##################

if [ "$(id -u)" != "0" ]; then
        echo "ERROR: This script must be run with sudo privileges"
        exit 1
fi

apt update
apt dist-upgrade -y
apt install -y wireguard

if [ ! -d /etc/wireguard ]; then
  echo "Can't find wireguard folder" && exit 1
else
  wg genkey | tee /etc/wireguard/privatekey | wg pubkey | tee /etc/wireguard/publickey > /dev/null
fi

echo "creating wg0 interface"
cat << EOF > /etc/wireguard/"$WG_IF.conf"
[Interface]
Address = 10.9.0.1/24
ListenPort = $WG_PORT
PrivateKey = $(cat /etc/wireguard/privatekey)
PostUp = iptables -A FORWARD -i $WG_IF -j ACCEPT; iptables -A FORWARD -o $WG_IF -j ACCEPT; iptables -t nat -A POSTROUTING -o $SERVER_IF -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_IF -j ACCEPT; iptables -D FORWARD -o $WG_IF -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_IF -j MASQUERADE
EOF

iptables -A INPUT -i $SERVER_IF -p udp -m state --state NEW -m udp --dport 65443 -j ACCEPT
iptables -A FORWARD -i $WG_IF -j ACCEPT
iptables -A FORWARD -o $WG_IF -j ACCEPT

systemctl enable wg-quick@$WG_IF.service
systemctl start wg-quick@$WG_IF.service

sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf
sysctl -p

if [ "$LOCAL_INSTALL" == "true" ]; then
  exit 0
else
  echo "creating user"
  useradd -m -s /bin/bash josefo
  echo "josefo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

