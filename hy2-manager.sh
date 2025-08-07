#!/bin/bash

# Hysteria2 配置管理脚本
# 版本: 1.1.0
# 作者: Hysteria2 Manager

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 错误处理函数
error_exit() {
    echo -e "${RED}错误: $1${NC}" >&2
    exit "${2:-1}"
}

# 脚本目录处理 - 改进符号链接检测
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    local dir
    
    # 处理符号链接
    while [[ -L "$source" ]]; do
        dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    
    # 如果脚本在 /usr/local/bin 中运行，假设安装在 /opt/s-hy2
    if [[ "$dir" == "/usr/local/bin" ]]; then
        dir="/opt/s-hy2"
    fi
    
    echo "$dir"
}

SCRIPT_DIR="$(get_script_dir)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# 配置文件路径
CONFIG_PATH="/etc/hysteria/config.yaml"
SERVER_DOMAIN_CONFIG="/etc/hysteria/server-domain.conf"
SERVICE_NAME="hysteria-server.service"

# 日志记录函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "此脚本需要 root 权限运行，请使用 sudo 运行此脚本"
    fi
}

# 检查脚本文件完整性
check_script_integrity() {
    local missing_scripts=()
    
    # 检查必需的脚本文件
    local required_scripts=(
        "install.sh"
        "config.sh"
        "service.sh"
        "domain-test.sh"
        "node-info.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$SCRIPTS_DIR/$script" ]]; then
            missing_scripts+=("$script")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_warn "检测到缺失的脚本文件:"
        for script in "${missing_scripts[@]}"; do
            echo "  - $script"
        done
        echo ""
        echo "这可能影响某些功能的正常使用"
        echo ""
    fi
}

# 打印标题
print_header() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}           Hysteria2 配置管理脚本 v1.1.0${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# 打印菜单
print_menu() {
    echo -e "${YELLOW}请选择操作:${NC}"
    echo ""
    echo -e "${GREEN} 1.${NC} 安装 Hysteria2"
    echo -e "${GREEN} 2.${NC} 快速配置"
    echo -e "${GREEN} 3.${NC} 手动配置"
    echo -e "${GREEN} 4.${NC} 修改配置"
    echo -e "${GREEN} 5.${NC} 域名管理"
    echo -e "${GREEN} 6.${NC} 证书管理"
    echo -e "${GREEN} 7.${NC} 服务管理"
    echo -e "${GREEN} 8.${NC} 节点信息"
    echo -e "${GREEN} 9.${NC} 查看日志"
    echo -e "${GREEN}10.${NC} 卸载服务"
    echo -e "${GREEN}11.${NC} 关于脚本"
    echo -e "${RED} 0.${NC} 退出"
    echo ""
    echo -n -e "${BLUE}请输入选项 [0-11]: ${NC}"
}

# 检查 Hysteria2 是否已安装
check_hysteria_installed() {
    command -v hysteria &> /dev/null
}

# 检查服务状态
check_service_status() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✅ 运行中${NC}"
        return 0
    elif systemctl is-enabled --quiet "$SERVICE_NAME"; then
        echo -e "${YELLOW}⏸️  已启用但未运行${NC}"
        return 1
    else
        echo -e "${RED}❌ 未启用${NC}"
        return 2
    fi
}

# 显示系统信息
show_system_info() {
    local server_ip
    server_ip=$(get_server_ip)
    local server_domain
    server_domain=$(get_server_domain)
    
    echo -e "${CYAN}系统信息:${NC}"
    echo "服务器IP: ${server_ip:-未知}"
    if [[ -n "$server_domain" ]]; then
        echo "服务器域名: $server_domain"
    fi
    echo "系统: $(get_system_info)"
    echo ""
}

# 获取系统信息
get_system_info() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${PRETTY_NAME:-$NAME $VERSION_ID}"
    else
        echo "未知系统"
    fi
}

# 显示当前状态
show_status() {
    show_system_info
    
    echo -e "${CYAN}Hysteria2 状态:${NC}"
    if check_hysteria_installed; then
        echo -e "程序状态: ${GREEN}✅ 已安装${NC}"
        echo -n "服务状态: "
        check_service_status
        if [[ -f "$CONFIG_PATH" ]]; then
            echo -e "配置文件: ${GREEN}✅ 存在${NC}"
        else
            echo -e "配置文件: ${RED}❌ 不存在${NC}"
        fi
    else
        echo -e "程序状态: ${RED}❌ 未安装${NC}"
    fi
    echo ""
}

# 安全地执行脚本
safe_source_script() {
    local script_path="$1"
    local script_name="$2"
    
    if [[ -f "$script_path" ]]; then
        log_info "加载 $script_name..."
        # shellcheck source=/dev/null
        source "$script_path" || {
            log_error "$script_name 加载失败"
            return 1
        }
        return 0
    else
        log_error "$script_name 不存在: $script_path"
        echo ""
        echo "可能的解决方案:"
        echo "1. 重新运行安装脚本"
        echo "2. 检查脚本文件是否完整"
        echo ""
        return 1
    fi
}

# 等待用户确认
wait_for_user() {
    echo ""
    read -p "按回车键继续..." -r
}

# 安装 Hysteria2
install_hysteria() {
    log_info "准备安装 Hysteria2..."
    
    if safe_source_script "$SCRIPTS_DIR/install.sh" "安装脚本"; then
        install_hysteria2
    fi
    wait_for_user
}

# 一键快速配置
quick_config() {
    log_info "准备执行一键快速配置..."
    
    if ! check_hysteria_installed; then
        log_error "Hysteria2 未安装，请先安装"
        wait_for_user
        return
    fi
    
    if safe_source_script "$SCRIPTS_DIR/config.sh" "配置脚本"; then
        quick_setup_hysteria
    fi
}

# 手动配置
manual_config() {
    log_info "准备执行手动配置..."
    
    if ! check_hysteria_installed; then
        log_error "Hysteria2 未安装，请先安装"
        wait_for_user
        return
    fi
    
    if safe_source_script "$SCRIPTS_DIR/config.sh" "配置脚本"; then
        generate_hysteria_config
    fi
}

# 管理服务
manage_service() {
    log_info "准备进入服务管理..."
    
    if ! check_hysteria_installed; then
        log_error "Hysteria2 未安装，请先安装"
        wait_for_user
        return
    fi
    
    if safe_source_script "$SCRIPTS_DIR/service.sh" "服务管理脚本"; then
        manage_hysteria_service
    fi
}

# 查看日志 - 改进版本
view_logs() {
    log_info "查看 Hysteria2 服务日志..."
    
    if ! systemctl list-units --type=service | grep -q "$SERVICE_NAME"; then
        log_error "Hysteria2 服务不存在"
        wait_for_user
        return
    fi
    
    echo ""
    echo -e "${CYAN}=== 最近 50 行日志 ===${NC}"
    journalctl --no-pager -n 50 -u "$SERVICE_NAME" --no-hostname
    
    echo ""
    echo -e "${YELLOW}日志选项:${NC}"
    echo "1. 查看实时日志"
    echo "2. 查看完整日志"
    echo "3. 查看错误日志"
    echo "0. 返回"
    echo ""
    echo -n -e "${BLUE}请选择 [0-3]: ${NC}"
    read -r choice
    
    case $choice in
        1)
            echo -e "${BLUE}实时日志 (按 Ctrl+C 退出):${NC}"
            journalctl -f -u "$SERVICE_NAME" --no-hostname
            ;;
        2)
            echo -e "${BLUE}完整日志:${NC}"
            journalctl --no-pager -u "$SERVICE_NAME" --no-hostname | less
            ;;
        3)
            echo -e "${BLUE}错误日志:${NC}"
            journalctl --no-pager -p err -u "$SERVICE_NAME" --no-hostname
            wait_for_user
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
}

