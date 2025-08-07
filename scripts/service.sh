#!/bin/bash

# Hysteria2 服务管理脚本 - 优化版本

# 性能监控函数
show_service_metrics() {
    local pid=$(pgrep -f hysteria-server)
    
    if [[ -n "$pid" ]]; then
        echo -e "${CYAN}=== 性能指标 ===${NC}"
        
        # CPU 和内存使用
        local cpu_usage=$(ps -p $pid -o %cpu= 2>/dev/null | awk '{print $1"%"}')
        local mem_usage=$(ps -p $pid -o rss= 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
        local mem_percent=$(ps -p $pid -o %mem= 2>/dev/null | awk '{print $1"%"}')
        local runtime=$(ps -p $pid -o etime= 2>/dev/null | awk '{print $1}')
        
        echo "CPU 使用率: ${cpu_usage:-N/A}"
        echo "内存使用: ${mem_usage:-N/A} (${mem_percent:-N/A})"
        echo "运行时间: ${runtime:-N/A}"
        
        # 文件描述符使用情况
        if [[ -d "/proc/$pid/fd" ]]; then
            local fd_count=$(ls /proc/$pid/fd 2>/dev/null | wc -l)
            echo "文件描述符: $fd_count"
        fi
        
        # 网络连接统计
        if command -v netstat >/dev/null; then
            local port=$(grep -E "^listen:" "$CONFIG_PATH" 2>/dev/null | awk '{print $2}' | sed 's/://' || echo "443")
            local connections=$(netstat -an 2>/dev/null | grep ":$port " | grep ESTABLISHED | wc -l)
            local listen_sockets=$(netstat -tln 2>/dev/null | grep ":$port " | wc -l)
            
            echo "活动连接: $connections"
            echo "监听套接字: $listen_sockets"
        fi
        
        # 线程信息
        if [[ -d "/proc/$pid/task" ]]; then
            local thread_count=$(ls /proc/$pid/task 2>/dev/null | wc -l)
            echo "线程数量: $thread_count"
        fi
        
        echo ""
    else
        echo -e "${RED}服务未运行，无法获取性能指标${NC}"
        return 1
    fi
}

# 连接统计分析
show_connection_stats() {
    echo -e "${CYAN}=== 连接统计 ===${NC}"
    
    local port=$(grep -E "^listen:" "$CONFIG_PATH" 2>/dev/null | awk '{print $2}' | sed 's/://' || echo "443")
    
    if ! command -v netstat >/dev/null; then
        echo -e "${YELLOW}netstat 命令不可用，无法显示连接统计${NC}"
        return 1
    fi
    
    # 各种连接状态统计
    echo "端口 $port 连接状态统计:"
    
    local established=$(netstat -an 2>/dev/null | grep ":$port " | grep -c ESTABLISHED)
    local time_wait=$(netstat -an 2>/dev/null | grep ":$port " | grep -c TIME_WAIT)
    local close_wait=$(netstat -an 2>/dev/null | grep ":$port " | grep -c CLOSE_WAIT)
    local listen=$(netstat -tln 2>/dev/null | grep -c ":$port ")
    
    echo "  ESTABLISHED: $established"
    echo "  TIME_WAIT: $time_wait"
    echo "  CLOSE_WAIT: $close_wait"
    echo "  LISTEN: $listen"
    
    # 连接的客户端IP统计
    echo ""
    echo "客户端连接统计 (前10个):"
    netstat -an 2>/dev/null | grep ":$port " | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10 | while read count ip; do
        echo "  $ip: $count 连接"
    done
    
    echo ""
}

# 日志分析
analyze_logs() {
    echo -e "${CYAN}=== 日志分析 ===${NC}"
    
    if ! command -v journalctl >/dev/null; then
        echo -e "${YELLOW}journalctl 命令不可用${NC}"
        return 1
    fi
    
    # 最近1小时的日志统计
    local log_period="1 hour ago"
    echo "最近1小时日志统计:"
    
    # 错误日志统计
    local error_count=$(journalctl -u $SERVICE_NAME --since "$log_period" --no-pager -q | grep -ic "error" || echo "0")
    local warning_count=$(journalctl -u $SERVICE_NAME --since "$log_period" --no-pager -q | grep -ic "warn" || echo "0")
    local info_count=$(journalctl -u $SERVICE_NAME --since "$log_period" --no-pager -q | wc -l || echo "0")
    
    echo "  错误消息: $error_count"
    echo "  警告消息: $warning_count" 
    echo "  总日志行: $info_count"
    
    # 最近的错误和警告
    if [[ $error_count -gt 0 ]]; then
        echo ""
        echo -e "${RED}最近的错误消息:${NC}"
        journalctl -u $SERVICE_NAME --since "$log_period" --no-pager -q | grep -i "error" | tail -3 | sed 's/^/  /'
    fi
    
    if [[ $warning_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}最近的警告消息:${NC}"
        journalctl -u $SERVICE_NAME --since "$log_period" --no-pager -q | grep -i "warn" | tail -3 | sed 's/^/  /'
    fi
    
    echo ""
}

# 检查服务状态详情（优化版本）
check_service_detailed() {
    echo -e "${CYAN}Hysteria2 服务详细状态:${NC}"
    echo ""
    
    if ! check_hysteria_installed; then
        echo -e "${RED}Hysteria2 未安装${NC}"
        return 1
    fi
    
    # 服务基本状态
    echo -e "${BLUE}=== 服务状态 ===${NC}"
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "  运行状态: ${GREEN}运行中${NC}"
        
        # 获取服务启动时间
        local start_time=$(systemctl show $SERVICE_NAME --property=ActiveEnterTimestamp --value)
        if [[ -n "$start_time" ]]; then
            echo "  启动时间: $start_time"
        fi
    else
        echo -e "  运行状态: ${RED}已停止${NC}"
        
        # 获取停止原因
        local exit_code=$(systemctl show $SERVICE_NAME --property=ExecMainStatus --value)
        if [[ -n "$exit_code" && "$exit_code" != "0" ]]; then
            echo -e "  退出代码: ${RED}$exit_code${NC}"
        fi
    fi
    
    if systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "  开机启动: ${GREEN}已启用${NC}"
    else
        echo -e "  开机启动: ${RED}未启用${NC}"
    fi
    
    # 配置文件状态
    echo ""
    echo -e "${BLUE}=== 配置文件 ===${NC}"
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "  配置文件: ${GREEN}存在${NC} ($CONFIG_PATH)"
        echo "  文件大小: $(du -h "$CONFIG_PATH" | cut -f1)"
        echo "  文件权限: $(stat -c %a "$CONFIG_PATH" 2>/dev/null || stat -f %Lp "$CONFIG_PATH" 2>/dev/null)"
        echo "  修改时间: $(stat -c %y "$CONFIG_PATH" 2>/dev/null | cut -d. -f1 || stat -f %Sm "$CONFIG_PATH" 2>/dev/null)"
        
        # 配置文件语法检查
        if command -v hysteria >/dev/null; then
            if hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
                echo -e "  语法检查: ${GREEN}通过${NC}"
            else
                echo -e "  语法检查: ${RED}失败${NC}"
            fi
        fi
    else
        echo -e "  配置文件: ${RED}不存在${NC}"
    fi
    
    # 端口监听状态
    echo ""
    echo -e "${BLUE}=== 端口监听 ===${NC}"
    if [[ -f "$CONFIG_PATH" ]]; then
        local port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://')
        if [[ -z "$port" ]]; then
            port="443"
        fi
        
        echo "  监听端口: $port"
        
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "  端口状态: ${GREEN}正在监听${NC}"
            
            # 显示监听详情
            local listen_info=$(netstat -tulnp 2>/dev/null | grep ":$port ")
            if [[ -n "$listen_info" ]]; then
                echo "  监听详情: $listen_info"
            fi
        else
            echo -e "  端口状态: ${RED}未监听${NC}"
        fi
        
        # 检查防火墙状态
        echo ""
        echo -e "${BLUE}=== 防火墙检查 ===${NC}"
        
        # UFW检查
        if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
            if ufw status 2>/dev/null | grep -q "$port"; then
                echo -e "  UFW: ${GREEN}端口 $port 已允许${NC}"
            else
                echo -e "  UFW: ${YELLOW}端口 $port 未在规则中${NC}"
            fi
        fi
        
        # firewalld检查
        if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
            if firewall-cmd --list-ports 2>/dev/null | grep -q "$port"; then
                echo -e "  Firewalld: ${GREEN}端口 $port 已开放${NC}"
            else
                echo -e "  Firewalld: ${YELLOW}端口 $port 未开放${NC}"
            fi
        fi
        
        # iptables检查
        if command -v iptables >/dev/null; then
            if iptables -L INPUT -n 2>/dev/null | grep -q "$port"; then
                echo -e "  iptables: ${GREEN}发现端口 $port 相关规则${NC}"
            else
                echo -e "  iptables: ${YELLOW}未发现端口 $port 相关规则${NC}"
            fi
        fi
    fi
    
    # 进程信息
    echo ""
    echo -e "${BLUE}=== 进程信息 ===${NC}"
    local pid=$(pgrep -f hysteria-server)
    if [[ -n "$pid" ]]; then
        echo -e "  进程ID: ${GREEN}$pid${NC}"
        show_service_metrics
    else
        echo -e "  进程状态: ${RED}未运行${NC}"
    fi
    
    # 显示连接统计
    if [[ -n "$pid" ]]; then
        echo ""
        show_connection_stats
    fi
    
    # 日志分析
    echo ""
    analyze_logs
}

# 服务操作增强函数
service_operation_with_validation() {
    local operation=$1
    local service_name=${2:-$SERVICE_NAME}
    
    echo -e "${BLUE}执行服务操作: $operation${NC}"
    
    # 预检查
    if [[ "$operation" == "start" || "$operation" == "restart" ]]; then
        if [[ ! -f "$CONFIG_PATH" ]]; then
            echo -e "${RED}错误: 配置文件不存在，无法启动服务${NC}"
            return 1
        fi
        
        # 配置文件语法检查
        if command -v hysteria >/dev/null; then
            echo "正在验证配置文件..."
            if ! hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
                echo -e "${RED}错误: 配置文件语法错误${NC}"
                echo "请修复配置文件后重试"
                return 1
            fi
            echo -e "${GREEN}配置文件验证通过${NC}"
        fi
    fi
    
    # 执行操作
    echo "正在执行 systemctl $operation $service_name..."
    
    if systemctl "$operation" "$service_name"; then
        echo -e "${GREEN}操作成功: $operation${NC}"
        
        # 等待服务稳定
        if [[ "$operation" == "start" || "$operation" == "restart" ]]; then
            echo "等待服务启动..."
            local wait_count=0
            local max_wait=10
            
            while [[ $wait_count -lt $max_wait ]]; do
                if systemctl is-active --quiet "$service_name"; then
                    echo -e "${GREEN}服务启动成功${NC}"
                    break
                fi
                sleep 1
                ((wait_count++))
                echo -n "."
            done
            
            if [[ $wait_count -eq $max_wait ]]; then
                echo -e "\n${YELLOW}服务启动可能较慢，请稍后检查状态${NC}"
            fi
            
            # 端口检查
            if [[ -f "$CONFIG_PATH" ]]; then
                local port=$(grep -E "^listen:" "$CONFIG_PATH" | awk '{print $2}' | sed 's/://' || echo "443")
                echo "检查端口 $port 监听状态..."
                
                local port_wait=0
                while [[ $port_wait -lt 5 ]]; do
                    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                        echo -e "${GREEN}端口 $port 监听正常${NC}"
                        break
                    fi
                    sleep 1
                    ((port_wait++))
                done
                
                if [[ $port_wait -eq 5 ]]; then
                    echo -e "${YELLOW}警告: 端口 $port 可能未正常监听${NC}"
                fi
            fi
        fi
        
        return 0
    else
        echo -e "${RED}操作失败: $operation${NC}"
        
        # 显示失败原因
        local status_output=$(systemctl status "$service_name" --no-pager -l)
        echo "服务状态:"
        echo "$status_output" | head -10
        
        return 1
    fi
}

# 启动服务（优化版本）
start_service() {
    echo -e "${BLUE}启动 Hysteria2 服务...${NC}"
    
    if ! check_hysteria_installed; then
        echo -e "${RED}错误: Hysteria2 未安装${NC}"
        return 1
    fi
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}服务已在运行中${NC}"
        show_service_metrics
        return 0
    fi
    
    service_operation_with_validation "start"
}

# 停止服务（优化版本）
stop_service() {
    echo -e "${BLUE}停止 Hysteria2 服务...${NC}"
    
    if ! systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}服务未在运行${NC}"
        return 0
    fi
    
    # 显示停止前的连接统计
    echo "停止前连接统计:"
    show_connection_stats
    
    service_operation_with_validation "stop"
    
    # 确认服务已完全停止
    local stop_wait=0
    while [[ $stop_wait -lt 10 ]]; do
        if ! systemctl is-active --quiet $SERVICE_NAME; then
            echo -e "${GREEN}服务已完全停止${NC}"
            break
        fi
        sleep 1
        ((stop_wait++))
        echo -n "."
    done
    
    if [[ $stop_wait -eq 10 ]]; then
        echo -e "\n${YELLOW}服务停止可能较慢${NC}"
    fi
}

