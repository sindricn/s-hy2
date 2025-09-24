#!/bin/bash

# Hysteria2 配置生成脚本 (安全版本)
# 严格错误处理
set -euo pipefail

# 加载安全输入验证模块
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$script_dir/input-validation.sh" ]]; then
    source "$script_dir/input-validation.sh"
else
    echo "警告: 安全输入验证模块未找到" >&2
fi

# 等待用户确认
wait_for_user() {
    echo ""
    read -p "按回车键继续..." -r
}

# 生成随机密码 (安全版本)
generate_password() {
    local length="${1:-12}"

    # 验证长度参数
    if command -v validate_number_secure >/dev/null 2>&1; then
        if ! validate_number_secure "$length" 8 64; then
            echo "警告: 密码长度无效，使用默认值12" >&2
            length=12
        fi
    else
        # 基础验证
        if [[ ! "$length" =~ ^[0-9]+$ ]] || [[ $length -lt 8 ]] || [[ $length -gt 64 ]]; then
            echo "警告: 密码长度无效，使用默认值12" >&2
            length=12
        fi
    fi

    # 安全生成密码
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
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

# 获取当前配置文件中的监听端口
get_current_listen_port() {
    if [[ -f "$CONFIG_PATH" ]]; then
        local port=$(grep -E "^\s*listen:" "$CONFIG_PATH" | awk -F':' '{print $3}' | tr -d ' ' | head -1)
        echo "${port:-443}"
    else
        echo "443"
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
    
    # 输入监听端口
    echo -n -e "${BLUE}请输入监听端口 (默认 443): ${NC}"
    read -r listen_port
    listen_port=${listen_port:-443}
    
    # 验证端口范围
    if [[ ! "$listen_port" =~ ^[0-9]+$ ]] || [[ "$listen_port" -lt 1 ]] || [[ "$listen_port" -gt 65535 ]]; then
        echo -e "${YELLOW}端口范围无效，使用默认端口 443${NC}"
        listen_port=443
    fi
    
    # 输入认证密码
    echo -n -e "${BLUE}请输入认证密码 (留空自动生成): ${NC}"
    read -r password
    if [[ -z "$password" ]]; then
        password=$(generate_password 16)
        echo -e "${GREEN}自动生成密码: $password${NC}"
    fi
    
    # 询问是否启用混淆
    echo ""
    echo -n -e "${BLUE}是否启用混淆功能? [Y/n]: ${NC}"
    read -r enable_obfs
    
    local obfs_config=""
    if [[ ! $enable_obfs =~ ^[Nn]$ ]]; then
        echo -n -e "${BLUE}请输入混淆密码 (留空自动生成): ${NC}"
        read -r obfs_password
        if [[ -z "$obfs_password" ]]; then
            obfs_password=$(generate_password 16)
            echo -e "${GREEN}自动生成混淆密码: $obfs_password${NC}"
        fi
        
        obfs_config="

obfs:
  type: salamander
  salamander:
    password: $obfs_password"
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

listen: :$listen_port

acme:
  domains:
    - $domain
  email: $email

auth:
  type: password
  password: $password$obfs_config

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
    echo -e "${YELLOW}监听端口: $listen_port${NC}"
    echo -e "${YELLOW}认证密码: $password${NC}"
    if [[ -n "$obfs_password" ]]; then
        echo -e "${YELLOW}混淆密码: $obfs_password${NC}"
        echo -e "${YELLOW}混淆类型: Salamander${NC}"
    else
        echo -e "${YELLOW}混淆功能: 未启用${NC}"
    fi
    echo -e "${YELLOW}伪装网站: $masquerade_url${NC}"
    
    wait_for_user
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
    
    # 输入监听端口
    echo -n -e "${BLUE}请输入监听端口 (默认 443): ${NC}"
    read -r listen_port
    listen_port=${listen_port:-443}
    
    # 验证端口范围
    if [[ ! "$listen_port" =~ ^[0-9]+$ ]] || [[ "$listen_port" -lt 1 ]] || [[ "$listen_port" -gt 65535 ]]; then
        echo -e "${YELLOW}端口范围无效，使用默认端口 443${NC}"
        listen_port=443
    fi
    
    # 输入认证密码
    echo -n -e "${BLUE}请输入认证密码 (留空自动生成): ${NC}"
    read -r password
    if [[ -z "$password" ]]; then
        password=$(generate_password 16)
        echo -e "${GREEN}自动生成密码: $password${NC}"
    fi
    
    # 询问是否启用混淆
    echo ""
    echo -n -e "${BLUE}是否启用混淆功能? [Y/n]: ${NC}"
    read -r enable_obfs
    
    local obfs_config=""
    if [[ ! $enable_obfs =~ ^[Nn]$ ]]; then
        echo -n -e "${BLUE}请输入混淆密码 (留空自动生成): ${NC}"
        read -r obfs_password
        if [[ -z "$obfs_password" ]]; then
            obfs_password=$(generate_password 16)
            echo -e "${GREEN}自动生成混淆密码: $obfs_password${NC}"
        fi
        
        obfs_config="
obfs:
  type: salamander
  salamander:
    password: $obfs_password"
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

listen: :$listen_port

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $password$obfs_config

masquerade:
  type: proxy
  proxy:
    url: $masquerade_url
    rewriteHost: true
EOF
    
    echo ""
    echo -e "${GREEN}自签名证书配置生成成功!${NC}"
    echo -e "${YELLOW}证书域名: $cert_domain${NC}"
    echo -e "${YELLOW}监听端口: $listen_port${NC}"
    echo -e "${YELLOW}认证密码: $password${NC}"
    if [[ -n "$obfs_password" ]]; then
        echo -e "${YELLOW}混淆密码: $obfs_password${NC}"
        echo -e "${YELLOW}混淆类型: Salamander${NC}"
    else
        echo -e "${YELLOW}混淆功能: 未启用${NC}"
    fi
    echo -e "${YELLOW}伪装网站: $masquerade_url${NC}"
    
    wait_for_user
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

# 改进的端口跳跃状态检查
check_port_hopping_status() {
    local interface=$(get_network_interface)
    local target_port=$(get_current_listen_port)
    
    # 多种检测方式
    local found=false
    
    # 方式1: 检查 REDIRECT 规则到目标端口
    if iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null | grep -q "REDIRECT.*dpt:.*--to-ports $target_port"; then
        found=true
    fi
    
    # 方式2: 检查端口范围规则
    if iptables -t nat -L PREROUTING -n 2>/dev/null | grep -E "REDIRECT.*dpts:[0-9]+:[0-9]+.*--to-ports $target_port" >/dev/null; then
        found=true
    fi
    
    # 方式3: 检查保存的配置文件
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        source /etc/hysteria/port-hopping.conf 2>/dev/null
        if [[ -n "$IPTABLES_RULE" ]]; then
            # 验证规则是否实际存在
            local rule_parts
            IFS=' ' read -ra rule_parts <<< "$IPTABLES_RULE"
            local check_rule=""
            for part in "${rule_parts[@]}"; do
                if [[ "$part" != "iptables" && "$part" != "-t" && "$part" != "nat" && "$part" != "-A" ]]; then
                    check_rule+="$part "
                fi
            done
            if iptables -t nat -C PREROUTING $check_rule 2>/dev/null; then
                found=true
            fi
        fi
    fi
    
    # 方式4: 通用检查 - 查找所有 REDIRECT 到目标端口的规则
    if iptables -t nat -S PREROUTING 2>/dev/null | grep -E "REDIRECT.*--to-ports $target_port" >/dev/null; then
        found=true
    fi
    
    if $found; then
        return 0  # 已开启
    else
        return 1  # 未开启
    fi
}

# 获取当前端口跳跃配置信息
get_port_hopping_info() {
    local interface=$(get_network_interface)
    local info=""
    
    # 尝试从配置文件获取信息
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        source /etc/hysteria/port-hopping.conf 2>/dev/null
        if [[ -n "$START_PORT" && -n "$END_PORT" && -n "$TARGET_PORT" ]]; then
            info="端口范围: $START_PORT-$END_PORT -> $TARGET_PORT"
        fi
    fi
    
    # 如果配置文件没有信息，尝试从 iptables 规则解析
    if [[ -z "$info" ]]; then
        local target_port=$(get_current_listen_port)
        local rule_info=$(iptables -t nat -L PREROUTING -n 2>/dev/null | grep "REDIRECT.*--to-ports $target_port" | head -1)
        if [[ -n "$rule_info" ]]; then
            # 尝试提取端口范围信息
            if [[ "$rule_info" =~ dpts:([0-9]+):([0-9]+) ]]; then
                local start_port="${BASH_REMATCH[1]}"
                local end_port="${BASH_REMATCH[2]}"
                info="端口范围: $start_port-$end_port -> $target_port"
            elif [[ "$rule_info" =~ dpt:([0-9]+) ]]; then
                local port="${BASH_REMATCH[1]}"
                info="单端口: $port -> $target_port"
            else
                info="检测到端口跳跃规则"
            fi
        fi
    fi
    
    echo "$info"
}

# 清除端口跳跃规则
clear_port_hopping_rules() {
    local cleared=false
    local interface=$(get_network_interface)
    
    echo -e "${BLUE}正在清除端口跳跃规则...${NC}"
    
    # 方式1: 使用保存的配置文件中的规则
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        source /etc/hysteria/port-hopping.conf 2>/dev/null
        if [[ -n "$IPTABLES_RULE" ]]; then
            # 将 -A 替换为 -D 来删除规则
            local delete_rule="${IPTABLES_RULE/-A/-D}"
            if eval "$delete_rule" 2>/dev/null; then
                echo "已清除配置文件中记录的规则"
                cleared=true
            fi
        fi
    fi
    
    # 方式2: 清除所有到目标端口的REDIRECT规则
    local target_port=$(get_current_listen_port)
    local rules_to_delete=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^-A\ PREROUTING.*REDIRECT.*--to-ports\ $target_port ]]; then
            rules_to_delete+=("${line/-A/-D}")
        fi
    done < <(iptables -t nat -S PREROUTING 2>/dev/null)
    
    for rule in "${rules_to_delete[@]}"; do
        if iptables -t nat $rule 2>/dev/null; then
            echo "已清除规则: $rule"
            cleared=true
        fi
    done
    
    # 方式3: 通用清理方式（基于行号）
    local line_numbers=($(iptables -t nat -L PREROUTING --line-numbers 2>/dev/null | grep "REDIRECT.*--to-ports $target_port" | awk '{print $1}' | sort -rn))
    for line_num in "${line_numbers[@]}"; do
        if iptables -t nat -D PREROUTING "$line_num" 2>/dev/null; then
            echo "已清除第 $line_num 行规则"
            cleared=true
        fi
    done
    
    # 删除配置文件
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        rm -f "/etc/hysteria/port-hopping.conf"
        echo "已删除端口跳跃配置文件"
    fi
    
    if $cleared; then
        echo -e "${GREEN}端口跳跃规则清除成功${NC}"
    else
        echo -e "${YELLOW}没有找到需要清除的端口跳跃规则${NC}"
    fi
}

