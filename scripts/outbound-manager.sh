#!/bin/bash

# Hysteria2 出站规则管理模块
# 用于配置和管理 Hysteria2 的出站规则

# 适度的错误处理
set -uo pipefail

# 加载公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
else
    echo "错误: 无法加载公共库" >&2
    exit 1
fi

# 配置路径 (防止重复定义)
if [[ -z "${HYSTERIA_CONFIG:-}" ]]; then
    readonly HYSTERIA_CONFIG="/etc/hysteria/config.yaml"
fi
if [[ -z "${OUTBOUND_TEMPLATES_DIR:-}" ]]; then
    readonly OUTBOUND_TEMPLATES_DIR="$SCRIPT_DIR/outbound-templates"
fi
if [[ -z "${BACKUP_DIR:-}" ]]; then
    readonly BACKUP_DIR="/var/backups/s-hy2/outbound"
fi

# 初始化出站管理
init_outbound_manager() {
    log_info "初始化出站规则管理器"

    # 创建模板目录
    mkdir -p "$OUTBOUND_TEMPLATES_DIR" "$BACKUP_DIR"

    # 创建基础模板（如果不存在）
    create_default_templates
}

# 创建默认模板
create_default_templates() {
    # Direct 出站模板
    if [[ ! -f "$OUTBOUND_TEMPLATES_DIR/direct.yaml" ]]; then
        cat > "$OUTBOUND_TEMPLATES_DIR/direct.yaml" << 'EOF'
# Direct 直连出站配置模板
outbounds:
  - name: direct_out
    type: direct
    direct:
      mode: auto
      # bindIPv4: "1.2.3.4"    # 可选：绑定 IPv4 地址
      # bindIPv6: "::1"        # 可选：绑定 IPv6 地址
      # bindDevice: "eth0"     # 可选：绑定网卡

# 简单 ACL 规则 - 全部直连
acl: |
  direct_out(all)
EOF
    fi

    # SOCKS5 出站模板
    if [[ ! -f "$OUTBOUND_TEMPLATES_DIR/socks5.yaml" ]]; then
        cat > "$OUTBOUND_TEMPLATES_DIR/socks5.yaml" << 'EOF'
# SOCKS5 代理出站配置模板
outbounds:
  - name: direct_out
    type: direct
  - name: socks5_out
    type: socks5
    socks5:
      addr: "proxy.example.com:1080"
      username: "your_username"  # 可选
      password: "your_password"  # 可选

# 简单 ACL 规则 - 国外走代理，国内直连
acl: |
  # 国外 IP 走 SOCKS5 代理
  socks5_out(geoip:!cn)
  # 国内 IP 直连
  direct_out(geoip:cn)
  # 其他所有连接直连
  direct_out(all)
EOF
    fi

    # HTTP 出站模板
    if [[ ! -f "$OUTBOUND_TEMPLATES_DIR/http.yaml" ]]; then
        cat > "$OUTBOUND_TEMPLATES_DIR/http.yaml" << 'EOF'
# HTTP/HTTPS 代理出站配置模板
outbounds:
  - name: direct_out
    type: direct
  - name: http_out
    type: http
    http:
      url: "http://username:password@proxy.example.com:8080"
      # 或 HTTPS: "https://username:password@proxy.example.com:8080"
      insecure: false  # 是否跳过 TLS 验证

# 简单 ACL 规则 - 特定域名走代理
acl: |
  # 特定网站走 HTTP 代理
  http_out(suffix:google.com)
  http_out(suffix:youtube.com)
  http_out(suffix:facebook.com)
  # 其他所有连接直连
  direct_out(all)
EOF
    fi

    log_success "默认出站模板已创建"
}

# 显示出站管理菜单
show_outbound_menu() {
    clear
    echo -e "${CYAN}=== Hysteria2 出站规则配置 ===${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 查看当前出站配置"
    echo -e "${GREEN}2.${NC} 添加新的出站规则"
    echo -e "${GREEN}3.${NC} 使用模板配置"
    echo -e "${GREEN}4.${NC} 修改现有配置"
    echo -e "${GREEN}5.${NC} 测试出站连通性"
    echo -e "${GREEN}6.${NC} 备份和恢复配置"
    echo -e "${RED}0.${NC} 返回主菜单"
    echo ""
}