# 域名管理 - 重构版本，分离ACME域名和伪装域名
domain_management() {
    while true; do
        clear
        echo -e "${CYAN}=== 域名管理 ===${NC}"
        echo ""

        # 显示当前域名配置状态
        echo -e "${YELLOW}当前域名配置状态:${NC}"
        
        # 检查ACME域名
        if [[ -f "$SERVER_DOMAIN_CONFIG" ]]; then
            local acme_domain
            acme_domain=$(cat "$SERVER_DOMAIN_CONFIG")
            echo -e "ACME域名: ${GREEN}$acme_domain${NC}"
        else
            echo -e "ACME域名: ${YELLOW}未配置${NC}"
        fi
        
        # 检查伪装域名
        local masquerade_domain=""
        if [[ -f "$CONFIG_PATH" ]]; then
            masquerade_domain=$(grep -A 3 "masquerade:" "$CONFIG_PATH" 2>/dev/null | grep "url:" | awk '{print $2}' | sed 's|https\?://||' | sed 's|/.*||')
        fi
        
        if [[ -n "$masquerade_domain" ]]; then
            echo -e "伪装域名: ${GREEN}$masquerade_domain${NC}"
        else
            echo -e "伪装域名: ${YELLOW}未配置${NC}"
        fi

        echo ""
        echo -e "${YELLOW}域名管理选项:${NC}"
        echo -e "${GREEN}1.${NC} ACME域名管理"
        echo -e "${GREEN}2.${NC} 伪装域名管理"
        echo -e "${GREEN}3.${NC} 测试域名连通性"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-3]: ${NC}"
        read -r choice

        case $choice in
            1) acme_domain_management ;;
            2) masquerade_domain_management ;;
            3) test_domain_connectivity ;;
            0) break ;;
            *) 
                log_error "无效选项"
                sleep 1
                ;;
        esac
    done
}

# ACME域名管理
acme_domain_management() {
    while true; do
        clear
        echo -e "${CYAN}=== ACME域名管理 ===${NC}"
        echo ""
        echo -e "${BLUE}ACME域名用于申请SSL证书，需要域名解析到本服务器${NC}"
        echo ""

        # 显示当前配置
        if [[ -f "$SERVER_DOMAIN_CONFIG" ]]; then
            local current_domain
            current_domain=$(cat "$SERVER_DOMAIN_CONFIG")
            echo -e "${GREEN}当前ACME域名: $current_domain${NC}"
        else
            echo -e "${YELLOW}当前未配置ACME域名${NC}"
        fi

        echo ""
        echo -e "${YELLOW}ACME域名选项:${NC}"
        echo -e "${GREEN}1.${NC} 设置ACME域名"
        echo -e "${GREEN}2.${NC} 验证域名解析"
        echo -e "${GREEN}3.${NC} 删除ACME域名配置"
        echo -e "${RED}0.${NC} 返回上级菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-3]: ${NC}"
        read -r choice

        case $choice in
            1) set_server_domain ;;
            2) verify_domain_resolution ;;
            3) remove_server_domain ;;
            0) break ;;
            *) 
                log_error "无效选项"
                sleep 1
                ;;
        esac
    done
}

# 伪装域名管理
masquerade_domain_management() {
    while true; do
        clear
        echo -e "${CYAN}=== 伪装域名管理 ===${NC}"
        echo ""
        echo -e "${BLUE}伪装域名用于TLS握手，提高连接的隐蔽性${NC}"
        echo ""

        # 显示当前伪装域名配置
        local current_masquerade=""
        if [[ -f "$CONFIG_PATH" ]]; then
            current_masquerade=$(grep -A 3 "masquerade:" "$CONFIG_PATH" 2>/dev/null | grep "url:" | awk '{print $2}')
        fi
        
        if [[ -n "$current_masquerade" ]]; then
            echo -e "${GREEN}当前伪装域名: $current_masquerade${NC}"
        else
            echo -e "${YELLOW}当前未配置伪装域名${NC}"
        fi

        echo ""
        echo -e "${YELLOW}伪装域名选项:${NC}"
        echo -e "${GREEN}1.${NC} 手动设置伪装域名"
        echo -e "${GREEN}2.${NC} 自动测试选择最佳伪装域名"
        echo -e "${GREEN}3.${NC} 删除伪装域名配置"
        echo -e "${RED}0.${NC} 返回上级菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-3]: ${NC}"
        read -r choice

        case $choice in
            1) set_masquerade_domain ;;
            2) auto_select_masquerade_domain ;;
            3) remove_masquerade_domain ;;
            0) break ;;
            *) 
                log_error "无效选项"
                sleep 1
                ;;
        esac
    done
}

# 测试域名连通性
test_domain_connectivity() {
    echo ""
    echo -e "${BLUE}测试域名连通性${NC}"
    echo ""
    
    # 测试ACME域名
    if [[ -f "$SERVER_DOMAIN_CONFIG" ]]; then
        local acme_domain
        acme_domain=$(cat "$SERVER_DOMAIN_CONFIG")
        echo -e "${YELLOW}测试ACME域名: $acme_domain${NC}"
        verify_domain_resolution
    fi
    
    # 测试伪装域名
    if [[ -f "$CONFIG_PATH" ]]; then
        local masquerade_url
        masquerade_url=$(grep -A 3 "masquerade:" "$CONFIG_PATH" 2>/dev/null | grep "url:" | awk '{print $2}')
        if [[ -n "$masquerade_url" ]]; then
            echo ""
            echo -e "${YELLOW}测试伪装域名连通性: $masquerade_url${NC}"
            test_masquerade_connectivity "$masquerade_url"
        fi
    fi
    
    wait_for_user
}

