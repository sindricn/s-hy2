#!/bin/bash

# Hysteria2 配置管理脚本一键安装脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 脚本信息
SCRIPT_NAME="hy2-manager"
INSTALL_DIR="/opt/$SCRIPT_NAME"
BIN_DIR="/usr/local/bin"
REPO_URL="https://github.com/sindricn/s-hy2"

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
            apt install -y curl wget git openssl net-tools
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y curl wget git openssl net-tools
            else
                yum install -y curl wget git openssl net-tools
            fi
            ;;
        *)
            echo -e "${YELLOW}未知系统，尝试通用安装...${NC}"
            ;;
    esac
}

# 下载脚本
download_script() {
    echo -e "${BLUE}下载 Hysteria2 配置管理脚本...${NC}"
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 下载方式1: 从 GitHub 下载
    if command -v git &> /dev/null; then
        echo -e "${BLUE}使用 git 克隆仓库...${NC}"
        git clone "$REPO_URL" . 2>/dev/null || {
            echo -e "${YELLOW}Git 克隆失败，尝试直接下载...${NC}"
            download_direct
        }
    else
        download_direct
    fi
    
    # 设置执行权限
    chmod +x hy2-manager.sh
    chmod +x scripts/*.sh
}

# 直接下载文件
download_direct() {
    echo -e "${BLUE}直接下载脚本文件...${NC}"
    
    # 这里应该替换为实际的下载链接
    # 由于这是示例，我们创建一个本地复制的方式
    echo -e "${YELLOW}注意: 请手动将脚本文件复制到 $INSTALL_DIR${NC}"
    echo "或者从以下地址下载:"
    echo "  主脚本: $REPO_URL/raw/main/hy2-manager.sh"
    echo "  脚本目录: $REPO_URL/tree/main/scripts"
    echo "  模板目录: $REPO_URL/tree/main/templates"
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
            
            cat > "$desktop_dir/Hysteria2-Manager.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Hysteria2 Manager
Comment=Hysteria2 配置管理工具
Exec=sudo $INSTALL_DIR/hy2-manager.sh
Icon=network-server
Terminal=true
Categories=Network;System;
EOF
            
            chmod +x "$desktop_dir/Hysteria2-Manager.desktop"
            chown "$SUDO_USER:$SUDO_USER" "$desktop_dir/Hysteria2-Manager.desktop"
            
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
    echo -e "${GREEN}命令快捷方式:${NC} hy2-manager, s-hy2"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  方式1: 快捷命令 (推荐)"
    echo "    sudo s-hy2"
    echo ""
    echo "  方式2: 完整命令"
    echo "    sudo hy2-manager"
    echo ""
    echo "  方式3: 运行完整路径"
    echo "    sudo $INSTALL_DIR/hy2-manager.sh"
    echo ""
    echo -e "${YELLOW}功能特性:${NC}"
    echo "  ✓ 一键安装/卸载 Hysteria2"
    echo "  ✓ 交互式配置生成"
    echo "  ✓ 智能伪装域名选择"
    echo "  ✓ 服务管理和监控"
    echo "  ✓ 进阶配置支持"
    echo ""
    echo -e "${BLUE}现在可以运行 'sudo s-hy2' 开始使用!${NC}"
    echo ""
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
        rm -f "/home/$SUDO_USER/Desktop/Hysteria2-Manager.desktop"
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
    
    echo -e "${CYAN}Hysteria2 配置管理脚本安装程序${NC}"
    echo ""
    
    check_root
    detect_system
    install_dependencies
    download_script
    create_symlink
    create_desktop_shortcut
    show_completion
}

# 运行主函数
main "$@"
