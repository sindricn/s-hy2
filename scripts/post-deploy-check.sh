#!/bin/bash

# Hysteria2 部署后检查模块
# 确保节点部署完成后各项功能正常

# 严格错误处理
set -euo pipefail

# 加载公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
else
    echo "错误: 无法加载公共库" >&2
    exit 1
fi

# 加载防火墙管理模块
if [[ -f "$SCRIPT_DIR/firewall-manager.sh" ]]; then
    source "$SCRIPT_DIR/firewall-manager.sh"
fi

# 配置路径
readonly HYSTERIA_CONFIG="/etc/hysteria/config.yaml"
readonly HYSTERIA_SERVICE="hysteria-server"
readonly CHECK_TIMEOUT=10

# 全面部署检查
comprehensive_deploy_check() {
    log_info "开始全面部署检查"

    echo -e "${CYAN}=== Hysteria2 全面部署检查 ===${NC}"
    echo ""

    local total_checks=8
    local passed_checks=0
    local failed_checks=()

    # 检查 1: 二进制文件
    echo -e "${BLUE}[1/$total_checks] 检查 Hysteria2 二进制文件${NC}"
    if check_hysteria_binary; then
        echo "✅ Hysteria2 二进制文件正常"
        ((passed_checks++))
    else
        echo "❌ Hysteria2 二进制文件异常"
        failed_checks+=("二进制文件")
    fi
    echo ""

    # 检查 2: 配置文件
    echo -e "${BLUE}[2/$total_checks] 检查配置文件${NC}"
    if check_config_file; then
        echo "✅ 配置文件正常"
        ((passed_checks++))
    else
        echo "❌ 配置文件异常"
        failed_checks+=("配置文件")
    fi
    echo ""

    # 检查 3: 证书配置
    echo -e "${BLUE}[3/$total_checks] 检查证书配置${NC}"
    if check_certificate_config; then
        echo "✅ 证书配置正常"
        ((passed_checks++))
    else
        echo "❌ 证书配置异常"
        failed_checks+=("证书配置")
    fi
    echo ""

    # 检查 4: 系统服务
    echo -e "${BLUE}[4/$total_checks] 检查系统服务${NC}"
    if check_system_service; then
        echo "✅ 系统服务正常"
        ((passed_checks++))
    else
        echo "❌ 系统服务异常"
        failed_checks+=("系统服务")
    fi
    echo ""

    # 检查 5: 端口监听
    echo -e "${BLUE}[5/$total_checks] 检查端口监听${NC}"
    if check_port_listening; then
        echo "✅ 端口监听正常"
        ((passed_checks++))
    else
        echo "❌ 端口监听异常"
        failed_checks+=("端口监听")
    fi
    echo ""

    # 检查 6: 防火墙规则
    echo -e "${BLUE}[6/$total_checks] 检查防火墙规则${NC}"
    if check_firewall_rules; then
        echo "✅ 防火墙规则正常"
        ((passed_checks++))
    else
        echo "❌ 防火墙规则异常"
        failed_checks+=("防火墙规则")
    fi
    echo ""

    # 检查 7: 网络连通性
    echo -e "${BLUE}[7/$total_checks] 检查网络连通性${NC}"
    if check_network_connectivity; then
        echo "✅ 网络连通性正常"
        ((passed_checks++))
    else
        echo "❌ 网络连通性异常"
        failed_checks+=("网络连通性")
    fi
    echo ""

    # 检查 8: 性能状态
    echo -e "${BLUE}[8/$total_checks] 检查性能状态${NC}"
    if check_performance_status; then
        echo "✅ 性能状态正常"
        ((passed_checks++))
    else
        echo "❌ 性能状态异常"
        failed_checks+=("性能状态")
    fi
    echo ""

    # 生成检查报告
    generate_check_report "$passed_checks" "$total_checks" "${failed_checks[@]}"

    return $((total_checks - passed_checks))
}

# 检查 Hysteria2 二进制文件
check_hysteria_binary() {
    # 检查命令是否存在
    if ! command -v hysteria >/dev/null 2>&1; then
        echo "  ❌ hysteria 命令不存在"
        return 1
    fi

    # 检查版本信息
    local version
    version=$(hysteria version 2>/dev/null | head -1 || echo "")
    if [[ -n "$version" ]]; then
        echo "  📦 版本: $version"
    else
        echo "  ⚠️  无法获取版本信息"
    fi

    # 检查可执行权限
    local hysteria_path
    hysteria_path=$(which hysteria)
    if [[ -x "$hysteria_path" ]]; then
        echo "  ✅ 可执行权限正常"
    else
        echo "  ❌ 可执行权限异常"
        return 1
    fi

    return 0
}

