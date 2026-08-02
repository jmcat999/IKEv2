# SSL 证书目录

把 VPN 服务器证书和私钥放在本目录。

默认文件名：

```text
server.crt  # fullchain：服务器证书 + 中间证书
server.key  # 私钥
```

如果使用其他文件名，请在项目根目录的 `.env` 中设置：

```env
VPN_CERT_FILE=my-vpn.crt
VPN_KEY_FILE=my-vpn.key
```

真实证书和私钥会被 `.gitignore` 忽略，不要提交到 GitHub。
