#!/bin/bash

# Hysteria2 节点信息显示脚本

# 从配置文件解析信息
parse_config_info() {
    local config_file="$CONFIG_PATH"
    local node_info=()
    
    if [[ ! -f "$config_file" ]]; then
        echo "配置文件不存在"
        return 1
    fi
    
    # 解析监听端口
    local port=$(grep -E "^listen:" "$config_file" | awk '{print $2}' | sed 's/://')
    if [[ -z "$port" ]]; then
        port="443"
    fi
    
    # 解析认证密码
    local auth_password=$(grep -A 2 "^auth:" "$config_file" | grep "password:" | awk '{print $2}')
    
    # 解析混淆密码
    local obfs_password=""
    if grep -q "^obfs:" "$config_file"; then
        obfs_password=$(grep -A 3 "^obfs:" "$config_file" | grep "password:" | awk '{print $2}')
    fi
    
    # 解析伪装域名
    local masquerade_url=$(grep -A 3 "masquerade:" "$config_file" | grep "url:" | awk '{print $2}')
    local sni_domain=""
    if [[ -n "$masquerade_url" ]]; then
        sni_domain=$(echo "$masquerade_url" | sed 's|https\?://||' | sed 's|/.*||')
    fi
    
    # 检查证书类型
    local cert_type="ACME"
    local insecure="false"
    if grep -q "^tls:" "$config_file"; then
        cert_type="自签名"
        insecure="true"
    fi
    
    echo "$port|$auth_password|$obfs_password|$sni_domain|$cert_type|$insecure"
}

# 获取服务器域名配置
get_server_domain() {
    if [[ -f "/etc/hysteria/server-domain.conf" ]]; then
        cat "/etc/hysteria/server-domain.conf"
    else
        echo ""
    fi
}