# 设置伪装域名
set_masquerade_domain() {
    echo ""
    echo -e "${BLUE}设置伪装域名${NC}"
    echo "请输入伪装域名 URL (例如: https://www.bing.com):"
    echo -n -e "${YELLOW}伪装URL: ${NC}"
    read -r masquerade_url

    if [[ -z "$masquerade_url" ]]; then
        log_error "伪装URL不能为空"
        wait_for_user
        return
    fi

    # 验证URL格式
    if [[ ! "$masquerade_url" =~ ^https?:// ]]; then
        masquerade_url="https://$masquerade_url"
    fi

    # 备份配置文件
    if [[ -f "$CONFIG_PATH" ]]; then
        cp "$CONFIG_PATH" "$CONFIG_PATH.bak"
        
        # 更新或添加伪装域名配置
        if grep -q "masquerade:" "$CONFIG_PATH"; then
            # 更新现有配置
            sed -i "/masquerade:/,/url:/s|url:.*|url: $masquerade_url|" "$CONFIG_PATH"
        else
            # 添加新配置
            echo "" >> "$CONFIG_PATH"
            echo "masquerade:" >> "$CONFIG_PATH"
            echo "  type: proxy" >> "$CONFIG_PATH"
            echo "  url: $masquerade_url" >> "$CONFIG_PATH"
        fi
        
        log_success "伪装域名已设置: $masquerade_url"
        
        echo ""
        echo -n -e "${YELLOW}是否重启服务以应用更改? [Y/n]: ${NC}"
        read -r restart
        if [[ ! $restart =~ ^[Nn]$ ]]; then
            systemctl restart "$SERVICE_NAME"
            log_success "服务已重启"
        fi
    else
        log_error "配置文件不存在"
    fi
    
    wait_for_user
}

# 自动选择最佳伪装域名
auto_select_masquerade_domain() {
    echo ""
    echo -e "${BLUE}自动测试并选择最佳伪装域名${NC}"
    
    if safe_source_script "$SCRIPTS_DIR/domain-test.sh" "域名测试脚本"; then
        test_masquerade_domains
    fi
}

# 删除伪装域名配置
remove_masquerade_domain() {
    echo ""
    echo -e "${YELLOW}删除伪装域名配置${NC}"

    if [[ ! -f "$CONFIG_PATH" ]]; then
        log_warn "配置文件不存在"
        wait_for_user
        return
    fi

    if ! grep -q "masquerade:" "$CONFIG_PATH"; then
        log_warn "未配置伪装域名"
        wait_for_user
        return
    fi

    local current_masquerade
    current_masquerade=$(grep -A 3 "masquerade:" "$CONFIG_PATH" | grep "url:" | awk '{print $2}')
    echo "当前伪装域名: $current_masquerade"
    echo ""
    echo -n -e "${RED}确定要删除伪装域名配置吗? [y/N]: ${NC}"
    read -r confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        cp "$CONFIG_PATH" "$CONFIG_PATH.bak"
        # 删除masquerade配置块
        sed -i '/masquerade:/,/url:/d' "$CONFIG_PATH"
        log_success "伪装域名配置已删除"
        
        echo ""
        echo -n -e "${YELLOW}是否重启服务以应用更改? [Y/n]: ${NC}"
        read -r restart
        if [[ ! $restart =~ ^[Nn]$ ]]; then
            systemctl restart "$SERVICE_NAME"
            log_success "服务已重启"
        fi
    else
        echo -e "${BLUE}取消删除${NC}"
    fi

    wait_for_user
}

# 测试伪装域名连通性
test_masquerade_connectivity() {
    local url="$1"
    local domain
    domain=$(echo "$url" | sed 's|https\?://||' | sed 's|/.*||')
    
    echo "正在测试 $url..."
    
    # 测试HTTP连接
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null)
    
    if [[ "$http_code" =~ ^[23] ]]; then
        echo -e "${GREEN}✅ HTTP连接测试成功 (状态码: $http_code)${NC}"
    else
        echo -e "${YELLOW}⚠️  HTTP连接测试异常 (状态码: $http_code)${NC}"
    fi
    
    # 测试DNS解析
    if command -v dig &> /dev/null; then
        local ip
        ip=$(dig +short "$domain" A 2>/dev/null | head -1)
        if [[ -n "$ip" && "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo -e "${GREEN}✅ DNS解析成功: $ip${NC}"
        else
            echo -e "${RED}❌ DNS解析失败${NC}"
        fi
    fi
}

# 证书管理
certificate_management() {
    while true; do
        clear
        echo -e "${CYAN}=== 证书管理 ===${NC}"
        echo ""
        
        # 检查当前证书状态
        show_certificate_status
        
        echo ""
        echo -e "${YELLOW}证书管理选项:${NC}"
        echo -e "${GREEN}1.${NC} 生成自签名证书"
        echo -e "${GREEN}2.${NC} 上传自定义证书"
        echo -e "${GREEN}3.${NC} 查看证书信息"
        echo -e "${GREEN}4.${NC} 删除证书文件"
        echo -e "${GREEN}5.${NC} 证书文件路径管理"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-5]: ${NC}"
        read -r choice

        case $choice in
            1) generate_self_signed_cert ;;
            2) upload_custom_cert ;;
            3) show_certificate_info ;;
            4) remove_certificate_files ;;
            5) manage_certificate_paths ;;
            0) break ;;
            *) 
                log_error "无效选项"
                sleep 1
                ;;
        esac
    done
}

# 显示证书状态
show_certificate_status() {
    echo -e "${YELLOW}当前证书状态:${NC}"
    
    # 检查配置文件中的证书配置
    if [[ -f "$CONFIG_PATH" ]]; then
        if grep -q "^tls:" "$CONFIG_PATH"; then
            local cert_file
            local key_file
            cert_file=$(grep -A 5 "^tls:" "$CONFIG_PATH" | grep "cert:" | awk '{print $2}')
            key_file=$(grep -A 5 "^tls:" "$CONFIG_PATH" | grep "key:" | awk '{print $2}')
            
            echo -e "证书模式: ${GREEN}手动证书${NC}"
            echo -e "证书文件: ${cert_file:-未设置}"
            echo -e "密钥文件: ${key_file:-未设置}"
            
            # 检查文件是否存在
            if [[ -n "$cert_file" && -f "$cert_file" ]]; then
                echo -e "证书文件状态: ${GREEN}存在${NC}"
            else
                echo -e "证书文件状态: ${RED}不存在${NC}"
            fi
            
            if [[ -n "$key_file" && -f "$key_file" ]]; then
                echo -e "密钥文件状态: ${GREEN}存在${NC}"
            else
                echo -e "密钥文件状态: ${RED}不存在${NC}"
            fi
        elif grep -q "^acme:" "$CONFIG_PATH"; then
            echo -e "证书模式: ${GREEN}ACME自动证书${NC}"
            local domains
            domains=$(grep -A 5 "^acme:" "$CONFIG_PATH" | grep "domains:" -A 5 | grep -E "^\s*-" | sed 's/^\s*-\s*//' | tr '\n' ' ')
            echo -e "ACME域名: ${domains:-未设置}"
        else
            echo -e "证书模式: ${YELLOW}未配置${NC}"
        fi
    else
        echo -e "证书模式: ${RED}配置文件不存在${NC}"
    fi
}

# 生成自签名证书
generate_self_signed_cert() {
    echo ""
    echo -e "${BLUE}生成自签名证书${NC}"
    echo ""
    
    # 获取域名
    echo -n -e "${YELLOW}请输入证书域名 (留空使用服务器IP): ${NC}"
    read -r cert_domain
    
    if [[ -z "$cert_domain" ]]; then
        cert_domain=$(get_server_ip)
        echo "使用服务器IP: $cert_domain"
    fi
    
    # 设置证书文件路径
    local cert_dir="/etc/hysteria"
    local cert_file="$cert_dir/server.crt"
    local key_file="$cert_dir/server.key"
    
    # 创建目录
    mkdir -p "$cert_dir"
    
    echo "正在生成自签名证书..."
    
    # 生成私钥和证书
    if openssl req -x509 -nodes -newkey rsa:2048 -keyout "$key_file" -out "$cert_file" -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$cert_domain" 2>/dev/null; then
        
        # 设置权限
        chmod 600 "$key_file"
        chmod 644 "$cert_file"
        chown hysteria:hysteria "$cert_file" "$key_file" 2>/dev/null || true
        
        log_success "自签名证书生成成功"
        echo "证书文件: $cert_file"
        echo "密钥文件: $key_file"
        echo "域名: $cert_domain"
        
        # 询问是否更新配置文件
        echo ""
        echo -n -e "${YELLOW}是否更新配置文件使用新证书? [Y/n]: ${NC}"
        read -r update_config
        if [[ ! $update_config =~ ^[Nn]$ ]]; then
            update_tls_config "$cert_file" "$key_file"
        fi
    else
        log_error "自签名证书生成失败"
    fi
    
    wait_for_user
}

