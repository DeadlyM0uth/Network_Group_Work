#!/usr/bin/env bash
#
# Messenger Block Guardian (Unix)
# Блокировка Matrix-мессенджера в Tailscale на конечной станции.
#
# Usage:
#   sudo ./block_guardian.sh --block-messenger
#   sudo ./block_guardian.sh --block-messenger --kill-clients
#   sudo ./block_guardian.sh --all-peers
#   sudo ./block_guardian.sh --stop
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/logs/block_guardian.log}"

# --- конфигурация (менять под свой tailnet) ---
SERVER_HOST="messenger-server.tail9da30d.ts.net"
SERVER_IP=""
CHAIN="LAB_BLOCK_MESSENGER"
TAILNET_CIDR="100.64.0.0/10"
BLACKHOLE_MARKER="messenger-block-guardian"

BLOCK_MESSENGER=0
ALL_TAILNET=0
ALL_PEERS=0
ALL_PORTS=0
KILL_CLIENTS=0
STOP=0
INTERVAL=2

BLOCK_MODE=""
BLOCK_ADDRS=()

log() {
    local line
    line="$(date '+%Y-%m-%d %H:%M:%S')  $*"
    echo "$line"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$line" >> "$LOG_FILE"
}

require_root() {
    [[ $EUID -eq 0 ]] || { echo "Запустите от root: sudo $0 ..." >&2; exit 1; }
}

is_tailscale_ip() {
    local ip="$1"
    [[ "$ip" =~ ^100\.([0-9]+)\. ]] || return 1
    local second="${BASH_REMATCH[1]}"
    (( second >= 64 && second <= 127 ))
}

resolve_server_ip() {
    if [[ -n "$SERVER_IP" ]]; then
        echo "$SERVER_IP"
        return
    fi
    if command -v getent >/dev/null 2>&1; then
        getent ahosts "$SERVER_HOST" 2>/dev/null | awk '{print $1; exit}'
    elif command -v tailscale >/dev/null 2>&1; then
        tailscale ip -4 "$SERVER_HOST" 2>/dev/null || true
    fi
}

get_peer_ips() {
    command -v tailscale >/dev/null 2>&1 || return
    tailscale status --json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
peers = data.get('Peer') or {}
peer_list = peers.values() if isinstance(peers, dict) else peers
ips = set()
for p in peer_list:
    for ip in p.get('TailscaleIPs') or []:
        parts = ip.split('.')
        if len(parts) == 4 and parts[0] == '100':
            o = int(parts[1])
            if 64 <= o <= 127:
                ips.add(ip)
for ip in sorted(ips):
    print(ip)
" 2>/dev/null || true
}

remove_blocks() {
    if command -v iptables >/dev/null 2>&1; then
        iptables -D OUTPUT -j "$CHAIN" 2>/dev/null || true
        iptables -D FORWARD -j "$CHAIN" 2>/dev/null || true
        iptables -F "$CHAIN" 2>/dev/null || true
        iptables -X "$CHAIN" 2>/dev/null || true
    fi
    ip route show type blackhole 2>/dev/null | while read -r dst _; do
        [[ "$dst" == 100.* ]] && ip route del blackhole "$dst" 2>/dev/null || true
    done
    log "All blocks removed"
}

install_blackhole_route() {
    local addr="$1" is_cidr="$2"
    local prefix="$addr"
    [[ "$is_cidr" == "0" ]] && prefix="${addr}/32"
    if ip route add blackhole "$prefix" 2>/dev/null; then
        log "Route blackhole $prefix"
    else
        log "Route blackhole $prefix failed (may already exist)"
    fi
}

install_blocks() {
    local all_ports_flag=0
    if [[ "$ALL_TAILNET" == "1" || "$ALL_PEERS" == "1" || "$ALL_PORTS" == "1" || "$BLOCK_MESSENGER" == "1" ]]; then
        all_ports_flag=1
    fi

    remove_blocks

    if command -v iptables >/dev/null 2>&1; then
        iptables -N "$CHAIN" 2>/dev/null || iptables -F "$CHAIN"
    else
        log "WARNING: iptables not found, using routes only"
    fi

    for entry in "${BLOCK_ADDRS[@]}"; do
        local addr="${entry%%|*}" is_cidr="${entry##*|}"
        if command -v iptables >/dev/null 2>&1; then
            if [[ "$all_ports_flag" == "1" ]]; then
                iptables -A "$CHAIN" -d "$addr" -p tcp -j DROP -m comment --comment "$BLACKHOLE_MARKER"
                iptables -A "$CHAIN" -d "$addr" -p udp -j DROP -m comment --comment "$BLACKHOLE_MARKER"
                log "iptables DROP all tcp/udp -> $addr"
            else
                iptables -A "$CHAIN" -d "$addr" -p tcp --dport 443 -j DROP -m comment --comment "$BLACKHOLE_MARKER"
                iptables -A "$CHAIN" -d "$addr" -p tcp --dport 8448 -j DROP -m comment --comment "$BLACKHOLE_MARKER"
                iptables -A "$CHAIN" -d "$addr" -p udp -j DROP -m comment --comment "$BLACKHOLE_MARKER"
                log "iptables DROP tcp/443,8448 + udp -> $addr"
            fi
        fi
        install_blackhole_route "$addr" "$is_cidr"
    done

    if command -v iptables >/dev/null 2>&1; then
        iptables -C OUTPUT -j "$CHAIN" 2>/dev/null || iptables -I OUTPUT 1 -j "$CHAIN"
        iptables -C FORWARD -j "$CHAIN" 2>/dev/null || iptables -I FORWARD 1 -j "$CHAIN"
    fi
}

