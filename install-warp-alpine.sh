#!/bin/sh
set -euo pipefail
GITHUB_REPO="zhangweixy666/warp-"
VERSION="v1"
WARP_BIN="/usr/local/bin/warp"
WARP_DIR="/opt/warp-go"
WARP_PORT=1080
CONFIG_DIR="/etc/shadowquic"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

[ "$(id -u)" -ne 0 ] && err "请用 root 运行"
[ ! -f /etc/alpine-release ] && err "仅支持 Alpine Linux"

detect_mode() { curl -6 -s --connect-timeout 3 https://ipv6.icanhazip.com -o /dev/null 2>/dev/null && echo "6" || echo "4"; }
is_valid() { [ -f "$1" ] && [ "$(head -c 4 "$1" 2>/dev/null)" = "$(printf '\x7f\x45\x4c\x46')" ]; }

# === WARP ===
find_warp() {
    is_valid "$WARP_BIN" && { log "warp 已就绪"; return 0; }
    for p in /root/warp /home/warp /tmp/warp; do
        is_valid "$p" && { cp "$p" "$WARP_BIN" && chmod +x "$WARP_BIN" && log "使用本地 $p"; return 0; }
    done
    info "下载 warp 二进制..."
    curl -L -o /tmp/warp "https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/warp" 2>/dev/null || err "下载失败"
    is_valid /tmp/warp || err "文件损坏"
    mv /tmp/warp "$WARP_BIN" && chmod +x "$WARP_BIN" && log "下载完成"
}

install_warp() {
    mkdir -p "$WARP_DIR" && cd "$WARP_DIR"
    if [ ! -f reg.json ]; then
        info "注册 WARP 账号..."
        "$WARP_BIN" -reg 2>&1 | grep -v "^$" || true
        grep -q '"id"' reg.json 2>/dev/null || err "注册失败"
    fi
    log "注册成功"
    local mode; mode=$(detect_mode)
    cat > /etc/init.d/warp-go << SERVICE
#!/sbin/openrc-run
supervisor=supervise-daemon
name="warp-go"
command="$WARP_BIN"
command_args="-ip $mode -l 127.0.0.1:$WARP_PORT"
command_background=true
pidfile="/run/\$RC_SVCNAME.pid"
respawn_delay=5; respawn_max=0
output_log="/var/log/warp-go.log"; error_log="/var/log/warp-go.log"
SERVICE
    chmod +x /etc/init.d/warp-go
    rc-update add warp-go default >/dev/null 2>&1
    rc-service warp-go restart 2>/dev/null || true
    log "WARP 服务已创建"
    sleep 3
    local ip=$(curl -x "socks5h://127.0.0.1:$WARP_PORT" -s --connect-timeout 5 --max-time 10 https://ipv4.icanhazip.com 2>/dev/null || echo "检测中...")
    log "出口 IP: $ip"
    cat > /usr/local/bin/warp-keepalive.sh << 'KEEP'
#!/bin/sh
W=/usr/local/bin/warp
pgrep -f "$W -ip" >/dev/null 2>&1 && exit 0
cd /opt/warp-go
if curl -6 -s --connect-timeout 3 https://ipv6.icanhazip.com -o /dev/null 2>/dev/null; then M=6; else M=4; fi
nohup "$W" -ip "$M" -l 127.0.0.1:1080 > /opt/warp-go/warp.log 2>&1 &
KEEP
    chmod +x /usr/local/bin/warp-keepalive.sh
    (crontab -l 2>/dev/null | grep -v warp-keepalive; echo "* * * * * /usr/local/bin/warp-keepalive.sh >/dev/null 2>&1") | crontab - 2>/dev/null || true
    log "保活已安装"
    cat > /usr/local/bin/warpctl << 'CTL'
#!/bin/sh
case "${1:-status}" in
    status|st) P=$(pgrep -f "/usr/local/bin/warp -ip" | head -1); [ -n "$P" ] && echo "运行中 PID=$P 出口IP=$(curl -x socks5h://127.0.0.1:1080 -s --connect-timeout 3 https://ipv4.icanhazip.com 2>/dev/null || echo ?)" || echo "未运行";;
    restart|re) rc-service warp-go restart 2>/dev/null || { pkill -f "/usr/local/bin/warp -ip" 2>/dev/null; sleep 1; cd /opt/warp-go; curl -6 -s --connect-timeout 3 https://ipv6.icanhazip.com -o /dev/null 2>/dev/null && M=6 || M=4; nohup /usr/local/bin/warp -ip "$M" -l 127.0.0.1:1080 > /opt/warp-go/warp.log 2>&1 &; }; sleep 3; curl -x socks5h://127.0.0.1:1080 -s --connect-timeout 5 https://ipv4.icanhazip.com;;
    ip) curl -x socks5h://127.0.0.1:1080 -s --connect-timeout 5 https://ipv4.icanhazip.com 2>/dev/null || echo "不可用";;
    log) tail -30 /var/log/warp-go.log 2>/dev/null || echo "无日志";;
    *) echo "用法: warpctl status|restart|ip|log";;