# 检查配置文件
check_config_file() {
    # 检查文件是否存在
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        echo "  ❌ 配置文件不存在: $HYSTERIA_CONFIG"
        return 1
    fi

    # 检查文件权限
    if [[ ! -r "$HYSTERIA_CONFIG" ]]; then
        echo "  ❌ 配置文件不可读"
        return 1
    fi

    # 检查配置语法
    if hysteria config check "$HYSTERIA_CONFIG" >/dev/null 2>&1; then
        echo "  ✅ 配置语法正确"
    else
        echo "  ❌ 配置语法错误"
        hysteria config check "$HYSTERIA_CONFIG" 2>&1 | head -3 | sed 's/^/    /'
        return 1
    fi

    # 检查关键配置项
    check_config_items

    return 0
}

# 检查配置关键项
check_config_items() {
    local config_file="$HYSTERIA_CONFIG"

    # 检查监听地址
    if grep -q "^listen:" "$config_file"; then
        local listen_addr
        listen_addr=$(grep "^listen:" "$config_file" | awk '{print $2}' | tr -d '"')
        echo "  📡 监听地址: $listen_addr"
    else
        echo "  ⚠️  未找到监听地址配置"
    fi

    # 检查认证配置
    if grep -q "^auth:" "$config_file"; then
        echo "  🔐 认证配置: 已配置"
    else
        echo "  ⚠️  未找到认证配置"
    fi

    # 检查 TLS/证书配置
    if grep -q "^tls:" "$config_file" || grep -q "^acme:" "$config_file"; then
        echo "  🔒 TLS配置: 已配置"
    else
        echo "  ⚠️  未找到 TLS 配置"
    fi

    # 检查混淆配置
    if grep -q "obfs:" "$config_file"; then
        echo "  🎭 混淆配置: 已配置"
    else
        echo "  ℹ️  未配置混淆（可选）"
    fi
}

# 检查证书配置
check_certificate_config() {
    local config_file="$HYSTERIA_CONFIG"

    # 检查 TLS 配置类型
    if grep -q "^acme:" "$config_file"; then
        echo "  🔒 使用 ACME 自动证书"
        return check_acme_certificate
    elif grep -q "^tls:" "$config_file"; then
        echo "  🔒 使用自定义证书"
        return check_custom_certificate
    else
        echo "  ❌ 未找到 TLS 配置"
        return 1
    fi
}

# 检查 ACME 证书
check_acme_certificate() {
    local domains
    domains=$(grep -A 10 "^acme:" "$HYSTERIA_CONFIG" | grep -E "^\s*-\s" | awk '{print $2}' | tr -d '"')

    if [[ -n "$domains" ]]; then
        echo "  📋 ACME 域名:"
        echo "$domains" | sed 's/^/    - /'

        # 检查证书目录
        local acme_dir
        acme_dir=$(grep -A 20 "^acme:" "$HYSTERIA_CONFIG" | grep "dir:" | awk '{print $2}' | tr -d '"' || echo "/etc/hysteria/acme")

        if [[ -d "$acme_dir" ]]; then
            local cert_count
            cert_count=$(find "$acme_dir" -name "*.crt" 2>/dev/null | wc -l)
            echo "  📁 证书目录: $acme_dir ($cert_count 个证书文件)"
        else
            echo "  ⚠️  证书目录不存在: $acme_dir"
        fi
    else
        echo "  ❌ 未找到 ACME 域名配置"
        return 1
    fi

    return 0
}

# 检查自定义证书
check_custom_certificate() {
    local cert_file key_file

    cert_file=$(grep -A 5 "^tls:" "$HYSTERIA_CONFIG" | grep "cert:" | awk '{print $2}' | tr -d '"')
    key_file=$(grep -A 5 "^tls:" "$HYSTERIA_CONFIG" | grep "key:" | awk '{print $2}' | tr -d '"')

    if [[ -n "$cert_file" ]] && [[ -n "$key_file" ]]; then
        echo "  📄 证书文件: $cert_file"
        echo "  🔑 私钥文件: $key_file"

        # 检查文件是否存在
        if [[ -f "$cert_file" ]] && [[ -f "$key_file" ]]; then
            echo "  ✅ 证书文件存在"

            # 检查证书有效性
            if openssl x509 -in "$cert_file" -text -noout >/dev/null 2>&1; then
                echo "  ✅ 证书格式正确"

                # 检查证书过期时间
                local expiry_date
                expiry_date=$(openssl x509 -in "$cert_file" -enddate -noout | cut -d= -f2)
                echo "  📅 证书过期时间: $expiry_date"
            else
                echo "  ❌ 证书格式错误"
                return 1
            fi
        else
            echo "  ❌ 证书文件不存在"
            return 1
        fi
    else
        echo "  ❌ 未找到证书文件配置"
        return 1
    fi

    return 0
}

