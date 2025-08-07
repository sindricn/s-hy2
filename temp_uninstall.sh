# 卸载服务
uninstall_hysteria() {
    clear
    echo -e "${CYAN}=== Hysteria2 卸载向导 ===${NC}"
    echo ""
    
    echo -e "${YELLOW}卸载选项:${NC}"
    echo -e "${GREEN}1.${NC} 卸载hy2及其相关配置文件"
    echo -e "${GREEN}2.${NC} 卸载删除所有脚本相关的程序和依赖和插件，但是保留脚本"
    echo -e "${GREEN}3.${NC} 完全卸载，删除所有程序，依赖插件和配置文件，包括脚本"
    echo -e "${RED}0.${NC} 取消"
    echo ""
    echo -e "${CYAN}说明:${NC}"
    echo "选项1: 卸载 Hysteria2 程序和配置文件"
    echo "选项2: 卸载所有相关依赖(包括订阅链接依赖)，保留管理脚本"
    echo "选项3: 完全清理所有内容，包括管理脚本本身"
    echo ""
    echo -n -e "${BLUE}请选择卸载方式 [0-3]: ${NC}"
    read -r uninstall_choice
    
    case $uninstall_choice in
        1) uninstall_hy2_and_config ;;
        2) uninstall_all_dependencies ;;
        3) uninstall_everything ;;
        0) 
            echo -e "${BLUE}取消卸载${NC}"
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
    wait_for_user
}

