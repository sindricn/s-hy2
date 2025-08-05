#!/bin/bash

# Hysteria2 配置管理脚本
# 版本: 1.0.0
# 作者: Hysteria2 Manager

# 移除 set -e 以避免脚本意外退出
# set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本目录 - 处理符号链接
if [[ -L "${BASH_SOURCE[0]}" ]]; then
    # 如果是符号链接，获取真实路径
    SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
else
    # 如果不是符号链接，使用当前路径
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# 如果脚本在 /usr/local/bin 中运行，假设安装在 /opt/s-hy2
if [[ "$SCRIPT_DIR" == "/usr/local/bin" ]]; then
    SCRIPT_DIR="/opt/s-hy2"
fi

SCRIPTS_DIR="$SCRIPT_DIR/scripts"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# 配置文件路径
CONFIG_PATH="/etc/hysteria/config.yaml"
SERVER_DOMAIN_CONFIG="/etc/hysteria/server-domain.conf"
SERVICE_NAME="hysteria-server.service"

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
        echo "请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 打印标题
print_header() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}           Hysteria2 配置管理脚本${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# 打印菜单
print_menu() {
    echo -e "${YELLOW}请选择操作:${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 安装 Hysteria2"
    echo -e "${GREEN}2.${NC} 一键快速配置"
    echo -e "${GREEN}3.${NC} 手动配置"
    echo -e "${GREEN}4.${NC} 管理服务"
    echo -e "${GREEN}5.${NC} 查看日志"
    echo -e "${GREEN}6.${NC} 测试伪装域名"
    echo -e "${GREEN}7.${NC} 服务器域名配置"
    echo -e "${GREEN}8.${NC} 进阶配置"
    echo -e "${GREEN}9.${NC} 节点信息"
    echo -e "${GREEN}10.${NC} 卸载服务"
    echo -e "${GREEN}11.${NC} 关于脚本"
    echo -e "${RED}0.${NC} 退出"
    echo ""
    echo -n -e "${BLUE}请输入选项 [0-11]: ${NC}"
}

# 检查 Hysteria2 是否已安装
check_hysteria_installed() {
    if command -v hysteria &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查服务状态
check_service_status() {
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}运行中${NC}"
    elif systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}已启用但未运行${NC}"
    else
        echo -e "${RED}未启用${NC}"
    fi
}

# 显示当前状态
show_status() {
    echo ""
    echo -e "${CYAN}当前状态:${NC}"
    if check_hysteria_installed; then
        echo -e "Hysteria2: ${GREEN}已安装${NC}"
        echo -n "服务状态: "
        check_service_status
        if [[ -f "$CONFIG_PATH" ]]; then
            echo -e "配置文件: ${GREEN}存在${NC}"
        else
            echo -e "配置文件: ${RED}不存在${NC}"
        fi
    else
        echo -e "Hysteria2: ${RED}未安装${NC}"
    fi
    echo ""
}

# 安装 Hysteria2
install_hysteria() {
    echo -e "${BLUE}正在安装 Hysteria2...${NC}"

    # 调试信息
    echo "调试信息:"
    echo "  脚本目录: $SCRIPT_DIR"
    echo "  功能脚本目录: $SCRIPTS_DIR"
    echo "  安装脚本路径: $SCRIPTS_DIR/install.sh"
    echo ""

    if [[ -f "$SCRIPTS_DIR/install.sh" ]]; then
        echo -e "${GREEN}找到安装脚本，正在执行...${NC}"
        source "$SCRIPTS_DIR/install.sh"
        install_hysteria2
    else
        echo -e "${RED}错误: 安装脚本不存在${NC}"
        echo ""
        echo "详细信息:"
        echo "  期望路径: $SCRIPTS_DIR/install.sh"
        echo "  实际情况: $(ls -la "$SCRIPTS_DIR/" 2>/dev/null || echo "目录不存在")"
        echo ""
        echo "可能的解决方案:"
        echo "1. 重新运行安装脚本"
        echo "2. 检查安装是否完整"
        echo "3. 手动下载缺失的脚本文件"
        echo ""
        read -p "按回车键继续..."
    fi
}

