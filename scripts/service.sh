#!/bin/bash

# Hysteria2 服务管理脚本

# 检查服务状态详情
check_service_detailed() {
    echo -e "${CYAN}Hysteria2 服务详细状态:${NC}"
    echo ""
    
    if ! check_hysteria_installed; then
        echo -e "${RED}Hysteria2 未安装${NC}"
        return 1
    fi
    
    # 服务状态
    echo -e "${BLUE}服务状态:${NC}"
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "  运行状态: ${GREEN}运行中${NC}"
    else
        echo -e "  运行状态: ${RED}已停止${NC}"
    fi
    
    if systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "  开机启动: ${GREEN}已启用${NC}"
    else
        echo -e "  开机启动: ${RED}未启用${NC}"
    fi
    
    # 配置文件状态
    echo ""
    echo -e "${BLUE}配置文件:${NC}"
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "  配置文件: ${GREEN}存在${NC} ($CONFIG_PATH)"
        echo -e "  文件大小: $(du -h "$CONFIG_PATH" | cut -f1)"
        echo -e "  修改时间: $(stat -c %y "$CONFIG_PATH" 2>/dev/null || stat -f %Sm "$CONFIG_PATH" 2>/dev/null)"
    else
        echo -e "  配置文件: ${RED}不存在${NC}"
    fi
    
    # 端口监听状态
    echo ""
    echo -e "${BLUE}端口监听:${NC}"
    if [[ -f "$CONFIG_PATH" ]]; then
        local port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://')
        if [[ -z "$port" ]]; then
            port="443"
        fi
        
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "  端口 $port: ${GREEN}正在监听${NC}"
        else
            echo -e "  端口 $port: ${RED}未监听${NC}"
        fi
    fi
    
    # 进程信息
    echo ""
    echo -e "${BLUE}进程信息:${NC}"
    local pid=$(pgrep -f hysteria)
    if [[ -n "$pid" ]]; then
        echo -e "  进程ID: ${GREEN}$pid${NC}"
        echo -e "  内存使用: $(ps -p $pid -o rss= | awk '{printf "%.1f MB", $1/1024}')"
        echo -e "  CPU使用: $(ps -p $pid -o %cpu= | awk '{print $1"%"}')"
    else
        echo -e "  进程状态: ${RED}未运行${NC}"
    fi
}

# 启动服务
start_service() {
    echo -e "${BLUE}启动 Hysteria2 服务...${NC}"
    
    if ! check_hysteria_installed; then
        echo -e "${RED}错误: Hysteria2 未安装${NC}"
        return 1
    fi
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        echo "请先生成配置文件"
        return 1
    fi
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}服务已在运行中${NC}"
        return 0
    fi
    
    # 启动服务
    if systemctl start $SERVICE_NAME; then
        echo -e "${GREEN}服务启动成功${NC}"
        
        # 等待服务启动
        sleep 2
        
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo -e "${GREEN}服务运行正常${NC}"
        else
            echo -e "${RED}服务启动失败${NC}"
            echo "查看日志获取详细信息"
        fi
    else
        echo -e "${RED}服务启动失败${NC}"
    fi
}

# 停止服务
stop_service() {
    echo -e "${BLUE}停止 Hysteria2 服务...${NC}"
    
    if ! systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}服务未在运行${NC}"
        return 0
    fi
    
    if systemctl stop $SERVICE_NAME; then
        echo -e "${GREEN}服务停止成功${NC}"
    else
        echo -e "${RED}服务停止失败${NC}"
    fi
}

# 重启服务
restart_service() {
    echo -e "${BLUE}重启 Hysteria2 服务...${NC}"
    
    if ! check_hysteria_installed; then
        echo -e "${RED}错误: Hysteria2 未安装${NC}"
        return 1
    fi
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        return 1
    fi
    
    if systemctl restart $SERVICE_NAME; then
        echo -e "${GREEN}服务重启成功${NC}"
        
        # 等待服务启动
        sleep 2
        
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo -e "${GREEN}服务运行正常${NC}"
        else
            echo -e "${RED}服务重启后未正常运行${NC}"
        fi
    else
        echo -e "${RED}服务重启失败${NC}"
    fi
}

# 启用开机自启
enable_service() {
    echo -e "${BLUE}启用开机自启...${NC}"
    
    if systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}开机自启已启用${NC}"
        return 0
    fi
    
    if systemctl enable $SERVICE_NAME; then
        echo -e "${GREEN}开机自启启用成功${NC}"
    else
        echo -e "${RED}开机自启启用失败${NC}"
    fi
}

# 禁用开机自启
disable_service() {
    echo -e "${BLUE}禁用开机自启...${NC}"
    
    if ! systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}开机自启未启用${NC}"
        return 0
    fi
    
    if systemctl disable $SERVICE_NAME; then
        echo -e "${GREEN}开机自启禁用成功${NC}"
    else
        echo -e "${RED}开机自启禁用失败${NC}"
    fi
}

# 查看实时日志
view_live_logs() {
    echo -e "${BLUE}查看实时日志 (按 Ctrl+C 退出)...${NC}"
    echo ""
    journalctl -f -u $SERVICE_NAME
}

