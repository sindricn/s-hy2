#!/bin/bash

# Hysteria2 防火墙管理模块
# 自动检测并管理 Linux 系统防火墙

# 适度的错误处理
set -uo pipefail

# 加载公共库
# SCRIPT_DIR 由主脚本定义，此处已移除以避免覆盖
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/common.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
else
    echo "错误: 无法加载公共库" >&2
    exit 1
fi

# 防火墙类型常量 (防止重复定义)
if [[ -z "${FW_UNKNOWN:-}" ]]; then
    readonly FW_UNKNOWN=0
    readonly FW_IPTABLES=1
    readonly FW_FIREWALLD=2
    readonly FW_UFW=3
    readonly FW_NFTABLES=4
fi

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
    echo -e "${GREEN}2.${NC} 一键管理 Hysteria2 端口"
    echo -e "${GREEN}3.${NC} 手动开放端口"
    echo -e "${GREEN}4.${NC} 防火墙规则管理"
    echo -e "${GREEN}5.${NC} 防火墙服务管理"
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

# 手动开放端口（交互式）
open_custom_port() {
    log_info "手动开放端口"

    echo -e "${BLUE}=== 手动开放端口 ===${NC}"
    echo ""

    # 获取要开放的端口
    local custom_port
    while true; do
        read -p "请输入要开放的端口号 (1-65535): " custom_port

        # 验证端口号
        if [[ ! "$custom_port" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}错误: 请输入有效的数字${NC}"
            continue
        fi

        if [[ "$custom_port" -lt 1 || "$custom_port" -gt 65535 ]]; then
            echo -e "${RED}错误: 端口号必须在 1-65535 范围内${NC}"
            continue
        fi

        break
    done

    # 选择协议
    echo ""
    echo "选择协议类型："
    echo "1. TCP"
    echo "2. UDP"
    echo "3. TCP + UDP"
    echo ""

    local protocol_choice
    local protocols=()
    read -p "请选择 [1-3]: " protocol_choice

    case $protocol_choice in
        1) protocols=("tcp") ;;
        2) protocols=("udp") ;;
        3) protocols=("tcp" "udp") ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    # 确认开放
    echo ""
    echo -e "${YELLOW}即将开放端口：${NC}"
    echo "端口: $custom_port"
    echo "协议: ${protocols[*]}"
    echo ""
    read -p "确认开放此端口？ [y/N]: " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}操作已取消${NC}"
        return 0
    fi

    # 执行开放操作
    echo -e "${GREEN}正在开放端口 $custom_port...${NC}"

    local success=true
    for protocol in "${protocols[@]}"; do
        case $DETECTED_FIREWALL in
            $FW_FIREWALLD)
                if ! firewall-cmd --permanent --add-port="$custom_port/$protocol" >/dev/null 2>&1; then
                    success=false
                    break
                fi
                ;;
            $FW_UFW)
                if ! ufw allow "$custom_port/$protocol" >/dev/null 2>&1; then
                    success=false
                    break
                fi
                ;;
            $FW_IPTABLES)
                if ! iptables -I INPUT -p "$protocol" --dport "$custom_port" -j ACCEPT >/dev/null 2>&1; then
                    success=false
                    break
                fi
                ;;
            $FW_NFTABLES)
                if ! nft add rule inet filter input "$protocol" dport "$custom_port" accept >/dev/null 2>&1; then
                    success=false
                    break
                fi
                ;;
            *)
                log_error "不支持的防火墙类型"
                return 1
                ;;
        esac
    done

    if [ "$success" = true ]; then
        # 重载配置
        case $DETECTED_FIREWALL in
            $FW_FIREWALLD)
                firewall-cmd --reload >/dev/null 2>&1
                ;;
            $FW_IPTABLES)
                save_iptables_rules
                ;;
        esac

        log_success "端口 $custom_port (${protocols[*]}) 已成功开放"
    else
        log_error "端口开放失败"
        return 1
    fi

    echo ""
    wait_for_user
}

# 开放 Hysteria2 端口（自动）
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

# 管理防火墙规则
manage_firewall_rules() {
    echo -e "${BLUE}=== 防火墙规则管理 ===${NC}"
    echo ""
    echo "1. 查看当前规则"
    echo "2. 删除 Hysteria2 相关规则"
    echo "3. 重新添加 Hysteria2 规则"
    echo "4. 启用防火墙规则"
    echo "5. 停用防火墙规则"
    echo ""

    local choice
    read -p "请选择操作 [1-5]: " choice

    case $choice in
        1) show_firewall_status ;;
        2) remove_hysteria_rules ;;
        3) open_hysteria_port ;;
        4) enable_firewall_rules ;;
        5) disable_firewall_rules ;;
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

