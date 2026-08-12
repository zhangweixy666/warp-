# 🚀 warp-go + shadowquic 一键部署

## 📖 项目简介

Alpine Linux x86_64 上一键部署 WARP 出口代理和 ShadowQuic 隐蔽隧道。

## ✨ 核心特性

🛡️ **WARP 加速** — 基于 warp-go 提供 SOCKS5 代理
📊 **管理面板** — 内置 quic-manager 交互面板
🛠️ **一键部署** — 自动下载二进制、注册 WARP、创建服务
🔄 **出站切换** — ShadowQuic 支持直连 / SOCKS5 双模式
⚡ **性能优化** — 支持 BBR、GSO、MTU 探测、Zero-RTT
🔋 **自动保活** — crontab 守护进程

## 💡 快速部署

```bash
wget -O- https://raw.githubusercontent.com/zhangweixy666/warp-/main/install-warp-alpine.sh | sh
```

## 📋 管理命令

| 命令 | 说明 |
|------|------|
| `warpctl status` | WARP 运行状态和出口 IP |
| `warpctl restart` | 重启 WARP |
| `warpctl ip` | 出口 IP |
| `warpctl log` | WARP 日志 |
| `quic-manager` | ShadowQuic 交互管理面板 |
| `switch-quic direct` | 切换到直连出站 |
| `switch-quic socks` | 切换到 SOCKS5 出站 |
| `switch-quic status` | ShadowQuic 状态 |
| `switch-quic log` | ShadowQuic 日志 |
| `switch-quic restart` | 重启 ShadowQuic |

## 🔧 高级用法

### 接入 sing-box

```bash
sh install-warp-alpine.sh sb-on   # 全流量走 WARP
sh install-warp-alpine.sh sb-off  # 恢复直连
```

## 🔑 配置说明

| 项目 | 默认值 | 说明 |
|------|--------|------|
| WARP SOCKS5 | `127.0.0.1:1080` | 本地代理端口 |
| ShadowQuic 端口 | `1443` | QUIC 入站端口 |
| 默认用户 | `user1` | 连接用户名 |
| 默认密码 | `changeme` | 建议修改 |

## ⚠️ 注意

- 仅支持 **Alpine Linux x86_64**
- 需要 root 权限
- 安装后 WARP 和 ShadowQuic 设为开机自启

## ⭐ Star

[![Star](https://img.shields.io/github/stars/zhangweixy666/warp-)](https://github.com/zhangweixy666/warp-/stargazers)

## 🙏 鸣谢

- [warp-go](https://github.com/badafans/warp-go)
- [shadowquic](https://github.com/spongebob888/shadowquic)

## ⚠️ 免责声明

本项目仅供教育、科学研究及个人安全测试之目的。
