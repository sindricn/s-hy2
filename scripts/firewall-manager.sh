#!/bin/bash

# Hysteria2 防火墙管理模块
# 自动检测并管理 Linux 系统防火墙

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

# 防火墙类型常量
readonly FW_UNKNOWN=0
readonly FW_IPTABLES=1
readonly FW_FIREWALLD=2
readonly FW_UFW=3
readonly FW_NFTABLES=4

# 全局变量
DETECTED_FIREWALL=$FW_UNKNOWN
FIREWALL_NAME=""
HYSTERIA_PORT=""

# 检测系统防火墙类型（性能优化版本）
detect_firewall() {
    log_info "检测系统防火墙类型"

    # 使用缓存避免重复检测
    local cache_key="firewall_detection"
    if [[ -n "${FIREWALL_DETECTION_CACHE:-}" ]]; then
        DETECTED_FIREWALL="$FIREWALL_DETECTION_CACHE"
        FIREWALL_NAME="$FIREWALL_NAME_CACHE"
        log_info "使用缓存的防火墙检测结果: $FIREWALL_NAME"
        return 0
    fi

    # 检测优先级：firewalld > ufw > iptables > nftables
    # 批量检查命令存在性
    local commands_exist=""
    for cmd in systemctl ufw iptables nft; do
        if command -v "$cmd" >/dev/null 2>&1; then
            commands_exist="$commands_exist $cmd"
        fi
    done

    # 检测 firewalld（优化：一次性检查状态和配置）
    if [[ "$commands_exist" == *"systemctl"* ]]; then
        local firewalld_status
        firewalld_status=$(systemctl is-active firewalld 2>/dev/null || echo "inactive")

        if [[ "$firewalld_status" == "active" ]]; then
            DETECTED_FIREWALL=$FW_FIREWALLD
            FIREWALL_NAME="firewalld"
            log_success "检测到防火墙: firewalld (运行中)"
            # 缓存结果
            FIREWALL_DETECTION_CACHE=$FW_FIREWALLD
            FIREWALL_NAME_CACHE="firewalld"
            return 0
        elif systemctl is-enabled --quiet firewalld 2>/dev/null; then
            DETECTED_FIREWALL=$FW_FIREWALLD
            FIREWALL_NAME="firewalld"
            log_warn "检测到防火墙: firewalld (已安装但未运行)"
            # 缓存结果
            FIREWALL_DETECTION_CACHE=$FW_FIREWALLD
            FIREWALL_NAME_CACHE="firewalld"
            return 0
        fi
    fi

    # 检测 ufw（优化：减少命令调用）
    if [[ "$commands_exist" == *"ufw"* ]]; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1 || echo "Status: inactive")

        if [[ "$ufw_status" =~ "Status: active" ]]; then
            DETECTED_FIREWALL=$FW_UFW
            FIREWALL_NAME="ufw"
            log_success "检测到防火墙: ufw (激活状态)"
        else
            DETECTED_FIREWALL=$FW_UFW
            FIREWALL_NAME="ufw"
            log_warn "检测到防火墙: ufw (已安装但未激活)"
        fi
        # 缓存结果
        FIREWALL_DETECTION_CACHE=$FW_UFW
        FIREWALL_NAME_CACHE="ufw"
        return 0
    fi

    # 检测 iptables（优化：快速规则计数）
    if [[ "$commands_exist" == *"iptables"* ]]; then
        # 优化：使用更快的规则计数方法
        local rule_count
        rule_count=$(iptables -L -n --line-numbers 2>/dev/null | grep -c "^[0-9]" || echo "0")

        if [[ $rule_count -gt 3 ]]; then  # 调整阈值，更准确
            DETECTED_FIREWALL=$FW_IPTABLES
            FIREWALL_NAME="iptables"
            log_success "检测到防火墙: iptables (有自定义规则: $rule_count 条)"
        else
            DETECTED_FIREWALL=$FW_IPTABLES
            FIREWALL_NAME="iptables"
            log_warn "检测到防火墙: iptables (默认配置)"
            return 0
        fi
    fi

    # 检测 nftables
    if command -v nft >/dev/null 2>&1; then
        local nft_rules
        nft_rules=$(nft list tables 2>/dev/null | wc -l)
        if [[ $nft_rules -gt 0 ]]; then
            DETECTED_FIREWALL=$FW_NFTABLES
            FIREWALL_NAME="nftables"
            log_success "检测到防火墙: nftables (有配置表)"
            return 0
        else
            DETECTED_FIREWALL=$FW_NFTABLES
            FIREWALL_NAME="nftables"
            log_warn "检测到防火墙: nftables (无配置表)"
            return 0
        fi
    fi

    # 未检测到防火墙
    DETECTED_FIREWALL=$FW_UNKNOWN
    FIREWALL_NAME="unknown"
    log_warn "未检测到已知的防火墙系统"
    return 1
}

