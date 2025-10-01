#!/bin/bash

# Hysteria2 安装脚本 (改进版本)
# 作为 s-hy2 管理脚本的一部分

# 适度的错误处理
set -uo pipefail

# 加载公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/scripts/common.sh" ]]; then
    source "$SCRIPT_DIR/scripts/common.sh"
elif [[ -f "$(dirname "$0")/scripts/common.sh" ]]; then
    source "$(dirname "$0")/scripts/common.sh"
else
    echo "错误: 无法找到公共库 common.sh" >&2
    exit 1
fi

# 加载安全模块
if [[ -f "$SCRIPT_DIR/scripts/input-validation.sh" ]]; then
    source "$SCRIPT_DIR/scripts/input-validation.sh"
fi

if [[ -f "$SCRIPT_DIR/scripts/secure-download.sh" ]]; then
    source "$SCRIPT_DIR/scripts/secure-download.sh"
fi

# 获取系统信息
get_system_info() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${ID:-unknown} ${VERSION_ID:-unknown}"
    else
        echo "unknown unknown"
    fi
}

# 检查系统兼容性
check_system_compatibility() {
    local system_info
    system_info=$(get_system_info)
    read -r OS_ID VERSION_ID <<< "$system_info"

    # 静默检查，不输出信息
    case $OS_ID in
        ubuntu|debian|centos|rhel|fedora)
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

# 检查网络连接
check_network_connection() {
    local test_urls=(
        "https://get.hy2.sh"
        "https://github.com"
    )

    # 静默检测网络
    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 3 --max-time 5 --head "$url" >/dev/null 2>&1; then
            return 0
        fi
    done

    # 网络失败才提示
    log_error "网络连接失败，请检查网络后重试"
    return 1
}

# 检查必要的命令
check_required_commands() {
    local missing_commands=()
    local required_commands=("curl" "systemctl")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "缺少必要命令: ${missing_commands[*]}"
        return 1
    fi

    return 0
}

# 检查端口占用
check_port_usage() {
    local port=443

    # 静默检查端口，只在占用时提示
    if ss -tlnp 2>/dev/null | grep -q ":$port " || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        log_warn "端口 $port 已被占用，配置时可使用其他端口"
    fi

    return 0
}

# 备份现有配置
backup_existing_config() {
    if [[ -f "/etc/hysteria/config.yaml" ]]; then
        local backup_file="/etc/hysteria/config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "备份现有配置到: $backup_file"
        cp "/etc/hysteria/config.yaml" "$backup_file"
        return 0
    fi
    return 1
}

# 安装 Hysteria2
install_hysteria2_binary() {
    export HYSTERIA_INSTALL_METHOD="script"
    local install_script_url="https://get.hy2.sh/"

    echo "正在安装 Hysteria2..."

    # 使用官方推荐的管道方式安装，捕获输出并过滤
    local output
    if output=$(timeout 300 bash <(curl -fsSL "$install_script_url") 2>&1); then
        # 显示关键信息（如果有）
        echo "$output" | grep -E "(Installing|Success|Complete|installed|完成|成功)" | head -3 || true
        echo "✓ 安装成功"
        return 0
    else
        log_error "安装失败"
        echo "$output" | tail -5  # 显示最后几行错误信息
        return 1
    fi
}

# 配置系统服务
configure_system_service() {
    local service_file="/lib/systemd/system/hysteria-server.service"

    if [[ ! -f "$service_file" ]] && [[ ! -f "/usr/lib/systemd/system/hysteria-server.service" ]]; then
        return 1
    fi

    systemctl daemon-reload 2>/dev/null
    systemctl enable hysteria-server.service >/dev/null 2>&1
    return 0
}

# 创建配置目录
create_config_directory() {
    if mkdir -p /etc/hysteria 2>/dev/null; then
        chmod 755 /etc/hysteria
        if id hysteria &>/dev/null; then
            chown hysteria:hysteria /etc/hysteria 2>/dev/null
        fi
        return 0
    fi
    return 1
}

