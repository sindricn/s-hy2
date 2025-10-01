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
    
    log_info "检测系统: $OS_ID $VERSION_ID"
    
    case $OS_ID in
        ubuntu)
            if [[ $(echo "$VERSION_ID >= 18.04" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
                return 0
            fi
            ;;
        debian)
            if [[ $(echo "$VERSION_ID >= 9" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
                return 0
            fi
            ;;
        centos|rhel)
            if [[ $(echo "$VERSION_ID >= 7" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
                return 0
            fi
            ;;
        fedora)
            if [[ $(echo "$VERSION_ID >= 30" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
                return 0
            fi
            ;;
        *)
            log_warn "未知系统，将尝试通用安装"
            return 0
            ;;
    esac
    
    log_warn "系统版本可能不完全兼容，但将尝试安装"
    return 0
}

# 检查网络连接
check_network_connection() {
    log_info "检查网络连接..."

    local test_urls=(
        "https://github.com"
        "https://get.hy2.sh"
        "https://www.google.com"
        "https://raw.githubusercontent.com"
    )

    local connected=false
    # 直接使用 HTTP 连接测试，更可靠
    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 3 --max-time 8 --head "$url" >/dev/null 2>&1; then
            connected=true
            break
        fi
    done
    
    if $connected; then
        log_success "网络连接正常"
        return 0
    else
        log_error "网络连接检查失败"
        echo "请检查:"
        echo "1. 网络连接是否正常"
        echo "2. DNS 解析是否正常"
        echo "3. 防火墙是否阻止了连接"
        echo ""
        echo "是否继续安装? (可能会失败) [y/N]"
        read -r continue_install
        if [[ $continue_install =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
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
        log_error "缺少必要的命令:"
        printf ' • %s\n' "${missing_commands[@]}"
        echo ""
        echo "请先安装这些命令，然后重新运行脚本"
        return 1
    fi
    
    return 0
}

# 检查端口占用
check_port_usage() {
    local port=443
    
    if ss -tlnp | grep -q ":$port "; then
        log_warn "端口 $port 已被占用"
        echo ""
        echo "占用端口 $port 的进程:"
        ss -tlnp | grep ":$port " || netstat -tlnp | grep ":$port " 2>/dev/null
        echo ""
        echo "请处理端口占用后重新安装，或在配置时使用其他端口"
        echo ""
        echo -n "是否继续安装? [y/N]: "
        read -r continue_install
        if [[ ! $continue_install =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        log_success "端口 $port 可用"
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

# 安装 Hysteria2 (安全版本)
install_hysteria2_binary() {
    log_info "开始安装 Hysteria2..."

    # 设置安装脚本的环境变量
    export HYSTERIA_INSTALL_METHOD="script"

    # 使用官方推荐的安装方式
    local install_script_url="https://get.hy2.sh/"

    log_info "执行官方安装脚本..."

    # 使用官方推荐的管道方式安装
    if timeout 300 bash <(curl -fsSL "$install_script_url"); then
        log_success "Hysteria2 安装成功"
        return 0
    else
        log_error "Hysteria2 安装失败"
        log_info "如果安装失败，请检查网络连接或手动执行: bash <(curl -fsSL https://get.hy2.sh/)"
        return 1
    fi
}

# 配置系统服务
configure_system_service() {
    log_info "配置系统服务..."
    
    # 检查服务文件是否存在
    local service_file="/lib/systemd/system/hysteria-server.service"
    if [[ ! -f "$service_file" ]] && [[ ! -f "/usr/lib/systemd/system/hysteria-server.service" ]]; then
        log_warn "系统服务文件未找到，可能需要手动配置"
        return 1
    fi
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    # 启用服务（但不启动，等配置完成后再启动）
    if systemctl enable hysteria-server.service; then
        log_success "系统服务配置成功"
        return 0
    else
        log_error "系统服务配置失败"
        return 1
    fi
}

# 创建配置目录
create_config_directory() {
    log_info "创建配置目录..."
    
    if mkdir -p /etc/hysteria; then
        # 设置适当的权限
        chmod 755 /etc/hysteria
        
        # 如果 hysteria 用户存在，设置所有权
        if id hysteria &>/dev/null; then
            chown hysteria:hysteria /etc/hysteria
        fi
        
        log_success "配置目录创建成功"
        return 0
    else
        log_error "配置目录创建失败"
        return 1
    fi
}

# 检查安装结果
verify_installation() {
    log_info "验证安装结果..."
    
    # 检查二进制文件
    if ! command -v hysteria &> /dev/null; then
        log_error "Hysteria2 二进制文件未找到"
        return 1
    fi
    
    # 检查版本
    local version
    version=$(hysteria version 2>/dev/null | head -1)
    if [[ -n "$version" ]]; then
        log_success "Hysteria2 安装成功: $version"
    else
        log_warn "无法获取版本信息，但二进制文件存在"
    fi
    
    # 检查系统服务
    if systemctl list-unit-files | grep -q hysteria-server; then
        log_success "系统服务注册成功"
    else
        log_warn "系统服务未正确注册"
    fi
    
    # 检查用户账户
    if id hysteria &>/dev/null; then
        log_success "hysteria 用户账户存在"
    else
        log_warn "hysteria 用户账户不存在"
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
        version=$(hysteria version 2>/dev/null | head -1)
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
    
    # 执行安装前检查
    log_info "执行安装前检查..."
    echo ""
    
    if ! check_system_compatibility; then
        error_exit "系统兼容性检查失败"
    fi
    
    if ! check_required_commands; then
        error_exit "必要命令检查失败"
    fi
    
    if ! check_network_connection; then
        error_exit "网络连接检查失败"
    fi
    
    if ! check_port_usage; then
        error_exit "端口检查失败"
    fi
    
    echo ""
    log_success "所有检查通过，开始安装..."
    echo ""
    
    # 执行安装步骤
    local install_success=true
    
    # 步骤1: 安装二进制文件
    if ! install_hysteria2_binary; then
        install_success=false
    fi
    
    # 步骤2: 创建配置目录
    if $install_success && ! create_config_directory; then
        log_warn "配置目录创建失败，但继续安装"
    fi
    
    # 步骤3: 配置系统服务
    if $install_success && ! configure_system_service; then
        log_warn "系统服务配置失败，但继续安装"
    fi
    
    # 步骤4: 验证安装
    if $install_success && ! verify_installation; then
        install_success=false
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
