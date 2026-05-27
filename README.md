# Cat66 IKEv2 Docker

正式版：`v1.1.0`

这是一个基于 **Debian + strongSwan + swanctl** 的 Docker IKEv2/IPSec 服务端项目，目标是部署安卓/Windows 原生可用的：

```text
IKEv2/IPSec MSCHAPv2
```

当前已验证：

```text
IKEv2 SA ESTABLISHED
CHILD_SA INSTALLED
TUNNEL-in-UDP
EAP-MSCHAPv2 用户认证成功
真实流量 in/out 正常
```

---

## 两种独立模式

项目现在支持两种互相独立的运行模式：

```text
nat       默认模式，VPN 客户端使用独立网段，例如 10.66.0.0/24，并通过 NAT 访问内网/外网。
proxyarp  高级模式，VPN 客户端使用局域网同网段 IP，例如 192.168.0.240/28，不做 NAT，通过 Proxy ARP 暴露给 LAN。
```

配置文件位置：

```text
config/modes/nat/swanctl.conf.template
config/modes/proxyarp/swanctl.conf.template
```

启动脚本会根据 `.env` 里的：

```env
VPN_MODE=nat
# 或
VPN_MODE=proxyarp
```

自动选择对应模式配置。

---

## 目录结构

推荐部署目录：

```text
/vol1/1000/docker/ikev2
├── certs
│   ├── cert.pem       # fullchain，服务器证书 + 中间证书
│   └── privkey.pem    # 私钥
├── ssl                # 可选，兼容旧文件名
│   ├── cat66.cn.key
│   └── cat66.cn.pem
├── config
│   ├── modes
│   │   ├── nat
│   │   │   └── swanctl.conf.template
│   │   └── proxyarp
│   │       └── swanctl.conf.template
│   ├── strongswan.conf
│   ├── swanctl.conf.template
│   └── start.sh
├── docker-compose.yml
├── install.sh
├── .env.example
└── README.md
```

证书要求：

```text
certs/cert.pem 必须是 fullchain
certs/privkey.pem 必须和证书匹配
证书 SAN 必须包含 VPN_DOMAIN，例如 DNS:cat66.cn
证书 EKU 需要包含 TLS Web Server Authentication
```

本项目启动脚本会自动把 fullchain 拆分为：

```text
服务器证书 -> /etc/swanctl/x509/cert.pem
中间证书 -> /etc/swanctl/x509ca/chain-01.pem
```

这是本项目正式版的关键修复点。

---

## 前提条件

宿主机必须支持 Linux XFRM/IPsec：

```bash
modprobe xfrm_user
modprobe xfrm_interface
modprobe esp4
modprobe esp6
modprobe xfrm_algo

ip xfrm state
ip xfrm policy
```

`ip xfrm state` 和 `ip xfrm policy` 不报错即可。

部分内核没有启用 `CONFIG_XFRM_STATISTICS`，所以 `/proc/net/xfrm_stat` 不存在不一定是问题。

---

## 一键安装

在 FnNas 宿主机执行：

```bash
mkdir -p /vol1/1000/docker/ikev2
cd /vol1/1000/docker/ikev2

git clone https://github.com/jmcat999/IKEv2.git .
```

复制配置：

```bash
cp .env.example .env
nano .env
```

默认 NAT 模式配置：

```env
VPN_MODE=nat
VPN_DOMAIN=cat66.cn
VPN_USER=2654603465
VPN_PASSWORD=ChangeThisPassword123!
VPN_POOL=10.66.0.0/24
VPN_DNS1=1.1.1.1
VPN_DNS2=8.8.8.8
LAN_SUBNET=192.168.0.0/24
```

放证书：

```text
/vol1/1000/docker/ikev2/certs/cert.pem
/vol1/1000/docker/ikev2/certs/privkey.pem
```

如果你仍然使用旧文件名，也可以放到：

```text
/vol1/1000/docker/ikev2/ssl/cat66.cn.pem
/vol1/1000/docker/ikev2/ssl/cat66.cn.key
```

启动：

```bash
chmod +x install.sh
./install.sh
```

---

## NAT 模式

适合普通远程访问，推荐默认使用。

`.env` 示例：

```env
VPN_MODE=nat
VPN_POOL=10.66.0.0/24
LAN_SUBNET=192.168.0.0/24
# VPN_LOCAL_TS=0.0.0.0/0
```

特点：

```text
VPN 客户端拿 10.66.0.x
容器自动做 MASQUERADE/NAT
不需要修改主路由静态路由
最稳定，不容易和局域网 DHCP 冲突
```

---

## Proxy ARP 同网段模式

高级模式，让 VPN 客户端拿局域网同网段 IP。

假设局域网是：

```text
路由器：192.168.0.1
FnNas：192.168.0.2
LAN：192.168.0.0/24
```

建议在主路由 DHCP 里预留一小段不分配，例如：

```text
192.168.0.240 - 192.168.0.254
```

`.env` 示例：

```env
VPN_MODE=proxyarp
VPN_POOL=192.168.0.240/28
LAN_SUBNET=192.168.0.0/24
# VPN_LOCAL_TS 默认等于 LAN_SUBNET
```

特点：

```text
VPN 客户端拿 192.168.0.240/28 里的地址
不做 MASQUERADE/NAT
宿主机开启 Proxy ARP
局域网设备可以看到 VPN 客户端同网段源 IP
```

安全要求：

