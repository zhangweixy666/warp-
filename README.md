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

> 仓库只包含脚本与源码归档，`warp` 二进制由安装脚本从 GitHub Releases 自动下载，无需手动准备。

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

> 配置保护：只要 `/etc/shadowquic/server-direct.yaml` 或 `server-socks.yaml` 任一文件存在（例如重新安装或被其他项目共用），脚本即视为已配置并跳过覆盖，只补齐缺失项，绝不改动已有文件。新生成的配置文件权限为 `600`（含凭据）。

## 🎛️ 分模式安装
不需要全部组件时，可以只装其中一项：
安装 WARP + ShadowQuic（完整，默认）：
```bash
sh /root/install-warp-alpine.sh all
```
只安装 WARP（SOCKS5 127.0.0.1:1080）：
```bash
sh /root/install-warp-alpine.sh warp
```
只安装 ShadowQuic（UDP 1443）：
```bash
sh /root/install-warp-alpine.sh quic
```
> 说明：不带参数与 `all` 等效；`warp` / `quic` 模式只安装对应组件和服务。
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

## ⚡ sing-box 快捷开关
安装好 sing-box 并配置节点后，可用快捷命令一键切换出站：
经 WARP 出站（等效 `singbox-warp-on`）：
```bash
sh /root/install-warp-alpine.sh sb-on
```
恢复直连出站（等效 `singbox-warp-off`）：
```bash
sh /root/install-warp-alpine.sh sb-off
```
重启 sing-box（等效 `singbox-restart`）：
```bash
sh /root/install-warp-alpine.sh sb-restart
```
已安装后也可直接运行：
```bash
sb-on
sb-off
sb-restart
```
> 快捷命令会先检查程序是否已安装，未安装时会提示先运行默认安装。

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
>
> 卸载保护：`remove` 会检查 `/etc/shadowquic/.managed-by-warp-go` 标记。若该标记不存在，说明配置可能由其他项目（如 suoha-plus）创建，脚本会拒绝卸载并退出，避免误删他人配置。确认要卸载时先执行：
> `touch /etc/shadowquic/.managed-by-warp-go`

## 📜 更新记录

### 2026-09-01 仓库卫生与许可证补全

- 变更：移除仓库工作区内的 `warp` 二进制副本（8.5 MB，与 Release `v1` 资产 md5 `888578cc6f56dfe94ad04625ca371e4b` 完全一致）。安装脚本本就通过 Release 下载该文件，仓库内副本属纯冗余，且存在与 Release 漂移的风险。
- 变更：源码包 `warp-go-src-20260726-fixed.tar.gz` 内补入 `LICENSE`（MIT 全文）与 `UPSTREAM-NOTES.md`（第三方依赖许可证清单），并为 4 个 `.go` 文件添加 SPDX 版权头，修复「仓库声明 MIT 但源码包内无许可证文件」的合规缺口。
- 变更：`.gitignore` 由 C/C++/CMake/vcpkg 模板改写为匹配本仓库形态的规则（备份与临时产物、日志、`/warp` 构建产物、Go 构建产物）。
- 文档：新增「源码与构建」章节，明确源码归档位置、构建命令与二进制分发方式；补全 License 章节。

### 2026-08-31 脚本修订（Alpine 真机两轮全量实测）

