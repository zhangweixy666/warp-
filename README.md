<div align="center">

<h1>🚀 warp-go + ShadowQuic + sing-box</h1>

<p><b>Alpine Linux x86_64 上的 WARP、ShadowQuic 与 sing-box 一键部署管理脚本</b></p>

<p>一套装完 · OpenRC 自启 · 崩溃保活 · 命令行 + 交互面板双管理</p>

[![Platform](https://img.shields.io/badge/platform-Alpine%20x86__64-0d597f?style=for-the-badge&logo=alpine-linux)](#-系统要求)
[![WARP](https://img.shields.io/badge/egress-Cloudflare%20WARP-f38020?style=for-the-badge)](https://www.cloudflare.com/products/warp/)
[![ShadowQuic](https://img.shields.io/badge/QUIC-ShadowQuic-8a2be2?style=for-the-badge)](https://github.com/spongebob888/shadowquic)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)

<p><b>WARP 出口 · QUIC 节点 · 多协议 sing-box，三件套一次到位</b></p>

[🚀 快速开始](#-快速开始)　·　[🧩 组件一览](#-组件一览)　·　[🎛 分模式安装](#-分模式安装)　·　[🧰 管理命令](#-管理命令)　·　[❓ 常见问题](#-常见问题)

</div>

---

## 🎯 这个项目解决什么

在 Alpine 上手动搭这套东西，麻烦点很集中：

| 麻烦点 | 这里的做法 |
|:---|:---|
| WARP 官方客户端在 Alpine 上不好装 | 用独立的 `warp-go` 实现，跑成 `127.0.0.1:1080` 的 SOCKS5 |
| 想要 QUIC 节点又不想买域名证书 | ShadowQuic + JLS SNI 伪装，UDP `1443`，无需域名 |
| 装完不知道怎么切「直连 / 走 WARP」 | `switch-quic direct` / `switch-quic socks` 一条命令切换 |
| 服务挂了没人管 | OpenRC 自启 + 崩溃自动重启 + 保活 |
| 和别的项目共用 `/etc/shadowquic` 相互踩踏 | 归属标记 `.managed-by-warp-go`，无标记**拒绝卸载**、也不乱杀进程 |
| 上游更新了想跟进，又怕生产被改坏 | ShadowQuic 自动跟随最新版 + SHA-256 校验 + 覆盖前备份；也可用环境变量钉死版本 |

> 💡 **默认最小可用**：不带参数就是 `WARP + ShadowQuic`，sing-box 是可选模块，不装不影响主流程。

---

## 🚀 快速开始

### 1. 下载安装脚本

```bash
curl -fsSL https://raw.githubusercontent.com/zhangweixy666/warp-/main/install-warp-alpine.sh -o /root/install-warp-alpine.sh
```

### 2. 赋予执行权限

```bash
chmod +x /root/install-warp-alpine.sh
```

### 3. 默认安装（WARP + ShadowQuic）

```bash
sh /root/install-warp-alpine.sh
```

装完默认就是这样：

| 组件 | 监听 | 凭据 |
|:---|:---|:---|
| WARP SOCKS5 | `127.0.0.1:1080` | 无（仅本机） |
| ShadowQuic | UDP `1443` | `user1` / `changeme` |

> ⚠️ **装完第一件事：改掉默认密码** `user1 / changeme`，并在云安全组放行 UDP `1443`。
> 🔒 WARP 的 `1080` 默认**只监听回环**，不要把它暴露到公网。
> 📦 `warp` 二进制由安装脚本从 GitHub Releases 自动下载，仓库不携带二进制副本。

---

## 📖 目录

- [🎯 这个项目解决什么](#-这个项目解决什么)
- [🚀 快速开始](#-快速开始)
- [🧩 组件一览](#-组件一览)
- [🎛 分模式安装](#-分模式安装)
- [🧰 管理命令](#-管理命令)
  - [WARP](#warp)
  - [ShadowQuic](#shadowquic)
  - [sing-box](#sing-box)
- [🏗 架构与数据流](#-架构与数据流)
- [💾 备份与恢复](#-备份与恢复)
- [🔐 版本管理与安全边界](#-版本管理与安全边界)
- [🔍 常用排障](#-常用排障)
- [🧹 卸载](#-卸载)
- [🧩 系统要求](#-系统要求)
- [❓ 常见问题](#-常见问题)
- [📜 更新记录](#-更新记录)
- [📦 源码与构建](#-源码与构建)
- [🙏 致谢与许可](#-致谢与许可)

---

## 🧩 组件一览

| 组件 | 作用 | 默认监听 | 是否默认安装 |
|:---|:---|:---|:---:|
| **WARP**（`warp-go`） | 提供本机 SOCKS5 出口，出口 IP 变为 Cloudflare WARP 的 IP | `127.0.0.1:1080` | ✅ |
| **ShadowQuic** | QUIC 代理服务，可选直连出站或经 WARP 出站 | UDP `:1443` | ✅ |
| **sing-box** | 可选的多协议节点服务（Reality / AnyTLS / TUIC / Hysteria2 / VLESS-WS / VMess-WS） | 按节点配置 | ❌ |

**三种典型用法**

```text
用法 A：只要干净出口
客户端 → WARP SOCKS5(127.0.0.1:1080) → 互联网

用法 B：要一个抗封锁的 QUIC 节点
客户端 → ShadowQuic(UDP 1443) → 直连出站 → 互联网

用法 C：QUIC 节点 + WARP 落地 IP
客户端 → ShadowQuic(UDP 1443) → WARP SOCKS5 → 互联网
```

> 用法 C 就是 `switch-quic socks` 干的事，常用于解锁或换落地 IP。

---

## 🎛 分模式安装

不需要全部组件时，可以只装其中一项：

```bash
sh /root/install-warp-alpine.sh all
```

```bash
sh /root/install-warp-alpine.sh warp
```

```bash
sh /root/install-warp-alpine.sh quic
```

| 参数 | 含义 |
|:---|:---|
| （无参数）/ `install` / `all` | WARP + ShadowQuic（默认） |
| `warp` | 只装 WARP SOCKS5 |
| `quic` | 只装 ShadowQuic |
| `remove` / `uninstall` | 卸载 |

---

## 🧰 管理命令

### WARP

```bash
warpctl status
```

```bash
warpctl restart
```

```bash
warpctl ip
```

```bash
warpctl log
```

打开交互式面板：

```bash
warp-manager
```

验证出口是否真的走了 WARP：

```bash
curl -x socks5h://127.0.0.1:1080 https://ipv4.icanhazip.com
```

### ShadowQuic

打开管理面板：

```bash
quic-manager
```

切换出站模式：

```bash
switch-quic direct
```

```bash
switch-quic socks
```

```bash
switch-quic status
```

```bash
switch-quic restart
```

```bash
switch-quic stop
```

看端口：

```bash
ss -lntup
```

```bash
ss -lunp
```

### sing-box

安装程序与管理器（不自动创建节点）：

```bash
sh /root/install-warp-alpine.sh singbox-install
```

创建第一个节点（交互式 VLESS + WebSocket）：

```bash
singbox-manager vless-ws
```

打开完整菜单：

```bash
singbox-manager
```

查看状态 / 重启 / 日志：

```bash
singbox-status
```

```bash
singbox-restart
```

```bash
tail -n 100 /var/log/sing-box/sing-box.log
```

校验配置：

```bash
sing-box check -c /etc/sing-box/config.json
```

**sing-box 出站快捷开关**

```bash
sb-on
```

```bash
sb-off
```

```bash
sb-restart
```

等价写法：

```bash
sh /root/install-warp-alpine.sh sb-on
```

> 📌 `sb-on` / `sb-off` 只重启 sing-box，**不会**重启 ShadowQuic。
> 📌 管理器脚本来自 [`-singbox1.3.x-vless-anytls`](https://github.com/zhangweixy666/-singbox1.3.x-vless-anytls)，默认跟随其 `main` 最新版；要钉死版本用 `SINGBOX_MANAGER_REF=<commit|tag|branch>`。

**支持的节点类型**

- VLESS + Reality
- AnyTLS
- TUIC
- Hysteria2
- VLESS + WebSocket
- VMess + WebSocket
- 自签证书 / Cloudflare ACME 证书

> ⚠️ 默认测试配置是 VLESS + WebSocket **无 TLS**，只适合验证流程，不建议直接当生产公网节点。正式部署请用 Reality、TLS 或反代，并设置强认证参数。

---

## 🏗 架构与数据流

```text
                       ┌─────────────────────────────┐
   客户端 ── UDP/QUIC ─▶│  ShadowQuic  UDP :1443      │
                       └───────────┬─────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
              direct 出站                  socks 出站
                    │                             │
                    │                   ┌─────────▼──────────┐
                    │                   │ WARP 127.0.0.1:1080│
                    │                   └─────────┬──────────┘
                    │                             │
                    └──────────────┬──────────────┘
                                   ▼
                                互联网
```

**文件位置**

```text
/etc/sing-box/config.json
/etc/sing-box/backups/
/etc/sing-box/certs/
/etc/sing-box/reality/
/etc/shadowquic/
/opt/warp-go/
```

---

## 💾 备份与恢复

```bash
singbox-backup
```

```bash
singbox-restore
```

> `singbox-remove` 会**保留** `/etc/sing-box/` 下的配置、证书和备份，方便后续恢复。

---

## 🔐 版本管理与安全边界

### ShadowQuic 版本策略

默认**自动跟随官方最新 release**：

- 安装前读取本地版本并与官方 tag 比对，同版本跳过（重复执行幂等）
- 版本号双通道获取：GitHub API 优先，失败回退 `releases/latest` 的 302 重定向（避免 API 限流）
- 下载后做 **SHA-256 完整性校验**（比对官方 release API 的 `digest`）
- 覆盖前备份旧二进制到 `/usr/local/bin/shadowquic.bak-<时间戳>`
- 覆盖后**回读版本号二次确认**，防止「替换成功但没生效」的假成功
- 服务在跑且确认归属本仓库时才自动重启；无法确认归属只提示，不擅自动别人的服务

**钉版本 / 强制重装**

```bash
SHADOWQUIC_VERSION=v0.3.13 sh /root/install-warp-alpine.sh quic
```

```bash
SHADOWQUIC_FORCE=1 sh /root/install-warp-alpine.sh quic
```

### 归属保护（重要）

同机上可能还有 `suoha-plus` 等其他项目在用 `/etc/shadowquic`。本项目的做法是：

- 只有存在 `/etc/shadowquic/.managed-by-warp-go` 标记时，才认为配置归自己管
- 无标记时 `remove` **拒绝卸载并退出**，`switch-quic stop` 也**不会** `pkill -f shadowquic`
- 因此不会出现「装个别的脚本，把正在跑的节点一起杀了」

确实要接管时，先显式认领：

```bash
touch /etc/shadowquic/.managed-by-warp-go
```

### 配置保护

只要 `/etc/shadowquic/server-direct.yaml` 或 `server-socks.yaml` **任一存在**（重装或被其他项目共用），脚本就视为「已配置」，只补齐缺失项，**绝不覆盖已有文件**。新生成的配置文件权限为 `600`（含凭据）。

---

## 🔍 常用排障

```bash
warpctl status
```

```bash
rc-service shadowquic status
```

```bash
singbox-status
```

```bash
ss -lntup
```

```bash
tail -n 100 /var/log/shadowquic-service.log
```

```bash
tail -n 100 /var/log/sing-box/sing-box.log
```

**逐项检查**

- [ ] 云安全组是否放行 UDP `1443`
- [ ] WARP 是否在 `127.0.0.1:1080` 监听
- [ ] `sing-box check` 是否通过
- [ ] sing-box 节点地址是否填的公网 IP / 域名（**不能填 `127.0.0.1`**）
- [ ] 端口是否被其他程序占用
- [ ] 改完配置有没有重启对应服务
- [ ] ShadowQuic 默认密码改了没有

---

## 🧹 卸载

```bash
sh /root/install-warp-alpine.sh remove
```

```bash
singbox-remove
```

> 🛡 **卸载保护**：`remove` 会检查 `/etc/shadowquic/.managed-by-warp-go` 标记。标记不存在说明配置可能由其他项目（如 suoha-plus）创建，脚本会拒绝卸载并退出，避免误删他人配置。

---

## 🧩 系统要求

| 项目 | 要求 |
|:---|:---|
| 系统 | **仅 Alpine Linux** |
| 架构 | **x86_64 / amd64** |
| 权限 | root |
| 依赖 | `curl`、`tar`、`jq`、`openrc`（Alpine 自带） |
| 网络 | 需能访问 GitHub Releases |

---

## ❓ 常见问题

<details>
<summary><b>为什么只支持 Alpine x86_64？</b></summary>

`warp-go` 的预编译二进制和 OpenRC 服务单元都是按 Alpine x86_64 交付的。Debian/Ubuntu 用户建议看 [suoha-plus](https://github.com/zhangweixy666/suoha-plus) 或 [dns-setup](https://github.com/zhangweixy666/dns-setup)。

</details>

<details>
<summary><b>装完连不上，先查什么？</b></summary>

按这个顺序：

1. `ss -lunp | grep 1443` —— 有没有真的在监听
2. 云安全组放行 UDP `1443` 了吗
3. `switch-quic status` 和 `rc-service shadowquic status`
4. `tail -n 100 /var/log/shadowquic-service.log`
5. 如果用的是 `socks` 模式，先确认 WARP 自己通：`curl -x socks5h://127.0.0.1:1080 https://ipv4.icanhazip.com`

</details>

<details>
<summary><b>`direct` 和 `socks` 出站到底差在哪？</b></summary>

- `direct`：ShadowQuic 直接用自己的公网 IP 出站，链路最短、延迟最低
- `socks`：ShadowQuic 把流量交给本机 WARP 的 SOCKS5，落地 IP 变成 Cloudflare WARP 的 IP，常用于解锁或换地区

切换只用一条命令，配置是两份 YAML 文件，随时可以切回去。

</details>

<details>
<summary><b>会不会把同机别的 shadowquic 杀掉？</b></summary>

不会。本项目用 `/etc/shadowquic/.managed-by-warp-go` 标记判定归属：

- 无标记 → 拒绝卸载、跳过停止
- `start` 时也用 `rc-service status` + `/run/shadowquic.pid` 精确判定，不用 `pgrep -f 'shadowquic -c'` 把外部进程误判成本服务

> 这条是踩过血坑改的：早期版本用 `pkill -f shadowquic`，同机其他项目（比如 suoha-plus）的生产进程会被一并杀掉。

</details>

<details>
<summary><b>ShadowQuic 自动更新会不会把生产搞坏？</b></summary>

有防护：

- 同版本跳过，不重复下载
- SHA-256 校验不过就**拒绝安装**
- 覆盖前自动备份旧二进制
- 覆盖后回读版本确认
- 只有确认归属本仓库时才重启服务

不想跟随上游就用 `SHADOWQUIC_VERSION=v0.3.13` 钉死。

</details>

<details>
<summary><b>sing-box 模块是必需的吗？</b></summary>

不是。默认只装 WARP + ShadowQuic。需要多协议节点时再执行 `sh /root/install-warp-alpine.sh singbox-install`，它只装程序和管理器，**不会自动创建节点配置**。

</details>

<details>
<summary><b>`singbox-remove` 会删我的配置吗？</b></summary>

不会。它会保留 `/etc/sing-box/` 下的 `config.json`、证书和 `backups/`，只卸载程序和服务。

</details>

<details>
<summary><b>为什么仓库里没有 `warp` 二进制？</b></summary>

因为它有 8.5 MB，且容易与 Release 资产漂移。现在统一从 GitHub Releases 下载，仓库只保留脚本与源码归档（`warp-go-src-*.tar.gz`）。

</details>

---

## 📜 更新记录

### 2026-10-01 — ShadowQuic 改为自动跟随官方最新版

- 🔄 `install_shadowquic` 不再「已安装就跳过」，改为拉取最新 release 并覆盖升级（0.3.12 → 0.4.0 真机实测通过）
- ✅ 同版本跳过，保持重复执行幂等
- 🔐 版本号双通道（API + 302 重定向），下载做 SHA-256 校验
- 💾 覆盖前备份旧二进制，覆盖后回读版本二次确认
- 🔧 新增 `SHADOWQUIC_VERSION` 钉版本、`SHADOWQUIC_FORCE=1` 强制重装
- 🩹 下载失败按 HTTP 状态码精确诊断（`404` = 版本不存在，其他才是网络问题）
- 🩹 断网时保留当前可用版本且命令不中断

<details>
<summary><b>📚 历史版本（点击展开）</b></summary>

<br>

**2026-09-01 — sing-box 管理器改为自动同步上游最新版**
`singbox-install` 不再钉固定 commit，改为跟随 `-singbox1.3.x-vless-anytls` 的 `main`；新增 `SINGBOX_MANAGER_REF` 可钉任意 commit/tag/分支；同步失败时区分「本地已有则继续」与「本地没有则报错」。

**2026-09-01 — 仓库卫生与许可证补全**
移除仓库内 8.5 MB 的 `warp` 二进制副本（与 Release 资产完全一致，纯冗余）；源码包补入 `LICENSE` 与 `UPSTREAM-NOTES.md`，4 个 `.go` 文件加 SPDX 头；`.gitignore` 改为匹配本仓库形态；新增「源码与构建」章节。

**2026-08-31 — Alpine 真机两轮全量实测**
移除 `set -o pipefail`（busybox ash 下会让 `$(curl | grep | sed)` 失败触发 `set -e`，导致所有下载失败提示变成死代码）；三处下载统一 `curl -fsSL` + 显式失败捕获；`remove` / `switch-quic` / `quic-manager` 不再 `pkill -f shadowquic`，改归属标记判定；`start_shadowquic_checked` 改用 `rc-service status` + pid 文件精确判定；`sb-on/off` 写回前 `chmod 600`；配置保护由「两份都存在」改为「任一存在」；补 `mkdir -p /var/log/shadowquic` 与绝对路径 `exec`；清理一处无效 UTF-8 字节；兜底版本升到 `v0.3.13`；安装完输出默认凭据安全提示。

**2026-08-30 — 脚本修订**
`warpctl log` 日志路径修正（`/opt/warp-go/warp.log`）；`config_shadowquic` 不再无条件覆盖已有配置；`remove` 未删净时改为警告而非误报成功；修 2 处乱码文案。

</details>

---

## 📦 源码与构建

`warp-go-src-20260726-fixed.tar.gz` 是 `warp` 可执行文件的完整 Go 源码归档：

| 文件 | 说明 |
|:---|:---|
| `main.go`、`tunnel/`、`registration/` | MASQUE 隧道与 WARP 注册实现 |
| `docs/warp-masque-reverse-engineering.md` | 协议逆向分析文档 |
| `LICENSE` | MIT 许可证全文 |
| `UPSTREAM-NOTES.md` | 第三方依赖与许可证声明 |

自行构建：

```bash
tar xzf warp-go-src-20260726-fixed.tar.gz
```

```bash
cd warp-go
```

```bash
go build -trimpath -ldflags='-s -w' -o warp .
```

预编译二进制通过 [GitHub Releases](https://github.com/zhangweixy666/warp-/releases) 分发。本地已有 `/usr/local/bin/warp`、`/root/warp`、`/home/warp`、`/tmp/warp` 时安装脚本会优先复用。

---

## 🙏 致谢与许可

- [Cloudflare WARP](https://www.cloudflare.com/products/warp/)
- [sing-box](https://github.com/SagerNet/sing-box)
- [ShadowQuic](https://github.com/spongebob888/shadowquic)
- [edgetunnel](https://github.com/cmliu/edgetunnel)

**许可**：MIT（© 2026 zhangweixy666）

- 本项目是对 Cloudflare WARP MASQUE 协议的独立逆向实现，**不包含** Cloudflare 官方源代码或二进制
- Go 依赖各自保留上游许可证（`quic-go`、`qpack` 为 MIT；`golang.org/x/*` 为 BSD-3-Clause），清单见源码包内 `UPSTREAM-NOTES.md`
- 运行时下载的第三方组件（ShadowQuic、sing-box、cloudflared）分别受其自身许可证约束

> ⚠️ **免责声明**：本项目仅供学习、研究和个人测试使用。请遵守所在地法律法规及云服务商条款，只在你拥有或获授权管理的服务器上使用。

<div align="center">

**[⬆ 回到顶部](#-warp-go--shadowquic--sing-box)**

Made with 🚀 by [zhangweixy666](https://github.com/zhangweixy666)

</div>