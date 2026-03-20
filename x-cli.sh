#!/bin/bash

REALITY_DOMAINS=("www.microsoft.com" "www.apple.com" "www.oracle.com" "www.ibm.com" "www.samsung.com" "www.qualcomm.com")
VLESS_PORT=$((RANDOM % 50000 + 10000))
API_PORT=62789

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_NC='\033[0m'

log_info() { echo -e "${COLOR_GREEN}[INFO]${COLOR_NC} $1"; }
log_warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $1"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1"; }

detect_package_manager() {
    for manager in apt-get apt dnf yum apk pacman zypper; do
        if command -v "$manager" &>/dev/null; then
            echo "$manager"
            return 0
        fi
    done
    return 1
}

generate_random_hex() {
    local byte_count=$1

    if command -v od &>/dev/null; then
        od -An -N "$byte_count" -tx1 /dev/urandom 2>/dev/null | tr -d ' \n'
        return 0
    fi
    if command -v hexdump &>/dev/null; then
        hexdump -vn "$byte_count" -e '1/1 "%02x"' /dev/urandom 2>/dev/null
        return 0
    fi
    if command -v openssl &>/dev/null; then
        openssl rand -hex "$byte_count" 2>/dev/null
        return 0
    fi
    return 1
}

install_packages() {
    local manager=$1
    shift

    case "$manager" in
        apt-get)
            DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1 &&
                DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null 2>&1
            ;;
        apt)
            DEBIAN_FRONTEND=noninteractive apt update -qq >/dev/null 2>&1 &&
                DEBIAN_FRONTEND=noninteractive apt install -y -qq "$@" >/dev/null 2>&1
            ;;
        dnf)
            dnf install -y "$@" >/dev/null 2>&1
            ;;
        yum)
            yum install -y "$@" >/dev/null 2>&1
            ;;
        apk)
            apk add --no-cache "$@" >/dev/null 2>&1
            ;;
        pacman)
            pacman -Sy --noconfirm "$@" >/dev/null 2>&1
            ;;
        zypper)
            zypper --non-interactive install "$@" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

download_file() {
    local url=$1 output=$2

    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$output"
        return $?
    fi
    if command -v wget &>/dev/null; then
        wget -q -O "$output" "$url"
        return $?
    fi
    return 1
}

extract_zip_file() {
    local zip_file=$1 dest_dir=$2 inner_path=${3:-}

    if command -v unzip &>/dev/null; then
        if [ -n "$inner_path" ]; then
            unzip -qo "$zip_file" "$inner_path" -d "$dest_dir"
        else
            unzip -qo "$zip_file" -d "$dest_dir"
        fi
        return $?
    fi
    if command -v bsdtar &>/dev/null; then
        bsdtar -xf "$zip_file" -C "$dest_dir"
        return $?
    fi
    if command -v busybox &>/dev/null && busybox unzip >/dev/null 2>&1; then
        if [ -n "$inner_path" ]; then
            busybox unzip -o "$zip_file" "$inner_path" -d "$dest_dir" >/dev/null 2>&1
        else
            busybox unzip -o "$zip_file" -d "$dest_dir" >/dev/null 2>&1
        fi
        return $?
    fi
    if command -v python3 &>/dev/null; then
        python3 - "$zip_file" "$dest_dir" "$inner_path" <<'PY'
import sys
import zipfile

zip_path, dest_dir, inner_path = sys.argv[1:4]
with zipfile.ZipFile(zip_path) as zf:
    if inner_path:
        zf.extract(inner_path, dest_dir)
    else:
        zf.extractall(dest_dir)
PY
        return $?
    fi
    return 1
}

ensure_jq() {
    if command -v jq &>/dev/null; then
        return 0
    fi

    local pkg_manager jq_arch jq_url tmp_file
    pkg_manager=$(detect_package_manager)
    if [ -n "$pkg_manager" ] && install_packages "$pkg_manager" jq; then
        command -v jq &>/dev/null && return 0
    fi

    case "$(uname -m)" in
        x86_64) jq_arch="amd64" ;;
        aarch64|arm64) jq_arch="arm64" ;;
        armv7l) jq_arch="armhf" ;;
        *)
            log_error "当前架构不支持自动下载 jq: $(uname -m)"
            return 1
            ;;
    esac

    jq_url="https://github.com/jqlang/jq/releases/latest/download/jq-linux-${jq_arch}"
    tmp_file=$(mktemp /tmp/jq.XXXXXX)
    log_info "尝试下载独立 jq 二进制..."
    if ! download_file "$jq_url" "$tmp_file"; then
        rm -f "$tmp_file"
        log_error "jq 下载失败"
        return 1
    fi
    install -m 0755 "$tmp_file" /usr/local/bin/jq
    rm -f "$tmp_file"
    command -v jq &>/dev/null
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "需要 root 权限"
        exit 1
    fi
}

check_ipv4() {
    log_info "检查网络..."
    SERVER_IP=$(get_public_ipv4)
    if [ -n "$SERVER_IP" ]; then
        log_info "服务器 IPv4: $SERVER_IP"
        return 0
    fi
    log_error "无法获取 IPv4"
    exit 1
}

