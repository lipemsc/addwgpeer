#!/bin/bash
# This script adds a peer to a WireGuard server and generates a QR code for the client configuration.

print_help () {
    echo "Usage: $0 <wg interface> <client ip> <server endpoint> [OPTIONS]"
    echo "OPTIONS:"
    echo "  -h, --help          Show this help message"
    echo "  --dns <dns server>  Set the DNS server for the client"
    echo "  --allowed-ips <ip>  Set the allowed IPs for the client"
    echo "  --output <file>     Save the client configuration to a file"
    
}

print_wg_missing () {
    echo "WireGuard is not installed. Please install it."
}


if [ $# -lt 4 ] || [ "$1" == "-h" ]; then
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

WG_INTERFACE=$1
CLIENT_IP=$2
SERVER_ENDPOINT=$3


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


if ! wg show $1 &> /dev/null ; then
    echo "WireGuard interface $1 does not exist."
    exit 1
fi


PRIVKEY=$(wg genkey)
PUBKEY=$(echo $PRIVKEY | wg pubkey)

SERVERPUBKEY=$(wg show $1 public-key)

#echo $PRIVKEY
#echo $PUBKEY

if ! wg set $1 peer $PUBKEY allowed-ips $2 &> /dev/null ; then
    echo "Failed to add peer to WireGuard interface $1."
    exit 1
fi


echo "[Interface]
Address = $2" > /tmp/wg-tmp

if [ -n "$DNS_SERVER" ]; then
    echo "DNS = $DNS_SERVER" >> /tmp/wg-tmp
fi

echo "PrivateKey = $PRIVKEY

[Peer]
PublicKey = $SERVERPUBKEY" >> /tmp/wg-tmp

if [ -n "$ALLOWED_IPS" ]; then
    echo "AllowedIPs = $ALLOWED_IPS" >> /tmp/wg-tmp
fi

echo "Endpoint = $3" >> /tmp/wg-tmp

qrencode -t ansiutf8 < /tmp/wg-tmp

if [ -n "$OUTPUT_FILE" ]; then
    cp /tmp/wg-tmp $OUTPUT_FILE
    echo "Client configuration saved to $OUTPUT_FILE"
fi

rm /tmp/wg-tmp

wg-quick save $1
