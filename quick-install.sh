#!/bin/bash

# Hysteria2 配置管理脚本一键安装脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash
# 调试模式: curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash -s -- --debug

# 检查是否启用调试模式
if [[ "$1" == "--debug" ]]; then
    set -x  # 启用调试输出
    DEBUG_MODE=true
else
    DEBUG_MODE=false
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 脚本信息
SCRIPT_NAME="s-hy2"
INSTALL_DIR="/opt/$SCRIPT_NAME"
BIN_DIR="/usr/local/bin"
REPO_URL="https://github.com/sindricn/s-hy2"
RAW_URL="https://raw.githubusercontent.com/sindricn/s-hy2/dev"

# 打印标题
print_header() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}    Hysteria2 配置管理脚本一键安装${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
        echo "请使用 sudo 运行此脚本"
        return 1
    fi
    return 0
}

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        echo -e "${BLUE}检测到系统: $PRETTY_NAME${NC}"
        return 0
    else
        echo -e "${RED}无法检测系统类型${NC}"
        return 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}安装必要依赖...${NC}"

    case $OS in
        ubuntu|debian)
            echo "更新软件包列表..."
            if ! apt update; then
                echo -e "${YELLOW}警告: 软件包列表更新失败，继续安装...${NC}"
            fi
            echo "安装依赖包..."
            if ! apt install -y curl wget git openssl net-tools iptables; then
                echo -e "${YELLOW}警告: 部分依赖安装失败，继续执行...${NC}"
            fi
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                echo "使用 dnf 安装依赖..."
                if ! dnf install -y curl wget git openssl net-tools iptables; then
                    echo -e "${YELLOW}警告: 部分依赖安装失败，继续执行...${NC}"
                fi
            else
                echo "使用 yum 安装依赖..."
                if ! yum install -y curl wget git openssl net-tools iptables; then
                    echo -e "${YELLOW}警告: 部分依赖安装失败，继续执行...${NC}"
                fi
            fi
            ;;
        *)
            echo -e "${YELLOW}未知系统，跳过依赖安装...${NC}"
            ;;
    esac

    echo -e "${GREEN}依赖安装完成${NC}"
}

# 下载单个文件
download_file() {
    local url="$1"
    local output="$2"
    local description="$3"

    echo "  下载 $description..."
    if ! curl -fsSL "$url" -o "$output"; then
        echo -e "${RED}    失败: 无法下载 $description${NC}"
        return 1
    fi
    return 0
}

