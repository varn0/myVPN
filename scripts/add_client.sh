#!/bin/bash

set -eoux pipefail


# add above args  with getopts
srv_port="65443"
local_client="false"

while getopts ":c:p:l:u:s:i:" opt; do
  case $opt in
    c) wg_client="${OPTARG}"
    ;;
    i) srv_public_ip="${OPTARG}"
    ;;
    p) srv_port="${OPTARG}"
    ;;
    l) local_client="${OPTARG}"
    ;;
    u) username="${OPTARG:-ubuntu}"
    ;;
    s) srv_ip="${OPTARG:-$srv_public_ip}"
    ;;
    \?) echo "Usage: $0 [-c client last octet] [-p server port] [-l local client] [-u username] [-s server ip] [-i server public ip]" >&2
    ;;
  esac
done

echo "port$srv_port"

echo "copying remote config"
ssh $username@$srv_ip sudo cp /etc/wireguard/wg0.conf /home/$username
ssh $username@$srv_ip sudo cp /etc/wireguard/publickey /home/$username
scp $username@$srv_ip:/home/$username/publickey /tmp/publickey
scp $username@$srv_ip:/home/$username/wg0.conf /tmp/wg0.conf
ssh $username@$srv_ip sudo rm -f /home/$username/wg0.conf
ssh $username@$srv_ip sudo rm -f /home/$username/publickey

wg_publickey=$(cat /tmp/publickey)

wg_client_pubkey=$(wg genkey | tee /tmp/privatekey | wg pubkey)
wg_client_privkey=$(cat /tmp/privatekey)
wg_client_presharedkey=$(wg genpsk)
wg_client_ip="10.9.0.$wg_client/32"

echo "adding client $wg_client with ip $wg_client_ip"
cat << EOF >> wg0.conf
[Interface]
PrivateKey = $wg_client_privkey
Address = $wg_client_ip
DNS = 1.1.1.1

[Peer]
PublicKey = $wg_publickey
AllowedIPs = 0.0.0.0/0
PresharedKey = $wg_client_presharedkey
Endpoint = $srv_public_ip:$srv_port
PersistentKeepalive=25
EOF

# if second arg is local send to /etc/wireguard/wg0.conf else copy in current dir
if [ "$local_client" == "true" ]; then
  sudo cp wg0.conf /etc/wireguard/wg0.conf
  rm -f ../wg0.conf
fi
qrencode -t png -o conf.png < wg0.conf

cat << EOF >> /tmp/wg0.conf
[Peer]
PublicKey = $wg_client_pubkey
AllowedIPs = $wg_client_ip
PresharedKey = $wg_client_presharedkey
EOF

# upload new server configuration and restart wireguard
ssh $username@$srv_ip rm -f /home/$username/wg0.conf
scp /tmp/wg0.conf $username@$srv_ip:/home/$username/wg0.conf
ssh $username@$srv_ip sudo cp /home/$username/wg0.conf /etc/wireguard/wg0.conf
ssh $username@$srv_ip "sudo wg-quick down wg0 && sudo wg-quick up wg0"


rm -f /tmp/wg0.conf
rm -f /tmp/publickey
rm -f /tmp/privatekey