# 获取 Hysteria2 端口
get_hysteria_port() {
    if [[ -f "/etc/hysteria/config.yaml" ]]; then
        # 从配置文件提取端口
        HYSTERIA_PORT=$(grep -E "^\s*listen:" /etc/hysteria/config.yaml | awk -F':' '{print $NF}' | tr -d ' ' | head -1)

        # 如果没有找到端口，使用默认值
        if [[ -z "$HYSTERIA_PORT" ]]; then
            HYSTERIA_PORT="443"
        fi
    else
        HYSTERIA_PORT="443"
    fi

    log_info "Hysteria2 端口: $HYSTERIA_PORT"
}

# 显示防火墙管理菜单
show_firewall_menu() {
    clear
    echo -e "${CYAN}=== Hysteria2 防火墙管理 ===${NC}"
    echo ""
    echo -e "${BLUE}当前防火墙: ${GREEN}$FIREWALL_NAME${NC}"
    echo -e "${BLUE}Hysteria2 端口: ${GREEN}$HYSTERIA_PORT${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 查看防火墙状态"
    echo -e "${GREEN}2.${NC} 开放 Hysteria2 端口"
    echo -e "${GREEN}3.${NC} 检查端口连通性"
    echo -e "${GREEN}4.${NC} 管理防火墙规则"
    echo -e "${GREEN}5.${NC} 防火墙服务管理"
    echo -e "${GREEN}6.${NC} 端口扫描和诊断"
    echo -e "${RED}0.${NC} 返回主菜单"
    echo ""
}

# 查看防火墙状态
show_firewall_status() {
    log_info "查看防火墙状态"

    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            show_firewalld_status
            ;;
        $FW_UFW)
            show_ufw_status
            ;;
        $FW_IPTABLES)
            show_iptables_status
            ;;
        $FW_NFTABLES)
            show_nftables_status
            ;;
        *)
            log_error "未知的防火墙类型"
            ;;
    esac

    echo ""
    wait_for_user
}

# firewalld 状态
show_firewalld_status() {
    echo -e "${BLUE}=== firewalld 状态 ===${NC}"
    echo ""

    # 服务状态
    echo -e "${GREEN}服务状态:${NC}"
    systemctl status firewalld --no-pager -l || true
    echo ""

    # 活动区域
    echo -e "${GREEN}活动区域:${NC}"
    firewall-cmd --get-active-zones 2>/dev/null || echo "无活动区域"
    echo ""

    # 默认区域
    echo -e "${GREEN}默认区域:${NC}"
    firewall-cmd --get-default-zone 2>/dev/null || echo "未设置"
    echo ""

    # 开放的端口
    echo -e "${GREEN}开放的端口:${NC}"
    firewall-cmd --list-ports 2>/dev/null || echo "无开放端口"
    echo ""

    # 检查 Hysteria2 端口
    if firewall-cmd --query-port="$HYSTERIA_PORT/tcp" 2>/dev/null; then
        echo -e "${GREEN}✅ Hysteria2 端口 $HYSTERIA_PORT/tcp 已开放${NC}"
    else
        echo -e "${RED}❌ Hysteria2 端口 $HYSTERIA_PORT/tcp 未开放${NC}"
    fi

    if firewall-cmd --query-port="$HYSTERIA_PORT/udp" 2>/dev/null; then
        echo -e "${GREEN}✅ Hysteria2 端口 $HYSTERIA_PORT/udp 已开放${NC}"
    else
        echo -e "${RED}❌ Hysteria2 端口 $HYSTERIA_PORT/udp 未开放${NC}"
    fi
}

