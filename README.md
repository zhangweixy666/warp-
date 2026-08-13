# warp-go + ShadowQuic + sing-box

仅支持 **Alpine Linux x86_64/amd64**。

## 默认安装

默认只安装 WARP SOCKS5、ShadowQuic、OpenRC 服务、保活和管理命令。

```bash
curl -fsSL https://raw.githubusercontent.com/zhangweixy666/warp-/main/install-warp-alpine.sh -o /root/install-warp-alpine.sh
sh /root/install-warp-alpine.sh
```

## 管理命令

```bash
warp-manager
warpctl status
warpctl restart
warpctl ip
quic-manager
switch-quic direct
switch-quic socks
switch-quic status
switch-quic restart
```

默认端口：

| 项目 | 地址 |
|---|---|
| WARP SOCKS5 | `127.0.0.1:1080` |
| ShadowQuic | UDP `1443` |

## 可选 sing-box 模块

默认不会安装 sing-box。需要时执行：

```bash
sh /root/install-warp-alpine.sh singbox-install
singbox-manager
```

模块使用 sing-box 1.13.14 管理器，支持 VLESS+Reality、AnyTLS、TUIC、Hysteria2、VLESS/VMess+WS、证书和 Reality 密钥管理。

快捷命令：

```bash
singbox-install
singbox-manager
singbox-status
singbox-restart
singbox-backup
singbox-restore
singbox-warp-on
singbox-warp-off
singbox-remove
```

`singbox-warp-on/off` 会先校验配置，再通过 OpenRC 重启 sing-box，并在修改前创建时间戳备份；不会重启 WARP 或 ShadowQuic。

## 卸载

```bash
sh /root/install-warp-alpine.sh remove
singbox-remove
```

`singbox-remove` 只删除 sing-box 程序和服务，保留 `/etc/sing-box/` 下的配置、证书和备份。

## 注意

请修改 ShadowQuic 默认密码，并在云服务商安全组放行 UDP 1443。本项目仅供教育、研究和个人测试使用，请遵守所在地法律法规。
