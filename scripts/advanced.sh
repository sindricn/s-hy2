#!/bin/bash

# Hysteria2 进阶配置脚本 - 优化版本

# 安全检查函数
security_check() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
        return 1
    fi
    
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
        
        # 检查端口状态
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "  状态: ${GREEN}正在监听${NC}"
        else
            echo -e "  状态: ${RED}未监听${NC}"
        fi
    fi
    
    # 混淆配置
    if grep -q "^obfs:" "$CONFIG_PATH"; then
        echo -e "${BLUE}混淆配置:${NC} ${GREEN}已启用${NC}"
        local obfs_type=$(grep -A 3 "^obfs:" "$CONFIG_PATH" | grep "type:" | awk '{print $2}')
        local obfs_password=$(grep -A 5 "^obfs:" "$CONFIG_PATH" | grep "password:" | awk '{print $2}')
        if [[ -n "$obfs_type" ]]; then
            echo -e "  算法: $obfs_type"
        fi
        if [[ -n "$obfs_password" ]]; then
            echo -e "  密码: $obfs_password"
        fi
        
        # 检查混淆信息文件
        if [[ -f "/etc/hysteria/obfs-info.conf" ]]; then
            echo -e "  配置文件: ${GREEN}存在${NC}"
        fi
    else
        echo -e "${BLUE}混淆配置:${NC} ${RED}未启用${NC}"
    fi
    
    # 端口跳跃
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        echo -e "${BLUE}端口跳跃:${NC} ${GREEN}已配置${NC}"
        source "/etc/hysteria/port-hopping.conf"
        echo -e "  跳跃范围: $START_PORT-$END_PORT"
        echo -e "  网络接口: $INTERFACE"
        echo -e "  端口数量: $((END_PORT - START_PORT + 1))"
        
        # 检查 iptables 规则是否存在
        if iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q "$START_PORT:$END_PORT"; then
            echo -e "  规则状态: ${GREEN}已生效${NC}"
        else
            echo -e "  规则状态: ${RED}未生效${NC}"
        fi
    else
        echo -e "${BLUE}端口跳跃:${NC} ${RED}未配置${NC}"
    fi
    
    # 配置文件信息
    echo ""
    echo -e "${BLUE}配置文件信息:${NC}"
    echo "  路径: $CONFIG_PATH"
    echo "  大小: $(du -h "$CONFIG_PATH" | cut -f1)"
    echo "  权限: $(stat -c %a "$CONFIG_PATH" 2>/dev/null || stat -f %Lp "$CONFIG_PATH" 2>/dev/null)"
    echo "  修改: $(stat -c %y "$CONFIG_PATH" 2>/dev/null | cut -d. -f1 || stat -f %Sm "$CONFIG_PATH" 2>/dev/null)"
    
    # 备份文件统计
    local backup_count=$(ls "$CONFIG_PATH".backup.* 2>/dev/null | wc -l)
    if [[ $backup_count -gt 0 ]]; then
        echo -e "  备份: ${GREEN}$backup_count 个备份文件${NC}"
        
        # 显示最新备份
        local latest_backup=$(ls -t "$CONFIG_PATH".backup.* 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            echo "  最新备份: $(basename "$latest_backup")"
        fi
    else
        echo -e "  备份: ${YELLOW}无备份文件${NC}"
    fi
    
    echo ""
}