check_xray() {
    [ -f /usr/local/bin/xray ]
}

check_deps() {
    local pkg_manager

    # curl 和 wget 至少有一个即可，两者都缺才尝试安装
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        log_info "安装下载工具（curl/wget）..."
        pkg_manager=$(detect_package_manager)
        if [ -z "$pkg_manager" ]; then
            log_error "curl 和 wget 均不可用，且未找到受支持的包管理器"
            log_error "请手动安装 curl 或 wget 后重试"
            exit 1
        fi
        if ! install_packages "$pkg_manager" wget curl; then
            log_error "安装下载工具失败，请手动安装 curl 或 wget"
            exit 1
        fi
    fi

    if ! ensure_jq; then
        log_error "缺少 jq，且自动安装/下载失败"
        exit 1
    fi

    if ! command -v qrencode &>/dev/null; then
        log_warn "未安装 qrencode，后续仅输出链接，不显示二维码"
    fi
}

check_geoip() {
    if [ ! -f /usr/local/share/xray/geoip.dat ]; then
        log_info "下载 GeoIP..."
        mkdir -p /usr/local/share/xray
        if ! download_file "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" "/usr/local/share/xray/geoip.dat"; then
            log_error "GeoIP 下载失败"
            exit 1
        fi
    fi
}

fetch_url_text() {
    local url=$1

    if command -v curl &>/dev/null; then
        curl -fsSL -4 --max-time 5 "$url" 2>/dev/null
        return $?
    fi
    if command -v wget &>/dev/null; then
        # 不加 -4，保持与 BusyBox wget 兼容
        wget -q -O - "$url" 2>/dev/null
        return $?
    fi
    return 1
}

get_public_ipv4() {
    local ip url

    for url in "https://ifconfig.me" "https://ip.sb" "https://api.ipify.org"; do
        ip=$(fetch_url_text "$url" | tr -d '[:space:]')
        if [ -n "$ip" ] && [[ ! "$ip" == *":"* ]]; then
            echo "$ip"
            return 0
        fi
    done
    return 1
}

random_domain() {
    echo "${REALITY_DOMAINS[$((RANDOM % ${#REALITY_DOMAINS[@]}))]}"
}

generate_keys() {
    log_info "生成 Reality 密钥..."
    local key_pair
    key_pair=$(/usr/local/bin/xray x25519 2>&1)
    PRIVATE_KEY=$(echo "$key_pair" | grep "Private key:" | awk '{print $3}')
    PUBLIC_KEY=$(echo "$key_pair" | grep "Public key:" | awk '{print $3}')

    if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
        if ! command -v openssl &>/dev/null; then
            log_error "xray x25519 失败，且系统缺少 openssl，无法回退生成密钥"
            exit 1
        fi
        log_warn "xray x25519 失败，使用 openssl 生成 x25519 密钥..."
        local pem_file
        pem_file=$(mktemp /tmp/xray_key.XXXXXX.pem)
        openssl genpkey -algorithm X25519 2>/dev/null > "$pem_file"
        local priv_hex pub_hex
        priv_hex=$(openssl pkey -in "$pem_file" -text -noout 2>/dev/null | \
            awk '/priv:/{f=1;next} /pub:/{f=0} f{gsub(/[ :]/,""); printf $0}')
        pub_hex=$(openssl pkey -in "$pem_file" -pubout -text -noout 2>/dev/null | \
            awk '/pub:/{f=1;next} f{gsub(/[ :]/,""); printf $0}')
        rm -f "$pem_file"
        PRIVATE_KEY=$(printf '%s' "$priv_hex" | xxd -r -p | base64 | tr '+/' '-_' | tr -d '=\n')
        PUBLIC_KEY=$(printf '%s' "$pub_hex" | xxd -r -p | base64 | tr '+/' '-_' | tr -d '=\n')
    fi

    if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
        log_error "密钥生成失败（xray x25519 和 openssl 均失败）"
        exit 1
    fi
    SHORT_ID=$(generate_random_hex 4)
    SHORT_IDS="[\"\", \"${SHORT_ID}\", \"$(generate_random_hex 2)\", \"$(generate_random_hex 3)\", \"$(generate_random_hex 4)\"]"
    if [ -z "$SHORT_ID" ] || [ -z "$SHORT_IDS" ]; then
        log_error "随机 Short ID 生成失败"
        exit 1
    fi
    log_info "PublicKey: $PUBLIC_KEY"
}

