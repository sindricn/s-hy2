#!/bin/bash

# Hysteria2 配置生成脚本

# 生成随机密码
generate_password() {
    local length=${1:-12}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# 验证域名格式
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    else
        return 1
    fi
}

# 验证邮箱格式
validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# 获取服务器域名配置
get_server_domain() {
    if [[ -f "/etc/hysteria/server-domain.conf" ]]; then
        cat "/etc/hysteria/server-domain.conf"
    else
        echo ""
    fi
}

# ACME 配置模式
configure_acme_mode() {
    echo -e "${BLUE}ACME 自动证书配置${NC}"
    echo ""

    # 检查是否已配置服务器域名
    local configured_domain=$(get_server_domain)
    local domain=""

    if [[ -n "$configured_domain" ]]; then
        echo -e "${GREEN}检测到已配置的服务器域名: $configured_domain${NC}"
        echo ""
        echo -n -e "${YELLOW}是否使用已配置的域名? [Y/n]: ${NC}"
        read -r use_configured

        if [[ ! $use_configured =~ ^[Nn]$ ]]; then
            domain="$configured_domain"
            echo -e "${GREEN}使用已配置域名: $domain${NC}"
        fi
    fi

    # 如果没有使用已配置域名，则手动输入
    if [[ -z "$domain" ]]; then
        echo -e "${BLUE}手动输入域名${NC}"
        while true; do
            echo -n -e "${BLUE}请输入域名 (例: your.domain.com): ${NC}"
            read -r domain
            if validate_domain "$domain"; then
                break
            else
                echo -e "${RED}域名格式无效，请重新输入${NC}"
            fi
        done
    fi
    
    # 输入邮箱
    while true; do
        echo -n -e "${BLUE}请输入邮箱地址: ${NC}"
        read -r email
        if validate_email "$email"; then
            break
        else
            echo -e "${RED}邮箱格式无效，请重新输入${NC}"
        fi
    done
    
    # 输入密码
    echo -n -e "${BLUE}请输入认证密码 (留空自动生成): ${NC}"
    read -r password
    if [[ -z "$password" ]]; then
        password=$(generate_password 16)
        echo -e "${GREEN}自动生成密码: $password${NC}"
    fi
    
    # 选择伪装网站
    echo ""
    echo -e "${BLUE}选择伪装网站:${NC}"
    echo "1. 使用默认 (news.ycombinator.com)"
    echo "2. 自动测试选择最优域名"
    echo "3. 手动输入"
    echo -n -e "${BLUE}请选择 [1-3]: ${NC}"
    read -r masq_choice
    
    case $masq_choice in
        1)
            masquerade_url="https://news.ycombinator.com/"
            ;;
        2)
            echo -e "${BLUE}正在测试域名延迟...${NC}"
            if [[ -f "$SCRIPTS_DIR/domain-test.sh" ]]; then
                source "$SCRIPTS_DIR/domain-test.sh"
                masquerade_url=$(get_best_domain)
            else
                masquerade_url="https://news.ycombinator.com/"
            fi
            ;;
        3)
            echo -n -e "${BLUE}请输入伪装网站URL: ${NC}"
            read -r masquerade_url
            ;;
        *)
            masquerade_url="https://news.ycombinator.com/"
            ;;
    esac
    
    # 生成配置文件
    cat > "$CONFIG_PATH" << EOF
# Hysteria2 配置文件 - ACME 模式
# 生成时间: $(date)

listen: :443

acme:
  domains:
    - $domain
  email: $email

auth:
  type: password
  password: $password

masquerade:
  type: proxy
  proxy:
    url: $masquerade_url
    rewriteHost: true
EOF
    
    echo ""
    echo -e "${GREEN}ACME 配置文件生成成功!${NC}"
    echo -e "${YELLOW}域名: $domain${NC}"
    echo -e "${YELLOW}邮箱: $email${NC}"
    echo -e "${YELLOW}密码: $password${NC}"
    echo -e "${YELLOW}伪装网站: $masquerade_url${NC}"
}