# 清除所有端口跳跃规则（系统级别）
clear_all_port_hopping_rules() {
    local cleared=false
    
    echo -e "${BLUE}正在清除所有端口跳跃规则...${NC}"
    
    # 获取所有REDIRECT规则
    local all_redirect_rules=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^-A\ PREROUTING.*REDIRECT ]]; then
            all_redirect_rules+=("${line/-A/-D}")
        fi
    done < <(iptables -t nat -S PREROUTING 2>/dev/null)
    
    # 删除所有REDIRECT规则
    for rule in "${all_redirect_rules[@]}"; do
        if iptables -t nat $rule 2>/dev/null; then
            echo "已清除规则: $rule"
            cleared=true
        fi
    done
    
    # 备选方法：按行号删除所有REDIRECT规则
    local line_numbers=($(iptables -t nat -L PREROUTING --line-numbers 2>/dev/null | grep "REDIRECT" | awk '{print $1}' | sort -rn))
    for line_num in "${line_numbers[@]}"; do
        if iptables -t nat -D PREROUTING "$line_num" 2>/dev/null; then
            echo "已清除第 $line_num 行REDIRECT规则"
            cleared=true
        fi
    done
    
    # 删除所有相关的配置文件
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        rm -f "/etc/hysteria/port-hopping.conf"
        echo "已删除端口跳跃配置文件"
    fi
    
    if $cleared; then
        echo -e "${GREEN}所有端口跳跃规则清除成功${NC}"
        local remaining_rules=$(iptables -t nat -L PREROUTING -n 2>/dev/null | grep "REDIRECT" | wc -l)
        if [[ $remaining_rules -eq 0 ]]; then
            echo -e "${GREEN}确认：系统中没有剩余的端口重定向规则${NC}"
        else
            echo -e "${YELLOW}警告：系统中还有 $remaining_rules 条端口重定向规则${NC}"
        fi
    else
        echo -e "${YELLOW}没有找到需要清除的端口跳跃规则${NC}"
    fi
}