install_compat_xray() {
    local arch
    arch=$(uname -m)
    local zipname
    case "$arch" in
        x86_64)        zipname="Xray-linux-64.zip" ;;
        aarch64|arm64) zipname="Xray-linux-arm64-v8a.zip" ;;
        armv7l)        zipname="Xray-linux-arm32-v7a.zip" ;;
        *) log_error "不支持的架构: $arch"; exit 1 ;;
    esac
    mkdir -p /usr/local/bin /usr/local/share/xray /var/log/xray /usr/local/etc/xray

    # 优先尝试 v24.12.31（Go 1.23 编译，兼容 ARMv8.0，功能更新）
    local try_versions=("v24.12.31" "v1.8.23")
    for ver in "${try_versions[@]}"; do
        log_info "尝试下载 Xray ${ver} ($arch)..."
            download_file \
                "https://github.com/XTLS/Xray-core/releases/download/${ver}/${zipname}" \
                /tmp/xray_compat.zip || \
            { log_warn "下载 ${ver} 失败，尝试下一版本..."; continue; }
            extract_zip_file /tmp/xray_compat.zip /usr/local/bin xray || \
                { rm -f /tmp/xray_compat.zip; log_warn "缺少可用的 zip 解包工具，尝试下一版本..."; continue; }
        chmod +x /usr/local/bin/xray
        rm -f /tmp/xray_compat.zip
        if /usr/local/bin/xray x25519 &>/dev/null; then
            log_info "Xray ${ver} 安装完成（ARMv8 兼容）"
            return 0
        fi
        log_warn "Xray ${ver} 仍不兼容（SIGILL），尝试更旧版本..."
    done
    log_error "所有兼容版本均安装失败"
    exit 1
}

install_xray() {
    if check_xray; then
        if /usr/local/bin/xray x25519 &>/dev/null; then
            log_info "Xray 已存在且兼容，跳过"
            return 0
        fi
        log_warn "当前 Xray 与 CPU 不兼容（SIGILL），安装兼容版本..."
        install_compat_xray
    else
        # 官方安装脚本内部使用 curl，无 curl 时直接走兼容版本路径
        if command -v curl &>/dev/null; then
            log_info "安装 Xray（最新版）..."
            local installer
            installer=$(mktemp /tmp/xray_install.XXXXXX.sh)
            if download_file "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" "$installer"; then
                bash "$installer" @ install 2>/dev/null
                rm -f "$installer"
                if /usr/local/bin/xray x25519 &>/dev/null; then
                    return 0
                fi
                log_warn "最新版本不兼容当前 CPU（SIGILL），安装兼容版本..."
            else
                rm -f "$installer"
                log_warn "安装脚本下载失败，直接安装兼容版本..."
            fi
        else
            log_info "curl 不可用，跳过官方安装脚本，直接安装兼容版本..."
        fi
        install_compat_xray
    fi
    if ! /usr/local/bin/xray x25519 &>/dev/null; then
        log_error "Xray 安装失败，请检查架构和网络"
        exit 1
    fi
}

open_firewall_port() {
    local port=$1
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "${port}/tcp" >/dev/null 2>&1
        log_info "UFW: 已开放端口 $port/tcp"
    fi
    if command -v iptables &>/dev/null; then
        iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
            iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
        log_info "iptables: 已开放端口 $port/tcp"
    fi
}

uninstall_xray() {
    log_info "停止服务..."
    /etc/init.d/xray stop 2>/dev/null || true
    log_info "删除文件..."
    rm -f /etc/init.d/xray
    rm -f /usr/local/bin/xray
    rm -rf /usr/local/etc/xray
    rm -rf /usr/local/share/xray
    rm -rf /var/log/xray
    rm -f /root/xray_config.txt

    log_info "卸载完成"
}

create_config() {
    local domain=$1 port=$2
    mkdir -p /usr/local/etc/xray /var/log/xray

    cat > /usr/local/etc/xray/config.json << EOFCONFIG
{
  "log": {"loglevel": "warning"},
  "routing": {
    "rules": [
      {"inboundTag": ["api"], "outboundTag": "api", "type": "field"},
      {"ip": ["geoip:private"], "outboundTag": "blocked", "type": "field"},
      {"outboundTag": "blocked", "protocol": ["bittorrent"], "type": "field"}
    ]
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": ${API_PORT},
      "protocol": "dokodemo-door",
      "settings": {"address": "127.0.0.1"},
      "tag": "api"
    },
    {
      "port": ${port},
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "${UUID}", "flow": "xtls-rprx-vision", "level": 0}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${domain}:443",
          "serverNames": ["${domain}"],
          "privateKey": "${PRIVATE_KEY}",
          "publicKey": "${PUBLIC_KEY}",
          "shortIds": ${SHORT_IDS}
        }
      },
      "tag": "vless-in",
      "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "blocked"}
  ],
  "policy": {
    "levels": {"0": {"handshake": 4, "connIdle": 100, "uplinkOnly": 1, "downlinkOnly": 1, "bufferSize": 1024}},
    "system": {"statsInboundDownlink": true, "statsInboundUplink": true}
  },
  "api": {"services": ["HandlerService", "StatsService"], "tag": "api"},
  "stats": {}
}
EOFCONFIG
}