should_monitor_ip() {
    local ip="$1"
    if [[ "$ALL_TAILNET" == "1" || "$ALL_PEERS" == "1" ]]; then
        is_tailscale_ip "$ip"
        return
    fi
    local target="${BLOCK_ADDRS[0]%%|*}"
    [[ "$ip" == "$target" ]]
}

is_protected_process() {
    local name="$1"
    [[ "$name" =~ ^(tailscaled|systemd|sshd|python3|block_guardian) ]]
}

get_blocked_connections() {
    ss -H -tn state established,syn-sent,fin-wait-1,fin-wait-2,close-wait 2>/dev/null |
    while read -r _ _ local remote state; do
        local rip="${remote%:*}" rport="${remote##*:}"
        should_monitor_ip "$rip" || continue
        local lip="${local%:*}" lport="${local##*:}"
        echo "$lip $lport $rip $rport $state"
    done
}

monitor_once() {
    local line lip lport rip rport state pid pname
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        read -r lip lport rip rport state <<< "$line"
        pid="$(ss -H -tnp "dst $rip" 2>/dev/null | grep ":$rport " | head -1 | sed -n 's/.*pid=\([0-9]*\).*/\1/p')"
        [[ -z "$pid" ]] && continue
        pname="$(ps -p "$pid" -o comm= 2>/dev/null || echo "pid-$pid")"
        is_protected_process "$pname" && continue

        log "BLOCK ATTEMPT DETECTED: $pname ($pid) $lip:$lport -> $rip:$rport [$state]"

        if [[ "$KILL_CLIENTS" == "1" ]]; then
            log "  -> Kill $pname PID $pid"
            kill -9 "$pid" 2>/dev/null || true
        fi
    done < <(get_blocked_connections)
}

count_existing_sessions() {
    get_blocked_connections | wc -l | tr -d ' '
}

usage() {
    cat <<EOF
Usage: sudo $0 [OPTIONS]

  --block-messenger    Блок Matrix-сервера (режим по умолчанию для лабораторной)
  --server-ip IP       Явный IP сервера
  --server-host HOST   Hostname для резолва (default: $SERVER_HOST)
  --all-peers          Блок всех peer IP из tailscale status
  --all-tailnet        Блок всего диапазона $TAILNET_CIDR
  --all-ports          Блок всех TCP-портов (не только 443/8448)
  --kill-clients       Завершать процесс клиента при попытке подключения
  --interval SEC       Интервал мониторинга (default: 2)
  --stop               Снять блокировку и выйти
  -h, --help           Справка

Примеры:
  sudo $0 --block-messenger
  sudo $0 --block-messenger --kill-clients
  sudo $0 --all-peers
  sudo $0 --stop
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --block-messenger) BLOCK_MESSENGER=1; ALL_PORTS=1; shift ;;
        --server-ip)       SERVER_IP="$2"; shift 2 ;;
        --server-host)     SERVER_HOST="$2"; shift 2 ;;
        --all-tailnet)     ALL_TAILNET=1; shift ;;
        --all-peers)       ALL_PEERS=1; shift ;;
        --all-ports)       ALL_PORTS=1; shift ;;
        --kill-clients)    KILL_CLIENTS=1; shift ;;
        --interval)        INTERVAL="$2"; shift 2 ;;
        --stop)            STOP=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        *)                 echo "Unknown: $1" >&2; usage; exit 1 ;;
    esac
done

# Без аргументов — режим блокировки мессенджера
if [[ "$STOP" != "1" && "$BLOCK_MESSENGER" != "1" && "$ALL_TAILNET" != "1" && "$ALL_PEERS" != "1" ]]; then
    BLOCK_MESSENGER=1
    ALL_PORTS=1
fi

if [[ "$STOP" == "1" ]]; then
    require_root
    remove_blocks
    echo "Блокировка снята."
    exit 0
fi

require_root

BLOCK_ADDRS=()
if [[ "$ALL_TAILNET" == "1" ]]; then
    BLOCK_MODE="ALL TAILNET $TAILNET_CIDR"
    BLOCK_ADDRS+=("${TAILNET_CIDR}|1")
elif [[ "$ALL_PEERS" == "1" ]]; then
    mapfile -t peers < <(get_peer_ips)
    [[ ${#peers[@]} -gt 0 ]] || { echo "Peer IP не найдены. Запущен ли tailscale?" >&2; exit 1; }
    BLOCK_MODE="ALL PEERS (${#peers[@]} IPs)"
    log "Peers to block: ${peers[*]}"
    for ip in "${peers[@]}"; do BLOCK_ADDRS+=("${ip}|0"); done
else
    ip="$(resolve_server_ip || true)"
    [[ -n "$ip" ]] || { echo "Не удалось резолвить $SERVER_HOST. Укажите --server-ip." >&2; exit 1; }
    BLOCK_MODE="MESSENGER $ip"
    BLOCK_ADDRS+=("${ip}|0")
fi

echo ""
echo "  Messenger Block Guardian [$BLOCK_MODE]"
echo "  Server: $SERVER_HOST"
echo "  Log:    $LOG_FILE"
echo "  Ctrl+C — остановить мониторинг (правила остаются до --stop)"
echo ""

install_blocks
log "Guardian started mode=$BLOCK_MODE kill_clients=$KILL_CLIENTS"

existing="$(count_existing_sessions)"
if [[ "$existing" -gt 0 ]]; then
    log "WARNING: $existing existing tailnet TCP session(s). Restart messenger client to test block."
fi

trap 'log "Guardian loop interrupted"; exit 0' INT TERM

while true; do
    monitor_once
    sleep "$INTERVAL"
done