# 一键快速配置
quick_config() {
    echo -e "${BLUE}一键快速配置...${NC}"
    if [[ -f "$SCRIPTS_DIR/config.sh" ]]; then
        source "$SCRIPTS_DIR/config.sh"
        quick_setup_hysteria
    else
        echo -e "${RED}错误: 配置脚本不存在${NC}"
        read -p "按回车键继续..."
    fi
}

# 手动配置
manual_config() {
    echo -e "${BLUE}手动配置...${NC}"
    if [[ -f "$SCRIPTS_DIR/config.sh" ]]; then
        source "$SCRIPTS_DIR/config.sh"
        generate_hysteria_config
    else
        echo -e "${RED}错误: 配置脚本不存在${NC}"
        read -p "按回车键继续..."
    fi
}

# 管理服务
manage_service() {
    echo -e "${BLUE}服务管理...${NC}"
    if [[ -f "$SCRIPTS_DIR/service.sh" ]]; then
        source "$SCRIPTS_DIR/service.sh"
        manage_hysteria_service
    else
        echo -e "${RED}错误: 服务管理脚本不存在${NC}"
    fi
}

# 查看日志
view_logs() {
    echo -e "${BLUE}查看服务日志...${NC}"
    echo ""
    journalctl --no-pager -e -u $SERVICE_NAME
    echo ""
    read -p "按回车键继续..."
}

# 测试伪装域名
test_domains() {
    echo -e "${BLUE}测试伪装域名...${NC}"
    if [[ -f "$SCRIPTS_DIR/domain-test.sh" ]]; then
        source "$SCRIPTS_DIR/domain-test.sh"
        test_masquerade_domains
    else
        echo -e "${RED}错误: 域名测试脚本不存在${NC}"
    fi
}

# 服务器域名配置
server_domain_config() {
    echo -e "${BLUE}服务器域名配置${NC}"
    echo ""

    # 显示当前配置
    if [[ -f "$SERVER_DOMAIN_CONFIG" ]]; then
        local current_domain=$(cat "$SERVER_DOMAIN_CONFIG")
        echo -e "${YELLOW}当前配置域名: $current_domain${NC}"
    else
        echo -e "${YELLOW}当前未配置服务器域名${NC}"
    fi

    echo ""
    echo -e "${GREEN}1.${NC} 设置服务器域名"
    echo -e "${GREEN}2.${NC} 验证域名解析"
    echo -e "${GREEN}3.${NC} 删除域名配置"
    echo -e "${RED}0.${NC} 返回主菜单"
    echo ""
    echo -n -e "${BLUE}请选择操作 [0-3]: ${NC}"
    read -r choice

    case $choice in
        1)
            set_server_domain
            ;;
        2)
            verify_domain_resolution
            ;;
        3)
            remove_server_domain
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            sleep 1
            server_domain_config
            ;;
    esac
}

# 设置服务器域名
set_server_domain() {
    echo ""
    echo -e "${BLUE}设置服务器域名${NC}"
    echo ""
    echo "请输入解析到此服务器的域名 (例如: example.com):"
    echo -n -e "${YELLOW}域名: ${NC}"
    read -r domain

    if [[ -z "$domain" ]]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..."
        return
    fi

    # 简单的域名格式验证
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        echo -e "${RED}域名格式不正确${NC}"
        read -p "按回车键继续..."
        return
    fi

    # 保存域名配置
    echo "$domain" > "$SERVER_DOMAIN_CONFIG"
    echo -e "${GREEN}服务器域名已设置: $domain${NC}"

    # 询问是否立即验证
    echo ""
    echo -n -e "${YELLOW}是否立即验证域名解析? [Y/n]: ${NC}"
    read -r verify
    if [[ ! $verify =~ ^[Nn]$ ]]; then
        verify_domain_resolution
    fi

    read -p "按回车键继续..."
}