create_init_script() {
    if [ -f /etc/init.d/xray ]; then
        return 0
    fi
    cat > /etc/init.d/xray << 'EOF'
#!/bin/bash
PIDFILE=/var/run/xray.pid
CONFIG=/usr/local/etc/xray/config.json
LOGFILE=/var/log/xray/xray.log
mkdir -p /var/log/xray
case "$1" in
    start)
        [ -f $PIDFILE ] && kill -0 $(cat $PIDFILE) 2>/dev/null && { echo "已运行"; exit 1; }
        /usr/local/bin/xray run -c $CONFIG > $LOGFILE 2>&1 &
        echo $! > $PIDFILE
        sleep 1
        kill -0 $(cat $PIDFILE) 2>/dev/null && echo "已启动 (PID: $(cat $PIDFILE))" || { echo "失败"; cat $LOGFILE; exit 1; }
        ;;
    stop) [ -f $PIDFILE ] && { kill $(cat $PIDFILE) 2>/dev/null; rm -f $PIDFILE; echo "已停止"; } || echo "未运行" ;;
    restart) $0 stop; sleep 1; $0 start ;;
    status) [ -f $PIDFILE ] && kill -0 $(cat $PIDFILE) 2>/dev/null && { echo "运行中 (PID: $(cat $PIDFILE))"; exit 0; } || { echo "未运行"; exit 1; } ;;
    *) echo "用法：$0 {start|stop|restart|status}"; exit 1 ;;
esac
EOF
    chmod +x /etc/init.d/xray
}

generate_links() {
    local ip=$1 port=$2 domain=$3
    UUID=$(jq -r '.inbounds[1].settings.clients[0].id' /usr/local/etc/xray/config.json)
    PUBKEY=$(jq -r '.inbounds[1].streamSettings.realitySettings.publicKey' /usr/local/etc/xray/config.json)
    SHORTID=$(jq -r '.inbounds[1].streamSettings.realitySettings.shortIds[1]' /usr/local/etc/xray/config.json)

    local LINK="vless://${UUID}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${domain}&fp=chrome&pbk=${PUBKEY}&sid=${SHORTID}&type=tcp#VLESS-${port}"

    echo ""
    echo "=========================================="
    echo "      Xray VLESS Reality 完成"
    echo "=========================================="
    echo "服务器 IPv4: ${ip}  端口：${port}  域名：${domain}"
    echo "PublicKey: ${PUBKEY}"
    echo ""
    echo "客户端链接:"
    echo "$LINK"
    echo ""
    qrencode -t ANSIUTF8 "$LINK" 2>/dev/null || log_warn "qrencode 未安装"

    cat > /root/xray_config.txt << EOFSAVE
=== Xray VLESS Reality ===
服务器 IPv4: ${ip}
端口：${port}
域名：${domain}
UUID: ${UUID}
PublicKey: ${PUBKEY}
ShortId: ${SHORTID}

链接:
${LINK}
EOFSAVE
    echo "配置已保存到：/root/xray_config.txt"
}

add_port() {
    local new_port=$1
    if [ -z "$new_port" ]; then
        log_error "用法：$0 add_port <端口号>"
        exit 1
    fi
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        log_error "端口号无效（范围 1-65535）"
        exit 1
    fi
    if [ ! -f /usr/local/etc/xray/config.json ]; then
        log_error "配置不存在，请先执行 install"
        exit 1
    fi
    # 检查端口是否已存在
    if jq -e ".inbounds[] | select(.port == $new_port)" /usr/local/etc/xray/config.json &>/dev/null; then
        log_error "端口 $new_port 已存在于配置中"
        exit 1
    fi
    local domain
    domain=$(jq -r '.inbounds[1].streamSettings.realitySettings.serverNames[0]' /usr/local/etc/xray/config.json)
    local new_uuid
    new_uuid=$(cat /proc/sys/kernel/random/uuid)
    # 重新生成一对新密钥
    generate_keys
    cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak.$(date +%Y%m%d%H%M%S)
    # 拼接新 inbound JSON
    local new_inbound
    new_inbound=$(cat << EOFJSON
{
  "port": ${new_port},
  "protocol": "vless",
  "settings": {
    "clients": [{"id": "${new_uuid}", "flow": "xtls-rprx-vision", "level": 0}],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "${domain}:443",
      "serverNames": ["${domain}"],
      "privateKey": "${PRIVATE_KEY}",
      "publicKey": "${PUBLIC_KEY}",
      "shortIds": ${SHORT_IDS}
    }
  },
  "tag": "vless-in-${new_port}",
  "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
}
EOFJSON
)
    jq ".inbounds += [${new_inbound}]" \
        /usr/local/etc/xray/config.json > /tmp/x.json && \
        mv /tmp/x.json /usr/local/etc/xray/config.json
    open_firewall_port "$new_port"
    /etc/init.d/xray restart
    sleep 1
    local pub_ip
    pub_ip=$(get_public_ipv4)
    local LINK="vless://${new_uuid}@${pub_ip}:${new_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${domain}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#VLESS-${new_port}"
    echo ""
    log_info "端口 $new_port 已添加"
    echo "UUID:      $new_uuid"
    echo "PublicKey: $PUBLIC_KEY"
    echo "ShortId:   $SHORT_ID"
    echo ""
    echo "客户端链接:"
    echo "$LINK"
    qrencode -t ANSIUTF8 "$LINK" 2>/dev/null || true
}

