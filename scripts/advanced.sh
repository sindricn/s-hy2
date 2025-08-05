#!/bin/bash

# Hysteria2 进阶配置脚本

# 修改监听端口
modify_listen_port() {
    echo -e "${BLUE}修改监听端口${NC}"
    echo ""
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        return 1
    fi
    
    # 显示当前端口
    local current_port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://')
    if [[ -z "$current_port" ]]; then
        current_port="443"
        echo -e "${YELLOW}当前端口: 443 (默认)${NC}"
    else
        echo -e "${YELLOW}当前端口: $current_port${NC}"
    fi
    
    # 输入新端口
    while true; do
        echo -n -e "${BLUE}请输入新端口 (1-65535): ${NC}"
        read -r new_port
        
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ $new_port -ge 1 ]] && [[ $new_port -le 65535 ]]; then
            break
        else
            echo -e "${RED}端口格式无效，请输入 1-65535 之间的数字${NC}"
        fi
    done
    
    # 检查端口占用
    if netstat -tuln | grep -q ":$new_port "; then
        echo -e "${YELLOW}警告: 端口 $new_port 已被占用${NC}"
        echo -n -e "${BLUE}是否继续? [y/N]: ${NC}"
        read -r continue_change
        if [[ ! $continue_change =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消端口修改${NC}"
            return
        fi
    fi
    
    # 备份配置文件
    cp "$CONFIG_PATH" "$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 修改配置文件
    if grep -q "^listen:" "$CONFIG_PATH"; then
        sed -i "s/^listen:.*/listen: :$new_port/" "$CONFIG_PATH"
    else
        sed -i "1i listen: :$new_port" "$CONFIG_PATH"
    fi
    
    echo -e "${GREEN}端口已修改为: $new_port${NC}"
    
    # 询问是否重启服务
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -n -e "${BLUE}是否重启服务以应用新端口? [y/N]: ${NC}"
        read -r restart_service
        if [[ $restart_service =~ ^[Yy]$ ]]; then
            systemctl restart $SERVICE_NAME
            echo -e "${GREEN}服务已重启${NC}"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}注意: 请确保防火墙允许新端口通信${NC}"
}

# 添加混淆配置
add_obfuscation() {
    echo -e "${BLUE}添加混淆配置${NC}"
    echo ""
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        return 1
    fi
    
    # 检查是否已有混淆配置
    if grep -q "^obfs:" "$CONFIG_PATH"; then
        echo -e "${YELLOW}检测到现有混淆配置${NC}"
        echo -n -e "${BLUE}是否覆盖现有配置? [y/N]: ${NC}"
        read -r overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消混淆配置${NC}"
            return
        fi
    fi
    
    # 输入混淆密码
    echo -n -e "${BLUE}请输入混淆密码 (留空自动生成): ${NC}"
    read -r obfs_password
    if [[ -z "$obfs_password" ]]; then
        obfs_password=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
        echo -e "${GREEN}自动生成混淆密码: $obfs_password${NC}"
    fi
    
    # 备份配置文件
    cp "$CONFIG_PATH" "$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 删除现有混淆配置
    sed -i '/^obfs:/,/^[a-zA-Z]/{ /^[a-zA-Z]/!d; }' "$CONFIG_PATH"
    sed -i '/^obfs:/d' "$CONFIG_PATH"
    
    # 添加混淆配置
    cat >> "$CONFIG_PATH" << EOF

obfs:
  type: salamander
  salamander:
    password: $obfs_password
EOF
    
    echo -e "${GREEN}混淆配置已添加${NC}"
    echo -e "${YELLOW}混淆密码: $obfs_password${NC}"
    
    # 询问是否重启服务
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -n -e "${BLUE}是否重启服务以应用混淆配置? [y/N]: ${NC}"
        read -r restart_service
        if [[ $restart_service =~ ^[Yy]$ ]]; then
            systemctl restart $SERVICE_NAME
            echo -e "${GREEN}服务已重启${NC}"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}注意: 客户端也需要配置相同的混淆密码${NC}"
}