# 获取服务器IP
get_current_server_ip() {
    local ip=""

    # 尝试多种方法获取公网IP
    ip=$(curl -s --connect-timeout 5 ipv4.icanhazip.com 2>/dev/null) || \
    ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null) || \
    ip=$(curl -s --connect-timeout 5 ip.sb 2>/dev/null) || \
    ip=$(curl -s --connect-timeout 5 checkip.amazonaws.com 2>/dev/null)

    if [[ -n "$ip" && "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
    else
        # 如果无法获取公网IP，尝试获取本地IP
        ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')
        echo "${ip:-127.0.0.1}"
    fi
}

# 获取服务器地址（优先使用域名）
get_server_address() {
    local configured_domain=$(get_server_domain)

    if [[ -n "$configured_domain" ]]; then
        echo "$configured_domain"
    else
        get_current_server_ip
    fi
}

# 获取端口跳跃信息
get_port_hopping_info() {
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        source "/etc/hysteria/port-hopping.conf"
        echo "$START_PORT-$END_PORT"
    else
        echo "未配置"
    fi
}

# 生成节点链接
generate_node_link() {
    local server_ip="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"
    
    local link="hysteria2://$auth_password@$server_ip:$port"
    local params=""
    
    if [[ -n "$sni_domain" ]]; then
        params="${params}&sni=$sni_domain"
    fi
    
    if [[ "$insecure" == "true" ]]; then
        params="${params}&insecure=1"
    fi
    
    if [[ -n "$obfs_password" ]]; then
        params="${params}&obfs=salamander&obfs-password=$obfs_password"
    fi
    
    # 移除开头的&
    params="${params#&}"
    
    if [[ -n "$params" ]]; then
        link="${link}?${params}"
    fi
    
    link="${link}#Hysteria2-Server"
    
    echo "$link"
}


# 生成 Clash 配置
generate_clash_config() {
    local server_address="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"
    local port_hopping="$7"

    cat << EOF
# Clash 配置片段 (Hysteria2)
proxies:
  - name: "Hysteria2-Server"
    type: hysteria2
    server: $server_address
    port: $port
    password: $auth_password
EOF
    
    # 添加端口跳跃配置
    if [[ -n "$port_hopping" && "$port_hopping" != "未配置" ]]; then
        # 提取纯净的端口范围格式（如果包含描述则提取端口范围部分）
        local port_range=$(echo "$port_hopping" | grep -oE '[0-9]+-[0-9]+' | head -1)
        if [[ -n "$port_range" ]]; then
            cat << EOF
    ports: $port_range
EOF
        fi
    fi
    
    if [[ -n "$obfs_password" ]]; then
        cat << EOF
    obfs: salamander
    obfs-password: "$obfs_password"
EOF
    fi
    
    if [[ -n "$sni_domain" ]]; then
        cat << EOF
    sni: $sni_domain
EOF
    fi
    
    if [[ "$insecure" == "true" ]]; then
        cat << EOF
    skip-cert-verify: true
EOF
    fi
    
    cat << EOF
    alpn:
      - h3
EOF
}

# 生成 SingBox 配置
generate_singbox_config() {
    local server_address="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"

    cat << EOF
# SingBox 配置片段 (Hysteria2 Outbound)
{
  "type": "hysteria2",
  "tag": "Hysteria2-Server",
  "server": "$server_address",
  "server_port": $port,
  "password": "$auth_password",
EOF
    
    if [[ -n "$obfs_password" ]]; then
        cat << EOF
  "obfs": {
    "type": "salamander",
    "password": "$obfs_password"
  },
EOF
    fi
    
    cat << EOF
  "tls": {
        "enabled": true,
EOF
    
    if [[ -n "$sni_domain" ]]; then
        cat << EOF
    "server_name": "$sni_domain",
EOF
    fi
    
    if [[ "$insecure" == "true" ]]; then
        cat << EOF
    "insecure": true,
EOF
    else
        cat << EOF
    "insecure": false,
EOF
    fi
    
    cat << EOF
    "alpn": ["h3"]
  }
}
EOF
}

# 生成 SingBox PC端配置（带inbounds）
generate_singbox_pc_config() {
    local server_address="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"

    cat << EOF
# SingBox PC端完整配置 (Hysteria2)
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "8.8.8.8"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "rule_set": "geosite-cn",
        "server": "local"
      }
    ]
  },
  "inbounds": [
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 1080,
      "sniff": true,
      "users": []
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "Hysteria2-Server",
      "server": "$server_address",
      "server_port": $port,
      "password": "$auth_password",
EOF
    
    if [[ -n "$obfs_password" ]]; then
        cat << EOF
      "obfs": {
        "type": "salamander",
        "password": "$obfs_password"
      },
EOF
    fi
    
    cat << EOF
      "tls": {
        "enabled": true,
EOF
    
    if [[ -n "$sni_domain" ]]; then
        cat << EOF
        "server_name": "$sni_domain",
EOF
    fi
    
    if [[ "$insecure" == "true" ]]; then
        cat << EOF
        "insecure": true,
EOF
    else
        cat << EOF
        "insecure": false,
EOF
    fi
    
    cat << EOF
        "alpn": ["h3"]
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "domain_keyword": ["google", "youtube", "twitter", "facebook", "github"],
        "outbound": "Hysteria2-Server"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "geoip-cn",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs",
        "download_detour": "Hysteria2-Server"
      },
      {
        "type": "remote",
        "tag": "geosite-cn",
        "format": "binary", 
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs",
        "download_detour": "Hysteria2-Server"
      }
    ],
    "final": "Hysteria2-Server",
    "auto_detect_interface": true
  }
}
EOF
}

# 生成客户端配置
generate_client_config() {
    local server_address="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"

    cat << EOF
# Hysteria2 官方客户端配置
server: $server_address:$port
auth: $auth_password

tls:
  sni: $sni_domain
  insecure: $insecure

EOF
    
    if [[ -n "$obfs_password" ]]; then
        cat << EOF
obfs:
  type: salamander
  salamander:
    password: $obfs_password

EOF
    fi
    
    cat << EOF
socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:8080

bandwidth:
  up: 100 mbps
  down: 100 mbps

# 可选: UDP 转发
# udpForwarding:
#   - listen: 127.0.0.1:5353
#     remote: 8.8.8.8:53

# 可选: TCP 转发
# tcpForwarding:
#   - listen: 127.0.0.1:6666
#     remote: www.google.com:80
EOF
}


