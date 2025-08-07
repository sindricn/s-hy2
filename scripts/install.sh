#!/bin/bash

# Hysteria2 安装脚本

# 安装 Hysteria2
install_hysteria2() {
    echo -e "${BLUE}开始安装 Hysteria2...${NC}"
    echo ""
    
    # 检查是否已安装
    if check_hysteria_installed; then
        echo -e "${YELLOW}Hysteria2 已经安装${NC}"
        echo -n -e "${BLUE}是否重新安装? [y/N]: ${NC}"
        read -r reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消安装${NC}"
            return
        fi
    fi
    
    # 检查网络连接
    echo -e "${BLUE}检查网络连接...${NC}"
    if ! ping -c 1 google.com &> /dev/null; then
        echo -e "${RED}网络连接失败，请检查网络设置${NC}"
        return
    fi
    
    # 更新系统包
    echo -e "${BLUE}更新系统包...${NC}"
    if command -v apt &> /dev/null; then
        apt update
    elif command -v yum &> /dev/null; then
        yum update -y
    elif command -v dnf &> /dev/null; then
        dnf update -y
    fi
    
    # 安装必要依赖
    echo -e "${BLUE}安装必要依赖...${NC}"
    if command -v apt &> /dev/null; then
        apt install -y curl wget openssl
    elif command -v yum &> /dev/null; then
        yum install -y curl wget openssl
    elif command -v dnf &> /dev/null; then
        dnf install -y curl wget openssl
    fi
    
    # 下载并安装 Hysteria2
    echo -e "${BLUE}下载并安装 Hysteria2...${NC}"
    if bash <(curl -fsSL https://get.hy2.sh/); then
        echo -e "${GREEN}Hysteria2 安装成功!${NC}"
        
        # 创建配置目录
        mkdir -p /etc/hysteria
        
        # 设置权限
        if id "hysteria" &>/dev/null; then
            chown hysteria:hysteria /etc/hysteria
        fi
        
        echo ""
        echo -e "${GREEN}安装完成!${NC}"
        echo -e "${YELLOW}下一步: 生成配置文件${NC}"
        
    else
        echo -e "${RED}Hysteria2 安装失败${NC}"
        echo "请检查网络连接或手动安装"
    fi
    
    echo ""
}

# 检查系统信息
check_system_info() {
    echo -e "${CYAN}系统信息:${NC}"
    echo "操作系统: $(uname -s)"
    echo "架构: $(uname -m)"
    echo "内核版本: $(uname -r)"
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "发行版: $PRETTY_NAME"
    fi
    
    echo ""
}

# 检查端口占用
check_port_usage() {
    local port=${1:-443}
    echo -e "${BLUE}检查端口 $port 占用情况...${NC}"
    
    if netstat -tuln | grep -q ":$port "; then
        echo -e "${YELLOW}警告: 端口 $port 已被占用${NC}"
        echo "占用进程:"
        netstat -tulnp | grep ":$port "
        echo ""
        echo -e "${YELLOW}建议在配置时使用其他端口${NC}"
    else
        echo -e "${GREEN}端口 $port 可用${NC}"
    fi
    echo ""
}

# 预安装检查
pre_install_check() {
    echo -e "${BLUE}执行预安装检查...${NC}"
    echo ""
    
    check_system_info
    check_port_usage 443
    
    # 检查防火墙状态
    echo -e "${BLUE}检查防火墙状态...${NC}"
    if command -v ufw &> /dev/null; then
        ufw_status=$(ufw status | head -1)
        echo "UFW: $ufw_status"
    elif command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --state &> /dev/null; then
            echo "Firewalld: 运行中"
        else
            echo "Firewalld: 未运行"
        fi
    elif command -v iptables &> /dev/null; then
        echo "iptables: 已安装"
    else
        echo "防火墙: 未检测到"
    fi
    
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo "1. 确保服务器可以访问互联网"
    echo "2. 如果使用 ACME 模式，需要域名解析到此服务器"
    echo "3. 确保防火墙允许相应端口通信"
    echo "4. 建议在安装前备份重要数据"
    echo ""
    
    echo -n -e "${BLUE}是否继续安装? [Y/n]: ${NC}"
    read -r continue_install
    if [[ $continue_install =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}取消安装${NC}"
        return 1
    fi
    
    return 0
}

# 卸载 Hysteria2 (仅程序)
uninstall_hysteria_program() {
    echo -e "${BLUE}卸载 Hysteria2 程序 (保留配置文件)...${NC}"
    echo ""

    if ! check_hysteria_installed; then
        echo -e "${YELLOW}Hysteria2 未安装${NC}"
        return
    fi

    echo -e "${YELLOW}此操作将卸载 Hysteria2 程序，但保留配置文件和证书${NC}"
    echo -n -e "${BLUE}确定要继续吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi

    # 使用官方卸载脚本
    if bash <(curl -fsSL https://get.hy2.sh/) --remove; then
        echo ""
        echo -e "${GREEN}Hysteria2 程序卸载完成!${NC}"
        echo ""
        echo -e "${CYAN}配置文件和证书已保留在 /etc/hysteria${NC}"
        echo ""
        echo -e "${YELLOW}如需完全清理，请手动执行以下命令:${NC}"
        echo ""
        echo -e "${BLUE}删除配置文件和证书:${NC}"
        echo "    rm -rf /etc/hysteria"
        echo ""
        echo -e "${BLUE}删除用户账户:${NC}"
        echo "    userdel -r hysteria"
        echo ""
        echo -e "${BLUE}清理 systemd 服务残留:${NC}"
        echo "    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service"
        echo "    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service"
        echo "    systemctl daemon-reload"
        echo ""
    else
        echo -e "${RED}卸载失败${NC}"
    fi
}

# 主安装函数
install_hysteria_main() {
    if pre_install_check; then
        install_hysteria2
    fi
}