# 配置健康检查（新增功能）
health_check() {
    echo -e "${BLUE}配置健康检查${NC}"
    echo ""
    
    local issues=0
    local warnings=0
    
    # 检查配置文件存在性
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}✗ 配置文件不存在${NC}"
        ((issues++))
        return
    else
        echo -e "${GREEN}✓ 配置文件存在${NC}"
    fi
    
    # 检查配置文件权限
    local perms=$(stat -c %a "$CONFIG_PATH" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        echo -e "${GREEN}✓ 配置文件权限正确 ($perms)${NC}"
    else
        echo -e "${YELLOW}⚠ 配置文件权限: $perms (建议: 600)${NC}"
        ((warnings++))
    fi
    
    # 检查配置语法
    if command -v hysteria >/dev/null && hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
        echo -e "${GREEN}✓ 配置文件语法正确${NC}"
    else
        echo -e "${RED}✗ 配置文件语法错误${NC}"
        ((issues++))
    fi
    
    # 检查端口配置
    local port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://')
    if [[ -n "$port" ]]; then
        if validate_port "$port" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 端口配置有效: $port${NC}"
            
            # 检查端口占用
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                if pgrep -f hysteria >/dev/null; then
                    echo -e "${GREEN}✓ 端口 $port 被 Hysteria 占用${NC}"
                else
                    echo -e "${YELLOW}⚠ 端口 $port 被其他程序占用${NC}"
                    ((warnings++))
                fi
            else
                echo -e "${YELLOW}⚠ 端口 $port 未被占用${NC}"
                ((warnings++))
            fi
        else
            echo -e "${RED}✗ 端口配置无效: $port${NC}"
            ((issues++))
        fi
    else
        echo -e "${YELLOW}⚠ 使用默认端口 443${NC}"
        ((warnings++))
    fi
    
    # 检查证书配置
    if grep -q "^acme:" "$CONFIG_PATH"; then
        echo -e "${GREEN}✓ ACME 证书配置已启用${NC}"
        local domain=$(grep -A 5 "^acme:" "$CONFIG_PATH" | grep -E "^\s*-" | head -1 | awk '{print $2}')
        if [[ -n "$domain" ]]; then
            echo -e "  域名: $domain"
        fi
    elif grep -q "^tls:" "$CONFIG_PATH"; then
        echo -e "${GREEN}✓ TLS 证书配置已启用${NC}"
        local cert_path=$(grep -A 3 "^tls:" "$CONFIG_PATH" | grep "cert:" | awk '{print $2}')
        local key_path=$(grep -A 3 "^tls:" "$CONFIG_PATH" | grep "key:" | awk '{print $2}')
        
        if [[ -f "$cert_path" ]]; then
            echo -e "${GREEN}✓ 证书文件存在${NC}"
        else
            echo -e "${RED}✗ 证书文件不存在: $cert_path${NC}"
            ((issues++))
        fi
        
        if [[ -f "$key_path" ]]; then
            echo -e "${GREEN}✓ 私钥文件存在${NC}"
        else
            echo -e "${RED}✗ 私钥文件不存在: $key_path${NC}"
            ((issues++))
        fi
    else
        echo -e "${YELLOW}⚠ 未配置证书${NC}"
        ((warnings++))
    fi
    
    # 检查认证配置
    if grep -q "^auth:" "$CONFIG_PATH"; then
        echo -e "${GREEN}✓ 认证配置已启用${NC}"
        local auth_type=$(grep -A 2 "^auth:" "$CONFIG_PATH" | grep "type:" | awk '{print $2}')
        echo -e "  认证类型: ${auth_type:-未知}"
    else
        echo -e "${RED}✗ 未配置认证${NC}"
        ((issues++))
    fi
    
    # 检查混淆配置
    if grep -q "^obfs:" "$CONFIG_PATH"; then
        echo -e "${GREEN}✓ 混淆配置已启用${NC}"
    else
        echo -e "${BLUE}ℹ 混淆配置未启用 (可选)${NC}"
    fi
    
    # 检查端口跳跃
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        echo -e "${GREEN}✓ 端口跳跃配置存在${NC}"
        source "/etc/hysteria/port-hopping.conf"
        
        if iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q "$START_PORT:$END_PORT"; then
            echo -e "${GREEN}✓ 端口跳跃规则已生效${NC}"
        else
            echo -e "${YELLOW}⚠ 端口跳跃规则未生效${NC}"
            ((warnings++))
        fi
    else
        echo -e "${BLUE}ℹ 端口跳跃未配置 (可选)${NC}"
    fi
    
    # 总结
    echo ""
    echo -e "${CYAN}健康检查总结:${NC}"
    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}✓ 配置健康，发现 $warnings 个警告${NC}"
    else
        echo -e "${RED}✗ 发现 $issues 个问题和 $warnings 个警告${NC}"
        echo -e "${YELLOW}建议修复问题后重新检查${NC}"
    fi
    
    return $issues
}

