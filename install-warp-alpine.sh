#!/bin/sh
set -euo pipefail

# ==========================================
# warp-go + shadowquic 一键部署
# 仅支持 Alpine Linux x86_64
# ==========================================

if [ ! -f /etc/alpine-release ]; then
    echo "[错误] 仅支持 Alpine Linux"; exit 1
fi

ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
    echo "[错误] 仅支持 x86_64 架构"; exit 1
fi
echo "[✓] 系统: Alpine Linux x86_64"

ACTION="${1:-install}"
case "$ACTION" in
    install)
        ;;
    sb-on)
        [ -x /usr/local/bin/sb-on ] || { echo "[错误] sb-on 尚未安装，请先运行默认安装"; exit 1; }
        exec /usr/local/bin/sb-on
        ;;
    sb-off)
        [ -x /usr/local/bin/sb-off ] || { echo "[错误] sb-off 尚未安装，请先运行默认安装"; exit 1; }
        exec /usr/local/bin/sb-off
        ;;
    singbox-install|singbox-manager|singbox-status|singbox-restart|singbox-warp-on|singbox-warp-off|singbox-backup|singbox-restore|singbox-remove)
        [ -x "/usr/local/bin/$ACTION" ] || { echo "[错误] $ACTION 尚未安装，请先运行默认安装"; exit 1; }
        exec "/usr/local/bin/$ACTION"
        ;;
    remove|uninstall)
        rc-service shadowquic stop 2>/dev/null || true
        rc-service warp-go stop 2>/dev/null || true
        rc-update del shadowquic default 2>/dev/null || true
        rc-update del warp-go default 2>/dev/null || true
        pkill -9 -f '[/]usr/local/bin/shadowquic -c' 2>/dev/null || true
        pkill -9 -f '[/]usr/local/bin/shadowquic-daemon.sh' 2>/dev/null || true
        pkill -f '[/]usr/local/bin/warp -ip' 2>/dev/null || true
        rm -f /etc/init.d/shadowquic /etc/init.d/warp-go \
            /usr/local/bin/shadowquic /usr/local/bin/shadowquic-daemon.sh \
            /usr/local/bin/switch-quic /usr/local/bin/quic-manager \
            /usr/local/bin/warp /usr/local/bin/warpctl \
            /usr/local/bin/warp-manager /usr/local/bin/sb-on \
            /usr/local/bin/sb-off /usr/local/bin/sb-restart \
            /usr/local/bin/warp-keepalive.sh
        rm -rf /etc/shadowquic /opt/warp-go
        (crontab -l 2>/dev/null | grep -v warp-keepalive | crontab -) 2>/dev/null || true
        echo "[✓] 已卸载 WARP + ShadowQuic"
        exit 0
        ;;
    *)
        echo "用法: sh $0 [install|sb-on|sb-off|remove]"
        exit 2
        ;;
esac

apk update >/dev/null 2>&1 || true
apk add --no-cache curl jq procps bash dialog nano >/dev/null 2>&1 || true

WARP_DIR="/opt/warp-go"
WARP_BIN="/usr/local/bin/warp"
WARP_PORT=1080
GITHUB_REPO="zhangweixy666/warp-"
VER="v1"

# ---------- WARP ----------
find_warp() {
    if [ -f "$WARP_BIN" ] && [ "$(head -c 4 "$WARP_BIN" 2>/dev/null)" = "$(printf '\x7f\x45\x4c\x46')" ]; then
        echo "[✓] warp 已就绪"; return 0
    fi
    for p in /root/warp /home/warp /tmp/warp; do
        if [ -f "$p" ] && [ "$(head -c 4 "$p" 2>/dev/null)" = "$(printf '\x7f\x45\x4c\x46')" ]; then
            cp "$p" "$WARP_BIN" && chmod +x "$WARP_BIN"; echo "[✓] 使用本地 $p"; return 0
        fi
    done
    echo "[i] 下载 warp..."
    curl -L -o /tmp/warp "https://github.com/${GITHUB_REPO}/releases/download/${VER}/warp" 2>/dev/null
    if [ -f /tmp/warp ] && [ "$(head -c 4 /tmp/warp 2>/dev/null)" = "$(printf '\x7f\x45\x4c\x46')" ]; then
        mv /tmp/warp "$WARP_BIN" && chmod +x "$WARP_BIN"; echo "[✓] warp 下载完成"
    else
        echo "[✗] warp 下载失败"; exit 1
    fi
}

