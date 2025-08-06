# 检查证书文件（优化版本）
check_certificates() {
    echo -e "${CYAN}=== 证书文件检查 ===${NC}"
    echo ""
    
    local cert_dir="/etc/hysteria"
    local cert_file="$cert_dir/server.crt"
    local key_file="$cert_dir/server.key"
    
    # 检查 ACME 证书配置
    if grep -q "^acme:" "$CONFIG_PATH" 2>/dev/null; then
        echo -e "${BLUE}ACME 自动证书模式${NC}"
        
        # 获取配置的域名
        local domains=($(grep -A 10 "^acme:" "$CONFIG_PATH" | grep -E "^\s*-" | awk '{print $2}'))
        
        if [[ ${#domains[@]} -gt 0 ]]; then
            echo "配置域名: ${domains[*]}"
            
            # 检查域名解析
            for domain in "${domains[@]}"; do
                echo -n "检查域名解析 $domain... "
                local resolved_ip=$(timeout 5 dig +short A "$domain" 2>/dev/null | head -1)
                if [[ -n "$resolved_ip" ]]; then
                    echo -e "${GREEN}✓ $resolved_ip${NC}"
                    add_diagnostic_result "SUCCESS" "域名解析" "域名 $domain 解析正常: $resolved_ip"
                else
                    echo -e "${RED}✗ 解析失败${NC}"
                    add_diagnostic_result "CRITICAL" "域名解析" "域名 $domain 解析失败" true
                fi
            done
            
            # 检查域名是否指向当前服务器
            local public_ip=$(timeout 5 curl -s ipv4.icanhazip.com 2>/dev/null)
            if [[ -n "$public_ip" ]]; then
                for domain in "${domains[@]}"; do
                    local domain_ip=$(timeout 5 dig +short A "$domain" 2>/dev/null | head -1)
                    if [[ "$domain_ip" == "$public_ip" ]]; then
                        echo -e "${GREEN}✓ 域名 $domain 正确指向当前服务器${NC}"
                        add_diagnostic_result "SUCCESS" "域名配置" "域名 $domain 正确指向服务器"
                    else
                        echo -e "${YELLOW}⚠ 域名 $domain 未指向当前服务器 ($domain_ip vs $public_ip)${NC}"
                        add_diagnostic_result "WARNING" "域名配置" "域名 $domain 未指向当前服务器" true
                    fi
                done
            fi
            
        else
            echo -e "${RED}✗ ACME 配置中未找到域名${NC}"
            add_diagnostic_result "CRITICAL" "ACME配置" "ACME 配置中未找到域名" true
        fi
        
        # 检查 ACME 证书目录
        local acme_dir="/var/lib/hysteria"
        if [[ -d "$acme_dir" ]]; then
            echo "ACME 证书目录: $acme_dir (存在)"
            local cert_count=$(find "$acme_dir" -name "*.crt" 2>/dev/null | wc -l)
            echo "已生成证书数量: $cert_count"
        else
            echo "ACME 证书目录: $acme_dir (不存在)"
            add_diagnostic_result "INFO" "ACME证书" "ACME 证书目录不存在，首次运行时会创建"
        fi
        
    # 检查手动证书配置
    elif grep -q "^tls:" "$CONFIG_PATH" 2>/dev/null; then
        echo -e "${BLUE}手动证书模式${NC}"
        
        local config_cert=$(grep -A 3 "^tls:" "$CONFIG_PATH" | grep "cert:" | awk '{print $2}')
        local config_key=$(grep -A 3 "^tls:" "$CONFIG_PATH" | grep "key:" | awk '{print $2}')
        
        echo "配置中的证书路径: $config_cert"
        echo "配置中的私钥路径: $config_key"
        
        # 检查证书文件
        if [[ -f "$config_cert" ]]; then
            echo -e "${GREEN}✓ 证书文件存在${NC}"
            local cert_size=$(du -h "$config_cert" | cut -f1)
            echo "  大小: $cert_size"
            
            # 检查证书详情
            if command -v openssl >/dev/null; then
                local cert_info=$(openssl x509 -in "$config_cert" -text -noout 2>/dev/null)
                if [[ -n "$cert_info" ]]; then
                    local subject=$(echo "$cert_info" | grep "Subject:" | cut -d= -f2- | sed 's/^[[:space:]]*//')
                    local issuer=$(echo "$cert_info" | grep "Issuer:" | cut -d= -f2- | sed 's/^[[:space:]]*//')
                    local not_after=$(echo "$cert_info" | grep "Not After" | cut -d: -f2-)
                    
                    echo "  主体: $subject"
                    echo "  颁发者: $issuer"
                    echo "  有效期至: $not_after"
                    
                    # 检查证书是否过期
                    local expiry_timestamp=$(date -d "$not_after" +%s 2>/dev/null)
                    local current_timestamp=$(date +%s)
                    
                    if [[ -n "$expiry_timestamp" ]] && [[ $expiry_timestamp -gt $current_timestamp ]]; then
                        local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                        echo -e "  状态: ${GREEN}有效 (剩余 $days_left 天)${NC}"
                        
                        if [[ $days_left -lt 30 ]]; then
                            add_diagnostic_result "WARNING" "证书有效期" "证书将在 $days_left 天后过期" true
                        else
                            add_diagnostic_result "SUCCESS" "证书有效期" "证书有效，剩余 $days_left 天"
                        fi
                    else
                        echo -e "  状态: ${RED}已过期${NC}"
                        add_diagnostic_result "CRITICAL" "证书有效期" "证书已过期" true
                    fi
                    
                    add_diagnostic_result "SUCCESS" "证书文件" "证书文件存在且可读取"
                else
                    echo -e "  状态: ${RED}证书格式错误${NC}"
                    add_diagnostic_result "CRITICAL" "证书格式" "证书文件格式错误" true
                fi
            fi
        else
            echo -e "${RED}✗ 证书文件不存在${NC}"
            add_diagnostic_result "CRITICAL" "证书文件" "证书文件不存在: $config_cert" true
        fi
        
        # 检查私钥文件
        if [[ -f "$config_key" ]]; then
            echo -e "${GREEN}✓ 私钥文件存在${NC}"
            local key_size=$(du -h "$config_key" | cut -f1)
            local key_perms=$(stat -c %a "$config_key" 2>/dev/null)
            echo "  大小: $key_size"
            echo "  权限: $key_perms"
            
            if [[ "$key_perms" == "600" ]]; then
                add_diagnostic_result "SUCCESS" "私钥权限" "私钥文件权限正确"
            else
                add_diagnostic_result "WARNING" "私钥权限" "私钥文件权限不安全: $key_perms (建议: 600)" true
            fi
            
            # 验证私钥格式
            if command -v openssl >/dev/null; then
                if openssl rsa -in "$config_key" -check -noout 2>/dev/null; then
                    echo -e "  格式: ${GREEN}有效${NC}"
                    add_diagnostic_result "SUCCESS" "私钥格式" "私钥文件格式有效"
                else
                    echo -e "  格式: ${RED}无效${NC}"
                    add_diagnostic_result "CRITICAL" "私钥格式" "私钥文件格式无效" true
                fi
            fi
        else
            echo -e "${RED}✗ 私钥文件不存在${NC}"
            add_diagnostic_result "CRITICAL" "私钥文件" "私钥文件不存在: $config_key" true
        fi
        
    # 检查默认自签名证书
    elif [[ -f "$cert_file" && -f "$key_file" ]]; then
        echo -e "${BLUE}自签名证书模式${NC}"
        echo -e "${GREEN}✓ 自签名证书文件存在${NC}"
        echo "证书路径: $cert_file"
        echo "私钥路径: $key_file"
        
        add_diagnostic_result "INFO" "证书配置" "使用自签名证书"
        
    else
        echo -e "${YELLOW}⚠ 未找到证书配置或文件${NC}"
        add_diagnostic_result "WARNING" "证书配置" "未找到有效的证书配置" true
    fi
    
    echo ""
}

# 检查服务状态（优化版本）
check_service_status() {
    echo -e "${CYAN}=== 服务状态检查 ===${NC}"
    echo ""
    
    # 基本服务状态
    echo -n "服务运行状态: "
    if systemctl is-active --quiet hysteria-server.service; then
        echo -e "${GREEN}运行中${NC}"
        add_diagnostic_result "SUCCESS" "服务状态" "服务正在运行"
        
        # 获取服务详细信息
        local start_time=$(systemctl show hysteria-server.service --property=ActiveEnterTimestamp --value)
        if [[ -n "$start_time" ]]; then
            echo "启动时间: $start_time"
        fi
        
        # 检查服务稳定性
        local restart_count=$(systemctl show hysteria-server.service --property=NRestarts --value)
        echo "重启次数: ${restart_count:-0}"
        
        if [[ "${restart_count:-0}" -gt 5 ]]; then
            add_diagnostic_result "WARNING" "服务稳定性" "服务重启次数较多: $restart_count" false
        fi
        
    else
        echo -e "${RED}未运行${NC}"
        add_diagnostic_result "CRITICAL" "服务状态" "服务未运行" true
        
        # 获取停止原因
        local exit_code=$(systemctl show hysteria-server.service --property=ExecMainStatus --value)
        local exit_signal=$(systemctl show hysteria-server.service --property=ExecMainSignal --value)
        
        if [[ -n "$exit_code" && "$exit_code" != "0" ]]; then
            echo "退出代码: $exit_code"
            add_diagnostic_result "CRITICAL" "服务退出" "服务异常退出，代码: $exit_code" true
        fi
        
        if [[ -n "$exit_signal" && "$exit_signal" != "0" ]]; then
            echo "信号: $exit_signal"
        fi
    fi
    
    # 开机自启状态
    echo -n "开机自启状态: "
    if systemctl is-enabled --quiet hysteria-server.service; then
        echo -e "${GREEN}已启用${NC}"
        add_diagnostic_result "SUCCESS" "开机自启" "开机自启已启用"
    else
        echo -e "${RED}未启用${NC}"
        add_diagnostic_result "WARNING" "开机自启" "开机自启未启用" true
    fi
    
    # 进程信息
    local pid=$(pgrep -f hysteria-server)
    if [[ -n "$pid" ]]; then
        echo ""
        echo -e "${BLUE}进程信息:${NC}"
        echo "进程ID: $pid"
        
        # 性能信息
        local cpu_usage=$(ps -p $pid -o %cpu= 2>/dev/null | awk '{print $1"%"}')
        local mem_usage=$(ps -p $pid -o rss= 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
        local mem_percent=$(ps -p $pid -o %mem= 2>/dev/null | awk '{print $1"%"}')
        
        echo "CPU 使用率: ${cpu_usage:-N/A}"
        echo "内存使用: ${mem_usage:-N/A} (${mem_percent:-N/A})"
        
        # 文件描述符
        if [[ -d "/proc/$pid/fd" ]]; then
            local fd_count=$(ls /proc/$pid/fd 2>/dev/null | wc -l)
            echo "文件描述符: $fd_count"
            
            if [[ $fd_count -gt 1000 ]]; then
                add_diagnostic_result "WARNING" "资源使用" "文件描述符使用较多: $fd_count" false
            fi
        fi
        
        add_diagnostic_result "SUCCESS" "进程状态" "进程运行正常，PID: $pid"
    fi
    
    echo ""
}

# 检查端口监听（优化版本）
check_port_listening() {
    echo -e "${CYAN}=== 端口监听检查 ===${NC}"
    echo ""
    
    local port="443"
    if [[ -f "$CONFIG_PATH" ]]; then
        port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://' || echo "443")
    fi
    
    echo -e "${BLUE}检查端口 $port 监听状态:${NC}"
    
    # 检查端口是否在监听
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓ 端口 $port 正在监听${NC}"
        
        # 显示详细监听信息
        local listen_info=$(netstat -tulnp 2>/dev/null | grep ":$port ")
        echo "监听详情:"
        echo "$listen_info" | sed 's/^/  /'
        
        add_diagnostic_result "SUCCESS" "端口监听" "端口 $port 正在监听"
        
        # 检查连接统计
        local established=$(netstat -an 2>/dev/null | grep ":$port " | grep -c ESTABLISHED || echo "0")
        local time_wait=$(netstat -an 2>/dev/null | grep ":$port " | grep -c TIME_WAIT || echo "0")
        
        echo ""
        echo "连接统计:"
        echo "  ESTABLISHED: $established"
        echo "  TIME_WAIT: $time_wait"
        
        if [[ $established -gt 100 ]]; then
            add_diagnostic_result "INFO" "连接数量" "活跃连接较多: $established"
        fi
        
    else
        echo -e "${RED}✗ 端口 $port 未监听${NC}"
        add_diagnostic_result "CRITICAL" "端口监听" "端口 $port 未监听" true
        
        # 检查端口是否被占用
        local port_owner=$(netstat -tulnp 2>/dev/null | grep ":$port " | head -1)
        if [[ -n "$port_owner" ]]; then
            echo "端口被其他进程占用:"
            echo "  $port_owner"
            add_diagnostic_result "CRITICAL" "端口占用" "端口 $port 被其他进程占用" true
        fi
        
        echo ""
        echo "可能原因:"
        echo "1. 服务未启动"
        echo "2. 配置文件错误"
        echo "3. 端口被其他程序占用"
        echo "4. 防火墙阻止端口监听"
    fi
    
    # 测试端口连通性
    echo ""
    echo -e "${BLUE}端口连通性测试:${NC}"
    
    local public_ip=$(timeout 3 curl -s ipv4.icanhazip.com 2>/dev/null)
    if [[ -n "$public_ip" ]]; then
        echo -n "测试外部连接到 $public_ip:$port... "
        if timeout 5 bash -c "</dev/tcp/$public_ip/$port" &>/dev/null; then
            echo -e "${GREEN}✓ 可连接${NC}"
            add_diagnostic_result "SUCCESS" "外部连接" "端口 $port 外部可连接"
        else
            echo -e "${RED}✗ 无法连接${NC}"
            add_diagnostic_result "WARNING" "外部连接" "端口 $port 外部无法连接，可能被防火墙阻挡" true
        fi
    else
        echo "无法获取公网IP，跳过外部连接测试"
    fi
    
    echo ""
}

# 检查防火墙状态（优化版本）
check_firewall() {
    echo -e "${CYAN}=== 防火墙检查 ===${NC}"
    echo ""
    
    local port="443"
    if [[ -f "$CONFIG_PATH" ]]; then
        port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://' || echo "443")
    fi
    
    local firewall_detected=false
    local port_allowed=false
    
    # 检查 UFW
    if command -v ufw &> /dev/null; then
        echo -e "${BLUE}UFW 防火墙:${NC}"
        local ufw_status=$(ufw status 2>/dev/null)
        local ufw_active=$(echo "$ufw_status" | head -1)
        echo "$ufw_active"
        
        if echo "$ufw_active" | grep -q "Status: active"; then
            firewall_detected=true
            
            # 检查端口规则
            if echo "$ufw_status" | grep -E "^$port\b|^$port/"; then
                echo -e "${GREEN}✓ 端口 $port 在 UFW 规则中${NC}"
                port_allowed=true
                add_diagnostic_result "SUCCESS" "UFW规则" "端口 $port 已在 UFW 中允许"
            else
                echo -e "${YELLOW}⚠ 端口 $port 不在 UFW 规则中${NC}"
                add_diagnostic_result "WARNING" "UFW规则" "端口 $port 未在 UFW 中配置" true
            fi
            
            echo "UFW 规则详情:"
            echo "$ufw_status" | tail -n +4 | head -10 | sed 's/^/  /'
        else
            echo "UFW 未激活"
            add_diagnostic_result "INFO" "UFW状态" "UFW 防火墙未激活"
        fi
        echo ""
    fi
    
    # 检查 firewalld
    if command -v firewall-cmd &> /dev/null; then
        echo -e "${BLUE}Firewalld 防火墙:${NC}"
        if firewall-cmd --state &>/dev/null; then
            echo "运行中"
            firewall_detected=true
            
            # 检查端口是否开放
            if firewall-cmd --list-ports 2>/dev/null | grep -q "$port"; then
                echo -e "${GREEN}✓ 端口 $port 已开放${NC}"
                port_allowed=true
                add_diagnostic_result "SUCCESS" "Firewalld规则" "端口 $port 已在 firewalld 中开放"
            else
                echo -e "${YELLOW}⚠ 端口 $port 未开放${NC}"
                add_diagnostic_result "WARNING" "Firewalld规则" "端口 $port 未在 firewalld 中开放" true
            fi
            
            echo "开放端口:"
            firewall-cmd --list-ports 2>/dev/null | sed 's/^/  /'
            
            echo "活动区域:"
            firewall-cmd --get-active-zones 2>/dev/null | sed 's/^/  /'
        else
            echo "未运行"
            add_diagnostic_result "INFO" "Firewalld状态" "Firewalld 防火墙未运行"
        fi
        echo ""
    fi
    
    # 检查 iptables
    if command -v iptables &> /dev/null; then
        echo -e "${BLUE}iptables 规则:${NC}"
        firewall_detected=true
        
        # 检查 INPUT 链中的端口规则
        local iptables_rules=$(iptables -L INPUT -n 2>/dev/null)
        if echo "$iptables_rules" | grep -q "$port"; then
            echo -e "${GREEN}✓ 发现端口 $port 相关规则${NC}"
            echo "相关规则:"
            echo "$iptables_rules" | grep "$port" | sed 's/^/  /'
            add_diagnostic_result "SUCCESS" "iptables规则" "发现端口 $port 相关的 iptables 规则"
        else
            echo -e "${YELLOW}⚠ 未发现端口 $port 相关规则${NC}"
            add_diagnostic_result "WARNING" "iptables规则" "未发现端口 $port 的 iptables 规则" false
        fi
        
        # 检查默认策略
        local default_policy=$(iptables -L INPUT 2>/dev/null | head -1 | grep -o 'policy [A-Z]*' | cut -d' ' -f2)
        if [[ "$default_policy" == "DROP" || "$default_policy" == "REJECT" ]]; then
            echo "INPUT 链默认策略: $default_policy"
            add_diagnostic_result "INFO" "iptables策略" "INPUT 链默认策略为 $default_policy，需要明确允许端口"
        fi
        echo ""
    fi
    
    # 总结防火墙状态
    if [[ "$firewall_detected" == false ]]; then
        echo -e "${GREEN}✓ 未检测到活跃的防火墙，端口访问不受限制${NC}"
        add_diagnostic_result "INFO" "防火墙状态" "未检测到活跃的防火墙"
    elif [[ "$port_allowed" == true ]]; then
        echo -e "${GREEN}✓ 防火墙已正确配置，端口 $port 已允许${NC}"
        add_diagnostic_result "SUCCESS" "防火墙配置" "防火墙已正确配置端口 $port"
    else
        echo -e "${YELLOW}⚠ 防火墙可能阻止端口 $port 访问${NC}"
        add_diagnostic_result "WARNING" "防火墙阻挡" "防火墙可能阻止端口 $port 访问" true
    fi
    
    echo ""
}

# 检查网络连通性（优化版本）
check_network_connectivity() {
    echo -e "${CYAN}=== 网络连通性检查 ===${NC}"
    echo ""
    
    # DNS 解析测试
    echo -e "${BLUE}DNS 解析测试:${NC}"
    local dns_servers=("8.8.8.8" "1.1.1.1" "114.114.114.114")
    local dns_ok=false
    
    for dns in "${dns_servers[@]}"; do
        echo -n "测试 DNS $dns... "
        if timeout 3 nslookup google.com "$dns" &>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            dns_ok=true
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    if [[ "$dns_ok" == true ]]; then
        add_diagnostic_result "SUCCESS" "DNS解析" "DNS 解析正常"
    else
        add_diagnostic_result "CRITICAL" "DNS解析" "DNS 解析失败" true
    fi
    
    echo ""
    
    # 外网连接测试
    echo -e "${BLUE}外网连接测试:${NC}"
    local test_sites=("google.com" "cloudflare.com" "github.com")
    local connectivity_ok=false
    
    for site in "${test_sites[@]}"; do
        echo -n "连接 $site... "
        if timeout 5 curl -s --connect-timeout 3 "$site" &>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            connectivity_ok=true
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    if [[ "$connectivity_ok" == true ]]; then
        add_diagnostic_result "SUCCESS" "外网连接" "外网连接正常"
    else
        add_diagnostic_result "CRITICAL" "外网连接" "外网连接失败" true
    fi
    
    echo ""
    
    # 网络接口检查
    echo -e "${BLUE}网络接口检查:${NC}"
    local interfaces=$(ip link show | grep -E "^[0-9]+:" | grep "UP" | awk -F': ' '{print $2}' | grep -v lo)
    
    if [[ -n "$interfaces" ]]; then
        echo "活跃网络接口:"
        echo "$interfaces" | while read -r interface; do
            local ip=$(ip addr show "$interface" | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            echo "  $interface: ${ip:-无IP}"
        done
        add_diagnostic_result "SUCCESS" "网络接口" "网络接口正常"
    else
        echo -e "${RED}✗ 未找到活跃的网络接口${NC}"
        add_diagnostic_result "CRITICAL" "网络接口" "未找到活跃的网络接口" true
    fi
    
    echo ""
    
    # 路由表检查
    echo -e "${BLUE}路由检查:${NC}"
    local default_route=$(ip route | grep default)
    if [[ -n "$default_route" ]]; then
        echo "默认路由:"
        echo "$default_route" | sed 's/^/  /'
        add_diagnostic_result "SUCCESS" "路由配置" "默认路由配置正常"
    else
        echo -e "${RED}✗ 未找到默认路由${NC}"
        add_diagnostic_result "CRITICAL" "路由配置" "未找到默认路由" true
    fi
    
    echo ""
}

# 检查日志错误（优化版本）
check_logs() {
    echo -e "${CYAN}=== 日志错误检查 ===${NC}"
    echo ""
    
    if ! command -v journalctl >/dev/null; then
        echo -e "${YELLOW}journalctl 命令不可用，无法检查日志${NC}"
        add_diagnostic_result "WARNING" "日志检查" "journalctl 不可用"
        return 1
    fi
    
    # 检查不同时间段的日志
    local time_periods=("1 hour" "6 hours" "24 hours")
    
    for period in "${time_periods[@]}"; do
        echo -e "${BLUE}最近 $period 的日志统计:${NC}"
        
        local error_count=$(journalctl -u hysteria-server.service --since "$period ago" --no-pager -q 2>/dev/null | grep -ic "error" || echo "0")
        local warning_count=$(journalctl -u hysteria-server.service --since "$period ago" --no-pager -q 2>/dev/null | grep -ic "warn" || echo "0")
        local fatal_count=$(journalctl -u hysteria-server.service --since "$period ago" --no-pager -q 2>/dev/null | grep -ic "fatal" || echo "0")
        local total_lines=$(journalctl -u hysteria-server.service --since "$period ago" --no-pager -q 2>/dev/null | wc -l || echo "0")
        
        echo "  总日志行数: $total_lines"
        echo "  错误消息: $error_count"
        echo "  警告消息: $warning_count"
        echo "  严重错误: $fatal_count"
        
        # 根据错误数量判断问题严重性
        if [[ $fatal_count -gt 0 ]]; then
            add_diagnostic_result "CRITICAL" "日志分析" "最近 $period 发现 $fatal_count 个严重错误" true
        elif [[ $error_count -gt 10 ]]; then
            add_diagnostic_result "WARNING" "日志分析" "最近 $period 错误消息较多: $error_count 个" false
        elif [[ $error_count -eq 0 && $warning_count -eq 0 ]]; then
            add_diagnostic_result "SUCCESS" "日志分析" "最近 $period 无错误或警告"
        fi
        
        echo ""
    done
    
    # 显示最近的严重错误
    echo -e "${BLUE}最近的严重错误 (如果有):${NC}"
    local recent_errors=$(journalctl -u hysteria-server.service --since "24 hours ago" --no-pager -q 2>/dev/null | grep -iE "error|fatal" | tail -3)
    
    if [[ -n "$recent_errors" ]]; then
        echo "$recent_errors" | sed 's/^/  /'
        add_diagnostic_result "WARNING" "最近错误" "发现最近的错误日志"
    else
        echo -e "${GREEN}✓ 未发现最近的严重错误${NC}"
    fi
    
    echo ""
}

# 自动修复功能
auto_fix_issues() {
    echo -e "${CYAN}=== 自动修复问题 ===${NC}"
    echo ""
    
    local fixed_count=0
    local failed_count=0
    
    # 遍历诊断结果，寻找可修复的问题
    for result in "${DIAGNOSTIC_RESULTS[@]}"; do
        IFS='|' read -r level category message fix_available <<< "$result"
        
        if [[ "$fix_available" == "true" && ("$level" == "CRITICAL" || "$level" == "WARNING") ]]; then
            echo -e "${BLUE}正在修复: $message${NC}"
            
            case "$category" in
                "程序安装")
                    if ! command -v hysteria >/dev/null; then
                        echo "  尝试安装 Hysteria2..."
                        if bash <(curl -fsSL https://get.hy2.sh/) 2>/dev/null; then
                            echo -e "  ${GREEN}✓ Hysteria2 安装成功${NC}"
                            ((fixed_count++))
                        else
                            echo -e "  ${RED}✗ 安装失败${NC}"
                            ((failed_count++))
                        fi
                    fi
                    ;;
                    
                "文件权限")
                    if [[ -f "$CONFIG_PATH" ]]; then
                        echo "  修复配置文件权限..."
                        if chmod 600 "$CONFIG_PATH"; then
                            echo -e "  ${GREEN}✓ 权限修复成功${NC}"
                            ((fixed_count++))
                        else
                            echo -e "  ${RED}✗ 权限修复失败${NC}"
                            ((failed_count++))
                        fi
                    fi
                    ;;
                    
                "私钥权限")
                    local key_file=$(grep -A 3 "^tls:" "$CONFIG_PATH" 2>/dev/null | grep "key:" | awk '{print $2}')
                    if [[ -f "$key_file" ]]; then
                        echo "  修复私钥文件权限..."
                        if chmod 600 "$key_file"; then
                            echo -e "  ${GREEN}✓ 私钥权限修复成功${NC}"
                            ((fixed_count++))
                        else
                            echo -e "  ${RED}✗ 私钥权限修复失败${NC}"
                            ((failed_count++))
                        fi
                    fi
                    ;;
                    
                "服务状态")
                    if ! systemctl is-active --quiet hysteria-server.service; then
                        echo "  尝试启动服务..."
                        if systemctl start hysteria-server.service; then
                            echo -e "  ${GREEN}✓ 服务启动成功${NC}"
                            ((fixed_count++))
                        else
                            echo -e "  ${RED}✗ 服务启动失败${NC}"
                            ((failed_count++))
                        fi
                    fi
                    ;;
                    
                "开机自启")
                    if ! systemctl is-enabled --quiet hysteria-server.service; then
                        echo "  启用开机自启..."
                        if systemctl enable hysteria-server.service; then
                            echo -e "  ${GREEN}✓ 开机自启启用成功${NC}"
                            ((fixed_count++))
                        else
                            echo -e "  ${RED}✗ 开机自启启用失败${NC}"
                            ((failed_count++))
                        fi
                    fi
                    ;;
                    
                "系统资源")
                    if [[ "$message" == *"内存"* ]]; then
                        echo "  尝试释放内存..."
                        if sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null; then
                            echo -e "  ${GREEN}✓ 内存释放完成${NC}"
                            ((fixed_count++))
                        else
                            echo -e "  ${YELLOW}⚠ 内存释放权限不足${NC}"
                        fi
                    fi
                    ;;
                    
                "UFW规则"|"Firewalld规则"|"防火墙阻挡")
                    local port=$(grep -E "^listen:" "$CONFIG_PATH" 2>/dev/null | awk '{print $2}' | sed 's/://' || echo "443")
                    
                    if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
                        echo "  配置 UFW 规则..."
                        if ufw allow "$port" 2>/dev/null; then
                            echo -e "  ${GREEN}✓ UFW 规则添加成功${NC}"
                            ((fixed_count++))
                        else
                            echo -e "  ${RED}✗ UFW 规则添加失败${NC}"
                            ((failed_count++))
                        fi
                    elif command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
                        echo "  配置 firewalld 规则..."
                        if firewall-cmd --permanent --add-port="$port/tcp" 2>/dev/null && firewall-cmd --reload 2>/dev/null; then
                            echo -e "  ${GREEN}✓ firewalld 规则添加成功${NC}"
                            ((fixed_count++))
                        else
                            echo -e "  ${RED}✗ firewalld 规则添加失败${NC}"
                            ((failed_count++))
                        fi
                    fi
                    ;;
                    
                "配置文件")
                    if [[ ! -f "$CONFIG_PATH" ]]; then
                        echo "  创建基础配置文件..."
                        mkdir -p "$(dirname "$CONFIG_PATH")"
                        cat > "$CONFIG_PATH" << 'EOF'