add_user() {
    if [ -z "$1" ]; then
        log_error "用法：$0 add <用户名>"
        exit 1
    fi
    if [ ! -f /usr/local/etc/xray/config.json ]; then
        log_error "配置不存在"
        exit 1
    fi
    local new_uuid=$(cat /proc/sys/kernel/random/uuid)
    cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak.$(date +%Y%m%d%H%M%S)
    jq ".inbounds[1].settings.clients += [{\"id\": \"${new_uuid}\", \"flow\": \"xtls-rprx-vision\", \"level\": 0, \"email\": \"$1\"}]" \
        /usr/local/etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /usr/local/etc/xray/config.json
    /etc/init.d/xray restart
    log_info "用户 $1 已添加"
    echo "UUID: $new_uuid"
}

list_users() {
    if [ ! -f /usr/local/etc/xray/config.json ]; then
        log_error "配置不存在"
        exit 1
    fi
    log_info "用户列表:"
    jq -r '.inbounds[1].settings.clients[] | "UUID: \(.id) | 备注：\(.email // "N/A")"' /usr/local/etc/xray/config.json
}

# TCP 端口可达性测试（多方法，不依赖 HTTP）
tcp_reachable() {
    local host=$1 port=$2
    # 方法1: nc
    if command -v nc &>/dev/null; then
        nc -z -w5 "$host" "$port" 2>/dev/null && return 0
    fi
    # 方法2: bash /dev/tcp 内置
    timeout 5 bash -c "exec 3<>/dev/tcp/${host}/${port}" 2>/dev/null && return 0
    # 方法3: curl telnet（仅测 TCP 握手，非 HTTP）
    if command -v curl &>/dev/null; then
        local rc
        curl -s --connect-timeout 5 --max-time 6 "telnet://${host}:${port}" 2>/dev/null
        rc=$?
        # 7=连接拒绝, 28=超时, 其他均表示 TCP 握手成功
        [ $rc -ne 7 ] && [ $rc -ne 28 ] && return 0
    fi
    return 1
}

diag() {
    echo ""
    echo -e "  ${COLOR_GREEN}══════════════ Xray 诊断 ══════════════${COLOR_NC}"

    # 1. 进程状态
    echo -e "  ${COLOR_YELLOW}▸ 进程${COLOR_NC}"
    if [ -f /var/run/xray.pid ] && kill -0 "$(cat /var/run/xray.pid)" 2>/dev/null; then
        local pid ver
        pid=$(cat /var/run/xray.pid)
        ver=$(/usr/local/bin/xray version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1)
        echo -e "    ${COLOR_GREEN}● 运行中${COLOR_NC}  PID: ${pid}  版本: ${ver:-未知}"
    else
        echo -e "    ${COLOR_RED}● 未运行${COLOR_NC}"
        echo    "    → 启动: /etc/init.d/xray start"
        [ -f /var/log/xray/xray.log ] && echo "    → 日志: $(tail -1 /var/log/xray/xray.log)"
    fi

    [ ! -f /usr/local/etc/xray/config.json ] && { echo ""; log_error "配置文件不存在"; echo ""; return; }

    # 2. 公网 IP
    echo ""
    echo -e "  ${COLOR_YELLOW}▸ 网络${COLOR_NC}"
    local pub_ip
    pub_ip=$(get_public_ipv4)
    if [ -n "$pub_ip" ]; then
        echo -e "    公网 IP: ${COLOR_GREEN}${pub_ip}${COLOR_NC}"
    else
        echo -e "    公网 IP: ${COLOR_RED}获取失败${COLOR_NC}"
    fi

    # 3. 逐端口检查
    echo ""
    echo -e "  ${COLOR_YELLOW}▸ 端口检查${COLOR_NC}"
    while IFS= read -r inbound; do
        local port domain
        port=$(echo "$inbound" | jq -r '.port')
        domain=$(echo "$inbound" | jq -r '.streamSettings.realitySettings.serverNames[0] // "N/A"')

        # 本机监听
        local listen_ok=0
        if ss -tlnp 2>/dev/null | grep -q ":${port}[^0-9]" || \
           netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
            listen_ok=1
        fi

        # iptables 放行
        local fw_msg
        if command -v iptables &>/dev/null; then
            if iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
                fw_msg="iptables ${COLOR_GREEN}✓${COLOR_NC}"
            else
                iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
                fw_msg="iptables ${COLOR_YELLOW}⚡已自动放行${COLOR_NC}"
            fi
        else
            fw_msg="iptables N/A"
        fi

        # 公网 TCP 连通性
        local net_ok=0 net_msg
        if [ -n "$pub_ip" ]; then
            if tcp_reachable "$pub_ip" "$port"; then
                net_ok=1
            fi
        fi

        # 输出
        printf "  ┌ 端口 %-6s  域名: %s\n" "$port" "$domain"
        if [ $listen_ok -eq 1 ]; then
            echo -e "  │ 本机监听  ${COLOR_GREEN}✓ 正常${COLOR_NC}  │  ${fw_msg}"
        else
            echo -e "  │ 本机监听  ${COLOR_RED}✗ 未监听${COLOR_NC}（服务未启动）  │  ${fw_msg}"
        fi
        if [ $net_ok -eq 1 ]; then
            echo -e "  └ 公网连通  ${COLOR_GREEN}✓ 可达${COLOR_NC}"
        else
            echo -e "  └ 公网连通  ${COLOR_RED}✗ 不可达${COLOR_NC}  ← 请在云控制台安全组开放 TCP ${port}"
        fi
        echo ""
    done < <(jq -c '.inbounds[] | select(.protocol=="vless")' /usr/local/etc/xray/config.json)

    # 4. 最近日志
    echo -e "  ${COLOR_YELLOW}▸ 最近日志（最后 8 行）${COLOR_NC}"
    if [ -f /var/log/xray/xray.log ] && [ -s /var/log/xray/xray.log ]; then
        tail -8 /var/log/xray/xray.log | sed 's/^/    /'
    else
        echo "    （日志为空或不存在）"
    fi

    echo ""
    echo -e "  ${COLOR_GREEN}══════════════════════════════════════${COLOR_NC}"
    echo ""
}

