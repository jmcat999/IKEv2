#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

mkdir -p ssl config

if [ ! -f .env ]; then
  cp .env.example .env
  echo "已生成 .env，请先编辑 VPN_DOMAIN 和运行模式配置后重新运行。"
  echo "文件路径：$(pwd)/.env"
  exit 1
fi

if [ ! -f config/users.txt ]; then
  touch config/users.txt
  chmod 600 config/users.txt || true
  echo "已创建空的 config/users.txt，请先填写 VPN 账号和密码后重新运行。"
  echo "格式：用户名:密码，每行一个账号。"
  echo "示例：user1:password1"
  echo "文件路径：$(pwd)/config/users.txt"
  exit 1
fi

read_env_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); sub(/\r$/, ""); print; exit }' .env
}

VPN_CERT_FILE="${VPN_CERT_FILE:-$(read_env_value VPN_CERT_FILE)}"
VPN_KEY_FILE="${VPN_KEY_FILE:-$(read_env_value VPN_KEY_FILE)}"
VPN_CERT_FILE="${VPN_CERT_FILE:-server.crt}"
VPN_KEY_FILE="${VPN_KEY_FILE:-server.key}"

if [ ! -f "ssl/$VPN_CERT_FILE" ]; then
  echo "错误：找不到证书 ssl/$VPN_CERT_FILE"
  echo "请把完整证书链放到 ssl/ 目录，并在 .env 中设置 VPN_CERT_FILE。"
  exit 1
fi

if [ ! -f "ssl/$VPN_KEY_FILE" ]; then
  echo "错误：找不到私钥 ssl/$VPN_KEY_FILE"
  echo "请把私钥放到 ssl/ 目录，并在 .env 中设置 VPN_KEY_FILE。"
  exit 1
fi

chmod 600 "ssl/$VPN_KEY_FILE" || true
chmod 600 config/users.txt || true

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

if ! docker compose version >/dev/null 2>&1; then
  echo "错误：找不到 docker compose。"
  exit 1
fi

echo "启动 IKEv2/IPSec MSCHAPv2 容器..."
docker compose up -d --build

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
echo "  用户名：config/users.txt 里的用户名"
echo "  密码：config/users.txt 对应用户的密码"
