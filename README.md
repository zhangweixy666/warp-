# 🚀 warp-go + shadowquic 一键部署

## 📖 项目简介

warp-go + shadowquic 是一个基于 Alpine Linux 的边缘加速隧道部署方案。它能够快速部署 WARP 出口代理和 ShadowQuic 隐蔽隧道，并提供强大的管理面板和灵活的出站切换能力。

## ✨ 核心特性

🛡️ **WARP 加速**：基于 warp-go 提供 SOCKS5 代理，支持 IPv4/IPv6 自动适配，出口 IP 全球优选。
📊 **管理面板**：内置交互式管理面板（warp-manager / quic-manager），支持实时状态查看、模式切换、日志追踪。
🛠️ **部署灵活**：一键安装脚本，自动识别架构（x86_64/arm64/armv7/armv6），自动下载对应版本。
🔄 **出站切换**：ShadowQuic 支持直连 / SOCKS5 双模式即时切换，无需重启服务。
⚡ **性能优化**：支持 BBR 拥塞控制、GSO 加速、MTU 探测、Zero-RTT 等高级特性。
🌐 **全端适配**：完美适配 sing-box、Clash、Shadowrocket 等主流客户端。
🔋 **自动保活**：内置 crontab 守护进程，服务异常自动拉起，开机自启。

## 💡 快速部署

### ⚙️ 一键安装

```bash
wget -O- https://raw.githubusercontent.com/zhangweixy666/warp-/main/install-warp-alpine.sh | sh
```

### 🖥️ 全能管理面板

```bash
warp-manager
```

## 📋 管理命令

| 命令 | 说明 |
|------|------|
| `warpctl status` | 查看 WARP 运行状态和出口 IP |
| `warpctl restart` | 重启 WARP |
| `warpctl ip` | 查看出口 IP |
| `warpctl log` | 查看 WARP 日志 |
| `quic-manager` | ShadowQuic 交互式管理面板 |
| `switch-quic direct` | 切换到直连出站 |
| `switch-quic socks` | 切换到 SOCKS5 出站（走 WARP） |
| `switch-quic status` | 查看 ShadowQuic 状态 |
| `switch-quic log` | 查看 ShadowQuic 日志 |
| `switch-quic restart` | 重启 ShadowQuic |

## 🔧 高级实用技巧

### 🎯 接入 sing-box

```bash
sh install-warp-alpine.sh sb-on     # 接入 WARP
sh install-warp-alpine.sh sb-off    # 断开 WARP
```

### 🔄 ShadowQuic 模式切换

```bash
switch-quic direct    # 直连出站
switch-quic socks     # SOCKS5 出站（走 WARP）
```

### 📝 修改用户密码

编辑对应配置文件后重启：

```bash
nano /etc/shadowquic/server-direct.yaml
nano /etc/shadowquic/server-socks.yaml
switch-quic restart
```

## 🔑 配置说明

| 项目 | 默认值 | 说明 |
|------|--------|------|
| WARP SOCKS5 | `127.0.0.1:1080` | WARP 本地 SOCKS5 代理端口 |
| ShadowQuic 端口 | `1443` | QUIC 入站端口（UDP） |
| 默认用户 | `user1` | ShadowQuic 连接用户名 |
| 默认密码 | `changeme` | ShadowQuic 连接密码（建议修改） |
| 伪装域名 | `www.apple.com` | TLS 伪装 SNI |

## ⭐ 项目热度

[![Star](https://img.shields.io/github/stars/zhangweixy666/warp-)](https://github.com/zhangweixy666/warp-/stargazers)

## 🙏 特别鸣谢

- [warp-go](https://github.com/badafans/warp-go) - WARP 客户端实现
- [shadowquic](https://github.com/spongebob888/shadowquic) - QUIC 隧道服务

## ⚠️ 免责声明

本项目仅供教育、科学研究及个人安全测试之目的。
使用者在下载或使用本项目代码时，必须严格遵守所在地区的法律法规。
作者对任何滥用本项目代码导致的行为或后果均不承担任何责任。
建议在测试完成后 24 小时内删除本项目相关部署。

如果您觉得项目对您有帮助，请给一个 Star 🌟，这是对我最大的鼓励！