# 重启服务（优化版本）
restart_service() {
    echo -e "${BLUE}重启 Hysteria2 服务...${NC}"
    
    if ! check_hysteria_installed; then
        echo -e "${RED}错误: Hysteria2 未安装${NC}"
        return 1
    fi
    
    # 显示重启前状态
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo "重启前状态:"
        show_service_metrics
    fi
    
    service_operation_with_validation "restart"
}

# 启用开机自启（优化版本）
enable_service() {
    echo -e "${BLUE}启用开机自启...${NC}"
    
    if systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}开机自启已启用${NC}"
        return 0
    fi
    
    if systemctl enable $SERVICE_NAME; then
        echo -e "${GREEN}开机自启启用成功${NC}"
        
        # 验证启用状态
        if systemctl is-enabled --quiet $SERVICE_NAME; then
            echo -e "${GREEN}验证: 开机自启已正确启用${NC}"
        else
            echo -e "${YELLOW}警告: 启用状态验证失败${NC}"
        fi
    else
        echo -e "${RED}开机自启启用失败${NC}"
    fi
}

# 禁用开机自启（优化版本）
disable_service() {
    echo -e "${BLUE}禁用开机自启...${NC}"
    
    if ! systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}开机自启未启用${NC}"
        return 0
    fi
    
    if systemctl disable $SERVICE_NAME; then
        echo -e "${GREEN}开机自启禁用成功${NC}"
        
        # 验证禁用状态
        if ! systemctl is-enabled --quiet $SERVICE_NAME; then
            echo -e "${GREEN}验证: 开机自启已正确禁用${NC}"
        else
            echo -e "${YELLOW}警告: 禁用状态验证失败${NC}"
        fi
    else
        echo -e "${RED}开机自启禁用失败${NC}"
    fi
}

