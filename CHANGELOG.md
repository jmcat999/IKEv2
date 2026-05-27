# Changelog

## v1.1.0 - Independent Mode Configs

新增两种独立运行模式：

### 新增

- 新增 `VPN_MODE=nat` 默认模式。
- 新增 `VPN_MODE=proxyarp` 高级同网段模式。
- 新增独立配置目录：
  - `config/modes/nat/swanctl.conf.template`
  - `config/modes/proxyarp/swanctl.conf.template`
- `start.sh` 会根据 `VPN_MODE` 自动选择对应配置。
- NAT 模式自动启用 MASQUERADE。
- Proxy ARP 模式不做 MASQUERADE，并开启 Proxy ARP。
- 新增 `LAN_SUBNET` 和 `VPN_LOCAL_TS` 环境变量。
- README 增加 NAT / Proxy ARP 两种模式教程。

### 说明

- NAT 模式推荐普通用户使用，默认 `VPN_POOL=10.66.0.0/24`。
- Proxy ARP 模式适合同网段 IP 需求，例如 `VPN_POOL=192.168.0.240/28`。
- Proxy ARP 模式必须避开主路由 DHCP 地址池和已有设备 IP。

## v1.0.0 - Official Release

正式可用版本。

### 已验证

- IKEv2 SA 可以成功建立。
- CHILD_SA 可以成功安装。
- Android/Windows IKEv2 EAP-MSCHAPv2 客户端可连接。
- VPN 客户端可以获得 `10.66.0.x` 地址。
- `swanctl --list-sas` 显示 `ESTABLISHED` 和 `INSTALLED`。
- 隧道存在真实 in/out 流量。

### 核心修复

- 安装并启用 `eap-mschapv2` 插件。
- 支持 Android/Windows 常见 IKE proposal。
- 支持 MODP 4096/2048，并保留 MODP 1024 兼容项。
- `send_cert = always`，服务端主动发送证书。
- `send_certreq = no`，不向客户端发送证书请求。
- 自动拆分 fullchain：
  - 服务器证书放入 `/etc/swanctl/x509/`
  - 中间证书放入 `/etc/swanctl/x509ca/`
- 启动时打印证书链数量、证书信息和关键 swanctl 配置，方便排查。

### 部署要求

- 宿主机必须支持 XFRM/IPsec。
- Docker 容器必须使用 host network。
- Docker 容器必须使用 privileged。
- `certs/cert.pem` 必须是 fullchain。
- `certs/privkey.pem` 必须与证书匹配。