# 显示节点信息
display_node_info() {
    echo -e "${BLUE}Hysteria2 节点信息${NC}"
    echo ""
    
    # 检查服务状态
    if ! systemctl is-active --quiet hysteria-server.service; then
        echo -e "${RED}警告: Hysteria2 服务未运行${NC}"
        echo "请先启动服务"
        echo ""
        return
    fi
    
    # 检查配置文件
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        return
    fi
    
    # 获取服务器信息
    local server_address=$(get_server_address)
    local server_ip=$(get_current_server_ip)
    local configured_domain=$(get_server_domain)
    local config_info=$(parse_config_info)

    if [[ -z "$config_info" ]]; then
        echo -e "${RED}错误: 无法解析配置文件${NC}"
        return
    fi

    # 解析配置信息
    IFS='|' read -r port auth_password obfs_password sni_domain cert_type insecure <<< "$config_info"

    # 获取端口跳跃信息
    local port_hopping=$(get_port_hopping_info)

    # 显示基本信息
    echo -e "${CYAN}=== 服务器信息 ===${NC}"
    if [[ -n "$configured_domain" ]]; then
        echo -e "${YELLOW}服务器域名:${NC} $configured_domain:$port"
        echo -e "${YELLOW}服务器IP:${NC} $server_ip:$port"
    else
        echo -e "${YELLOW}服务器地址:${NC} $server_ip:$port"
    fi
    echo -e "${YELLOW}认证密码:${NC} $auth_password"
    if [[ -n "$obfs_password" ]]; then
        echo -e "${YELLOW}混淆密码:${NC} $obfs_password"
        echo -e "${YELLOW}混淆类型:${NC} Salamander"
    else
        echo -e "${YELLOW}混淆配置:${NC} 未启用"
    fi
    echo -e "${YELLOW}SNI域名:${NC} ${sni_domain:-未设置}"
    echo -e "${YELLOW}证书类型:${NC} $cert_type"
    echo -e "${YELLOW}端口跳跃:${NC} $port_hopping"
    echo ""

    # 生成链接（使用服务器地址）
    local node_link=$(generate_node_link "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure")
    
    while true; do
        echo -e "${CYAN}=== 节点信息选项 ===${NC}"
        echo -e "${GREEN}1.${NC} 节点链接"
        echo -e "${GREEN}2.${NC} 订阅信息"
        echo -e "${GREEN}3.${NC} 客户端配置"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-3]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                show_node_links "$node_link"
                ;;
            2)
                show_subscription_info "$node_link" "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure"
                ;;
            3)
                show_client_configs "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选项${NC}"
                sleep 1
                ;;
        esac
    done
}

# 显示节点链接
show_node_links() {
    local node_link="$1"
    
    clear
    echo -e "${CYAN}=== 节点链接 ===${NC}"
    echo ""
    
    # 显示 Hysteria2 节点链接
    echo -e "${YELLOW}Hysteria2 节点链接:${NC}"
    echo "$node_link"
    echo ""
    
    echo -e "${BLUE}使用说明:${NC}"
    echo "• 复制上方链接到支持 Hysteria2 的客户端"
    echo "• 推荐客户端：v2rayNG (Android)、ShadowRocket (iOS)"
    echo "• 也可以手动输入到客户端的添加节点功能中"
    echo ""
}

