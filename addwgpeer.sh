#!/bin/bash
# This script adds a peer to a WireGuard server and generates a QR code for the client configuration.

print_help () {
    echo "Usage: $0 <wg interface> <client ip> <server endpoint> [OPTIONS]"
    echo "OPTIONS:"
    echo "  -h, --help          Show this help message"
    echo "  --dns <dns server>  Set the DNS server for the client"
    echo "  --allowed-ips <ip>  Set the allowed IPs for the client (default: 0.0.0.0/0,::/0)"
    echo "  --output <file>     Save the client configuration to a file"
    
}

print_wg_missing () {
    echo "WireGuard is not installed. Please install it."
}

WG_INTERFACE=$1

if [ $# -lt 4 ] || [ "$WG_INTERFACE" == "-h" ]; then
    print_help
    exit 1
fi

if ! command -v wg &> /dev/null ; then
    print_wg_missing
    exit 1
fi

if ! command -v wg-quick &> /dev/null ; then
    print_wg_missing
    exit 1
fi

if ! command -v qrencode &> /dev/null ; then
    echo "qrencode could not be found, please install it."
    exit 1
fi

for i in $(seq 4 $#); do
    j=$((i+1))
    # echo "$i = ${!i}"
    # echo "$(( $i+1 )) = ${!j}"
    
    if [ "${!i}" == "--dns" ]; then
        DNS_SERVER="${!j}"
        if [ -z "$DNS_SERVER" ]; then
            echo "Error: --dns option requires a DNS server address."
            exit 1
        fi
    fi

    if [ "${!i}" == "--allowed-ips" ]; then
        ALLOWED_IPS="${!j}"
        if [ -z "$ALLOWED_IPS" ]; then
            echo "Error: --allowed-ips option requires an IP address."
            exit 1
        fi
    fi

    if [ "${!i}" == "--output" ]; then
        OUTPUT_FILE="${!j}"
        if [ -z "$OUTPUT_FILE" ]; then
            echo "Error: --output option requires a file name."
            exit 1
        fi
    fi


done


if ! wg show $WG_INTERFACE &> /dev/null ; then
    echo "WireGuard interface $WG_INTERFACE does not exist."
    exit 1
fi


CLIENT_IP=$2
NO_OF_CLIENT_IPS=$(( $(echo $CLIENT_IP | grep -o ',' | wc -l)+1 ))
CLIENT_IPS_WO_CIDR=()

if [ $NO_OF_CLIENT_IPS -gt 0 ]; then
    for i in $(seq 1 $NO_OF_CLIENT_IPS); do
        ip=$(echo $CLIENT_IP | cut -d',' -f$i)
        ip_wo_cidr=$(echo $ip | cut -d'/' -f1)
        CLIENT_IPS_WO_CIDR+=($ip_wo_cidr)
    done
fi

fst=1
for i in ${CLIENT_IPS_WO_CIDR[*]}; do
    if [ $fst -eq 1 ]; then
        SERVER_ALLOWED_IPS=$i
        fst=0
    else
        SERVER_ALLOWED_IPS="$SERVER_ALLOWED_IPS,$i"
    fi
done

SERVER_ENDPOINT=$3

PRIVKEY=$(wg genkey)
PUBKEY=$(echo $PRIVKEY | wg pubkey)
SERVERPUBKEY=$(wg show $WG_INTERFACE public-key)

#echo $PRIVKEY
#echo $PUBKEY

if ! wg set $WG_INTERFACE peer $PUBKEY allowed-ips $SERVER_ALLOWED_IPS &> /dev/null ; then
    echo "Failed to add peer to WireGuard interface $WG_INTERFACE."
    exit 1
fi


echo "[Interface]
Address = $CLIENT_IP" > /tmp/wg-tmp

if [ -n "$DNS_SERVER" ]; then
    echo "DNS = $DNS_SERVER" >> /tmp/wg-tmp
fi

echo "PrivateKey = $PRIVKEY

[Peer]
PublicKey = $SERVERPUBKEY" >> /tmp/wg-tmp

if [ -n "$ALLOWED_IPS" ]; then
    echo "AllowedIPs = $ALLOWED_IPS" >> /tmp/wg-tmp
else
    echo "AllowedIPs = 0.0.0.0/0,::/0" >> /tmp/wg-tmp
fi

echo "Endpoint = $SERVER_ENDPOINT" >> /tmp/wg-tmp

qrencode -t ansiutf8 < /tmp/wg-tmp

if [ -n "$OUTPUT_FILE" ]; then
    cp /tmp/wg-tmp $OUTPUT_FILE
    echo "Client configuration saved to $OUTPUT_FILE"
fi

rm /tmp/wg-tmp

wg-quick save $WG_INTERFACE
