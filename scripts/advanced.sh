#!/bin/bash

# Hysteria2 进阶配置脚本 - 修复版本
# 修复配置文件路径和变量定义问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量定义
CONFIG_PATH="/etc/hysteria/hysteria.yaml"
SERVICE_NAME="hysteria-server"
CONFIG_DIR="/etc/hysteria"

# 初始化函数 - 检查和设置基本环境
init_environment() {
    # 检查 root 权限
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
        exit 1
    fi
    
    # 检查配置目录
    if [[ ! -d "$CONFIG_DIR" ]]; then
        echo -e "${BLUE}创建配置目录: $CONFIG_DIR${NC}"
        mkdir -p "$CONFIG_DIR"
    fi
    
    # 自动检测配置文件路径
    detect_config_file
    
    # 检查 Hysteria 是否已安装
    if ! command -v hysteria >/dev/null 2>&1; then
        echo -e "${YELLOW}警告: 未检测到 Hysteria 命令${NC}"
        echo "请确保 Hysteria 已正确安装"
    fi
}

# 自动检测配置文件
detect_config_file() {
    local possible_paths=(
        "/etc/hysteria/hysteria.yaml"
        "/etc/hysteria/config.yaml"
        "/etc/hysteria/server.yaml"
        "/opt/hysteria/hysteria.yaml"
        "/usr/local/etc/hysteria/hysteria.yaml"
    )
    
    echo -e "${BLUE}检测配置文件...${NC}"
    
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            CONFIG_PATH="$path"
            echo -e "${GREEN}找到配置文件: $CONFIG_PATH${NC}"
            return 0
        fi
    done
    
    echo -e "${YELLOW}未找到配置文件，使用默认路径: $CONFIG_PATH${NC}"
    return 1
}

# 创建默认配置文件
create_default_config() {
    echo -e "${BLUE}创建默认配置文件${NC}"
    
    cat > "$CONFIG_PATH" << EOF
# Hysteria2 服务器配置文件
# 生成时间: $(date)

listen: :443

# ACME 自动证书配置（推荐）
acme:
  domains:
    - your-domain.com
  email: your-email@example.com

# 认证配置
auth:
  type: password
  password: $(openssl rand -base64 32)

# 带宽限制（可选）
bandwidth:
  up: 1 gbps
  down: 1 gbps

# 忽略客户端带宽（可选）
ignoreClientBandwidth: false
EOF

    chmod 600 "$CONFIG_PATH"
    echo -e "${GREEN}默认配置文件已创建: $CONFIG_PATH${NC}"
    echo -e "${YELLOW}请编辑配置文件并设置正确的域名和邮箱${NC}"
}

# 安全检查函数
security_check() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
        return 1
    fi
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}配置文件不存在: $CONFIG_PATH${NC}"
        echo -n -e "${BLUE}是否创建默认配置文件? [y/N]: ${NC}"
        read -r create_config
        if [[ $create_config =~ ^[Yy]$ ]]; then
            create_default_config
            return 0
        else
            return 1
        fi
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
        if [[ -f "$CONFIG_DIR/obfs-info.conf" ]]; then
            echo -e "  配置文件: ${GREEN}存在${NC}"
        fi
    else
        echo -e "${BLUE}混淆配置:${NC} ${RED}未启用${NC}"
    fi
    
    # 端口跳跃
    if [[ -f "$CONFIG_DIR/port-hopping.conf" ]]; then
        echo -e "${BLUE}端口跳跃:${NC} ${GREEN}已配置${NC}"
        source "$CONFIG_DIR/port-hopping.conf"
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
    return 0
}

# 配置健康检查
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
    if [[ -f "$CONFIG_DIR/port-hopping.conf" ]]; then
        echo -e "${GREEN}✓ 端口跳跃配置存在${NC}"
        source "$CONFIG_DIR/port-hopping.conf"
        
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

# 配置备份函数
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

# 修改监听端口
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

# 查看当前进阶配置
view_advanced_config() {
    echo -e "${CYAN}当前进阶配置状态:${NC}"
    echo ""
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}配置文件不存在: $CONFIG_PATH${NC}"
        return 1
    fi
    
    security_check
}

# 主进阶配置函数
advanced_configuration() {
    # 初始化环境
    init_environment
    
    while true; do
        clear
        echo -e "${BLUE}Hysteria2 进阶配置 - 修复版本${NC}"
        echo ""
        
        # 显示系统状态
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo -e "服务状态: ${GREEN}运行中${NC}"
        else
            echo -e "服务状态: ${RED}已停止${NC}"
        fi
        
        if [[ -f "$CONFIG_PATH" ]]; then
            local config_size=$(du -h "$CONFIG_PATH" | cut -f1)
            echo -e "配置文件: ${GREEN}存在${NC} ($config_size) - $CONFIG_PATH"
        else
            echo -e "配置文件: ${RED}不存在${NC} - $CONFIG_PATH"
        fi
        
        echo ""
        echo -e "${YELLOW}配置选项:${NC}"
        echo -e "${GREEN}1.${NC} 修改监听端口"
        echo -e "${GREEN}2.${NC} 查看配置状态"
        echo -e "${GREEN}3.${NC} 配置健康检查"
        echo -e "${GREEN}4.${NC} 重新检测配置文件"
        echo -e "${GREEN}5.${NC} 创建默认配置文件"
        echo ""
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-5]: ${NC}"
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
                view_advanced_config
                echo ""
                read -p "按回车键继续..."
                ;;
            3)
                clear
                health_check
                echo ""
                read -p "按回车键继续..."
                ;;
            4)
                clear
                echo -e "${BLUE}重新检测配置文件...${NC}"
                detect_config_file
                echo ""
                read -p "按回车键继续..."
                ;;
            5)
                clear
                if [[ -f "$CONFIG_PATH" ]]; then
                    echo -e "${YELLOW}配置文件已存在: $CONFIG_PATH${NC}"
                    echo -n -e "${BLUE}是否覆盖现有配置? [y/N]: ${NC}"
                    read -r overwrite
                    if [[ $overwrite =~ ^[Yy]$ ]]; then
                        create_default_config
                    else
                        echo -e "${BLUE}取消创建${NC}"
                    fi
                else
                    create_default_config
                fi
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

# 如果脚本被直接执行，运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    advanced_configuration
fi