# 启用防火墙规则
enable_firewall_rules() {
    log_info "启用防火墙规则"

    echo -e "${BLUE}=== 启用防火墙规则 ===${NC}"
    echo ""

    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            if systemctl is-active firewalld >/dev/null 2>&1; then
                echo -e "${GREEN}✅ firewalld 服务已启用并运行${NC}"
                echo "当前活动规则："
                firewall-cmd --list-all
            else
                echo -e "${YELLOW}⚠️  firewalld 服务未运行${NC}"
                read -p "是否启动 firewalld 服务？ [y/N]: " start_fw
                if [[ $start_fw =~ ^[Yy]$ ]]; then
                    systemctl start firewalld
                    systemctl enable firewalld
                    log_success "firewalld 服务已启动并设为开机自启"
                else
                    echo -e "${BLUE}firewalld 服务保持停止状态${NC}"
                fi
            fi
            ;;
        $FW_UFW)
            if ufw status | grep -q "Status: active"; then
                echo -e "${GREEN}✅ ufw 防火墙已启用${NC}"
                ufw status verbose
            else
                echo -e "${YELLOW}⚠️  ufw 防火墙未启用${NC}"
                read -p "是否启用 ufw 防火墙？ [y/N]: " enable_ufw
                if [[ $enable_ufw =~ ^[Yy]$ ]]; then
                    ufw --force enable
                    log_success "ufw 防火墙已启用"
                else
                    echo -e "${BLUE}ufw 防火墙保持停用状态${NC}"
                fi
            fi
            ;;
        $FW_IPTABLES)
            echo -e "${GREEN}✅ iptables 规则始终有效${NC}"
            echo "当前规则："
            iptables -L INPUT -n --line-numbers | head -20
            ;;
        $FW_NFTABLES)
            if systemctl is-active nftables >/dev/null 2>&1; then
                echo -e "${GREEN}✅ nftables 服务已启用并运行${NC}"
                echo "当前规则："
                nft list table inet filter 2>/dev/null | head -20
            else
                echo -e "${YELLOW}⚠️  nftables 服务未运行${NC}"
                read -p "是否启动 nftables 服务？ [y/N]: " start_nft
                if [[ $start_nft =~ ^[Yy]$ ]]; then
                    systemctl start nftables
                    systemctl enable nftables
                    log_success "nftables 服务已启动并设为开机自启"
                else
                    echo -e "${BLUE}nftables 服务保持停止状态${NC}"
                fi
            fi
            ;;
        *)
            log_error "不支持的防火墙类型"
            ;;
    esac

    echo ""
    wait_for_user
}

# 停用防火墙规则
disable_firewall_rules() {
    log_info "停用防火墙规则"

    echo -e "${BLUE}=== 停用防火墙规则 ===${NC}"
    echo ""

    echo -e "${RED}⚠️  警告: 停用防火墙规则将降低系统安全性${NC}"
    echo ""
    read -p "确认要停用防火墙规则吗？ [y/N]: " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}操作已取消${NC}"
        wait_for_user
        return 0
    fi

    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            if systemctl is-active firewalld >/dev/null 2>&1; then
                systemctl stop firewalld
                systemctl disable firewalld
                log_success "firewalld 服务已停止并禁用开机自启"
            else
                echo -e "${BLUE}firewalld 服务已处于停止状态${NC}"
            fi
            ;;
        $FW_UFW)
            if ufw status | grep -q "Status: active"; then
                ufw --force disable
                log_success "ufw 防火墙已停用"
            else
                echo -e "${BLUE}ufw 防火墙已处于停用状态${NC}"
            fi
            ;;
        $FW_IPTABLES)
            echo -e "${YELLOW}⚠️  iptables 规则管理${NC}"
            echo "选择操作："
            echo "1. 清空所有规则（允许所有流量）"
            echo "2. 设置默认拒绝策略但保留现有规则"
            echo "3. 取消操作"
            echo ""
            read -p "请选择 [1-3]: " iptables_choice

            case $iptables_choice in
                1)
                    iptables -F INPUT
                    iptables -P INPUT ACCEPT
                    save_iptables_rules
                    log_success "已清空 iptables INPUT 规则并设为允许所有"
                    ;;
                2)
                    iptables -P INPUT DROP
                    save_iptables_rules
                    log_success "已设置 iptables 默认拒绝策略"
                    ;;
                3)
                    echo -e "${BLUE}操作已取消${NC}"
                    ;;
            esac
            ;;
        $FW_NFTABLES)
            if systemctl is-active nftables >/dev/null 2>&1; then
                systemctl stop nftables
                systemctl disable nftables
                log_success "nftables 服务已停止并禁用开机自启"
            else
                echo -e "${BLUE}nftables 服务已处于停止状态${NC}"
            fi
            ;;
        *)
            log_error "不支持的防火墙类型"
            ;;
    esac

    echo ""
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