# 验证域名解析
verify_domain_resolution() {
    echo ""
    echo -e "${BLUE}验证域名解析${NC}"

    if [[ ! -f "$SERVER_DOMAIN_CONFIG" ]]; then
        echo -e "${RED}未配置服务器域名${NC}"
        read -p "按回车键继续..."
        return
    fi

    local domain=$(cat "$SERVER_DOMAIN_CONFIG")
    local server_ip=$(get_server_ip)

    echo "正在验证域名: $domain"
    echo "服务器IP: $server_ip"
    echo ""

    # 使用多种方法解析域名
    local resolved_ip=""

    # 方法1: 使用 dig
    if command -v dig &> /dev/null; then
        resolved_ip=$(dig +short "$domain" A | head -1)
    fi

    # 方法2: 使用 nslookup (备选)
    if [[ -z "$resolved_ip" ]] && command -v nslookup &> /dev/null; then
        resolved_ip=$(nslookup "$domain" | grep -A1 "Name:" | tail -1 | awk '{print $2}')
    fi

    # 方法3: 使用 host (备选)
    if [[ -z "$resolved_ip" ]] && command -v host &> /dev/null; then
        resolved_ip=$(host "$domain" | grep "has address" | awk '{print $4}' | head -1)
    fi

    if [[ -n "$resolved_ip" ]]; then
        echo "域名解析结果: $resolved_ip"

        if [[ "$resolved_ip" == "$server_ip" ]]; then
            echo -e "${GREEN}✅ 域名解析正确，指向当前服务器${NC}"
        else
            echo -e "${RED}❌ 域名解析错误${NC}"
            echo "域名指向: $resolved_ip"
            echo "服务器IP: $server_ip"
            echo ""
            echo "请检查域名DNS设置"
        fi
    else
        echo -e "${YELLOW}⚠️ 无法解析域名，可能原因:${NC}"
        echo "1. 域名DNS设置未生效"
        echo "2. 网络连接问题"
        echo "3. DNS服务器问题"
    fi

    read -p "按回车键继续..."
}

# 删除服务器域名配置
remove_server_domain() {
    echo ""
    echo -e "${YELLOW}删除服务器域名配置${NC}"

    if [[ ! -f "$SERVER_DOMAIN_CONFIG" ]]; then
        echo -e "${YELLOW}未配置服务器域名${NC}"
        read -p "按回车键继续..."
        return
    fi

    local domain=$(cat "$SERVER_DOMAIN_CONFIG")
    echo "当前配置域名: $domain"
    echo ""
    echo -n -e "${RED}确定要删除域名配置吗? [y/N]: ${NC}"
    read -r confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm -f "$SERVER_DOMAIN_CONFIG"
        echo -e "${GREEN}域名配置已删除${NC}"
    else
        echo -e "${BLUE}取消删除${NC}"
    fi

    read -p "按回车键继续..."
}

