#!/bin/bash

# Hysteria2 故障排除和诊断脚本

# 系统信息检查
check_system_info() {
    echo -e "${CYAN}=== 系统信息检查 ===${NC}"
    echo ""
    
    echo -e "${BLUE}操作系统信息:${NC}"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "发行版: $PRETTY_NAME"
        echo "版本: $VERSION"
        echo "ID: $ID"
    fi
    
    echo ""
    echo -e "${BLUE}系统资源:${NC}"
    echo "内核版本: $(uname -r)"
    echo "架构: $(uname -m)"
    echo "CPU核心: $(nproc)"
    echo "内存: $(free -h | grep Mem | awk '{print $2}')"
    echo "磁盘空间: $(df -h / | tail -1 | awk '{print $4}') 可用"
    
    echo ""
    echo -e "${BLUE}网络信息:${NC}"
    echo "主机名: $(hostname)"
    echo "内网IP: $(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')"
    
    # 获取公网IP
    local public_ip=$(curl -s --connect-timeout 5 ipv4.icanhazip.com 2>/dev/null)
    if [[ -n "$public_ip" ]]; then
        echo "公网IP: $public_ip"
    else
        echo "公网IP: 无法获取"
    fi
    
    echo ""
}

# 检查 Hysteria2 安装状态
check_hysteria_installation() {
    echo -e "${CYAN}=== Hysteria2 安装检查 ===${NC}"
    echo ""
    
    if command -v hysteria &> /dev/null; then
        echo -e "${GREEN}✓ Hysteria2 已安装${NC}"
        echo "版本: $(hysteria version 2>/dev/null | head -1)"
        echo "路径: $(which hysteria)"
    else
        echo -e "${RED}✗ Hysteria2 未安装${NC}"
        return 1
    fi
    
    echo ""
}