listen: :443

auth:
  type: password
  password: changeme

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com/
    rewriteHost: true
EOF
                        chmod 600 "$CONFIG_PATH"
                        echo -e "  ${GREEN}✓ 基础配置文件创建成功${NC}"
                        echo -e "  ${YELLOW}⚠ 请手动配置认证密码和证书${NC}"
                        ((fixed_count++))
                    fi
                    ;;
                    
                *)
                    echo -e "  ${YELLOW}⚠ 暂不支持自动修复此类问题${NC}"
                    ;;
            esac
            
            echo ""
        fi
    done
    
    # 修复总结
    echo -e "${CYAN}修复总结:${NC}"
    echo "成功修复: $fixed_count 个问题"
    echo "修复失败: $failed_count 个问题"
    
    if [[ $fixed_count -gt 0 ]]; then
        echo -e "${GREEN}建议重新运行诊断以验证修复结果${NC}"
    fi
    
    echo ""
}

# 生成详细诊断报告
generate_diagnostic_report() {
    local report_file="/tmp/hysteria2-diagnostic-$(date +%Y%m%d_%H%M%S).txt"
    local html_report_file="/tmp/hysteria2-diagnostic-$(date +%Y%m%d_%H%M%S).html"
    
    echo -e "${BLUE}生成详细诊断报告...${NC}"
    
    # 生成文本报告
    {
        echo "Hysteria2 详细诊断报告"
        echo "========================================"
        echo "生成时间: $(date)"
        echo "系统信息: $(uname -a)"
        echo "报告版本: v2.0"
        echo ""
        
        echo "========================================"
        echo "诊断结果汇总"
        echo "========================================"
        
        local critical_count=0
        local warning_count=0
        local success_count=0
        local info_count=0
        
        for result in "${DIAGNOSTIC_RESULTS[@]}"; do
            IFS='|' read -r level category message fix_available <<< "$result"
            case "$level" in
                "CRITICAL") ((critical_count++)) ;;
                "WARNING") ((warning_count++)) ;;
                "SUCCESS") ((success_count++)) ;;
                "INFO") ((info_count++)) ;;
            esac
        done
        
        echo "严重问题: $critical_count"
        echo "警告问题: $warning_count"
        echo "正常项目: $success_count"
        echo "信息项目: $info_count"
        echo ""
        
        echo "========================================"
        echo "详细诊断结果"
        echo "========================================"
        
        for result in "${DIAGNOSTIC_RESULTS[@]}"; do
            IFS='|' read -r level category message fix_available <<< "$result"
            echo "[$level] $category: $message"
            if [[ "$fix_available" == "true" ]]; then
                echo "  └─ 支持自动修复"
            fi
            echo ""
        done
        
        echo "========================================"
        echo "系统详细信息"
        echo "========================================"
        check_system_info 2>&1
        
        echo "========================================"
        echo "安装状态"
        echo "========================================"
        check_hysteria_installation 2>&1
        
        echo "========================================"
        echo "配置检查"
        echo "========================================"
        check_configuration 2>&1
        
        echo "========================================"
        echo "证书检查"
        echo "========================================"
        check_certificates 2>&1
        
        echo "========================================"
        echo "服务状态"
        echo "========================================"
        check_service_status 2>&1
        
        echo "========================================"
        echo "端口检查"
        echo "========================================"
        check_port_listening 2>&1
        
        echo "========================================"
        echo "防火墙检查"
        echo "========================================"
        check_firewall 2>&1
        
        echo "========================================"
        echo "网络连通性"
        echo "========================================"
        check_network_connectivity 2>&1
        
        echo "========================================"
        echo "日志分析"
        echo "========================================"
        check_logs 2>&1
        
        echo "========================================"
        echo "报告结束"
        echo "========================================"
        
    } > "$report_file" 2>&1
    
    # 生成 HTML 报告
    generate_html_report "$html_report_file"
    
    echo -e "${GREEN}诊断报告已生成:${NC}"
    echo "文本版本: $report_file"
    echo "HTML版本: $html_report_file"
    echo ""
    
    echo -n -e "${BLUE}选择查看方式:${NC}"
    echo ""
    echo "1. 查看文本报告"
    echo "2. 在浏览器中打开HTML报告"
    echo "3. 不查看"
    echo ""
    echo -n -e "${BLUE}请选择 [1-3]: ${NC}"
    read -r view_choice
    
    case $view_choice in
        1)
            if command -v less >/dev/null; then
                less "$report_file"
            else
                cat "$report_file"
            fi
            ;;
        2)
            echo "HTML报告路径: $html_report_file"
            echo "请在浏览器中打开此文件查看详细报告"
            ;;
        3)
            ;;
        *)
            echo -e "${YELLOW}无效选择${NC}"
            ;;
    esac
}