# 配置备份管理（新增功能）
manage_config_backups() {
    echo -e "${BLUE}配置备份管理${NC}"
    echo ""
    
    local backups=($(ls "$CONFIG_PATH".backup.* 2>/dev/null | sort -r))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${YELLOW}没有找到配置备份文件${NC}"
        echo ""
        echo -n -e "${BLUE}是否立即创建备份? [y/N]: ${NC}"
        read -r create_backup
        if [[ $create_backup =~ ^[Yy]$ ]]; then
            backup_config_with_checksum "$CONFIG_PATH"
        fi
        return
    fi
    
    echo -e "${GREEN}找到 ${#backups[@]} 个备份文件:${NC}"
    echo ""
    printf "%-5s %-25s %-12s %s\n" "编号" "文件名" "大小" "修改时间"
    echo "---------------------------------------------------------------"
    
    for i in "${!backups[@]}"; do
        local backup="${backups[$i]}"
        local size=$(du -h "$backup" 2>/dev/null | cut -f1)
        local mtime=$(stat -c %y "$backup" 2>/dev/null | cut -d. -f1 || stat -f %Sm "$backup" 2>/dev/null)
        local basename_backup=$(basename "$backup")
        printf "%-5d %-25s %-12s %s\n" $((i+1)) "${basename_backup}" "$size" "$mtime"
    done
    
    echo ""
    echo -e "${GREEN}1.${NC} 恢复备份"
    echo -e "${GREEN}2.${NC} 删除备份"
    echo -e "${GREEN}3.${NC} 创建新备份"
    echo -e "${GREEN}4.${NC} 查看备份内容"
    echo -e "${GREEN}5.${NC} 清理旧备份"
    echo -e "${RED}0.${NC} 返回"
    echo ""
    echo -n -e "${BLUE}请选择操作 [0-5]: ${NC}"
    read -r backup_choice
    
    case $backup_choice in
        1)
            echo -n -e "${BLUE}请选择要恢复的备份编号 [1-${#backups[@]}]: ${NC}"
            read -r restore_choice
            if [[ "$restore_choice" =~ ^[0-9]+$ ]] && [[ $restore_choice -ge 1 ]] && [[ $restore_choice -le ${#backups[@]} ]]; then
                local selected_backup="${backups[$((restore_choice-1))]}"
                echo -e "${YELLOW}即将恢复: $(basename "$selected_backup")${NC}"
                echo -n -e "${BLUE}确定要恢复此备份吗? [y/N]: ${NC}"
                read -r confirm_restore
                if [[ $confirm_restore =~ ^[Yy]$ ]]; then
                    if rollback_config "$selected_backup"; then
                        echo -e "${GREEN}配置已成功恢复${NC}"
                        echo -n -e "${BLUE}是否重启服务? [Y/n]: ${NC}"
                        read -r restart_after_restore
                        if [[ ! $restart_after_restore =~ ^[Nn]$ ]]; then
                            systemctl restart $SERVICE_NAME
                        fi
                    fi
                fi
            fi
            ;;
        2)
            echo -n -e "${BLUE}请选择要删除的备份编号 [1-${#backups[@]}]: ${NC}"
            read -r delete_choice
            if [[ "$delete_choice" =~ ^[0-9]+$ ]] && [[ $delete_choice -ge 1 ]] && [[ $delete_choice -le ${#backups[@]} ]]; then
                local selected_backup="${backups[$((delete_choice-1))]}"
                echo -n -e "${BLUE}确定要删除 $(basename "$selected_backup")? [y/N]: ${NC}"
                read -r confirm_delete
                if [[ $confirm_delete =~ ^[Yy]$ ]]; then
                    rm -f "$selected_backup" "${selected_backup}.checksum"
                    echo -e "${GREEN}备份已删除${NC}"
                fi
            fi
            ;;
        3)
            backup_config_with_checksum "$CONFIG_PATH"
            ;;
        4)
            echo -n -e "${BLUE}请选择要查看的备份编号 [1-${#backups[@]}]: ${NC}"
            read -r view_choice
            if [[ "$view_choice" =~ ^[0-9]+$ ]] && [[ $view_choice -ge 1 ]] && [[ $view_choice -le ${#backups[@]} ]]; then
                local selected_backup="${backups[$((view_choice-1))]}"
                echo -e "${BLUE}备份内容: $(basename "$selected_backup")${NC}"
                echo ""
                cat "$selected_backup"
            fi
            ;;
        5)
            echo -n -e "${BLUE}保留最近多少个备份? [5]: ${NC}"
            read -r keep_count
            keep_count=${keep_count:-5}
            if [[ "$keep_count" =~ ^[0-9]+$ ]] && [[ $keep_count -gt 0 ]]; then
                local delete_count=$((${#backups[@]} - keep_count))
                if [[ $delete_count -gt 0 ]]; then
                    echo -e "${YELLOW}将删除 $delete_count 个旧备份${NC}"
                    echo -n -e "${BLUE}确定继续? [y/N]: ${NC}"
                    read -r confirm_cleanup
                    if [[ $confirm_cleanup =~ ^[Yy]$ ]]; then
                        for ((i=keep_count; i<${#backups[@]}; i++)); do
                            rm -f "${backups[$i]}" "${backups[$i]}.checksum"
                        done
                        echo -e "${GREEN}旧备份已清理${NC}"
                    fi
                else
                    echo -e "${GREEN}备份数量在限制范围内，无需清理${NC}"
                fi
            fi
            ;;
    esac
    
    if [[ $backup_choice -ne 0 ]]; then
        echo ""
        read -p "按回车键继续..."
    fi
}

# 主进阶配置函数（优化版本）
advanced_configuration() {
    while true; do
        clear
        echo -e "${BLUE}Hysteria2 进阶配置 - 优化版本${NC}"
        echo ""
        
        # 显示系统状态
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo -e "服务状态: ${GREEN}运行中${NC}"
        else
            echo -e "服务状态: ${RED}已停止${NC}"
        fi
        
        if [[ -f "$CONFIG_PATH" ]]; then
            local config_size=$(du -h "$CONFIG_PATH" | cut -f1)
            echo -e "配置文件: ${GREEN}存在${NC} ($config_size)"
        else
            echo -e "配置文件: ${RED}不存在${NC}"
        fi
        
        echo ""
        echo -e "${YELLOW}配置选项:${NC}"
        echo -e "${GREEN}1.${NC} 修改监听端口"
        echo -e "${GREEN}2.${NC} 添加混淆配置"
        echo -e "${GREEN}3.${NC} 移除混淆配置"
        echo -e "${GREEN}4.${NC} 配置端口跳跃"
        echo -e "${GREEN}5.${NC} 移除端口跳跃"
        echo -e "${GREEN}6.${NC} 查看配置状态"
        echo ""
        echo -e "${YELLOW}管理工具:${NC}"
        echo -e "${GREEN}7.${NC} 配置健康检查"
        echo -e "${GREEN}8.${NC} 配置备份管理"
        echo ""
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-8]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                clear
                modify_listen_port
                echo ""
                read -p "按回车键继续..."
                ;;
            2)
                clear
                add_obfuscation
                echo ""
                read -p "按回车键继续..."
                ;;
            3)
                clear
                remove_obfuscation
                echo ""
                read -p "按回车键继续..."
                ;;
            4)
                clear
                configure_port_hopping
                echo ""
                read -p "按回车键继续..."
                ;;
            5)
                clear
                remove_port_hopping
                echo ""
                read -p "按回车键继续..."
                ;;
            6)
                clear
                view_advanced_config
                echo ""
                read -p "按回车键继续..."
                ;;
            7)
                clear
                health_check
                echo ""
                read -p "按回车键继续..."
                ;;
            8)
                clear
                manage_config_backups
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
        echo -e "${RED}错误: 配置文件不存在${NC}"
        echo "请先生成配置文件"
        return 1
    fi
    
    return 0
}

# 端口验证函数
validate_port() {
    local port=$1
    
    # 检查端口范围
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ $port -lt 1 ]] || [[ $port -gt 65535 ]]; then
        echo -e "${RED}端口必须在 1-65535 范围内${NC}"
        return 1
    fi
    
    # 检查特权端口警告
    if [[ $port -lt 1024 ]] && [[ $port -ne 443 ]] && [[ $port -ne 80 ]]; then
        echo -e "${YELLOW}警告: 端口 $port 是特权端口，确保以 root 权限运行${NC}"
    fi
    
    return 0
}