# 自签名证书配置模式
configure_self_cert_mode() {
    echo -e "${BLUE}自签名证书配置${NC}"
    echo ""
    
    # 选择伪装域名
    echo -e "${BLUE}选择伪装域名:${NC}"
    echo "1. 使用默认 (cdn.jsdelivr.net)"
    echo "2. 自动测试选择最优域名"
    echo "3. 手动输入"
    echo -n -e "${BLUE}请选择 [1-3]: ${NC}"
    read -r domain_choice
    
    case $domain_choice in
        1)
            cert_domain="cdn.jsdelivr.net"
            masquerade_url="https://cdn.jsdelivr.net/"
            ;;
        2)
            echo -e "${BLUE}正在测试域名延迟...${NC}"
            if [[ -f "$SCRIPTS_DIR/domain-test.sh" ]]; then
                source "$SCRIPTS_DIR/domain-test.sh"
                best_domain=$(get_best_domain_name)
                cert_domain="$best_domain"
                masquerade_url="https://$best_domain/"
            else
                cert_domain="cdn.jsdelivr.net"
                masquerade_url="https://cdn.jsdelivr.net/"
            fi
            ;;
        3)
            echo -n -e "${BLUE}请输入伪装域名: ${NC}"
            read -r cert_domain
            masquerade_url="https://$cert_domain/"
            ;;
        *)
            cert_domain="cdn.jsdelivr.net"
            masquerade_url="https://cdn.jsdelivr.net/"
            ;;
    esac
    
    # 输入密码
    echo -n -e "${BLUE}请输入认证密码 (留空自动生成): ${NC}"
    read -r password
    if [[ -z "$password" ]]; then
        password=$(generate_password 16)
        echo -e "${GREEN}自动生成密码: $password${NC}"
    fi
    
    # 生成自签名证书
    echo -e "${BLUE}生成自签名证书...${NC}"
    mkdir -p /etc/hysteria
    
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /etc/hysteria/server.key \
        -out /etc/hysteria/server.crt \
        -subj "/CN=$cert_domain" \
        -days 3650
    
    # 设置证书权限
    if id "hysteria" &>/dev/null; then
        chown hysteria:hysteria /etc/hysteria/server.key
        chown hysteria:hysteria /etc/hysteria/server.crt
    fi
    
    # 生成配置文件
    cat > "$CONFIG_PATH" << EOF
# Hysteria2 配置文件 - 自签名证书模式
# 生成时间: $(date)

listen: :443

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $password

masquerade:
  type: proxy
  proxy:
    url: $masquerade_url
    rewriteHost: true
EOF
    
    echo ""
    echo -e "${GREEN}自签名证书配置生成成功!${NC}"
    echo -e "${YELLOW}证书域名: $cert_domain${NC}"
    echo -e "${YELLOW}密码: $password${NC}"
    echo -e "${YELLOW}伪装网站: $masquerade_url${NC}"
}