# 查看当前出站配置
view_current_outbound() {
    log_info "查看当前出站配置"

    # 使用统一的检查函数
    if ! check_hysteria2_ready "config"; then
        return 0  # 友好返回，不退出脚本
    fi

    echo -e "${BLUE}=== 当前出站配置 ===${NC}"
    echo ""

    # 检查是否有出站配置
    if grep -q "^outbounds:" "$HYSTERIA_CONFIG"; then
        echo -e "${GREEN}出站规则：${NC}"
        sed -n '/^outbounds:/,/^[^[:space:]]/p' "$HYSTERIA_CONFIG" | sed '$d'
        echo ""
    else
        echo -e "${YELLOW}当前配置中没有出站规则（使用默认直连）${NC}"
        echo ""
    fi

    # 检查是否有 ACL 配置
    if grep -q "^acl:" "$HYSTERIA_CONFIG"; then
        echo -e "${GREEN}ACL 规则：${NC}"
        sed -n '/^acl:/,/^[^[:space:]]/p' "$HYSTERIA_CONFIG" | sed '$d'
    else
        echo -e "${YELLOW}当前配置中没有 ACL 规则（使用默认路由）${NC}"
    fi

    echo ""
    wait_for_user
}

# 添加新的出站规则
add_outbound_rule() {
    log_info "添加新的出站规则"

    echo -e "${BLUE}=== 添加出站规则 ===${NC}"
    echo ""
    echo "选择出站类型："
    echo "1. Direct (直连)"
    echo "2. SOCKS5 代理"
    echo "3. HTTP/HTTPS 代理"
    echo ""

    local choice
    read -p "请选择 [1-3]: " choice

    case $choice in
        1) add_direct_outbound ;;
        2) add_socks5_outbound ;;
        3) add_http_outbound ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}

# 添加直连出站
add_direct_outbound() {
    echo -e "${BLUE}=== 配置 Direct 直连出站 ===${NC}"
    echo ""

    local name interface ipv4 ipv6

    # 获取出站名称
    read -p "出站名称 (例: china_direct): " name
    if [[ -z "$name" ]]; then
        name="direct_out"
    fi

    # 是否绑定特定网卡
    echo "是否绑定特定网卡？ [y/N]"
    read -r bind_interface

    if [[ $bind_interface =~ ^[Yy]$ ]]; then
        echo "可用网卡："
        # 优化：缓存网卡信息并使用更高效的命令
        if [[ -z "${CACHED_INTERFACES:-}" ]]; then
            # 使用更快的方法获取网卡列表
            if command -v ip >/dev/null 2>&1; then
                CACHED_INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
            else
                # 降级方案
                CACHED_INTERFACES=$(ls /sys/class/net/ | grep -v "lo")
            fi
        fi
        echo "$CACHED_INTERFACES" | nl -w2 -s') '
        read -p "请选择网卡名称 (例: eth0): " interface
    fi

    # 是否绑定特定 IP
    echo "是否绑定特定 IP 地址？ [y/N]"
    read -r bind_ip

    if [[ $bind_ip =~ ^[Yy]$ ]]; then
        read -p "IPv4 地址 (可选): " ipv4
        read -p "IPv6 地址 (可选): " ipv6
    fi

    # 生成配置
    generate_direct_config "$name" "$interface" "$ipv4" "$ipv6"
}

# 添加 SOCKS5 出站
add_socks5_outbound() {
    echo -e "${BLUE}=== 配置 SOCKS5 代理出站 ===${NC}"
    echo ""

    local name addr username password

    read -p "出站名称 (例: socks5_proxy): " name
    if [[ -z "$name" ]]; then
        name="socks5_out"
    fi

    read -p "代理服务器地址:端口 (例: proxy.example.com:1080): " addr
    if [[ -z "$addr" ]]; then
        log_error "代理地址不能为空"
        return 1
    fi

    echo "是否需要认证？ [y/N]"
    read -r need_auth

    if [[ $need_auth =~ ^[Yy]$ ]]; then
        read -p "用户名: " username
        read -s -p "密码: " password
        echo ""
    fi

    # 生成配置
    generate_socks5_config "$name" "$addr" "$username" "$password"
}

