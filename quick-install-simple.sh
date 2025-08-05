#!/bin/bash

# Hysteria2 配置管理脚本简化安装脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install-simple.sh | sudo bash

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
RAW_URL="https://raw.githubusercontent.com/sindricn/s-hy2/main"

# 打印标题
print_header() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}    Hysteria2 配置管理脚本简化安装${NC}"
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
    echo -e "${GREEN}✓ Root 权限检查通过${NC}"
    return 0
}

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        echo -e "${GREEN}✓ 检测到系统: $PRETTY_NAME${NC}"
        return 0
    else
        echo -e "${RED}✗ 无法检测系统类型${NC}"
        return 1
    fi
}

# 安装基本依赖
install_basic_deps() {
    echo -e "${BLUE}安装基本依赖...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt update -qq
            apt install -y curl wget
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y curl wget
            else
                yum install -y curl wget
            fi
            ;;
        *)
            echo -e "${YELLOW}未知系统，跳过依赖安装${NC}"
            ;;
    esac
    
    echo -e "${GREEN}✓ 基本依赖安装完成${NC}"
}

# 创建目录
create_directories() {
    echo -e "${BLUE}创建安装目录...${NC}"
    
    if mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/scripts" "$INSTALL_DIR/templates"; then
        echo -e "${GREEN}✓ 目录创建成功${NC}"
        return 0
    else
        echo -e "${RED}✗ 目录创建失败${NC}"
        return 1
    fi
}

# 下载主脚本
download_main_script() {
    echo -e "${BLUE}下载主脚本...${NC}"
    
    cd "$INSTALL_DIR" || return 1
    
    if curl -fsSL "$RAW_URL/hy2-manager.sh" -o hy2-manager.sh; then
        chmod +x hy2-manager.sh
        echo -e "${GREEN}✓ 主脚本下载成功${NC}"
        return 0
    else
        echo -e "${RED}✗ 主脚本下载失败${NC}"
        return 1
    fi
}

