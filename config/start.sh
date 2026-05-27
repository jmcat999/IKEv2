#!/bin/bash
set -e

modprobe xfrm_user || true
modprobe xfrm_interface || true
modprobe esp4 || true
modprobe esp6 || true
modprobe xfrm_algo || true

mkdir -p /etc/swanctl/x509
mkdir -p /etc/swanctl/private

cp /certs/cert.pem /etc/swanctl/x509/cert.pem
cp /certs/privkey.pem /etc/swanctl/private/privkey.pem
chmod 600 /etc/swanctl/private/privkey.pem

envsubst < /etc/swanctl/swanctl.conf.template > /etc/swanctl/swanctl.conf

sysctl -w net.ipv4.ip_forward=1 || true

PUBLIC_IFACE=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)

if [ -z "$PUBLIC_IFACE" ]; then
    echo "无法识别公网网卡"
    ip route
    exit 1
fi

echo "公网网卡: $PUBLIC_IFACE"

iptables -C FORWARD -s "$VPN_POOL" -j ACCEPT 2>/dev/null || iptables -A FORWARD -s "$VPN_POOL" -j ACCEPT
iptables -C FORWARD -d "$VPN_POOL" -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -A FORWARD -d "$VPN_POOL" -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -C POSTROUTING -s "$VPN_POOL" -o "$PUBLIC_IFACE" -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s "$VPN_POOL" -o "$PUBLIC_IFACE" -j MASQUERADE

ipsec start --nofork &
IPSEC_PID=$!

sleep 3

swanctl --load-all
swanctl --list-conns

wait $IPSEC_PID