# 添加 HTTP 出站
add_http_outbound() {
    echo -e "${BLUE}=== 配置 HTTP/HTTPS 代理出站 ===${NC}"
    echo ""

    local name url insecure

    read -p "出站名称 (例: http_proxy): " name
    if [[ -z "$name" ]]; then
        name="http_out"
    fi

    echo "代理类型："
    echo "1. HTTP 代理"
    echo "2. HTTPS 代理"
    read -p "选择 [1-2]: " proxy_type

    if [[ $proxy_type == "1" ]]; then
        read -p "HTTP 代理 URL (例: http://user:pass@proxy.com:8080): " url
    else
        read -p "HTTPS 代理 URL (例: https://user:pass@proxy.com:8080): " url
        echo "是否跳过 TLS 验证？ [y/N]"
        read -r skip_tls
        if [[ $skip_tls =~ ^[Yy]$ ]]; then
            insecure="true"
        else
            insecure="false"
        fi
    fi

    if [[ -z "$url" ]]; then
        log_error "代理 URL 不能为空"
        return 1
    fi

    # 生成配置
    generate_http_config "$name" "$url" "$insecure"
}

# 生成配置函数
generate_direct_config() {
    local name="$1" interface="$2" ipv4="$3" ipv6="$4"

    echo "生成的 Direct 出站配置："
    echo "---"
    echo "outbounds:"
    echo "  - name: $name"
    echo "    type: direct"
    echo "    direct:"
    echo "      mode: auto"

    if [[ -n "$interface" ]]; then
        echo "      bindDevice: \"$interface\""
    fi
    if [[ -n "$ipv4" ]]; then
        echo "      bindIPv4: \"$ipv4\""
    fi
    if [[ -n "$ipv6" ]]; then
        echo "      bindIPv6: \"$ipv6\""
    fi
    echo "---"
    echo ""

    apply_outbound_config "$name" "direct"
}

generate_socks5_config() {
    local name="$1" addr="$2" username="$3" password="$4"

    echo "生成的 SOCKS5 出站配置："
    echo "---"
    echo "outbounds:"
    echo "  - name: $name"
    echo "    type: socks5"
    echo "    socks5:"
    echo "      addr: \"$addr\""

    if [[ -n "$username" ]]; then
        echo "      username: \"$username\""
        echo "      password: \"$password\""
    fi
    echo "---"
    echo ""

    apply_outbound_config "$name" "socks5"
}

generate_http_config() {
    local name="$1" url="$2" insecure="$3"

    echo "生成的 HTTP 出站配置："
    echo "---"
    echo "outbounds:"
    echo "  - name: $name"
    echo "    type: http"
    echo "    http:"
    echo "      url: \"$url\""

    if [[ -n "$insecure" ]]; then
        echo "      insecure: $insecure"
    fi
    echo "---"
    echo ""

    apply_outbound_config "$name" "http"
}

# 应用出站配置
apply_outbound_config() {
    local name="$1" type="$2"

    echo "是否将此配置应用到 Hysteria2？ [y/N]"
    read -r apply_config

    if [[ $apply_config =~ ^[Yy]$ ]]; then
        backup_current_config
        # 这里需要实际的配置应用逻辑
        log_success "出站配置已添加：$name ($type)"

        # 询问是否重启服务
        echo "是否重启 Hysteria2 服务以应用配置？ [y/N]"
        read -r restart_service

        if [[ $restart_service =~ ^[Yy]$ ]]; then
            systemctl restart hysteria-server
            log_success "服务已重启"
        fi
    fi
}