esac
CTL
    chmod +x /usr/local/bin/warpctl
    log "warpctl 已安装"
}

# === ShadowQuic ===
install_shadowquic() {
    [ -f /usr/local/bin/shadowquic ] && { log "shadowquic 已安装"; return 0; }
    local arch; arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)  local b="shadowquic-x86_64-linux-musl";;
        aarch64|arm64) local b="shadowquic-aarch64-linux-musl";;
        armv7l|armhf)  local b="shadowquic-armv7-linux-muslhf";;
        armv6l)        local b="shadowquic-armv6-linux-musl";;
        *) err "不支持的架构: $arch";;
    esac
    log "架构: $arch"
    info "获取 shadowquic 版本..."
    local sqv=$(curl -sL https://api.github.com/repos/spongebob888/shadowquic/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    [ -z "$sqv" ] && sqv="v0.3.12"
    log "版本: $sqv"
    info "下载 shadowquic..."
    curl -L -o /tmp/shadowquic "https://github.com/spongebob888/shadowquic/releases/download/${sqv}/${b}" 2>/dev/null || err "下载失败"
    is_valid /tmp/shadowquic || err "文件损坏"
    chmod +x /tmp/shadowquic && mv -f /tmp/shadowquic /usr/local/bin/shadowquic
    log "shadowquic 安装完成"
    mkdir -p "$CONFIG_DIR"
    cat > "${CONFIG_DIR}/server-direct.yaml" << 'YAML1'
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
YAML1
    cat > "${CONFIG_DIR}/server-socks.yaml" << 'YAML2'
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
YAML2
    echo "direct" > "${CONFIG_DIR}/last-mode"
    log "双配置创建完成"
    cat > /usr/local/bin/shadowquic-daemon.sh << 'DAEMON'
#!/bin/sh
MODE=$(cat /etc/shadowquic/last-mode 2>/dev/null || echo "direct")
CONF="/etc/shadowquic/server-${MODE}.yaml"
LOG="/var/log/shadowquic-${MODE}.log"
exec shadowquic -c "$CONF" >> "$LOG" 2>&1
DAEMON
    chmod +x /usr/local/bin/shadowquic-daemon.sh
    cat > /usr/local/bin/switch-quic << 'SWITCH'
#!/bin/sh
stop_all() { rc-service shadowquic stop 2>/dev/null; pkill -9 -f shadowquic 2>/dev/null; pkill -9 -f supervise-daemon 2>/dev/null; sleep 2; }
case "${1:-}" in
    direct) stop_all; echo "direct" > /etc/shadowquic/last-mode; rc-service shadowquic start; echo "已切换到直连出站";;
    socks)  stop_all; echo "socks" > /etc/shadowquic/last-mode; rc-service shadowquic start; echo "已切换到 SOCKS5 出站";;
    stop)   stop_all; echo "已停止";;
    restart) stop_all; rc-service shadowquic start; echo "已重启";;
    status) echo "模式: $(cat /etc/shadowquic/last-mode 2>/dev/null)"; rc-service shadowquic status 2>/dev/null; ps aux | grep shadowquic | grep -v grep || echo "无进程";;
    log)    tail -30 "/var/log/shadowquic-$(cat /etc/shadowquic/last-mode 2>/dev/null || echo direct).log" 2>/dev/null || echo "无日志";;
    *) echo "用法: switch-quic {direct|socks|stop|restart|status|log}";;
esac
SWITCH
    chmod +x /usr/local/bin/switch-quic
    cat > /etc/init.d/shadowquic << 'OPENRC'
