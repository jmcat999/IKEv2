#!/bin/bash
set -e

VPN_MODE="${VPN_MODE:-nat}"
VPN_DOMAIN="${VPN_DOMAIN:?缺少 VPN_DOMAIN}"
VPN_USER="${VPN_USER:?缺少 VPN_USER}"
VPN_PASSWORD="${VPN_PASSWORD:?缺少 VPN_PASSWORD}"

# 从 IPv4/CIDR 或 IPv4 范围取第一个 IP。
# 例如：192.168.0.240/28 -> 192.168.0.240
# 例如：192.168.0.180-192.168.0.200 -> 192.168.0.180
pool_first_ip() {
    local pool="$1"
    pool="${pool%%/*}"
    pool="${pool%%-*}"
    echo "$pool"
}

# 从 IPv4/CIDR 或 IPv4 范围自动推导 /24 局域网。
# 例如：192.168.0.240/28 -> 192.168.0.0/24
# 例如：192.168.0.180-192.168.0.200 -> 192.168.0.0/24
derive_ipv4_lan24() {
    local ip
    ip="$(pool_first_ip "$1")"
    IFS='.' read -r a b c d <<EOF
$ip
EOF
    if [ -z "${a:-}" ] || [ -z "${b:-}" ] || [ -z "${c:-}" ] || [ -z "${d:-}" ]; then
        return 1
    fi
    echo "$a.$b.$c.0/24"
}

# 从 IPv4/CIDR 或 IPv4 范围自动推导网关 DNS。
# 例如：192.168.0.240/28 -> 192.168.0.1
# 例如：192.168.0.180-192.168.0.200 -> 192.168.0.1
derive_ipv4_gateway() {
    local ip
    ip="$(pool_first_ip "$1")"
    IFS='.' read -r a b c d <<EOF
$ip
EOF
    if [ -z "${a:-}" ] || [ -z "${b:-}" ] || [ -z "${c:-}" ] || [ -z "${d:-}" ]; then
        return 1
    fi
    echo "$a.$b.$c.1"
}

# strongSwan 支持 192.168.0.180-192.168.0.200 地址池，iptables 不支持这种写法。
# 这里把地址池转换为 iptables 能接受的 match 参数。
ipt_src_pool_args() {
    local pool="$1"
    if echo "$pool" | grep -q '-'; then
        echo "-m iprange --src-range $pool"
    else
        echo "-s $pool"
    fi
}

ipt_dst_pool_args() {
    local pool="$1"
    if echo "$pool" | grep -q '-'; then
        echo "-m iprange --dst-range $pool"
    else
        echo "-d $pool"
    fi
}

iptables_rule_ensure() {
    local table=""
    if [ "$1" = "-t" ]; then
        table="-t $2"
        shift 2
    fi

    # shellcheck disable=SC2086
    iptables $table -C "$@" 2>/dev/null || iptables $table -A "$@"
}

case "$VPN_MODE" in
    nat)
        # NAT 模式独立配置。可以和 Proxy ARP 配置同时存在。
        VPN_POOL="${NAT_VPN_POOL:-${VPN_POOL:-10.66.0.0/24}}"
        VPN_DNS1="${NAT_DNS1:-${VPN_DNS1:-1.1.1.1}}"
        VPN_DNS2="${NAT_DNS2:-${VPN_DNS2:-8.8.8.8}}"
        VPN_LOCAL_TS="${NAT_LOCAL_TS:-${VPN_LOCAL_TS:-0.0.0.0/0}}"
        LAN_SUBNET="${LAN_SUBNET:-}"
        ;;
    proxyarp)
        # Proxy ARP 模式独立配置。通常只需要填写 PROXYARP_VPN_POOL。
        VPN_POOL="${PROXYARP_VPN_POOL:-${VPN_POOL:-192.168.0.240/28}}"
        AUTO_LAN_SUBNET="$(derive_ipv4_lan24 "$VPN_POOL" || true)"
        AUTO_LAN_DNS="$(derive_ipv4_gateway "$VPN_POOL" || true)"
        LAN_SUBNET="${PROXYARP_LAN_SUBNET:-${LAN_SUBNET:-${AUTO_LAN_SUBNET}}}"
        if [ -z "$LAN_SUBNET" ]; then
            echo "错误: 无法从 PROXYARP_VPN_POOL=$VPN_POOL 自动推导 LAN_SUBNET，请手动设置 PROXYARP_LAN_SUBNET"
            exit 1
        fi
        VPN_LOCAL_TS="${PROXYARP_LOCAL_TS:-${VPN_LOCAL_TS:-$LAN_SUBNET}}"
        VPN_DNS1="${PROXYARP_DNS1:-${VPN_DNS1:-${AUTO_LAN_DNS:-1.1.1.1}}}"
        VPN_DNS2="${PROXYARP_DNS2:-${VPN_DNS2:-1.1.1.1}}"
        ;;
    *)
        echo "错误: 不支持的 VPN_MODE=$VPN_MODE，只能是 nat 或 proxyarp"
        exit 1
        ;;