# 移除混淆配置
remove_obfuscation() {
    echo -e "${BLUE}移除混淆配置${NC}"
    echo ""
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        return 1
    fi
    
    if ! grep -q "^obfs:" "$CONFIG_PATH"; then
        echo -e "${YELLOW}未找到混淆配置${NC}"
        return
    fi
    
    echo -n -e "${BLUE}确定要移除混淆配置吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消移除${NC}"
        return
    fi
    
    # 备份配置文件
    cp "$CONFIG_PATH" "$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 删除混淆配置
    sed -i '/^obfs:/,/^[a-zA-Z]/{ /^[a-zA-Z]/!d; }' "$CONFIG_PATH"
    sed -i '/^obfs:/d' "$CONFIG_PATH"
    
    echo -e "${GREEN}混淆配置已移除${NC}"
    
    # 询问是否重启服务
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -n -e "${BLUE}是否重启服务以应用更改? [y/N]: ${NC}"
        read -r restart_service
        if [[ $restart_service =~ ^[Yy]$ ]]; then
            systemctl restart $SERVICE_NAME
            echo -e "${GREEN}服务已重启${NC}"
        fi
    fi
}

# 配置端口跳跃
configure_port_hopping() {
    echo -e "${BLUE}配置端口跳跃${NC}"
    echo ""
    
    # 获取网卡信息
    echo -e "${BLUE}检测网络接口...${NC}"
    local interfaces=($(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo))
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        echo -e "${RED}未找到可用的网络接口${NC}"
        return 1
    fi
    
    echo -e "${BLUE}可用的网络接口:${NC}"
    for i in "${!interfaces[@]}"; do
        echo "$((i+1)). ${interfaces[$i]}"
    done
    
    echo -n -e "${BLUE}请选择网络接口 [1-${#interfaces[@]}]: ${NC}"
    read -r interface_choice
    
    if [[ ! "$interface_choice" =~ ^[0-9]+$ ]] || [[ $interface_choice -lt 1 ]] || [[ $interface_choice -gt ${#interfaces[@]} ]]; then
        echo -e "${RED}无效选择${NC}"
        return 1
    fi
    
    local selected_interface="${interfaces[$((interface_choice-1))]}"
    
    # 输入端口范围
    echo -n -e "${BLUE}请输入起始端口 (建议 20000): ${NC}"
    read -r start_port
    echo -n -e "${BLUE}请输入结束端口 (建议 50000): ${NC}"
    read -r end_port
    
    if [[ ! "$start_port" =~ ^[0-9]+$ ]] || [[ ! "$end_port" =~ ^[0-9]+$ ]] || [[ $start_port -ge $end_port ]]; then
        echo -e "${RED}端口范围无效${NC}"
        return 1
    fi
    
    # 获取目标端口
    local target_port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://')
    if [[ -z "$target_port" ]]; then
        target_port="443"
    fi
    
    # 生成 iptables 规则
    local iptables_rule="iptables -t nat -A PREROUTING -i $selected_interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port"
    
    echo ""
    echo -e "${YELLOW}将要执行的 iptables 规则:${NC}"
    echo "$iptables_rule"
    echo ""
    echo -e "${YELLOW}配置信息:${NC}"
    echo "网络接口: $selected_interface"
    echo "端口范围: $start_port-$end_port"
    echo "目标端口: $target_port"
    echo ""
    
    echo -n -e "${BLUE}是否执行此规则? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消端口跳跃配置${NC}"
        return
    fi
    
    # 执行 iptables 规则
    if eval "$iptables_rule"; then
        echo -e "${GREEN}端口跳跃规则已添加${NC}"
        
        # 保存 iptables 规则
        echo -n -e "${BLUE}是否保存 iptables 规则以便重启后生效? [y/N]: ${NC}"
        read -r save_rules
        if [[ $save_rules =~ ^[Yy]$ ]]; then
            if command -v iptables-save &> /dev/null; then
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules 2>/dev/null
                echo -e "${GREEN}iptables 规则已保存${NC}"
            else
                echo -e "${YELLOW}无法自动保存规则，请手动保存${NC}"
            fi
        fi
        
        # 保存配置信息
        cat > "/etc/hysteria/port-hopping.conf" << EOF
# 端口跳跃配置
# 生成时间: $(date)
INTERFACE=$selected_interface
START_PORT=$start_port
END_PORT=$end_port
TARGET_PORT=$target_port
IPTABLES_RULE="$iptables_rule"
EOF
        
        echo -e "${GREEN}端口跳跃配置已保存到 /etc/hysteria/port-hopping.conf${NC}"
        
    else
        echo -e "${RED}端口跳跃规则添加失败${NC}"
    fi
}

# 移除端口跳跃
remove_port_hopping() {
    echo -e "${BLUE}移除端口跳跃配置${NC}"
    echo ""
    
    if [[ ! -f "/etc/hysteria/port-hopping.conf" ]]; then
        echo -e "${YELLOW}未找到端口跳跃配置文件${NC}"
        echo -e "${BLUE}手动查找相关 iptables 规则...${NC}"
        
        local hysteria_rules=$(iptables -t nat -L PREROUTING --line-numbers | grep "REDIRECT.*hysteria\|REDIRECT.*443")
        if [[ -n "$hysteria_rules" ]]; then
            echo -e "${YELLOW}找到可能相关的规则:${NC}"
            echo "$hysteria_rules"
        else
            echo -e "${YELLOW}未找到相关的 iptables 规则${NC}"
        fi
        return
    fi
    
    # 读取配置
    source "/etc/hysteria/port-hopping.conf"
    
    echo -e "${YELLOW}当前端口跳跃配置:${NC}"
    echo "网络接口: $INTERFACE"
    echo "端口范围: $START_PORT-$END_PORT"
    echo "目标端口: $TARGET_PORT"
    echo ""
    
    echo -n -e "${BLUE}确定要移除端口跳跃配置吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消移除${NC}"
        return
    fi
    
    # 删除 iptables 规则
    local remove_rule="iptables -t nat -D PREROUTING -i $INTERFACE -p udp --dport $START_PORT:$END_PORT -j REDIRECT --to-ports $TARGET_PORT"
    
    if eval "$remove_rule" 2>/dev/null; then
        echo -e "${GREEN}端口跳跃规则已移除${NC}"
    else
        echo -e "${YELLOW}规则可能已经不存在或移除失败${NC}"
    fi
    
    # 删除配置文件
    rm -f "/etc/hysteria/port-hopping.conf"
    echo -e "${GREEN}端口跳跃配置文件已删除${NC}"
}

# 查看当前进阶配置
view_advanced_config() {
    echo -e "${CYAN}当前进阶配置状态:${NC}"
    echo ""
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        return 1
    fi
    
    # 监听端口
    local port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://')
    if [[ -z "$port" ]]; then
        echo -e "${BLUE}监听端口:${NC} 443 (默认)"
    else
        echo -e "${BLUE}监听端口:${NC} $port"
    fi
    
    # 混淆配置
    if grep -q "^obfs:" "$CONFIG_PATH"; then
        echo -e "${BLUE}混淆配置:${NC} ${GREEN}已启用${NC}"
        local obfs_password=$(grep -A 3 "^obfs:" "$CONFIG_PATH" | grep "password:" | awk '{print $2}')
        if [[ -n "$obfs_password" ]]; then
            echo -e "${BLUE}混淆密码:${NC} $obfs_password"
        fi
    else
        echo -e "${BLUE}混淆配置:${NC} ${RED}未启用${NC}"
    fi
    
    # 端口跳跃
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        echo -e "${BLUE}端口跳跃:${NC} ${GREEN}已配置${NC}"
        source "/etc/hysteria/port-hopping.conf"
        echo -e "${BLUE}跳跃范围:${NC} $START_PORT-$END_PORT"
        echo -e "${BLUE}网络接口:${NC} $INTERFACE"
    else
        echo -e "${BLUE}端口跳跃:${NC} ${RED}未配置${NC}"
    fi
    
    echo ""
}

# 主进阶配置函数
advanced_configuration() {
    while true; do
        echo -e "${BLUE}Hysteria2 进阶配置${NC}"
        echo ""
        
        view_advanced_config
        
        echo -e "${YELLOW}配置选项:${NC}"
        echo -e "${GREEN}1.${NC} 修改监听端口"
        echo -e "${GREEN}2.${NC} 添加混淆配置"
        echo -e "${GREEN}3.${NC} 移除混淆配置"
        echo -e "${GREEN}4.${NC} 配置端口跳跃"
        echo -e "${GREEN}5.${NC} 移除端口跳跃"
        echo -e "${GREEN}6.${NC} 查看配置状态"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-6]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                modify_listen_port
                echo ""
                read -p "按回车键继续..."
                ;;
            2)
                add_obfuscation
                echo ""
                read -p "按回车键继续..."
                ;;
            3)
                remove_obfuscation
                echo ""
                read -p "按回车键继续..."
                ;;
            4)
                configure_port_hopping
                echo ""
                read -p "按回车键继续..."
                ;;
            5)
                remove_port_hopping
                echo ""
                read -p "按回车键继续..."
                ;;
            6)
                view_advanced_config
                echo ""
                read -p "按回车键继续..."
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选项${NC}"
                sleep 1
                ;;
        esac
    done
}
