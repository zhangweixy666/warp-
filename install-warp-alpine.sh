#!/bin/sh
set -euo pipefail
GITHUB_REPO="zhangweixy666/warp-"
VERSION="v1"
WARP_BIN="/usr/local/bin/warp"
WARP_DIR="/opt/warp-go"
WARP_PORT=1080

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

[ "$(id -u)" -ne 0 ] && err "请用 root 运行"
[ ! -f /etc/alpine-release ] && err "仅支持 Alpine Linux"

# 检测 IPv4/IPv6
detect_mode() {
    curl -6 -s --connect-timeout 3 https://ipv6.icanhazip.com -o /dev/null 2>/dev/null && echo "6" || echo "4"
}

# 校验是否为有效 ELF 二进制
is_valid_elf() {
    [ -f "$1" ] && [ "$(head -c 4 "$1" 2>/dev/null)" = "$(printf '\x7f\x45\x4c\x46')" ]
}

# 查找或下载二进制
find_warp() {
    is_valid_elf "$WARP_BIN" && { log "warp 已就绪"; return 0; }

    # 搜索常见位置
    for p in /root/warp /home/warp /tmp/warp; do
        is_valid_elf "$p" && { cp "$p" "$WARP_BIN" && chmod +x "$WARP_BIN" && log "使用本地 $p"; return 0; }
    done

    # 下载
    local url="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/warp"
    info "下载 warp 二进制..."
    curl -L -o /tmp/warp "$url" 2>/dev/null || err "下载失败"
    is_valid_elf /tmp/warp || err "下载文件损坏"
    mv /tmp/warp "$WARP_BIN" && chmod +x "$WARP_BIN" && log "下载完成"
}

# 安装
install() {
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  warp-go Alpine 一键部署${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""

    apk update >/dev/null 2>&1 || true
    apk add --no-cache curl jq procps >/dev/null 2>&1 || true

    find_warp

    # 注册
    mkdir -p "$WARP_DIR" && cd "$WARP_DIR"
    if [ ! -f reg.json ]; then
        info "注册 WARP 账号..."
        "$WARP_BIN" -reg 2>&1 | grep -v "^$" || true
        is_valid_reg() { [ -f reg.json ] && grep -q '"id"' reg.json; }
        is_valid_reg || err "注册失败，请检查网络后重试: $WARP_BIN -reg"
    fi
    log "注册成功"

    # 创建 OpenRC 服务
    local mode
    mode=$(detect_mode)
    cat > /etc/init.d/warp-go << SERVICE
#!/sbin/openrc-run
supervisor=supervise-daemon
name="warp-go"
command="$WARP_BIN"
command_args="-ip $mode -l 127.0.0.1:$WARP_PORT"
command_background=true
pidfile="/run/\$RC_SVCNAME.pid"
respawn_delay=5
respawn_max=0
output_log="/var/log/warp-go.log"
error_log="/var/log/warp-go.log"
SERVICE
    chmod +x /etc/init.d/warp-go
    rc-update add warp-go default >/dev/null 2>&1
    rc-service warp-go restart 2>/dev/null || true
    log "OpenRC 服务已创建"

    # 验证
    sleep 3
    local ip
    ip=$(curl -x "socks5h://127.0.0.1:$WARP_PORT" -s --connect-timeout 5 --max-time 10 https://ipv4.icanhazip.com 2>/dev/null || echo "检测失败")
    log "出口 IP: $ip"

    # 保活脚本
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
    log "crontab 保活已安装"

    # warpctl 快捷命令
    cat > /usr/local/bin/warpctl << 'CTL'
#!/bin/sh
case "${1:-status}" in
    status|st)
        P=$(pgrep -f "/usr/local/bin/warp -ip" | head -1)
        if [ -n "$P" ]; then
            I=$(curl -x socks5h://127.0.0.1:1080 -s --connect-timeout 3 https://ipv4.icanhazip.com 2>/dev/null || echo "?")
            echo "运行中 PID=$P 出口IP=$I"
        else echo "未运行"; fi
        ;;
    restart|re)
        rc-service warp-go restart 2>/dev/null || {
            pkill -f "/usr/local/bin/warp -ip" 2>/dev/null || true
            sleep 1; cd /opt/warp-go
            if curl -6 -s --connect-timeout 3 https://ipv6.icanhazip.com -o /dev/null 2>/dev/null; then M=6; else M=4; fi
            nohup /usr/local/bin/warp -ip "$M" -l 127.0.0.1:1080 > /opt/warp-go/warp.log 2>&1 &
        }
        sleep 3; curl -x socks5h://127.0.0.1:1080 -s --connect-timeout 5 https://ipv4.icanhazip.com
        ;;
    ip) curl -x socks5h://127.0.0.1:1080 -s --connect-timeout 5 https://ipv4.icanhazip.com 2>/dev/null || echo "不可用";;
    log) tail -30 /var/log/warp-go.log 2>/dev/null || echo "无日志";;
    *) echo "用法: warpctl status|restart|ip|log";;