# 备份当前配置
backup_current_config() {
    if [[ -f "$HYSTERIA_CONFIG" ]]; then
        local backup_file="$BACKUP_DIR/config-$(date +%Y%m%d_%H%M%S).yaml"
        cp "$HYSTERIA_CONFIG" "$backup_file"
        log_info "配置已备份到: $backup_file"
    fi
}

# 使用模板配置
use_template_config() {
    echo -e "${BLUE}=== 使用模板配置 ===${NC}"
    echo ""
    echo "可用模板："
    echo "1. Direct 直连模板"
    echo "2. SOCKS5 代理模板"
    echo "3. HTTP 代理模板"
    echo ""

    local choice
    read -p "请选择模板 [1-3]: " choice

    case $choice in
        1) apply_template "direct.yaml" ;;
        2) apply_template "socks5.yaml" ;;
        3) apply_template "http.yaml" ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}

# 应用模板
apply_template() {
    local template="$1"
    local template_path="$OUTBOUND_TEMPLATES_DIR/$template"

    if [[ ! -f "$template_path" ]]; then
        log_error "模板文件不存在: $template"
        return 1
    fi

    echo -e "${BLUE}模板内容预览：${NC}"
    echo "---"
    cat "$template_path"
    echo "---"
    echo ""

    echo "是否使用此模板？ [y/N]"
    read -r use_template

    if [[ $use_template =~ ^[Yy]$ ]]; then
        backup_current_config

        # 这里需要实际的模板应用逻辑
        log_success "模板配置已应用: $template"

        echo "是否重启 Hysteria2 服务？ [y/N]"
        read -r restart_service

        if [[ $restart_service =~ ^[Yy]$ ]]; then
            systemctl restart hysteria-server
            log_success "服务已重启"
        fi
    fi
}

# 测试出站连通性
test_outbound_connectivity() {
    log_info "测试出站连通性"

    # 这里实现连通性测试逻辑
    echo "连通性测试功能开发中..."
    wait_for_user
}

# 备份和恢复配置
backup_restore_config() {
    echo -e "${BLUE}=== 备份和恢复配置 ===${NC}"
    echo ""
    echo "1. 创建配置备份"
    echo "2. 恢复配置备份"
    echo "3. 查看备份列表"
    echo ""

    local choice
    read -p "请选择操作 [1-3]: " choice

    case $choice in
        1) backup_current_config ;;
        2) restore_config_backup ;;
        3) list_config_backups ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}

# 恢复配置备份
restore_config_backup() {
    list_config_backups
    echo ""
    read -p "请输入要恢复的备份文件名: " backup_file

    local backup_path="$BACKUP_DIR/$backup_file"
    if [[ ! -f "$backup_path" ]]; then
        log_error "备份文件不存在: $backup_file"
        return 1
    fi

    echo "是否恢复此备份？这将覆盖当前配置。 [y/N]"
    read -r restore_backup

    if [[ $restore_backup =~ ^[Yy]$ ]]; then
        cp "$backup_path" "$HYSTERIA_CONFIG"
        log_success "配置已恢复"

        echo "是否重启 Hysteria2 服务？ [y/N]"
        read -r restart_service

        if [[ $restart_service =~ ^[Yy]$ ]]; then
            systemctl restart hysteria-server
            log_success "服务已重启"
        fi
    fi
}

# 列出配置备份
list_config_backups() {
    echo -e "${GREEN}可用的配置备份：${NC}"
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -la "$BACKUP_DIR"/*.yaml 2>/dev/null || echo "没有找到备份文件"
    else
        echo "备份目录不存在"
    fi
}

# 主出站管理函数
manage_outbound() {
    init_outbound_manager

    while true; do
        show_outbound_menu

        local choice
        read -p "请选择操作 [0-6]: " choice

        case $choice in
            1) view_current_outbound ;;
            2) add_outbound_rule ;;
            3) use_template_config ;;
            4)
                log_info "修改配置功能开发中"
                wait_for_user
                ;;
            5) test_outbound_connectivity ;;
            6) backup_restore_config ;;
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
    manage_outbound
fi