# 查看实时日志（优化版本）
view_live_logs() {
    echo -e "${BLUE}查看实时日志 (按 Ctrl+C 退出)...${NC}"
    echo ""
    echo -e "${YELLOW}提示: 可以使用以下快捷键:${NC}"
    echo "  Ctrl+C - 退出"
    echo "  Shift+PageUp/PageDown - 上下滚动"
    echo ""
    
    # 显示最近几行日志作为上下文
    echo -e "${BLUE}最近的日志上下文:${NC}"
    journalctl -u $SERVICE_NAME -n 5 --no-pager
    echo ""
    echo -e "${BLUE}=== 实时日志开始 ===${NC}"
    
    journalctl -f -u $SERVICE_NAME
}

# 查看历史日志（优化版本）
view_history_logs() {
    echo -e "${BLUE}查看历史日志${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 最近 50 行"
    echo -e "${GREEN}2.${NC} 最近 100 行"
    echo -e "${GREEN}3.${NC} 最近 500 行"
    echo -e "${GREEN}4.${NC} 今天的日志"
    echo -e "${GREEN}5.${NC} 昨天的日志"
    echo -e "${GREEN}6.${NC} 最近1小时"
    echo -e "${GREEN}7.${NC} 最近24小时"
    echo -e "${GREEN}8.${NC} 自定义行数"
    echo -e "${GREEN}9.${NC} 按时间范围"
    echo -e "${GREEN}10.${NC} 仅显示错误"
    echo ""
    echo -n -e "${BLUE}请选择 [1-10]: ${NC}"
    read -r choice
    
    case $choice in
        1)
            echo -e "${BLUE}最近 50 行日志:${NC}"
            journalctl --no-pager -n 50 -u $SERVICE_NAME
            ;;
        2)
            echo -e "${BLUE}最近 100 行日志:${NC}"
            journalctl --no-pager -n 100 -u $SERVICE_NAME
            ;;
        3)
            echo -e "${BLUE}最近 500 行日志:${NC}"
            journalctl --no-pager -n 500 -u $SERVICE_NAME
            ;;
        4)
            echo -e "${BLUE}今天的日志:${NC}"
            journalctl --no-pager --since today -u $SERVICE_NAME
            ;;
        5)
            echo -e "${BLUE}昨天的日志:${NC}"
            journalctl --no-pager --since yesterday --until today -u $SERVICE_NAME
            ;;
        6)
            echo -e "${BLUE}最近1小时日志:${NC}"
            journalctl --no-pager --since "1 hour ago" -u $SERVICE_NAME
            ;;
        7)
            echo -e "${BLUE}最近24小时日志:${NC}"
            journalctl --no-pager --since "24 hours ago" -u $SERVICE_NAME
            ;;
        8)
            echo -n -e "${BLUE}请输入行数: ${NC}"
            read -r lines
            if [[ "$lines" =~ ^[0-9]+$ ]]; then
                echo -e "${BLUE}最近 $lines 行日志:${NC}"
                journalctl --no-pager -n "$lines" -u $SERVICE_NAME
            else
                echo -e "${RED}无效的行数${NC}"
            fi
            ;;
        9)
            echo -n -e "${BLUE}开始时间 (例: 2024-01-01 00:00): ${NC}"
            read -r start_time
            echo -n -e "${BLUE}结束时间 (例: 2024-01-02 00:00, 留空为现在): ${NC}"
            read -r end_time
            
            local cmd="journalctl --no-pager --since \"$start_time\""
            if [[ -n "$end_time" ]]; then
                cmd="$cmd --until \"$end_time\""
            fi
            cmd="$cmd -u $SERVICE_NAME"
            
            echo -e "${BLUE}指定时间范围的日志:${NC}"
            eval "$cmd"
            ;;
        10)
            echo -e "${BLUE}仅显示错误日志:${NC}"
            journalctl --no-pager -u $SERVICE_NAME | grep -i "error\|fail\|fatal"
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
}

