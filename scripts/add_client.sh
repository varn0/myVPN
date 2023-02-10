#!/bin/bash

set -eou pipefail


wg_client=${1:?"set client last octet"}
arg2=${2:-"--local-client"}
arg3=${3:-"--local-server"}
public_name="$PUBLIC_NAME"
public_ip="$PUBLIC_IP"


if [ "$arg3" == "--local-server" ]; then
  echo "copying local config"
  sudo cp /etc/wireguard/wg0.conf /tmp/wg0.conf
  sudo cp /etc/wireguard/publickey /tmp/publickey
else
  echo "copying remote config"
  ssh ubuntu@$public_name sudo cp /etc/wireguard/wg0.conf /home/ubuntu
  ssh ubuntu@$public_name sudo cp /etc/wireguard/publickey /home/ubuntu
  scp ubuntu@$public_name:/home/ubuntu/publickey /tmp/publickey
  scp ubuntu@$public_name:/home/ubuntu/wg0.conf /tmp/wg0.conf
  ssh ubuntu@$public_name sudo rm -f /home/ubuntu/wg0.conf
  ssh ubuntu@$public_name sudo rm -f /home/ubuntu/publickey
fi

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
Endpoint = $public_ip:65443
PersistentKeepalive=25
EOF

# if second arg is local send to /etc/wireguard/wg0.conf else copy in current dir
if [ "$arg2" == "--local-client" ]; then
  sudo cp wg0.conf /etc/wireguard/wg0.conf
  rm -f ../wg0.conf
else
  qrencode -t ansiutf8 < wg0.conf
fi

cat << EOF >> /tmp/wg0.conf
[Peer]
PublicKey = $wg_client_pubkey
AllowedIPs = $wg_client_ip
PresharedKey = $wg_client_presharedkey
EOF

if [ "$arg3" == "--local-server" ]; then
  sudo wg-quick down wg0
  sudo wg-quick up wg0
else
  # upload new server configuration and restart wireguard
  ssh ubuntu@$public_name rm -f /home/ubuntu/wg0.conf
  scp /tmp/wg0.conf ubuntu@$public_name:/home/ubuntu/wg0.conf
  ssh ubuntu@$public_name sudo cp /home/ubuntu/wg0.conf /etc/wireguard/wg0.conf
  ssh ubuntu@$public_name "sudo wg-quick down wg0 && sudo wg-quick up wg0"
fi


rm -f /tmp/wg0.conf
rm -f /tmp/publickey
rm -f /tmp/privatekey