list_ports() {
    if [ ! -f /usr/local/etc/xray/config.json ]; then
        log_error "配置不存在"
        exit 1
    fi
    local pub_ip
    pub_ip=$(get_public_ipv4)

    local count
    count=$(jq '[.inbounds[] | select(.protocol == "vless")] | length' /usr/local/etc/xray/config.json)
    echo ""
    echo "========================================="
    echo "       共 ${count} 个 VLESS 入站端口"
    echo "========================================="

    local i=0
    while IFS= read -r inbound; do
        i=$((i + 1))
        local port uuid pubkey shortid domain
        port=$(echo "$inbound"    | jq -r '.port')
        uuid=$(echo "$inbound"    | jq -r '.settings.clients[0].id')
        pubkey=$(echo "$inbound"  | jq -r '.streamSettings.realitySettings.publicKey')
        shortid=$(echo "$inbound" | jq -r '.streamSettings.realitySettings.shortIds[1]')
        domain=$(echo "$inbound"  | jq -r '.streamSettings.realitySettings.serverNames[0]')
        local LINK="vless://${uuid}@${pub_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${domain}&fp=chrome&pbk=${pubkey}&sid=${shortid}&type=tcp#VLESS-${port}"
        echo ""
        echo "--- 端口 #${i}: ${port} ---"
        echo "域名: ${domain}"
        echo "UUID:      ${uuid}"
        echo "PublicKey: ${pubkey}"
        echo "ShortId:   ${shortid}"
        echo ""
        echo "链接: ${LINK}"
        qrencode -t ANSIUTF8 "$LINK" 2>/dev/null || true
    done < <(jq -c '.inbounds[] | select(.protocol == "vless")' /usr/local/etc/xray/config.json)
    echo ""
    echo "========================================="
    echo ""
}

show_link() {
    if [ ! -f /usr/local/etc/xray/config.json ]; then
        log_error "配置不存在"
        exit 1
    fi
    local ip=$(get_public_ipv4)
    if [ -z "$ip" ]; then
        log_error "无法获取 IP"
        exit 1
    fi
    local uuid=$(jq -r '.inbounds[1].settings.clients[0].id' /usr/local/etc/xray/config.json)
    local port=$(jq -r '.inbounds[1].port' /usr/local/etc/xray/config.json)
    local domain=$(jq -r '.inbounds[1].streamSettings.realitySettings.serverNames[0]' /usr/local/etc/xray/config.json)
    local pubkey=$(jq -r '.inbounds[1].streamSettings.realitySettings.publicKey' /usr/local/etc/xray/config.json)
    local shortid=$(jq -r '.inbounds[1].streamSettings.realitySettings.shortIds[1]' /usr/local/etc/xray/config.json)
    local LINK="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${domain}&fp=chrome&pbk=${pubkey}&sid=${shortid}&type=tcp#VLESS-${port}"
    echo "$LINK"
    qrencode -t ANSIUTF8 "$LINK" 2>/dev/null
}

reinstall() {
    log_warn "即将卸载并重新安装 Xray"
    log_warn "现有配置和用户将被清空！"
    if [ -t 0 ]; then
        read -p "确认继续？(y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "取消操作"
            exit 0
        fi
    fi

    uninstall_xray
    sleep 2

    DOMAIN=$(random_domain)
    log_info "随机域名：$DOMAIN"
    check_deps
    install_xray
    check_geoip
    generate_keys
    UUID=$(cat /proc/sys/kernel/random/uuid)
    create_config "$DOMAIN" "$VLESS_PORT"
    create_init_script
    open_firewall_port "$VLESS_PORT"
    log_info "启动 Xray..."
    /etc/init.d/xray start
    sleep 2
    if ! /etc/init.d/xray status; then
        log_error "启动失败"
        tail -5 /var/log/xray/xray.log
        exit 1
    fi
    generate_links "$SERVER_IP" "$VLESS_PORT" "$DOMAIN"
}