reg_warp() {
    mkdir -p "$WARP_DIR" && cd "$WARP_DIR"
    if [ -f reg.json ] && grep -q '"id"' reg.json 2>/dev/null; then
        echo "[✓] WARP 已注册"; return 0
    fi
    echo "[i] 注册 WARP..."
    "$WARP_BIN" -reg 2>&1 | grep -v "^$" || true
    if grep -q '"id"' reg.json 2>/dev/null; then echo "[✓] WARP 注册成功"
    else echo "[✗] WARP 注册失败"; exit 1; fi
}

start_warp() {
    if curl -6 -s --connect-timeout 3 https://ipv6.icanhazip.com -o /dev/null 2>/dev/null; then
        IP_MODE="6"; echo "[✓] IPv6 网络"
    else
        IP_MODE="4"; echo "[✓] IPv4 网络"
    fi
    if pgrep -f "$WARP_BIN -ip" >/dev/null 2>&1; then
        echo "[✓] WARP 已在运行"
    else
        echo "[i] 启动 WARP..."
        cd "$WARP_DIR"; nohup "$WARP_BIN" -ip "$IP_MODE" -l "127.0.0.1:$WARP_PORT" > warp.log 2>&1 &
        sleep 3
        if pgrep -f "$WARP_BIN -ip" >/dev/null 2>&1; then echo "[✓] WARP 启动成功"
        else echo "[✗] WARP 启动失败"; exit 1; fi
    fi
    WARP_IP=$(curl -x "socks5h://127.0.0.1:$WARP_PORT" -s --connect-timeout 5 --max-time 10 https://ipv4.icanhazip.com 2>/dev/null || echo "检测中...")
    echo "[✓] WARP 出口 IP: $WARP_IP"
}

# ---------- shadowquic ----------
install_shadowquic() {
    if [ -f /usr/local/bin/shadowquic ]; then echo "[✓] shadowquic 已安装"; return 0; fi
    echo "[i] 获取最新版本..."
    SQ_VER=$(curl -sL https://api.github.com/repos/spongebob888/shadowquic/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    [ -z "$SQ_VER" ] && SQ_VER="v0.3.12"
    echo "[i] 下载 shadowquic ${SQ_VER}..."
    curl -L -o /tmp/shadowquic "https://github.com/spongebob888/shadowquic/releases/download/${SQ_VER}/shadowquic-x86_64-linux-musl" 2>/dev/null
    if [ -f /tmp/shadowquic ] && [ "$(head -c 4 /tmp/shadowquic 2>/dev/null)" = "$(printf '\x7f\x45\x4c\x46')" ]; then
        chmod +x /tmp/shadowquic; mv -f /tmp/shadowquic /usr/local/bin/shadowquic
        echo "[✓] shadowquic 安装完成"
    else
        echo "[✗] shadowquic 下载失败"; exit 1
    fi
}

config_shadowquic() {
    mkdir -p /etc/shadowquic
    cat > /etc/shadowquic/server-direct.yaml << 'YAML'
inbound:
  type: shadowquic
  bind-addr: "[::]:1443"
  users:
    - username: "user1"
      password: "changeme"
  server-name: "www.apple.com"
  jls-upstream:
    addr: "www.apple.com:443"
    rate-limit: 1000000
  alpn: ["h3"]
  zero-rtt: true
  congestion-control: bbr
  gso: true
  mtu-discovery: true
  blackhole-detection: false
  initial-mtu: 1300
  min-mtu: 1200
outbound:
  type: direct
log-level: info
YAML
    cat > /etc/shadowquic/server-socks.yaml << 'YAML'
inbound:
  type: shadowquic
  bind-addr: "[::]:1443"
  users:
    - username: "user1"
      password: "changeme"
  server-name: "www.apple.com"
  jls-upstream:
    addr: "www.apple.com:443"
    rate-limit: 1000000
  alpn: ["h3"]
  zero-rtt: true
  congestion-control: bbr
  gso: true
  mtu-discovery: true
  blackhole-detection: false
  initial-mtu: 1300
  min-mtu: 1200
outbound:
  type: socks
  addr: "127.0.0.1:1080"
log-level: info
YAML
    echo "direct" > /etc/shadowquic/last-mode
    echo "[✓] 配置创建完成"
}

setup_service() {
    cat > /etc/init.d/shadowquic << 'OPENRC'
#!/sbin/openrc-run
supervisor=supervise-daemon
name="ShadowQuic"
command="/usr/local/bin/shadowquic-daemon.sh"
pidfile="/run/$RC_SVCNAME.pid"
respawn_delay=5
respawn_max=0
output_log="/var/log/shadowquic-service.log"
error_log="/var/log/shadowquic-service.log"
OPENRC
    chmod +x /etc/init.d/shadowquic
    rc-update add shadowquic default >/dev/null 2>&1
    echo "[✓] 开机自启已设置"

    cat > /usr/local/bin/shadowquic-daemon.sh << 'DAEMON'
#!/bin/sh
MODE=$(cat /etc/shadowquic/last-mode 2>/dev/null || echo "direct")
CONF="/etc/shadowquic/server-${MODE}.yaml"
LOG="/var/log/shadowquic-${MODE}.log"
exec shadowquic -c "$CONF" >> "$LOG" 2>&1
DAEMON
    chmod +x /usr/local/bin/shadowquic-daemon.sh
}

setup_commands() {
    # switch-quic
    cat > /usr/local/bin/switch-quic << 'SWITCH'
#!/bin/sh
stop_all() {
    rc-service shadowquic stop 2>/dev/null || true
    pkill -9 -f '[/]usr/local/bin/shadowquic -c' 2>/dev/null || true
    pkill -9 -f '[/]usr/local/bin/shadowquic-daemon.sh' 2>/dev/null || true
    pkill -9 -f 'supervise-daemon shadowquic' 2>/dev/null || true
    sleep 2
}
case "${1:-}" in
    direct)  stop_all; echo "direct" > /etc/shadowquic/last-mode; rc-service shadowquic start; echo "已切换到直连出站" ;;
    socks)   stop_all; echo "socks" > /etc/shadowquic/last-mode; rc-service shadowquic start; echo "已切换到 SOCKS5 出站" ;;
    stop)    stop_all; echo "已停止" ;;
    restart) stop_all; rc-service shadowquic start; echo "已重启" ;;
    status)  echo "模式: $(cat /etc/shadowquic/last-mode 2>/dev/null)"; rc-service shadowquic status 2>/dev/null; ps aux | grep shadowquic | grep -v grep || echo "无进程" ;;
    log)     tail -30 "/var/log/shadowquic-$(cat /etc/shadowquic/last-mode 2>/dev/null || echo direct).log" 2>/dev/null || echo "无日志" ;;
    *)       echo "用法: switch-quic {direct|socks|stop|restart|status|log}" ;;