# 检查系统服务
check_system_service() {
    # 检查服务是否存在
    if ! systemctl list-unit-files | grep -q "$HYSTERIA_SERVICE"; then
        echo "  ❌ 系统服务不存在: $HYSTERIA_SERVICE"
        return 1
    fi

    # 检查服务状态
    if systemctl is-active --quiet "$HYSTERIA_SERVICE"; then
        echo "  ✅ 服务运行中"
    else
        echo "  ❌ 服务未运行"
        echo "  📄 服务状态:"
        systemctl status "$HYSTERIA_SERVICE" --no-pager -l | head -5 | sed 's/^/    /'
        return 1
    fi

    # 检查开机自启
    if systemctl is-enabled --quiet "$HYSTERIA_SERVICE"; then
        echo "  ✅ 开机自启已启用"
    else
        echo "  ⚠️  开机自启未启用"
    fi

    # 检查服务启动时间
    local start_time
    start_time=$(systemctl show "$HYSTERIA_SERVICE" --property=ActiveEnterTimestamp --value 2>/dev/null || echo "未知")
    echo "  ⏰ 启动时间: $start_time"

    return 0
}

# 检查端口监听
check_port_listening() {
    local hysteria_port
    hysteria_port=$(grep -E "^\s*listen:" "$HYSTERIA_CONFIG" | awk -F':' '{print $NF}' | tr -d ' ' | head -1)

    if [[ -z "$hysteria_port" ]]; then
        hysteria_port="443"  # 默认端口
    fi

    echo "  🔌 检查端口: $hysteria_port"

    # 检查端口监听状态
    if ss -tulpn | grep ":$hysteria_port " >/dev/null; then
        echo "  ✅ 端口正在监听"

        # 显示监听详情
        local listen_info
        listen_info=$(ss -tulpn | grep ":$hysteria_port " | head -1)
        echo "  📊 监听详情: $listen_info"
    else
        echo "  ❌ 端口未监听"
        echo "  💡 可能原因:"
        echo "    - 服务未启动"
        echo "    - 端口配置错误"
        echo "    - 端口被其他程序占用"
        return 1
    fi

    # 检查端口占用情况
    local port_process
    port_process=$(ss -tulpn | grep ":$hysteria_port " | grep -o 'pid=[0-9]*' | cut -d= -f2 | head -1)

    if [[ -n "$port_process" ]]; then
        local process_info
        process_info=$(ps -p "$port_process" -o comm= 2>/dev/null || echo "未知进程")
        echo "  🔍 占用进程: $process_info (PID: $port_process)"
    fi

    return 0
}

# 检查防火墙规则
check_firewall_rules() {
    # 获取端口
    local hysteria_port
    hysteria_port=$(grep -E "^\s*listen:" "$HYSTERIA_CONFIG" | awk -F':' '{print $NF}' | tr -d ' ' | head -1)
    hysteria_port=${hysteria_port:-443}

    echo "  🔥 检查防火墙端口: $hysteria_port"

    # 检测防火墙类型
    local fw_type=""
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        fw_type="firewalld"
    elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        fw_type="ufw"
    elif command -v iptables >/dev/null 2>&1; then
        fw_type="iptables"
    elif command -v nft >/dev/null 2>&1; then
        fw_type="nftables"
    fi

    if [[ -z "$fw_type" ]]; then
        echo "  ⚠️  未检测到活动的防火墙"
        return 0  # 没有防火墙不算错误
    fi

    echo "  🛡️  防火墙类型: $fw_type"

    # 根据防火墙类型检查规则
    case "$fw_type" in
        "firewalld")
            if firewall-cmd --query-port="$hysteria_port/tcp" >/dev/null 2>&1 && \
               firewall-cmd --query-port="$hysteria_port/udp" >/dev/null 2>&1; then
                echo "  ✅ 防火墙规则正确"
                return 0
            else
                echo "  ❌ 防火墙规则缺失"
                return 1
            fi
            ;;
        "ufw")
            if ufw status | grep "$hysteria_port" >/dev/null; then
                echo "  ✅ 防火墙规则正确"
                return 0
            else
                echo "  ❌ 防火墙规则缺失"
                return 1
            fi
            ;;
        "iptables")
            if iptables -L INPUT -n | grep "dpt:$hysteria_port" >/dev/null; then
                echo "  ✅ 防火墙规则正确"
                return 0
            else
                echo "  ❌ 防火墙规则缺失"
                return 1
            fi
            ;;
        *)
            echo "  ⚠️  无法自动检查此防火墙类型的规则"
            return 0  # 不确定的情况不算错误
            ;;
    esac
}