#!/sbin/openrc-run
supervisor=supervise-daemon
name="ShadowQuic"
command="/usr/local/bin/shadowquic-daemon.sh"
pidfile="/run/$RC_SVCNAME.pid"
respawn_delay=5; respawn_max=0
output_log="/var/log/shadowquic-service.log"; error_log="/var/log/shadowquic-service.log"
OPENRC
    chmod +x /etc/init.d/shadowquic
    rc-update add shadowquic default >/dev/null 2>&1
    cat > /usr/local/bin/quic-manager << 'MANAGER'
#!/bin/sh
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
stop_all() { rc-service shadowquic stop 2>/dev/null; pkill -9 -f shadowquic 2>/dev/null; pkill -9 -f supervise-daemon 2>/dev/null; sleep 2; }
show_menu() {
    while true; do
        MODE=$(cat /etc/shadowquic/last-mode 2>/dev/null || echo "direct")
        if pgrep -f 'shadowquic -c' >/dev/null 2>&1; then RUNNING="${GREEN}● 运行中${NC}"; else RUNNING="${RED}● 已停止${NC}"; fi
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
    log "管理面板已安装 (quic-manager)"
}

# === sing-box ===
sb_on() {
    [ ! -f /etc/sing-box/config.json ] && err "无 sing-box 配置"
    cp /etc/sing-box/config.json /etc/sing-box/config.json.bak
    jq '.outbounds += [{"type":"socks","tag":"warp","server":"127.0.0.1","server_port":1080,"version":"5"}] | .route.final = "warp"' /etc/sing-box/config.json > /tmp/sb.json && mv /tmp/sb.json /etc/sing-box/config.json
    pkill -f "sing-box run" 2>/dev/null || true; sleep 1; nohup sing-box run -c /etc/sing-box/config.json >/dev/null 2>&1 &
    log "sing-box 已接入 WARP"
}
sb_off() {
    [ ! -f /etc/sing-box/config.json ] && err "无 sing-box 配置"
    cp /etc/sing-box/config.json /etc/sing-box/config.json.bak
    jq 'del(.outbounds[]|select(.tag=="warp")) | .route.final = "direct"' /etc/sing-box/config.json > /tmp/sb.json && mv /tmp/sb.json /etc/sing-box/config.json
    pkill -f "sing-box run" 2>/dev/null || true; sleep 1; nohup sing-box run -c /etc/sing-box/config.json >/dev/null 2>&1 &
    log "sing-box 已断开 WARP"
}

# === 主入口 ===
install_all() {
    echo -e "${BOLD}===== warp-go + shadowquic 一键部署 =====${NC}"
    apk update >/dev/null 2>&1 || true
    apk add --no-cache curl jq procps bash dialog nano >/dev/null 2>&1 || true
    find_warp; install_warp; install_shadowquic
    echo -e "${BOLD}===== 部署完成 =====${NC}"
    echo ""
    log "WARP SOCKS5: socks5://127.0.0.1:$WARP_PORT"
    log "ShadowQuic: 端口 1443  用户: user1  密码: changeme"
    echo ""
    echo "WARP 管理:"
    echo "  warpctl status|restart|ip|log"
    echo ""
    echo "ShadowQuic 管理:"
    echo "  quic-manager          交互面板"
    echo "  switch-quic direct    直连出站"
    echo "  switch-quic socks     SOCKS5出站（走 WARP）"
    echo "  switch-quic status    状态"
    echo "  switch-quic log       日志"
    echo "  switch-quic restart   重启"
    echo ""
    echo "sing-box 接入:"
    echo "  sh $0 sb-on    接入"
    echo "  sh $0 sb-off   断开"
    echo ""
    echo "卸载: sh $0 remove"
}

case "${1:-install}" in
    install|"") install_all;;
    sb-on) sb_on;;
    sb-off) sb_off;;
    remove|uninstall)
        rc-service warp-go stop 2>/dev/null || true; rc-update del warp-go 2>/dev/null || true
        rc-service shadowquic stop 2>/dev/null || true; rc-update del shadowquic 2>/dev/null || true
        rm -f /etc/init.d/warp-go /etc/init.d/shadowquic /usr/local/bin/warp /usr/local/bin/shadowquic /usr/local/bin/warpctl /usr/local/bin/switch-quic /usr/local/bin/quic-manager /usr/local/bin/warp-keepalive.sh /usr/local/bin/shadowquic-daemon.sh
        rm -rf /opt/warp-go /etc/shadowquic
        crontab -l 2>/dev/null | grep -v warp | crontab - 2>/dev/null || true
        log "已卸载"
        ;;
    *) echo "用法: $0 {install|sb-on|sb-off|remove}";;
esac