esac
SWITCH
    chmod +x /usr/local/bin/switch-quic

    # warpctl
    cat > /usr/local/bin/warpctl << 'CTL'
#!/bin/sh
case "${1:-status}" in
    status|st) P=$(pgrep -f "/usr/local/bin/warp -ip" | head -1); [ -n "$P" ] && echo "运行中 PID=$P 出口IP=$(curl -x socks5h://127.0.0.1:1080 -s --connect-timeout 3 https://ipv4.icanhazip.com 2>/dev/null || echo ?)" || echo "未运行";;
    restart|re)
        pkill -f '[/]usr/local/bin/warp -ip' 2>/dev/null || true
        sleep 1
        cd /opt/warp-go
        curl -6 -s --connect-timeout 3 https://ipv6.icanhazip.com -o /dev/null 2>/dev/null && M=6 || M=4
        nohup /usr/local/bin/warp -ip "$M" -l 127.0.0.1:1080 > /opt/warp-go/warp.log 2>&1 &
        sleep 3
        curl -x socks5h://127.0.0.1:1080 -s --connect-timeout 5 https://ipv4.icanhazip.com
        ;;
    ip) curl -x socks5h://127.0.0.1:1080 -s --connect-timeout 5 https://ipv4.icanhazip.com 2>/dev/null || echo "不可用";;
    log) tail -30 /var/log/warp-go.log 2>/dev/null || echo "无日志";;
    *) echo "用法: warpctl status|restart|ip|log";;