# ufw 状态
show_ufw_status() {
    echo -e "${BLUE}=== ufw 状态 ===${NC}"
    echo ""

    # 详细状态
    echo -e "${GREEN}详细状态:${NC}"
    ufw status verbose 2>/dev/null || echo "ufw 未激活或出错"
    echo ""

    # 检查 Hysteria2 端口
    local ufw_rules
    ufw_rules=$(ufw status numbered 2>/dev/null | grep "$HYSTERIA_PORT" || echo "")

    if [[ -n "$ufw_rules" ]]; then
        echo -e "${GREEN}✅ 找到 Hysteria2 端口相关规则:${NC}"
        echo "$ufw_rules"
    else
        echo -e "${RED}❌ 未找到 Hysteria2 端口 $HYSTERIA_PORT 的规则${NC}"
    fi
}

# iptables 状态
show_iptables_status() {
    echo -e "${BLUE}=== iptables 状态 ===${NC}"
    echo ""

    # INPUT 链规则
    echo -e "${GREEN}INPUT 链规则:${NC}"
    iptables -L INPUT -n --line-numbers 2>/dev/null || echo "无法获取 INPUT 规则"
    echo ""

    # 检查 Hysteria2 端口
    local tcp_rule udp_rule
    tcp_rule=$(iptables -L INPUT -n | grep "dpt:$HYSTERIA_PORT" | grep tcp || echo "")
    udp_rule=$(iptables -L INPUT -n | grep "dpt:$HYSTERIA_PORT" | grep udp || echo "")

    if [[ -n "$tcp_rule" ]]; then
        echo -e "${GREEN}✅ 找到 TCP 端口 $HYSTERIA_PORT 规则:${NC}"
        echo "$tcp_rule"
    else
        echo -e "${RED}❌ 未找到 TCP 端口 $HYSTERIA_PORT 规则${NC}"
    fi

    if [[ -n "$udp_rule" ]]; then
        echo -e "${GREEN}✅ 找到 UDP 端口 $HYSTERIA_PORT 规则:${NC}"
        echo "$udp_rule"
    else
        echo -e "${RED}❌ 未找到 UDP 端口 $HYSTERIA_PORT 规则${NC}"
    fi
}

# nftables 状态
show_nftables_status() {
    echo -e "${BLUE}=== nftables 状态 ===${NC}"
    echo ""

    # 列出所有表
    echo -e "${GREEN}nftables 表:${NC}"
    nft list tables 2>/dev/null || echo "无 nftables 表"
    echo ""

    # 列出规则集
    echo -e "${GREEN}规则集:${NC}"
    nft list ruleset 2>/dev/null | head -20 || echo "无法获取规则集"

    # 简单检查端口
    local port_rules
    port_rules=$(nft list ruleset 2>/dev/null | grep "$HYSTERIA_PORT" || echo "")

    if [[ -n "$port_rules" ]]; then
        echo -e "${GREEN}✅ 找到端口 $HYSTERIA_PORT 相关规则${NC}"
    else
        echo -e "${RED}❌ 未找到端口 $HYSTERIA_PORT 相关规则${NC}"
    fi
}