esac
CTL
    chmod +x /usr/local/bin/warpctl
    log "快捷命令: warpctl status|restart|ip|log"

    # 完成
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  部署完成！${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
    log "SOCKS5: socks5://127.0.0.1:$WARP_PORT"
    echo ""
    echo "管理命令:"
    echo "  warpctl status    查看状态"
    echo "  warpctl restart   重启"
    echo "  warpctl ip        出口 IP"
    echo "  warpctl log       日志"
    echo ""
    echo "接入/断开:"
    echo "  sh $0 sb-on       接入 sing-box"
    echo "  sh $0 sb-off      断开 sing-box"
    echo "  sh $0 sq-on       接入 shadowquic"
    echo "  sh $0 sq-off      断开 shadowquic"
    echo ""
    echo "卸载: sh $0 remove"
    echo ""
}

# 接入 sing-box
sb_on() {
    [ ! -f /etc/sing-box/config.json ] && err "未找到 sing-box 配置文件"
    cp /etc/sing-box/config.json /etc/sing-box/config.json.bak
    jq '.outbounds += [{"type":"socks","tag":"warp","server":"127.0.0.1","server_port":1080,"version":"5"}] | .route.final = "warp"' /etc/sing-box/config.json > /tmp/sb.json && mv /tmp/sb.json /etc/sing-box/config.json
    pkill -f "sing-box run" 2>/dev/null || true
    sleep 1
    mkdir -p /var/log/sing-box
    nohup sing-box run -c /etc/sing-box/config.json >/dev/null 2>&1 &
    log "sing-box 已接入 WARP"
}

# 断开 sing-box
sb_off() {
    [ ! -f /etc/sing-box/config.json ] && err "未找到 sing-box 配置文件"
    cp /etc/sing-box/config.json /etc/sing-box/config.json.bak
    jq 'del(.outbounds[]|select(.tag=="warp")) | .route.final = "direct"' /etc/sing-box/config.json > /tmp/sb.json && mv /tmp/sb.json /etc/sing-box/config.json
    pkill -f "sing-box run" 2>/dev/null || true
    sleep 1
    mkdir -p /var/log/sing-box
    nohup sing-box run -c /etc/sing-box/config.json >/dev/null 2>&1 &
    log "sing-box 已断开 WARP"
}

# 接入 shadowquic
sq_on() {
    mkdir -p /etc/shadowquic
    cat > /etc/shadowquic/server-warp.yaml << 'YAML'
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
    echo "warp" > /etc/shadowquic/last-mode
    log "shadowquic 配置已生成"
    [ -f /etc/init.d/shadowquic ] && rc-service shadowquic restart 2>/dev/null || true
}

# 断开 shadowquic
sq_off() {
    rm -f /etc/shadowquic/server-warp.yaml
    echo "direct" > /etc/shadowquic/last-mode
    [ -f /etc/init.d/shadowquic ] && rc-service shadowquic restart 2>/dev/null || true
    log "shadowquic 已切换为直连"
}

# 卸载
remove() {
    rc-service warp-go stop 2>/dev/null || true
    rc-update del warp-go 2>/dev/null || true
    rm -f /etc/init.d/warp-go /usr/local/bin/warp /usr/local/bin/warpctl /usr/local/bin/warp-keepalive.sh
    rm -rf /opt/warp-go
    crontab -l 2>/dev/null | grep -v warp | crontab - 2>/dev/null || true
    log "已卸载"
}

case "${1:-install}" in
    install|"") install;;
    sb-on) sb_on;;
    sb-off) sb_off;;
    sq-on) sq_on;;
    sq-off) sq_off;;
    remove|uninstall) remove;;
    *) echo "用法: $0 {install|sb-on|sb-off|sq-on|sq-off|remove}";;
esac
