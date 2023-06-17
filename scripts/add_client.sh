#!/bin/bash

set -eou pipefail


# add above args  with getopts
srv_port="65443"
local_client="false"

while getopts ":c:p:l:u:s:i:" opt; do
  case $opt in
    c) wg_client="${OPTARG}"
    ;;
    s) srv_public_ip="${OPTARG}"
    ;;
    p) srv_port="${OPTARG}"
    ;;
    l) local_client="${OPTARG}"
    ;;
    u) username="${OPTARG:-ubuntu}"
    ;;
    i) srv_private_ip="${OPTARG:-$srv_public_ip}"
    ;;
    \?) echo "Usage: $0 [-c client last octet] [-p server port] [-l local client] [-u username] [-i server ip] [-s server public ip]" >&2
    ;;
  esac
done


srv_wg_publickey=$(ssh "${username}@${srv_public_ip}" "cat /etc/wireguard/publickey")


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
PublicKey = $srv_wg_publickey
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

                                      
ssh "${username}@${srv_public_ip}" << EOF 
  echo "[Peer]" >> /etc/wireguard/wg0.conf
  echo "PublicKey = ${wg_client_pubkey}" >> /etc/wireguard/wg0.conf
  echo "AllowedIPs = ${wg_client_ip}/32" >> /etc/wireguard/wg0.conf
  wg-quick down wg0
  wg-quick up wg0
EOF


rm -f /tmp/publickey
rm -f /tmp/privatekey