# 获取服务器公网IP
get_server_ip() {
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

# 自动检测网卡
get_network_interface() {
    # 获取默认路由的网卡
    local interface=$(ip route | grep default | head -1 | awk '{print $5}')

    # 如果没有找到，尝试其他方法
    if [[ -z "$interface" ]]; then
        interface=$(ip link show | grep -E "^[0-9]+:" | grep -v lo | head -1 | awk -F': ' '{print $2}')
    fi

    # 最后的备选方案
    if [[ -z "$interface" ]]; then
        interface="eth0"
    fi

    echo "$interface"
}

# 检查端口跳跃状态
check_port_hopping_status() {
    if iptables -t nat -L PREROUTING 2>/dev/null | grep -q "REDIRECT.*--to-ports 443"; then
        return 0  # 已开启
    else
        return 1  # 未开启
    fi
}

# 询问端口跳跃设置
ask_port_hopping_config() {
    echo -e "${BLUE}检查端口跳跃状态...${NC}"

    if check_port_hopping_status; then
        echo -e "${GREEN}端口跳跃已开启${NC}"
        echo ""
        echo -n -e "${YELLOW}是否保持端口跳跃开启? [Y/n]: ${NC}"
        read -r keep_hopping

        if [[ $keep_hopping =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}关闭端口跳跃...${NC}"
            # 清除端口跳跃规则
            iptables -t nat -D PREROUTING -i $(get_network_interface) -p udp --dport 20000:50000 -j REDIRECT --to-ports 443 2>/dev/null || true
            echo -e "${GREEN}端口跳跃已关闭${NC}"
        else
            echo -e "${GREEN}保持端口跳跃开启${NC}"
        fi
    else
        echo -e "${YELLOW}端口跳跃未开启${NC}"
        echo ""
        echo -n -e "${YELLOW}是否开启端口跳跃? [y/N]: ${NC}"
        read -r enable_hopping

        if [[ $enable_hopping =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}开启端口跳跃...${NC}"
            # 添加端口跳跃规则
            iptables -t nat -A PREROUTING -i $(get_network_interface) -p udp --dport 20000:50000 -j REDIRECT --to-ports 443
            echo -e "${GREEN}端口跳跃已开启${NC}"
        else
            echo -e "${BLUE}保持端口跳跃关闭${NC}"
        fi
    fi
    echo ""
}

# 询问是否重启服务
ask_restart_service() {
    echo ""
    echo -n -e "${YELLOW}配置已完成，是否立即重启 Hysteria2 服务? [Y/n]: ${NC}"
    read -r restart_service

    if [[ ! $restart_service =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}正在重启 Hysteria2 服务...${NC}"
        systemctl restart hysteria-server

        if systemctl is-active --quiet hysteria-server; then
            echo -e "${GREEN}✅ 服务重启成功${NC}"
        else
            echo -e "${RED}❌ 服务重启失败${NC}"
            echo "请检查配置文件或查看日志"
        fi
    else
        echo -e "${YELLOW}请稍后手动重启服务: systemctl restart hysteria-server${NC}"
    fi
}

# 一键快速配置
quick_setup_hysteria() {
    echo -e "${CYAN}=== Hysteria2 一键快速配置 ===${NC}"
    echo ""

    # 检查是否已安装
    if ! check_hysteria_installed; then
        echo -e "${RED}错误: Hysteria2 未安装${NC}"
        echo "请先安装 Hysteria2"
        read -p "按回车键继续..."
        return
    fi

    # 检查现有配置
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "${YELLOW}检测到现有配置文件${NC}"
        echo -n -e "${BLUE}是否覆盖现有配置? [y/N]: ${NC}"
        read -r overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消配置生成${NC}"
            read -p "按回车键继续..."
            return
        fi

        # 备份现有配置
        cp "$CONFIG_PATH" "$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}已备份现有配置${NC}"
    fi

    echo -e "${BLUE}正在执行一键快速配置...${NC}"
    echo ""

    # 1. 获取服务器信息
    echo -e "${BLUE}步骤 1/7: 获取服务器信息...${NC}"
    local server_ip=$(get_server_ip)
    local network_interface=$(get_network_interface)
    echo "服务器IP: $server_ip"
    echo "网络接口: $network_interface"

    # 2. 测试最优伪装域名
    echo -e "${BLUE}步骤 2/7: 测试最优伪装域名...${NC}"
    if [[ -f "$SCRIPTS_DIR/domain-test.sh" ]]; then
        source "$SCRIPTS_DIR/domain-test.sh"
        local best_domain=$(get_best_domain_name)
        local masquerade_url="https://$best_domain/"
        echo "最优伪装域名: $best_domain"
    else
        local best_domain="cdn.jsdelivr.net"
        local masquerade_url="https://cdn.jsdelivr.net/"
        echo "使用默认伪装域名: $best_domain"
    fi

    # 3. 生成密码
    echo -e "${BLUE}步骤 3/7: 生成随机密码...${NC}"
    local auth_password=$(generate_password 16)
    local obfs_password=$(generate_password 16)
    echo "认证密码: $auth_password"
    echo "混淆密码: $obfs_password"

    # 4. 生成自签名证书
    echo -e "${BLUE}步骤 4/7: 生成自签名证书...${NC}"
    mkdir -p /etc/hysteria

    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /etc/hysteria/server.key \
        -out /etc/hysteria/server.crt \
        -subj "/CN=$best_domain" \
        -days 3650 &>/dev/null

    # 设置证书权限
    if id "hysteria" &>/dev/null; then
        chown hysteria:hysteria /etc/hysteria/server.key
        chown hysteria:hysteria /etc/hysteria/server.crt
    fi
    echo "证书生成完成"

    # 5. 生成配置文件
    echo -e "${BLUE}步骤 5/7: 生成配置文件...${NC}"
    cat > "$CONFIG_PATH" << EOF
# Hysteria2 配置文件 - 一键快速配置
# 生成时间: $(date)
# 服务器IP: $server_ip

listen: :443

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $auth_password

masquerade:
  type: proxy
  proxy:
    url: $masquerade_url
    rewriteHost: true

obfs:
  type: salamander
  salamander:
    password: $obfs_password
EOF

    # 设置配置文件权限
    if id "hysteria" &>/dev/null; then
        chown hysteria:hysteria "$CONFIG_PATH"
    fi
    chmod 600 "$CONFIG_PATH"
    echo "配置文件生成完成"

    # 6. 配置端口跳跃
    echo -e "${BLUE}步骤 6/7: 配置端口跳跃...${NC}"
    local start_port=20000
    local end_port=50000
    local target_port=443

    # 生成 iptables 规则
    local iptables_rule="iptables -t nat -A PREROUTING -i $network_interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port"

    if eval "$iptables_rule" 2>/dev/null; then
        echo "端口跳跃配置成功 ($start_port-$end_port -> $target_port)"

        # 保存端口跳跃配置
        cat > "/etc/hysteria/port-hopping.conf" << EOF
# 端口跳跃配置 - 一键快速配置
# 生成时间: $(date)
INTERFACE=$network_interface
START_PORT=$start_port
END_PORT=$end_port
TARGET_PORT=$target_port
IPTABLES_RULE="$iptables_rule"
EOF
    else
        echo "端口跳跃配置失败，跳过此步骤"
    fi

    # 7. 启动服务
    echo -e "${BLUE}步骤 7/7: 启动服务...${NC}"

    # 启用并启动服务
    systemctl enable hysteria-server.service &>/dev/null
    if systemctl start hysteria-server.service; then
        sleep 3
        if systemctl is-active --quiet hysteria-server.service; then
            echo -e "${GREEN}服务启动成功!${NC}"

            # 显示配置信息
            echo ""
            echo -e "${CYAN}=== 一键快速配置完成 ===${NC}"
            echo ""
            echo -e "${YELLOW}配置信息:${NC}"
            echo "服务器地址: $server_ip:443"
            echo "认证密码: $auth_password"
            echo "混淆密码: $obfs_password"
            echo "伪装域名: $best_domain"
            echo "端口跳跃: $start_port-$end_port"
            echo ""

            # 生成节点信息
            generate_node_info "$server_ip" "$auth_password" "$obfs_password" "$best_domain" "$start_port" "$end_port"

        else
            echo -e "${RED}服务启动失败${NC}"
            echo "请查看日志: journalctl -u hysteria-server.service"
        fi
    else
        echo -e "${RED}服务启动失败${NC}"
    fi

    # 检查端口跳跃状态并询问
    ask_port_hopping_config

    # 询问是否重启服务
    ask_restart_service

    echo ""
    read -p "按回车键继续..."
}

# 生成节点信息
generate_node_info() {
    local server_ip="$1"
    local auth_password="$2"
    local obfs_password="$3"
    local sni_domain="$4"
    local start_port="$5"
    local end_port="$6"

    # 检查是否有配置的服务器域名
    local configured_domain=$(get_server_domain)
    local server_address=""

    if [[ -n "$configured_domain" ]]; then
        server_address="$configured_domain:443"
        echo -e "${GREEN}使用已配置的服务器域名: $configured_domain${NC}"
    else
        server_address="$server_ip:443"
        echo -e "${YELLOW}使用服务器IP地址: $server_ip${NC}"
    fi

    # 保存节点信息到文件
    local node_file="/etc/hysteria/node-info.txt"

    cat > "$node_file" << EOF
# Hysteria2 节点信息
# 生成时间: $(date)

服务器地址: $server_address
认证密码: $auth_password
混淆密码: $obfs_password
SNI域名: $sni_domain
端口跳跃: $start_port-$end_port
证书验证: 忽略 (自签名证书)

# 客户端配置示例
server: $server_address
auth: $auth_password
tls:
  sni: $sni_domain
  insecure: true
obfs:
  type: salamander
  salamander:
    password: $obfs_password
socks5:
  listen: 127.0.0.1:1080
http:
  listen: 127.0.0.1:8080

# 节点链接 (Hysteria2://)
hysteria2://$auth_password@$server_ip:443?sni=$sni_domain&insecure=1&obfs=salamander&obfs-password=$obfs_password#Hysteria2-QuickSetup

# 订阅链接 (Base64编码)
$(echo "hysteria2://$auth_password@$server_ip:443?sni=$sni_domain&insecure=1&obfs=salamander&obfs-password=$obfs_password#Hysteria2-QuickSetup" | base64 -w 0)
EOF

    echo -e "${GREEN}节点信息已保存到: $node_file${NC}"
}

# 主配置生成函数
generate_hysteria_config() {
    # 检查是否已安装
    if ! check_hysteria_installed; then
        echo -e "${RED}错误: Hysteria2 未安装${NC}"
        echo "请先安装 Hysteria2"
        read -p "按回车键继续..."
        return
    fi
    
    # 检查现有配置
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "${YELLOW}检测到现有配置文件${NC}"
        echo -n -e "${BLUE}是否覆盖现有配置? [y/N]: ${NC}"
        read -r overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消配置生成${NC}"
            read -p "按回车键继续..."
            return
        fi
        
        # 备份现有配置
        cp "$CONFIG_PATH" "$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}已备份现有配置${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}选择配置模式:${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} ACME 自动证书 (推荐，需要域名)"
    echo -e "${GREEN}2.${NC} 自签名证书 (快速部署，无需域名)"
    echo ""
    echo -n -e "${BLUE}请选择模式 [1-2]: ${NC}"
    read -r config_mode
    
    case $config_mode in
        1)
            configure_acme_mode
            ;;
        2)
            configure_self_cert_mode
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            read -p "按回车键继续..."
            return
            ;;
    esac
    
    # 设置配置文件权限
    if id "hysteria" &>/dev/null; then
        chown hysteria:hysteria "$CONFIG_PATH"
    fi
    chmod 600 "$CONFIG_PATH"
    
    echo ""
    echo -e "${GREEN}配置文件已保存到: $CONFIG_PATH${NC}"

    # 检查端口跳跃状态并询问
    ask_port_hopping_config

    # 询问是否重启服务
    ask_restart_service

    echo ""
    echo -e "${YELLOW}其他管理命令:${NC}"
    echo "1. 查看状态: systemctl status hysteria-server.service"
    echo "2. 查看日志: journalctl -u hysteria-server.service"
    echo ""
    read -p "按回车键继续..."
}