update_config() {
    if [ ! -f /usr/local/etc/xray/config.json ]; then
        log_error "配置不存在"
        exit 1
    fi
    log_info "重新生成配置..."
    DOMAIN=$(random_domain)
    log_info "新域名：$DOMAIN"
    cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak.$(date +%Y%m%d%H%M%S)
    generate_keys
    UUID=$(cat /proc/sys/kernel/random/uuid)
    VLESS_PORT=$(jq -r '.inbounds[1].port' /usr/local/etc/xray/config.json)
    create_config "$DOMAIN" "$VLESS_PORT"
    open_firewall_port "$VLESS_PORT"
    /etc/init.d/xray restart
    sleep 2
    if ! /etc/init.d/xray status; then
        log_error "启动失败"
        tail -5 /var/log/xray/xray.log
        exit 1
    fi
    generate_links "$SERVER_IP" "$VLESS_PORT" "$DOMAIN"
}

show_menu() {
    clear
    echo -e "${COLOR_GREEN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║       Xray VLESS Reality 管理脚本         ║"
    echo "  ║       https://github.com/your/repo        ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${COLOR_NC}"

    # 服务状态
    if [ -f /var/run/xray.pid ] && kill -0 "$(cat /var/run/xray.pid)" 2>/dev/null; then
        local pid; pid=$(cat /var/run/xray.pid)
        local ver; ver=$(/usr/local/bin/xray version 2>/dev/null | head -1 | awk '{print $2}')
        echo -e "  状态: ${COLOR_GREEN}● 运行中${COLOR_NC}  PID: ${pid}  版本: ${ver:-未知}"
    elif [ -f /usr/local/bin/xray ]; then
        echo -e "  状态: ${COLOR_RED}● 已停止${COLOR_NC}"
    else
        echo -e "  状态: ${COLOR_YELLOW}● 未安装${COLOR_NC}"
    fi

    # 端口概览
    if [ -f /usr/local/etc/xray/config.json ]; then
        local ports; ports=$(jq -r '[.inbounds[] | select(.protocol=="vless") | .port | tostring] | join("  ")' /usr/local/etc/xray/config.json 2>/dev/null)
        [ -n "$ports" ] && echo -e "  端口: ${COLOR_YELLOW}${ports}${COLOR_NC}"
    fi

    echo ""
    echo -e "  ${COLOR_YELLOW}── 安装管理 ──${COLOR_NC}"
    echo "  1) 安装 Xray"
    echo "  2) 重新安装"
    echo "  3) 更新配置（换域名/密钥）"
    echo "  4) 卸载 Xray"
    echo ""
    echo -e "  ${COLOR_YELLOW}── 端口 & 用户 ──${COLOR_NC}"
    echo "  5) 查看所有端口链接"
    echo "  6) 新增端口"
    echo "  7) 添加用户（到主端口）"
    echo "  8) 查看用户列表"
    echo ""
    echo -e "  ${COLOR_YELLOW}── 服务控制 ──${COLOR_NC}"
    echo "  9) 启动"
    echo "  10) 停止"
    echo "  11) 重启"
    echo "  12) 诊断"
    echo ""
    echo "  0) 退出"
    echo ""
}

