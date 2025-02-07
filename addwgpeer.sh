PRIVKEY=$(wg genkey)

PUBKEY=$(echo $PRIVKEY | wg pubkey)

SERVERPUBKEY=$(wg show $1 public-key)

#echo $PRIVKEY
#echo $PUBKEY

wg set $1 peer $PUBKEY allowed-ips $2

echo "
[Interface]
Address = $2
DNS = 1.1.1.1
PrivateKey = $PRIVKEY

[Peer]
PublicKey = $SERVERPUBKEY
AllowedIPs = 0.0.0.0/0
Endpoint = $3
" | qrencode -t utf8

