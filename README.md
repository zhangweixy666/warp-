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

> 本 README 的命令均按“一个代码块一个命令”排列。GitHub 的复制按钮会复制当前代码块，不会把其他命令一起复制。

## ✨ 项目简介

这是一个面向 Alpine Linux 的轻量级网络服务部署脚本，默认安装 WARP SOCKS5 和 ShadowQuic，并提供 OpenRC 自启动、保活、管理面板与命令行管理工具。

sing-box 作为可选模块提供，需要时再安装，不改变默认 WARP + ShadowQuic 的部署流程。

> 仅支持 Alpine Linux `x86_64/amd64`。请在你拥有或获授权管理的服务器上使用。

## 🧩 功能概览

| 组件 | 作用 | 默认监听 |
|---|---|---|
| WARP | 提供本机 SOCKS5 出口 | `127.0.0.1:1080` |
| ShadowQuic | 提供 QUIC 服务，可选择直连或经 WARP 出站 | UDP `:1443` |
| sing-box | 可选的多协议节点服务 | 按节点配置决定 |

默认安装不会开放 WARP 的 `1080` 端口到公网。ShadowQuic 默认凭据为 `user1 / changeme`，部署后请立即修改，并在云安全组放行 UDP `1443`。

## ⚡ 快速开始

### 1. 下载并赋予执行权限

下载脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/zhangweixy666/warp-/main/install-warp-alpine.sh -o /root/install-warp-alpine.sh
```

赋予执行权限：

```bash
chmod +x /root/install-warp-alpine.sh
```

### 2. 默认安装 WARP + ShadowQuic

执行安装：

```bash
sh /root/install-warp-alpine.sh
```

安装完成后，默认服务为：

- WARP SOCKS5：`socks5://127.0.0.1:1080`
- ShadowQuic：UDP `1443`
- ShadowQuic 默认账号：`user1`
- ShadowQuic 默认密码：`changeme`

## 🧰 WARP 管理

查看 WARP 状态和出口 IP：

```bash
warpctl status
```

重启 WARP：

```bash
warpctl restart
```

只查看 WARP 出口 IP：

```bash
warpctl ip
```

查看 WARP 日志：

```bash
warpctl log
```

打开 WARP 交互式管理面板：

```bash
warp-manager
```

通过本机 SOCKS5 测试出口：

```bash
curl -x socks5h://127.0.0.1:1080 https://ipv4.icanhazip.com
```

## 🌐 ShadowQuic 管理

打开 ShadowQuic 管理面板：

```bash
quic-manager
```

切换到直连出站：

```bash
switch-quic direct
```

切换到经 WARP SOCKS5 出站：

```bash
switch-quic socks
```

查看 ShadowQuic 状态：

```bash
switch-quic status
```

重启 ShadowQuic：

```bash
switch-quic restart
```

停止 ShadowQuic：

```bash
switch-quic stop
```

查看监听端口：

```bash
ss -lntup
```

查看 UDP 监听：

```bash
ss -lunp
```

## 🧱 可选 sing-box 模块

### 1. 安装 sing-box

安装 sing-box 二进制和管理器：

```bash
sh /root/install-warp-alpine.sh singbox-install
```

> 这一步只安装程序，不会自动创建节点配置。

### 2. 创建第一个节点

交互式配置 VLESS + WebSocket：

```bash
singbox-manager vless-ws
```

也可以打开完整管理菜单：

```bash
singbox-manager
```

进入菜单后选择“节点管理”，再选择需要的协议。

配置时请填写 VPS 的公网 IP 或域名。不要填写以下回环地址：

- `127.0.0.1`
- `127.0.1.1`
- `localhost`

回环地址只能在服务器本机使用，外部客户端无法通过它连接。

### 3. 查看 sing-box 状态

查看版本、进程、配置校验和服务状态：

```bash
singbox-status
```

单独检查配置文件：

```bash
sing-box check -c /etc/sing-box/config.json
```

查看 OpenRC 服务状态：

```bash
rc-service sing-box status
```

重启 sing-box：