# 检查网络连通性
check_network_connectivity() {
    echo "  🌐 检查网络连通性"

    # 检查本地网络接口
    local active_interfaces
    active_interfaces=$(ip link show up | grep -E "^[0-9]+:" | grep -v "lo:" | wc -l)
    echo "  📡 活动网络接口: $active_interfaces 个"

    # 检查外部 IP
    local external_ip
    external_ip=$(timeout 5 curl -s ifconfig.me 2>/dev/null || echo "获取失败")
    echo "  🌍 外部 IP: $external_ip"

    # 检查 DNS 解析
    if timeout 5 nslookup google.com >/dev/null 2>&1; then
        echo "  ✅ DNS 解析正常"
    else
        echo "  ❌ DNS 解析异常"
        return 1
    fi

    # 检查外部连通性
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    local reachable=0

    for host in "${test_hosts[@]}"; do
        if timeout 3 ping -c 1 "$host" >/dev/null 2>&1; then
            ((reachable++))
        fi
    done

    if [[ $reachable -gt 0 ]]; then
        echo "  ✅ 外部连通性正常 ($reachable/3 个主机可达)"
    else
        echo "  ❌ 外部连通性异常"
        return 1
    fi

    return 0
}

# 检查性能状态
check_performance_status() {
    echo "  📊 检查系统性能"

    # CPU 使用率
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo "  💻 CPU 使用率: ${cpu_usage}%"

    # 内存使用率
    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    echo "  🧠 内存使用率: ${mem_usage}%"

    # 磁盘使用率
    local disk_usage
    disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    echo "  💾 磁盘使用率: ${disk_usage}%"

    # 系统负载
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    echo "  ⚖️  系统负载: $load_avg"

    # 检查是否有性能问题
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        echo "  ⚠️  CPU 使用率过高"
    fi

    if (( $(echo "$mem_usage > 90" | bc -l) )); then
        echo "  ⚠️  内存使用率过高"
    fi

    if (( disk_usage > 90 )); then
        echo "  ⚠️  磁盘使用率过高"
    fi

    # 检查 Hysteria2 进程资源使用
    local hysteria_pid
    hysteria_pid=$(pgrep -f hysteria | head -1)

    if [[ -n "$hysteria_pid" ]]; then
        local process_info
        process_info=$(ps -p "$hysteria_pid" -o %cpu,%mem,pid,comm --no-headers 2>/dev/null || echo "")
        if [[ -n "$process_info" ]]; then
            echo "  🔄 Hysteria2 进程: $process_info"
        fi
    else
        echo "  ❌ 未找到 Hysteria2 进程"
        return 1
    fi

    return 0
}

# 生成检查报告
generate_check_report() {
    local passed="$1"
    local total="$2"
    shift 2
    local failed=("$@")

    echo -e "${CYAN}=== 检查结果总结 ===${NC}"
    echo ""

    local success_rate=$((passed * 100 / total))

    echo "📊 检查统计:"
    echo "  • 总检查项: $total"
    echo "  • 通过检查: $passed"
    echo "  • 失败检查: $((total - passed))"
    echo "  • 成功率: $success_rate%"
    echo ""

    if [[ $success_rate -eq 100 ]]; then
        echo -e "${GREEN}🎉 恭喜！所有检查都通过了！${NC}"
        echo -e "${GREEN}Hysteria2 节点部署完全成功，可以正常使用。${NC}"
    elif [[ $success_rate -ge 75 ]]; then
        echo -e "${YELLOW}⚠️  大部分检查通过，但有一些小问题。${NC}"
        echo -e "${YELLOW}节点基本可用，建议修复以下问题：${NC}"
    else
        echo -e "${RED}❌ 检查失败较多，需要重点关注。${NC}"
        echo -e "${RED}节点可能无法正常工作，需要修复以下问题：${NC}"
    fi

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo ""
        echo "🔧 需要修复的问题:"
        for item in "${failed[@]}"; do
            echo "  • $item"
        done
    fi

    echo ""
    echo "💡 建议操作:"
    echo "  • 如有问题，请查看详细日志: journalctl -u hysteria-server -f"
    echo "  • 检查配置文件: $HYSTERIA_CONFIG"
    echo "  • 重启服务: systemctl restart hysteria-server"
    echo "  • 检查防火墙: 使用防火墙管理功能"

    # 保存检查报告
    save_check_report "$passed" "$total" "${failed[@]}"
}