# 获取服务器IP
get_server_ip() {
    local ip=""

    # 尝试多种方法获取公网IP
    ip=$(curl -s --connect-timeout 5 ipv4.icanhazip.com 2>/dev/null) || \
    ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null) || \
    ip=$(curl -s --connect-timeout 5 ip.sb 2>/dev/null) || \
    ip=$(curl -s --connect-timeout 5 checkip.amazonaws.com 2>/dev/null)

    if [[ -n "$ip" && "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
    else
        # 如果无法获取公网IP，尝试获取本地IP
        ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')
        echo "${ip:-127.0.0.1}"
    fi
}

# 获取配置的服务器域名
get_server_domain() {
    if [[ -f "$SERVER_DOMAIN_CONFIG" ]]; then
        cat "$SERVER_DOMAIN_CONFIG"
    else
        echo ""
    fi
}

# 进阶配置
advanced_config() {
    echo -e "${BLUE}进阶配置...${NC}"
    if [[ -f "$SCRIPTS_DIR/advanced.sh" ]]; then
        source "$SCRIPTS_DIR/advanced.sh"
        advanced_configuration
    else
        echo -e "${RED}错误: 进阶配置脚本不存在${NC}"
        read -p "按回车键继续..."
    fi
}

# 节点信息
show_node_info() {
    echo -e "${BLUE}节点信息...${NC}"
    if [[ -f "$SCRIPTS_DIR/node-info.sh" ]]; then
        source "$SCRIPTS_DIR/node-info.sh"
        display_node_info
    else
        echo -e "${RED}错误: 节点信息脚本不存在${NC}"
        read -p "按回车键继续..."
    fi
}

# 故障排除
troubleshoot() {
    echo -e "${BLUE}故障排除...${NC}"
    if [[ -f "$SCRIPTS_DIR/troubleshoot.sh" ]]; then
        source "$SCRIPTS_DIR/troubleshoot.sh"
        run_diagnostics
    else
        echo -e "${RED}错误: 故障排除脚本不存在${NC}"
        read -p "按回车键继续..."
    fi
}

# 卸载服务
uninstall_hysteria() {
    echo -e "${YELLOW}Hysteria2 卸载选项:${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 仅卸载 Hysteria2 服务器 (保留配置文件)"
    echo -e "${GREEN}2.${NC} 卸载 Hysteria2 服务器及配置文件"
    echo -e "${GREEN}3.${NC} 卸载脚本及 Hysteria2 服务器和所有文件"
    echo -e "${RED}0.${NC} 取消"
    echo ""
    echo -e "${CYAN}说明:${NC}"
    echo "选项1: 只删除程序，保留配置和证书，便于重新安装"
    echo "选项2: 删除程序和配置，但保留管理脚本"
    echo "选项3: 完全删除所有相关文件，包括管理脚本"
    echo ""
    echo -n -e "${BLUE}请选择卸载方式 [0-3]: ${NC}"
    read -r uninstall_choice

    case $uninstall_choice in
        1)
            uninstall_server_only
            ;;
        2)
            uninstall_server_and_config
            ;;
        3)
            uninstall_everything
            ;;
        0)
            echo -e "${BLUE}取消卸载${NC}"
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac

    echo ""
    read -p "按回车键继续..."
}

