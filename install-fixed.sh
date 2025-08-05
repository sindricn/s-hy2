#!/bin/bash

# Hysteria2 配置管理脚本修复版安装脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/install-fixed.sh | sudo bash

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

# 检查是否为交互模式
INTERACTIVE=false
if [[ -t 0 ]]; then
    INTERACTIVE=true
fi

# 打印标题
print_header() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}    Hysteria2 配置管理脚本安装程序${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 需要 root 权限运行此脚本${NC}"
        echo "请使用: sudo bash"
        exit 1
    fi
    echo -e "${GREEN}✓ Root 权限检查通过${NC}"
}

# 检测系统
detect_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
        echo -e "${GREEN}✓ 系统: $PRETTY_NAME${NC}"
    else
        echo -e "${RED}✗ 无法检测系统类型${NC}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}安装基本依赖...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt update -qq >/dev/null 2>&1
            apt install -y curl wget >/dev/null 2>&1
            ;;
        centos|rhel|fedora)
            if command -v dnf &>/dev/null; then
                dnf install -y curl wget >/dev/null 2>&1
            else
                yum install -y curl wget >/dev/null 2>&1
            fi
            ;;
    esac
    
    echo -e "${GREEN}✓ 依赖安装完成${NC}"
}

# 创建目录
create_directories() {
    echo -e "${BLUE}创建安装目录...${NC}"
    
    if mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/scripts" "$INSTALL_DIR/templates"; then
        echo -e "${GREEN}✓ 目录创建成功${NC}"
    else
        echo -e "${RED}✗ 目录创建失败${NC}"
        exit 1
    fi
}

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    local description="$3"
    
    if curl -fsSL "$url" -o "$output" 2>/dev/null; then
        echo -e "${GREEN}  ✓ $description${NC}"
        return 0
    else
        echo -e "${RED}  ✗ $description${NC}"
        return 1
    fi
}

# 下载所有文件
download_files() {
    echo -e "${BLUE}下载脚本文件...${NC}"
    
    cd "$INSTALL_DIR" || exit 1
    
    local total=0
    local success=0
    
    # 下载主脚本
    ((total++))
    if download_file "$RAW_URL/hy2-manager.sh" "hy2-manager.sh" "主脚本"; then
        chmod +x hy2-manager.sh
        ((success++))
    fi
    
    # 下载功能脚本
    local scripts=(
        "install.sh:安装脚本"
        "config.sh:配置脚本"
        "service.sh:服务管理脚本"
        "domain-test.sh:域名测试脚本"
        "advanced.sh:进阶配置脚本"
        "node-info.sh:节点信息脚本"
    )
    
    for script_info in "${scripts[@]}"; do
        IFS=':' read -r script_name script_desc <<< "$script_info"
        ((total++))
        if download_file "$RAW_URL/scripts/$script_name" "scripts/$script_name" "$script_desc"; then
            chmod +x "scripts/$script_name"
            ((success++))
        fi
    done
    
    # 下载配置模板
    local templates=(
        "acme-config.yaml:ACME配置模板"
        "self-cert-config.yaml:自签名配置模板"
        "advanced-config.yaml:高级配置模板"
        "client-config.yaml:客户端配置模板"
    )
    
    for template_info in "${templates[@]}"; do
        IFS=':' read -r template_name template_desc <<< "$template_info"
        ((total++))
        if download_file "$RAW_URL/templates/$template_name" "templates/$template_name" "$template_desc"; then
            ((success++))
        fi
    done
    
    echo -e "${GREEN}✓ 文件下载完成 ($success/$total)${NC}"
    
    if [[ $success -lt 7 ]]; then  # 至少需要主脚本和6个核心脚本
        echo -e "${RED}✗ 关键文件下载失败，安装无法继续${NC}"
        exit 1
    fi
}

# 创建快捷方式
create_shortcuts() {
    echo -e "${BLUE}创建快捷方式...${NC}"
    
    if ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/s-hy2" && \
       ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/hy2-manager"; then
        echo -e "${GREEN}✓ 快捷方式创建成功${NC}"
    else
        echo -e "${YELLOW}⚠ 快捷方式创建失败，可直接运行: $INSTALL_DIR/hy2-manager.sh${NC}"
    fi
}

# 验证安装
verify_installation() {
    echo -e "${BLUE}验证安装...${NC}"
    
    # 检查关键文件
    local required_files=(
        "$INSTALL_DIR/hy2-manager.sh"
        "$INSTALL_DIR/scripts/install.sh"
        "$INSTALL_DIR/scripts/config.sh"
        "$INSTALL_DIR/scripts/service.sh"
    )
    
    local missing=0
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "${RED}✗ 缺少文件: $file${NC}"
            ((missing++))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        echo -e "${GREEN}✓ 安装验证通过${NC}"
        return 0
    else
        echo -e "${RED}✗ 安装验证失败，缺少 $missing 个关键文件${NC}"
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
    echo -e "${GREEN}快捷命令:${NC} s-hy2"
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
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo -n -e "${YELLOW}是否立即运行 s-hy2? [y/N]: ${NC}"
        read -r run_now
        if [[ $run_now =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${BLUE}正在启动 s-hy2...${NC}"
            sleep 1
            exec "$INSTALL_DIR/hy2-manager.sh"
        fi
    fi
    
    echo -e "${BLUE}安装完成，请运行 'sudo s-hy2' 开始使用${NC}"
}

# 卸载函数
uninstall() {
    echo -e "${YELLOW}卸载 S-Hy2 管理脚本...${NC}"
    
    rm -f "$BIN_DIR/s-hy2" "$BIN_DIR/hy2-manager"
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
    echo "• 创建快捷命令"
    echo "• 验证安装结果"
    echo ""
    
    # 交互确认
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo -n -e "${YELLOW}是否继续安装? [Y/n]: ${NC}"
        read -r confirm
        if [[ $confirm =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}取消安装${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}检测到非交互模式，自动开始安装...${NC}"
        sleep 2
    fi
    
    echo ""
    echo -e "${BLUE}开始安装...${NC}"
    
    # 执行安装步骤
    check_root
    detect_system
    install_dependencies
    create_directories
    download_files
    create_shortcuts
    
    if verify_installation; then
        show_completion
    else
        echo -e "${RED}安装过程中出现问题，请检查错误信息${NC}"
        exit 1
    fi
}

# 运行主函数
main "$@"