```text
不要使用整个 192.168.0.0/24 作为 VPN_POOL
VPN_POOL 必须避开主路由 DHCP 地址池
VPN_POOL 必须避开已有设备 IP
如果客户端所在地网络也是 192.168.0.0/24，可能发生路由冲突
```

---

## 安卓配置

VPN 类型：

```text
IKEv2/IPSec MSCHAPv2
```

填写：

```text
服务器地址：cat66.cn
IPSec 标识符：cat66.cn
用户名：2654603465
密码：.env 里的 VPN_PASSWORD
```

注意：

```text
服务器地址和 IPSec 标识符必须和证书域名一致
不要填写 IP
不要选择 PSK
不要填写预共享密钥
```

---

## Windows 配置

建议用管理员 PowerShell 创建：

```powershell
$Name = "Cat66 IKEv2"
$Server = "cat66.cn"

Remove-VpnConnection -Name $Name -Force -ErrorAction SilentlyContinue

$Eap = New-EapConfiguration

Add-VpnConnection `
  -Name $Name `
  -ServerAddress $Server `
  -TunnelType Ikev2 `
  -AuthenticationMethod Eap `
  -EapConfigXmlStream $Eap.EapConfigXmlStream `
  -EncryptionLevel Required `
  -RememberCredential `
  -Force `
  -PassThru
```

可选：指定 IKEv2 算法：

```powershell
Set-VpnConnectionIPsecConfiguration `
  -ConnectionName "Cat66 IKEv2" `
  -AuthenticationTransformConstants SHA256128 `
  -CipherTransformConstants AES256 `
  -EncryptionMethod AES256 `
  -IntegrityCheckMethod SHA256 `
  -PfsGroup None `
  -DHGroup Group14 `
  -Force `
  -PassThru
```

---

## 端口转发

上级路由器需要把下面端口转发到 FnNas：

```text
UDP 500
UDP 4500
```

---

## 查看日志

```bash
docker logs -f ikev2-mschapv2
```

启动成功时应看到类似：

```text
运行模式: nat
VPN_POOL: 10.66.0.0/24
VPN_LOCAL_TS: 0.0.0.0/0
证书链数量: 2
loaded certificate 'CN=cat66.cn'
loaded certificate 'C=US, O=DigiCert Inc ...'
loaded EAP shared key with id 'eap-user'
loaded connection 'ikev2-mschapv2'
```

Proxy ARP 模式应看到：

```text
运行模式: proxyarp
VPN_POOL: 192.168.0.240/28
LAN_SUBNET: 192.168.0.0/24
应用 Proxy ARP 模式防火墙规则: 不做 MASQUERADE
```

---

## 查看在线连接

```bash
docker exec -it ikev2-mschapv2 swanctl --list-sas
```

成功连接时应看到：

```text
ikev2-mschapv2: ESTABLISHED, IKEv2
net: INSTALLED, TUNNEL-in-UDP
remote 10.66.0.x/32
in/out bytes 正常增长
```

Proxy ARP 模式则会看到：

```text
remote 192.168.0.24x/32
```

---

## 停止

```bash
docker compose down
```

---

## 更新

```bash
cd /vol1/1000/docker/ikev2

git pull

docker compose down
docker compose pull
docker compose up -d
```

---

## 常见问题

### 1. `unable to create netlink socket`

说明容器或宿主机无法访问 XFRM。检查：

```bash
modprobe xfrm_user
modprobe xfrm_interface
modprobe esp4
modprobe esp6
ip xfrm state
```

Docker 必须使用：

```yaml
network_mode: host
privileged: true
```

### 2. `no shared key found`

说明客户端选成了 PSK 模式。

请改成：

```text
IKEv2/IPSec MSCHAPv2
```

不要选：

```text
IKEv2/IPSec PSK
IPSec Xauth PSK
```

### 3. `loading EAP_MSCHAPV2 method failed`

说明镜像缺少或未加载 `eap-mschapv2` 插件。

正式版镜像已安装并启用：

```text
libstrongswan-eap-mschapv2.so
```

检查：

```bash
docker exec -it ikev2-mschapv2 sh -c 'find /usr/lib /lib -name "*mschap*" 2>/dev/null'
```

### 4. 连接卡在 `EAP/REQ/ID`

重点检查证书链。`cert.pem` 必须是 fullchain，且脚本会拆分为服务器证书和中间证书。

检查：

```bash
grep -c "BEGIN CERTIFICATE" certs/cert.pem
openssl x509 -in certs/cert.pem -noout -subject -issuer -dates -ext subjectAltName -ext extendedKeyUsage
```

### 5. NAT 模式能连接但不能上网

检查 IPv4 转发和 NAT：

```bash
sysctl net.ipv4.ip_forward
iptables -t nat -S | grep 10.66
```

### 6. Proxy ARP 模式同网段不通

检查：

```bash
cat /proc/sys/net/ipv4/conf/all/proxy_arp
ip neigh show
iptables -S FORWARD
```

同时确认：

```text
VPN_POOL 没有和 DHCP 地址池冲突
VPN_POOL 没有和已有设备 IP 冲突
客户端所在地网络没有和家里 LAN 网段重叠
```

---

## 已验证成功日志

成功连接后示例：

```text
ikev2-mschapv2: ESTABLISHED, IKEv2
remote 'cat66.cn' @ x.x.x.x EAP: '2654603465' [10.66.0.1]
net: INSTALLED, TUNNEL-in-UDP
in/out packets 正常增长
```
