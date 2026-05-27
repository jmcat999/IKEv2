# IKEv2/IPSec MSCHAPv2 Docker

这是一个基于 Debian + strongSwan 的 Docker 项目，用于部署安卓系统原生支持的：

```text
IKEv2/IPSec MSCHAPv2
```

适合你的目录结构：

```text
/vol1/1000/docker/ikev2
├── ssl
│   ├── cat66.cn.key
│   └── cat66.cn.pem
├── Dockerfile
├── docker-compose.yml
├── install.sh
└── config
    ├── strongswan.conf
    ├── swanctl.conf.template
    └── start.sh
```

## 前提

宿主机必须支持 Linux XFRM/IPsec，并且已经加载模块：

```bash
modprobe xfrm_user
modprobe xfrm_interface
modprobe esp4
modprobe esp6
modprobe xfrm_algo

ip xfrm state
ip xfrm policy
```

`ip xfrm state` 和 `ip xfrm policy` 不报错即可。部分内核没有启用 `CONFIG_XFRM_STATISTICS`，所以 `/proc/net/xfrm_stat` 不存在也不一定有问题。

## 一键安装

在 FnNas 宿主机执行：

```bash
mkdir -p /vol1/1000/docker/ikev2
cd /vol1/1000/docker/ikev2

git clone https://github.com/jmcat999/IKEv2.git .
```

把证书放到：

```text
/vol1/1000/docker/ikev2/ssl/cat66.cn.key
/vol1/1000/docker/ikev2/ssl/cat66.cn.pem
```

编辑 `.env`：

```bash
cp .env.example .env
nano .env
```

至少修改：

```env
VPN_DOMAIN=cat66.cn
VPN_USER=2654603465
VPN_PASSWORD=ChangeThisPassword123!
```

启动：

```bash
chmod +x install.sh
./install.sh
```

## 安卓填写

```text
类型：IKEv2/IPSec MSCHAPv2
服务器地址：cat66.cn
IPSec 标识符：cat66.cn
用户名：2654603465
密码：你在 .env 设置的 VPN_PASSWORD
```

注意：服务器地址和 IPSec 标识符必须与证书域名一致，不要填写 IP。

## 端口

上级路由器需要转发到 FnNas：

```text
UDP 500
UDP 4500
```

## 查看日志

```bash
docker logs -f ikev2-mschapv2
```

## 查看连接

```bash
docker exec -it ikev2-mschapv2 swanctl --list-conns
docker exec -it ikev2-mschapv2 swanctl --list-sas
```

## 停止

```bash
docker compose down
```

## 常见问题

### 容器日志出现 unable to create netlink socket

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

### 安卓提示认证失败

检查：

1. 服务器地址是否等于证书域名。
2. IPSec 标识符是否等于证书域名。
3. 用户名密码是否正确。
4. 证书是否包含对应 SAN，例如 `DNS:cat66.cn`。

### 能连上但不能上网

检查宿主机 IPv4 转发和 NAT：

```bash
sysctl net.ipv4.ip_forward
iptables -t nat -S | grep 10.66
```