# 下载脚本文件
download_scripts() {
    echo -e "${BLUE}下载 Hysteria2 配置管理脚本...${NC}"

    # 创建安装目录
    if ! mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/scripts" "$INSTALL_DIR/templates" "$INSTALL_DIR/scripts/outbound-templates"; then
        echo -e "${RED}错误: 无法创建安装目录${NC}"
        exit 1
    fi

    cd "$INSTALL_DIR" || {
        echo -e "${RED}错误: 无法进入安装目录${NC}"
        exit 1
    }

    local failed_downloads=0

    # 下载主脚本
    if ! download_file "$RAW_URL/hy2-manager.sh" "hy2-manager.sh" "主脚本"; then
        ((failed_downloads++))
    fi

    # 下载功能脚本
    echo "下载功能模块..."
    local scripts=(
        "common.sh:公共库脚本"
        "install.sh:安装脚本"
        "config.sh:配置脚本"
        "config-loader.sh:配置加载器"
        "service.sh:服务管理脚本"
        "domain-test.sh:域名测试脚本"
        "node-info.sh:节点信息脚本"
        "input-validation.sh:输入验证模块"
        "secure-download.sh:安全下载模块"
        "firewall-manager.sh:防火墙管理模块"
        "outbound-manager.sh:出站管理模块"
        "performance-monitor.sh:性能监控模块"
        "performance-utils.sh:性能工具模块"
        "post-deploy-check.sh:部署后检查模块"
    )

    for script_info in "${scripts[@]}"; do
        IFS=':' read -r script_name script_desc <<< "$script_info"
        if ! download_file "$RAW_URL/scripts/$script_name" "scripts/$script_name" "$script_desc"; then
            ((failed_downloads++))
        fi
    done

    # 下载配置模板
    echo "下载配置模板..."
    local templates=(
        "acme-config.yaml:ACME配置模板"
        "self-cert-config.yaml:自签名配置模板"
        "client-config.yaml:客户端配置模板"
    )

    for template_info in "${templates[@]}"; do
        IFS=':' read -r template_name template_desc <<< "$template_info"
        if ! download_file "$RAW_URL/templates/$template_name" "templates/$template_name" "$template_desc"; then
            ((failed_downloads++))
        fi
    done

    # 下载出站模板
    echo "下载出站配置模板..."
    local outbound_templates=(
        "direct.yaml:直连出站模板"
        "socks5.yaml:SOCKS5出站模板"
        "http.yaml:HTTP出站模板"
    )

    for template_info in "${outbound_templates[@]}"; do
        IFS=':' read -r template_name template_desc <<< "$template_info"
        if ! download_file "$RAW_URL/scripts/outbound-templates/$template_name" "scripts/outbound-templates/$template_name" "$template_desc"; then
            ((failed_downloads++))
        fi
    done

    # 设置执行权限
    echo "设置执行权限..."
    chmod +x hy2-manager.sh 2>/dev/null || echo -e "${YELLOW}警告: 无法设置主脚本执行权限${NC}"
    chmod +x scripts/*.sh 2>/dev/null || echo -e "${YELLOW}警告: 无法设置脚本执行权限${NC}"

    if [[ $failed_downloads -gt 0 ]]; then
        echo -e "${YELLOW}警告: $failed_downloads 个文件下载失败，但继续安装...${NC}"
    fi

    echo -e "${GREEN}脚本文件下载完成${NC}"
}

# 创建符号链接
create_symlink() {
    echo -e "${BLUE}创建命令行快捷方式...${NC}"

    # 创建符号链接到 /usr/local/bin
    if ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/hy2-manager" && \
       ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/s-hy2"; then
        echo -e "${GREEN}已创建命令行快捷方式:${NC}"
        echo "  hy2-manager"
        echo "  s-hy2"
        return 0
    else
        echo -e "${RED}创建快捷方式失败${NC}"
        return 1
    fi
}

# 创建桌面快捷方式 (可选)
create_desktop_shortcut() {
    if [[ -d "/home" ]] && [[ -n "$SUDO_USER" ]]; then
        local user_home="/home/$SUDO_USER"
        local desktop_dir="$user_home/Desktop"
        
        if [[ -d "$desktop_dir" ]]; then
            echo -e "${BLUE}创建桌面快捷方式...${NC}"
            
            cat > "$desktop_dir/S-Hy2-Manager.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=S-Hy2 Manager
Comment=Hysteria2 配置管理工具
Exec=sudo $INSTALL_DIR/hy2-manager.sh
Icon=network-server
Terminal=true
Categories=Network;System;
EOF
            
            chmod +x "$desktop_dir/S-Hy2-Manager.desktop"
            chown "$SUDO_USER:$SUDO_USER" "$desktop_dir/S-Hy2-Manager.desktop"
            
            echo -e "${GREEN}桌面快捷方式已创建${NC}"
        fi
    fi
}

# 显示安装完成信息
show_completion() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}    Hysteria2 配置管理脚本安装完成!${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
    echo -e "${GREEN}安装位置:${NC} $INSTALL_DIR"
    echo -e "${GREEN}命令快捷方式:${NC} s-hy2, hy2-manager"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  方式1: 快捷命令 (推荐)"
    echo "    sudo s-hy2"
    echo ""
    echo "  方式2: 完整命令"
    echo "    sudo hy2-manager"
    echo ""
    echo -e "${YELLOW}功能特性:${NC}"
    echo "  ✓ 一键安装/卸载 Hysteria2"
    echo "  ✓ 一键快速配置 (自签名证书+混淆+端口跳跃)"
    echo "  ✓ 手动配置 (ACME/自签名证书)"
    echo "  ✓ 智能伪装域名选择"
    echo "  ✓ 服务管理和监控"
    echo "  ✓ 节点信息和订阅链接生成"
    echo "  ✓ 配置管理和证书管理"
    echo "  ✓ 防火墙智能管理"
    echo "  ✓ 出站代理配置"
    echo "  ✓ 性能监控和优化"
    echo "  ✓ 部署后安全检查"
    echo ""
    echo -e "${YELLOW}快速开始:${NC}"
    echo "1. 运行: sudo s-hy2"
    echo "2. 选择 '1. 安装 Hysteria2'"
    echo "3. 选择 '2. 一键快速配置'"
    echo "4. 选择 '7. 节点信息' 查看连接信息"
    echo ""
    echo -e "${BLUE}现在可以运行 'sudo s-hy2' 开始使用!${NC}"
    echo ""
}

# 检查网络连接
check_network() {
    echo -e "${BLUE}检查网络连接...${NC}"

    # 尝试多个网站测试网络连接
    local test_urls=(
        "https://www.google.com"
        "https://github.com"
        "https://raw.githubusercontent.com"
        "https://www.baidu.com"
    )

    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}网络连接正常${NC}"
            return 0
        fi
    done

    echo -e "${YELLOW}警告: 网络连接可能有问题，但继续尝试安装...${NC}"
    return 0
}

# 卸载脚本
uninstall() {
    echo -e "${YELLOW}卸载 Hysteria2 配置管理脚本...${NC}"
    
    # 删除符号链接
    rm -f "$BIN_DIR/hy2-manager"
    rm -f "$BIN_DIR/s-hy2"
    
    # 删除安装目录
    rm -rf "$INSTALL_DIR"
    
    # 删除桌面快捷方式
    if [[ -n "$SUDO_USER" ]]; then
        rm -f "/home/$SUDO_USER/Desktop/S-Hy2-Manager.desktop"
    fi
    
    echo -e "${GREEN}卸载完成${NC}"
}

# 简化的确认函数 - 直接安装或交互确认
confirm_installation() {
    # 检查是否通过管道运行
    if [[ -t 0 ]]; then
        # 标准输入可用，可以进行交互
        echo -n -e "${YELLOW}是否继续安装? [Y/n]: ${NC}"
        read -r confirm
        if [[ $confirm =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}取消安装${NC}"
            exit 0
        fi
    else
        # 通过管道运行，检查是否有强制参数
        if [[ "$1" != "--force" && "$1" != "-f" ]]; then
            echo -e "${YELLOW}检测到通过管道运行脚本，开始安装...${NC}"
        else
            echo -e "${BLUE}强制模式，跳过确认${NC}"
        fi
    fi
}

# 主函数
main() {
    # 检查参数
    if [[ "$1" == "--uninstall" ]]; then
        uninstall
        exit 0
    fi

    print_header

    echo -e "${YELLOW}即将安装 Hysteria2 配置管理脚本${NC}"
    echo ""
    echo -e "${BLUE}此脚本将会:${NC}"
    echo "• 检测系统环境"
    echo "• 安装必要依赖"
    echo "• 下载脚本文件"
    echo "• 创建快捷命令 's-hy2'"
    echo "• 设置执行权限"
    echo ""

    # 使用改进的确认函数
    confirm_installation "$1"

    echo ""
    echo -e "${BLUE}开始安装...${NC}"

    # 逐步执行，增加错误处理
    if ! check_root; then
        echo -e "${RED}安装失败: 需要 root 权限${NC}"
        exit 1
    fi

    check_network  # 网络检查不强制退出

    if ! detect_system; then
        echo -e "${RED}安装失败: 无法检测系统类型${NC}"
        exit 1
    fi

    install_dependencies  # 依赖安装失败不强制退出

    if ! download_scripts; then
        echo -e "${RED}安装失败: 脚本下载失败${NC}"
        exit 1
    fi

    if ! create_symlink; then
        echo -e "${YELLOW}警告: 创建快捷方式失败，但安装继续...${NC}"
    fi

    create_desktop_shortcut  # 桌面快捷方式失败不影响安装

    show_completion
}

# 运行主函数
main "$@"