# 选项1: 卸载hy2及其相关配置文件
uninstall_hy2_and_config() {
    echo ""
    echo -e "${BLUE}卸载 Hysteria2 程序和配置文件${NC}"
    echo ""
    
    echo -e "${YELLOW}此操作将删除:${NC}"
    echo "• Hysteria2 程序文件"
    echo "• 系统服务"
    echo "• 配置文件和证书"
    echo "• 用户账户"
    echo "• 端口跳跃规则"
    echo ""
    echo -n -e "${YELLOW}确定要卸载吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi
    
    log_info "开始卸载 Hysteria2..."
    
    # 1. 清理端口跳跃规则
    log_info "步骤 1/5: 清理端口跳跃规则..."
    cleanup_port_hopping
    
    # 2. 停止并禁用服务
    log_info "步骤 2/5: 停止并禁用服务..."
    if systemctl is-active --quiet hysteria-server.service; then
        systemctl stop hysteria-server.service
        log_info "已停止服务"
    fi
    if systemctl is-enabled --quiet hysteria-server.service 2>/dev/null; then
        systemctl disable hysteria-server.service 2>/dev/null
        log_info "已禁用服务"
    fi
    
    # 3. 卸载 Hysteria2 程序
    log_info "步骤 3/5: 卸载 Hysteria2 程序..."
    if check_hysteria_installed; then
        if bash <(curl -fsSL https://get.hy2.sh/) --remove 2>/dev/null; then
            log_info "Hysteria2 程序卸载成功"
        else
            log_warn "程序卸载失败，继续清理"
        fi
    else
        log_info "Hysteria2 未安装，跳过程序卸载"
    fi
    
    # 4. 删除配置文件和证书
    log_info "步骤 4/5: 删除配置文件和证书..."
    if [[ -d "/etc/hysteria" ]]; then
        rm -rf /etc/hysteria
        log_info "已删除 /etc/hysteria 目录"
    fi
    
    # 5. 清理用户账户和系统残留
    log_info "步骤 5/5: 清理用户账户和系统残留..."
    if id "hysteria" &>/dev/null; then
        userdel -r hysteria 2>/dev/null && log_info "已删除 hysteria 用户"
    fi
    
    # 清理 systemd 残留文件
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service 2>/dev/null
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service 2>/dev/null
    systemctl daemon-reload
    
    echo ""
    log_success "Hysteria2 程序和配置文件卸载完成!"
}

# 选项2: 卸载删除所有脚本相关的程序和依赖和插件，但是保留脚本
uninstall_all_dependencies() {
    echo ""
    echo -e "${BLUE}卸载所有依赖和插件 (保留管理脚本)${NC}"
    echo ""
    
    echo -e "${YELLOW}此操作将删除:${NC}"
    echo "• Hysteria2 程序和配置"
    echo "• nginx (订阅链接依赖)"
    echo "• 订阅文件 (/var/www/html/sub/)"
    echo "• 端口跳跃规则"
    echo "• 系统用户账户"
    echo ""
    echo -e "${GREEN}保留内容:${NC}"
    echo "• 管理脚本 (s-hy2)"
    echo ""
    echo -n -e "${YELLOW}确定要卸载所有依赖吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi
    
    log_info "开始卸载所有依赖..."
    
    # 1. 先执行基本的 hy2 卸载
    log_info "步骤 1/4: 卸载 Hysteria2..."
    # 清理端口跳跃规则
    cleanup_port_hopping
    
    # 停止并禁用服务
    if systemctl is-active --quiet hysteria-server.service; then
        systemctl stop hysteria-server.service
    fi
    if systemctl is-enabled --quiet hysteria-server.service 2>/dev/null; then
        systemctl disable hysteria-server.service 2>/dev/null
    fi
    
    # 卸载程序
    if check_hysteria_installed; then
        bash <(curl -fsSL https://get.hy2.sh/) --remove 2>/dev/null || log_warn "程序卸载失败"
    fi
    
    # 删除配置
    rm -rf /etc/hysteria 2>/dev/null
    
    # 删除用户
    if id "hysteria" &>/dev/null; then
        userdel -r hysteria 2>/dev/null
    fi
    
    # 2. 卸载 nginx (订阅链接依赖)
    log_info "步骤 2/4: 卸载 nginx..."
    if command -v nginx &>/dev/null; then
        systemctl stop nginx 2>/dev/null
        systemctl disable nginx 2>/dev/null
        
        if command -v apt &>/dev/null; then
            apt remove -y nginx nginx-common nginx-core 2>/dev/null
            apt autoremove -y 2>/dev/null
        elif command -v yum &>/dev/null; then
            yum remove -y nginx 2>/dev/null
        elif command -v dnf &>/dev/null; then
            dnf remove -y nginx 2>/dev/null
        fi
        log_info "已卸载 nginx"
    else
        log_info "nginx 未安装，跳过"
    fi
    
    # 3. 删除订阅文件
    log_info "步骤 3/4: 删除订阅文件..."
    if [[ -d "/var/www/html/sub" ]]; then
        rm -rf /var/www/html/sub
        log_info "已删除订阅文件目录"
    fi
    
    # 清理可能的web根目录 (如果为空)
    if [[ -d "/var/www/html" && -z "$(ls -A /var/www/html 2>/dev/null)" ]]; then
        rmdir /var/www/html 2>/dev/null
    fi
    if [[ -d "/var/www" && -z "$(ls -A /var/www 2>/dev/null)" ]]; then
        rmdir /var/www 2>/dev/null
    fi
    
    # 4. 清理系统残留
    log_info "步骤 4/4: 清理系统残留..."
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service 2>/dev/null
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service 2>/dev/null
    systemctl daemon-reload
    
    echo ""
    log_success "所有依赖和插件卸载完成!"
    echo ""
    echo -e "${GREEN}管理脚本已保留，可以使用 's-hy2' 重新安装${NC}"
}

# 选项3: 完全卸载，删除所有程序，依赖插件和配置文件，包括脚本
uninstall_everything() {
    echo ""
    echo -e "${RED}完全卸载 - 删除所有内容${NC}"
    echo ""
    
    echo -e "${RED}警告: 此操作将删除:${NC}"
    echo "• Hysteria2 程序和配置"
    echo "• nginx 及订阅文件"
    echo "• 管理脚本 (s-hy2)"
    echo "• 所有相关目录和文件"
    echo "• 端口跳跃规则"
    echo "• 系统用户账户"
    echo ""
    echo -e "${YELLOW}此操作不可逆！请输入 'YES' 确认完全卸载: ${NC}"
    read -r confirm
    if [[ "$confirm" != "YES" ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi
    
    log_info "开始完全卸载..."
    
    # 1. 清理端口跳跃配置
    log_info "步骤 1/7: 清理端口跳跃配置..."
    cleanup_port_hopping
    
    # 2. 停止并禁用服务
    log_info "步骤 2/7: 停止并禁用服务..."
    if systemctl is-active --quiet hysteria-server.service; then
        systemctl stop hysteria-server.service
    fi
    if systemctl is-enabled --quiet hysteria-server.service 2>/dev/null; then
        systemctl disable hysteria-server.service 2>/dev/null
    fi
    
    # 3. 卸载 Hysteria2 程序
    log_info "步骤 3/7: 卸载 Hysteria2 程序..."
    if check_hysteria_installed; then
        bash <(curl -fsSL https://get.hy2.sh/) --remove 2>/dev/null || log_warn "程序卸载失败，继续清理"
    fi
    
    # 4. 卸载 nginx 和清理订阅文件
    log_info "步骤 4/7: 卸载 nginx 和清理订阅文件..."
    if command -v nginx &>/dev/null; then
        systemctl stop nginx 2>/dev/null
        systemctl disable nginx 2>/dev/null
        
        if command -v apt &>/dev/null; then
            apt remove -y nginx nginx-common nginx-core 2>/dev/null
            apt autoremove -y 2>/dev/null
        elif command -v yum &>/dev/null; then
            yum remove -y nginx 2>/dev/null
        elif command -v dnf &>/dev/null; then
            dnf remove -y nginx 2>/dev/null
        fi
    fi
    
    # 删除web目录
    rm -rf /var/www 2>/dev/null
    
    # 5. 删除配置文件和证书
    log_info "步骤 5/7: 删除配置文件和证书..."
    rm -rf /etc/hysteria 2>/dev/null
    
    # 6. 清理系统残留
    log_info "步骤 6/7: 清理系统残留..."
    if id "hysteria" &>/dev/null; then
        userdel -r hysteria 2>/dev/null
    fi
    
    # 清理 iptables 规则残留
    iptables -t nat -L PREROUTING --line-numbers 2>/dev/null | grep "REDIRECT.*443" | awk '{print $1}' | tac | while read -r line; do
        iptables -t nat -D PREROUTING "$line" 2>/dev/null
    done
    
    # 清理 systemd 残留
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service 2>/dev/null
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service 2>/dev/null
    systemctl daemon-reload
    
    # 7. 删除管理脚本
    log_info "步骤 7/7: 删除管理脚本..."
    rm -f /usr/local/bin/hy2-manager 2>/dev/null
    rm -f /usr/local/bin/s-hy2 2>/dev/null
    
    # 删除安装目录
    if [[ -d "/opt/s-hy2" ]]; then
        rm -rf /opt/s-hy2
    fi
    
    # 删除桌面快捷方式
    if [[ -n "$SUDO_USER" ]]; then
        rm -f "/home/$SUDO_USER/Desktop/S-Hy2-Manager.desktop" 2>/dev/null
    fi
    
    echo ""
    log_success "完全卸载完成!"
    echo -e "${BLUE}系统已完全清理，感谢使用 S-Hy2 管理脚本${NC}"
    echo ""
    echo -e "${YELLOW}重新安装:${NC}"
    echo "curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash"
    echo ""
    
    # 由于脚本本身已被删除，这里直接退出
    exit 0
}

# 清理端口跳跃配置
cleanup_port_hopping() {
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        # shellcheck source=/dev/null
        source "/etc/hysteria/port-hopping.conf" 2>/dev/null
        if [[ -n "$INTERFACE" && -n "$START_PORT" && -n "$END_PORT" && -n "$TARGET_PORT" ]]; then
            iptables -t nat -D PREROUTING -i "$INTERFACE" -p udp --dport "$START_PORT:$END_PORT" -j REDIRECT --to-ports "$TARGET_PORT" 2>/dev/null
            log_info "已清理端口跳跃规则"
        fi
    fi
    
    # 清理其他可能的端口跳跃规则
    local rules_cleared=0
    while IFS= read -r line_num; do
        if [[ -n "$line_num" ]]; then
            if iptables -t nat -D PREROUTING "$line_num" 2>/dev/null; then
                ((rules_cleared++))
            fi
        fi
    done < <(iptables -t nat -L PREROUTING --line-numbers 2>/dev/null | grep "REDIRECT.*443" | awk '{print $1}' | tac)
    
    if [[ $rules_cleared -gt 0 ]]; then
        log_info "清理了 $rules_cleared 条端口跳跃规则"
    fi
    
    # 删除配置文件
    rm -f "/etc/hysteria/port-hopping.conf" 2>/dev/null
}