# 生成订阅文件并创建web访问链接
generate_subscription_files() {
    local node_link="$1"
    local server_address="$2"
    local port="$3"
    local auth_password="$4"
    local obfs_password="$5"
    local sni_domain="$6"
    local insecure="$7"
    
    local server_ip=$(get_current_server_ip)
    local configured_domain=$(get_server_domain)
    local server_host=""
    
    # 优先使用配置的域名，否则使用IP
    if [[ -n "$configured_domain" ]]; then
        server_host="$configured_domain"
        echo -e "${GREEN}使用配置的服务器域名: $configured_domain${NC}"
    else
        server_host="$server_ip"
        echo -e "${YELLOW}使用服务器IP地址: $server_ip${NC}"
    fi
    
    local sub_dir="/var/www/html/sub"
    local timestamp=$(date +%s)
    local uuid=$(openssl rand -hex 8)
    
    # 创建订阅文件目录
    mkdir -p "$sub_dir"
    
    # 生成不同格式的订阅文件
    local hysteria2_sub="$sub_dir/hysteria2-${uuid}.txt"
    local clash_sub="$sub_dir/clash-${uuid}.yaml"
    local singbox_sub="$sub_dir/singbox-${uuid}.json"
    local singbox_pc_sub="$sub_dir/singbox-pc-${uuid}.json"
    local base64_sub="$sub_dir/base64-${uuid}.txt"
    
    # 1. Hysteria2 原生订阅格式
    echo "$node_link" > "$hysteria2_sub"
    
    # 2. Base64编码订阅 (通用格式，兼容v2rayNG等客户端)
    # 直接对节点链接进行base64编码，不添加注释避免解析问题
    echo "$node_link" | base64 -w 0 > "$base64_sub"
    
    # 获取端口跳跃信息
    local port_hopping=$(get_port_hopping_info)
    
    # 3. Clash订阅格式
    cat > "$clash_sub" << EOF
# Clash 订阅配置
# 更新时间: $(date)
proxies:
  - name: "Hysteria2-Server"
    type: hysteria2
    server: $server_address
    port: $port
    password: $auth_password
EOF
    
    # 添加端口跳跃配置 
    if [[ -n "$port_hopping" && "$port_hopping" != "未配置" ]]; then
        # 提取纯净的端口范围格式（如：20000-50000）
        local port_range=$(echo "$port_hopping" | grep -oE '[0-9]+-[0-9]+' | head -1)
        if [[ -n "$port_range" ]]; then
            cat >> "$clash_sub" << EOF
    ports: $port_range
EOF
        fi
    fi
    
    if [[ -n "$obfs_password" ]]; then
        cat >> "$clash_sub" << EOF
    obfs: salamander
    obfs-password: "$obfs_password"
EOF
    fi
    
    if [[ -n "$sni_domain" ]]; then
        cat >> "$clash_sub" << EOF
    sni: $sni_domain
EOF
    fi
    
    if [[ "$insecure" == "true" ]]; then
        cat >> "$clash_sub" << EOF
    skip-cert-verify: true
EOF
    fi
    
    cat >> "$clash_sub" << EOF
    alpn:
      - h3

proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies:
      - "🔄 自动选择"
      - "Hysteria2-Server"
      - "🎯 全球直连"
  
  - name: "🔄 自动选择"
    type: url-test
    proxies:
      - "Hysteria2-Server"
    url: 'http://www.gstatic.com/generate_204'
    interval: 300
    tolerance: 50
  
  - name: "🌍 国外媒体"
    type: select
    proxies:
      - "🚀 节点选择"
      - "🔄 自动选择"
      - "Hysteria2-Server"
      - "🎯 全球直连"
  
  - name: "🎯 全球直连"
    type: select
    proxies:
      - "DIRECT"
  
  - name: "🛑 全球拦截"
    type: select
    proxies:
      - "REJECT"
      - "🎯 全球直连"

# 基础分流规则：国内直连，国外走代理
rules:
  # 局域网直连
  - DOMAIN-SUFFIX,local,🎯 全球直连
  - IP-CIDR,192.168.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,10.0.0.0/8,🎯 全球直连,no-resolve
  - IP-CIDR,172.16.0.0/12,🎯 全球直连,no-resolve
  - IP-CIDR,127.0.0.0/8,🎯 全球直连,no-resolve
  - IP-CIDR,100.64.0.0/10,🎯 全球直连,no-resolve
  - IP-CIDR6,::1/128,🎯 全球直连,no-resolve
  - IP-CIDR6,fc00::/7,🎯 全球直连,no-resolve
  - IP-CIDR6,fe80::/10,🎯 全球直连,no-resolve
  
  # 常用国外媒体服务
  - DOMAIN-KEYWORD,youtube,🌍 国外媒体
  - DOMAIN-KEYWORD,google,🌍 国外媒体
  - DOMAIN-KEYWORD,twitter,🌍 国外媒体
  - DOMAIN-KEYWORD,facebook,🌍 国外媒体
  - DOMAIN-KEYWORD,instagram,🌍 国外媒体
  - DOMAIN-KEYWORD,telegram,🌍 国外媒体
  - DOMAIN-KEYWORD,netflix,🌍 国外媒体
  - DOMAIN-KEYWORD,github,🌍 国外媒体
  - DOMAIN-SUFFIX,openai.com,🌍 国外媒体
  - DOMAIN-SUFFIX,chatgpt.com,🌍 国外媒体
  
  # 广告拦截
  - DOMAIN-KEYWORD,ad,🛑 全球拦截
  - DOMAIN-KEYWORD,ads,🛑 全球拦截
  - DOMAIN-KEYWORD,analytics,🛑 全球拦截
  - DOMAIN-KEYWORD,track,🛑 全球拦截
  
  # 国内域名和IP直连
  - GEOIP,CN,🎯 全球直连
  - GEOSITE,CN,🎯 全球直连
  
  # 其他流量走代理
  - MATCH,🚀 节点选择
EOF
    
    # 4. SingBox订阅格式（移动端兼容）
    cat > "$singbox_sub" << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "8.8.8.8"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "rule_set": "geosite-cn",
        "server": "local"
      }
    ]
  },
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "Hysteria2-Server",
      "server": "$server_address",
      "server_port": $port,
      "password": "$auth_password",