# 开放 Hysteria2 端口
open_hysteria_port() {
    log_info "开放 Hysteria2 端口: $HYSTERIA_PORT"

    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            open_port_firewalld
            ;;
        $FW_UFW)
            open_port_ufw
            ;;
        $FW_IPTABLES)
            open_port_iptables
            ;;
        $FW_NFTABLES)
            open_port_nftables
            ;;
        *)
            log_error "不支持的防火墙类型"
            return 1
            ;;
    esac
}

# firewalld 开放端口
open_port_firewalld() {
    echo -e "${BLUE}=== 使用 firewalld 开放端口 ===${NC}"
    echo ""

    # 检查服务状态
    if ! systemctl is-active --quiet firewalld; then
        echo "firewalld 未运行，是否启动？ [y/N]"
        read -r start_firewalld
        if [[ $start_firewalld =~ ^[Yy]$ ]]; then
            systemctl start firewalld
            log_success "firewalld 已启动"
        else
            log_error "需要启动 firewalld 才能配置规则"
            return 1
        fi
    fi

    # 开放 TCP 端口
    if firewall-cmd --add-port="$HYSTERIA_PORT/tcp" --permanent; then
        log_success "TCP 端口 $HYSTERIA_PORT 已添加到永久规则"
    else
        log_error "添加 TCP 端口规则失败"
    fi

    # 开放 UDP 端口
    if firewall-cmd --add-port="$HYSTERIA_PORT/udp" --permanent; then
        log_success "UDP 端口 $HYSTERIA_PORT 已添加到永久规则"
    else
        log_error "添加 UDP 端口规则失败"
    fi

    # 重新加载规则
    if firewall-cmd --reload; then
        log_success "防火墙规则已重新加载"
    else
        log_error "重新加载防火墙规则失败"
    fi

    # 验证端口
    verify_port_opened
}

# ufw 开放端口
open_port_ufw() {
    echo -e "${BLUE}=== 使用 ufw 开放端口 ===${NC}"
    echo ""

    # 检查 ufw 状态
    local ufw_status
    ufw_status=$(ufw status | head -1)

    if [[ "$ufw_status" =~ "inactive" ]]; then
        echo "ufw 未激活，是否激活？ [y/N]"
        read -r enable_ufw
        if [[ $enable_ufw =~ ^[Yy]$ ]]; then
            ufw --force enable
            log_success "ufw 已激活"
        else
            log_warn "ufw 未激活，将直接添加规则"
        fi
    fi

    # 添加端口规则
    if ufw allow "$HYSTERIA_PORT/tcp"; then
        log_success "TCP 端口 $HYSTERIA_PORT 规则已添加"
    else
        log_error "添加 TCP 端口规则失败"
    fi

    if ufw allow "$HYSTERIA_PORT/udp"; then
        log_success "UDP 端口 $HYSTERIA_PORT 规则已添加"
    else
        log_error "添加 UDP 端口规则失败"
    fi

    # 验证端口
    verify_port_opened
}

# iptables 开放端口
open_port_iptables() {
    echo -e "${BLUE}=== 使用 iptables 开放端口 ===${NC}"
    echo ""

    # 添加 TCP 规则
    if iptables -I INPUT -p tcp --dport "$HYSTERIA_PORT" -j ACCEPT; then
        log_success "TCP 端口 $HYSTERIA_PORT 规则已添加"
    else
        log_error "添加 TCP 端口规则失败"
    fi

    # 添加 UDP 规则
    if iptables -I INPUT -p udp --dport "$HYSTERIA_PORT" -j ACCEPT; then
        log_success "UDP 端口 $HYSTERIA_PORT 规则已添加"
    else
        log_error "添加 UDP 端口规则失败"
    fi

    # 保存规则
    echo "是否保存 iptables 规则？ [y/N]"
    read -r save_rules

    if [[ $save_rules =~ ^[Yy]$ ]]; then
        save_iptables_rules
    else
        log_warn "规则未保存，重启后将丢失"
    fi

    # 验证端口
    verify_port_opened
}