esac
CTL
    chmod +x /usr/local/bin/warpctl

    # sing-box 开关脚本
    cat > /usr/local/bin/sb-on << 'SBON'
#!/bin/sh
set -eu
CONFIG=/etc/sing-box/config.json
BIN=/usr/local/bin/sing-box
[ -f "$CONFIG" ] || { echo "[错误] 未找到 $CONFIG"; exit 1; }
[ -x "$BIN" ] || { echo "[错误] 未找到 $BIN"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "[错误] 未找到 jq"; exit 1; }
mkdir -p /etc/sing-box/backups
cp -p "$CONFIG" "/etc/sing-box/backups/config.json.before-warp-$(date +%Y%m%d_%H%M%S)"
jq 'if any(.outbounds[]?; .tag == "warp") then . else .outbounds += [{"type":"socks","tag":"warp","server":"127.0.0.1","server_port":1080,"version":"5"}] end | .route.final = "warp"' "$CONFIG" > "$CONFIG.tmp"
"$BIN" check -c "$CONFIG.tmp"
mv "$CONFIG.tmp" "$CONFIG"
rc-service sing-box restart >/dev/null 2>&1 || rc-service sing-box start >/dev/null 2>&1
echo "[✓] sing-box 已接入 WARP"
SBON
    chmod +x /usr/local/bin/sb-on

    cat > /usr/local/bin/sb-off << 'SBOFF'
#!/bin/sh
set -eu
CONFIG=/etc/sing-box/config.json
BIN=/usr/local/bin/sing-box
[ -f "$CONFIG" ] || { echo "[错误] 未找到 $CONFIG"; exit 1; }
[ -x "$BIN" ] || { echo "[错误] 未找到 $BIN"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "[错误] 未找到 jq"; exit 1; }
mkdir -p /etc/sing-box/backups
cp -p "$CONFIG" "/etc/sing-box/backups/config.json.before-direct-$(date +%Y%m%d_%H%M%S)"
jq 'del(.outbounds[]? | select(.tag == "warp")) | if .route.final == "warp" then .route.final = "direct" else . end' "$CONFIG" > "$CONFIG.tmp"
"$BIN" check -c "$CONFIG.tmp"
mv "$CONFIG.tmp" "$CONFIG"
rc-service sing-box restart >/dev/null 2>&1 || rc-service sing-box start >/dev/null 2>&1
echo "[✓] sing-box 已切换为直连"
SBOFF
    chmod +x /usr/local/bin/sb-off

    # 总管理面板
    cat > /usr/local/bin/warp-manager << 'WMANAGER'
#!/bin/sh
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
pause() { read -r -p "按回车返回..." _; }
while true; do
    clear
    MODE=$(cat /etc/shadowquic/last-mode 2>/dev/null || echo "未安装")
    WARP_STATE=$(pgrep -f '[/]usr/local/bin/warp -ip' >/dev/null 2>&1 && echo "运行中" || echo "已停止")
    SQ_STATE=$(pgrep -f '[/]usr/local/bin/shadowquic -c' >/dev/null 2>&1 && echo "运行中" || echo "已停止")
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}      WARP + ShadowQuic 管理面板${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo "WARP: $WARP_STATE | ShadowQuic: $SQ_STATE | 模式: $MODE"
    echo ""
    echo "1. WARP 状态"
    echo "2. 重启 WARP"
    echo "3. ShadowQuic 直连出站"
    echo "4. ShadowQuic SOCKS5 出站"
    echo "5. ShadowQuic 状态"
    echo "6. ShadowQuic 日志"
    echo "7. 打开 ShadowQuic 面板"
    echo "8. Sing-box 接入 WARP"
    echo "9. Sing-box 断开 WARP"
    echo "0. 退出"
    echo ""
    read -r -p "请选择 [0-9]: " choice
    case "$choice" in
        1) warpctl status; pause;;
        2) warpctl restart; pause;;
        3) switch-quic direct; pause;;
        4) switch-quic socks; pause;;
        5) switch-quic status; pause;;
        6) switch-quic log; pause;;
        7) exec quic-manager;;
        8) sb-on; pause;;
        9) sb-off; pause;;
        0) exit 0;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1;;
    esac