# 清除指定端口的跳跃规则
clear_specific_port_rules() {
    local target_port="$1"
    local cleared=false
    
    if [[ -z "$target_port" ]]; then
        echo -e "${RED}错误: 未指定目标端口${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在清除指向端口 $target_port 的跳跃规则...${NC}"
    
    # 清除指向特定端口的REDIRECT规则
    local rules_to_delete=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^-A\ PREROUTING.*REDIRECT.*--to-ports\ $target_port ]]; then
            rules_to_delete+=("${line/-A/-D}")
        fi
    done < <(iptables -t nat -S PREROUTING 2>/dev/null)
    
    for rule in "${rules_to_delete[@]}"; do
        if iptables -t nat $rule 2>/dev/null; then
            echo "已清除规则: $rule"
            cleared=true
        fi
    done
    
    # 备选方法：按行号删除
    local line_numbers=($(iptables -t nat -L PREROUTING --line-numbers 2>/dev/null | grep "REDIRECT.*--to-ports $target_port" | awk '{print $1}' | sort -rn))
    for line_num in "${line_numbers[@]}"; do
        if iptables -t nat -D PREROUTING "$line_num" 2>/dev/null; then
            echo "已清除第 $line_num 行规则"
            cleared=true
        fi
    done
    
    if $cleared; then
        echo -e "${GREEN}指向端口 $target_port 的跳跃规则清除成功${NC}"
    else
        echo -e "${YELLOW}没有找到指向端口 $target_port 的跳跃规则${NC}"
    fi
}

