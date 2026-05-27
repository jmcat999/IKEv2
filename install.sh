#!/bin/bash
set -euo pipefail

BASE_DIR="/vol1/1000/docker/ikev2"
IMAGE_DEFAULT="ghcr.io/jmcat999/ikev2:latest"

cd "$(dirname "$0")"

mkdir -p ssl certs data

if [ ! -f .env ]; then
  cp .env.example .env
  echo "已生成 .env，请先编辑 VPN_DOMAIN、VPN_USER、VPN_PASSWORD 后重新运行。"
  echo "文件路径：$(pwd)/.env"
  exit 1
fi

if [ -f ssl/cat66.cn.pem ] && [ ! -f certs/cert.pem ]; then
  cp ssl/cat66.cn.pem certs/cert.pem
fi

if [ -f ssl/cat66.cn.key ] && [ ! -f certs/privkey.pem ]; then
  cp ssl/cat66.cn.key certs/privkey.pem
fi

if [ ! -f certs/cert.pem ]; then
  echo "错误：找不到证书 certs/cert.pem"
  echo "你可以把 cat66.cn.pem 放到 ssl/cat66.cn.pem，脚本会自动复制。"
  exit 1
fi

if [ ! -f certs/privkey.pem ]; then
  echo "错误：找不到私钥 certs/privkey.pem"
  echo "你可以把 cat66.cn.key 放到 ssl/cat66.cn.key，脚本会自动复制。"
  exit 1
fi

chmod 600 certs/privkey.pem || true

echo "加载宿主机 IPsec/XFRM 模块..."
modprobe xfrm_user || true
modprobe xfrm_interface || true
modprobe esp4 || true
modprobe esp6 || true
modprobe xfrm_algo || true

if ! ip xfrm state >/dev/null 2>&1; then
  echo "错误：宿主机 ip xfrm state 不可用。请先确认内核 XFRM/IPsec 模块可用。"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "错误：找不到 docker 命令。"
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "错误：找不到 docker compose。"
  exit 1
fi

echo "启动 IKEv2/IPSec MSCHAPv2 容器..."
$COMPOSE up -d --build

echo ""
echo "部署完成。"
echo ""
echo "查看日志："
echo "  docker logs -f ikev2-mschapv2"
echo ""
echo "查看连接："
echo "  docker exec -it ikev2-mschapv2 swanctl --list-sas"
echo ""
echo "安卓填写："
echo "  类型：IKEv2/IPSec MSCHAPv2"
echo "  服务器地址：.env 里的 VPN_DOMAIN"
echo "  IPSec 标识符：.env 里的 VPN_DOMAIN"
echo "  用户名：.env 里的 VPN_USER"
echo "  密码：.env 里的 VPN_PASSWORD"