interactive_select_port() {
    local prompt=$1
    if [ ! -f /usr/local/etc/xray/config.json ]; then
        log_error "配置不存在"
        return 1
    fi
    local ports=()
    while IFS= read -r p; do ports+=("$p"); done < \
        <(jq -r '.inbounds[] | select(.protocol=="vless") | .port | tostring' /usr/local/etc/xray/config.json)
    if [ ${#ports[@]} -eq 0 ]; then
        log_error "没有找到 VLESS 端口"
        return 1
    fi
    if [ ${#ports[@]} -eq 1 ]; then
        SELECTED_PORT="${ports[0]}"
        return 0
    fi
    echo ""
    echo "$prompt"
    local i=0
    for p in "${ports[@]}"; do
        i=$((i+1))
        echo "  $i) 端口 $p"
    done
    echo "  0) 全部"
    echo ""
    read -rp "请选择 [0-${#ports[@]}]: " sel
    if [[ "$sel" == "0" ]]; then
        SELECTED_PORT="all"
    elif [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#ports[@]}" ]; then
        SELECTED_PORT="${ports[$((sel-1))]}"
    else
        log_warn "输入无效，默认显示全部"
        SELECTED_PORT="all"
    fi
}

show_single_port_link() {
    local target_port=$1
    local pub_ip=$2
    local inbound
    inbound=$(jq -c ".inbounds[] | select(.protocol==\"vless\" and (.port | tostring)==\"${target_port}\")" \
        /usr/local/etc/xray/config.json)
    [ -z "$inbound" ] && { log_error "端口 ${target_port} 不存在"; return 1; }

    local uuid domain pubkey shortid
    uuid=$(echo "$inbound"    | jq -r '.settings.clients[0].id')
    domain=$(echo "$inbound"  | jq -r '.streamSettings.realitySettings.serverNames[0]')
    pubkey=$(echo "$inbound"  | jq -r '.streamSettings.realitySettings.publicKey')
    shortid=$(echo "$inbound" | jq -r '.streamSettings.realitySettings.shortIds[1]')
    local LINK="vless://${uuid}@${pub_ip}:${target_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${domain}&fp=chrome&pbk=${pubkey}&sid=${shortid}&type=tcp#VLESS-${target_port}"

    echo ""
    echo "  ┌─────────────────────────────────────────┐"
    printf  "  │  端口: %-34s│\n" "${target_port}"
    printf  "  │  域名: %-34s│\n" "${domain}"
    echo "  └─────────────────────────────────────────┘"
    echo "  UUID:      ${uuid}"
    echo "  PublicKey: ${pubkey}"
    echo "  ShortId:   ${shortid}"
    echo ""
    echo "  链接:"
    echo "  ${LINK}"
    echo ""
    qrencode -t ANSIUTF8 "$LINK" 2>/dev/null || true
}

list_ports() {
    if [ ! -f /usr/local/etc/xray/config.json ]; then
        log_error "配置不存在"
        exit 1
    fi
    local pub_ip
    pub_ip=$(get_public_ipv4)

    # 如果是交互调用，先让用户选
    if [ -t 0 ]; then
        interactive_select_port "选择要查看的端口："
    else
        SELECTED_PORT="all"
    fi

    local count
    count=$(jq '[.inbounds[] | select(.protocol == "vless")] | length' /usr/local/etc/xray/config.json)
    echo ""
    echo "  ═══════════════════════════════════════════"
    echo "       IP: ${pub_ip}   共 ${count} 个端口"
    echo "  ═══════════════════════════════════════════"

    if [ "$SELECTED_PORT" == "all" ]; then
        while IFS= read -r p; do
            show_single_port_link "$p" "$pub_ip"
        done < <(jq -r '.inbounds[] | select(.protocol=="vless") | .port | tostring' /usr/local/etc/xray/config.json)
    else
        show_single_port_link "$SELECTED_PORT" "$pub_ip"
    fi

    echo "  ═══════════════════════════════════════════"
    echo ""
}

run_menu() {
    while true; do
        show_menu
        read -rp "  请输入选项: " choice
        echo ""
        case "$choice" in
            1)
                check_deps; install_xray; check_geoip
                generate_keys
                DOMAIN=$(random_domain)
                UUID=$(cat /proc/sys/kernel/random/uuid)
                create_config "$DOMAIN" "$VLESS_PORT"
                create_init_script
                open_firewall_port "$VLESS_PORT"
                /etc/init.d/xray start
                sleep 2
                /etc/init.d/xray status && \
                    generate_links "$SERVER_IP" "$VLESS_PORT" "$DOMAIN" || \
                    { log_error "启动失败"; tail -5 /var/log/xray/xray.log; }
                ;;
            2) reinstall ;;
            3) update_config ;;
            4)
                read -rp "  确认卸载？(y/N): " c
                [[ "$c" == "y" || "$c" == "Y" ]] && uninstall_xray || log_info "取消"
                ;;
            5) list_ports ;;
            6)
                read -rp "  输入新端口号: " np
                add_port "$np"
                ;;
            7)
                read -rp "  输入用户名/备注: " un
                add_user "$un"
                ;;
            8) list_users ;;
            9)  /etc/init.d/xray start ;;
            10) /etc/init.d/xray stop ;;
            11) /etc/init.d/xray restart ;;
            12) diag ;;
            0)  echo "  再见！"; exit 0 ;;
            *)  log_warn "无效选项" ;;
        esac
        echo ""
        read -rp "  按 Enter 返回菜单..." _
    done
}

main() {
    check_root

    # 无参数 → 交互菜单（查看链接类命令不需要获取 IP）
    if [ $# -eq 0 ]; then
        # 菜单中涉及安装/状态时才检查 IP，这里先进入菜单
        run_menu
        exit 0
    fi

    # 有参数 → 直接执行（非交互模式）
    case "$1" in
        install|reinstall|update|uninstall|add_port|add|diag|restart|status|stop)
            check_ipv4 ;;
    esac

    case "$1" in
        install)
            DOMAIN=$(random_domain)
            log_info "随机域名：$DOMAIN"
            check_deps
            install_xray
            check_geoip
            generate_keys
            UUID=$(cat /proc/sys/kernel/random/uuid)
            create_config "$DOMAIN" "$VLESS_PORT"
            create_init_script
            open_firewall_port "$VLESS_PORT"
            log_info "启动 Xray..."
            /etc/init.d/xray start
            sleep 2
            if ! /etc/init.d/xray status; then
                log_error "启动失败"
                tail -5 /var/log/xray/xray.log
                exit 1
            fi
            generate_links "$SERVER_IP" "$VLESS_PORT" "$DOMAIN"
            ;;
        reinstall)  reinstall ;;
        update)     update_config ;;
        uninstall)  uninstall_xray ;;
        add)        add_user "$2" ;;
        add_port)   add_port "$2" ;;
        list)       list_users ;;
        link)       show_link ;;
        ports)      list_ports ;;
        diag)       diag ;;
        restart)    /etc/init.d/xray restart ;;
        status)     /etc/init.d/xray status ;;
        stop)       /etc/init.d/xray stop ;;
        *)
            echo "用法：$0 {install|reinstall|update|uninstall|add|add_port|list|ports|link|diag|restart|status|stop}"
            echo "      $0         （无参数进入交互菜单）"
            exit 1
            ;;
    esac
}

main "$@"