# 上传自定义证书
upload_custom_cert() {
    echo ""
    echo -e "${BLUE}上传自定义证书${NC}"
    echo ""
    echo "请提供证书文件路径："
    echo ""
    
    echo -n -e "${YELLOW}证书文件路径 (.crt/.pem): ${NC}"
    read -r cert_path
    
    echo -n -e "${YELLOW}私钥文件路径 (.key): ${NC}"
    read -r key_path
    
    # 验证文件存在
    if [[ ! -f "$cert_path" ]]; then
        log_error "证书文件不存在: $cert_path"
        wait_for_user
        return
    fi
    
    if [[ ! -f "$key_path" ]]; then
        log_error "私钥文件不存在: $key_path"
        wait_for_user
        return
    fi
    
    # 验证证书文件格式
    if ! openssl x509 -in "$cert_path" -text -noout &>/dev/null; then
        log_error "无效的证书文件格式"
        wait_for_user
        return
    fi
    
    if ! openssl rsa -in "$key_path" -check &>/dev/null && ! openssl ec -in "$key_path" -check &>/dev/null; then
        log_error "无效的私钥文件格式"
        wait_for_user
        return
    fi
    
    # 复制到标准位置
    local cert_dir="/etc/hysteria"
    local new_cert_file="$cert_dir/custom.crt"
    local new_key_file="$cert_dir/custom.key"
    
    mkdir -p "$cert_dir"
    
    if cp "$cert_path" "$new_cert_file" && cp "$key_path" "$new_key_file"; then
        # 设置权限
        chmod 600 "$new_key_file"
        chmod 644 "$new_cert_file"
        chown hysteria:hysteria "$new_cert_file" "$new_key_file" 2>/dev/null || true
        
        log_success "证书文件上传成功"
        echo "新证书文件: $new_cert_file"
        echo "新私钥文件: $new_key_file"
        
        # 显示证书信息
        echo ""
        echo -e "${CYAN}证书信息:${NC}"
        openssl x509 -in "$new_cert_file" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"
        
        # 询问是否更新配置文件
        echo ""
        echo -n -e "${YELLOW}是否更新配置文件使用新证书? [Y/n]: ${NC}"
        read -r update_config
        if [[ ! $update_config =~ ^[Nn]$ ]]; then
            update_tls_config "$new_cert_file" "$new_key_file"
        fi
    else
        log_error "证书文件复制失败"
    fi
    
    wait_for_user
}

# 更新TLS配置
update_tls_config() {
    local cert_file="$1"
    local key_file="$2"
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    # 备份配置文件
    cp "$CONFIG_PATH" "$CONFIG_PATH.bak"
    
    # 删除现有的ACME配置
    sed -i '/^acme:/,/^[[:alpha:]]/{ /^acme:/d; /^[[:alpha:]]/!d; }' "$CONFIG_PATH"
    
    # 添加或更新TLS配置
    if grep -q "^tls:" "$CONFIG_PATH"; then
        # 更新现有TLS配置
        sed -i "/^tls:/,/^[[:alpha:]]/ {
            /cert:/c\\  cert: $cert_file
            /key:/c\\  key: $key_file
        }" "$CONFIG_PATH"
    else
        # 添加新的TLS配置
        echo "" >> "$CONFIG_PATH"
        echo "tls:" >> "$CONFIG_PATH"
        echo "  cert: $cert_file" >> "$CONFIG_PATH"
        echo "  key: $key_file" >> "$CONFIG_PATH"
    fi
    
    log_success "配置文件已更新"
    
    # 询问是否重启服务
    echo -n -e "${YELLOW}是否重启服务以应用新证书? [Y/n]: ${NC}"
    read -r restart
    if [[ ! $restart =~ ^[Nn]$ ]]; then
        systemctl restart "$SERVICE_NAME"
        log_success "服务已重启"
    fi
}

# 查看证书信息
show_certificate_info() {
    echo ""
    echo -e "${BLUE}证书详细信息${NC}"
    echo ""
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        log_error "配置文件不存在"
        wait_for_user
        return
    fi
    
    # 获取证书文件路径
    local cert_file
    if grep -q "^tls:" "$CONFIG_PATH"; then
        cert_file=$(grep -A 5 "^tls:" "$CONFIG_PATH" | grep "cert:" | awk '{print $2}')
    else
        log_warn "未配置手动证书，检查ACME证书..."
        # 查找ACME证书
        local acme_dir="/var/lib/hysteria"
        if [[ -d "$acme_dir" ]]; then
            cert_file=$(find "$acme_dir" -name "*.crt" | head -1)
        fi
    fi
    
    if [[ -z "$cert_file" || ! -f "$cert_file" ]]; then
        log_error "未找到证书文件"
        wait_for_user
        return
    fi
    
    echo -e "${CYAN}证书文件: $cert_file${NC}"
    echo ""
    
    # 显示证书详细信息
    echo -e "${YELLOW}证书基本信息:${NC}"
    openssl x509 -in "$cert_file" -text -noout | grep -A 1 "Subject:"
    openssl x509 -in "$cert_file" -text -noout | grep -A 1 "Issuer:"
    
    echo ""
    echo -e "${YELLOW}有效期:${NC}"
    openssl x509 -in "$cert_file" -text -noout | grep -E "Not (Before|After)"
    
    echo ""
    echo -e "${YELLOW}主体备用名称 (SAN):${NC}"
    openssl x509 -in "$cert_file" -text -noout | grep -A 5 "Subject Alternative Name:" || echo "无"
    
    echo ""
    echo -e "${YELLOW}证书指纹:${NC}"
    echo -n "MD5: "
    openssl x509 -in "$cert_file" -noout -fingerprint -md5 | cut -d'=' -f2
    echo -n "SHA1: "
    openssl x509 -in "$cert_file" -noout -fingerprint -sha1 | cut -d'=' -f2
    echo -n "SHA256: "
    openssl x509 -in "$cert_file" -noout -fingerprint -sha256 | cut -d'=' -f2
    
    wait_for_user
}

# 删除证书文件
remove_certificate_files() {
    echo ""
    echo -e "${YELLOW}删除证书文件${NC}"
    echo ""
    
    # 列出可删除的证书文件
    local cert_files=()
    if [[ -f "/etc/hysteria/server.crt" ]]; then
        cert_files+=("/etc/hysteria/server.crt和server.key (自签名证书)")
    fi
    if [[ -f "/etc/hysteria/custom.crt" ]]; then
        cert_files+=("/etc/hysteria/custom.crt和custom.key (自定义证书)")
    fi
    
    if [[ ${#cert_files[@]} -eq 0 ]]; then
        log_warn "未找到可删除的证书文件"
        wait_for_user
        return
    fi
    
    echo -e "${YELLOW}找到以下证书文件:${NC}"
    for i in "${!cert_files[@]}"; do
        echo "$((i+1)). ${cert_files[i]}"
    done
    echo "0. 取消"
    echo ""
    echo -n -e "${BLUE}请选择要删除的证书 [0-${#cert_files[@]}]: ${NC}"
    read -r choice
    
    if [[ "$choice" == "0" ]]; then
        echo -e "${BLUE}取消删除${NC}"
        wait_for_user
        return
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#cert_files[@]} ]]; then
        log_error "无效选择"
        wait_for_user
        return
    fi
    
    local selected_cert="${cert_files[$((choice-1))]}"
    echo ""
    echo -e "${RED}警告: 将删除 $selected_cert${NC}"
    echo -n -e "${YELLOW}确定要删除吗? [y/N]: ${NC}"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        case $choice in
            1)
                if [[ -f "/etc/hysteria/server.crt" ]]; then
                    rm -f /etc/hysteria/server.crt /etc/hysteria/server.key
                    log_success "自签名证书已删除"
                fi
                ;;
            2)
                if [[ -f "/etc/hysteria/custom.crt" ]]; then
                    rm -f /etc/hysteria/custom.crt /etc/hysteria/custom.key
                    log_success "自定义证书已删除"
                fi
                ;;
        esac
    else
        echo -e "${BLUE}取消删除${NC}"
    fi
    
    wait_for_user
}

# 证书文件路径管理
manage_certificate_paths() {
    echo ""
    echo -e "${BLUE}证书文件路径管理${NC}"
    echo ""
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        log_error "配置文件不存在"
        wait_for_user
        return
    fi
    
    # 显示当前配置
    if grep -q "^tls:" "$CONFIG_PATH"; then
        local current_cert
        local current_key
        current_cert=$(grep -A 5 "^tls:" "$CONFIG_PATH" | grep "cert:" | awk '{print $2}')
        current_key=$(grep -A 5 "^tls:" "$CONFIG_PATH" | grep "key:" | awk '{print $2}')
        
        echo -e "${YELLOW}当前证书配置:${NC}"
        echo "证书文件: $current_cert"
        echo "私钥文件: $current_key"
    else
        echo -e "${YELLOW}当前未配置手动证书${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}路径管理选项:${NC}"
    echo "1. 修改证书文件路径"
    echo "2. 修改私钥文件路径"
    echo "3. 同时修改证书和私钥路径"
    echo "0. 返回"
    echo ""
    echo -n -e "${BLUE}请选择操作 [0-3]: ${NC}"
    read -r choice
    
    case $choice in
        1)
            echo -n -e "${YELLOW}输入新的证书文件路径: ${NC}"
            read -r new_cert
            if [[ -f "$new_cert" ]]; then
                local current_key
                current_key=$(grep -A 5 "^tls:" "$CONFIG_PATH" | grep "key:" | awk '{print $2}')
                update_tls_config "$new_cert" "$current_key"
            else
                log_error "证书文件不存在"
            fi
            ;;
        2)
            echo -n -e "${YELLOW}输入新的私钥文件路径: ${NC}"
            read -r new_key
            if [[ -f "$new_key" ]]; then
                local current_cert
                current_cert=$(grep -A 5 "^tls:" "$CONFIG_PATH" | grep "cert:" | awk '{print $2}')
                update_tls_config "$current_cert" "$new_key"
            else
                log_error "私钥文件不存在"
            fi
            ;;
        3)
            echo -n -e "${YELLOW}输入新的证书文件路径: ${NC}"
            read -r new_cert
            echo -n -e "${YELLOW}输入新的私钥文件路径: ${NC}"
            read -r new_key
            
            if [[ -f "$new_cert" && -f "$new_key" ]]; then
                update_tls_config "$new_cert" "$new_key"
            else
                log_error "文件不存在，请检查路径"
            fi
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
    
    wait_for_user
}