EOF
    
    if [[ -n "$obfs_password" ]]; then
        cat >> "$singbox_sub" << EOF
      "obfs": {
        "type": "salamander",
        "password": "$obfs_password"
      },
EOF
    fi
    
    cat >> "$singbox_sub" << EOF
      "tls": {
        "enabled": true,
EOF
    
    if [[ -n "$sni_domain" ]]; then
        cat >> "$singbox_sub" << EOF
        "server_name": "$sni_domain",
EOF
    fi
    
    if [[ "$insecure" == "true" ]]; then
        cat >> "$singbox_sub" << EOF
        "insecure": true,
EOF
    else
        cat >> "$singbox_sub" << EOF
        "insecure": false,
EOF
    fi
    
    cat >> "$singbox_sub" << EOF
        "alpn": ["h3"]
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn", 
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "geoip-cn",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs",
        "download_detour": "Hysteria2-Server"
      },
      {
        "type": "remote",
        "tag": "geosite-cn",
        "format": "binary", 
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs",
        "download_detour": "Hysteria2-Server"
      }
    ],
    "final": "Hysteria2-Server",
    "auto_detect_interface": true
  }
}
EOF
    
    # 5. SingBox PC端配置（带inbounds）
    cat > "$singbox_pc_sub" << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "8.8.8.8"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "rule_set": "geosite-cn",
        "server": "local"
      }
    ]
  },
  "inbounds": [
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 1080,
      "sniff": true,
      "users": []
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "Hysteria2-Server",
      "server": "$server_address",
      "server_port": $port,
      "password": "$auth_password",
EOF
    
    if [[ -n "$obfs_password" ]]; then
        cat >> "$singbox_pc_sub" << EOF
      "obfs": {
        "type": "salamander",
        "password": "$obfs_password"
      },
EOF
    fi
    
    cat >> "$singbox_pc_sub" << EOF
      "tls": {
        "enabled": true,
EOF
    
    if [[ -n "$sni_domain" ]]; then
        cat >> "$singbox_pc_sub" << EOF
        "server_name": "$sni_domain",
EOF
    fi
    
    if [[ "$insecure" == "true" ]]; then
        cat >> "$singbox_pc_sub" << EOF
        "insecure": true,
EOF
    else
        cat >> "$singbox_pc_sub" << EOF
        "insecure": false,
EOF
    fi
    
    cat >> "$singbox_pc_sub" << EOF
        "alpn": ["h3"]
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn", 
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "geoip-cn",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs",
        "download_detour": "Hysteria2-Server"
      },
      {
        "type": "remote",
        "tag": "geosite-cn",
        "format": "binary", 
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs",
        "download_detour": "Hysteria2-Server"
      }
    ],
    "final": "Hysteria2-Server",
    "auto_detect_interface": true
  }
}
EOF
    
    # 设置文件权限
    chmod 644 "$hysteria2_sub" "$clash_sub" "$singbox_sub" "$singbox_pc_sub" "$base64_sub"
    
    # 检查 nginx 或 apache 是否安装，如果没有则提示安装
    if ! command -v nginx &>/dev/null && ! command -v apache2 &>/dev/null && ! command -v httpd &>/dev/null; then
        echo -e "${YELLOW}警告: 未检测到HTTP服务器 (nginx/apache)${NC}"
        echo -e "${BLUE}订阅链接功能需要HTTP服务器支持${NC}"
        echo ""
        echo -n -e "${YELLOW}是否自动安装nginx服务器? [Y/n]: ${NC}"
        read -r install_nginx
        
        if [[ ! $install_nginx =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}正在安装nginx服务器...${NC}"
            local install_success=false
            
            if command -v apt &>/dev/null; then
                if apt update && apt install -y nginx; then
                    systemctl start nginx && systemctl enable nginx
                    install_success=true
                fi
            elif command -v yum &>/dev/null; then
                if yum install -y nginx; then
                    systemctl start nginx && systemctl enable nginx
                    install_success=true
                fi
            elif command -v dnf &>/dev/null; then
                if dnf install -y nginx; then
                    systemctl start nginx && systemctl enable nginx
                    install_success=true
                fi
            fi
            
            if $install_success; then
                echo -e "${GREEN}nginx安装成功!${NC}"
            else
                echo -e "${RED}nginx安装失败${NC}"
                echo -e "${YELLOW}请手动安装HTTP服务器并配置访问 $sub_dir 目录${NC}"
                echo ""
                echo -e "${BLUE}手动配置步骤:${NC}"
                echo "1. 安装nginx: apt install nginx 或 yum install nginx"
                echo "2. 确保nginx可以访问 $sub_dir 目录"
                echo "3. 重启nginx服务"
                echo ""
                return
            fi
        else
            echo -e "${YELLOW}跳过安装HTTP服务器${NC}"
            echo -e "${BLUE}注意: 订阅链接将无法通过HTTP访问${NC}"
            echo -e "${YELLOW}请手动安装HTTP服务器并配置访问 $sub_dir 目录${NC}"
            echo ""
        fi
    fi
    
    # 生成订阅链接 (优先使用域名)
    local hysteria2_url="http://${server_host}/sub/hysteria2-${uuid}.txt"
    local clash_url="http://${server_host}/sub/clash-${uuid}.yaml"
    local singbox_url="http://${server_host}/sub/singbox-${uuid}.json"
    local singbox_pc_url="http://${server_host}/sub/singbox-pc-${uuid}.json"
    local base64_url="http://${server_host}/sub/base64-${uuid}.txt"
    
    echo -e "${GREEN}订阅文件生成成功!${NC}"
    echo ""
    echo -e "${YELLOW}Hysteria2 原生订阅链接:${NC}"
    echo "$hysteria2_url"
    echo ""
    echo -e "${YELLOW}通用Base64订阅链接:${NC}"
    echo "$base64_url"
    echo ""
    echo -e "${YELLOW}Clash 订阅链接:${NC}"
    echo "$clash_url"
    echo ""
    echo -e "${YELLOW}SingBox 移动端订阅链接 (推荐移动设备):${NC}"
    echo "$singbox_url"
    echo ""
    echo -e "${YELLOW}SingBox PC端订阅链接 (适用桌面系统):${NC}"
    echo "$singbox_pc_url"
    echo ""
    echo -e "${BLUE}使用说明:${NC}"
    echo "• 复制相应的订阅链接到客户端的订阅功能"
    echo "• Hysteria2客户端使用原生订阅链接"
    echo "• v2rayNG等客户端可使用Base64订阅链接"
    echo "• Clash客户端使用Clash订阅链接"
    echo "• SingBox移动端：使用移动端订阅链接（避免端口冲突）"
    echo "• SingBox桌面端：使用PC端订阅链接（包含本地代理端口）"
    echo ""
}