# 生成 HTML 报告
generate_html_report() {
    local html_file=$1
    
    cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hysteria2 诊断报告</title>
    <style>
        body { font-family: 'Arial', sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; border-bottom: 3px solid #007acc; padding-bottom: 10px; }
        h2 { color: #007acc; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .summary-item { padding: 15px; border-radius: 5px; text-align: center; font-weight: bold; }
        .critical { background-color: #ffebee; color: #c62828; border-left: 4px solid #c62828; }
        .warning { background-color: #fff3e0; color: #ef6c00; border-left: 4px solid #ef6c00; }
        .success { background-color: #e8f5e8; color: #2e7d32; border-left: 4px solid #2e7d32; }
        .info { background-color: #e3f2fd; color: #1565c0; border-left: 4px solid #1565c0; }
        .result-item { margin: 10px 0; padding: 10px; border-radius: 5px; }
        .timestamp { text-align: right; color: #666; font-size: 0.9em; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; }
        .expandable { cursor: pointer; user-select: none; }
        .expandable:hover { background-color: #f0f0f0; }
        .content { display: none; margin-top: 10px; padding: 10px; background-color: #f9f9f9; border-radius: 3px; }
        .expanded .content { display: block; }
    </style>
    <script>
        function toggleContent(element) {
            element.classList.toggle('expanded');
        }
    </script>
</head>
<body>
    <div class="container">
        <h1>🔍 Hysteria2 诊断报告</h1>
        <div class="timestamp">生成时间: REPLACE_TIMESTAMP</div>
        
        <h2>📊 诊断结果汇总</h2>
        <div class="summary">
            <div class="summary-item critical">
                <div>严重问题</div>
                <div style="font-size: 2em;">REPLACE_CRITICAL_COUNT</div>
            </div>
            <div class="summary-item warning">
                <div>警告问题</div>
                <div style="font-size: 2em;">REPLACE_WARNING_COUNT</div>
            </div>
            <div class="summary-item success">
                <div>正常项目</div>
                <div style="font-size: 2em;">REPLACE_SUCCESS_COUNT</div>
            </div>
            <div class="summary-item info">
                <div>信息项目</div>
                <div style="font-size: 2em;">REPLACE_INFO_COUNT</div>
            </div>
        </div>
        
        <h2>📋 详细诊断结果</h2>
        <div id="results">
            REPLACE_DETAILED_RESULTS
        </div>
        
        <h2>💡 修复建议</h2>
        <div id="suggestions">
            REPLACE_FIX_SUGGESTIONS
        </div>
        
        <h2>🔧 系统信息</h2>
        <div class="expandable" onclick="toggleContent(this)">
            <strong>展开/收起系统详细信息</strong>
            <div class="content">
                <pre>REPLACE_SYSTEM_INFO</pre>
            </div>
        </div>
    </div>
</body>
</html>
EOF

    # 替换内容
    local timestamp=$(date)
    local critical_count=0
    local warning_count=0
    local success_count=0
    local info_count=0
    local detailed_results=""
    local fix_suggestions=""
    
    for result in "${DIAGNOSTIC_RESULTS[@]}"; do
        IFS='|' read -r level category message fix_available <<< "$result"
        case "$level" in
            "CRITICAL") ((critical_count++)) ;;
            "WARNING") ((warning_count++)) ;;
            "SUCCESS") ((success_count++)) ;;
            "INFO") ((info_count++)) ;;
        esac
        
        detailed_results+="<div class=\"result-item $level\"><strong>[$level] $category:</strong> $message"
        if [[ "$fix_available" == "true" ]]; then
            detailed_results+=" <em>(支持自动修复)</em>"
            fix_suggestions+="<li><strong>$category:</strong> $message</li>"
        fi
        detailed_results+="</div>"
    done
    
    if [[ -z "$fix_suggestions" ]]; then
        fix_suggestions="<div class=\"success\">✅ 暂无需要修复的问题</div>"
    else
        fix_suggestions="<ul>$fix_suggestions</ul><p><strong>提示:</strong> 运行脚本的自动修复功能来解决这些问题。</p>"
    fi
    
    # 获取系统信息
    local system_info
    system_info=$(check_system_info 2>&1 | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    
    # 执行替换
    sed -i "s/REPLACE_TIMESTAMP/$timestamp/g" "$html_file"
    sed -i "s/REPLACE_CRITICAL_COUNT/$critical_count/g" "$html_file"
    sed -i "s/REPLACE_WARNING_COUNT/$warning_count/g" "$html_file"
    sed -i "s/REPLACE_SUCCESS_COUNT/$success_count/g" "$html_file"
    sed -i "s/REPLACE_INFO_COUNT/$info_count/g" "$html_file"
    sed -i "s|REPLACE_DETAILED_RESULTS|$detailed_results|g" "$html_file"
    sed -i "s|REPLACE_FIX_SUGGESTIONS|$fix_suggestions|g" "$html_file"
    sed -i "s|REPLACE_SYSTEM_INFO|$system_info|g" "$html_file"
}

# 快速健康检查
quick_health_check() {
    echo -e "${BLUE}快速健康检查${NC}"
    echo ""
    
    local issues=0
    
    # 重置诊断结果
    DIAGNOSTIC_RESULTS=()
    
    echo -n "检查 Hysteria 安装... "
    if command -v hysteria >/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        ((issues++))
        add_diagnostic_result "CRITICAL" "程序安装" "Hysteria2 未安装" true
    fi
    
    echo -n "检查配置文件... "
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "${GREEN}✓${NC}"
        add_diagnostic_result "SUCCESS" "配置文件" "配置文件存在"
    else
        echo -e "${RED}✗${NC}"
        ((issues++))
        add_diagnostic_result "CRITICAL" "配置文件" "配置文件不存在" true
    fi
    
    echo -n "检查服务状态... "
    if systemctl is-active --quiet hysteria-server.service; then
        echo -e "${GREEN}✓${NC}"
        add_diagnostic_result "SUCCESS" "服务状态" "服务正在运行"
    else
        echo -e "${RED}✗${NC}"
        ((issues++))
        add_diagnostic_result "CRITICAL" "服务状态" "服务未运行" true
    fi
    
    echo -n "检查端口监听... "
    local port=$(grep -E "^listen:" "$CONFIG_PATH" 2>/dev/null | awk '{print $2}' | sed 's/://' || echo "443")
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓${NC}"
        add_diagnostic_result "SUCCESS" "端口监听" "端口 $port 正在监听"
    else
        echo -e "${RED}✗${NC}"
        ((issues++))
        add_diagnostic_result "CRITICAL" "端口监听" "端口 $port 未监听" true
    fi
    
    echo -n "检查网络连通性... "
    if timeout 3 curl -s google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        add_diagnostic_result "SUCCESS" "网络连接" "网络连通正常"
    else
        echo -e "${RED}✗${NC}"
        ((issues++))
        add_diagnostic_result "WARNING" "网络连接" "网络连接可能有问题" false
    fi
    
    echo ""
    echo -e "${CYAN}快速检查结果:${NC}"
    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}✓ 系统健康，未发现问题${NC}"
    else
        echo -e "${RED}✗ 发现 $issues 个问题${NC}"
        echo -e "${BLUE}建议运行完整诊断获取详细信息${NC}"
    fi
    
    return $issues
}

# 主诊断函数（优化版本）
run_diagnostics() {
    while true; do
        clear
        echo -e "${BLUE}Hysteria2 故障排除和诊断 - 优化版本${NC}"
        echo ""
        
        # 显示快速状态
        if systemctl is-active --quiet hysteria-server.service 2>/dev/null; then
            echo -e "服务状态: ${GREEN}●${NC} 运行中"
        else
            echo -e "服务状态: ${RED}●${NC} 已停止"
        fi
        
        if [[ -f "$CONFIG_PATH" ]]; then
            echo -e "配置文件: ${GREEN}存在${NC}"
        else
            echo -e "配置文件: ${RED}不存在${NC}"
        fi
        
        echo ""
        echo -e "${YELLOW}检查选项:${NC}"
        echo -e "${GREEN}1.${NC} 快速健康检查"
        echo -e "${GREEN}2.${NC} 系统信息检查"
        echo -e "${GREEN}3.${NC} Hysteria2 安装检查"
        echo -e "${GREEN}4.${NC} 配置文件检查"
        echo -e "${GREEN}5.${NC} 证书文件检查"
        echo -e "${GREEN}6.${NC} 服务状态检查"
        echo -e "${GREEN}7.${NC} 端口监听检查"
        echo -e "${GREEN}8.${NC} 防火墙检查"
        echo -e "${GREEN}9.${NC} 网络连通性检查"
        echo -e "${GREEN}10.${NC} 日志错误检查"
        echo ""
        echo -e "${YELLOW}综合功能:${NC}"
        echo -e "${GREEN}11.${NC} 完整诊断 (所有检查)"
        echo -e "${GREEN}12.${NC} 自动修复问题"
        echo -e "${GREEN}13.${NC} 生成诊断报告"
        echo ""
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择检查项目 [0-13]: ${NC}"
        read -r choice
        
        # 重置诊断结果
        DIAGNOSTIC_RESULTS=()
        
        case $choice in
            1) 
                clear
                quick_health_check
                echo ""
                read -p "按回车键继续..."
                ;;
            2) 
                clear
                check_system_info
                read -p "按回车键继续..." 
                ;;
            3) 
                clear
                check_hysteria_installation
                read -p "按回车键继续..." 
                ;;
            4) 
                clear
                check_configuration
                read -p "按回车键继续..." 
                ;;
            5) 
                clear
                check_certificates
                read -p "按回车键继续..." 
                ;;
            6) 
                clear
                check_service_status
                read -p "按回车键继续..." 
                ;;
            7) 
                clear
                check_port_listening
                read -p "按回车键继续..." 
                ;;
            8) 
                clear
                check_firewall
                read -p "按回车键继续..." 
                ;;
            9) 
                clear
                check_network_connectivity
                read -p "按回车键继续..." 
                ;;
            10) 
                clear
                check_logs
                read -p "按回车键继续..." 
                ;;
            11)
                clear
                echo -e "${BLUE}执行完整诊断...${NC}"
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
                
                # 总结
                local critical_count=0
                local warning_count=0
                for result in "${DIAGNOSTIC_RESULTS[@]}"; do
                    IFS='|' read -r level _ _ _ <<< "$result"
                    case "$level" in
                        "CRITICAL") ((critical_count++)) ;;
                        "WARNING") ((warning_count++)) ;;
                    esac
                done
                
                echo ""
                echo -e "${CYAN}完整诊断总结:${NC}"
                echo "严重问题: $critical_count 个"
                echo "警告问题: $warning_count 个"
                
                if [[ $critical_count -eq 0 && $warning_count -eq 0 ]]; then
                    echo -e "${GREEN}✓ 系统完全健康${NC}"
                elif [[ $critical_count -eq 0 ]]; then
                    echo -e "${YELLOW}⚠ 系统基本健康，有一些警告${NC}"
                else
                    echo -e "${RED}✗ 发现严重问题，需要修复${NC}"
                fi
                
                read -p "按回车键继续..."
                ;;
            12)
                clear
                if [[ ${#DIAGNOSTIC_RESULTS[@]} -eq 0 ]]; then
                    echo -e "${YELLOW}请先运行诊断检查${NC}"
                    echo -n -e "${BLUE}是否运行快速健康检查? [Y/n]: ${NC}"
                    read -r run_check
                    if [[ ! $run_check =~ ^[Nn]$ ]]; then
                        quick_health_check
                        echo ""
                    fi
                fi
                
                if [[ ${#DIAGNOSTIC_RESULTS[@]} -gt 0 ]]; then
                    auto_fix_issues
                else
                    echo -e "${YELLOW}没有可修复的问题${NC}"
                fi
                read -p "按回车键继续..."
                ;;
            13)
                clear
                if [[ ${#DIAGNOSTIC_RESULTS[@]} -eq 0 ]]; then
                    echo -e "${BLUE}正在执行完整诊断以生成报告...${NC}"
                    echo ""
                    check_system_info >/dev/null 2>&1
                    check_hysteria_installation >/dev/null 2>&1
                    check_configuration >/dev/null 2>&1
                    check_certificates >/dev/null 2>&1
                    check_service_status >/dev/null 2>&1
                    check_port_listening >/dev/null 2>&1
                    check_firewall >/dev/null 2>&1
                    check_network_connectivity >/dev/null 2>&1
                    check_logs >/dev/null 2>&1
                fi
                generate_diagnostic_report
                read -p "按回车键继续..."
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
}#!/bin/bash

# Hysteria2 故障排除和诊断脚本 - 优化版本

# 自动修复问题的计数器
FIXED_ISSUES=0
FAILED_FIXES=0

# 问题等级定义
declare -A ISSUE_LEVELS=(
    ["CRITICAL"]="${RED}严重${NC}"
    ["WARNING"]="${YELLOW}警告${NC}"
    ["INFO"]="${BLUE}信息${NC}"
    ["SUCCESS"]="${GREEN}正常${NC}"
)

# 记录诊断结果
declare -a DIAGNOSTIC_RESULTS=()

# 添加诊断结果
add_diagnostic_result() {
    local level=$1
    local category=$2
    local message=$3
    local fix_available=${4:-false}
    
    DIAGNOSTIC_RESULTS+=("$level|$category|$message|$fix_available")
}

# 系统信息检查（优化版本）
check_system_info() {
    echo -e "${CYAN}=== 系统信息检查 ===${NC}"
    echo ""
    
    echo -e "${BLUE}操作系统信息:${NC}"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "发行版: $PRETTY_NAME"
        echo "版本: $VERSION"
        echo "ID: $ID"
        echo "内核: $(uname -r)"
        
        # 检查系统是否支持
        case $ID in
            ubuntu|debian|centos|rhel|fedora|opensuse*)
                add_diagnostic_result "SUCCESS" "系统兼容性" "支持的操作系统: $PRETTY_NAME"
                ;;
            *)
                add_diagnostic_result "WARNING" "系统兼容性" "未完全测试的操作系统: $PRETTY_NAME"
                ;;
        esac
    fi
    
    echo ""
    echo -e "${BLUE}硬件信息:${NC}"
    echo "架构: $(uname -m)"
    echo "CPU核心: $(nproc)"
    
    # 内存检查
    local mem_total=$(free -m | awk '/^Mem:/ {print $2}')
    local mem_available=$(free -m | awk '/^Mem:/ {print $7}')
    local mem_usage_percent=$((($mem_total - $mem_available) * 100 / $mem_total))
    
    echo "内存总量: ${mem_total}MB"
    echo "可用内存: ${mem_available}MB (使用率: ${mem_usage_percent}%)"
    
    if [[ $mem_available -lt 128 ]]; then
        add_diagnostic_result "WARNING" "系统资源" "可用内存不足: ${mem_available}MB" true
    elif [[ $mem_usage_percent -gt 90 ]]; then
        add_diagnostic_result "WARNING" "系统资源" "内存使用率过高: ${mem_usage_percent}%" true
    else
        add_diagnostic_result "SUCCESS" "系统资源" "内存充足: ${mem_available}MB 可用"
    fi
    
    # 磁盘检查
    local disk_info=$(df -h / | tail -1)
    local disk_usage=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
    local disk_available=$(echo "$disk_info" | awk '{print $4}')
    
    echo "磁盘使用: ${disk_usage}% (可用: ${disk_available})"
    
    if [[ $disk_usage -gt 90 ]]; then
        add_diagnostic_result "CRITICAL" "磁盘空间" "磁盘使用率过高: ${disk_usage}%" true
    elif [[ $disk_usage -gt 80 ]]; then
        add_diagnostic_result "WARNING" "磁盘空间" "磁盘使用率较高: ${disk_usage}%" false
    else
        add_diagnostic_result "SUCCESS" "磁盘空间" "磁盘空间充足"
    fi
    
    echo ""
    echo -e "${BLUE}网络信息:${NC}"
    echo "主机名: $(hostname)"
    
    # 内网IP
    local internal_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    if [[ -n "$internal_ip" ]]; then
        echo "内网IP: $internal_ip"
        add_diagnostic_result "SUCCESS" "网络配置" "内网IP: $internal_ip"
    else
        echo "内网IP: 无法获取"
        add_diagnostic_result "WARNING" "网络配置" "无法获取内网IP" true
    fi
    
    # 公网IP
    local public_ip=$(timeout 5 curl -s ipv4.icanhazip.com 2>/dev/null || timeout 5 curl -s ifconfig.me 2>/dev/null)
    if [[ -n "$public_ip" ]]; then
        echo "公网IP: $public_ip"
        add_diagnostic_result "SUCCESS" "网络连接" "公网IP: $public_ip"
    else
        echo "公网IP: 无法获取"
        add_diagnostic_result "CRITICAL" "网络连接" "无法获取公网IP，网络可能有问题" true
    fi
    
    echo ""
}

# 检查 Hysteria2 安装状态（优化版本）
check_hysteria_installation() {
    echo -e "${CYAN}=== Hysteria2 安装检查 ===${NC}"
    echo ""
    
    if command -v hysteria &> /dev/null; then
        local version=$(hysteria version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "未知版本")
        echo -e "${GREEN}✓ Hysteria2 已安装${NC}"
        echo "版本: $version"
        echo "路径: $(which hysteria)"
        
        # 检查可执行文件权限
        local hysteria_path=$(which hysteria)
        local perms=$(stat -c %a "$hysteria_path" 2>/dev/null || stat -f %Lp "$hysteria_path" 2>/dev/null)
        echo "权限: $perms"
        
        add_diagnostic_result "SUCCESS" "程序安装" "Hysteria2 已安装: $version"
        
        # 检查版本是否是最新的（简单检查）
        if [[ "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            add_diagnostic_result "INFO" "版本信息" "版本格式正常: $version"
        else
            add_diagnostic_result "WARNING" "版本信息" "版本格式异常: $version"
        fi
        
    else
        echo -e "${RED}✗ Hysteria2 未安装${NC}"
        add_diagnostic_result "CRITICAL" "程序安装" "Hysteria2 未安装" true
        return 1
    fi
    
    echo ""
}

# 检查配置文件（优化版本）
check_configuration() {
    echo -e "${CYAN}=== 配置文件检查 ===${NC}"
    echo ""
    
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "${GREEN}✓ 配置文件存在${NC}"
        echo "路径: $CONFIG_PATH"
        echo "大小: $(du -h "$CONFIG_PATH" | cut -f1)"
        echo "修改时间: $(stat -c %y "$CONFIG_PATH" 2>/dev/null | cut -d. -f1 || stat -f %Sm "$CONFIG_PATH" 2>/dev/null)"
        
        # 检查配置文件权限
        local perms=$(stat -c %a "$CONFIG_PATH" 2>/dev/null || stat -f %Lp "$CONFIG_PATH" 2>/dev/null)
        echo "文件权限: $perms"
        
        if [[ "$perms" == "600" ]]; then
            add_diagnostic_result "SUCCESS" "文件权限" "配置文件权限正确: $perms"
        else
            add_diagnostic_result "WARNING" "文件权限" "配置文件权限不安全: $perms (建议: 600)" true
        fi
        
        # 检查配置文件所有者
        local owner=$(stat -c %U:%G "$CONFIG_PATH" 2>/dev/null || stat -f %Su:%Sg "$CONFIG_PATH" 2>/dev/null)
        echo "文件所有者: $owner"
        
        # 检查配置文件语法
        echo ""
        echo -e "${BLUE}配置文件语法检查:${NC}"
        if command -v hysteria >/dev/null; then
            if hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
                echo -e "${GREEN}✓ 配置文件语法正确${NC}"
                add_diagnostic_result "SUCCESS" "配置语法" "配置文件语法正确"
            else
                echo -e "${RED}✗ 配置文件语法错误${NC}"
                echo "语法错误详情:"
                hysteria server --config "$CONFIG_PATH" --check 2>&1 | head -5 | sed 's/^/  /'
                add_diagnostic_result "CRITICAL" "配置语法" "配置文件语法错误" true
            fi
        else
            echo -e "${YELLOW}⚠ 无法验证语法 (hysteria 命令不可用)${NC}"
            add_diagnostic_result "WARNING" "配置验证" "无法验证配置文件语法"
        fi
        
        # 分析配置内容
        echo ""
        echo -e "${BLUE}配置内容分析:${NC}"
        
        # 监听端口
        local port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://')
        if [[ -n "$port" ]]; then
            echo "监听端口: $port"
            add_diagnostic_result "INFO" "端口配置" "监听端口: $port"
        else
            echo "监听端口: 443 (默认)"
            add_diagnostic_result "INFO" "端口配置" "使用默认端口: 443"
        fi
        
        # 认证配置
        local auth_type=$(grep -A 2 "^auth:" "$CONFIG_PATH" | grep "type:" | awk '{print $2}')
        if [[ -n "$auth_type" ]]; then
            echo "认证方式: $auth_type"
            add_diagnostic_result "SUCCESS" "认证配置" "已配置认证: $auth_type"
        else
            echo -e "${RED}认证方式: 未配置${NC}"
            add_diagnostic_result "CRITICAL" "认证配置" "未配置认证方式" true
        fi
        
        # 证书配置
        if grep -q "^acme:" "$CONFIG_PATH"; then
            echo "证书类型: ACME 自动证书"
            local domains=$(grep -A 5 "^acme:" "$CONFIG_PATH" | grep -E "^\s*-" | head -5 | awk '{print $2}' | tr '\n' ' ')
            echo "ACME 域名: ${domains:-未设置}"
            add_diagnostic_result "SUCCESS" "证书配置" "ACME 自动证书已配置"
        elif grep -q "^tls:" "$CONFIG_PATH"; then
            echo "证书类型: 手动证书"
            local cert_path=$(grep -A 3 "^tls:" "$CONFIG_PATH" | grep "cert:" | awk '{print $2}')
            local key_path=$(grep -A 3 "^tls:" "$CONFIG_PATH" | grep "key:" | awk '{print $2}')
            echo "证书路径: $cert_path"
            echo "私钥路径: $key_path"
            add_diagnostic_result "SUCCESS" "证书配置" "手动证书已配置"
        else
            echo -e "${RED}证书类型: 未配置${NC}"
            add_diagnostic_result "CRITICAL" "证书配置" "未配置证书" true
        fi
        
        # 混淆配置
        if grep -q "^obfs:" "$CONFIG_PATH"; then
            local obfs_type=$(grep -A 3 "^obfs:" "$CONFIG_PATH" | grep "type:" | awk '{print $2}')
            echo "混淆配置: 已启用 ($obfs_type)"
            add_diagnostic_result "SUCCESS" "混淆配置" "混淆已启用: $obfs_type"
        else
            echo "混淆配置: 未启用"
            add_diagnostic_result "INFO" "混淆配置" "混淆未启用 (可选)"
        fi
        
        # 伪装配置
        if grep -q "^masquerade:" "$CONFIG_PATH"; then
            local masq_url=$(grep -A 5 "^masquerade:" "$CONFIG_PATH" | grep "url:" | awk '{print $2}')
            echo "伪装网站: ${masq_url:-已配置}"
            add_diagnostic_result "SUCCESS" "伪装配置" "伪装网站已配置"
        else
            echo "伪装网站: 未配置"
            add_diagnostic_result "WARNING" "伪装配置" "未配置伪装网站" false
        fi
        
    else
        echo -e "${RED}✗ 配置文件不存在${NC}"
        echo "预期路径: $CONFIG_PATH"
        add_diagnostic_result "CRITICAL" "配置文件" "配置文件不存在" true
        return 1
    fi
    
    echo ""
}

# 检查证书文件（优化版本）
check_certificates