# 下载核心脚本
download_core_scripts() {
    echo -e "${BLUE}下载核心脚本...${NC}"

    local scripts=(
        "install.sh"
        "config.sh"
        "service.sh"
        "domain-test.sh"
        "advanced.sh"
        "node-info.sh"
    )

    local success=0
    local total=${#scripts[@]}
    local failed_scripts=()

    for script in "${scripts[@]}"; do
        echo "  下载 $script..."
        if curl -fsSL "$RAW_URL/scripts/$script" -o "scripts/$script"; then
            chmod +x "scripts/$script"
            ((success++))
            echo -e "    ${GREEN}✓ $script 下载成功${NC}"
        else
            echo -e "    ${RED}✗ $script 下载失败${NC}"
            failed_scripts+=("$script")
        fi
    done

    echo -e "${GREEN}✓ 核心脚本下载完成 ($success/$total)${NC}"

    if [[ ${#failed_scripts[@]} -gt 0 ]]; then
        echo -e "${YELLOW}失败的脚本: ${failed_scripts[*]}${NC}"
        echo -e "${YELLOW}这可能会影响某些功能的使用${NC}"
    fi

    return 0
}

# 下载配置模板
download_templates() {
    echo -e "${BLUE}下载配置模板...${NC}"
    
    local templates=(
        "acme-config.yaml"
        "self-cert-config.yaml"
        "advanced-config.yaml"
        "client-config.yaml"
    )
    
    local success=0
    local total=${#templates[@]}
    
    for template in "${templates[@]}"; do
        if curl -fsSL "$RAW_URL/templates/$template" -o "templates/$template"; then
            ((success++))
        else
            echo -e "${YELLOW}  警告: $template 下载失败${NC}"
        fi
    done
    
    echo -e "${GREEN}✓ 配置模板下载完成 ($success/$total)${NC}"
    return 0
}

# 创建快捷方式
create_shortcuts() {
    echo -e "${BLUE}创建快捷方式...${NC}"

    if ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/hy2-manager" && \
       ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/s-hy2"; then
        echo -e "${GREEN}✓ 快捷方式创建成功${NC}"
        return 0
    else
        echo -e "${RED}✗ 快捷方式创建失败${NC}"
        return 1
    fi
}

# 验证安装
verify_installation() {
    echo -e "${BLUE}验证安装...${NC}"

    local issues=0

    # 检查主脚本
    if [[ -f "$INSTALL_DIR/hy2-manager.sh" && -x "$INSTALL_DIR/hy2-manager.sh" ]]; then
        echo -e "${GREEN}✓ 主脚本存在且可执行${NC}"
    else
        echo -e "${RED}✗ 主脚本不存在或不可执行${NC}"
        ((issues++))
    fi

    # 检查核心脚本
    local required_scripts=("install.sh" "config.sh" "service.sh")
    for script in "${required_scripts[@]}"; do
        if [[ -f "$INSTALL_DIR/scripts/$script" ]]; then
            echo -e "${GREEN}✓ $script 存在${NC}"
        else
            echo -e "${RED}✗ $script 不存在${NC}"
            ((issues++))
        fi
    done

    # 检查快捷方式
    if [[ -L "$BIN_DIR/s-hy2" ]]; then
        echo -e "${GREEN}✓ s-hy2 快捷方式存在${NC}"
    else
        echo -e "${YELLOW}⚠ s-hy2 快捷方式不存在${NC}"
    fi

    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}✓ 安装验证通过${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ 发现 $issues 个问题，但安装基本完成${NC}"
        return 1
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}    安装完成!${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
    echo -e "${GREEN}安装位置:${NC} $INSTALL_DIR"
    echo -e "${GREEN}快捷命令:${NC} s-hy2, hy2-manager"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  sudo s-hy2"
    echo ""
    echo -e "${YELLOW}快速开始:${NC}"
    echo "1. 运行: sudo s-hy2"
    echo "2. 选择 '1. 安装 Hysteria2'"
    echo "3. 选择 '2. 一键快速配置'"
    echo ""

    # 询问是否立即运行
    if [[ -t 0 ]]; then
        echo -n -e "${YELLOW}是否立即运行 s-hy2? [y/N]: ${NC}"
        read -r run_now
        if [[ $run_now =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${BLUE}正在启动 s-hy2...${NC}"
            exec "$INSTALL_DIR/hy2-manager.sh"
        else
            echo -e "${BLUE}安装完成，稍后可运行 'sudo s-hy2' 开始使用${NC}"
        fi
    else
        echo -e "${BLUE}安装完成，请运行 'sudo s-hy2' 开始使用${NC}"
    fi
}

# 卸载函数
uninstall() {
    echo -e "${YELLOW}卸载 S-Hy2 管理脚本...${NC}"
    
    rm -f "$BIN_DIR/hy2-manager"
    rm -f "$BIN_DIR/s-hy2"
    rm -rf "$INSTALL_DIR"
    
    echo -e "${GREEN}卸载完成${NC}"
}

# 主函数
main() {
    # 检查卸载参数
    if [[ "$1" == "--uninstall" ]]; then
        uninstall
        exit 0
    fi
    
    print_header
    
    echo -e "${YELLOW}即将安装 Hysteria2 配置管理脚本${NC}"
    echo ""
    echo -e "${BLUE}此脚本将会:${NC}"
    echo "• 检测系统环境"
    echo "• 安装基本依赖"
    echo "• 下载脚本文件"
    echo "• 创建快捷命令 's-hy2'"
    echo "• 设置执行权限"
    echo ""

    # 检查是否通过管道运行
    if [[ -t 0 ]]; then
        # 交互模式
        echo -n -e "${YELLOW}是否继续安装? [Y/n]: ${NC}"
        read -r confirm
        if [[ $confirm =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}取消安装${NC}"
            exit 0
        fi
    else
        # 管道模式，自动确认
        echo -e "${YELLOW}检测到管道模式，自动开始安装...${NC}"
        sleep 2
    fi
    
    echo ""
    echo -e "${BLUE}开始安装...${NC}"
    
    # 执行安装步骤
    if ! check_root; then
        echo -e "${RED}安装失败: 需要 root 权限${NC}"
        exit 1
    fi
    
    if ! detect_system; then
        echo -e "${RED}安装失败: 无法检测系统${NC}"
        exit 1
    fi
    
    install_basic_deps
    
    if ! create_directories; then
        echo -e "${RED}安装失败: 无法创建目录${NC}"
        exit 1
    fi
    
    if ! download_main_script; then
        echo -e "${RED}安装失败: 主脚本下载失败${NC}"
        exit 1
    fi
    
    download_core_scripts
    download_templates
    
    if ! create_shortcuts; then
        echo -e "${YELLOW}警告: 快捷方式创建失败${NC}"
    fi

    # 验证安装
    verify_installation

    show_completion
}

# 运行主函数
main "$@"
