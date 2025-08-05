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

# 生成订阅链接
generate_subscription_link() {
    local node_link="$1"
    echo "$node_link" | base64 -w 0
}

# 生成客户端配置
generate_client_config() {
    local server_ip="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"
    
    cat << EOF
# Hysteria2 客户端配置
server: $server_ip:$port
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
        read -p "按回车键继续..."
        return
    fi
    
    # 检查配置文件
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    # 获取服务器信息
    local server_ip=$(get_current_server_ip)
    local config_info=$(parse_config_info)
    
    if [[ -z "$config_info" ]]; then
        echo -e "${RED}错误: 无法解析配置文件${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    # 解析配置信息
    IFS='|' read -r port auth_password obfs_password sni_domain cert_type insecure <<< "$config_info"
    
    # 获取端口跳跃信息
    local port_hopping=$(get_port_hopping_info)
    
    # 显示基本信息
    echo -e "${CYAN}=== 服务器信息 ===${NC}"
    echo -e "${YELLOW}服务器地址:${NC} $server_ip:$port"
    echo -e "${YELLOW}认证密码:${NC} $auth_password"
    if [[ -n "$obfs_password" ]]; then
        echo -e "${YELLOW}混淆密码:${NC} $obfs_password"
    else
        echo -e "${YELLOW}混淆配置:${NC} 未启用"
    fi
    echo -e "${YELLOW}SNI域名:${NC} ${sni_domain:-未设置}"
    echo -e "${YELLOW}证书类型:${NC} $cert_type"
    echo -e "${YELLOW}端口跳跃:${NC} $port_hopping"
    echo ""
    
    # 生成链接
    local node_link=$(generate_node_link "$server_ip" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure")
    local subscription_link=$(generate_subscription_link "$node_link")
    
    while true; do
        echo -e "${CYAN}=== 节点信息选项 ===${NC}"
        echo -e "${GREEN}1.${NC} 显示节点链接"
        echo -e "${GREEN}2.${NC} 显示订阅链接"
        echo -e "${GREEN}3.${NC} 显示客户端配置"
        echo -e "${GREEN}4.${NC} 保存到文件"
        echo -e "${GREEN}5.${NC} 生成二维码 (需要 qrencode)"
        echo -e "${GREEN}6.${NC} 刷新信息"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-6]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                echo ""
                echo -e "${CYAN}节点链接:${NC}"
                echo "$node_link"
                echo ""
                read -p "按回车键继续..."
                ;;
            2)
                echo ""
                echo -e "${CYAN}订阅链接 (Base64):${NC}"
                echo "$subscription_link"
                echo ""
                read -p "按回车键继续..."
                ;;
            3)
                echo ""
                echo -e "${CYAN}客户端配置:${NC}"
                echo ""
                generate_client_config "$server_ip" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure"
                echo ""
                read -p "按回车键继续..."
                ;;
            4)
                save_node_info_to_file "$server_ip" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure" "$port_hopping" "$node_link" "$subscription_link"
                ;;
            5)
                generate_qr_code "$node_link"
                ;;
            6)
                # 刷新信息
                server_ip=$(get_current_server_ip)
                config_info=$(parse_config_info)
                IFS='|' read -r port auth_password obfs_password sni_domain cert_type insecure <<< "$config_info"
                port_hopping=$(get_port_hopping_info)
                node_link=$(generate_node_link "$server_ip" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure")
                subscription_link=$(generate_subscription_link "$node_link")
                echo -e "${GREEN}信息已刷新${NC}"
                sleep 1
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

# 保存节点信息到文件
save_node_info_to_file() {
    local server_ip="$1"
    local port="$2"
    local auth_password="$3"
    local obfs_password="$4"
    local sni_domain="$5"
    local insecure="$6"
    local port_hopping="$7"
    local node_link="$8"
    local subscription_link="$9"
    
    local output_file="/etc/hysteria/node-info.txt"
    
    cat > "$output_file" << EOF
# Hysteria2 节点信息
# 生成时间: $(date)

=== 服务器信息 ===
服务器地址: $server_ip:$port
认证密码: $auth_password
混淆密码: ${obfs_password:-未启用}
SNI域名: ${sni_domain:-未设置}
证书验证: $([ "$insecure" == "true" ] && echo "忽略 (自签名)" || echo "验证 (ACME)")
端口跳跃: $port_hopping

=== 节点链接 ===
$node_link

=== 订阅链接 (Base64) ===
$subscription_link

=== 客户端配置 ===
$(generate_client_config "$server_ip" "$port" "$auth_password" "$obfs_password" "$sni_domain" "$insecure")
EOF
    
    echo ""
    echo -e "${GREEN}节点信息已保存到: $output_file${NC}"
    echo ""
    read -p "按回车键继续..."
}

# 生成二维码
generate_qr_code() {
    local content="$1"
    
    if command -v qrencode &> /dev/null; then
        echo ""
        echo -e "${CYAN}节点链接二维码:${NC}"
        echo ""
        qrencode -t ANSIUTF8 "$content"
        echo ""
    else
        echo ""
        echo -e "${YELLOW}qrencode 未安装，无法生成二维码${NC}"
        echo "安装命令:"
        echo "  Ubuntu/Debian: apt install qrencode"
        echo "  CentOS/RHEL: yum install qrencode"
        echo ""
    fi
    
    read -p "按回车键继续..."
}