- 修复（高危）：移除脚本开头的 `set -o pipefail`。Alpine 的 busybox ash 支持 pipefail，它会让 `$(curl ... | grep ... | sed ...)` 中的管道失败直接触发 `set -e` 退出，导致 shadowquic 版本兜底与所有下载失败提示成为死代码——GitHub 不可达时脚本会静默消失。
- 修复（高危）：`find_warp` / `install_shadowquic` / `singbox-install` 三处下载统一改为 `curl -fsSL --connect-timeout 5 --max-time 120` 并用 `if ! ...; then` 显式捕获失败，输出明确的网络诊断提示；同时区分「连不上」与「内容不是 ELF」两类错误。
- 修复（高危）：`remove` 与 `switch-quic` / `quic-manager` 的 `stop_all` 不再 `pkill -f shadowquic`。同机若有其他项目（如 suoha-plus）共用 `/usr/local/bin/shadowquic` 二进制，旧逻辑会误杀其生产进程。现改为以 `/etc/shadowquic/.managed-by-warp-go` 标记判定归属，无标记则拒绝卸载、跳过 stop。
- 修复：`start_shadowquic_checked` 改用 `rc-service status` + `/run/shadowquic.pid` 精确判定，不再用 `pgrep -f 'shadowquic -c'` 把外部进程误判为本服务启动成功。
- 修复：`sb-on` / `sb-off` 写回 `config.json` 前先 `chmod 600`，避免 `jq > tmp` + `mv` 把含凭据的配置从 `600` 放宽为 `644`。
- 修复：`config_shadowquic` 的保护条件由「两份配置都存在」改为「任一存在」，半损坏状态不再被覆盖；新建配置统一 `chmod 600`。
- 修复：`setup_service` 与 shadowquic daemon 增加 `mkdir -p /var/log/shadowquic`，并将 `exec shadowquic` 改为绝对路径，避免日志目录缺失或服务环境 PATH 差异导致启动失败。
- 修复：`singbox-install` 在离线时不再静默退出，改为输出下载失败原因（此前 `singbox-manager` 等所有子命令在断网时都会无提示失败）。
- 修复：清理脚本中残留的一处无效 UTF-8 字节（第 226 行「配置创建完成」），此前会导致文件无法按 UTF-8 解码、终端输出乱码。
- 变更：shadowquic 下载失败兜底版本由 `v0.3.12` 更新为 `v0.3.13`（当前上游最新 release）。
- 新增：安装完成后输出默认凭据安全提示，提醒立即修改 `user1/changeme` 或在云安全组限制 UDP `1443` 来源。

### 2026-08-30 脚本修订

- 修复：`warpctl log` 日志路径错误，由不存在的 `/var/log/warp-go.log` 改为实际的 `/opt/warp-go/warp.log`。
- 修复：`config_shadowquic` 不再无条件覆盖 `/etc/shadowquic/server-direct.yaml` 与 `server-socks.yaml`；检测到两份配置已存在时自动跳过（仅补齐缺失的 `last-mode` 文件），避免破坏已有部署或被其他项目共用的配置。
- 修复：`remove` 卸载完成后的检查逻辑，文件未删净时改为输出警告而非误报成功。
- 修复：脚本内 2 处乱码文案（“已停止”“没有备份目录”）。

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

## 📦 源码与构建

`warp-go-src-20260726-fixed.tar.gz` 是 `warp` 可执行文件的完整 Go 源码归档，内含：

| 文件 | 说明 |
| --- | --- |
| `main.go`、`tunnel/`、`registration/` | MASQUE 隧道与 WARP 注册实现 |
| `docs/warp-masque-reverse-engineering.md` | 协议逆向分析文档 |
| `LICENSE` | MIT 许可证全文 |
| `UPSTREAM-NOTES.md` | 第三方依赖与许可证声明 |

自行构建：

```bash
tar xzf warp-go-src-20260726-fixed.tar.gz
cd warp-go
go build -trimpath -ldflags='-s -w' -o warp .
```

预编译的 `warp` 二进制通过 [GitHub Releases](https://github.com/zhangweixy666/warp-/releases) 分发，
安装脚本会自动下载（本地已有 `/usr/local/bin/warp`、`/root/warp`、`/home/warp`、`/tmp/warp` 时优先复用），
仓库工作区不再携带二进制副本。

## 📄 License

本仓库的 Shell 脚本与 `warp-go` 源码采用 **MIT License**（© 2026 zhangweixy666），
全文见 [`LICENSE`](LICENSE) 以及源码包内的 `warp-go/LICENSE`。

- 本项目是对 Cloudflare WARP MASQUE 协议的独立逆向实现，不包含 Cloudflare 官方源代码或二进制文件。
- Go 依赖以 module 方式引入，各自保留上游许可证（`quic-go`、`qpack` 为 MIT；`golang.org/x/*` 为 BSD-3-Clause），清单见源码包内 `UPSTREAM-NOTES.md`。
- 运行时下载的第三方组件（ShadowQuic、sing-box、cloudflared）分别受其自身许可证约束。
- 使用和再分发前，请确认符合所在地法律法规及 Cloudflare 服务条款。