# 显示订阅信息
show_subscription_info() {
    local node_link="$1"
    local server_address="$2"
    local port="$3"
    local auth_password="$4"
    local obfs_password="$5"
    local sni_domain="$6"
    local insecure="$7"
    
    clear
    echo -e "${CYAN}=== 订阅信息 ===${NC}"
    echo ""
    
    # 生成订阅文件并获取链接
    generate_subscription_files "$node_link" "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure"
}

# 显示客户端配置
show_client_configs() {
    local server_address="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"
    
    while true; do
        clear
        echo -e "${CYAN}=== 客户端配置 ===${NC}"
        echo ""
        echo -e "${YELLOW}选择客户端配置类型:${NC}"
        echo -e "${GREEN}1.${NC} Hysteria2 官方客户端配置"
        echo -e "${GREEN}2.${NC} Clash 配置"
        echo -e "${GREEN}3.${NC} SingBox 移动端配置 (推荐移动设备)"
        echo -e "${GREEN}4.${NC} SingBox PC端配置 (适用桌面系统)"
        echo -e "${GREEN}5.${NC} 保存所有配置到文件"
        echo -e "${GREEN}6.${NC} 显示推荐客户端列表"
        echo -e "${RED}0.${NC} 返回上级菜单"
        echo ""
        echo -n -e "${BLUE}请选择配置类型 [0-6]: ${NC}"
        read -r config_choice
        
        case $config_choice in
            1)
                clear
                echo -e "${CYAN}=== Hysteria2 官方客户端配置 ===${NC}"
                echo ""
                generate_client_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure"
                echo ""
                echo -e "${BLUE}保存方法:${NC}"
                echo "• 将上方配置保存为 config.yaml 文件"
                echo "• 使用 hysteria2 官方客户端加载配置文件"
                echo ""
                ;;
            2)
                clear
                echo -e "${CYAN}=== Clash 配置 ===${NC}"
                echo ""
                local port_hopping=$(get_port_hopping_info)
                generate_clash_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure" "$port_hopping"
                echo ""
                echo -e "${BLUE}使用方法:${NC}"
                echo "• 将上方配置添加到 Clash 配置文件的 proxies 部分"
                echo "• 推荐客户端：Clash Verge Rev, ClashX Pro"
                echo ""
                ;;
            3)
                clear
                echo -e "${CYAN}=== SingBox 移动端配置 ===${NC}"
                echo ""
                generate_singbox_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure"
                echo ""
                echo -e "${BLUE}使用方法:${NC}"
                echo "• 将上方配置添加到 SingBox 配置文件的 outbounds 部分"
                echo "• 适用于：SingBox Android/iOS 客户端"
                echo "• 特点：无 inbounds 配置，避免端口冲突"
                echo ""
                ;;
            4)
                clear
                echo -e "${CYAN}=== SingBox PC端配置 ===${NC}"
                echo ""
                generate_singbox_pc_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure"
                echo ""
                echo -e "${BLUE}使用方法:${NC}"
                echo "• 完整的 SingBox 配置文件，可直接使用"
                echo "• 适用于：SingBox 桌面客户端"
                echo "• 特点：包含 inbounds 配置，提供本地代理端口"
                echo ""
                ;;
            5)
                save_all_configs_to_file "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure"
                ;;
            6)
                show_recommended_clients
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选项${NC}"
                sleep 1
                ;;
        esac
    done
}

