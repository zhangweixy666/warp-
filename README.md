# 🚀 warp-go + shadowquic 一键部署

## 📖 项目简介

面向 **Alpine Linux x86_64** 的 WARP + ShadowQuic 一键部署脚本。
默认安装流程会下载并注册 WARP，下载 x86_64 版 ShadowQuic，创建直连/SOCKS5 双配置、OpenRC 服务和交互管理命令。

## ✨ 核心特性

- 🛡️ WARP SOCKS5 出口：`127.0.0.1:1080`
- 🚀 ShadowQuic QUIC 入站：UDP `1443`
- 🔄 直连 / SOCKS5 出站一键切换
- 🖥️ `warp-manager` 和 `quic-manager` 交互面板
- ⚡ BBR、GSO、MTU 探测、Zero-RTT
- 🔋 WARP 保活和 ShadowQuic 开机自启
- 🔌 可选接入 sing-box

## 💡 快速部署

```bash
curl -fsSL https://raw.githubusercontent.com/zhangweixy666/warp-/main/install-warp-alpine.sh \
  -o /root/install-warp-alpine.sh
sh /root/install-warp-alpine.sh
```

> 脚本只接受 Alpine Linux x86_64/amd64。其他系统或架构会直接退出。

## 📋 管理命令

| 命令 | 说明 |
|------|------|
| `warp-manager` | WARP + ShadowQuic + sing-box 总菜单 |
| `warpctl status` | WARP 状态和出口 IP |
| `warpctl restart` | 重启 WARP |
| `warpctl ip` | 查看 WARP 出口 IP |
| `warpctl log` | 查看 WARP 日志 |
| `quic-manager` | ShadowQuic 交互面板 |
| `switch-quic direct` | 直连出站 |
| `switch-quic socks` | SOCKS5 出站，走 WARP |
| `switch-quic status` | 查看 ShadowQuic 状态 |
| `switch-quic log` | 查看 ShadowQuic 日志 |
| `switch-quic restart` | 重启 ShadowQuic |
| `switch-quic stop` | 停止 ShadowQuic |

## 🔧 sing-box

安装完成且存在 `/etc/sing-box/config.json` 后：

```bash
sh /root/install-warp-alpine.sh sb-on   # 添加 WARP SOCKS5 出站并启用
sh /root/install-warp-alpine.sh sb-off  # 删除 WARP 出站并恢复 direct
```

也可以在 `warp-manager` 中选择 8/9。

## 🔑 默认配置

| 项目 | 默认值 |
|------|--------|
| WARP SOCKS5 | `127.0.0.1:1080` |
| ShadowQuic 端口 | `1443/UDP` |
| 用户名 | `user1` |
| 密码 | `changeme` |
| 伪装域名 | `www.apple.com` |

请在实际使用前修改 `/etc/shadowquic/server-direct.yaml` 和 `server-socks.yaml` 中的用户名、密码及相关参数。

## 🗑️ 卸载

```bash
sh /root/install-warp-alpine.sh remove
```

## ⚠️ 注意事项

- 仅支持 Alpine Linux x86_64/amd64，并需要 root 权限。
- 请确保 UDP `1443` 已在云服务商安全组和防火墙放行。
- 默认密码仅用于初始配置，部署后应立即修改。

## 🙏 鸣谢

- [warp-go](https://github.com/badafans/warp-go)
- [shadowquic](https://github.com/spongebob888/shadowquic)

## ⚠️ 免责声明

本项目仅供教育、科学研究及个人安全测试使用。使用者须遵守所在地法律法规，作者不对滥用或由此产生的损失负责。