# 查看历史日志
view_history_logs() {
    echo -e "${BLUE}查看历史日志${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 最近 50 行"
    echo -e "${GREEN}2.${NC} 最近 100 行"
    echo -e "${GREEN}3.${NC} 最近 500 行"
    echo -e "${GREEN}4.${NC} 今天的日志"
    echo -e "${GREEN}5.${NC} 自定义行数"
    echo ""
    echo -n -e "${BLUE}请选择 [1-5]: ${NC}"
    read -r choice
    
    case $choice in
        1)
            journalctl --no-pager -n 50 -u $SERVICE_NAME
            ;;
        2)
            journalctl --no-pager -n 100 -u $SERVICE_NAME
            ;;
        3)
            journalctl --no-pager -n 500 -u $SERVICE_NAME
            ;;
        4)
            journalctl --no-pager --since today -u $SERVICE_NAME
            ;;
        5)
            echo -n -e "${BLUE}请输入行数: ${NC}"
            read -r lines
            if [[ "$lines" =~ ^[0-9]+$ ]]; then
                journalctl --no-pager -n "$lines" -u $SERVICE_NAME
            else
                echo -e "${RED}无效的行数${NC}"
            fi
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
}

# 配置文件操作
config_operations() {
    echo -e "${BLUE}配置文件操作${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 查看配置文件"
    echo -e "${GREEN}2.${NC} 编辑配置文件"
    echo -e "${GREEN}3.${NC} 备份配置文件"
    echo -e "${GREEN}4.${NC} 恢复配置文件"
    echo -e "${GREEN}5.${NC} 验证配置文件"
    echo ""
    echo -n -e "${BLUE}请选择 [1-5]: ${NC}"
    read -r choice
    
    case $choice in
        1)
            if [[ -f "$CONFIG_PATH" ]]; then
                echo -e "${BLUE}当前配置文件内容:${NC}"
                echo ""
                cat "$CONFIG_PATH"
            else
                echo -e "${RED}配置文件不存在${NC}"
            fi
            ;;
        2)
            if [[ -f "$CONFIG_PATH" ]]; then
                echo -e "${BLUE}使用 nano 编辑配置文件...${NC}"
                nano "$CONFIG_PATH"
                echo -e "${GREEN}编辑完成${NC}"
                echo -n -e "${BLUE}是否重启服务以应用更改? [y/N]: ${NC}"
                read -r restart
                if [[ $restart =~ ^[Yy]$ ]]; then
                    restart_service
                fi
            else
                echo -e "${RED}配置文件不存在${NC}"
            fi
            ;;
        3)
            if [[ -f "$CONFIG_PATH" ]]; then
                local backup_file="$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
                cp "$CONFIG_PATH" "$backup_file"
                echo -e "${GREEN}配置文件已备份到: $backup_file${NC}"
            else
                echo -e "${RED}配置文件不存在${NC}"
            fi
            ;;
        4)
            echo -e "${BLUE}可用的备份文件:${NC}"
            local backups=($(ls "$CONFIG_PATH".backup.* 2>/dev/null))
            if [[ ${#backups[@]} -eq 0 ]]; then
                echo -e "${RED}没有找到备份文件${NC}"
                return
            fi
            
            for i in "${!backups[@]}"; do
                echo "$((i+1)). ${backups[$i]}"
            done
            
            echo -n -e "${BLUE}请选择要恢复的备份 [1-${#backups[@]}]: ${NC}"
            read -r backup_choice
            
            if [[ "$backup_choice" =~ ^[0-9]+$ ]] && [[ $backup_choice -ge 1 ]] && [[ $backup_choice -le ${#backups[@]} ]]; then
                local selected_backup="${backups[$((backup_choice-1))]}"
                cp "$selected_backup" "$CONFIG_PATH"
                echo -e "${GREEN}配置文件已恢复${NC}"
            else
                echo -e "${RED}无效选择${NC}"
            fi
            ;;
        5)
            if [[ -f "$CONFIG_PATH" ]]; then
                echo -e "${BLUE}验证配置文件语法...${NC}"
                if hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
                    echo -e "${GREEN}配置文件语法正确${NC}"
                else
                    echo -e "${RED}配置文件语法错误${NC}"
                    echo "请检查配置文件格式"
                fi
            else
                echo -e "${RED}配置文件不存在${NC}"
            fi
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
}

# 主服务管理函数
manage_hysteria_service() {
    while true; do
        echo -e "${BLUE}Hysteria2 服务管理${NC}"
        echo ""
        
        # 显示当前状态
        check_service_detailed
        
        echo ""
        echo -e "${YELLOW}服务操作:${NC}"
        echo -e "${GREEN}1.${NC} 启动服务"
        echo -e "${GREEN}2.${NC} 停止服务"
        echo -e "${GREEN}3.${NC} 重启服务"
        echo -e "${GREEN}4.${NC} 启用开机自启"
        echo -e "${GREEN}5.${NC} 禁用开机自启"
        echo ""
        echo -e "${YELLOW}日志查看:${NC}"
        echo -e "${GREEN}6.${NC} 查看实时日志"
        echo -e "${GREEN}7.${NC} 查看历史日志"
        echo ""
        echo -e "${YELLOW}配置管理:${NC}"
        echo -e "${GREEN}8.${NC} 配置文件操作"
        echo ""
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-8]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                start_service
                echo ""
                read -p "按回车键继续..."
                ;;
            2)
                stop_service
                echo ""
                read -p "按回车键继续..."
                ;;
            3)
                restart_service
                echo ""
                read -p "按回车键继续..."
                ;;
            4)
                enable_service
                echo ""
                read -p "按回车键继续..."
                ;;
            5)
                disable_service
                echo ""
                read -p "按回车键继续..."
                ;;
            6)
                view_live_logs
                ;;
            7)
                view_history_logs
                echo ""
                read -p "按回车键继续..."
                ;;
            8)
                config_operations
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