# 检查安装结果
verify_installation() {
    if ! command -v hysteria &> /dev/null; then
        log_error "二进制文件未找到"
        return 1
    fi

    local version
    # 尝试多种方式获取版本号
    version=$(hysteria version 2>/dev/null | head -1)

    if [[ -z "$version" ]]; then
        version=$(hysteria --version 2>/dev/null | head -1)
    fi
    if [[ -z "$version" ]]; then
        version=$(hysteria -v 2>/dev/null | head -1)
    fi

    # 提取版本号（支持多种格式）
    if [[ -n "$version" ]]; then
        version=$(echo "$version" | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo "✓ 安装完成: $version"
    else
        echo "✓ 安装完成"
    fi

    return 0
}

# 显示安装后信息
show_post_install_info() {
    echo ""
    echo -e "${CYAN}=== Hysteria2 安装完成 ===${NC}"
    echo ""
    echo -e "${YELLOW}下一步操作:${NC}"
    echo "1. 配置 Hysteria2 服务"
    echo "   • 选择 '2. 一键快速配置' (推荐新用户)"
    echo "   • 或选择 '3. 手动配置' (高级用户)"
    echo ""
    echo "2. 启动服务"
    echo "   • 配置完成后选择 '4. 管理服务'"
    echo ""
    echo "3. 查看节点信息"
    echo "   • 配置完成后选择 '9. 节点信息'"
    echo ""
    echo -e "${YELLOW}重要提示:${NC}"
    echo "• 安装仅完成程序部分，还需要配置才能使用"
    echo "• 配置文件将保存在 /etc/hysteria/config.yaml"
    echo "• 服务日志可通过 '5. 查看日志' 查看"
    echo ""
    echo -e "${GREEN}安装位置信息:${NC}"
    echo "• 二进制文件: $(which hysteria 2>/dev/null || echo "未找到")"
    echo "• 配置目录: /etc/hysteria/"
    echo "• 系统服务: hysteria-server.service"
    if id hysteria &>/dev/null; then
        echo "• 运行用户: hysteria"
    fi
    echo ""
}

# 处理安装失败
handle_install_failure() {
    echo ""
    log_error "Hysteria2 安装失败"
    echo ""
    echo -e "${YELLOW}可能的原因和解决方案:${NC}"
    echo ""
    echo "1. 网络问题:"
    echo "   • 检查网络连接"
    echo "   • 检查防火墙设置"
    echo "   • 尝试使用代理"
    echo ""
    echo "2. 系统兼容性:"
    echo "   • 确认系统版本支持"
    echo "   • 检查系统架构 (amd64/arm64)"
    echo ""
    echo "3. 权限问题:"
    echo "   • 确认以 root 权限运行"
    echo "   • 检查 SELinux 设置"
    echo ""
    echo "4. 手动安装:"
    echo "   • 访问 https://github.com/apernet/hysteria"
    echo "   • 下载对应架构的二进制文件"
    echo "   • 手动配置系统服务"
    echo ""
    echo "如需帮助，请访问项目页面或提交 Issue"
    echo ""
}

# 主安装函数
install_hysteria2() {
    echo -e "${CYAN}=== Hysteria2 安装向导 ===${NC}"
    echo ""
    
    # 检查是否已安装
    if command -v hysteria &> /dev/null; then
        local version
        # 尝试多种方式获取版本号
        version=$(hysteria version 2>/dev/null | head -1)

        # 如果第一种方式失败，尝试其他方式
        if [[ -z "$version" ]]; then
            version=$(hysteria --version 2>/dev/null | head -1)
        fi
        if [[ -z "$version" ]]; then
            version=$(hysteria -v 2>/dev/null | head -1)
        fi

        # 提取版本号（支持多种格式）
        if [[ -n "$version" ]]; then
            # 尝试提取 v2.x.x 或 2.x.x 格式
            version=$(echo "$version" | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        fi

        echo -e "${YELLOW}检测到已安装的 Hysteria2: ${version:-未知版本}${NC}"
        echo ""
        echo -n "是否重新安装? [y/N]: "
        read -r reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            log_info "取消安装"
            return 0
        fi
        echo ""
        log_info "将执行重新安装..."

        # 备份现有配置
        backup_existing_config
    fi
    
    # 执行安装前检查（静默）
    echo "检查环境..."

    check_system_compatibility || error_exit "系统不兼容"
    check_required_commands || error_exit "缺少必要命令"
    check_network_connection || error_exit "网络失败"
    check_port_usage

    echo ""

    # 执行安装步骤
    local install_success=true

    if ! install_hysteria2_binary; then
        install_success=false
    fi

    if $install_success; then
        create_config_directory
        configure_system_service
        verify_installation || install_success=false
    fi
    
    # 显示结果
    echo ""
    if $install_success; then
        show_post_install_info
    else
        handle_install_failure
    fi
    
    echo ""
    read -p "按回车键继续..." -r
    
    return $([ $install_success = true ] && echo 0 || echo 1)
}

# 卸载函数 (如果需要在这里处理)
uninstall_hysteria2() {
    log_info "卸载 Hysteria2..."
    
    # 停止服务
    if systemctl is-active --quiet hysteria-server; then
        systemctl stop hysteria-server
        log_info "已停止服务"
    fi
    
    # 禁用服务
    if systemctl is-enabled --quiet hysteria-server 2>/dev/null; then
        systemctl disable hysteria-server
        log_info "已禁用服务"
    fi
    
    # 使用官方卸载方法
    if curl -fsSL https://get.hy2.sh/ | bash -s -- --remove; then
        log_success "Hysteria2 卸载成功"
    else
        log_error "卸载失败，请手动清理"
        return 1
    fi
    
    return 0
}

# 如果脚本被直接运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_hysteria2
fi