# 保存 iptables 规则
save_iptables_rules() {
    # 不同发行版的保存方法
    if command -v iptables-save >/dev/null && command -v netfilter-persistent >/dev/null; then
        # Debian/Ubuntu with netfilter-persistent
        netfilter-persistent save
        log_success "规则已通过 netfilter-persistent 保存"
    elif command -v iptables-save >/dev/null && [[ -f /etc/sysconfig/iptables ]]; then
        # CentOS/RHEL
        iptables-save > /etc/sysconfig/iptables
        log_success "规则已保存到 /etc/sysconfig/iptables"
    elif command -v iptables-save >/dev/null; then
        # 通用方法
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
        iptables-save > /etc/iptables.rules 2>/dev/null || \
        log_warn "无法确定 iptables 规则保存位置"
    else
        log_error "无法保存 iptables 规则"
    fi
}

# nftables 开放端口
open_port_nftables() {
    echo -e "${BLUE}=== 使用 nftables 开放端口 ===${NC}"
    echo ""
    log_warn "nftables 配置较为复杂，建议手动配置"

    echo "nftables 基本规则示例："
    echo "nft add rule inet filter input tcp dport $HYSTERIA_PORT accept"
    echo "nft add rule inet filter input udp dport $HYSTERIA_PORT accept"
    echo ""

    echo "是否自动添加基本规则？ [y/N]"
    read -r auto_add

    if [[ $auto_add =~ ^[Yy]$ ]]; then
        # 创建基本表和链（如果不存在）
        nft add table inet filter 2>/dev/null || true
        nft add chain inet filter input { type filter hook input priority 0 \; } 2>/dev/null || true

        # 添加规则
        if nft add rule inet filter input tcp dport "$HYSTERIA_PORT" accept; then
            log_success "TCP 端口 $HYSTERIA_PORT 规则已添加"
        fi

        if nft add rule inet filter input udp dport "$HYSTERIA_PORT" accept; then
            log_success "UDP 端口 $HYSTERIA_PORT 规则已添加"
        fi
    fi

    wait_for_user
}

# 验证端口是否开放
verify_port_opened() {
    echo ""
    log_info "验证端口开放状态"

    # 检查端口监听状态
    if ss -tulpn | grep ":$HYSTERIA_PORT " >/dev/null; then
        log_success "端口 $HYSTERIA_PORT 正在监听"
    else
        log_warn "端口 $HYSTERIA_PORT 未在监听（Hysteria2 可能未运行）"
    fi

    # 防火墙规则验证
    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            if firewall-cmd --query-port="$HYSTERIA_PORT/tcp" >/dev/null 2>&1 && \
               firewall-cmd --query-port="$HYSTERIA_PORT/udp" >/dev/null 2>&1; then
                log_success "防火墙规则验证通过"
            else
                log_error "防火墙规则验证失败"
            fi
            ;;
        $FW_UFW)
            if ufw status | grep "$HYSTERIA_PORT" >/dev/null; then
                log_success "防火墙规则验证通过"
            else
                log_error "防火墙规则验证失败"
            fi
            ;;
        *)
            log_info "请手动验证防火墙规则"
            ;;
    esac
}

