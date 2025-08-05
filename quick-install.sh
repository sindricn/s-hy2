#!/bin/bash

# Hysteria2 配置管理脚本一键安装脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/your-repo/s-hy2/main/quick-install.sh | sudo bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 脚本信息
SCRIPT_NAME="s-hy2"
INSTALL_DIR="/opt/$SCRIPT_NAME"
BIN_DIR="/usr/local/bin"
REPO_URL="https://github.com/sindricn/s-hy2"
RAW_URL="https://raw.githubusercontent.com/sindricn/s-hy2/main"

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
        exit 1
    fi
}

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        echo -e "${RED}无法检测系统类型${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}检测到系统: $PRETTY_NAME${NC}"
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}安装必要依赖...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt update
            apt install -y curl wget git openssl net-tools iptables
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y curl wget git openssl net-tools iptables
            else
                yum install -y curl wget git openssl net-tools iptables
            fi
            ;;
        *)
            echo -e "${YELLOW}未知系统，尝试通用安装...${NC}"
            ;;
    esac
}

# 下载脚本文件
download_scripts() {
    echo -e "${BLUE}下载 Hysteria2 配置管理脚本...${NC}"
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$INSTALL_DIR/templates"
    
    cd "$INSTALL_DIR"
    
    # 下载主脚本
    echo "下载主脚本..."
    curl -fsSL "$RAW_URL/hy2-manager.sh" -o hy2-manager.sh
    
    # 下载功能脚本
    echo "下载功能模块..."
    curl -fsSL "$RAW_URL/scripts/install.sh" -o scripts/install.sh
    curl -fsSL "$RAW_URL/scripts/config.sh" -o scripts/config.sh
    curl -fsSL "$RAW_URL/scripts/service.sh" -o scripts/service.sh
    curl -fsSL "$RAW_URL/scripts/domain-test.sh" -o scripts/domain-test.sh
    curl -fsSL "$RAW_URL/scripts/advanced.sh" -o scripts/advanced.sh
    curl -fsSL "$RAW_URL/scripts/node-info.sh" -o scripts/node-info.sh
    
    # 下载配置模板
    echo "下载配置模板..."
    curl -fsSL "$RAW_URL/templates/acme-config.yaml" -o templates/acme-config.yaml
    curl -fsSL "$RAW_URL/templates/self-cert-config.yaml" -o templates/self-cert-config.yaml
    curl -fsSL "$RAW_URL/templates/advanced-config.yaml" -o templates/advanced-config.yaml
    curl -fsSL "$RAW_URL/templates/client-config.yaml" -o templates/client-config.yaml
    
    # 设置执行权限
    chmod +x hy2-manager.sh
    chmod +x scripts/*.sh
    
    echo -e "${GREEN}脚本文件下载完成${NC}"
}

# 创建符号链接
create_symlink() {
    echo -e "${BLUE}创建命令行快捷方式...${NC}"
    
    # 创建符号链接到 /usr/local/bin
    ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/hy2-manager"
    ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/s-hy2"
    
    echo -e "${GREEN}已创建命令行快捷方式:${NC}"
    echo "  hy2-manager"
    echo "  s-hy2"
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
    echo "  ✓ 进阶配置支持"
    echo ""
    echo -e "${YELLOW}快速开始:${NC}"
    echo "1. 运行: sudo s-hy2"
    echo "2. 选择 '1. 安装 Hysteria2'"
    echo "3. 选择 '2. 一键快速配置'"
    echo "4. 选择 '8. 节点信息' 查看连接信息"
    echo ""
    echo -e "${BLUE}现在可以运行 'sudo s-hy2' 开始使用!${NC}"
    echo ""
}

# 检查网络连接
check_network() {
    echo -e "${BLUE}检查网络连接...${NC}"
    if ! curl -s --connect-timeout 10 https://www.google.com > /dev/null; then
        echo -e "${RED}网络连接失败，请检查网络设置${NC}"
        exit 1
    fi
    echo -e "${GREEN}网络连接正常${NC}"
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
    echo -n -e "${YELLOW}是否继续安装? [Y/n]: ${NC}"
    read -r confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}取消安装${NC}"
        exit 0
    fi
    
    check_root
    check_network
    detect_system
    install_dependencies
    download_scripts
    create_symlink
    create_desktop_shortcut
    show_completion
}

# 运行主函数
main "$@"