# 检查配置文件
check_configuration() {
    echo -e "${CYAN}=== 配置文件检查 ===${NC}"
    echo ""
    
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "${GREEN}✓ 配置文件存在${NC}"
        echo "路径: $CONFIG_PATH"
        echo "大小: $(du -h "$CONFIG_PATH" | cut -f1)"
        echo "修改时间: $(stat -c %y "$CONFIG_PATH" 2>/dev/null)"
        
        # 检查配置文件权限
        local perms=$(stat -c %a "$CONFIG_PATH" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            echo -e "${GREEN}✓ 文件权限正确 ($perms)${NC}"
        else
            echo -e "${YELLOW}⚠ 文件权限: $perms (建议: 600)${NC}"
        fi
        
        # 检查配置文件语法
        echo ""
        echo -e "${BLUE}配置文件语法检查:${NC}"
        if hysteria server --config "$CONFIG_PATH" --check &>/dev/null; then
            echo -e "${GREEN}✓ 配置文件语法正确${NC}"
        else
            echo -e "${RED}✗ 配置文件语法错误${NC}"
            echo "请检查配置文件格式"
        fi
        
        # 显示关键配置信息
        echo ""
        echo -e "${BLUE}关键配置信息:${NC}"
        
        # 监听端口
        local port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://')
        echo "监听端口: ${port:-443}"
        
        # 认证方式
        local auth_type=$(grep -A 1 "^auth:" "$CONFIG_PATH" | grep "type:" | awk '{print $2}')
        echo "认证方式: ${auth_type:-未设置}"
        
        # 证书配置
        if grep -q "^acme:" "$CONFIG_PATH"; then
            echo "证书类型: ACME 自动证书"
            local domain=$(grep -A 2 "^acme:" "$CONFIG_PATH" | grep -E "^\s*-" | awk '{print $2}')
            echo "域名: ${domain:-未设置}"
        elif grep -q "^tls:" "$CONFIG_PATH"; then
            echo "证书类型: 手动证书"
            local cert_path=$(grep -A 2 "^tls:" "$CONFIG_PATH" | grep "cert:" | awk '{print $2}')
            echo "证书路径: ${cert_path:-未设置}"
        else
            echo "证书类型: 未配置"
        fi
        
        # 混淆配置
        if grep -q "^obfs:" "$CONFIG_PATH"; then
            echo -e "${GREEN}✓ 混淆已启用${NC}"
        else
            echo "混淆配置: 未启用"
        fi
        
    else
        echo -e "${RED}✗ 配置文件不存在${NC}"
        echo "路径: $CONFIG_PATH"
        return 1
    fi
    
    echo ""
}

# 检查证书文件
check_certificates() {
    echo -e "${CYAN}=== 证书文件检查 ===${NC}"
    echo ""
    
    local cert_dir="/etc/hysteria"
    
    if [[ -f "$cert_dir/server.crt" ]]; then
        echo -e "${GREEN}✓ 证书文件存在${NC}"
        echo "证书路径: $cert_dir/server.crt"
        echo "私钥路径: $cert_dir/server.key"
        
        # 检查证书有效期
        local cert_info=$(openssl x509 -in "$cert_dir/server.crt" -text -noout 2>/dev/null)
        if [[ -n "$cert_info" ]]; then
            local not_after=$(echo "$cert_info" | grep "Not After" | cut -d: -f2-)
            echo "有效期至: $not_after"
            
            local subject=$(echo "$cert_info" | grep "Subject:" | cut -d= -f2-)
            echo "证书主体: $subject"
        fi
        
        # 检查证书权限
        local cert_perms=$(stat -c %a "$cert_dir/server.crt" 2>/dev/null)
        local key_perms=$(stat -c %a "$cert_dir/server.key" 2>/dev/null)
        echo "证书权限: $cert_perms"
        echo "私钥权限: $key_perms"
        
    else
        echo -e "${YELLOW}⚠ 自签名证书不存在${NC}"
        echo "这可能是 ACME 模式或证书未生成"
    fi
    
    echo ""
}

# 检查服务状态
check_service_status() {
    echo -e "${CYAN}=== 服务状态检查 ===${NC}"
    echo ""
    
    # 服务运行状态
    if systemctl is-active --quiet hysteria-server.service; then
        echo -e "${GREEN}✓ 服务正在运行${NC}"
    else
        echo -e "${RED}✗ 服务未运行${NC}"
    fi
    
    # 服务启用状态
    if systemctl is-enabled --quiet hysteria-server.service; then
        echo -e "${GREEN}✓ 开机自启已启用${NC}"
    else
        echo -e "${YELLOW}⚠ 开机自启未启用${NC}"
    fi
    
    # 服务详细状态
    echo ""
    echo -e "${BLUE}服务详细状态:${NC}"
    systemctl status hysteria-server.service --no-pager -l
    
    echo ""
}

# 检查端口监听
check_port_listening() {
    echo -e "${CYAN}=== 端口监听检查 ===${NC}"
    echo ""
    
    local port="443"
    if [[ -f "$CONFIG_PATH" ]]; then
        port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://' || echo "443")
    fi
    
    echo -e "${BLUE}检查端口 $port 监听状态:${NC}"
    
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓ 端口 $port 正在监听${NC}"
        echo ""
        echo "监听详情:"
        netstat -tulnp 2>/dev/null | grep ":$port "
    else
        echo -e "${RED}✗ 端口 $port 未监听${NC}"
        echo ""
        echo "可能原因:"
        echo "1. 服务未启动"
        echo "2. 配置文件错误"
        echo "3. 端口被其他程序占用"
    fi
    
    echo ""
}

# 检查防火墙状态
check_firewall() {
    echo -e "${CYAN}=== 防火墙检查 ===${NC}"
    echo ""
    
    # 检查 UFW
    if command -v ufw &> /dev/null; then
        echo -e "${BLUE}UFW 状态:${NC}"
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        echo "$ufw_status"
        
        if [[ "$ufw_status" == *"active"* ]]; then
            echo ""
            echo "UFW 规则:"
            ufw status numbered 2>/dev/null | grep -E "(443|hysteria)"
        fi
    fi
    
    # 检查 firewalld
    if command -v firewall-cmd &> /dev/null; then
        echo -e "${BLUE}Firewalld 状态:${NC}"
        if firewall-cmd --state &>/dev/null; then
            echo "运行中"
            echo ""
            echo "开放端口:"
            firewall-cmd --list-ports 2>/dev/null
        else
            echo "未运行"
        fi
    fi
    
    # 检查 iptables
    echo ""
    echo -e "${BLUE}iptables 规则:${NC}"
    if iptables -L INPUT -n 2>/dev/null | grep -q "443"; then
        echo "发现端口 443 相关规则:"
        iptables -L INPUT -n 2>/dev/null | grep "443"
    else
        echo "未发现端口 443 相关规则"
    fi
    
    echo ""
}

# 检查网络连通性
check_network_connectivity() {
    echo -e "${CYAN}=== 网络连通性检查 ===${NC}"
    echo ""
    
    echo -e "${BLUE}DNS 解析测试:${NC}"
    if nslookup google.com &>/dev/null; then
        echo -e "${GREEN}✓ DNS 解析正常${NC}"
    else
        echo -e "${RED}✗ DNS 解析失败${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}外网连接测试:${NC}"
    if curl -s --connect-timeout 5 google.com &>/dev/null; then
        echo -e "${GREEN}✓ 外网连接正常${NC}"
    else
        echo -e "${RED}✗ 外网连接失败${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}端口连通性测试:${NC}"
    local port="443"
    if [[ -f "$CONFIG_PATH" ]]; then
        port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://' || echo "443")
    fi
    
    # 获取公网IP进行测试
    local public_ip=$(curl -s --connect-timeout 5 ipv4.icanhazip.com 2>/dev/null)
    if [[ -n "$public_ip" ]]; then
        echo "测试端口 $port 连通性..."
        if timeout 5 bash -c "</dev/tcp/$public_ip/$port" &>/dev/null; then
            echo -e "${GREEN}✓ 端口 $port 可连接${NC}"
        else
            echo -e "${RED}✗ 端口 $port 无法连接${NC}"
        fi
    else
        echo "无法获取公网IP，跳过端口测试"
    fi
    
    echo ""
}

# 检查日志错误
check_logs() {
    echo -e "${CYAN}=== 日志错误检查 ===${NC}"
    echo ""
    
    echo -e "${BLUE}最近的错误日志:${NC}"
    local error_logs=$(journalctl -u hysteria-server.service --since "1 hour ago" --no-pager | grep -i "error\|failed\|fatal" | tail -10)
    
    if [[ -n "$error_logs" ]]; then
        echo "$error_logs"
    else
        echo -e "${GREEN}✓ 未发现错误日志${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}最近的警告日志:${NC}"
    local warning_logs=$(journalctl -u hysteria-server.service --since "1 hour ago" --no-pager | grep -i "warn" | tail -5)
    
    if [[ -n "$warning_logs" ]]; then
        echo "$warning_logs"
    else
        echo -e "${GREEN}✓ 未发现警告日志${NC}"
    fi
    
    echo ""
}

# 生成诊断报告
generate_diagnostic_report() {
    local report_file="/tmp/hysteria2-diagnostic-$(date +%Y%m%d_%H%M%S).txt"
    
    echo -e "${BLUE}生成诊断报告...${NC}"
    
    {
        echo "Hysteria2 诊断报告"
        echo "生成时间: $(date)"
        echo "========================================"
        echo ""
        
        check_system_info
        check_hysteria_installation
        check_configuration
        check_certificates
        check_service_status
        check_port_listening
        check_firewall
        check_network_connectivity
        check_logs
        
    } > "$report_file" 2>&1
    
    echo -e "${GREEN}诊断报告已生成: $report_file${NC}"
    echo ""
    echo -n -e "${BLUE}是否查看报告内容? [y/N]: ${NC}"
    read -r view_report
    if [[ $view_report =~ ^[Yy]$ ]]; then
        less "$report_file"
    fi
}

# 主诊断函数
run_diagnostics() {
    while true; do
        echo -e "${BLUE}Hysteria2 故障排除和诊断${NC}"
        echo ""
        echo -e "${GREEN}1.${NC} 系统信息检查"
        echo -e "${GREEN}2.${NC} Hysteria2 安装检查"
        echo -e "${GREEN}3.${NC} 配置文件检查"
        echo -e "${GREEN}4.${NC} 证书文件检查"
        echo -e "${GREEN}5.${NC} 服务状态检查"
        echo -e "${GREEN}6.${NC} 端口监听检查"
        echo -e "${GREEN}7.${NC} 防火墙检查"
        echo -e "${GREEN}8.${NC} 网络连通性检查"
        echo -e "${GREEN}9.${NC} 日志错误检查"
        echo -e "${GREEN}10.${NC} 生成完整诊断报告"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择检查项目 [0-10]: ${NC}"
        read -r choice
        
        case $choice in
            1) check_system_info; read -p "按回车键继续..." ;;
            2) check_hysteria_installation; read -p "按回车键继续..." ;;
            3) check_configuration; read -p "按回车键继续..." ;;
            4) check_certificates; read -p "按回车键继续..." ;;
            5) check_service_status; read -p "按回车键继续..." ;;
            6) check_port_listening; read -p "按回车键继续..." ;;
            7) check_firewall; read -p "按回车键继续..." ;;
            8) check_network_connectivity; read -p "按回车键继续..." ;;
            9) check_logs; read -p "按回车键继续..." ;;
            10) generate_diagnostic_report; read -p "按回车键继续..." ;;
            0) break ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
}