# 检查端口连通性
check_port_connectivity() {
    log_info "检查端口连通性"

    echo -e "${BLUE}=== 端口连通性检查 ===${NC}"
    echo ""

    # 内部检查：端口监听状态
    echo -e "${GREEN}1. 内部端口监听检查:${NC}"
    if ss -tulpn | grep ":$HYSTERIA_PORT "; then
        log_success "端口 $HYSTERIA_PORT 正在监听"
    else
        log_error "端口 $HYSTERIA_PORT 未在监听"
        echo "可能原因："
        echo "- Hysteria2 服务未运行"
        echo "- 配置文件中端口设置错误"
        echo "- 服务启动失败"
        echo ""
    fi

    # 防火墙规则检查
    echo -e "${GREEN}2. 防火墙规则检查:${NC}"
    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            if firewall-cmd --query-port="$HYSTERIA_PORT/tcp" >/dev/null 2>&1; then
                echo "✅ TCP 端口规则存在"
            else
                echo "❌ TCP 端口规则不存在"
            fi

            if firewall-cmd --query-port="$HYSTERIA_PORT/udp" >/dev/null 2>&1; then
                echo "✅ UDP 端口规则存在"
            else
                echo "❌ UDP 端口规则不存在"
            fi
            ;;
        $FW_UFW)
            if ufw status | grep "$HYSTERIA_PORT" >/dev/null; then
                echo "✅ 端口规则存在"
            else
                echo "❌ 端口规则不存在"
            fi
            ;;
        *)
            echo "⚠️  请手动检查防火墙规则"
            ;;
    esac
    echo ""

    # 外部连通性测试
    echo -e "${GREEN}3. 外部连通性测试:${NC}"
    echo "将尝试从外部测试端口连通性..."

    # 获取服务器外部 IP
    local external_ip
    external_ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "未知")

    if [[ "$external_ip" != "未知" ]]; then
        echo "服务器外部 IP: $external_ip"
        echo "您可以使用以下命令从其他机器测试连通性："
        echo "telnet $external_ip $HYSTERIA_PORT"
        echo "nc -zv $external_ip $HYSTERIA_PORT"
        echo ""
    fi

    # 云服务商安全组提醒
    echo -e "${YELLOW}注意事项:${NC}"
    echo "- 如果使用云服务器，请检查安全组/防火墙设置"
    echo "- 确保云平台防火墙允许端口 $HYSTERIA_PORT"
    echo "- 某些云服务商默认阻止所有入站连接"
    echo ""

    wait_for_user
}

# 管理防火墙规则
manage_firewall_rules() {
    echo -e "${BLUE}=== 防火墙规则管理 ===${NC}"
    echo ""
    echo "1. 查看当前规则"
    echo "2. 删除 Hysteria2 相关规则"
    echo "3. 重新添加 Hysteria2 规则"
    echo "4. 备份当前规则"
    echo ""

    local choice
    read -p "请选择操作 [1-4]: " choice

    case $choice in
        1) show_firewall_status ;;
        2) remove_hysteria_rules ;;
        3) open_hysteria_port ;;
        4) backup_firewall_rules ;;
        *)
            log_error "无效选择"
            wait_for_user
            ;;
    esac
}

# 删除 Hysteria2 相关规则
remove_hysteria_rules() {
    echo -e "${YELLOW}警告: 将删除端口 $HYSTERIA_PORT 的防火墙规则${NC}"
    echo "确认删除？ [y/N]"
    read -r confirm_remove

    if [[ ! $confirm_remove =~ ^[Yy]$ ]]; then
        log_info "取消删除操作"
        return 0
    fi

    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            firewall-cmd --remove-port="$HYSTERIA_PORT/tcp" --permanent 2>/dev/null || true
            firewall-cmd --remove-port="$HYSTERIA_PORT/udp" --permanent 2>/dev/null || true
            firewall-cmd --reload
            log_success "firewalld 规则已删除"
            ;;
        $FW_UFW)
            ufw delete allow "$HYSTERIA_PORT/tcp" 2>/dev/null || true
            ufw delete allow "$HYSTERIA_PORT/udp" 2>/dev/null || true
            log_success "ufw 规则已删除"
            ;;
        $FW_IPTABLES)
            iptables -D INPUT -p tcp --dport "$HYSTERIA_PORT" -j ACCEPT 2>/dev/null || true
            iptables -D INPUT -p udp --dport "$HYSTERIA_PORT" -j ACCEPT 2>/dev/null || true
            log_success "iptables 规则已删除"
            ;;
        *)
            log_error "不支持的防火墙类型"
            ;;
    esac

    wait_for_user
}