```bash
singbox-restart
```

查看 sing-box 日志：

```bash
tail -n 100 /var/log/sing-box/sing-box.log
```

### 4. sing-box 支持的节点类型

管理器支持以下常见节点类型：

- VLESS + Reality
- AnyTLS
- TUIC
- Hysteria2
- VLESS + WebSocket
- VMess + WebSocket
- 自签证书
- Cloudflare ACME 证书

> 默认测试使用的是 VLESS + WebSocket 无 TLS 配置，适合验证服务和配置流程，不建议直接作为生产公网节点使用。正式部署建议使用 Reality、TLS 或反向代理，并设置安全的认证参数。

## 🔁 sing-box 接入或恢复 WARP

### 将 sing-box 出站切换到 WARP

前提：`/etc/sing-box/config.json` 已存在，并且至少配置了一个 sing-box 节点。

```bash
singbox-warp-on
```

执行后会：

1. 自动备份当前配置。
2. 添加本机 WARP SOCKS5 出站。
3. 将默认路由切换为 `warp`。
4. 检查配置。
5. 重启 sing-box。

确认默认路由：

```bash
jq -r '.route.final' /etc/sing-box/config.json
```

正常结果应为：

```text
warp
```

### 恢复直连出站

```bash
singbox-warp-off
```

确认已经恢复直连：

```bash
jq -r '.route.final' /etc/sing-box/config.json
```

正常结果应为：

```text
direct
```

WARP 开关只会重启 sing-box，不会重启 ShadowQuic。

## 💾 备份与恢复

备份 sing-box 配置：

```bash
singbox-backup
```

恢复最近一次配置备份：

```bash
singbox-restore
```

配置和备份位置：

```text
/etc/sing-box/config.json
/etc/sing-box/backups/
/etc/sing-box/certs/
/etc/sing-box/reality/
/etc/shadowquic/
/opt/warp-go/
```

## 🔍 常用排障

查看 WARP 状态：

```bash
warpctl status
```

查看 ShadowQuic 状态：

```bash
rc-service shadowquic status
```

查看 sing-box 状态：

```bash
singbox-status
```

检查所有监听端口：

```bash
ss -lntup
```

检查 UDP 监听端口：

```bash
ss -lunp
```

查看 ShadowQuic 日志：

```bash
tail -n 100 /var/log/shadowquic-service.log
```

查看 sing-box 日志：

```bash
tail -n 100 /var/log/sing-box/sing-box.log
```

常见检查项：

- 云安全组是否放行 UDP `1443`
- WARP 是否监听 `127.0.0.1:1080`
- sing-box 配置是否通过 `sing-box check`
- sing-box 节点地址是否填写公网 IP 或域名
- 节点端口是否被其他程序占用
- 修改配置后是否重启对应服务
- 是否已经修改 ShadowQuic 默认密码

## 🧹 卸载

卸载 WARP 和 ShadowQuic：

```bash
sh /root/install-warp-alpine.sh remove
```

卸载 sing-box 程序和服务：

```bash
singbox-remove
```

> `singbox-remove` 会保留 `/etc/sing-box/` 下的配置、证书和备份，便于后续恢复。

## ⚠️ 使用须知

- 仅支持 Alpine Linux `x86_64/amd64`。
- 建议安装前创建 VPS 快照。
- 请立即修改 ShadowQuic 默认密码。
- 不要把 WARP SOCKS5 管理端口直接暴露到公网。
- 对外提供 sing-box 节点时，请使用强密码、有效证书和合适的安全策略。
- 请遵守所在地法律法规及云服务商条款。
- 本项目仅供学习、研究和个人测试使用。

## 🙏 致谢

- [Cloudflare WARP](https://www.cloudflare.com/products/warp/)
- [sing-box](https://github.com/SagerNet/sing-box)
- [ShadowQuic](https://github.com/spongebob888/shadowquic)
- [edgetunnel](https://github.com/cmliu/edgetunnel)

## 📄 License

请在使用和再分发前确认相关上游项目的许可证及条款。