# 验证域名格式
validate_domain() {
    local domain="$1"
    [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

# 设置服务器域名
set_server_domain() {
    echo ""
    echo -e "${BLUE}设置服务器域名${NC}"
    echo "请输入解析到此服务器的域名 (例如: example.com):"
    echo -n -e "${YELLOW}域名: ${NC}"
    read -r domain

    if [[ -z "$domain" ]]; then
        log_error "域名不能为空"
        wait_for_user
        return
    fi

    if ! validate_domain "$domain"; then
        log_error "域名格式不正确"
        wait_for_user
        return
    fi

    # 创建目录（如果不存在）
    mkdir -p "$(dirname "$SERVER_DOMAIN_CONFIG")"
    
    # 保存域名配置
    echo "$domain" > "$SERVER_DOMAIN_CONFIG"
    log_success "服务器域名已设置: $domain"

    # 询问是否立即验证
    echo ""
    echo -n -e "${YELLOW}是否立即验证域名解析? [Y/n]: ${NC}"
    read -r verify
    if [[ ! $verify =~ ^[Nn]$ ]]; then
        verify_domain_resolution
    fi

    wait_for_user
}

# 验证域名解析 - 改进版本
verify_domain_resolution() {
    echo ""
    echo -e "${BLUE}验证域名解析${NC}"

    if [[ ! -f "$SERVER_DOMAIN_CONFIG" ]]; then
        log_error "未配置服务器域名"
        wait_for_user
        return
    fi

    local domain
    domain=$(cat "$SERVER_DOMAIN_CONFIG")
    local server_ip
    server_ip=$(get_server_ip)

    echo "正在验证域名: $domain"
    echo "服务器IP: $server_ip"
    echo ""

    # 使用多种方法解析域名
    local resolved_ips=()
    local dns_tools=("dig" "nslookup" "host")
    
    for tool in "${dns_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local result
            case $tool in
                dig)
                    result=$(dig +short "$domain" A | head -5)
                    ;;
                nslookup)
                    result=$(nslookup "$domain" 2>/dev/null | grep "Address:" | tail -n +2 | awk '{print $2}' | head -5)
                    ;;
                host)
                    result=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $4}' | head -5)
                    ;;
            esac
            
            if [[ -n "$result" ]]; then
                echo "使用 $tool 解析结果:"
                echo "$result" | while read -r ip; do
                    if [[ -n "$ip" && "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                        if [[ "$ip" == "$server_ip" ]]; then
                            echo -e "  ${GREEN}✅ $ip (匹配)${NC}"
                        else
                            echo -e "  ${YELLOW}⚠️  $ip (不匹配)${NC}"
                        fi
                        resolved_ips+=("$ip")
                    fi
                done
                break
            fi
        fi
    done

    if [[ ${#resolved_ips[@]} -eq 0 ]]; then
        log_error "无法解析域名，可能原因:"
        echo "1. 域名DNS设置未生效"
        echo "2. 网络连接问题"
        echo "3. DNS服务器问题"
    fi

    wait_for_user
}

# 删除服务器域名配置
remove_server_domain() {
    echo ""
    echo -e "${YELLOW}删除服务器域名配置${NC}"

    if [[ ! -f "$SERVER_DOMAIN_CONFIG" ]]; then
        log_warn "未配置服务器域名"
        wait_for_user
        return
    fi

    local domain
    domain=$(cat "$SERVER_DOMAIN_CONFIG")
    echo "当前配置域名: $domain"
    echo ""
    echo -n -e "${RED}确定要删除域名配置吗? [y/N]: ${NC}"
    read -r confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm -f "$SERVER_DOMAIN_CONFIG"
        log_success "域名配置已删除"
    else
        echo -e "${BLUE}取消删除${NC}"
    fi

    wait_for_user
}

# 获取服务器IP - 改进版本
get_server_ip() {
    local ip=""
    local timeout=5
    
    # IP获取服务列表（按可靠性排序）
    local ip_services=(
        "ipv4.icanhazip.com"
        "ifconfig.me/ip"
        "ip.sb"
        "checkip.amazonaws.com"
        "ipinfo.io/ip"
        "httpbin.org/ip"
    )

    for service in "${ip_services[@]}"; do
        ip=$(curl -s --connect-timeout "$timeout" --max-time "$timeout" "https://$service" 2>/dev/null)
        # 验证IP格式
        if [[ -n "$ip" && "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # 验证IP有效性
            IFS='.' read -ra ADDR <<< "$ip"
            local valid=true
            for octet in "${ADDR[@]}"; do
                if [[ $octet -gt 255 || $octet -lt 0 ]]; then
                    valid=false
                    break
                fi
            done
            if $valid; then
                echo "$ip"
                return
            fi
        fi
    done

    # 如果无法获取公网IP，尝试获取本地IP
    ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    echo "${ip:-127.0.0.1}"
}

# 获取配置的服务器域名
get_server_domain() {
    if [[ -f "$SERVER_DOMAIN_CONFIG" ]]; then
        cat "$SERVER_DOMAIN_CONFIG"
    fi
}

# 配置管理
config_management() {
    while true; do
        clear
        echo -e "${CYAN}=== 配置管理 ===${NC}"
        echo ""
        
        if [[ ! -f "$CONFIG_PATH" ]]; then
            echo -e "${YELLOW}未找到配置文件${NC}"
            echo ""
            echo -e "${GREEN}1.${NC} 返回主菜单"
            echo -n -e "${BLUE}请选择: ${NC}"
            read -r choice
            break
        fi
        
        echo -e "${YELLOW}配置管理选项:${NC}"
        echo -e "${GREEN}1.${NC} 查看当前配置"
        echo -e "${GREEN}2.${NC} 修改认证密码"
        echo -e "${GREEN}3.${NC} 修改端口设置"
        echo -e "${GREEN}4.${NC} 修改混淆设置"
        echo -e "${GREEN}5.${NC} 打开配置文件编辑"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-5]: ${NC}"
        read -r choice
        
        case $choice in
            1) view_current_config ;;
            2) modify_auth_password ;;
            3) modify_port_settings ;;
            4) modify_obfs_settings ;;
            5) edit_config_file ;;
            0) break ;;
            *)
                log_error "无效选项"
                sleep 1
                ;;
        esac
    done
}