# 备份防火墙规则
backup_firewall_rules() {
    local backup_dir="/var/backups/s-hy2/firewall"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    mkdir -p "$backup_dir"

    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            firewall-cmd --list-all > "$backup_dir/firewalld_$timestamp.conf"
            log_success "firewalld 规则已备份到: $backup_dir/firewalld_$timestamp.conf"
            ;;
        $FW_UFW)
            ufw status verbose > "$backup_dir/ufw_$timestamp.conf"
            log_success "ufw 规则已备份到: $backup_dir/ufw_$timestamp.conf"
            ;;
        $FW_IPTABLES)
            iptables-save > "$backup_dir/iptables_$timestamp.rules"
            log_success "iptables 规则已备份到: $backup_dir/iptables_$timestamp.rules"
            ;;
        $FW_NFTABLES)
            nft list ruleset > "$backup_dir/nftables_$timestamp.conf"
            log_success "nftables 规则已备份到: $backup_dir/nftables_$timestamp.conf"
            ;;
        *)
            log_error "无法备份未知类型的防火墙"
            ;;
    esac

    wait_for_user
}

# 防火墙服务管理
manage_firewall_service() {
    echo -e "${BLUE}=== 防火墙服务管理 ===${NC}"
    echo ""
    echo "1. 启动防火墙服务"
    echo "2. 停止防火墙服务"
    echo "3. 重启防火墙服务"
    echo "4. 查看服务状态"
    echo "5. 启用开机自启"
    echo "6. 禁用开机自启"
    echo ""

    local choice
    read -p "请选择操作 [1-6]: " choice

    local service_name
    case $DETECTED_FIREWALL in
        $FW_FIREWALLD) service_name="firewalld" ;;
        $FW_UFW) service_name="ufw" ;;
        *)
            log_error "当前防火墙不支持 systemctl 管理"
            wait_for_user
            return 1
            ;;
    esac

    case $choice in
        1)
            systemctl start "$service_name"
            log_success "$service_name 服务已启动"
            ;;
        2)
            systemctl stop "$service_name"
            log_success "$service_name 服务已停止"
            ;;
        3)
            systemctl restart "$service_name"
            log_success "$service_name 服务已重启"
            ;;
        4)
            systemctl status "$service_name" --no-pager -l
            ;;
        5)
            systemctl enable "$service_name"
            log_success "$service_name 开机自启已启用"
            ;;
        6)
            systemctl disable "$service_name"
            log_success "$service_name 开机自启已禁用"
            ;;
        *)
            log_error "无效选择"
            ;;
    esac

    wait_for_user
}

# 端口扫描和诊断
port_scan_diagnostic() {
    echo -e "${BLUE}=== 端口扫描和诊断 ===${NC}"
    echo ""

    # 本地端口扫描
    echo -e "${GREEN}1. 本地端口状态:${NC}"
    ss -tulpn | grep -E "(LISTEN|:$HYSTERIA_PORT)" | head -10
    echo ""

    # 进程检查
    echo -e "${GREEN}2. Hysteria2 进程状态:${NC}"
    if pgrep -f hysteria >/dev/null; then
        ps aux | grep -E "(hysteria|hy2)" | grep -v grep
        log_success "Hysteria2 进程运行中"
    else
        log_warn "未找到 Hysteria2 进程"
    fi
    echo ""

    # 系统资源检查
    echo -e "${GREEN}3. 系统资源状态:${NC}"
    echo "CPU 使用率:"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'
    echo "内存使用率:"
    free -h | awk 'NR==2{printf "%.1f%%\n", $3*100/$2}'
    echo "磁盘使用率:"
    df -h / | awk 'NR==2{print $5}'
    echo ""

    # 网络连接检查
    echo -e "${GREEN}4. 网络连接状态:${NC}"
    netstat -i | head -5 2>/dev/null || ip link show | head -5
    echo ""

    wait_for_user
}