# 保存所有配置到文件
save_all_configs_to_file() {
    local server_address="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"
    
    local output_file="/etc/hysteria/client-configs.txt"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > "$output_file" << EOF
# Hysteria2 客户端配置文件
# 生成时间: $timestamp

=== Hysteria2 官方客户端配置 ===
$(generate_client_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure")

=== Clash 配置 ===
$(local port_hopping=$(get_port_hopping_info); generate_clash_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure" "$port_hopping")

=== SingBox 配置 ===
$(generate_singbox_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure")
EOF

    echo ""
    echo -e "${GREEN}所有客户端配置已保存到: $output_file${NC}"
    echo ""
}

# 显示推荐客户端列表
show_recommended_clients() {
    clear
    echo -e "${CYAN}=== 推荐客户端列表 ===${NC}"
    echo ""
    
    echo -e "${BLUE}🖥️  桌面客户端:${NC}"
    echo -e "${GREEN}推荐:${NC}"
    echo "• Clash Verge Rev - 全平台支持，界面友好"
    echo "• SingBox 官方客户端 - 性能优秀，配置灵活"
    echo ""
    echo -e "${YELLOW}其他选择:${NC}"
    echo "• Clash Meta (ClashX Pro) - 经典选择"
    echo "• Hiddify Next - 多协议支持"
    echo "• NekoRay/NekoBox - 轻量级客户端"
    echo "• v2rayN (Windows) - 简单易用"
    echo "• V2rayU (macOS) - macOS 专用"
    echo ""
    
    echo -e "${BLUE}📱 移动客户端:${NC}"
    echo -e "${GREEN}Android 推荐:${NC}"
    echo "• v2rayNG - 免费开源，功能完整"
    echo "• NekoBox for Android - 轻量级选择"
    echo ""
    echo -e "${GREEN}iOS 推荐:${NC}"
    echo "• ShadowRocket - 付费但功能强大"
    echo "• Stash - 良好的 Clash 支持"
    echo ""
    echo -e "${YELLOW}其他选择:${NC}"
    echo "• SingBox (Android/iOS)"
    echo "• Hiddify Next (Android/iOS)"
    echo "• QuantumultX (iOS)"
    echo "• Loon (iOS)"
    echo ""
    
    echo -e "${BLUE}🌐 路由器/OpenWrt:${NC}"
    echo "• OpenClash - 支持 Hysteria2"
    echo "• SingBox - 官方路由器版本"
    echo "• Clash Premium/Meta 核心"
    echo ""
    
    echo -e "${YELLOW}💡 使用建议:${NC}"
    echo "• 新手推荐：v2rayNG (Android) 或 Clash Verge Rev (桌面)"
    echo "• iOS 用户推荐：ShadowRocket"
    echo "• 追求性能：SingBox 官方客户端"
    echo "• 优先使用节点链接，简单直接"
    echo "• 如需批量管理，使用订阅功能"
    echo ""
}

# 等待用户确认函数
wait_for_user() {
    echo ""
    read -p "按回车键继续..." -r
}

# 保存节点信息到文件
save_node_info_to_file() {
    local server_address="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"
    local port_hopping="$7"
    local node_link="$8"

    local output_file="/etc/hysteria/node-info.txt"
    local configured_domain=$(get_server_domain)
    local server_ip=$(get_current_server_ip)

    cat > "$output_file" << EOF
# Hysteria2 节点信息
# 生成时间: $(date)

=== 服务器信息 ===
EOF

    if [[ -n "$configured_domain" ]]; then
        cat >> "$output_file" << EOF
服务器域名: $configured_domain:$port
服务器IP: $server_ip:$port
EOF
    else
        cat >> "$output_file" << EOF
服务器地址: $server_address:$port
EOF
    fi

    cat >> "$output_file" << EOF
认证密码: $auth_password
混淆密码: ${obfs_password:-未启用}
混淆类型: $([ -n "$obfs_password" ] && echo "Salamander" || echo "未启用")
SNI域名: ${sni_domain:-未设置}
证书验证: $([ "$insecure" == "true" ] && echo "忽略 (自签名)" || echo "验证 (ACME)")
端口跳跃: $port_hopping

=== 节点链接 ===
$node_link

=== Hysteria2 通用订阅链接 ===
$(echo "$node_link" | base64 -w 0)

=== Hysteria2 官方客户端配置 ===
$(generate_client_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure")

=== Clash 配置 ===
$(local port_hopping=$(get_port_hopping_info); generate_clash_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure" "$port_hopping")

=== SingBox 配置 ===
$(generate_singbox_config "$server_address" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure")

=== 支持 Hysteria2 的客户端 ===

桌面客户端:
• Clash Verge Rev (推荐) - Windows/macOS/Linux
• Clash Meta (ClashX Pro) - Windows/macOS/Linux  
• SingBox (官方客户端) - Windows/macOS/Linux
• Hiddify Next - Windows/macOS/Linux
• NekoRay/NekoBox - Windows/Linux
• v2rayN - Windows
• V2rayU - macOS

移动客户端:
• v2rayNG - Android (推荐)
• NekoBox for Android - Android
• SingBox - Android
• Hiddify Next - Android
• Clash Meta for Android - Android
• ShadowRocket - iOS (推荐)
• Stash - iOS
• QuantumultX - iOS
• Loon - iOS

路由器/OpenWrt:
• OpenClash - 支持 Hysteria2
• SingBox - 官方路由器版本
• Clash Premium/Meta 核心

使用建议:
• 优先选择支持 Hysteria2 的新版客户端
• 推荐使用 Clash Verge Rev 或 v2rayNG
• iOS 用户推荐 ShadowRocket
• 节点链接和订阅链接都可使用
EOF

    echo ""
    echo -e "${GREEN}完整节点信息已保存到: $output_file${NC}"
}
