# warp-go — Cloudflare WARP SOCKS5 代理

基于 MASQUE over QUIC/H3 协议的轻量级 WARP 客户端，无需 TUN 虚拟网卡，纯 SOCKS5 代理。

## 特点

- 🚀 **轻量** — 单二进制 8.5MB，运行内存 20-50MB
- ⚡ **高速** — MASQUE over QUIC/H3 多路复用，延迟 1.8ms
- 🔧 **免编译** — 下载即用，无需 Go 环境
- 🛡️ **稳定** — OpenRC 服务 + supervise-daemon 崩溃自动重启 + crontab 保活
- 🔌 **灵活** — 可随时接入或断开 sing-box / shadowquic（互不冲突，分开选择）

## 一键安装
wget -O- https://raw.githubusercontent.com/zhangweixy666/warp-/main/install-warp-alpine.sh | sh

warpctl status             查看运行状态（PID + 出口 IP）
warpctl restart            重启 warp-go
warpctl ip                 查看当前出口 IP
warpctl log                查看日志
# 生成 shadowquic WARP 配置
sh install-warp-alpine.sh sq-on

# 切换为直连
sh install-warp-alpine.sh sq-off
# 接入 sing-box（自动修改配置 + 切换路由，全部流量走 WARP）
sh install-warp-alpine.sh sb-on

# 断开 sing-box（恢复直连）
sh install-warp-alpine.sh sb-off

# 总结
# sh install-warp-alpine.sh             安装
# sh install-warp-alpine.sh remove      卸载
# sh install-warp-alpine.sh sb-on       接入 sing-box
# sh install-warp-alpine.sh sb-off      断开 sing-box
# sh install-warp-alpine.sh sq-on       接入 shadowquic
# sh install-warp-alpine.sh sq-off      断开 shadowquic