# 端口建议函数
suggest_alternative_ports() {
    local occupied_port=$1
    local suggested_ports=(8443 9443 10443 20443 30443)
    
    echo -e "${BLUE}建议的替代端口:${NC}"
    for port in "${suggested_ports[@]}"; do
        if ! netstat -tuln | grep -q ":$port "; then
            echo "  $port (可用)"
        fi
    done
}

# 配置备份函数（增强版）
backup_config_with_checksum() {
    local config_file=$1
    local backup_suffix=${2:-$(date +%Y%m%d_%H%M%S)}
    local backup_file="${config_file}.backup.${backup_suffix}"
    
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}配置文件不存在: $config_file${NC}"
        return 1
    fi
    
    # 创建备份
    if cp "$config_file" "$backup_file"; then
        # 生成校验和
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "$config_file" > "${backup_file}.checksum"
        elif command -v shasum >/dev/null 2>&1; then
            shasum -a 256 "$config_file" > "${backup_file}.checksum"
        fi
        
        echo -e "${GREEN}配置已备份: $backup_file${NC}"
        echo "$backup_file"
        return 0
    else
        echo -e "${RED}配置备份失败${NC}"
        return 1
    fi
}

# 配置回滚函数
rollback_config() {
    local backup_file=$1
    local checksum_file="${backup_file}.checksum"
    
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}备份文件不存在: $backup_file${NC}"
        return 1
    fi
    
    # 验证备份文件完整性
    if [[ -f "$checksum_file" ]]; then
        echo -e "${BLUE}验证备份文件完整性...${NC}"
        if command -v sha256sum >/dev/null 2>&1; then
            if ! sha256sum -c "$checksum_file" >/dev/null 2>&1; then
                echo -e "${RED}警告: 备份文件可能已损坏${NC}"
                echo -n -e "${BLUE}是否继续回滚? [y/N]: ${NC}"
                read -r continue_rollback
                [[ ! $continue_rollback =~ ^[Yy]$ ]] && return 1
            fi
        fi
    fi
    
    # 执行回滚
    if cp "$backup_file" "$CONFIG_PATH"; then
        echo -e "${GREEN}配置已回滚${NC}"
        return 0
    else
        echo -e "${RED}配置回滚失败${NC}"
        return 1
    fi
}

