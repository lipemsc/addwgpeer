# addwgpeer
Simple script to add a Wireguard peer to a tunnel with saveconfig on

## Installation

```sh
sudo wget -O /usr/local/bin/addwgpeer https://github.com/lipemsc/addwgpeer/raw/refs/heads/main/addwgpeer.sh
sudo chmod +x /usr/local/bin/addwgpeer
```

## Usage

```sh
sudo sh addwgpeer.sh [wireguard-interface] [client-ip] [dns-server] [endpoint]
```
