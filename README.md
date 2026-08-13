# 🚀 warp-go + ShadowQuic + sing-box

<p align="center">
  <b>Alpine Linux x86_64 上的 WARP、ShadowQuic 与 sing-box 一键部署和管理脚本</b>
</p>

<p align="center">
  <a href="https://github.com/zhangweixy666/warp-/blob/main/install-warp-alpine.sh">安装脚本</a>
  ·
  <a href="https://github.com/zhangweixy666/warp-/issues">问题反馈</a>
  ·
  <a href="https://github.com/zhangweixy666/warp-/commits/main/">更新记录</a>
</p>

## ✨ 项目简介

这是一个面向 Alpine Linux 的轻量级网络服务部署脚本，默认安装 WARP SOCKS5 和 ShadowQuic，并提供 OpenRC 自启动、保活、交互式管理面板与命令行管理工具。

sing-box 作为**可选模块**提供：需要时再安装，不改变默认部署流程，也不会在默认安装时覆盖用户已有配置。

> 仅支持 Alpine Linux `x86_64/amd64`。请在你拥有或获授权管理的服务器上使用。

## 🧩 功能特性

- **WARP SOCKS5**：本地监听 `127.0.0.1:1080`
- **ShadowQuic**：UDP `1443`，支持直连出站和 SOCKS5 出站
- **sing-box 1.13.14**：可选安装和管理
- **OpenRC 集成**：服务启动、停止、重启和开机自启
- **WARP 保活**：定时检查并自动拉起 WARP
- **配置保护**：sing-box 修改前自动生成时间戳备份
- **安全重载**：修改 sing-box 配置前执行 `sing-box check`
- **管理面板**：`warp-manager`、`quic-manager`
- **轻量部署**：不依赖 Docker，适合 Alpine VPS

## ⚡ 快速开始

### 1. 下载脚本

```bash
curl -fsSL https://raw.githubusercontent.com/zhangweixy666/warp-/main/install-warp-alpine.sh \
  -o /root/install-warp-alpine.sh
chmod +x /root/install-warp-alpine.sh
```

### 2. 默认安装

默认流程安装 WARP + ShadowQuic：

```bash
sh /root/install-warp-alpine.sh
```

安装完成后：

| 服务 | 默认监听 |
|---|---|
| WARP SOCKS5 | `127.0.0.1:1080` |
| ShadowQuic | UDP `:1443` |

ShadowQuic 默认凭据为 `user1 / changeme`，部署后请立即修改密码，并在云厂商安全组放行 UDP `1443`。

## 🧰 管理命令

### WARP

```bash
warpctl status
warpctl restart
warpctl ip
warpctl log
warp-manager
```

### ShadowQuic

```bash
quic-manager
switch-quic direct
switch-quic socks
switch-quic status
switch-quic restart
switch-quic stop
```

### 服务状态

```bash
rc-service sing-box status
rc-service shadowquic status
ss -lntup
```

## 🧱 可选 sing-box 模块

默认安装**不会安装 sing-box**。在默认部署完成后，按需执行：

```bash
sh /root/install-warp-alpine.sh singbox-install
```

安装模块只会安装 sing-box 二进制和管理器，不会自动创建节点配置。首次使用需要至少配置一个节点，例如：

```bash
# 交互式配置 VLESS + WebSocket
singbox-manager vless-ws

# 或打开菜单，按“节点管理”完成配置
singbox-manager
```

配置过程中请填写 VPS 的公网 IP 或域名，不要使用 `127.0.0.1`、`127.0.1.1` 等回环地址。配置完成后检查：

```bash
singbox-status
sing-box check -c /etc/sing-box/config.json
rc-service sing-box status
```

模块使用 sing-box `1.13.14`，上游管理器支持常见协议和能力，包括：

- VLESS + Reality
- AnyTLS
- TUIC
- Hysteria2
- VLESS/VMess + WebSocket
- 自签证书和 ACME 证书
- Reality 密钥管理

常用命令：

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

### 将 sing-box 出站接入 WARP

```bash
singbox-warp-on
```

该命令会：

1. 备份 `/etc/sing-box/config.json`
2. 添加 WARP SOCKS5 出站
3. 将路由默认出站切换为 `warp`
4. 执行配置校验
5. 通过 OpenRC 重启 sing-box

恢复直连：

```bash
singbox-warp-off
```

该命令会删除 WARP 出站、恢复 `direct`，并再次校验配置。WARP 开关不会重启 ShadowQuic。

> `singbox-warp-on/off` 要求 `/etc/sing-box/config.json` 已存在，且至少已经配置一个 sing-box 节点。每次切换前会自动备份当前配置到 `/etc/sing-box/backups/`。

## 🗂️ 配置与备份

主要路径：

```text
/etc/sing-box/config.json
/etc/sing-box/backups/
/etc/shadowquic/
/opt/warp-go/
```

手动备份：

```bash
singbox-backup
```

恢复最近一次 sing-box 配置备份：

```bash
singbox-restore
```

## 🔍 故障排查

```bash
singbox-status
singbox-restart
rc-service sing-box status
rc-service shadowquic status
tail -n 100 /var/log/sing-box/sing-box.log
tail -n 100 /var/log/shadowquic-service.log
ss -lntup
```

常见检查项：

- 云安全组是否放行 UDP `1443`
- sing-box 配置是否通过 `sing-box check`
- `127.0.0.1:1080` 是否由 WARP 监听
- `20008` 是否被其他程序占用
- 修改配置后是否执行了服务重启

## 🧹 卸载

卸载默认组件：

```bash
sh /root/install-warp-alpine.sh remove
```

卸载 sing-box 程序和服务：

```bash
singbox-remove
```

`singbox-remove` 会保留 `/etc/sing-box/` 下的配置、证书和备份，便于后续恢复。

## ⚠️ 使用须知

- 仅支持 Alpine Linux `x86_64/amd64`
- 建议先做好 VPS 快照或配置备份
- 请立即修改 ShadowQuic 默认密码
- 不要把管理端口直接暴露到公网
- 请遵守所在地法律法规及云服务商条款
- 本项目仅供学习、研究和个人测试使用

## 🙏 致谢

- [Cloudflare WARP](https://www.cloudflare.com/products/warp/)
- [sing-box](https://github.com/SagerNet/sing-box)
- [ShadowQuic](https://github.com/spongebob888/shadowquic)
- [edgetunnel](https://github.com/cmliu/edgetunnel)

## 📄 License

请在使用和再分发前确认相关上游项目的许可证及条款。