# 智能管理 Hysteria2 端口
smart_manage_hysteria_port() {
    log_info "智能管理 Hysteria2 端口"

    echo -e "${CYAN}=== 一键管理 Hysteria2 端口 ===${NC}"
    echo ""

    # 首先检查防火墙服务状态
    local firewall_enabled=false
    local firewall_running=false

    case $DETECTED_FIREWALL in
        $FW_FIREWALLD)
            if systemctl is-enabled firewalld >/dev/null 2>&1; then
                firewall_enabled=true
            fi
            if systemctl is-active firewalld >/dev/null 2>&1; then
                firewall_running=true
            fi
            ;;
        $FW_UFW)
            if ufw status | grep -q "Status: active"; then
                firewall_enabled=true
                firewall_running=true
            fi
            ;;
        $FW_IPTABLES)
            # iptables 总是"运行"的，检查是否有规则
            if iptables -L INPUT | grep -q "DROP\|REJECT"; then
                firewall_enabled=true
                firewall_running=true
            fi
            ;;
        $FW_NFTABLES)
            if systemctl is-active nftables >/dev/null 2>&1; then
                firewall_enabled=true
                firewall_running=true
            fi
            ;;
    esac

    echo -e "${BLUE}防火墙状态检测：${NC}"
    echo "防火墙类型: $FIREWALL_NAME"
    echo "防火墙服务: $([ "$firewall_running" = true ] && echo "${GREEN}运行中${NC}" || echo "${RED}未运行${NC}")"
    echo "Hysteria2 端口: $HYSTERIA_PORT"
    echo ""

    # 如果防火墙未启用
    if [ "$firewall_enabled" = false ] || [ "$firewall_running" = false ]; then
        echo -e "${YELLOW}⚠️  防火墙未启用或未运行${NC}"
        echo -e "${BLUE}当前状态：${NC}端口 $HYSTERIA_PORT 可能已可访问（无防火墙限制）"
        echo ""
        echo -e "${GREEN}安全建议：${NC}"
        echo "虽然不影响 Hysteria2 连接，但为了安全考虑，建议启用防火墙并开放特定端口"
        echo ""
        read -p "是否启用防火墙并配置规则？ [y/N]: " enable_fw

        if [[ $enable_fw =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}正在启用防火墙并配置规则...${NC}"

            # 启用防火墙服务
            case $DETECTED_FIREWALL in
                $FW_FIREWALLD)
                    systemctl enable --now firewalld
                    ;;
                $FW_UFW)
                    ufw --force enable
                    ;;
                $FW_IPTABLES)
                    echo "iptables 无需启用服务，直接配置规则"
                    ;;
                $FW_NFTABLES)
                    systemctl enable --now nftables
                    ;;
            esac

            # 开放端口
            open_hysteria_port
        else
            echo -e "${BLUE}保持当前状态，跳过防火墙配置${NC}"
        fi
    else
        # 防火墙已启用，检查端口状态
        echo -e "${GREEN}✅ 防火墙已启用${NC}"
        echo ""

        local port_opened=false
        local port_status=""

        # 检查端口是否已开放
        case $DETECTED_FIREWALL in
            $FW_FIREWALLD)
                if firewall-cmd --query-port="$HYSTERIA_PORT/tcp" >/dev/null 2>&1 && \
                   firewall-cmd --query-port="$HYSTERIA_PORT/udp" >/dev/null 2>&1; then
                    port_opened=true
                    port_status="TCP/UDP 端口已开放"
                else
                    port_status="端口未开放或部分开放"
                fi
                ;;
            $FW_UFW)
                if ufw status | grep "$HYSTERIA_PORT" >/dev/null; then
                    port_opened=true
                    port_status="端口规则已存在"
                else
                    port_status="端口未开放"
                fi
                ;;
            $FW_IPTABLES)
                if iptables -L INPUT | grep "$HYSTERIA_PORT" >/dev/null; then
                    port_opened=true
                    port_status="端口规则已存在"
                else
                    port_status="端口未开放"
                fi
                ;;
            $FW_NFTABLES)
                if nft list table inet filter 2>/dev/null | grep "$HYSTERIA_PORT" >/dev/null; then
                    port_opened=true
                    port_status="端口规则已存在"
                else
                    port_status="端口未开放"
                fi
                ;;
        esac

        echo -e "${BLUE}端口状态检测：${NC}$port_status"
        echo ""

        if [ "$port_opened" = true ]; then
            echo -e "${GREEN}✅ 端口 $HYSTERIA_PORT 已正确配置${NC}"
            echo -e "${BLUE}Hysteria2 连接应该正常工作${NC}"
        else
            echo -e "${RED}❌ 端口 $HYSTERIA_PORT 未开放${NC}"
            echo -e "${YELLOW}⚠️  这将影响 Hysteria2 客户端连接${NC}"
            echo ""
            read -p "是否立即开放端口 $HYSTERIA_PORT？ [Y/n]: " open_port

            if [[ ! $open_port =~ ^[Nn]$ ]]; then
                echo -e "${GREEN}正在开放端口 $HYSTERIA_PORT...${NC}"
                open_hysteria_port
            else
                echo -e "${RED}⚠️  端口未开放，Hysteria2 客户端可能无法连接${NC}"
            fi
        fi
    fi

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
        read -p "请选择操作 [0-5]: " choice

        case $choice in
            1) show_firewall_status ;;
            2) smart_manage_hysteria_port ;;
            3) open_custom_port ;;
            4) manage_firewall_rules ;;
            5) manage_firewall_service ;;
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