# 保存检查报告
save_check_report() {
    local passed="$1"
    local total="$2"
    shift 2
    local failed=("$@")

    local report_dir="/var/log/s-hy2"
    local report_file="$report_dir/deploy-check-$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$report_dir"

    {
        echo "Hysteria2 部署检查报告"
        echo "=========================="
        echo "检查时间: $(date)"
        echo "通过检查: $passed/$total"
        echo "成功率: $((passed * 100 / total))%"
        echo ""

        if [[ ${#failed[@]} -gt 0 ]]; then
            echo "失败项目:"
            for item in "${failed[@]}"; do
                echo "- $item"
            done
        fi

        echo ""
        echo "系统信息:"
        echo "- 系统: $(uname -a)"
        echo "- 时间: $(date)"
        echo "- 用户: $(whoami)"
    } > "$report_file"

    log_info "检查报告已保存: $report_file"
}

# 快速健康检查
quick_health_check() {
    log_info "执行快速健康检查"

    echo -e "${CYAN}=== 快速健康检查 ===${NC}"
    echo ""

    # 服务状态
    if systemctl is-active --quiet "$HYSTERIA_SERVICE"; then
        echo "✅ 服务运行正常"
    else
        echo "❌ 服务未运行"
        return 1
    fi

    # 端口监听
    local port
    port=$(grep -E "^\s*listen:" "$HYSTERIA_CONFIG" | awk -F':' '{print $NF}' | tr -d ' ' | head -1)
    port=${port:-443}

    if ss -tulpn | grep ":$port " >/dev/null; then
        echo "✅ 端口 $port 监听正常"
    else
        echo "❌ 端口 $port 未监听"
        return 1
    fi

    # 配置文件
    if [[ -f "$HYSTERIA_CONFIG" ]] && hysteria config check "$HYSTERIA_CONFIG" >/dev/null 2>&1; then
        echo "✅ 配置文件正常"
    else
        echo "❌ 配置文件异常"
        return 1
    fi

    echo ""
    echo -e "${GREEN}✅ 快速检查通过，节点运行正常${NC}"
    return 0
}

# 修复常见问题
fix_common_issues() {
    log_info "尝试修复常见问题"

    echo -e "${BLUE}=== 自动修复常见问题 ===${NC}"
    echo ""

    local fixed_count=0

    # 修复 1: 重启服务
    echo "1. 检查并重启服务"
    if ! systemctl is-active --quiet "$HYSTERIA_SERVICE"; then
        if systemctl restart "$HYSTERIA_SERVICE"; then
            echo "  ✅ 服务已重启"
            ((fixed_count++))
        else
            echo "  ❌ 服务重启失败"
        fi
    else
        echo "  ✅ 服务运行正常"
    fi

    # 修复 2: 检查防火墙
    echo "2. 检查防火墙规则"
    local port
    port=$(grep -E "^\s*listen:" "$HYSTERIA_CONFIG" | awk -F':' '{print $NF}' | tr -d ' ' | head -1)
    port=${port:-443}

    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        if ! firewall-cmd --query-port="$port/tcp" >/dev/null 2>&1; then
            if firewall-cmd --add-port="$port/tcp" --permanent && firewall-cmd --reload; then
                echo "  ✅ 已开放 TCP 端口 $port"
                ((fixed_count++))
            fi
        fi
        if ! firewall-cmd --query-port="$port/udp" >/dev/null 2>&1; then
            if firewall-cmd --add-port="$port/udp" --permanent && firewall-cmd --reload; then
                echo "  ✅ 已开放 UDP 端口 $port"
                ((fixed_count++))
            fi
        fi
    fi

    # 修复 3: 权限检查
    echo "3. 检查文件权限"
    if [[ -f "$HYSTERIA_CONFIG" ]]; then
        if [[ ! -r "$HYSTERIA_CONFIG" ]]; then
            if chmod 644 "$HYSTERIA_CONFIG"; then
                echo "  ✅ 已修复配置文件权限"
                ((fixed_count++))
            fi
        else
            echo "  ✅ 配置文件权限正常"
        fi
    fi

    echo ""
    if [[ $fixed_count -gt 0 ]]; then
        echo -e "${GREEN}🔧 已修复 $fixed_count 个问题${NC}"
        echo "建议重新运行完整检查验证修复效果"
    else
        echo -e "${YELLOW}⚠️  没有发现可自动修复的问题${NC}"
    fi

    wait_for_user
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    comprehensive_deploy_check
fi