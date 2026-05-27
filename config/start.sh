#!/bin/bash
set -e

modprobe xfrm_user || true
modprobe xfrm_interface || true
modprobe esp4 || true
modprobe esp6 || true
modprobe xfrm_algo || true

mkdir -p /etc/swanctl/x509
mkdir -p /etc/swanctl/x509ca
mkdir -p /etc/swanctl/private

rm -f /etc/swanctl/x509/*.pem /etc/swanctl/x509ca/*.pem /etc/swanctl/private/*.pem

cp /certs/privkey.pem /etc/swanctl/private/privkey.pem
chmod 600 /etc/swanctl/private/privkey.pem

# cert.pem may be a fullchain file. swanctl expects the end-entity/server
# certificate under x509/ and CA/intermediate certificates under x509ca/.
# Split the PEM chain so Android/Windows clients can build the trust chain.
awk '
  /-----BEGIN CERTIFICATE-----/ { n++; file = (n == 1 ? "/etc/swanctl/x509/cert.pem" : sprintf("/etc/swanctl/x509ca/chain-%02d.pem", n - 1)) }
  { if (n > 0) print > file }
' /certs/cert.pem

if [ ! -s /etc/swanctl/x509/cert.pem ]; then
    echo "错误: 未能从 /certs/cert.pem 提取服务器证书"
    exit 1
fi

echo "证书链数量: $(grep -c 'BEGIN CERTIFICATE' /certs/cert.pem || true)"
echo "服务器证书信息:"
openssl x509 -in /etc/swanctl/x509/cert.pem -noout -subject -issuer -dates -ext subjectAltName -ext extendedKeyUsage || true

envsubst < /etc/swanctl/swanctl.conf.template > /etc/swanctl/swanctl.conf

echo "关键 swanctl 配置:"
grep -E 'send_cert|send_certreq|mobike|fragmentation|proposals|eap_id' /etc/swanctl/swanctl.conf || true

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