# 添加端口跳跃规则
add_port_hopping_rules() {
    local interface=$(get_network_interface)
    local start_port=${1:-20000}
    local end_port=${2:-50000}
    local target_port=${3:-$(get_current_listen_port)}
    
    echo -e "${BLUE}正在添加端口跳跃规则...${NC}"
    
    # 生成 iptables 规则
    local iptables_rule="iptables -t nat -A PREROUTING -i $interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port"
    
    if eval "$iptables_rule" 2>/dev/null; then
        echo -e "${GREEN}端口跳跃规则添加成功${NC}"
        echo "规则: $start_port-$end_port -> $target_port (接口: $interface)"
        
        # 保存配置到文件
        cat > "/etc/hysteria/port-hopping.conf" << EOF
# 端口跳跃配置
# 生成时间: $(date)
INTERFACE=$interface
START_PORT=$start_port
END_PORT=$end_port
TARGET_PORT=$target_port
IPTABLES_RULE="$iptables_rule"
EOF
        echo "配置已保存到: /etc/hysteria/port-hopping.conf"
        return 0
    else
        echo -e "${RED}端口跳跃规则添加失败${NC}"
        echo "请检查 iptables 权限或网络接口设置"
        return 1
    fi
}

# 询问端口跳跃设置
ask_port_hopping_config() {
    echo -e "${BLUE}检查端口跳跃状态...${NC}"

    if check_port_hopping_status; then
        local hopping_info=$(get_port_hopping_info)
        echo -e "${GREEN}✅ 端口跳跃已开启${NC}"
        if [[ -n "$hopping_info" ]]; then
            echo "   $hopping_info"
        fi
        echo ""
        echo -n -e "${YELLOW}是否保持端口跳跃开启? [Y/n]: ${NC}"
        read -r keep_hopping

        if [[ $keep_hopping =~ ^[Nn]$ ]]; then
            clear_port_hopping_rules
        else
            echo -e "${GREEN}保持端口跳跃开启${NC}"
        fi
    else
        echo -e "${YELLOW}❌ 端口跳跃未开启${NC}"
        echo ""
        echo -n -e "${YELLOW}是否开启端口跳跃? [y/N]: ${NC}"
        read -r enable_hopping

        if [[ $enable_hopping =~ ^[Yy]$ ]]; then
            # 询问端口范围
            echo ""
            echo -e "${BLUE}配置端口跳跃范围:${NC}"
            echo -n -e "${BLUE}起始端口 (默认 20000): ${NC}"
            read -r start_port
            start_port=${start_port:-20000}
            
            echo -n -e "${BLUE}结束端口 (默认 50000): ${NC}"
            read -r end_port
            end_port=${end_port:-50000}
            
            local current_port=$(get_current_listen_port)
            if add_port_hopping_rules "$start_port" "$end_port" "$current_port"; then
                echo -e "${GREEN}端口跳跃配置完成${NC}"
            fi
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

        sleep 2
        if systemctl is-active --quiet hysteria-server; then
            echo -e "${GREEN}✅ 服务重启成功${NC}"
        else
            echo -e "${RED}❌ 服务重启失败${NC}"
            echo "请检查配置文件或查看日志: journalctl -u hysteria-server.service"
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
        return
    fi

    # 检查现有配置
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "${YELLOW}检测到现有配置文件${NC}"
        echo -n -e "${BLUE}是否覆盖现有配置? [y/N]: ${NC}"
        read -r overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消配置生成${NC}"
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
    local target_port=$(get_current_listen_port)

    if add_port_hopping_rules "$start_port" "$end_port" "$target_port"; then
        echo "端口跳跃配置成功 ($start_port-$end_port -> $target_port)"
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

    echo ""
    wait_for_user
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
        return
    fi
    
    # 检查现有配置
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "${YELLOW}检测到现有配置文件${NC}"
        echo -n -e "${BLUE}是否覆盖现有配置? [y/N]: ${NC}"
        read -r overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消配置生成${NC}"
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
    
    wait_for_user
}