done
WMANAGER
    chmod +x /usr/local/bin/warp-manager
    echo "[✓] warp-manager 已安装"

    # ---------- 可选 sing-box 1.13.14 模块 ----------
    cat > /usr/local/bin/singbox-install << 'SBI'
#!/bin/sh
set -eu
M=/usr/local/bin/singbox-manager.sh
# 固定使用第二个仓库的已验证提交；不追踪 sing-box 或管理脚本的最新版本。
MANAGER_REF=432141cb5690e932f62b2380aa6dd8d045bfc5be
U=https://raw.githubusercontent.com/zhangweixy666/-singbox1.3.x-vless-anytls/$MANAGER_REF/singbox-manager.sh
TMP="$M.tmp.$$"
trap 'rm -f "$TMP"' EXIT INT TERM
echo "[i] 同步 sing-box 管理器固定版本: $MANAGER_REF"
curl -fsSL "$U" -o "$TMP"
[ -s "$TMP" ] && head -n 1 "$TMP" | grep -q '^#!/bin/sh$' || { rm -f "$TMP"; echo "[✗] sing-box 管理器下载内容无效"; exit 1; }
if [ ! -s "$M" ] || ! cmp -s "$TMP" "$M"; then
    mv "$TMP" "$M"
    chmod 755 "$M"
    echo "[✓] sing-box 管理器已同步"
else
    rm -f "$TMP"
    echo "[✓] sing-box 管理器已是固定版本"
fi
if [ -x /usr/local/bin/sing-box ]; then
    echo "[✓] sing-box 已安装"
else
    "$M" install
fi
echo "[✓] sing-box 模块安装完成"
echo "可用命令: singbox-manager singbox-status singbox-restart"
SBI
    chmod +x /usr/local/bin/singbox-install

    cat > /usr/local/bin/singbox-manager << 'SBM'
#!/bin/sh
set -eu
M=/usr/local/bin/singbox-manager.sh
# 每次调用先同步固定管理脚本；不会因为同步而更新已有 sing-box 二进制。
/usr/local/bin/singbox-install
exec "$M" "$@"
SBM
    chmod +x /usr/local/bin/singbox-manager

    cat > /usr/local/bin/singbox-status << 'SBS'
#!/bin/sh
set +e
echo "=== sing-box 状态 ==="
if [ -x /usr/local/bin/sing-box ]; then
    /usr/local/bin/sing-box version 2>/dev/null | head -1
else
    echo "二进制未安装"
fi
if pgrep -f '[s]ing-box run' >/dev/null 2>&1; then echo "进程: 运行中"; else echo "进程: 未运行"; fi
if [ -f /etc/sing-box/config.json ] && [ -x /usr/local/bin/sing-box ]; then
    /usr/local/bin/sing-box check -c /etc/sing-box/config.json
else
    echo "配置不存在或二进制未安装"
fi
rc-service sing-box status 2>/dev/null || true
SBS
    chmod +x /usr/local/bin/singbox-status

    cat > /usr/local/bin/singbox-restart << 'SBR'
#!/bin/sh
set -eu
B=/usr/local/bin/sing-box
C=/etc/sing-box/config.json
[ -x "$B" ] || { echo "[错误] sing-box 未安装"; exit 1; }
[ -f "$C" ] || { echo "[错误] 配置不存在"; exit 1; }
"$B" check -c "$C"
rc-service sing-box restart 2>/dev/null || rc-service sing-box start
echo "[✓] sing-box 已重启"
SBR
    chmod +x /usr/local/bin/singbox-restart

    cat > /usr/local/bin/singbox-backup << 'SBB'
#!/bin/sh
set -eu
C=/etc/sing-box/config.json
[ -f "$C" ] || { echo "[错误] 配置不存在"; exit 1; }
D=/etc/sing-box/backups
mkdir -p "$D"
T=$(date +%Y%m%d_%H%M%S)
cp -p "$C" "$D/config.json.$T"
[ ! -f /etc/sing-box/params.env ] || cp -p /etc/sing-box/params.env "$D/params.env.$T"
echo "[✓] 已备份: $D/config.json.$T"
SBB
    chmod +x /usr/local/bin/singbox-backup

    cat > /usr/local/bin/singbox-restore << 'SBRST'