# 配置文件操作（优化版本）
config_operations() {
    while true; do
        echo -e "${BLUE}配置文件操作${NC}"
        echo ""
        
        if [[ -f "$CONFIG_PATH" ]]; then
            local config_info="存在 ($(du -h "$CONFIG_PATH" | cut -f1))"
            echo -e "当前配置文件: ${GREEN}$config_info${NC}"
        else
            echo -e "当前配置文件: ${RED}不存在${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}1.${NC} 查看配置文件"
        echo -e "${GREEN}2.${NC} 编辑配置文件"
        echo -e "${GREEN}3.${NC} 验证配置文件"
        echo -e "${GREEN}4.${NC} 备份配置文件"
        echo -e "${GREEN}5.${NC} 恢复配置文件"
        echo -e "${GREEN}6.${NC} 比较配置差异"
        echo -e "${GREEN}7.${NC} 配置文件权限修复"
        echo -e "${GREEN}8.${NC} 生成示例配置"
        echo -e "${RED}0.${NC} 返回"
        echo ""
        echo -n -e "${BLUE}请选择 [0-8]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                if [[ -f "$CONFIG_PATH" ]]; then
                    echo -e "${BLUE}当前配置文件内容:${NC}"
                    echo "文件路径: $CONFIG_PATH"
                    echo "文件大小: $(du -h "$CONFIG_PATH" | cut -f1)"
                    echo "修改时间: $(stat -c %y "$CONFIG_PATH" 2>/dev/null | cut -d. -f1)"
                    echo ""
                    echo "--- 配置内容 ---"
                    cat "$CONFIG_PATH"
                    echo "--- 配置结束 ---"
                else
                    echo -e "${RED}配置文件不存在${NC}"
                fi
                ;;
            2)
                if [[ -f "$CONFIG_PATH" ]]; then
                    echo -e "${BLUE}编辑配置文件...${NC}"
                    echo -e "${YELLOW}提示: 建议在编辑前备份配置文件${NC}"
                    echo -n -e "${BLUE}是否先创建备份? [Y/n]: ${NC}"
                    read -r backup_first
                    
                    if [[ ! $backup_first =~ ^[Nn]$ ]]; then
                        local backup_file="$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
                        cp "$CONFIG_PATH" "$backup_file"
                        echo -e "${GREEN}已备份到: $backup_file${NC}"
                    fi
                    
                    # 选择编辑器
                    local editor="nano"
                    if command -v vim >/dev/null; then
                        echo -n -e "${BLUE}选择编辑器 (nano/vim) [nano]: ${NC}"
                        read -r editor_choice
                        [[ -n "$editor_choice" ]] && editor="$editor_choice"
                    fi
                    
                    "$editor" "$CONFIG_PATH"
                    echo -e "${GREEN}编辑完成${NC}"
                    
                    # 自动验证
                    if command -v hysteria >/dev/null; then
                        echo "正在验证配置文件语法..."
                        if hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
                            echo -e "${GREEN}配置文件语法正确${NC}"
                        else
                            echo -e "${RED}配置文件语法错误${NC}"
                            echo -n -e "${BLUE}是否恢复备份? [y/N]: ${NC}"
                            read -r restore_backup
                            if [[ $restore_backup =~ ^[Yy]$ ]] && [[ -f "$backup_file" ]]; then
                                cp "$backup_file" "$CONFIG_PATH"
                                echo -e "${GREEN}已恢复备份${NC}"
                            fi
                        fi
                    fi
                    
                    echo -n -e "${BLUE}是否重启服务以应用更改? [y/N]: ${NC}"
                    read -r restart
                    if [[ $restart =~ ^[Yy]$ ]]; then
                        service_operation_with_validation "restart"
                    fi
                else
                    echo -e "${RED}配置文件不存在${NC}"
                fi
                ;;
            3)
                if [[ -f "$CONFIG_PATH" ]]; then
                    echo -e "${BLUE}验证配置文件...${NC}"
                    echo "文件路径: $CONFIG_PATH"
                    
                    # 基本检查
                    echo -n "文件可读性: "
                    if [[ -r "$CONFIG_PATH" ]]; then
                        echo -e "${GREEN}可读${NC}"
                    else
                        echo -e "${RED}不可读${NC}"
                    fi
                    
                    echo -n "文件大小: "
                    local file_size=$(stat -c%s "$CONFIG_PATH" 2>/dev/null)
                    if [[ $file_size -gt 0 ]]; then
                        echo -e "${GREEN}$file_size 字节${NC}"
                    else
                        echo -e "${RED}空文件${NC}"
                    fi
                    
                    # 语法检查
                    echo -n "语法检查: "
                    if command -v hysteria >/dev/null; then
                        if hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
                            echo -e "${GREEN}通过${NC}"
                        else
                            echo -e "${RED}失败${NC}"
                            echo "详细错误:"
                            hysteria server --config "$CONFIG_PATH" --check 2>&1 | head -5
                        fi
                    else
                        echo -e "${YELLOW}无法验证 (hysteria 命令不可用)${NC}"
                    fi
                    
                    # 配置项检查
                    echo ""
                    echo "配置项检查:"
                    
                    local has_listen=$(grep -q "^listen:" "$CONFIG_PATH" && echo "yes" || echo "no")
                    local has_auth=$(grep -q "^auth:" "$CONFIG_PATH" && echo "yes" || echo "no")
                    local has_tls=$(grep -q "^tls:\|^acme:" "$CONFIG_PATH" && echo "yes" || echo "no")
                    local has_obfs=$(grep -q "^obfs:" "$CONFIG_PATH" && echo "yes" || echo "no")
                    
                    echo "  监听配置: $([[ "$has_listen" == "yes" ]] && echo -e "${GREEN}已配置${NC}" || echo -e "${YELLOW}使用默认${NC}")"
                    echo "  认证配置: $([[ "$has_auth" == "yes" ]] && echo -e "${GREEN}已配置${NC}" || echo -e "${RED}未配置${NC}")"
                    echo "  证书配置: $([[ "$has_tls" == "yes" ]] && echo -e "${GREEN}已配置${NC}" || echo -e "${RED}未配置${NC}")"
                    echo "  混淆配置: $([[ "$has_obfs" == "yes" ]] && echo -e "${GREEN}已启用${NC}" || echo -e "${BLUE}未启用${NC}")"
                    
                else
                    echo -e "${RED}配置文件不存在${NC}"
                fi
                ;;
            4)
                if [[ -f "$CONFIG_PATH" ]]; then
                    local backup_file="$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
                    if cp "$CONFIG_PATH" "$backup_file"; then
                        # 生成校验和
                        if command -v sha256sum >/dev/null; then
                            sha256sum "$CONFIG_PATH" > "${backup_file}.checksum"
                        fi
                        echo -e "${GREEN}配置文件已备份到: $backup_file${NC}"
                    else
                        echo -e "${RED}备份失败${NC}"
                    fi
                else
                    echo -e "${RED}配置文件不存在${NC}"
                fi
                ;;
            5)
                echo -e "${BLUE}可用的备份文件:${NC}"
                local backups=($(ls "$CONFIG_PATH".backup.* 2>/dev/null | sort -r))
                if [[ ${#backups[@]} -eq 0 ]]; then
                    echo -e "${RED}没有找到备份文件${NC}"
                else
                    for i in "${!backups[@]}"; do
                        local backup="${backups[$i]}"
                        local backup_time=$(stat -c %y "$backup" 2>/dev/null | cut -d. -f1)
                        local backup_size=$(du -h "$backup" | cut -f1)
                        echo "$((i+1)). $(basename "$backup") [$backup_size] ($backup_time)"
                    done
                    
                    echo ""
                    echo -n -e "${BLUE}请选择要恢复的备份 [1-${#backups[@]}]: ${NC}"
                    read -r backup_choice
                    
                    if [[ "$backup_choice" =~ ^[0-9]+$ ]] && [[ $backup_choice -ge 1 ]] && [[ $backup_choice -le ${#backups[@]} ]]; then
                        local selected_backup="${backups[$((backup_choice-1))]}"
                        
                        # 验证备份完整性
                        local checksum_file="${selected_backup}.checksum"
                        if [[ -f "$checksum_file" ]]; then
                            echo "验证备份完整性..."
                            if sha256sum -c "$checksum_file" >/dev/null 2>&1; then
                                echo -e "${GREEN}备份完整性验证通过${NC}"
                            else
                                echo -e "${YELLOW}警告: 备份完整性验证失败${NC}"
                                echo -n -e "${BLUE}是否继续恢复? [y/N]: ${NC}"
                                read -r continue_restore
                                [[ ! $continue_restore =~ ^[Yy]$ ]] && continue
                            fi
                        fi
                        
                        echo -n -e "${BLUE}确定要恢复此备份吗? [y/N]: ${NC}"
                        read -r confirm_restore
                        if [[ $confirm_restore =~ ^[Yy]$ ]]; then
                            # 先备份当前配置
                            local current_backup="$CONFIG_PATH.current.$(date +%Y%m%d_%H%M%S)"
                            cp "$CONFIG_PATH" "$current_backup"
                            
                            if cp "$selected_backup" "$CONFIG_PATH"; then
                                echo -e "${GREEN}配置文件已恢复${NC}"
                                echo -e "${BLUE}当前配置已备份到: $current_backup${NC}"
                                
                                # 验证恢复的配置
                                if command -v hysteria >/dev/null; then
                                    if hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
                                        echo -e "${GREEN}恢复的配置文件语法正确${NC}"
                                    else
                                        echo -e "${RED}恢复的配置文件语法错误${NC}"
                                    fi
                                fi
                            else
                                echo -e "${RED}配置恢复失败${NC}"
                            fi
                        fi
                    else
                        echo -e "${RED}无效选择${NC}"
                    fi
                fi
                ;;
            6)
                echo -e "${BLUE}比较配置差异${NC}"
                local backups=($(ls "$CONFIG_PATH".backup.* 2>/dev/null | sort -r))
                if [[ ${#backups[@]} -eq 0 ]]; then
                    echo -e "${RED}没有找到备份文件进行比较${NC}"
                else
                    echo "选择要比较的备份文件:"
                    for i in "${!backups[@]}"; do
                        echo "$((i+1)). $(basename "${backups[$i]}")"
                    done
                    
                    echo -n -e "${BLUE}请选择 [1-${#backups[@]}]: ${NC}"
                    read -r compare_choice
                    
                    if [[ "$compare_choice" =~ ^[0-9]+$ ]] && [[ $compare_choice -ge 1 ]] && [[ $compare_choice -le ${#backups[@]} ]]; then
                        local selected_backup="${backups[$((compare_choice-1))]}"
                        echo -e "${BLUE}比较当前配置与备份的差异:${NC}"
                        echo ""
                        
                        if command -v diff >/dev/null; then
                            diff -u "$selected_backup" "$CONFIG_PATH" || echo -e "${GREEN}文件相同${NC}"
                        else
                            echo -e "${YELLOW}diff 命令不可用，无法比较${NC}"
                        fi
                    fi
                fi
                ;;
            7)
                if [[ -f "$CONFIG_PATH" ]]; then
                    echo -e "${BLUE}修复配置文件权限...${NC}"
                    
                    local current_perms=$(stat -c %a "$CONFIG_PATH" 2>/dev/null)
                    echo "当前权限: $current_perms"
                    echo "推荐权限: 600"
                    
                    if chmod 600 "$CONFIG_PATH"; then
                        echo -e "${GREEN}权限修复完成${NC}"
                        
                        # 修复所有者
                        if id "hysteria" &>/dev/null; then
                            echo "修复文件所有者为 hysteria..."
                            chown hysteria:hysteria "$CONFIG_PATH" 2>/dev/null
                        fi
                    else
                        echo -e "${RED}权限修复失败${NC}"
                    fi
                else
                    echo -e "${RED}配置文件不存在${NC}"
                fi
                ;;
            8)
                echo -e "${BLUE}生成示例配置${NC}"
                echo -n -e "${BLUE}是否覆盖现有配置文件? [y/N]: ${NC}"
                read -r overwrite_config
                
                if [[ ! $overwrite_config =~ ^[Yy]$ ]] && [[ -f "$CONFIG_PATH" ]]; then
                    echo -e "${YELLOW}示例配置将保存到: ${CONFIG_PATH}.example${NC}"
                    local example_path="${CONFIG_PATH}.example"
                else
                    local example_path="$CONFIG_PATH"
                    [[ -f "$CONFIG_PATH" ]] && cp "$CONFIG_PATH" "$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
                fi
                
                cat > "$example_path" << 'EOF'
# Hysteria2 示例配置文件
# 更多配置选项请参考: https://hysteria.network/docs/

listen: :443

# 认证配置
auth:
  type: password
  password: your-password-here

# 证书配置 (选择其一)
# 方式1: ACME 自动证书
acme:
  domains:
    - your-domain.com
  email: your-email@example.com

# 方式2: 手动证书
# tls:
#   cert: /etc/hysteria/server.crt
#   key: /etc/hysteria/server.key

# 伪装网站
masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com/
    rewriteHost: true

# 混淆配置 (可选)
# obfs:
#   type: salamander
#   salamander:
#     password: your-obfs-password

# 带宽限制 (可选)
# bandwidth:
#   up: 100 mbps
#   down: 100 mbps

# 忽略客户端带宽 (可选)
# ignoreClientBandwidth: false

# UDP 转发超时 (可选)
# udpIdleTimeout: 60s

# 禁用 UDP (可选)
# disableUDP: false

# 日志级别 (可选)
# resolver:
#   type: udp
#   tcp:
#     addr: 8.8.8.8:53
#     timeout: 4s
#   udp:
#     addr: 8.8.8.8:53
#     timeout: 4s

# 自定义出站 (可选)
# outbounds:
#   - name: my-outbound
#     type: direct

# ACL 规则 (可选)
# acl:
#   file: /etc/hysteria/acl.txt
EOF
                
                echo -e "${GREEN}示例配置已生成: $example_path${NC}"
                echo -e "${YELLOW}请根据您的需求修改配置文件${NC}"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
        
        if [[ $choice -ne 0 ]]; then
            echo ""
        fi
    done
}

# 服务诊断（新增功能）
service_diagnostics() {
    echo -e "${BLUE}服务诊断${NC}"
    echo ""
    
    local issues=0
    local warnings=0
    
    echo -e "${CYAN}=== 诊断开始 ===${NC}"
    echo ""
    
    # 1. Hysteria 安装检查
    echo -n "检查 Hysteria 安装状态... "
    if command -v hysteria >/dev/null; then
        echo -e "${GREEN}✓${NC}"
        local version=$(hysteria version 2>/dev/null | head -1 || echo "未知版本")
        echo "  版本: $version"
    else
        echo -e "${RED}✗${NC}"
        echo "  Hysteria 未安装"
        ((issues++))
    fi
    
    # 2. 配置文件检查
    echo -n "检查配置文件... "
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "${GREEN}✓${NC}"
        
        # 权限检查
        local perms=$(stat -c %a "$CONFIG_PATH" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            echo "  权限: ${GREEN}正确 ($perms)${NC}"
        else
            echo "  权限: ${YELLOW}建议修改为 600 (当前: $perms)${NC}"
            ((warnings++))
        fi
        
        # 语法检查
        if command -v hysteria >/dev/null; then
            if hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
                echo "  语法: ${GREEN}正确${NC}"
            else
                echo "  语法: ${RED}错误${NC}"
                ((issues++))
            fi
        fi
    else
        echo -e "${RED}✗${NC}"
        echo "  配置文件不存在: $CONFIG_PATH"
        ((issues++))
    fi
    
    # 3. 服务状态检查
    echo -n "检查服务状态... "
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}运行中${NC}"
        
        # 检查端口监听
        local port=$(grep -E "^listen:" "$CONFIG_PATH" 2>/dev/null | awk '{print $2}' | sed 's/://' || echo "443")
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo "  端口 $port: ${GREEN}正在监听${NC}"
        else
            echo "  端口 $port: ${RED}未监听${NC}"
            ((issues++))
        fi
    else
        echo -e "${RED}未运行${NC}"
        ((warnings++))
    fi
    
    # 4. 防火墙检查
    echo -n "检查防火墙配置... "
    local firewall_ok=false
    local port=$(grep -E "^listen:" "$CONFIG_PATH" 2>/dev/null | awk '{print $2}' | sed 's/://' || echo "443")
    
    # 检查各种防火墙
    if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        if ufw status 2>/dev/null | grep -q "$port"; then
            firewall_ok=true
        fi
    elif command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
        if firewall-cmd --list-ports 2>/dev/null | grep -q "$port"; then
            firewall_ok=true
        fi
    else
        firewall_ok=true  # 没有活跃防火墙认为是OK的
    fi
    
    if $firewall_ok; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠${NC}"
        echo "  端口 $port 可能被防火墙阻挡"
        ((warnings++))
    fi
    
    # 5. 系统资源检查
    echo -n "检查系统资源... "
    local mem_available=$(free -m | awk '/^Mem:/ {print $7}')
    local disk_available=$(df / | tail -1 | awk '{print $4}')
    
    if [[ $mem_available -lt 100 ]]; then
        echo -e "${YELLOW}⚠${NC}"
        echo "  可用内存较低: ${mem_available}MB"
        ((warnings++))
    elif [[ $disk_available -lt 1048576 ]]; then  # 1GB in KB
        echo -e "${YELLOW}⚠${NC}"
        echo "  可用磁盘空间较低: $((disk_available/1024))MB"
        ((warnings++))
    else
        echo -e "${GREEN}✓${NC}"
    fi
    
    # 6. 网络连通性检查
    echo -n "检查网络连通性... "
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠${NC}"
        echo "  外网连接可能有问题"
        ((warnings++))
    fi
    
    # 7. 日志错误检查
    echo -n "检查最近的错误日志... "
    local recent_errors=$(journalctl -u $SERVICE_NAME --since "1 hour ago" --no-pager -q 2>/dev/null | grep -ic "error" || echo "0")
    
    if [[ $recent_errors -eq 0 ]]; then
        echo -e "${GREEN}✓${NC}"
    elif [[ $recent_errors -lt 5 ]]; then
        echo -e "${YELLOW}⚠${NC}"
        echo "  最近1小时有 $recent_errors 个错误"
        ((warnings++))
    else
        echo -e "${RED}✗${NC}"
        echo "  最近1小时有 $recent_errors 个错误"
        ((issues++))
    fi
    
    # 诊断总结
    echo ""
    echo -e "${CYAN}=== 诊断总结 ===${NC}"
    if [[ $issues -eq 0 ]]; then
        if [[ $warnings -eq 0 ]]; then
            echo -e "${GREEN}✓ 系统健康，无问题发现${NC}"
        else
            echo -e "${YELLOW}⚠ 系统基本健康，发现 $warnings 个警告${NC}"
        fi
    else
        echo -e "${RED}✗ 发现 $issues 个问题和 $warnings 个警告${NC}"
        echo -e "${YELLOW}建议修复问题后重新检查${NC}"
    fi
    
    # 建议操作
    if [[ $issues -gt 0 || $warnings -gt 0 ]]; then
        echo ""
        echo -e "${BLUE}建议操作:${NC}"
        
        if [[ $issues -gt 0 ]]; then
            echo -e "${RED}紧急修复:${NC}"
            if ! command -v hysteria >/dev/null; then
                echo "- 安装 Hysteria2"
            fi
            if [[ ! -f "$CONFIG_PATH" ]]; then
                echo "- 生成配置文件"
            fi
            if command -v hysteria >/dev/null && ! hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
                echo "- 修复配置文件语法错误"
            fi
        fi
        
        if [[ $warnings -gt 0 ]]; then
            echo -e "${YELLOW}优化建议:${NC}"
            local perms=$(stat -c %a "$CONFIG_PATH" 2>/dev/null)
            if [[ -f "$CONFIG_PATH" && "$perms" != "600" ]]; then
                echo "- 修复配置文件权限: chmod 600 $CONFIG_PATH"
            fi
            if [[ $mem_available -lt 100 ]]; then
                echo "- 释放系统内存"
            fi
            if [[ ! $firewall_ok ]]; then
                echo "- 配置防火墙规则允许端口 $port"
            fi
        fi
    fi
    
    return $issues
}

# 主服务管理函数（优化版本）
manage_hysteria_service() {
    while true; do
        clear
        echo -e "${BLUE}Hysteria2 服务管理 - 优化版本${NC}"
        echo ""
        
        # 快速状态显示
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo -e "服务状态: ${GREEN}●${NC} 运行中"
            local pid=$(pgrep -f hysteria-server)
            if [[ -n "$pid" ]]; then
                local cpu=$(ps -p $pid -o %cpu= 2>/dev/null | awk '{print $1"%"}')
                local mem=$(ps -p $pid -o rss= 2>/dev/null | awk '{printf "%.0fMB", $1/1024}')
                echo -e "资源使用: CPU $cpu, 内存 $mem"
            fi
        else
            echo -e "服务状态: ${RED}●${NC} 已停止"
        fi
        
        if systemctl is-enabled --quiet $SERVICE_NAME; then
            echo -e "开机自启: ${GREEN}已启用${NC}"
        else
            echo -e "开机自启: ${RED}未启用${NC}"
        fi
        
        if [[ -f "$CONFIG_PATH" ]]; then
            echo -e "配置文件: ${GREEN}存在${NC}"
        else
            echo -e "配置文件: ${RED}不存在${NC}"
        fi
        
        echo ""
        echo -e "${YELLOW}服务操作:${NC}"
        echo -e "${GREEN}1.${NC} 启动服务"
        echo -e "${GREEN}2.${NC} 停止服务"
        echo -e "${GREEN}3.${NC} 重启服务"
        echo -e "${GREEN}4.${NC} 启用开机自启"
        echo -e "${GREEN}5.${NC} 禁用开机自启"
        echo ""
        echo -e "${YELLOW}状态监控:${NC}"
        echo -e "${GREEN}6.${NC} 查看详细状态"
        echo -e "${GREEN}7.${NC} 性能监控"
        echo -e "${GREEN}8.${NC} 连接统计"
        echo ""
        echo -e "${YELLOW}日志管理:${NC}"
        echo -e "${GREEN}9.${NC} 查看实时日志"
        echo -e "${GREEN}10.${NC} 查看历史日志"
        echo ""
        echo -e "${YELLOW}配置管理:${NC}"
        echo -e "${GREEN}11.${NC} 配置文件操作"
        echo -e "${GREEN}12.${NC} 服务诊断"
        echo ""
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-12]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                clear
                start_service
                echo ""
                ;;
            2)
                clear
                stop_service
                echo ""
                ;;
            3)
                clear
                restart_service
                echo ""
                ;;
            4)
                clear
                enable_service
                echo ""
                ;;
            5)
                clear
                disable_service
                echo ""
                ;;
            6)
                clear
                check_service_detailed
                echo ""
                ;;
            7)
                clear
                echo -e "${BLUE}性能监控${NC}"
                echo ""
                show_service_metrics
                echo ""
                ;;
            8)
                clear
                show_connection_stats
                echo ""
                ;;
            9)
                clear
                view_live_logs
                ;;
            10)
                clear
                view_history_logs
                echo ""
                ;;
            11)
                clear
                config_operations
                ;;
            12)
                clear
                service_diagnostics
                echo ""
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