# 修改监听端口（优化版本）
modify_listen_port() {
    echo -e "${BLUE}修改监听端口${NC}"
    echo ""
    
    if ! security_check; then
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
        echo -n -e "${BLUE}请输入新端口 (1-65535, 回车取消): ${NC}"
        read -r new_port
        
        [[ -z "$new_port" ]] && { echo -e "${BLUE}取消端口修改${NC}"; return; }
        
        if validate_port "$new_port"; then
            break
        fi
    done
    
    # 检查端口占用
    if netstat -tuln | grep -q ":$new_port "; then
        echo -e "${YELLOW}警告: 端口 $new_port 已被占用${NC}"
        netstat -tulnp | grep ":$new_port "
        echo ""
        suggest_alternative_ports "$new_port"
        echo ""
        echo -n -e "${BLUE}是否继续使用此端口? [y/N]: ${NC}"
        read -r continue_change
        if [[ ! $continue_change =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消端口修改${NC}"
            return
        fi
    fi
    
    # 备份配置文件
    local backup_file
    if ! backup_file=$(backup_config_with_checksum "$CONFIG_PATH"); then
        echo -e "${RED}配置备份失败，取消操作${NC}"
        return 1
    fi
    
    # 修改配置文件
    local update_success=false
    if grep -q "^listen:" "$CONFIG_PATH"; then
        if sed -i.tmp "s/^listen:.*/listen: :$new_port/" "$CONFIG_PATH"; then
            update_success=true
        fi
    else
        if sed -i.tmp "1i listen: :$new_port" "$CONFIG_PATH"; then
            update_success=true
        fi
    fi
    
    # 清理临时文件
    rm -f "${CONFIG_PATH}.tmp"
    
    if [[ "$update_success" == "true" ]]; then
        echo -e "${GREEN}端口已修改为: $new_port${NC}"
        
        # 验证配置文件语法
        if command -v hysteria >/dev/null && ! hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
            echo -e "${RED}配置文件语法错误，正在回滚...${NC}"
            rollback_config "$backup_file"
            return 1
        fi
        
        # 询问是否重启服务
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo -n -e "${BLUE}是否重启服务以应用新端口? [Y/n]: ${NC}"
            read -r restart_service
            if [[ ! $restart_service =~ ^[Nn]$ ]]; then
                if systemctl restart $SERVICE_NAME; then
                    echo -e "${GREEN}服务已重启${NC}"
                else
                    echo -e "${RED}服务重启失败，正在回滚配置...${NC}"
                    rollback_config "$backup_file"
                    return 1
                fi
            fi
        fi
        
        # 防火墙提醒
        echo ""
        echo -e "${YELLOW}重要提醒:${NC}"
        echo "1. 请确保防火墙允许端口 $new_port 通信"
        echo "2. 如果使用云服务器，请检查安全组设置"
        echo "3. 客户端配置也需要更新端口号"
        
    else
        echo -e "${RED}配置文件修改失败${NC}"
        return 1
    fi
}

# 混淆算法选择
select_obfuscation_type() {
    echo -e "${BLUE}选择混淆算法:${NC}"
    echo "1. salamander (推荐，轻量级)"
    echo "2. 自定义算法"
    echo ""
    echo -n -e "${BLUE}请选择 [1-2]: ${NC}"
    read -r obfs_choice
    
    case $obfs_choice in
        1)
            echo "salamander"
            ;;
        2)
            echo -n -e "${BLUE}请输入自定义算法名称: ${NC}"
            read -r custom_obfs
            if [[ -n "$custom_obfs" ]]; then
                echo "$custom_obfs"
            else
                echo "salamander"
            fi
            ;;
        *)
            echo "salamander"
            ;;
    esac
}

# 生成安全密码
generate_secure_password() {
    local length=${1:-16}
    local charset="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-$length
    else
        # 备选方法
        tr -dc "$charset" < /dev/urandom | head -c $length
    fi
}