# 节点信息
show_node_info() {
    log_info "准备显示节点信息..."
    
    if ! check_hysteria_installed; then
        log_error "Hysteria2 未安装，请先安装"
        wait_for_user
        return
    fi
    
    if safe_source_script "$SCRIPTS_DIR/node-info.sh" "节点信息脚本"; then
        display_node_info
    fi
}

# 查看当前配置
view_current_config() {
    echo ""
    echo -e "${BLUE}当前配置文件内容:${NC}"
    echo -e "${CYAN}================================${NC}"
    cat "$CONFIG_PATH"
    echo -e "${CYAN}================================${NC}"
    wait_for_user
}

# 修改认证密码
modify_auth_password() {
    echo ""
    echo -e "${BLUE}修改认证密码${NC}"
    
    # 获取当前密码
    local current_password
    current_password=$(grep -E "^\s*password:" "$CONFIG_PATH" | awk '{print $2}' | tr -d '"' || echo "未设置")
    echo "当前密码: $current_password"
    echo ""
    
    echo -n -e "${YELLOW}输入新密码 (回车生成随机密码): ${NC}"
    read -r new_password
    
    if [[ -z "$new_password" ]]; then
        new_password=$(openssl rand -base64 12 | tr -d "=+/")
        echo "生成的随机密码: $new_password"
    fi
    
    # 备份配置文件
    cp "$CONFIG_PATH" "$CONFIG_PATH.bak"
    
    # 修改密码
    sed -i "s/password:.*/password: \"$new_password\"/" "$CONFIG_PATH"
    
    log_success "认证密码已更新"
    echo ""
    echo -n -e "${YELLOW}是否重启服务以应用更改? [Y/n]: ${NC}"
    read -r restart
    if [[ ! $restart =~ ^[Nn]$ ]]; then
        systemctl restart "$SERVICE_NAME"
        log_success "服务已重启"
    fi
    
    wait_for_user
}

# 修改端口设置
modify_port_settings() {
    echo ""
    echo -e "${BLUE}修改端口设置${NC}"
    
    # 获取当前端口
    local current_port
    current_port=$(grep -E "^\s*listen:" "$CONFIG_PATH" | awk -F':' '{print $3}' | tr -d ' ' || echo "443")
    echo "当前端口: $current_port"
    echo ""
    
    echo -n -e "${YELLOW}输入新端口 [1-65535]: ${NC}"
    read -r new_port
    
    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1 ]] || [[ "$new_port" -gt 65535 ]]; then
        log_error "端口必须是 1-65535 之间的数字"
        wait_for_user
        return
    fi
    
    # 检查端口是否被占用
    if ss -tuln | grep -q ":$new_port "; then
        log_warn "端口 $new_port 似乎已被占用，请确认"
        echo -n -e "${YELLOW}是否继续? [y/N]: ${NC}"
        read -r continue
        if [[ ! $continue =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    # 备份配置文件
    cp "$CONFIG_PATH" "$CONFIG_PATH.bak"
    
    # 修改端口
    sed -i "s/:$current_port/:$new_port/g" "$CONFIG_PATH"
    
    log_success "端口已更新为: $new_port"
    echo ""
    echo -n -e "${YELLOW}是否重启服务以应用更改? [Y/n]: ${NC}"
    read -r restart
    if [[ ! $restart =~ ^[Nn]$ ]]; then
        systemctl restart "$SERVICE_NAME"
        log_success "服务已重启"
    fi
    
    wait_for_user
}

# 修改混淆设置
modify_obfs_settings() {
    echo ""
    echo -e "${BLUE}修改混淆设置${NC}"
    
    # 检查当前混淆配置
    local current_obfs
    current_obfs=$(grep -E "^\s*type: salamander" "$CONFIG_PATH" && echo "启用" || echo "禁用")
    echo "当前混淆状态: $current_obfs"
    
    if [[ "$current_obfs" == "启用" ]]; then
        local current_obfs_password
        current_obfs_password=$(grep -A1 "type: salamander" "$CONFIG_PATH" | grep "password:" | awk '{print $2}' | tr -d '"')
        echo "当前混淆密码: $current_obfs_password"
    fi
    
    echo ""
    echo -e "${YELLOW}混淆选项:${NC}"
    echo "1. 启用混淆"
    echo "2. 禁用混淆"
    echo "3. 修改混淆密码"
    echo "0. 返回"
    echo ""
    echo -n -e "${BLUE}请选择: ${NC}"
    read -r obfs_choice
    
    case $obfs_choice in
        1|2|3)
            # 备份配置文件
            cp "$CONFIG_PATH" "$CONFIG_PATH.bak"
            
            case $obfs_choice in
                1)
                    echo -n -e "${YELLOW}输入混淆密码 (回车生成随机密码): ${NC}"
                    read -r obfs_password
                    if [[ -z "$obfs_password" ]]; then
                        obfs_password=$(openssl rand -base64 12 | tr -d "=+/")
                        echo "生成的随机密码: $obfs_password"
                    fi
                    
                    # 添加混淆配置
                    if ! grep -q "obfs:" "$CONFIG_PATH"; then
                        sed -i "/listen:/a\\
obfs:\\
  type: salamander\\
  password: \"$obfs_password\"" "$CONFIG_PATH"
                    else
                        sed -i "/obfs:/,+2c\\
obfs:\\
  type: salamander\\
  password: \"$obfs_password\"" "$CONFIG_PATH"
                    fi
                    log_success "混淆已启用"
                    ;;
                2)
                    # 删除混淆配置
                    sed -i '/obfs:/,+2d' "$CONFIG_PATH"
                    log_success "混淆已禁用"
                    ;;
                3)
                    if [[ "$current_obfs" == "禁用" ]]; then
                        log_error "当前未启用混淆"
                        wait_for_user
                        return
                    fi
                    
                    echo -n -e "${YELLOW}输入新的混淆密码: ${NC}"
                    read -r new_obfs_password
                    
                    if [[ -z "$new_obfs_password" ]]; then
                        log_error "混淆密码不能为空"
                        wait_for_user
                        return
                    fi
                    
                    # 修改混淆密码
                    sed -i "/obfs:/,+2s/password:.*/password: \"$new_obfs_password\"/" "$CONFIG_PATH"
                    log_success "混淆密码已更新"
                    ;;
            esac
            
            echo ""
            echo -n -e "${YELLOW}是否重启服务以应用更改? [Y/n]: ${NC}"
            read -r restart
            if [[ ! $restart =~ ^[Nn]$ ]]; then
                systemctl restart "$SERVICE_NAME"
                log_success "服务已重启"
            fi
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
    
    wait_for_user
}