#!/bin/sh
set -eu
D=/etc/sing-box/backups
C=/etc/sing-box/config.json
[ -d "$D" ] || { echo "[错误] 没有备份目录"; exit 1; }
B=$(ls -1t "$D"/config.json.* 2>/dev/null | head -1 || true)
[ -n "$B" ] || { echo "[错误] 没有可恢复的备份"; exit 1; }
cp -p "$C" "$C.before-restore.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
cp -p "$B" "$C"
if /usr/local/bin/sing-box check -c "$C"; then
    rc-service sing-box restart 2>/dev/null || true
    echo "[✓] 已恢复: $B"
else
    echo "[✗] 恢复后的配置校验失败，保留当前文件备份"
    exit 1
fi
SBRST
    chmod +x /usr/local/bin/singbox-restore

    cat > /usr/local/bin/singbox-warp-on << 'SBWO'
#!/bin/sh
exec /usr/local/bin/sb-on
SBWO
    chmod +x /usr/local/bin/singbox-warp-on

    cat > /usr/local/bin/singbox-warp-off << 'SBWF'
#!/bin/sh
exec /usr/local/bin/sb-off
SBWF
    chmod +x /usr/local/bin/singbox-warp-off

    cat > /usr/local/bin/singbox-remove << 'SBRM'
#!/bin/sh
set -eu
rc-service sing-box stop 2>/dev/null || true
rc-update del sing-box default 2>/dev/null || true
rm -f /etc/init.d/sing-box /usr/local/bin/sing-box /usr/local/bin/singbox-manager.sh
rm -f /usr/local/bin/singbox-install /usr/local/bin/singbox-manager
rm -f /usr/local/bin/singbox-status /usr/local/bin/singbox-restart
rm -f /usr/local/bin/singbox-backup /usr/local/bin/singbox-restore
rm -f /usr/local/bin/singbox-warp-on /usr/local/bin/singbox-warp-off /usr/local/bin/singbox-remove
echo "[✓] sing-box 程序和服务已删除"
echo "配置、证书和备份仍保留在 /etc/sing-box/"
SBRM
    chmod +x /usr/local/bin/singbox-remove

    # quic-manager
    cat > /usr/local/bin/quic-manager << 'MANAGER'