# 部署后验证检查
post_deploy_check() {
    log_info "执行部署后验证检查"

    echo -e "${CYAN}=== Hysteria2 部署后检查 ===${NC}"
    echo ""

    local check_passed=0
    local total_checks=5

    # 检查 1: 服务状态
    echo -e "${BLUE}检查 1/5: Hysteria2 服务状态${NC}"
    if systemctl is-active --quiet hysteria-server; then
        echo "✅ Hysteria2 服务运行正常"
        ((check_passed++))
    else
        echo "❌ Hysteria2 服务未运行"
    fi
    echo ""

    # 检查 2: 端口监听
    echo -e "${BLUE}检查 2/5: 端口监听状态${NC}"
    if ss -tulpn | grep ":$HYSTERIA_PORT " >/dev/null; then
        echo "✅ 端口 $HYSTERIA_PORT 正在监听"
        ((check_passed++))
    else
        echo "❌ 端口 $HYSTERIA_PORT 未在监听"
    fi
    echo ""

    # 检查 3: 防火墙规则
    echo -e "${BLUE}检查 3/5: 防火墙规则${NC}"
    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            if firewall-cmd --query-port="$HYSTERIA_PORT/tcp" >/dev/null 2>&1 && \
               firewall-cmd --query-port="$HYSTERIA_PORT/udp" >/dev/null 2>&1; then
                echo "✅ 防火墙规则配置正确"
                ((check_passed++))
            else
                echo "❌ 防火墙规则配置错误"
            fi
            ;;
        $FW_UFW)
            if ufw status | grep "$HYSTERIA_PORT" >/dev/null; then
                echo "✅ 防火墙规则配置正确"
                ((check_passed++))
            else
                echo "❌ 防火墙规则配置错误"
            fi
            ;;
        *)
            echo "⚠️  无法自动检查防火墙规则"
            ((check_passed++))  # 给予通过
            ;;
    esac
    echo ""

    # 检查 4: 配置文件
    echo -e "${BLUE}检查 4/5: 配置文件${NC}"
    if [[ -f "/etc/hysteria/config.yaml" ]]; then
        echo "✅ 配置文件存在"
        ((check_passed++))
    else
        echo "❌ 配置文件不存在"
    fi
    echo ""

    # 检查 5: 证书文件
    echo -e "${BLUE}检查 5/5: 证书文件${NC}"
    if [[ -f "/etc/hysteria/cert.crt" ]] || grep -q "acme:" /etc/hysteria/config.yaml 2>/dev/null; then
        echo "✅ 证书配置正常"
        ((check_passed++))
    else
        echo "❌ 证书配置可能有问题"
    fi
    echo ""

    # 总结
    echo -e "${CYAN}=== 检查结果总结 ===${NC}"
    echo "通过检查: $check_passed/$total_checks"

    if [[ $check_passed -eq $total_checks ]]; then
        echo -e "${GREEN}🎉 所有检查通过！Hysteria2 部署成功${NC}"
    elif [[ $check_passed -ge 3 ]]; then
        echo -e "${YELLOW}⚠️  部分检查未通过，但基本功能可用${NC}"
    else
        echo -e "${RED}❌ 多项检查失败，需要修复问题${NC}"
    fi

    echo ""
    wait_for_user
}

# 主防火墙管理函数
manage_firewall() {
    # 初始化
    detect_firewall
    get_hysteria_port

    if [[ $DETECTED_FIREWALL -eq $FW_UNKNOWN ]]; then
        log_error "未检测到支持的防火墙系统"
        echo "支持的防火墙: firewalld, ufw, iptables, nftables"
        wait_for_user
        return 1
    fi

    while true; do
        show_firewall_menu

        local choice
        read -p "请选择操作 [0-6]: " choice

        case $choice in
            1) show_firewall_status ;;
            2) open_hysteria_port ;;
            3) check_port_connectivity ;;
            4) manage_firewall_rules ;;
            5) manage_firewall_service ;;
            6) port_scan_diagnostic ;;
            0)
                log_info "返回主菜单"
                break
                ;;
            *)
                log_error "无效选择，请重新输入"
                wait_for_user
                ;;
        esac
    done
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    manage_firewall
fi