# 编辑配置文件
edit_config_file() {
    echo ""
    echo -e "${BLUE}打开配置文件编辑${NC}"
    echo "配置文件路径: $CONFIG_PATH"
    echo ""
    echo -e "${YELLOW}编辑器选项:${NC}"
    echo "1. 使用 nano (推荐新手)"
    echo "2. 使用 vim"
    echo "3. 使用系统默认编辑器"
    echo "0. 返回"
    echo ""
    echo -n -e "${BLUE}请选择编辑器: ${NC}"
    read -r editor_choice
    
    # 备份配置文件
    cp "$CONFIG_PATH" "$CONFIG_PATH.bak"
    log_info "已备份配置文件"
    
    case $editor_choice in
        1)
            if command -v nano &> /dev/null; then
                nano "$CONFIG_PATH"
            else
                log_error "nano 未安装，使用系统默认编辑器"
                ${EDITOR:-vi} "$CONFIG_PATH"
            fi
            ;;
        2)
            if command -v vim &> /dev/null; then
                vim "$CONFIG_PATH"
            else
                log_error "vim 未安装，使用系统默认编辑器"
                ${EDITOR:-vi} "$CONFIG_PATH"
            fi
            ;;
        3)
            ${EDITOR:-vi} "$CONFIG_PATH"
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择，使用系统默认编辑器"
            ${EDITOR:-vi} "$CONFIG_PATH"
            ;;
    esac
    
    echo ""
    echo -n -e "${YELLOW}配置已修改，是否重启服务以应用更改? [Y/n]: ${NC}"
    read -r restart
    if [[ ! $restart =~ ^[Nn]$ ]]; then
        if systemctl restart "$SERVICE_NAME"; then
            log_success "服务已重启"
        else
            log_error "服务重启失败，请检查配置文件语法"
            echo -n -e "${YELLOW}是否恢复备份配置? [Y/n]: ${NC}"
            read -r restore
            if [[ ! $restore =~ ^[Nn]$ ]]; then
                cp "$CONFIG_PATH.bak" "$CONFIG_PATH"
                systemctl restart "$SERVICE_NAME"
                log_info "已恢复备份配置"
            fi
        fi
    fi
    
    wait_for_user
}

# 卸载服务 - 改进版本，增加更多选项和安全确认
uninstall_hysteria() {
    clear
    echo -e "${CYAN}=== Hysteria2 卸载向导 ===${NC}"
    echo ""
    
    # 显示当前状态
    if check_hysteria_installed; then
        echo -e "${YELLOW}当前 Hysteria2 状态:${NC}"
        echo -n "服务状态: "
        check_service_status
        if [[ -f "$CONFIG_PATH" ]]; then
            echo "配置文件: 存在"
        fi
        if [[ -d "/etc/hysteria" ]]; then
            echo "配置目录: 存在"
        fi
        echo ""
    else
        echo -e "${YELLOW}Hysteria2 未安装，但可以清理残留文件${NC}"
        echo ""
    fi

    echo -e "${YELLOW}卸载选项:${NC}"
    echo -e "${GREEN}1.${NC} 仅卸载 Hysteria2 程序 (保留配置和证书)"
    echo -e "${GREEN}2.${NC} 卸载程序和配置文件 (保留管理脚本)"
    echo -e "${GREEN}3.${NC} 完全卸载 (包括管理脚本)"
    echo -e "${RED}0.${NC} 取消"
    echo ""
    echo -e "${CYAN}说明:${NC}"
    echo "选项1: 保留配置便于重新安装，适合升级或重装"
    echo "选项2: 清理配置重新开始，保留管理工具"
    echo "选项3: 完全清理系统，删除所有相关文件"
    echo ""
    echo -n -e "${BLUE}请选择卸载方式 [0-3]: ${NC}"
    read -r uninstall_choice

    case $uninstall_choice in
        1) uninstall_server_only ;;
        2) uninstall_server_and_config ;;
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