#!/bin/sh
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
stop_all() {
    rc-service shadowquic stop 2>/dev/null || true
    pkill -9 -f '[/]usr/local/bin/shadowquic -c' 2>/dev/null || true
    pkill -9 -f '[/]usr/local/bin/shadowquic-daemon.sh' 2>/dev/null || true
    pkill -9 -f 'supervise-daemon shadowquic' 2>/dev/null || true
    sleep 2
}
show_menu() {
    while true; do
        MODE=$(cat /etc/shadowquic/last-mode 2>/dev/null || echo "direct")
        if pgrep -f 'shadowquic -c' >/dev/null 2>&1; then RUNNING="${GREEN}● 运行中${NC}"; else RUNNING="${RED}● 已��止${NC}"; fi
        clear
        echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║        ShadowQuic 管理面板          ║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}状态:${NC} ${RUNNING}    ${CYAN}端口:${NC} 1443"
        echo -e "  ${CYAN}模式:${NC} $(echo $MODE | sed 's/direct/直连出站/;s/socks/SOCKS5出站/')"
        echo ""
        echo -e "  ${BOLD}1.${NC} 切换到直连出站"
        echo -e "  ${BOLD}2.${NC} 切换到 SOCKS5 出站"
        echo -e "  ${BOLD}3.${NC} 重启服务"
        echo -e "  ${BOLD}4.${NC} 停止服务"
        echo -e "  ${BOLD}5.${NC} 查看日志"
        echo -e "  ${BOLD}6.${NC} 编辑配置"
        echo -e "  ${BOLD}7.${NC} 修改用户名密码"
        echo -e "  ${BOLD}0.${NC} 退出"
        echo ""
        read -p "  $(echo -e $CYAN)请选择 [0-7]:$(echo -e $NC) " choice
        case "$choice" in
            1) stop_all; echo "direct" > /etc/shadowquic/last-mode; rc-service shadowquic start; sleep 2; echo -e "${GREEN}✓ 已切换${NC}"; read -p "按回车返回...";;
            2) stop_all; echo "socks" > /etc/shadowquic/last-mode; rc-service shadowquic start; sleep 2; echo -e "${GREEN}✓ 已切换${NC}"; read -p "按回车返回...";;
            3) stop_all; rc-service shadowquic start; sleep 2; echo -e "${GREEN}✓ 已重启${NC}"; read -p "按回车返回...";;
            4) stop_all; echo -e "${GREEN}✓ 已停止${NC}"; read -p "按回车返回...";;
            5) tail -30 "/var/log/shadowquic-$(cat /etc/shadowquic/last-mode 2>/dev/null || echo direct).log" 2>/dev/null || echo "无日志"; read -p "按回车返回...";;
            6) echo "  1) server-direct.yaml"; echo "  2) server-socks.yaml"; read -p "选择 [1-2]: " c; [ "$c" = "1" ] && nano /etc/shadowquic/server-direct.yaml; [ "$c" = "2" ] && nano /etc/shadowquic/server-socks.yaml; read -p "重启? [Y/n]: " ra; case "$ra" in n|N) ;; *) stop_all; rc-service shadowquic start; sleep 2; esac; read -p "按回车返回...";;
            7) echo "  1) 直连"; echo "  2) SOCKS5"; read -p "选择 [1-2]: " p; [ "$p" = "1" ] && nano /etc/shadowquic/server-direct.yaml; [ "$p" = "2" ] && nano /etc/shadowquic/server-socks.yaml; read -p "重启? [Y/n]: " ra2; case "$ra2" in n|N) ;; *) stop_all; rc-service shadowquic start; sleep 2; esac; read -p "按回车返回...";;
            0) echo -e "${GREEN}再见${NC}"; exit 0;;
            *) echo -e "${RED}无效选择${NC}"; sleep 1;;
        esac
    done
}
[ ! -f /usr/local/bin/shadowquic ] && echo -e "${RED}shadowquic 未安装${NC}" && exit 1
show_menu
MANAGER
    chmod +x /usr/local/bin/quic-manager
    echo "[✓] quic-manager 已安装"
}

# ---------- 主流程 ----------
echo ""
echo "========================================"
echo "   warp-go + shadowquic 一键部署"
echo "   仅支持 Alpine Linux x86_64"
echo "========================================"
echo ""

find_warp
reg_warp
start_warp
install_shadowquic
config_shadowquic
setup_service
setup_commands

# 启动 shadowquic
rc-service shadowquic start 2>/dev/null || true
sleep 2
if pgrep -f 'shadowquic -c' >/dev/null 2>&1; then
    echo "[✓] ShadowQuic 启动成功"
else
    echo "[✗] ShadowQuic 启动失败，请检查日志"
fi

# 保活
cat > /usr/local/bin/warp-keepalive.sh << 'KEEP'
#!/bin/sh
W=/usr/local/bin/warp
pgrep -f "$W -ip" >/dev/null 2>&1 && exit 0
cd /opt/warp-go
curl -6 -s --connect-timeout 3 https://ipv6.icanhazip.com -o /dev/null 2>/dev/null && M=6 || M=4
nohup "$W" -ip "$M" -l 127.0.0.1:1080 > /opt/warp-go/warp.log 2>&1 &
KEEP
chmod +x /usr/local/bin/warp-keepalive.sh
(crontab -l 2>/dev/null | grep -v warp-keepalive; echo "* * * * * /usr/local/bin/warp-keepalive.sh >/dev/null 2>&1") | crontab - 2>/dev/null || true
echo "[✓] WARP 保活已安装"

echo ""
echo "========================================"
echo "   部署完成！"
echo "========================================"
echo ""
echo "WARP SOCKS5: socks5://127.0.0.1:$WARP_PORT"
echo "ShadowQuic: 端口 1443  用户: user1  密码: changeme"
echo ""
echo "管理命令:"
echo "  warpctl status|restart|ip|log"
echo "  quic-manager"
echo "  switch-quic {direct|socks|status|log|restart}"