# 方式1: 仅卸载 Hysteria2 服务器
uninstall_server_only() {
    echo -e "${BLUE}仅卸载 Hysteria2 服务器 (保留配置文件和证书)${NC}"
    echo ""

    if ! check_hysteria_installed; then
        echo -e "${YELLOW}Hysteria2 未安装${NC}"
        return
    fi

    echo -e "${YELLOW}此操作将:${NC}"
    echo "✓ 删除 Hysteria2 程序文件"
    echo "✓ 停止并删除系统服务"
    echo "✗ 保留配置文件和证书"
    echo "✗ 保留用户账户"
    echo "✗ 保留管理脚本"
    echo ""
    echo -e "${YELLOW}确定要卸载 Hysteria2 服务器吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi

    # 使用官方卸载脚本
    echo -e "${BLUE}正在卸载 Hysteria2 服务器...${NC}"
    if bash <(curl -fsSL https://get.hy2.sh/) --remove; then
        echo ""
        echo -e "${GREEN}Hysteria2 服务器卸载完成!${NC}"
        echo ""
        echo -e "${CYAN}已保留内容:${NC}"
        echo "• 配置文件: /etc/hysteria/"
        echo "• SSL 证书文件"
        echo "• hysteria 用户账户"
        echo "• 管理脚本: s-hy2"
        echo ""
        echo -e "${YELLOW}重新安装:${NC}"
        echo "运行 's-hy2' 选择 '1. 安装 Hysteria2' 即可重新安装"
        echo ""
    else
        echo -e "${RED}卸载失败${NC}"
    fi
}

# 方式2: 卸载 Hysteria2 服务器及配置文件
uninstall_server_and_config() {
    echo -e "${BLUE}卸载 Hysteria2 服务器及配置文件${NC}"
    echo ""

    if ! check_hysteria_installed; then
        echo -e "${YELLOW}Hysteria2 未安装${NC}"
        return
    fi

    echo -e "${YELLOW}此操作将:${NC}"
    echo "✓ 删除 Hysteria2 程序文件"
    echo "✓ 停止并删除系统服务"
    echo "✓ 删除配置文件和证书"
    echo "✓ 删除用户账户"
    echo "✓ 清理端口跳跃规则"
    echo "✗ 保留管理脚本"
    echo ""
    echo -e "${YELLOW}确定要卸载 Hysteria2 服务器及配置吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi

    # 1. 卸载程序
    echo -e "${BLUE}步骤 1/5: 卸载 Hysteria2 程序...${NC}"
    bash <(curl -fsSL https://get.hy2.sh/) --remove

    # 2. 删除配置文件和证书
    echo -e "${BLUE}步骤 2/5: 删除配置文件和证书...${NC}"
    if [[ -d "/etc/hysteria" ]]; then
        rm -rf /etc/hysteria
        echo "已删除 /etc/hysteria"
    fi

    # 3. 删除用户账户
    echo -e "${BLUE}步骤 3/5: 删除用户账户...${NC}"
    if id "hysteria" &>/dev/null; then
        userdel -r hysteria 2>/dev/null || userdel hysteria 2>/dev/null
        echo "已删除 hysteria 用户"
    fi

    # 4. 清理 systemd 服务残留
    echo -e "${BLUE}步骤 4/5: 清理 systemd 服务残留...${NC}"
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service
    systemctl daemon-reload
    echo "已清理 systemd 服务残留"

    # 5. 清理端口跳跃配置
    echo -e "${BLUE}步骤 5/5: 清理端口跳跃配置...${NC}"
    # 注意：这里配置文件已经被删除，所以无法读取配置
    echo "端口跳跃规则可能需要手动清理"

    echo ""
    echo -e "${GREEN}Hysteria2 服务器及配置文件卸载完成!${NC}"
    echo ""
    echo -e "${CYAN}已保留内容:${NC}"
    echo "• 管理脚本: s-hy2"
    echo ""
    echo -e "${YELLOW}重新安装:${NC}"
    echo "运行 's-hy2' 选择 '1. 安装 Hysteria2' 和 '2. 一键快速配置' 即可重新部署"
    echo ""
}

# 方式3: 卸载脚本及 Hysteria2 服务器和所有文件
uninstall_everything() {
    echo -e "${RED}卸载脚本及 Hysteria2 服务器和所有文件${NC}"
    echo ""

    echo -e "${RED}警告: 此操作将删除所有相关文件，包括:${NC}"
    echo "• Hysteria2 程序文件"
    echo "• 配置文件和证书"
    echo "• 用户账户"
    echo "• 系统服务"
    echo "• 管理脚本 (s-hy2)"
    echo "• 端口跳跃规则"
    echo ""
    echo -e "${YELLOW}确定要完全卸载所有内容吗? 请输入 'YES' 确认: ${NC}"
    read -r confirm
    if [[ "$confirm" != "YES" ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi

    # 1. 清理端口跳跃配置 (需要在删除配置文件前执行)
    echo -e "${BLUE}步骤 1/8: 清理端口跳跃配置...${NC}"
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        source "/etc/hysteria/port-hopping.conf" 2>/dev/null
        if [[ -n "$INTERFACE" && -n "$START_PORT" && -n "$END_PORT" && -n "$TARGET_PORT" ]]; then
            iptables -t nat -D PREROUTING -i "$INTERFACE" -p udp --dport "$START_PORT:$END_PORT" -j REDIRECT --to-ports "$TARGET_PORT" 2>/dev/null
            echo "已清理端口跳跃 iptables 规则"
        fi
    else
        echo "未找到端口跳跃配置"
    fi

    # 2. 卸载 Hysteria2 程序
    echo -e "${BLUE}步骤 2/8: 卸载 Hysteria2 程序...${NC}"
    if check_hysteria_installed; then
        bash <(curl -fsSL https://get.hy2.sh/) --remove
    else
        echo "Hysteria2 未安装"
    fi

    # 3. 删除配置文件和证书
    echo -e "${BLUE}步骤 3/8: 删除配置文件和证书...${NC}"
    if [[ -d "/etc/hysteria" ]]; then
        rm -rf /etc/hysteria
        echo "已删除 /etc/hysteria"
    fi

    # 4. 删除用户账户
    echo -e "${BLUE}步骤 4/8: 删除用户账户...${NC}"
    if id "hysteria" &>/dev/null; then
        userdel -r hysteria 2>/dev/null || userdel hysteria 2>/dev/null
        echo "已删除 hysteria 用户"
    fi

    # 5. 清理 systemd 服务残留
    echo -e "${BLUE}步骤 5/8: 清理 systemd 服务残留...${NC}"
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service
    systemctl daemon-reload
    echo "已清理 systemd 服务残留"

    # 6. 清理 iptables 规则残留
    echo -e "${BLUE}步骤 6/8: 清理 iptables 规则残留...${NC}"
    iptables -t nat -L PREROUTING --line-numbers | grep "REDIRECT.*443" | awk '{print $1}' | tac | while read line; do
        iptables -t nat -D PREROUTING $line 2>/dev/null
    done
    echo "已清理可能的 iptables 规则残留"

    # 7. 删除管理脚本符号链接
    echo -e "${BLUE}步骤 7/8: 删除管理脚本符号链接...${NC}"
    rm -f /usr/local/bin/hy2-manager
    rm -f /usr/local/bin/s-hy2
    echo "已删除命令快捷方式"

    # 8. 删除管理脚本安装目录
    echo -e "${BLUE}步骤 8/8: 删除管理脚本安装目录...${NC}"
    if [[ -d "/opt/s-hy2" ]]; then
        rm -rf /opt/s-hy2
        echo "已删除 /opt/s-hy2"
    fi

    # 删除桌面快捷方式
    if [[ -n "$SUDO_USER" ]]; then
        rm -f "/home/$SUDO_USER/Desktop/S-Hy2-Manager.desktop"
        echo "已删除桌面快捷方式"
    fi

    echo ""
    echo -e "${GREEN}所有文件卸载完成!${NC}"
    echo -e "${BLUE}系统已完全清理，感谢使用 S-Hy2 管理脚本${NC}"
    echo ""
    echo -e "${YELLOW}重新安装:${NC}"
    echo "curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash"
    echo ""
}

# 关于脚本
about_script() {
    echo -e "${CYAN}关于 Hysteria2 配置管理脚本${NC}"
    echo ""
    echo "版本: 1.0.0"
    echo "功能: 简化 Hysteria2 的安装、配置和管理"
    echo ""
    echo "支持的功能:"
    echo "- 一键安装/卸载"
    echo "- 交互式配置生成"
    echo "- 智能伪装域名选择"
    echo "- 服务管理"
    echo "- 进阶配置"
    echo ""
    read -p "按回车键继续..."
}

# 主循环
main() {
    check_root
    
    while true; do
        print_header
        show_status
        print_menu
        
        read -r choice
        
        case $choice in
            1)
                install_hysteria
                ;;
            2)
                quick_config
                ;;
            3)
                manual_config
                ;;
            4)
                manage_service
                ;;
            5)
                view_logs
                ;;
            6)
                test_domains
                ;;
            7)
                server_domain_config
                ;;
            8)
                advanced_config
                ;;
            9)
                show_node_info
                ;;
            10)
                uninstall_hysteria
                ;;
            11)
                about_script
                ;;
            0)
                echo -e "${GREEN}感谢使用 Hysteria2 配置管理脚本!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 运行主程序
main "$@"