# 添加混淆配置（优化版本）
add_obfuscation() {
    echo -e "${BLUE}添加混淆配置${NC}"
    echo ""
    
    if ! security_check; then
        return 1
    fi
    
    # 检查是否已有混淆配置
    if grep -q "^obfs:" "$CONFIG_PATH"; then
        echo -e "${YELLOW}检测到现有混淆配置:${NC}"
        local current_type=$(grep -A 3 "^obfs:" "$CONFIG_PATH" | grep "type:" | awk '{print $2}')
        local current_password=$(grep -A 5 "^obfs:" "$CONFIG_PATH" | grep "password:" | awk '{print $2}')
        echo "当前算法: ${current_type:-未知}"
        echo "当前密码: ${current_password:-未设置}"
        echo ""
        echo -n -e "${BLUE}是否覆盖现有配置? [y/N]: ${NC}"
        read -r overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}取消混淆配置${NC}"
            return
        fi
    fi
    
    # 选择混淆算法
    local obfs_type=$(select_obfuscation_type)
    
    # 输入混淆密码
    echo -n -e "${BLUE}请输入混淆密码 (留空自动生成): ${NC}"
    read -r obfs_password
    if [[ -z "$obfs_password" ]]; then
        obfs_password=$(generate_secure_password 16)
        echo -e "${GREEN}自动生成混淆密码: $obfs_password${NC}"
    fi
    
    # 验证密码强度
    if [[ ${#obfs_password} -lt 8 ]]; then
        echo -e "${YELLOW}警告: 密码长度小于8位，安全性较低${NC}"
        echo -n -e "${BLUE}是否继续? [y/N]: ${NC}"
        read -r continue_weak
        [[ ! $continue_weak =~ ^[Yy]$ ]] && return
    fi
    
    # 备份配置文件
    local backup_file
    if ! backup_file=$(backup_config_with_checksum "$CONFIG_PATH"); then
        echo -e "${RED}配置备份失败，取消操作${NC}"
        return 1
    fi
    
    # 删除现有混淆配置
    sed -i '/^obfs:/,/^[a-zA-Z]/{ /^[a-zA-Z]/!d; }' "$CONFIG_PATH"
    sed -i '/^obfs:/d' "$CONFIG_PATH"
    
    # 添加新的混淆配置
    cat >> "$CONFIG_PATH" << EOF

obfs:
  type: $obfs_type
  $obfs_type:
    password: $obfs_password
EOF
    
    # 验证配置文件语法
    if command -v hysteria >/dev/null && ! hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
        echo -e "${RED}配置文件语法错误，正在回滚...${NC}"
        rollback_config "$backup_file"
        return 1
    fi
    
    echo -e "${GREEN}混淆配置已添加${NC}"
    echo -e "${YELLOW}混淆算法: $obfs_type${NC}"
    echo -e "${YELLOW}混淆密码: $obfs_password${NC}"
    
    # 保存配置信息到安全位置
    local obfs_info_file="/etc/hysteria/obfs-info.conf"
    cat > "$obfs_info_file" << EOF
# 混淆配置信息
# 生成时间: $(date)
OBFS_TYPE="$obfs_type"
OBFS_PASSWORD="$obfs_password"
EOF
    chmod 600 "$obfs_info_file"
    echo -e "${BLUE}混淆信息已保存到: $obfs_info_file${NC}"
    
    # 询问是否重启服务
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -n -e "${BLUE}是否重启服务以应用混淆配置? [Y/n]: ${NC}"
        read -r restart_service
        if [[ ! $restart_service =~ ^[Nn]$ ]]; then
            if systemctl restart $SERVICE_NAME; then
                echo -e "${GREEN}服务已重启${NC}"
            else
                echo -e "${RED}服务重启失败，请检查配置${NC}"
            fi
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}重要提醒:${NC}"
    echo "1. 客户端也需要配置相同的混淆算法和密码"
    echo "2. 请妥善保存混淆密码"
    echo "3. 定期更换混淆密码以提高安全性"
}

# 移除混淆配置（优化版本）
remove_obfuscation() {
    echo -e "${BLUE}移除混淆配置${NC}"
    echo ""
    
    if ! security_check; then
        return 1
    fi
    
    if ! grep -q "^obfs:" "$CONFIG_PATH"; then
        echo -e "${YELLOW}未找到混淆配置${NC}"
        return
    fi
    
    # 显示当前混淆配置
    echo -e "${YELLOW}当前混淆配置:${NC}"
    local current_type=$(grep -A 3 "^obfs:" "$CONFIG_PATH" | grep "type:" | awk '{print $2}')
    echo "算法: ${current_type:-未知}"
    echo ""
    
    echo -n -e "${BLUE}确定要移除混淆配置吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消移除${NC}"
        return
    fi
    
    # 备份配置文件
    local backup_file
    if ! backup_file=$(backup_config_with_checksum "$CONFIG_PATH"); then
        echo -e "${RED}配置备份失败，取消操作${NC}"
        return 1
    fi
    
    # 删除混淆配置
    sed -i '/^obfs:/,/^[a-zA-Z]/{ /^[a-zA-Z]/!d; }' "$CONFIG_PATH"
    sed -i '/^obfs:/d' "$CONFIG_PATH"
    
    # 验证配置文件语法
    if command -v hysteria >/dev/null && ! hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
        echo -e "${RED}配置文件语法错误，正在回滚...${NC}"
        rollback_config "$backup_file"
        return 1
    fi
    
    echo -e "${GREEN}混淆配置已移除${NC}"
    
    # 删除混淆信息文件
    rm -f "/etc/hysteria/obfs-info.conf"
    
    # 询问是否重启服务
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -n -e "${BLUE}是否重启服务以应用更改? [Y/n]: ${NC}"
        read -r restart_service
        if [[ ! $restart_service =~ ^[Nn]$ ]]; then
            if systemctl restart $SERVICE_NAME; then
                echo -e "${GREEN}服务已重启${NC}"
            else
                echo -e "${RED}服务重启失败，请检查配置${NC}"
            fi
        fi
    fi
}

# 端口范围验证
validate_port_range() {
    local start_port=$1
    local end_port=$2
    
    if [[ ! "$start_port" =~ ^[0-9]+$ ]] || [[ ! "$end_port" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}端口必须是数字${NC}"
        return 1
    fi
    
    if [[ $start_port -ge $end_port ]]; then
        echo -e "${RED}起始端口必须小于结束端口${NC}"
        return 1
    fi
    
    if [[ $start_port -lt 1024 ]]; then
        echo -e "${YELLOW}警告: 起始端口在特权端口范围内${NC}"
    fi
    
    local port_count=$((end_port - start_port + 1))
    if [[ $port_count -gt 30000 ]]; then
        echo -e "${YELLOW}警告: 端口范围过大 ($port_count 个端口)，可能影响性能${NC}"
        echo -n -e "${BLUE}是否继续? [y/N]: ${NC}"
        read -r continue_large
        [[ ! $continue_large =~ ^[Yy]$ ]] && return 1
    fi
    
    return 0
}

# 网络接口检测和选择
select_network_interface() {
    echo -e "${BLUE}检测网络接口...${NC}"
    local interfaces=($(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo))
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        echo -e "${RED}未找到可用的网络接口${NC}"
        return 1
    fi
    
    echo -e "${BLUE}可用的网络接口:${NC}"
    for i in "${!interfaces[@]}"; do
        local interface="${interfaces[$i]}"
        local ip=$(ip addr show "$interface" | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        local status=$(ip link show "$interface" | grep -q "state UP" && echo "UP" || echo "DOWN")
        printf "%d. %-15s %s (%s)\n" $((i+1)) "$interface" "${ip:-无IP}" "$status"
    done
    
    echo ""
    echo -n -e "${BLUE}请选择网络接口 [1-${#interfaces[@]}]: ${NC}"
    read -r interface_choice
    
    if [[ ! "$interface_choice" =~ ^[0-9]+$ ]] || [[ $interface_choice -lt 1 ]] || [[ $interface_choice -gt ${#interfaces[@]} ]]; then
        echo -e "${RED}无效选择${NC}"
        return 1
    fi
    
    echo "${interfaces[$((interface_choice-1))]}"
    return 0
}

# 配置端口跳跃（优化版本）
configure_port_hopping() {
    echo -e "${BLUE}配置端口跳跃${NC}"
    echo ""
    
    if ! security_check; then
        return 1
    fi
    
    # 检查 iptables 是否可用
    if ! command -v iptables >/dev/null; then
        echo -e "${RED}错误: 未找到 iptables 命令${NC}"
        echo "请安装 iptables 后重试"
        return 1
    fi
    
    # 选择网络接口
    local selected_interface
    if ! selected_interface=$(select_network_interface); then
        return 1
    fi
    
    echo -e "${GREEN}已选择网络接口: $selected_interface${NC}"
    echo ""
    
    # 输入端口范围
    while true; do
        echo -n -e "${BLUE}请输入起始端口 (建议 20000): ${NC}"
        read -r start_port
        echo -n -e "${BLUE}请输入结束端口 (建议 50000): ${NC}"
        read -r end_port
        
        if validate_port_range "$start_port" "$end_port"; then
            break
        fi
        echo ""
    done
    
    # 获取目标端口
    local target_port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://')
    if [[ -z "$target_port" ]]; then
        target_port="443"
    fi
    
    echo ""
    echo -e "${YELLOW}端口跳跃配置信息:${NC}"
    echo "网络接口: $selected_interface"
    echo "端口范围: $start_port-$end_port"
    echo "目标端口: $target_port"
    echo "端口数量: $((end_port - start_port + 1))"
    echo ""
    
    # 生成 iptables 规则
    local iptables_rule="iptables -t nat -A PREROUTING -i $selected_interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port"
    
    echo -e "${YELLOW}将要执行的 iptables 规则:${NC}"
    echo "$iptables_rule"
    echo ""
    
    echo -n -e "${BLUE}是否执行此规则? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消端口跳跃配置${NC}"
        return
    fi
    
    # 检查是否存在冲突的规则
    if iptables -t nat -L PREROUTING -n | grep -q "REDIRECT.*$target_port"; then
        echo -e "${YELLOW}警告: 发现可能冲突的 iptables 规则${NC}"
        iptables -t nat -L PREROUTING -n | grep "REDIRECT.*$target_port"
        echo ""
        echo -n -e "${BLUE}是否继续添加新规则? [y/N]: ${NC}"
        read -r continue_conflict
        [[ ! $continue_conflict =~ ^[Yy]$ ]] && return
    fi
    
    # 执行 iptables 规则
    if eval "$iptables_rule"; then
        echo -e "${GREEN}端口跳跃规则已添加${NC}"
        
        # 验证规则是否生效
        if iptables -t nat -L PREROUTING -n | grep -q "$start_port:$end_port"; then
            echo -e "${GREEN}规则验证成功${NC}"
        else
            echo -e "${YELLOW}警告: 规则可能未生效，请检查${NC}"
        fi
        
        # 保存 iptables 规则
        echo -n -e "${BLUE}是否保存 iptables 规则以便重启后生效? [Y/n]: ${NC}"
        read -r save_rules
        if [[ ! $save_rules =~ ^[Nn]$ ]]; then
            local rules_saved=false
            
            # 尝试不同的保存方法
            if command -v iptables-save >/dev/null; then
                if mkdir -p /etc/iptables 2>/dev/null && iptables-save > /etc/iptables/rules.v4 2>/dev/null; then
                    rules_saved=true
                elif iptables-save > /etc/iptables.rules 2>/dev/null; then
                    rules_saved=true
                fi
            fi
            
            if [[ "$rules_saved" == "true" ]]; then
                echo -e "${GREEN}iptables 规则已保存${NC}"
            else
                echo -e "${YELLOW}无法自动保存规则，请手动保存:${NC}"
                echo "iptables-save > /etc/iptables.rules"
            fi
        fi
        
        # 保存配置信息
        local config_file="/etc/hysteria/port-hopping.conf"
        cat > "$config_file" << EOF
# 端口跳跃配置
# 生成时间: $(date)
# 配置版本: 2.0

INTERFACE="$selected_interface"
START_PORT="$start_port"
END_PORT="$end_port"
TARGET_PORT="$target_port"
IPTABLES_RULE="$iptables_rule"

# 移除规则的命令
REMOVE_RULE="iptables -t nat -D PREROUTING -i $selected_interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port"
EOF
        chmod 600 "$config_file"
        
        echo -e "${GREEN}端口跳跃配置已保存到: $config_file${NC}"
        
    else
        echo -e "${RED}端口跳跃规则添加失败${NC}"
        echo "可能的原因:"
        echo "1. 权限不足"
        echo "2. iptables 配置问题"
        echo "3. 网络接口不存在"
    fi
}

# 移除端口跳跃（优化版本）
remove_port_hopping() {
    echo -e "${BLUE}移除端口跳跃配置${NC}"
    echo ""
    
    if ! security_check; then
        return 1
    fi
    
    local config_file="/etc/hysteria/port-hopping.conf"
    
    if [[ ! -f "$config_file" ]]; then
        echo -e "${YELLOW}未找到端口跳跃配置文件${NC}"
        echo -e "${BLUE}手动查找相关 iptables 规则...${NC}"
        
        local hysteria_rules=$(iptables -t nat -L PREROUTING --line-numbers 2>/dev/null | grep -E "REDIRECT.*443|REDIRECT.*hysteria")
        if [[ -n "$hysteria_rules" ]]; then
            echo -e "${YELLOW}找到可能相关的规则:${NC}"
            echo "$hysteria_rules"
            echo ""
            echo -e "${BLUE}请手动移除这些规则${NC}"
            echo "示例命令: iptables -t nat -D PREROUTING <规则编号>"
        else
            echo -e "${GREEN}未找到相关的 iptables 规则${NC}"
        fi
        return
    fi
    
    # 读取配置
    source "$config_file"
    
    echo -e "${YELLOW}当前端口跳跃配置:${NC}"
    echo "网络接口: $INTERFACE"
    echo "端口范围: $START_PORT-$END_PORT"
    echo "目标端口: $TARGET_PORT"
    echo "配置时间: $(stat -c %y "$config_file" 2>/dev/null || stat -f %Sm "$config_file" 2>/dev/null)"
    echo ""
    
    echo -n -e "${BLUE}确定要移除端口跳跃配置吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消移除${NC}"
        return
    fi
    
    # 删除 iptables 规则
    local remove_rule="iptables -t nat -D PREROUTING -i $INTERFACE -p udp --dport $START_PORT:$END_PORT -j REDIRECT --to-ports $TARGET_PORT"
    
    # 如果配置文件中有移除命令，优先使用
    if [[ -n "$REMOVE_RULE" ]]; then
        remove_rule="$REMOVE_RULE"
    fi
    
    echo -e "${BLUE}执行移除命令: $remove_rule${NC}"
    
    if eval "$remove_rule" 2>/dev/null; then
        echo -e "${GREEN}端口跳跃规则已移除${NC}"
        
        # 验证规则是否已移除
        if ! iptables -t nat -L PREROUTING -n | grep -q "$START_PORT:$END_PORT"; then
            echo -e "${GREEN}规则移除验证成功${NC}"
        else
            echo -e "${YELLOW}警告: 规则可能仍然存在${NC}"
        fi
    else
        echo -e "${YELLOW}规则可能已经不存在或移除失败${NC}"
        echo "这通常是正常的，可能规则已被手动移除"
    fi
    
    # 删除配置文件
    rm -f "$config_file"
    echo -e "${GREEN}端口跳跃配置文件已删除${NC}"
    
    # 询问是否保存 iptables 规则
    echo -n -e "${BLUE}是否保存当前 iptables 规则? [Y/n]: ${NC}"
    read -r save_current
    if [[ ! $save_current =~ ^[Nn]$ ]]; then
        if command -v iptables-save >/dev/null; then
            if iptables-save > /etc/iptables.rules 2>/dev/null; then
                echo -e "${GREEN}当前 iptables 规则已保存${NC}"
            fi
        fi
    fi
}

# 查看当前进阶配置（优化版本）
view_advanced_config() {
    echo -e "${CYAN}当前进阶配置状态:${NC}"
    echo ""
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