esac

export VPN_MODE VPN_DOMAIN VPN_USER VPN_PASSWORD VPN_POOL VPN_DNS1 VPN_DNS2 LAN_SUBNET VPN_LOCAL_TS

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

echo "运行模式: $VPN_MODE"
echo "VPN_POOL: $VPN_POOL"
echo "VPN_DNS: $VPN_DNS1, $VPN_DNS2"
echo "VPN_LOCAL_TS: $VPN_LOCAL_TS"
if [ "$VPN_MODE" = "proxyarp" ]; then
    echo "LAN_SUBNET: $LAN_SUBNET"
fi

echo "证书链数量: $(grep -c 'BEGIN CERTIFICATE' /certs/cert.pem || true)"
echo "服务器证书信息:"
openssl x509 -in /etc/swanctl/x509/cert.pem -noout -subject -issuer -dates -ext subjectAltName -ext extendedKeyUsage || true

MODE_TEMPLATE="/etc/cat66-ikev2/modes/$VPN_MODE/swanctl.conf.template"
LEGACY_TEMPLATE="/etc/swanctl/swanctl.conf.template"

if [ -f "$MODE_TEMPLATE" ]; then
    echo "使用模式配置: $MODE_TEMPLATE"
    envsubst < "$MODE_TEMPLATE" > /etc/swanctl/swanctl.conf
elif [ -f "$LEGACY_TEMPLATE" ]; then
    echo "警告: 未找到 $MODE_TEMPLATE，回退到旧模板 $LEGACY_TEMPLATE"
    envsubst < "$LEGACY_TEMPLATE" > /etc/swanctl/swanctl.conf
else
    echo "错误: 找不到 swanctl 配置模板"
    exit 1
fi

echo "关键 swanctl 配置:"
grep -E 'send_cert|send_certreq|mobike|fragmentation|proposals|eap_id|local_ts|dns =' /etc/swanctl/swanctl.conf || true

sysctl -w net.ipv4.ip_forward=1 || true

PUBLIC_IFACE=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)

if [ -z "$PUBLIC_IFACE" ]; then
    echo "无法识别公网网卡"
    ip route
    exit 1
fi

echo "公网网卡: $PUBLIC_IFACE"

VPN_POOL_SRC_ARGS="$(ipt_src_pool_args "$VPN_POOL")"
VPN_POOL_DST_ARGS="$(ipt_dst_pool_args "$VPN_POOL")"

# shellcheck disable=SC2086
iptables_rule_ensure FORWARD $VPN_POOL_SRC_ARGS -j ACCEPT
# shellcheck disable=SC2086
iptables_rule_ensure FORWARD $VPN_POOL_DST_ARGS -m state --state ESTABLISHED,RELATED -j ACCEPT

if [ "$VPN_MODE" = "nat" ]; then
    echo "应用 NAT 模式防火墙规则: VPN 客户端通过 $PUBLIC_IFACE 做 MASQUERADE 出口"
    # shellcheck disable=SC2086
    iptables_rule_ensure -t nat POSTROUTING $VPN_POOL_SRC_ARGS -o "$PUBLIC_IFACE" -j MASQUERADE
else
    echo "应用 Proxy ARP 模式防火墙规则: 不做 MASQUERADE，保留 VPN 客户端同网段源 IP"
    sysctl -w net.ipv4.conf.all.proxy_arp=1 || true
    sysctl -w "net.ipv4.conf.$PUBLIC_IFACE.proxy_arp=1" || true
    # shellcheck disable=SC2086
    iptables_rule_ensure FORWARD $VPN_POOL_SRC_ARGS -d "$LAN_SUBNET" -j ACCEPT
    # shellcheck disable=SC2086
    iptables_rule_ensure FORWARD -s "$LAN_SUBNET" $VPN_POOL_DST_ARGS -j ACCEPT
fi

ipsec start --nofork &
IPSEC_PID=$!

sleep 3

swanctl --load-all
swanctl --list-conns

wait $IPSEC_PID