# 方式1: 仅卸载 Hysteria2 服务器
uninstall_server_only() {
    echo ""
    echo -e "${BLUE}仅卸载 Hysteria2 程序 (保留配置和证书)${NC}"
    echo ""

    if ! check_hysteria_installed; then
        log_warn "Hysteria2 未安装"
        return
    fi

    echo -e "${YELLOW}此操作将:${NC}"
    echo "✓ 停止并卸载 Hysteria2 程序"
    echo "✓ 删除系统服务"
    echo "✗ 保留配置文件和证书"
    echo "✗ 保留用户账户"
    echo "✗ 保留管理脚本"
    echo ""
    echo -n -e "${YELLOW}确定要卸载 Hysteria2 程序吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi

    log_info "正在卸载 Hysteria2 程序..."
    
    # 停止服务
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        log_info "已停止服务"
    fi
    
    # 使用官方卸载脚本
    if bash <(curl -fsSL https://get.hy2.sh/) --remove 2>/dev/null; then
        echo ""
        log_success "Hysteria2 程序卸载完成!"
        echo ""
        echo -e "${CYAN}已保留内容:${NC}"
        echo "• 配置文件: /etc/hysteria/"
        echo "• SSL 证书文件"
        echo "• hysteria 用户账户"
        echo "• 管理脚本: s-hy2"
        echo ""
        echo -e "${YELLOW}重新安装:${NC}"
        echo "运行 's-hy2' 选择 '1. 安装 Hysteria2' 即可重新安装"
    else
        log_error "卸载失败，请检查网络连接或手动卸载"
    fi
}

# 方式2: 卸载 Hysteria2 服务器及配置文件
uninstall_server_and_config() {
    echo ""
    echo -e "${BLUE}卸载 Hysteria2 程序和配置文件${NC}"
    echo ""

    echo -e "${YELLOW}此操作将:${NC}"
    echo "✓ 停止并卸载 Hysteria2 程序"
    echo "✓ 删除系统服务"
    echo "✓ 删除配置文件和证书"
    echo "✓ 删除用户账户"
    echo "✓ 清理端口跳跃规则"
    echo "✗ 保留管理脚本"
    echo ""
    echo -n -e "${YELLOW}确定要卸载程序和配置吗? [y/N]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi

    # 清理端口跳跃配置 (需要在删除配置文件前执行)
    log_info "步骤 1/5: 清理端口跳跃配置..."
    cleanup_port_hopping

    # 停止服务
    log_info "步骤 2/5: 停止服务..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
    fi

    # 卸载程序
    log_info "步骤 3/5: 卸载 Hysteria2 程序..."
    if check_hysteria_installed; then
        bash <(curl -fsSL https://get.hy2.sh/) --remove 2>/dev/null || log_warn "程序卸载失败，继续清理"
    fi

    # 删除配置文件和证书
    log_info "步骤 4/5: 删除配置文件和证书..."
    if [[ -d "/etc/hysteria" ]]; then
        rm -rf /etc/hysteria
        log_success "已删除 /etc/hysteria"
    fi

    # 清理用户账户和系统残留
    log_info "步骤 5/5: 清理用户账户和系统残留..."
    cleanup_system_remnants

    echo ""
    log_success "Hysteria2 程序和配置文件卸载完成!"
    echo ""
    echo -e "${CYAN}已保留内容:${NC}"
    echo "• 管理脚本: s-hy2"
    echo ""
    echo -e "${YELLOW}重新部署:${NC}"
    echo "运行 's-hy2' 选择安装和配置选项即可重新部署"
}

# 方式3: 完全卸载
uninstall_everything() {
    echo ""
    echo -e "${RED}完全卸载 - 删除所有相关文件${NC}"
    echo ""

    echo -e "${RED}警告: 此操作将删除:${NC}"
    echo "• Hysteria2 程序文件"
    echo "• 所有配置文件和证书"
    echo "• 用户账户"
    echo "• 系统服务"
    echo "• 管理脚本 (s-hy2)"
    echo "• 端口跳跃规则"
    echo "• 所有相关目录和文件"
    echo ""
    echo -e "${YELLOW}此操作不可逆！请输入 'YES' 确认完全卸载: ${NC}"
    read -r confirm
    if [[ "$confirm" != "YES" ]]; then
        echo -e "${BLUE}取消卸载${NC}"
        return
    fi

    # 执行完全清理
    perform_complete_uninstall
}

# 清理端口跳跃配置
cleanup_port_hopping() {
    if [[ -f "/etc/hysteria/port-hopping.conf" ]]; then
        # shellcheck source=/dev/null
        source "/etc/hysteria/port-hopping.conf" 2>/dev/null
        if [[ -n "$INTERFACE" && -n "$START_PORT" && -n "$END_PORT" && -n "$TARGET_PORT" ]]; then
            iptables -t nat -D PREROUTING -i "$INTERFACE" -p udp --dport "$START_PORT:$END_PORT" -j REDIRECT --to-ports "$TARGET_PORT" 2>/dev/null
            log_info "已清理端口跳跃 iptables 规则"
        fi
    fi
    
    # 清理其他可能的端口跳跃规则
    local rules_cleared=0
    while IFS= read -r line_num; do
        if [[ -n "$line_num" ]] && iptables -t nat -D PREROUTING "$line_num" 2>/dev/null; then
            ((rules_cleared++))
        fi
    done < <(iptables -t nat -L PREROUTING --line-numbers 2>/dev/null | grep "REDIRECT.*--to-ports 443" | awk '{print $1}' | sort -rn)
    
    if [[ $rules_cleared -gt 0 ]]; then
        log_info "已清理 $rules_cleared 条端口跳跃规则"
    fi
}

# 清理系统残留
cleanup_system_remnants() {
    # 删除用户账户
    if id "hysteria" &>/dev/null; then
        userdel -r hysteria 2>/dev/null || userdel hysteria 2>/dev/null
        log_info "已删除 hysteria 用户"
    fi

    # 清理 systemd 服务残留
    local service_files=(
        "/etc/systemd/system/multi-user.target.wants/hysteria-server.service"
        "/etc/systemd/system/multi-user.target.wants/hysteria-server@*.service"
        "/lib/systemd/system/hysteria-server.service"
        "/usr/lib/systemd/system/hysteria-server.service"
    )
    
    for service_file in "${service_files[@]}"; do
        if [[ -f "$service_file" ]]; then
            rm -f "$service_file"
        fi
    done
    
    systemctl daemon-reload
    log_info "已清理 systemd 服务残留"
}

# 执行完全卸载
perform_complete_uninstall() {
    echo ""
    log_info "开始执行完全卸载..."
    
    # 1. 清理端口跳跃配置
    log_info "步骤 1/8: 清理端口跳跃配置..."
    cleanup_port_hopping

    # 2. 停止并禁用服务
    log_info "步骤 2/8: 停止并禁用服务..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
    fi
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME" 2>/dev/null
    fi

    # 3. 卸载 Hysteria2 程序
    log_info "步骤 3/8: 卸载 Hysteria2 程序..."
    if check_hysteria_installed; then
        bash <(curl -fsSL https://get.hy2.sh/) --remove 2>/dev/null || log_warn "程序卸载失败，继续清理"
    fi

    # 4. 删除配置文件和证书
    log_info "步骤 4/8: 删除配置文件和证书..."
    rm -rf /etc/hysteria

    # 5. 清理系统残留
    log_info "步骤 5/8: 清理系统残留..."
    cleanup_system_remnants

    # 6. 清理 iptables 规则残留
    log_info "步骤 6/8: 清理 iptables 规则残留..."
    iptables -t nat -L PREROUTING --line-numbers 2>/dev/null | grep "REDIRECT.*443" | awk '{print $1}' | tac | while read -r line; do
        iptables -t nat -D PREROUTING "$line" 2>/dev/null
    done

    # 7. 删除管理脚本符号链接
    log_info "步骤 7/8: 删除管理脚本符号链接..."
    rm -f /usr/local/bin/hy2-manager
    rm -f /usr/local/bin/s-hy2

    # 8. 删除管理脚本安装目录
    log_info "步骤 8/8: 删除管理脚本安装目录..."
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

# 关于脚本 - 增强版本
about_script() {
    clear
    echo -e "${CYAN}=== 关于 Hysteria2 配置管理脚本 ===${NC}"
    echo ""
    echo -e "${YELLOW}基本信息:${NC}"
    echo "脚本名称: S-Hy2 Manager"
    echo "版本: 1.1.0"
    echo "功能: 简化 Hysteria2 的安装、配置和管理"
    echo ""
    echo -e "${YELLOW}主要功能:${NC}"
    echo "✓ 一键安装/卸载 Hysteria2"
    echo "✓ 智能配置生成 (ACME/自签名证书)"
    echo "✓ 配置管理 (密码、端口、混淆等)"
    echo "✓ 域名管理 (ACME域名和伪装域名)"
    echo "✓ 证书管理 (生成、上传、查看)"
    echo "✓ 端口跳跃配置"
    echo "✓ 服务管理和监控"
    echo "✓ 节点信息和订阅链接生成"
    echo ""
    echo -e "${YELLOW}系统兼容性:${NC}"
    echo "• Ubuntu 18.04+ / Debian 9+"
    echo "• CentOS 7+ / RHEL 7+ / Fedora"
    echo "• 支持 systemd 的 Linux 发行版"
    echo ""
    echo -e "${YELLOW}脚本信息:${NC}"
    echo "安装位置: $SCRIPT_DIR"
    echo "配置目录: /etc/hysteria/"
    echo "日志查看: journalctl -u hysteria-server"
    echo ""
    echo -e "${YELLOW}获取支持:${NC}"
    echo "• GitHub: https://github.com/sindricn/s-hy2"
    echo "• Issues: 在 GitHub 仓库提交问题"
    echo ""
    wait_for_user
}

# 输入验证函数
validate_input() {
    local input="$1"
    local min="$2"
    local max="$3"
    
    if [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -ge "$min" ]] && [[ "$input" -le "$max" ]]; then
        return 0
    else
        return 1
    fi
}

# 主循环
main() {
    # 检查基本要求
    check_root
    check_script_integrity
    
    # 设置错误处理
    trap 'echo -e "\n${RED}脚本被中断${NC}"; exit 130' INT
    trap 'echo -e "\n${RED}脚本执行错误${NC}"; exit 1' ERR
    
    while true; do
        print_header
        show_status
        print_menu
        
        read -r choice
        
        # 输入验证
        if ! validate_input "$choice" 0 11; then
            log_error "请输入 0-11 之间的数字"
            sleep 2
            continue
        fi
        
        case $choice in
            1) install_hysteria ;;
            2) quick_config ;;
            3) manual_config ;;
            4) config_management ;;
            5) domain_management ;;
            6) certificate_management ;;
            7) manage_service ;;
            8) show_node_info ;;
            9) view_logs ;;
            10) uninstall_hysteria ;;
            11) about_script ;;
            0)
                echo -e "${GREEN}感谢使用 Hysteria2 配置管理脚本!${NC}"
                exit 0
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    local required_cmds=("curl" "systemctl" "iptables")
    
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "缺少必要的依赖:"
        printf ' • %s\n' "${missing_deps[@]}"
        echo ""
        echo "请安装缺少的依赖后重新运行脚本"
        exit 1
    fi
}

# 脚本初始化
init_script() {
    # 设置严格模式（但允许某些命令失败）
    set -o pipefail
    
    # 检查依赖
    check_dependencies
    
    # 检查脚本目录权限
    if [[ ! -r "$SCRIPT_DIR" ]]; then
        error_exit "无法访问脚本目录: $SCRIPT_DIR"
    fi
}

# 运行主程序
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_script
    main "$@"
fi
