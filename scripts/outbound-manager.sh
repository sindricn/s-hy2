#!/bin/bash

# Hysteria2 出站规则管理模块
# 功能: 配置和管理 Hysteria2 的出站规则
# 支持: Direct、SOCKS5、HTTP 代理类型
# 特性: 类型唯一性强制、具体参数修改、智能冲突检测

# 适度的错误处理
set -uo pipefail

# 加载公共库
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
else
    echo "错误: 无法加载公共库" >&2
    exit 1
fi

# 配置路径 (防止重复定义)
if [[ -z "${HYSTERIA_CONFIG:-}" ]]; then
    readonly HYSTERIA_CONFIG="/etc/hysteria/config.yaml"
fi
# 备份功能已移除

# 初始化出站管理
init_outbound_manager() {
    log_info "初始化出站规则管理器"

    # 检查必要的命令
    require_command "awk"
    require_command "grep"
    require_command "sed"

    # 检查 Hysteria2 安装状态
    check_hysteria2_installation
}

# 检查 Hysteria2 安装和配置状态
check_hysteria2_installation() {
    local has_binary=false
    local has_config_dir=false

    # 检查二进制文件
    if command -v hysteria >/dev/null 2>&1; then
        has_binary=true
    fi

    # 检查配置目录
    if [[ -d "/etc/hysteria" ]]; then
        has_config_dir=true
    fi

    # 根据检查结果提供指导
    if ! $has_binary; then
        echo ""
        echo -e "${RED}❌ Hysteria2 未安装${NC}"
        echo -e "${YELLOW}请先安装 Hysteria2 才能使用出站规则管理功能${NC}"
        echo ""
        echo -e "${BLUE}安装建议：${NC}"
        echo "1. 返回主菜单选择 '1. 安装 Hysteria2'"
        echo "2. 或手动安装: curl -fsSL https://get.hy2.sh/ | bash"
        echo ""
        read -p "按回车键返回主菜单..." -r
        return 1
    fi

    if ! $has_config_dir; then
        echo ""
        echo -e "${YELLOW}⚠️  配置目录不存在${NC}"
        echo -e "${BLUE}正在创建配置目录: /etc/hysteria${NC}"

        if mkdir -p "/etc/hysteria" 2>/dev/null; then
            echo -e "${GREEN}✅ 配置目录创建成功${NC}"
        else
            echo -e "${RED}❌ 无法创建配置目录，可能需要 root 权限${NC}"
            echo "请以 root 用户运行此脚本，或手动创建: sudo mkdir -p /etc/hysteria"
            read -p "按回车键继续..." -r
            return 1
        fi
    fi

    # 检查配置文件是否存在，不存在则创建基础配置
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  配置文件不存在: $HYSTERIA_CONFIG${NC}"
        echo -e "${BLUE}正在创建基础配置文件...${NC}"

        create_basic_hysteria_config
    fi

    # 检查配置文件权限
    check_config_file_permissions

    return 0
}

# 创建基础 Hysteria2 配置文件
create_basic_hysteria_config() {
    cat > "$HYSTERIA_CONFIG" << 'EOF'
# Hysteria2 服务器配置文件
# 此文件由 S-HY2 出站规则管理器创建

listen: :443

# TLS 配置 (请根据实际情况修改)
# tls:
#   cert: /path/to/your/cert.crt
#   key: /path/to/your/private.key

# 认证配置 (请根据实际情况修改)
auth:
  type: password
  password: "your_password_here"

# 混淆配置 (可选)
# obfs:
#   type: salamander
#   salamander:
#     password: "your_obfs_password"

# 出站配置将由规则管理器自动管理
# outbounds 段落请勿手动编辑
EOF

    if [[ -f "$HYSTERIA_CONFIG" ]]; then
        echo -e "${GREEN}✅ 基础配置文件创建成功${NC}"
        echo -e "${YELLOW}⚠️  请编辑配置文件设置 TLS 证书和认证密码:${NC}"
        echo -e "${CYAN}  $HYSTERIA_CONFIG${NC}"
    else
        echo -e "${RED}❌ 配置文件创建失败${NC}"
        return 1
    fi
}

# 检查和修复配置文件权限
check_config_file_permissions() {
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        return 1
    fi

    # 检查文件权限
    local file_perms=$(stat -c "%a" "$HYSTERIA_CONFIG" 2>/dev/null || stat -f "%A" "$HYSTERIA_CONFIG" 2>/dev/null || echo "unknown")

    # 如果权限太严格，修复权限
    if [[ "$file_perms" == "600" ]] || [[ "$file_perms" == "700" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  配置文件权限过于严格: $file_perms${NC}"
        echo -e "${BLUE}正在修复权限...${NC}"

        if chmod 644 "$HYSTERIA_CONFIG" 2>/dev/null; then
            echo -e "${GREEN}✅ 权限修复成功 (644)${NC}"
        else
            echo -e "${RED}❌ 权限修复失败，可能需要 root 权限${NC}"
            echo "请手动执行: sudo chmod 644 $HYSTERIA_CONFIG"
        fi
    fi

    # 检查目录权限
    local config_dir=$(dirname "$HYSTERIA_CONFIG")
    if [[ ! -r "$config_dir" ]]; then
        echo -e "${YELLOW}⚠️  配置目录权限问题${NC}"
        echo "请检查目录权限: $config_dir"
    fi
}

# 显示出站管理菜单
show_outbound_menu() {
    clear
    echo -e "${CYAN}=== Hysteria2 出站规则管理 ===${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 查看出站规则"
    echo -e "${GREEN}2.${NC} 新增出站规则"
    echo -e "${GREEN}3.${NC} 应用出站规则"
    echo -e "${GREEN}4.${NC} 修改出站规则"
    echo -e "${GREEN}5.${NC} 删除出站规则"
    echo ""
    echo -e "${RED}0.${NC} 返回主菜单"
    echo ""
}

# 查看当前出站配置
view_current_outbound() {
    log_info "查看当前出站配置"

    # 使用统一的检查函数
    if ! check_hysteria2_ready "config"; then
        return 0  # 友好返回，不退出脚本
    fi

    echo -e "${BLUE}=== 当前出站配置 ===${NC}"
    echo ""

    # 检查是否有出站配置 - 改进的匹配模式
    if grep -q "^[[:space:]]*outbounds:" "$HYSTERIA_CONFIG"; then
        echo -e "${GREEN}出站规则：${NC}"
        # 使用更精确的sed匹配，支持缩进
        sed -n '/^[[:space:]]*outbounds:/,/^[a-zA-Z]/p' "$HYSTERIA_CONFIG" | sed '$d'
        echo ""

        # 显示出站规则统计
        local outbound_count
        outbound_count=$(grep -c "^[[:space:]]*-[[:space:]]*name:" "$HYSTERIA_CONFIG" || echo "0")
        echo -e "${CYAN}共找到 $outbound_count 个出站规则${NC}"
        echo ""
    else
        echo -e "${YELLOW}当前配置中没有出站规则（使用默认直连）${NC}"
        echo ""
    fi

    # 检查是否有 ACL 配置 - 改进的匹配和显示
    if grep -q "^[[:space:]]*acl:" "$HYSTERIA_CONFIG"; then
        echo -e "${GREEN}ACL 规则：${NC}"
        # 改进的ACL显示逻辑，完整显示inline内容
        local in_acl=false
        local acl_indent=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*acl: ]]; then
                in_acl=true
                echo "$line"
                # 记录ACL节点的缩进级别
                acl_indent=$(echo "$line" | sed 's/acl:.*//')
            elif [[ "$in_acl" == true ]]; then
                # 检查是否是同级或更高级的配置节点（结束ACL显示）
                if [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(inline|file): ]]; then
                    local line_indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
                    # 如果缩进级别等于或小于ACL节点，说明ACL节点结束
                    if [[ ${#line_indent} -le ${#acl_indent} ]]; then
                        break
                    fi
                fi
                echo "$line"
            fi
        done < "$HYSTERIA_CONFIG"
    else
        echo -e "${YELLOW}当前配置中没有 ACL 规则（使用默认路由）${NC}"
    fi

    echo ""
    wait_for_user
}

# 添加新的出站规则
add_outbound_rule() {
    log_info "添加新的出站规则"

    echo -e "${BLUE}=== 添加出站规则 ===${NC}"
    echo ""
    echo "选择出站类型："
    echo "1. Direct (直连)"
    echo "2. SOCKS5 代理"
    echo "3. HTTP/HTTPS 代理"
    echo ""

    local choice
    read -p "请选择 [1-3]: " choice

    # 确定选择的类型
    local selected_type
    case $choice in
        1) selected_type="direct" ;;
        2) selected_type="socks5" ;;
        3) selected_type="http" ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    echo -e "${GREEN}已选择类型: $selected_type${NC}"

    # 执行对应的配置函数
    case $choice in
        1) add_direct_outbound ;;
        2) add_socks5_outbound ;;
        3) add_http_outbound ;;
    esac
}

# 添加直连出站
add_direct_outbound() {
    echo -e "${BLUE}=== 配置 Direct 直连出站 ===${NC}"
    echo ""

    local name interface ipv4 ipv6

    # 获取出站名称
    read -p "出站名称 (例: china_direct): " name
    if [[ -z "$name" ]]; then
        name="direct_out"
    fi

    # 是否绑定特定网卡
    read -p "是否绑定特定网卡？ [y/N]: " bind_interface

    if [[ $bind_interface =~ ^[Yy]$ ]]; then
        echo "可用网卡："
        # 优化：缓存网卡信息并使用更高效的命令
        if [[ -z "${CACHED_INTERFACES:-}" ]]; then
            # 使用更快的方法获取网卡列表
            if command -v ip >/dev/null 2>&1; then
                CACHED_INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
            else
                # 降级方案
                CACHED_INTERFACES=$(ls /sys/class/net/ | grep -v "lo")
            fi
        fi
        echo "$CACHED_INTERFACES" | nl -w2 -s') '
        read -p "请选择网卡名称 (例: eth0): " interface
    fi

    # 是否绑定特定 IP
    read -p "是否绑定特定 IP 地址？ [y/N]: " bind_ip

    if [[ $bind_ip =~ ^[Yy]$ ]]; then
        read -p "IPv4 地址 (可选): " ipv4
        read -p "IPv6 地址 (可选): " ipv6
    fi

    # 保存配置参数供后续使用
    export DIRECT_INTERFACE="$interface"
    export DIRECT_IPV4="$ipv4"
    export DIRECT_IPV6="$ipv6"

    # 生成配置
    generate_direct_config "$name" "$interface" "$ipv4" "$ipv6"
}

# 添加 SOCKS5 出站
add_socks5_outbound() {
    echo -e "${BLUE}=== 配置 SOCKS5 代理出站 ===${NC}"
    echo ""

    local name addr username password

    read -p "出站名称 (例: socks5_proxy): " name
    if [[ -z "$name" ]]; then
        name="socks5_out"
    fi

    read -p "代理服务器地址:端口 (例: proxy.example.com:1080): " addr
    if [[ -z "$addr" ]]; then
        log_error "代理地址不能为空"
        return 1
    fi

    read -p "是否需要认证？ [y/N]: " need_auth

    if [[ $need_auth =~ ^[Yy]$ ]]; then
        read -p "用户名: " username
        read -s -p "密码: " password
        echo ""
    fi

    # 保存配置参数供后续使用
    export SOCKS5_ADDR="$addr"
    export SOCKS5_USERNAME="$username"
    export SOCKS5_PASSWORD="$password"

    # 生成配置
    generate_socks5_config "$name" "$addr" "$username" "$password"
}

# 添加 HTTP 出站
add_http_outbound() {
    echo -e "${BLUE}=== 配置 HTTP/HTTPS 代理出站 ===${NC}"
    echo ""

    local name url insecure

    read -p "出站名称 (例: http_proxy): " name
    if [[ -z "$name" ]]; then
        name="http_out"
    fi

    echo "代理类型："
    echo "1. HTTP 代理"
    echo "2. HTTPS 代理"
    read -p "选择 [1-2]: " proxy_type

    if [[ $proxy_type == "1" ]]; then
        read -p "HTTP 代理 URL (例: http://user:pass@proxy.com:8080): " url
    else
        read -p "HTTPS 代理 URL (例: https://user:pass@proxy.com:8080): " url
        read -p "是否跳过 TLS 验证？ [y/N]: " skip_tls
        if [[ $skip_tls =~ ^[Yy]$ ]]; then
            insecure="true"
        else
            insecure="false"
        fi
    fi

    if [[ -z "$url" ]]; then
        log_error "代理 URL 不能为空"
        return 1
    fi

    # 保存配置参数供后续使用
    export HTTP_URL="$url"
    export HTTP_INSECURE="$insecure"

    # 生成配置
    generate_http_config "$name" "$url" "$insecure"
}

# 生成配置函数
generate_direct_config() {
    local name="$1" interface="$2" ipv4="$3" ipv6="$4"

    echo "生成的 Direct 出站配置："
    echo "---"
    echo "outbounds:"
    echo "  - name: $name"
    echo "    type: direct"
    echo "    direct:"
    echo "      mode: auto"

    if [[ -n "$interface" ]]; then
        echo "      bindDevice: \"$interface\""
    fi
    if [[ -n "$ipv4" ]]; then
        echo "      bindIPv4: \"$ipv4\""
    fi
    if [[ -n "$ipv6" ]]; then
        echo "      bindIPv6: \"$ipv6\""
    fi
    echo "---"
    echo ""

    apply_outbound_config "$name" "direct" "$existing_rule"
}

generate_socks5_config() {
    local name="$1" addr="$2" username="$3" password="$4"

    echo "生成的 SOCKS5 出站配置："
    echo "---"
    echo "outbounds:"
    echo "  - name: $name"
    echo "    type: socks5"
    echo "    socks5:"
    echo "      addr: \"$addr\""

    if [[ -n "$username" ]]; then
        echo "      username: \"$username\""
        echo "      password: \"$password\""
    fi
    echo "---"
    echo ""

    apply_outbound_config "$name" "socks5" "$existing_rule"
}

generate_http_config() {
    local name="$1" url="$2" insecure="$3"

    echo "生成的 HTTP 出站配置："
    echo "---"
    echo "outbounds:"
    echo "  - name: $name"
    echo "    type: http"
    echo "    http:"
    echo "      url: \"$url\""

    if [[ -n "$insecure" ]]; then
        echo "      insecure: $insecure"
    fi
    echo "---"
    echo ""

    apply_outbound_config "$name" "http" "$existing_rule"
}

# 应用出站配置 - 极简稳定版本
apply_outbound_config() {
    local name="$1" type="$2" existing_rule="${3:-}"

    read -p "是否将此配置应用到 Hysteria2？ [y/N]: " apply_config

    if [[ $apply_config =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[INFO]${NC} 开始应用出站配置: $name ($type)"

        # 使用极简稳定的方法
        if apply_outbound_simple "$name" "$type" "$existing_rule"; then
            echo -e "${GREEN}[SUCCESS]${NC} 出站配置已添加：$name ($type)"

            # 询问是否重启服务
            read -p "是否重启 Hysteria2 服务以应用配置？ [y/N]: " restart_service

            if [[ $restart_service =~ ^[Yy]$ ]]; then
                if systemctl restart hysteria-server 2>/dev/null; then
                    echo -e "${GREEN}[SUCCESS]${NC} 服务已重启"
                else
                    echo -e "${RED}[ERROR]${NC} 服务重启失败"
                fi
            fi
        else
            echo -e "${RED}[ERROR]${NC} 配置应用失败"
        fi
    else
        echo -e "${BLUE}[INFO]${NC} 操作已取消"
    fi
}

# 检查规则库中的类型冲突
check_rule_type_conflict() {
    local target_type="$1"
    init_rules_library

    if [[ ! -f "$RULES_LIBRARY" ]]; then
        return 0  # 文件不存在，没有冲突
    fi

    local in_rules_section=false
    local current_rule_name=""
    local current_rule_type=""

    while IFS= read -r line; do
        # 检测rules节点
        if [[ "$line" =~ ^rules:[[:space:]]*$ ]]; then
            in_rules_section=true
            continue
        fi

        # 离开rules节点 - 只有0级缩进的键才退出
        if [[ "$in_rules_section" == true ]] && [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*$ ]]; then
            break
        fi

        # 在rules节点中
        if [[ "$in_rules_section" == true ]]; then
            # 检测规则名（2级缩进）
            if [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z_][a-zA-Z0-9_]+):[[:space:]]*$ ]]; then
                current_rule_name="${BASH_REMATCH[1]}"
                current_rule_type=""
            fi
            # 检测规则类型（4级缩进）
            if [[ "$line" =~ ^[[:space:]]{4}type:[[:space:]]*(.+)$ ]]; then
                current_rule_type="${BASH_REMATCH[1]}"
                # 如果类型匹配，返回规则名
                if [[ "$current_rule_type" == "$target_type" ]]; then
                    echo "$current_rule_name"
                    return 0
                fi
            fi
        fi
    done < "$RULES_LIBRARY"

    return 1  # 没有找到冲突
}

# 检查现有同类型出站规则
check_existing_outbound_type() {
    local target_type="$1"
    local config_file="${2:-$HYSTERIA_CONFIG}"

    if [[ ! -f "$config_file" ]]; then
        return 1  # 文件不存在，没有冲突
    fi

    # 查找同类型的规则
    local in_outbounds=false
    local current_rule_type=""
    local current_rule_name=""

    while IFS= read -r line; do
        # 检测outbounds节点
        if [[ "$line" =~ ^[[:space:]]*outbounds: ]]; then
            in_outbounds=true
            continue
        fi

        # 离开outbounds节点
        if [[ "$in_outbounds" == true ]] && [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*- ]]; then
            in_outbounds=false
        fi

        # 在outbounds节点中
        if [[ "$in_outbounds" == true ]]; then
            # 检测规则名
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
                current_rule_name="${BASH_REMATCH[1]}"
                current_rule_name=$(echo "$current_rule_name" | xargs)  # 去除前后空格
            fi

            # 检测规则类型
            if [[ "$line" =~ ^[[:space:]]*type:[[:space:]]*(.+)$ ]]; then
                current_rule_type="${BASH_REMATCH[1]}"
                current_rule_type=$(echo "$current_rule_type" | xargs)  # 去除前后空格

                # 检查是否与目标类型匹配
                if [[ "$current_rule_type" == "$target_type" ]]; then
                    echo "$current_rule_name"  # 返回现有同类型规则的名称
                    return 0
                fi
            fi
        fi
    done < "$config_file"

    return 1  # 未找到同类型规则
}

# 静默删除指定规则（用于类型覆盖，无用户确认）
delete_existing_rule_silent() {
    local rule_name="$1"

    echo -e "${BLUE}[INFO]${NC} 正在删除现有规则: $rule_name"

    # 创建临时文件
    local temp_config="/tmp/hysteria_delete_temp_$(date +%s).yaml"

    # 智能删除逻辑：完整删除outbound规则和相关ACL条目
    local in_outbound_rule=false
    local in_acl_section=false
    local acl_base_indent=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        local should_keep=true

        # 1. 删除包含规则名的注释
        if [[ "$line" =~ ^[[:space:]]*#.*${rule_name} ]]; then
            should_keep=false
        fi

        # 2. 检测outbound规则块
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*${rule_name}[[:space:]]*$ ]]; then
            in_outbound_rule=true
            should_keep=false
        elif [[ "$in_outbound_rule" == true ]]; then
            # 在outbound规则块中，检查是否结束
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(type|direct|socks5|http|addr|url|mode|username|password|insecure): ]]; then
                in_outbound_rule=false
                should_keep=true
            else
                should_keep=false  # 删除outbound规则块内的所有行
            fi
        fi

        # 3. 检测ACL节点
        if [[ "$line" =~ ^[[:space:]]*acl: ]]; then
            in_acl_section=true
            acl_base_indent=$(echo "$line" | sed 's/acl:.*//')
            should_keep=true
        elif [[ "$in_acl_section" == true ]]; then
            # 检查是否离开ACL节点
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(inline|file): ]]; then
                local line_indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
                if [[ ${#line_indent} -le ${#acl_base_indent} ]]; then
                    in_acl_section=false
                    should_keep=true
                fi
            fi

            # 在ACL节点中处理 - 删除包含目标规则名的行
            if [[ "$in_acl_section" == true ]] && [[ "$line" =~ ${rule_name} ]]; then
                should_keep=false  # 删除ACL中包含目标规则名的条目
            fi
        fi

        # 写入保留的行
        if [[ "$should_keep" == true ]]; then
            echo "$line" >> "$temp_config"
        fi
    done < "$HYSTERIA_CONFIG"

    # 检查删除是否成功
    if grep -q "name: *$rule_name" "$temp_config" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} 删除失败，规则仍存在"
        rm -f "$temp_config"
        return 1
    fi

    # 应用修改
    if safe_move_config "$temp_config" "$HYSTERIA_CONFIG"; then
        echo -e "${GREEN}[SUCCESS]${NC} 现有规则 '$rule_name' 已删除"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} 删除失败，文件操作错误"
        rm -f "$temp_config"
        return 1
    fi
}

# 删除配置文件中的指定outbound规则（用于覆盖操作）
delete_existing_outbound_from_config() {
    local rule_name="$1"
    local config_file="${2:-$HYSTERIA_CONFIG}"

    if [[ -z "$rule_name" ]]; then
        log_error "规则名称不能为空"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        log_warn "配置文件不存在: $config_file"
        return 0  # 文件不存在视为成功删除
    fi

    # 检查文件是否可写
    if [[ ! -w "$config_file" ]]; then
        log_warn "配置文件无写权限: $config_file"
        return 1
    fi

    echo -e "${BLUE}[INFO]${NC} 从配置文件中删除规则: $rule_name"

    # 创建临时文件
    local temp_config
    temp_config=$(create_delete_temp_file)

    # 删除指定的outbound规则
    local in_outbound_rule=false
    local in_outbounds_section=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        local should_keep=true

        # 检测outbounds节点
        if [[ "$line" =~ ^[[:space:]]*outbounds:[[:space:]]*$ ]]; then
            in_outbounds_section=true
            should_keep=true
        elif [[ "$in_outbounds_section" == true ]]; then
            # 在outbounds节点中

            # 检测目标规则开始
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*${rule_name}[[:space:]]*$ ]]; then
                in_outbound_rule=true
                should_keep=false
            elif [[ "$in_outbound_rule" == true ]]; then
                # 在目标规则块中，检查是否结束
                if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(type|direct|socks5|http): ]]; then
                    # 遇到下一个规则或顶级节点，结束当前规则删除
                    in_outbound_rule=false
                    # 检查是否离开outbounds节点
                    if [[ "$line" =~ ^[a-zA-Z]+:[[:space:]]*$ ]]; then
                        in_outbounds_section=false
                    fi
                    should_keep=true
                else
                    # 仍在目标规则块中，继续删除
                    should_keep=false
                fi
            else
                # 不在目标规则块中，检查是否离开outbounds节点
                if [[ "$line" =~ ^[a-zA-Z]+:[[:space:]]*$ ]]; then
                    in_outbounds_section=false
                fi
                should_keep=true
            fi
        fi

        # 保留需要的行
        if [[ "$should_keep" == true ]]; then
            echo "$line" >> "$temp_config"
        fi
    done < "$config_file"

    # 替换原文件 - 增强错误处理
    if mv "$temp_config" "$config_file" 2>/dev/null; then
        echo -e "${GREEN}[SUCCESS]${NC} 规则 '$rule_name' 已从配置文件中删除"
        return 0
    elif cp "$temp_config" "$config_file" 2>/dev/null; then
        # mv失败时尝试cp
        rm -f "$temp_config"
        echo -e "${GREEN}[SUCCESS]${NC} 规则 '$rule_name' 已从配置文件中删除"
        return 0
    else
        log_error "删除规则失败: 文件操作错误，可能是权限问题"
        log_info "临时文件保存在: $temp_config"
        return 1
    fi
}

# 极简稳定的配置应用函数
apply_outbound_simple() {
    local name="$1" type="$2" existing_rule="${3:-}"

    echo -e "${BLUE}[INFO]${NC} 检查配置文件: $HYSTERIA_CONFIG"

    # 检查配置文件
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        echo -e "${RED}[ERROR]${NC} 配置文件不存在: $HYSTERIA_CONFIG"
        return 1
    fi

    # 如果有要覆盖的规则，先删除它
    if [[ -n "$existing_rule" ]]; then
        echo -e "${BLUE}[INFO]${NC} 删除现有规则: $existing_rule"
        if ! delete_existing_rule_silent "$existing_rule"; then
            echo -e "${RED}[ERROR]${NC} 删除现有规则失败"
            return 1
        fi
    fi

    # 直接操作，不创建不必要的备份

    # 创建临时文件
    local temp_file="/tmp/hysteria_temp_$$_$(date +%s).yaml"
    echo -e "${BLUE}[INFO]${NC} 创建临时文件: $temp_file"

    if ! cp "$HYSTERIA_CONFIG" "$temp_file" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} 无法创建临时文件"
        return 1
    fi

    # 添加出站配置
    echo -e "${BLUE}[INFO]${NC} 添加出站配置到临时文件"

    if grep -q "^[[:space:]]*outbounds:" "$temp_file" 2>/dev/null; then
        echo -e "${BLUE}[INFO]${NC} 检测到现有outbounds配置，插入新规则"

        # 创建新的临时文件用于正确插入
        local temp_file2="/tmp/hysteria_merge_$$_$(date +%s).yaml"
        local in_outbounds=false
        local inserted=false

        while IFS= read -r line || [[ -n "$line" ]]; do
            # 检测outbounds节点开始
            if [[ "$line" =~ ^[[:space:]]*outbounds: ]]; then
                in_outbounds=true
                echo "$line" >> "$temp_file2"
                continue
            fi

            # 在outbounds节点中，找到合适位置插入
            if [[ "$in_outbounds" == true ]] && [[ "$inserted" == false ]]; then
                # 如果遇到其他顶级节点，在此之前插入新规则
                if [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*- ]]; then
                    # 插入新规则
                    cat >> "$temp_file2" << EOF

  # 新增出站规则 - $name ($type)
  - name: $name
    type: $type
EOF
                    case $type in
                        "direct")
                            echo "    direct:" >> "$temp_file2"
                            echo "      mode: auto" >> "$temp_file2"
                            ;;
                        "socks5")
                            echo "    socks5:" >> "$temp_file2"
                            echo "      addr: \"${SOCKS5_ADDR:-127.0.0.1:1080}\"" >> "$temp_file2"
                            if [[ -n "${SOCKS5_USERNAME:-}" ]]; then
                                echo "      username: \"$SOCKS5_USERNAME\"" >> "$temp_file2"
                                echo "      password: \"$SOCKS5_PASSWORD\"" >> "$temp_file2"
                            fi
                            ;;
                        "http")
                            echo "    http:" >> "$temp_file2"
                            echo "      url: \"${HTTP_URL:-http://127.0.0.1:8080}\"" >> "$temp_file2"
                            if [[ -n "${HTTP_INSECURE:-}" ]]; then
                                echo "      insecure: $HTTP_INSECURE" >> "$temp_file2"
                            fi
                            ;;
                    esac
                    echo "" >> "$temp_file2"
                    inserted=true
                    in_outbounds=false
                fi
            fi

            echo "$line" >> "$temp_file2"
        done < "$temp_file"

        # 如果在文件末尾仍未插入，在outbounds节点末尾添加
        if [[ "$inserted" == false ]] && [[ "$in_outbounds" == true ]]; then
            cat >> "$temp_file2" << EOF

  # 新增出站规则 - $name ($type)
  - name: $name
    type: $type
EOF
            case $type in
                "direct")
                    echo "    direct:" >> "$temp_file2"
                    echo "      mode: auto" >> "$temp_file2"
                    ;;
                "socks5")
                    echo "    socks5:" >> "$temp_file2"
                    echo "      addr: \"${SOCKS5_ADDR:-127.0.0.1:1080}\"" >> "$temp_file2"
                    ;;
                "http")
                    echo "    http:" >> "$temp_file2"
                    echo "      url: \"${HTTP_URL:-http://127.0.0.1:8080}\"" >> "$temp_file2"
                    ;;
            esac
        fi

        # 替换原文件
        mv "$temp_file2" "$temp_file"

        # 智能ACL规则同步
        echo -e "${BLUE}[INFO]${NC} 同步ACL路由规则"
        if grep -q "^[[:space:]]*acl:" "$temp_file" 2>/dev/null; then
            echo -e "${BLUE}[INFO]${NC} 检测到现有ACL规则，智能添加路由条目"

            # 创建ACL添加的临时文件
            local temp_acl="/tmp/hysteria_acl_add_$$_$(date +%s).yaml"
            local in_acl_section=false
            local in_inline_section=false
            local acl_base_indent=""
            local added_acl_rule=false

            while IFS= read -r line || [[ -n "$line" ]]; do
                # 检测ACL节点
                if [[ "$line" =~ ^[[:space:]]*acl: ]]; then
                    in_acl_section=true
                    acl_base_indent=$(echo "$line" | sed 's/acl:.*//')
                    echo "$line" >> "$temp_acl"
                    continue
                fi

                # 在ACL节点中
                if [[ "$in_acl_section" == true ]]; then
                    # 检查是否离开ACL节点
                    if [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(inline|file): ]]; then
                        local line_indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
                        if [[ ${#line_indent} -le ${#acl_base_indent} ]]; then
                            # 离开ACL节点前，如果还没添加规则，则添加
                            if [[ "$added_acl_rule" == false ]]; then
                                echo "    - ${name}(all)  # 新增出站规则" >> "$temp_acl"
                                added_acl_rule=true
                            fi
                            in_acl_section=false
                            in_inline_section=false
                        fi
                    fi

                    # 检测inline节点
                    if [[ "$line" =~ ^[[:space:]]*inline:[[:space:]]*$ ]]; then
                        in_inline_section=true
                        echo "$line" >> "$temp_acl"
                        continue
                    fi

                    # 在inline节点中，添加新规则（在第一个条目后）
                    if [[ "$in_inline_section" == true ]] && [[ "$added_acl_rule" == false ]] && [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
                        echo "$line" >> "$temp_acl"
                        echo "    - ${name}(all)  # 新增出站规则" >> "$temp_acl"
                        added_acl_rule=true
                        continue
                    fi
                fi

                echo "$line" >> "$temp_acl"
            done < "$temp_file"

            # 如果文件末尾仍在ACL中且未添加规则
            if [[ "$in_acl_section" == true ]] && [[ "$added_acl_rule" == false ]]; then
                echo "    - ${name}(all)  # 新增出站规则" >> "$temp_acl"
            fi

            # 替换原文件
            mv "$temp_acl" "$temp_file"
        else
            echo -e "${BLUE}[INFO]${NC} 创建新的ACL规则配置"
            cat >> "$temp_file" << EOF

# ACL规则 - 路由配置
acl:
  inline:
    - ${name}(all)  # 新增出站规则路由
EOF
        fi

    else
        echo -e "${BLUE}[INFO]${NC} 未检测到outbounds配置，创建新节点"
        case $type in
            "direct")
                cat >> "$temp_file" << EOF

# 出站规则配置
outbounds:
  - name: $name
    type: direct
    direct:
      mode: auto

# ACL规则 - 路由配置
acl:
  inline:
    - $name(all)  # 所有流量通过此规则直连
EOF
                ;;
            "socks5")
                cat >> "$temp_file" << EOF

# 出站规则配置
outbounds:
  - name: $name
    type: socks5
    socks5:
      addr: "${SOCKS5_ADDR:-127.0.0.1:1080}"

# ACL规则 - 路由配置
acl:
  inline:
    - $name(all)  # 所有流量通过此规则代理
EOF
                ;;
        esac
    fi

    # 语法验证功能已移除 - 验证结果不准确且没有实际作用

    # 应用配置
    echo -e "${BLUE}[INFO]${NC} 应用新配置"
    if safe_move_config "$temp_file" "$HYSTERIA_CONFIG"; then
        echo -e "${GREEN}[SUCCESS]${NC} 配置已成功应用"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} 配置应用失败"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# 创建安全的临时文件 - 兼容性改进版
create_temp_config() {
    local temp_config

    # 尝试不同的mktemp选项以确保兼容性
    if command -v mktemp >/dev/null 2>&1; then
        # 尝试标准方式
        if temp_config=$(mktemp -t hysteria_config_XXXXXX.yaml 2>/dev/null); then
            log_debug "使用mktemp -t创建临时文件: $temp_config"
        # 备选方式1: 不使用-t选项
        elif temp_config=$(mktemp /tmp/hysteria_config_XXXXXX.yaml 2>/dev/null); then
            log_debug "使用mktemp备选方式创建临时文件: $temp_config"
        # 备选方式2: 手动创建
        else
            temp_config="/tmp/hysteria_config_$$_$(date +%s).yaml"
            if ! touch "$temp_config" 2>/dev/null; then
                log_error "无法创建临时文件: $temp_config"
                return 1
            fi
            log_debug "手动创建临时文件: $temp_config"
        fi
    else
        # 如果没有mktemp命令，手动创建
        temp_config="/tmp/hysteria_config_$$_$(date +%s).yaml"
        if ! touch "$temp_config" 2>/dev/null; then
            log_error "无法创建临时文件: $temp_config"
            return 1
        fi
        log_debug "手动创建临时文件（无mktemp）: $temp_config"
    fi

    # 设置适当权限
    if ! chmod 600 "$temp_config" 2>/dev/null; then
        log_warn "无法设置临时文件权限，继续执行"
    fi

    echo "$temp_config"
}

# 智能合并outbounds配置
merge_outbound_config() {
    local config_file="$1" name="$2" type="$3"

    # 检查是否已存在outbounds节点
    if grep -q "^[[:space:]]*outbounds:" "$config_file"; then
        log_info "检测到现有outbounds配置，添加到现有列表"
        add_to_existing_outbounds "$config_file" "$name" "$type"
    else
        log_info "未检测到outbounds配置，创建新的outbounds节点"
        add_new_outbounds_section "$config_file" "$name" "$type"
    fi
}

# 添加到现有outbounds列表
add_to_existing_outbounds() {
    local config_file="$1" name="$2" type="$3"

    case $type in
        "direct")
            # 在outbounds节点下添加新项
            cat >> "$config_file" << EOF

# 新增出站规则 - $name (Direct)
  - name: $name
    type: direct
    direct:
      mode: auto
EOF
            if [[ -n "${DIRECT_INTERFACE:-}" ]]; then
                echo "      bindDevice: \"$DIRECT_INTERFACE\"" >> "$config_file"
            fi
            if [[ -n "${DIRECT_IPV4:-}" ]]; then
                echo "      bindIPv4: \"$DIRECT_IPV4\"" >> "$config_file"
            fi
            if [[ -n "${DIRECT_IPV6:-}" ]]; then
                echo "      bindIPv6: \"$DIRECT_IPV6\"" >> "$config_file"
            fi
            ;;
        "socks5")
            cat >> "$config_file" << EOF

# 新增出站规则 - $name (SOCKS5)
  - name: $name
    type: socks5
    socks5:
      addr: "${SOCKS5_ADDR:-proxy.example.com:1080}"
EOF
            if [[ -n "${SOCKS5_USERNAME:-}" ]]; then
                echo "      username: \"$SOCKS5_USERNAME\"" >> "$config_file"
                echo "      password: \"$SOCKS5_PASSWORD\"" >> "$config_file"
            fi
            ;;
        "http")
            cat >> "$config_file" << EOF

# 新增出站规则 - $name (HTTP)
  - name: $name
    type: http
    http:
      url: "${HTTP_URL:-http://proxy.example.com:8080}"
EOF
            if [[ -n "${HTTP_INSECURE:-}" ]]; then
                echo "      insecure: $HTTP_INSECURE" >> "$config_file"
            fi
            ;;
    esac
}

# 创建新的outbounds节点
add_new_outbounds_section() {
    local config_file="$1" name="$2" type="$3"

    echo "" >> "$config_file"
    echo "# 出站规则配置" >> "$config_file"
    generate_direct_yaml_config "$name" >> "$config_file"
}

# 实际应用配置到文件的函数 - 改进版
apply_outbound_to_config() {
    local name="$1" type="$2"

    # 检查配置文件是否存在
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        log_error "Hysteria2 配置文件不存在: $HYSTERIA_CONFIG"
        return 1
    fi

    # 创建安全的临时文件
    local temp_config
    log_info "开始创建临时文件..."
    temp_config=$(create_temp_config)
    if [[ $? -ne 0 ]] || [[ -z "$temp_config" ]]; then
        log_error "创建临时文件失败"
        return 1
    fi
    log_info "临时文件已创建: $temp_config"

    # 复制原配置并检查结果
    log_info "复制配置文件到临时位置..."
    if ! cp "$HYSTERIA_CONFIG" "$temp_config"; then
        log_error "无法复制配置文件到临时位置"
        log_error "源文件: $HYSTERIA_CONFIG"
        log_error "目标文件: $temp_config"
        rm -f "$temp_config"
        return 1
    fi
    log_info "配置文件复制成功"

    # 备份功能已移除，直接应用配置

    # 智能合并配置
    case $type in
        "direct"|"socks5"|"http")
            merge_outbound_config "$temp_config" "$name" "$type"
            ;;
        *)
            log_error "不支持的出站类型: $type"
            rm -f "$temp_config"
            return 1
            ;;
    esac

    # 语法验证功能已移除 - 验证结果不准确且没有实际作用

    # 原子性替换配置文件
    if mv "$temp_config" "$HYSTERIA_CONFIG"; then
        log_success "配置已成功应用到: $HYSTERIA_CONFIG"
        return 0
    else
        log_error "配置应用失败，请检查文件权限和磁盘空间"
        rm -f "$temp_config"
        return 1
    fi
}

# 生成 Direct 类型的 YAML 配置
generate_direct_yaml_config() {
    local name="$1"

    echo ""
    echo "# 出站规则 - $name (Direct)"
    echo "outbounds:"
    echo "  - name: $name"
    echo "    type: direct"
    echo "    direct:"
    echo "      mode: auto"

    if [[ -n "${DIRECT_INTERFACE:-}" ]]; then
        echo "      bindDevice: \"$DIRECT_INTERFACE\""
    fi
    if [[ -n "${DIRECT_IPV4:-}" ]]; then
        echo "      bindIPv4: \"$DIRECT_IPV4\""
    fi
    if [[ -n "${DIRECT_IPV6:-}" ]]; then
        echo "      bindIPv6: \"$DIRECT_IPV6\""
    fi
}

# 生成 SOCKS5 类型的 YAML 配置
generate_socks5_yaml_config() {
    local name="$1"

    echo ""
    echo "# 出站规则 - $name (SOCKS5)"
    echo "outbounds:"
    echo "  - name: $name"
    echo "    type: socks5"
    echo "    socks5:"
    echo "      addr: \"${SOCKS5_ADDR:-proxy.example.com:1080}\""

    if [[ -n "${SOCKS5_USERNAME:-}" ]]; then
        echo "      username: \"$SOCKS5_USERNAME\""
        echo "      password: \"$SOCKS5_PASSWORD\""
    fi
}

# 生成 HTTP 类型的 YAML 配置
generate_http_yaml_config() {
    local name="$1"

    echo ""
    echo "# 出站规则 - $name (HTTP)"
    echo "outbounds:"
    echo "  - name: $name"
    echo "    type: http"
    echo "    http:"
    echo "      url: \"${HTTP_URL:-http://proxy.example.com:8080}\""

    if [[ -n "${HTTP_INSECURE:-}" ]]; then
        echo "      insecure: $HTTP_INSECURE"
    fi
}

# 备份当前配置
# 备份功能已移除








# 修改现有出站配置
modify_outbound_config() {
    log_info "修改现有出站配置"

    echo -e "${BLUE}=== 修改出站配置 ===${NC}"
    echo ""

    # 检查是否有出站配置
    if ! grep -q "^outbounds:" "$HYSTERIA_CONFIG"; then
        echo -e "${YELLOW}当前没有出站配置可修改${NC}"
        echo "请先添加出站规则"
        wait_for_user
        return
    fi

    # 列出现有的出站配置
    echo -e "${GREEN}当前出站规则：${NC}"
    local outbound_names=($(grep -A 1 "^[[:space:]]*-[[:space:]]*name:" "$HYSTERIA_CONFIG" | grep "name:" | sed 's/.*name:[[:space:]]*//' | tr -d '"'))

    if [[ ${#outbound_names[@]} -eq 0 ]]; then
        echo -e "${YELLOW}没有找到出站规则名称${NC}"
        wait_for_user
        return
    fi

    for i in "${!outbound_names[@]}"; do
        echo "$((i+1)). ${outbound_names[$i]}"
    done
    echo ""

    read -p "请选择要修改的出站规则 [1-${#outbound_names[@]}]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#outbound_names[@]} ]]; then
        log_error "无效选择"
        return
    fi

    local selected_outbound="${outbound_names[$((choice-1))]}"

    echo -e "${BLUE}修改选项：${NC}"
    echo "1. 修改规则名称"
    echo "2. 修改服务器地址"
    echo "3. 修改用户名"
    echo "4. 修改密码"
    echo "5. 删除此出站规则"
    echo ""

    read -p "请选择操作 [1-5]: " modify_choice

    case $modify_choice in
        1) modify_rule_name "$selected_outbound" ;;
        2) modify_server_address "$selected_outbound" ;;
        3) modify_username "$selected_outbound" ;;
        4) modify_password "$selected_outbound" ;;
        5) delete_outbound_rule "$selected_outbound" ;;
        *)
            log_error "无效选择"
            ;;
    esac
}

# 删除出站规则
delete_outbound_rule() {
    local rule_name="$1"

    echo -e "${RED}[WARNING]${NC} 即将删除出站规则: $rule_name"
    echo -e "${YELLOW}此操作不可逆，请确认操作${NC}"
    echo -n "确认删除？ [y/N]: "
    local confirm
    read -r confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[INFO]${NC} 取消删除操作"
        return
    fi

    echo -e "${BLUE}[INFO]${NC} 开始删除出站规则: $rule_name"

    # 直接删除，不创建不必要的备份

    # 创建临时文件
    local temp_config="/tmp/hysteria_delete_temp_$(date +%s).yaml"

    # 智能删除逻辑：完整删除outbound规则和相关ACL条目
    local in_outbound_rule=false
    local in_acl_section=false
    local acl_base_indent=""
    local delete_acl_inline=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        local should_keep=true

        # 1. 删除包含规则名的注释
        if [[ "$line" =~ ^[[:space:]]*#.*${rule_name} ]]; then
            should_keep=false
        fi

        # 2. 检测outbound规则块
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*${rule_name}[[:space:]]*$ ]]; then
            in_outbound_rule=true
            should_keep=false
        elif [[ "$in_outbound_rule" == true ]]; then
            # 在outbound规则块中，检查是否结束
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(type|direct|socks5|http|addr|url|mode|username|password|insecure): ]]; then
                in_outbound_rule=false
                should_keep=true
            else
                should_keep=false  # 删除outbound规则块内的所有行
            fi
        fi

        # 3. 检测ACL节点
        if [[ "$line" =~ ^[[:space:]]*acl:[[:space:]]*$ ]]; then
            in_acl_section=true
            acl_base_indent=$(echo "$line" | sed 's/acl:.*//')
            should_keep=true
        elif [[ "$line" =~ ^[[:space:]]*acl: ]]; then
            in_acl_section=true
            acl_base_indent=$(echo "$line" | sed 's/acl:.*//')
            should_keep=true
        elif [[ "$in_acl_section" == true ]]; then
            # 检查是否离开ACL节点
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(inline|file): ]]; then
                local line_indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
                if [[ ${#line_indent} -le ${#acl_base_indent} ]]; then
                    in_acl_section=false
                    should_keep=true
                fi
            fi

            # 在ACL节点中处理
            if [[ "$in_acl_section" == true ]]; then
                # 检测inline节点开始
                if [[ "$line" =~ ^[[:space:]]*inline:[[:space:]]*$ ]]; then
                    delete_acl_inline=false
                    should_keep=true
                # 在inline节点中检查包含目标规则名的行
                elif [[ "$line" =~ ${rule_name} ]]; then
                    should_keep=false  # 删除ACL中包含目标规则名的条目
                elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*${rule_name}[[:space:]]*$ ]]; then
                    should_keep=false  # 删除单独的规则名条目
                else
                    should_keep=true
                fi
            fi
        fi

        # 写入保留的行
        if [[ "$should_keep" == true ]]; then
            echo "$line" >> "$temp_config"
        fi
    done < "$HYSTERIA_CONFIG"

    # 检查删除是否成功
    if grep -q "name: *$rule_name" "$temp_config" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} 删除失败，规则仍存在"
        rm -f "$temp_config"
        return 1
    fi

    # 应用修改
    if mv "$temp_config" "$HYSTERIA_CONFIG" 2>/dev/null; then
        echo -e "${GREEN}[SUCCESS]${NC} 出站规则 '$rule_name' 已删除"

        # 询问是否重启服务
        echo ""
        read -p "是否重启 Hysteria2 服务以应用配置？ [y/N]: " restart_service

        if [[ $restart_service =~ ^[Yy]$ ]]; then
            if systemctl restart hysteria-server 2>/dev/null; then
                echo -e "${GREEN}[SUCCESS]${NC} 服务已重启"
            else
                echo -e "${YELLOW}[WARN]${NC} 服务重启失败，请手动重启"
            fi
        fi
    else
        echo -e "${RED}[ERROR]${NC} 配置应用失败"
        return 1
    fi

    echo ""
    wait_for_user
}



# 备份和恢复配置
# 备份功能已移除

# 恢复配置备份
# 备份功能已移除

# 列出配置备份
# 备份功能已移除

# 主出站管理函数
manage_outbound() {
    init_outbound_manager

    while true; do
        show_outbound_menu

        local choice
        read -p "请选择操作 [0-5]: " choice

        case $choice in
            1) view_outbound_rules ;;
            2) add_outbound_rule_new ;;
            3) apply_outbound_rule ;;
            4) modify_outbound_rule ;;
            5) delete_outbound_rule_new ;;
            0)
                log_info "返回主菜单"
                break
                ;;
            *)
                log_error "无效选择，请重新输入"
                wait_for_user
                ;;
        esac
    done
}

# 修改规则名称
modify_rule_name() {
    local old_name="$1"

    echo -e "${BLUE}=== 修改规则名称 ===${NC}"
    echo "当前规则名称: ${CYAN}$old_name${NC}"
    echo ""

    read -p "请输入新的规则名称: " new_name

    if [[ -z "$new_name" ]]; then
        log_error "规则名称不能为空"
        return
    fi

    # 检查新名称是否已存在
    if grep -q "name: *$new_name" "$HYSTERIA_CONFIG" 2>/dev/null; then
        log_error "规则名称 '$new_name' 已存在"
        return
    fi

    # 执行替换
    if sed -i.bak "s/name: *$old_name/name: $new_name/g" "$HYSTERIA_CONFIG" 2>/dev/null; then
        # 同时更新ACL中的引用
        sed -i.bak "s/- $old_name/- $new_name/g" "$HYSTERIA_CONFIG" 2>/dev/null
        rm -f "$HYSTERIA_CONFIG.bak"

        log_success "规则名称已更新: $old_name → $new_name"
        ask_restart_service
    else
        log_error "修改失败"
    fi
}

# 修改服务器地址
modify_server_address() {
    local rule_name="$1"

    echo -e "${BLUE}=== 修改服务器地址 ===${NC}"
    echo "规则名称: ${CYAN}$rule_name${NC}"
    echo ""

    # 获取当前地址
    local current_addr=$(sed -n "/- name: $rule_name/,/^  - name:/p" "$HYSTERIA_CONFIG" | grep -E "(addr|url):" | head -1 | sed 's/.*: *//')
    if [[ -n "$current_addr" ]]; then
        echo "当前地址: ${YELLOW}$current_addr${NC}"
    fi

    read -p "请输入新的服务器地址: " new_addr

    if [[ -z "$new_addr" ]]; then
        log_error "服务器地址不能为空"
        return
    fi

    # 创建临时文件进行修改
    local temp_config="/tmp/hysteria_modify_addr_$(date +%s).yaml"
    local in_target_rule=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*${rule_name}[[:space:]]*$ ]]; then
            in_target_rule=true
            echo "$line" >> "$temp_config"
        elif [[ "$in_target_rule" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(type|direct|socks5|http|addr|url|mode|username|password|insecure): ]]; then
                in_target_rule=false
                echo "$line" >> "$temp_config"
            elif [[ "$line" =~ ^[[:space:]]*(addr|url):[[:space:]]* ]]; then
                local indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
                if [[ "$line" =~ addr: ]]; then
                    echo "${indent}addr: $new_addr" >> "$temp_config"
                else
                    echo "${indent}url: $new_addr" >> "$temp_config"
                fi
            else
                echo "$line" >> "$temp_config"
            fi
        else
            echo "$line" >> "$temp_config"
        fi
    done < "$HYSTERIA_CONFIG"

    if mv "$temp_config" "$HYSTERIA_CONFIG" 2>/dev/null; then
        log_success "服务器地址已更新"
        ask_restart_service
    else
        log_error "修改失败"
        rm -f "$temp_config"
    fi
}

# 修改用户名
modify_username() {
    local rule_name="$1"

    echo -e "${BLUE}=== 修改用户名 ===${NC}"
    echo "规则名称: ${CYAN}$rule_name${NC}"
    echo ""

    # 获取当前用户名
    local current_username=$(sed -n "/- name: $rule_name/,/^  - name:/p" "$HYSTERIA_CONFIG" | grep "username:" | sed 's/.*username: *//' | tr -d '"')
    if [[ -n "$current_username" ]]; then
        echo "当前用户名: ${YELLOW}$current_username${NC}"
    fi

    read -p "请输入新的用户名 (留空则删除): " new_username

    # 修改用户名
    modify_config_field "$rule_name" "username" "$new_username"
}

# 修改密码
modify_password() {
    local rule_name="$1"

    echo -e "${BLUE}=== 修改密码 ===${NC}"
    echo "规则名称: ${CYAN}$rule_name${NC}"
    echo ""

    read -s -p "请输入新密码 (留空则删除): " new_password
    echo ""

    # 修改密码
    modify_config_field "$rule_name" "password" "$new_password"
}

# 通用配置字段修改函数
modify_config_field() {
    local rule_name="$1"
    local field_name="$2"
    local new_value="$3"

    local temp_config="/tmp/hysteria_modify_${field_name}_$(date +%s).yaml"
    local in_target_rule=false
    local field_found=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*${rule_name}[[:space:]]*$ ]]; then
            in_target_rule=true
            echo "$line" >> "$temp_config"
        elif [[ "$in_target_rule" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(type|direct|socks5|http|addr|url|mode|username|password|insecure): ]]; then
                # 如果没找到字段且有新值，在规则结束前插入
                if [[ "$field_found" == false && -n "$new_value" ]]; then
                    local base_indent="      " # 假设基础缩进
                    echo "${base_indent}${field_name}: $new_value" >> "$temp_config"
                fi
                in_target_rule=false
                echo "$line" >> "$temp_config"
            elif [[ "$line" =~ ^[[:space:]]*${field_name}:[[:space:]]* ]]; then
                field_found=true
                if [[ -n "$new_value" ]]; then
                    local indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
                    echo "${indent}${field_name}: $new_value" >> "$temp_config"
                fi
                # 如果新值为空，则跳过此行（删除字段）
            else
                echo "$line" >> "$temp_config"
            fi
        else
            echo "$line" >> "$temp_config"
        fi
    done < "$HYSTERIA_CONFIG"

    if mv "$temp_config" "$HYSTERIA_CONFIG" 2>/dev/null; then
        if [[ -n "$new_value" ]]; then
            log_success "${field_name} 已更新"
        else
            log_success "${field_name} 已删除"
        fi
        ask_restart_service
    else
        log_error "修改失败"
        rm -f "$temp_config"
    fi
}

# 询问是否重启服务
ask_restart_service() {
    echo ""
    read -p "是否重启 Hysteria2 服务以应用配置？ [y/N]: " restart_choice

    if [[ $restart_choice =~ ^[Yy]$ ]]; then
        if systemctl restart hysteria-server 2>/dev/null; then
            log_success "服务已重启"
        else
            log_error "服务重启失败，请手动重启"
        fi
    fi
}

# ===== 新的核心功能实现 =====

# 规则库文件路径
# 规则库目录变量
RULES_DIR="/etc/hysteria/outbound-rules"
RULES_LIBRARY="$RULES_DIR/rules-library.yaml"
RULES_STATE="$RULES_DIR/rules-state.yaml"

# 初始化规则库
init_rules_library() {
    if [[ ! -d "$RULES_DIR" ]]; then
        mkdir -p "$RULES_DIR" 2>/dev/null || {
            log_error "无法创建规则库目录，将使用临时目录"
            RULES_DIR="/tmp/hysteria-rules"
            RULES_LIBRARY="$RULES_DIR/rules-library.yaml"
            RULES_STATE="$RULES_DIR/rules-state.yaml"
            mkdir -p "$RULES_DIR"
        }
    fi

    if [[ ! -f "$RULES_LIBRARY" ]]; then
        cat > "$RULES_LIBRARY" << 'EOF'
# Hysteria2 出站规则库
# 格式：每个规则包含type、description和config字段
version: "1.0"
last_modified: ""
rules:
  # 示例规则（已注释）:
  # direct_rule:
  #   type: direct
  #   description: "直连规则示例"
  #   config:
  #     mode: auto
  #     bindDevice: eth0
EOF
    fi

    if [[ ! -f "$RULES_STATE" ]]; then
        cat > "$RULES_STATE" << 'EOF'
# Hysteria2 出站规则状态
applied_rules: []
last_sync: ""
EOF
    fi
}

# 1. 查看出站规则
view_outbound_rules() {
    init_rules_library

    echo -e "${BLUE}=== 出站规则总览 ===${NC}"
    echo ""

    # 显示配置文件中的规则
    echo -e "${GREEN}📄 配置文件中的规则：${NC}"
    if [[ -f "$HYSTERIA_CONFIG" ]] && grep -q "^[[:space:]]*outbounds:" "$HYSTERIA_CONFIG"; then
        local rule_count=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
                local rule_name="${BASH_REMATCH[1]}"
                rule_name=$(echo "$rule_name" | tr -d '"' | xargs)
                ((rule_count++))
                echo "  $rule_count. $rule_name ✅"
            fi
        done < <(sed -n '/^[[:space:]]*outbounds:/,/^[a-zA-Z]/p' "$HYSTERIA_CONFIG" | head -n -1)

        if [[ $rule_count -eq 0 ]]; then
            echo "  (无规则)"
        fi
    else
        echo "  (无规则)"
    fi

    echo ""

    # 显示规则库中的规则
    echo -e "${CYAN}📚 规则库中的规则：${NC}"
    if [[ -f "$RULES_LIBRARY" ]] && grep -q "rules:" "$RULES_LIBRARY"; then
        local lib_count=0
        # 使用简单可靠的grep方法直接提取规则名
        while IFS= read -r rule_name; do
            if [[ -n "$rule_name" ]]; then
                ((lib_count++))
                # 检查是否已应用 - 只根据配置文件实际状态
                local status="❌ 未应用"
                # 只检查配置文件中是否存在此规则
                if [[ -f "$HYSTERIA_CONFIG" ]] && grep -q "name:[[:space:]]*[\"']*${rule_name}[\"']*[[:space:]]*$" "$HYSTERIA_CONFIG" 2>/dev/null; then
                    status="✅ 已应用"
                fi
                echo "  $lib_count. $rule_name $status"
            fi
        done < <(grep -o "^[[:space:]]\{2\}[a-zA-Z_][a-zA-Z0-9_]*:" "$RULES_LIBRARY" | sed 's/^[[:space:]]\{2\}\([^:]*\):.*/\1/')

        if [[ $lib_count -eq 0 ]]; then
            echo "  (无规则)"
        fi
    else
        echo "  (无规则)"
    fi

    echo ""

    # 询问是否查看单个规则详细参数
    echo -e "${BLUE}是否查看特定规则的详细参数？${NC}"
    echo -e "${GREEN}1.${NC} 是，选择规则查看详细参数"
    echo -e "${YELLOW}2.${NC} 否，返回上级菜单"
    echo ""
    read -p "请选择 [1-2]: " detail_choice

    case $detail_choice in
        1)
            view_single_rule_details
            ;;
        2)
            ;;
        *)
            echo ""
            echo -e "${YELLOW}无效选择，返回上级菜单${NC}"
            ;;
    esac

    wait_for_user
}

# 查看单个规则详细参数
view_single_rule_details() {
    echo ""
    echo -e "${BLUE}=== 查看规则详细参数 ===${NC}"
    echo ""

    # 列出规则库中的规则
    local rules=()
    local rule_count=0

    echo -e "${CYAN}📚 规则库中的规则：${NC}"
    while IFS= read -r rule_name; do
        if [[ -n "$rule_name" ]]; then
            rules+=("$rule_name")
            ((rule_count++))
            # 检查是否已应用
            local status="❌ 未应用"
            if grep -q "- $rule_name" "$RULES_STATE" 2>/dev/null; then
                status="✅ 已应用"
            fi
            echo "  $rule_count. $rule_name $status"
        fi
    done < <(grep -o "^[[:space:]]\{2\}[a-zA-Z_][a-zA-Z0-9_]*:" "$RULES_LIBRARY" | sed 's/^[[:space:]]\{2\}\([^:]*\):.*/\1/')

    if [[ ${#rules[@]} -eq 0 ]]; then
        echo "  (无规则)"
        echo ""
        return
    fi

    echo ""
    read -p "请选择要查看的规则 [1-$rule_count]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt $rule_count ]]; then
        echo -e "${RED}无效选择${NC}"
        return 1
    fi

    local selected_rule="${rules[$((choice-1))]}"

    echo ""
    echo -e "${BLUE}=== 规则详细信息: ${CYAN}$selected_rule${NC} ===${NC}"
    echo ""

    # 获取规则基本信息
    echo -e "${GREEN}📋 基本信息：${NC}"
    local rule_type=$(awk -v rule="$selected_rule" '
    BEGIN { in_rule = 0 }
    $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; next }
    in_rule && /^[[:space:]]*type:[[:space:]]*/ {
        gsub(/^[[:space:]]*type:[[:space:]]*/, "");
        gsub(/[[:space:]]*$/, "");
        print $0;
        exit
    }
    in_rule && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ { in_rule = 0 }
    ' "$RULES_LIBRARY")

    local rule_desc=$(awk -v rule="$selected_rule" '
    BEGIN { in_rule = 0 }
    $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; next }
    in_rule && /^[[:space:]]*description:[[:space:]]*/ {
        gsub(/^[[:space:]]*description:[[:space:]]*"?/, "");
        gsub(/"?[[:space:]]*$/, "");
        print $0;
        exit
    }
    in_rule && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ { in_rule = 0 }
    ' "$RULES_LIBRARY")

    echo "  规则名称: $selected_rule"
    echo "  规则类型: ${rule_type:-"未知"}"
    echo "  规则描述: ${rule_desc:-"无描述"}"

    # 检查应用状态
    local applied_status="❌ 未应用"
    if grep -q "- $selected_rule" "$RULES_STATE" 2>/dev/null; then
        applied_status="✅ 已应用"
    fi
    echo "  应用状态: $applied_status"

    echo ""

    # 显示配置参数
    echo -e "${GREEN}⚙️  配置参数：${NC}"
    case "$rule_type" in
        "direct")
            show_direct_parameters "$selected_rule"
            ;;
        "socks5")
            show_socks5_parameters "$selected_rule"
            ;;
        "http")
            show_http_parameters "$selected_rule"
            ;;
        *)
            echo "  不支持的规则类型: $rule_type"
            ;;
    esac

    echo ""
}

# 显示direct类型参数
show_direct_parameters() {
    local rule_name="$1"
    echo "  类型: Direct (直连)"

    local mode=$(get_rule_config_value "$rule_name" "mode")
    local bindIPv4=$(get_rule_config_value "$rule_name" "bindIPv4")
    local bindIPv6=$(get_rule_config_value "$rule_name" "bindIPv6")
    local bindDevice=$(get_rule_config_value "$rule_name" "bindDevice")
    local fastOpen=$(get_rule_config_value "$rule_name" "fastOpen")

    echo "  连接模式 (mode): ${mode:-"auto (默认)"}"
    echo "  绑定IPv4 (bindIPv4): ${bindIPv4:-"未设置"}"
    echo "  绑定IPv6 (bindIPv6): ${bindIPv6:-"未设置"}"
    echo "  绑定设备 (bindDevice): ${bindDevice:-"未设置"}"
    echo "  快速打开 (fastOpen): ${fastOpen:-"false (默认)"}"
}

# 显示socks5类型参数
show_socks5_parameters() {
    local rule_name="$1"
    echo "  类型: SOCKS5 代理"

    local addr=$(get_rule_config_value "$rule_name" "addr")
    local username=$(get_rule_config_value "$rule_name" "username")
    local password=$(get_rule_config_value "$rule_name" "password")

    echo "  代理地址 (addr): ${addr:-"未设置"}"
    echo "  用户名 (username): ${username:-"未设置"}"
    echo "  密码 (password): ${password:+"***已设置***"}"
    [[ -z "$password" ]] && echo "  密码 (password): 未设置"
}

# 显示http类型参数
show_http_parameters() {
    local rule_name="$1"
    echo "  类型: HTTP/HTTPS 代理"

    local url=$(get_rule_config_value "$rule_name" "url")
    local insecure=$(get_rule_config_value "$rule_name" "insecure")

    echo "  代理URL (url): ${url:-"未设置"}"
    echo "  忽略TLS验证 (insecure): ${insecure:-"false (默认)"}"
}

# 2. 新增出站规则
add_outbound_rule_new() {
    init_rules_library

    echo -e "${BLUE}=== 新增出站规则 ===${NC}"
    echo ""

    # 获取规则名称
    local rule_name
    while true; do
        read -p "规则名称 (字母、数字、下划线): " rule_name

        if [[ -z "$rule_name" ]]; then
            echo -e "${RED}规则名称不能为空${NC}"
            continue
        fi

        if [[ ! "$rule_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo -e "${RED}规则名称只能包含字母、数字和下划线${NC}"
            continue
        fi

        # 检查是否已存在（检查2级缩进的规则名）
        if grep -q "^[[:space:]]\{2\}$rule_name:[[:space:]]*$" "$RULES_LIBRARY" 2>/dev/null; then
            echo -e "${RED}已存在同名的规则，需要重新录入其他名称${NC}"
            continue
        fi

        break
    done

    # 获取规则描述
    read -p "规则描述: " rule_desc
    if [[ -z "$rule_desc" ]]; then
        rule_desc="$rule_name 出站规则"
    fi

    # 选择规则类型
    echo ""
    echo "选择规则类型："
    echo "1. Direct (直连)"
    echo "2. SOCKS5 代理"
    echo "3. HTTP/HTTPS 代理"
    echo ""

    local rule_type=""
    local type_choice
    read -p "请选择 [1-3]: " type_choice

    case $type_choice in
        1) rule_type="direct" ;;
        2) rule_type="socks5" ;;
        3) rule_type="http" ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    # 名称冲突已在前面检查，允许同类型多个规则
    echo -e "${GREEN}规则类型: $rule_type${NC}"

    # 收集配置
    local config_data=""
    case $rule_type in
        "direct")
            echo ""
            echo -e "${BLUE}配置 Direct 直连参数${NC}"
            read -p "绑定网卡 (可选): " interface
            read -p "绑定IPv4 (可选): " ipv4
            read -p "绑定IPv6 (可选): " ipv6

            config_data="mode: auto"
            if [[ -n "$interface" ]]; then
                config_data+="\nbindDevice: \"$interface\""
            fi
            if [[ -n "$ipv4" ]]; then
                config_data+="\nbindIPv4: \"$ipv4\""
            fi
            if [[ -n "$ipv6" ]]; then
                config_data+="\nbindIPv6: \"$ipv6\""
            fi
            ;;
        "socks5")
            echo ""
            echo -e "${BLUE}配置 SOCKS5 代理参数${NC}"
            read -p "代理地址:端口: " addr
            if [[ -z "$addr" ]]; then
                log_error "代理地址不能为空"
                return 1
            fi

            config_data="addr: \"$addr\""

            read -p "需要认证？ [y/N]: " need_auth
            if [[ $need_auth =~ ^[Yy]$ ]]; then
                read -p "用户名: " username
                read -s -p "密码: " password
                echo ""
                if [[ -n "$username" ]]; then
                    config_data+="\nusername: \"$username\""
                    config_data+="\npassword: \"$password\""
                fi
            fi
            ;;
        "http")
            echo ""
            echo -e "${BLUE}配置 HTTP/HTTPS 代理参数${NC}"
            read -p "代理URL: " url
            if [[ -z "$url" ]]; then
                log_error "代理URL不能为空"
                return 1
            fi

            config_data="url: \"$url\""

            if [[ "$url" =~ ^https:// ]]; then
                read -p "跳过TLS验证？ [y/N]: " skip_tls
                if [[ $skip_tls =~ ^[Yy]$ ]]; then
                    config_data+="\ninsecure: true"
                fi
            fi
            ;;
    esac

    # 保存到规则库
    local temp_file="/tmp/rules_add_$$_$(date +%s).yaml"

    # 在rules节点下添加新规则
    awk -v rule="$rule_name" -v type="$rule_type" -v desc="$rule_desc" -v config="$config_data" '
    /^rules:/ {
        print $0
        print "  " rule ":"
        print "    type: " type
        print "    description: \"" desc "\""
        print "    config:"
        # 处理配置数据，添加正确的缩进
        n = split(config, lines, "\\n")
        for (i = 1; i <= n; i++) {
            if (lines[i] != "") {
                print "      " lines[i]
            }
        }
        print "    created_at: \"" strftime("%Y-%m-%dT%H:%M:%SZ") "\""
        print "    updated_at: \"" strftime("%Y-%m-%dT%H:%M:%SZ") "\""
        next
    }
    /^last_modified:/ {
        print "last_modified: \"" strftime("%Y-%m-%dT%H:%M:%SZ") "\""
        next
    }
    { print }
    ' "$RULES_LIBRARY" > "$temp_file"

    if mv "$temp_file" "$RULES_LIBRARY"; then
        log_success "规则 '$rule_name' 已添加到规则库"

        echo ""
        read -p "是否立即应用此规则？ [y/N]: " apply_now
        if [[ $apply_now =~ ^[Yy]$ ]]; then
            apply_rule_to_config_simple "$rule_name"
        fi
    else
        log_error "规则保存失败"
        rm -f "$temp_file"
        return 1
    fi

    wait_for_user
}

# 3. 应用出站规则
apply_outbound_rule() {
    init_rules_library

    echo -e "${BLUE}=== 应用出站规则 ===${NC}"
    echo ""

    # 列出规则库中未应用的规则 - 使用可靠的grep方法
    local unapplied_rules=()
    local rule_count=0

    while IFS= read -r rule_name; do
        if [[ -n "$rule_name" ]]; then
            # 检查是否已应用
            if ! grep -q "- $rule_name" "$RULES_STATE" 2>/dev/null; then
                unapplied_rules+=("$rule_name")
                ((rule_count++))
                echo "$rule_count. $rule_name"
            fi
        fi
    done < <(grep -o "^[[:space:]]\{2\}[a-zA-Z_][a-zA-Z0-9_]*:" "$RULES_LIBRARY" | sed 's/^[[:space:]]\{2\}\([^:]*\):.*/\1/')

    if [[ ${#unapplied_rules[@]} -eq 0 ]]; then
        echo -e "${YELLOW}没有可应用的规则${NC}"
        wait_for_user
        return
    fi

    echo ""
    read -p "请选择要应用的规则 [1-$rule_count]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt $rule_count ]]; then
        log_error "无效选择"
        return 1
    fi

    local selected_rule="${unapplied_rules[$((choice-1))]}"
    apply_rule_to_config_simple "$selected_rule"

    wait_for_user
}

# 应用出站规则的简化实现
# 新的规则应用函数 - 符合Hysteria2官方标准
apply_rule_to_config_simple() {
    local rule_name="$1"

    if [[ -z "$rule_name" ]]; then
        log_error "规则名称不能为空"
        return 1
    fi

    # 简化的YAML解析 - 使用更直接的方法
    local rule_type rule_config

    # 检查规则是否存在
    if ! grep -A 20 "^[[:space:]]*${rule_name}:[[:space:]]*$" "$RULES_LIBRARY" >/dev/null 2>&1; then
        log_error "规则 '$rule_name' 不存在于规则库中"
        return 1
    fi

    # 提取规则类型
    rule_type=$(awk -v rule="$rule_name" '
    BEGIN { found = 0; in_rule = 0 }
    $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; next }
    in_rule && /^[[:space:]]*type:[[:space:]]*/ {
        gsub(/^[[:space:]]*type:[[:space:]]*/, "");
        gsub(/[[:space:]]*$/, "");
        print $0;
        exit
    }
    in_rule && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ && !/^[[:space:]]*type:/ && !/^[[:space:]]*config:/ && !/^[[:space:]]*description:/ {
        in_rule = 0
    }
    ' "$RULES_LIBRARY")

    if [[ -z "$rule_type" ]]; then
        log_error "无法获取规则 '$rule_name' 的类型"
        return 1
    fi

    log_info "检测到规则类型: $rule_type"
    log_debug "开始检查配置文件中的同类型规则: $HYSTERIA_CONFIG"

    # 通用参数提取函数（去除引号）
    extract_rule_parameter() {
        local rule_name="$1"
        local param_name="$2"
        awk -v rule="$rule_name" -v param="$param_name" '
        BEGIN { in_rule = 0; in_config = 0 }
        $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; next }
        in_rule && /^[[:space:]]*config:[[:space:]]*$/ { in_config = 1; next }
        in_rule && in_config && $0 ~ "^[[:space:]]*" param ":[[:space:]]*" {
            gsub(/^[[:space:]]*[^:]*:[[:space:]]*/, "");
            gsub(/[[:space:]]*$/, "");
            gsub(/^"/, ""); gsub(/"$/, "");  # 去除前后引号
            print $0; exit
        }
        in_rule && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ && !/^[[:space:]]*config:/ { in_rule = 0 }
        ' "$RULES_LIBRARY"
    }

    # 安全移动配置文件并修复权限
    safe_move_config() {
        local temp_file="$1"
        local target_file="$2"

        if mv "$temp_file" "$target_file" 2>/dev/null; then
            # 修复配置文件权限，确保 Hysteria2 服务可以读取
            chmod 644 "$target_file" 2>/dev/null
            return 0
        else
            return 1
        fi
    }

    # 先提取配置参数（在使用前定义变量）- 完整参数支持
    local mode="" bindDevice="" bindIPv4="" bindIPv6="" fastOpen=""
    local addr="" username="" password="" url="" insecure=""

    case "$rule_type" in
        "direct")
            # 提取direct类型的所有参数
            mode=$(extract_rule_parameter "$rule_name" "mode")
            bindDevice=$(extract_rule_parameter "$rule_name" "bindDevice")
            bindIPv4=$(extract_rule_parameter "$rule_name" "bindIPv4")
            bindIPv6=$(extract_rule_parameter "$rule_name" "bindIPv6")
            fastOpen=$(extract_rule_parameter "$rule_name" "fastOpen")
            ;;

        "socks5")
            # 提取socks5类型的所有参数
            addr=$(extract_rule_parameter "$rule_name" "addr")
            username=$(extract_rule_parameter "$rule_name" "username")
            password=$(extract_rule_parameter "$rule_name" "password")
            ;;

        "http")
            # 提取http类型的所有参数
            url=$(extract_rule_parameter "$rule_name" "url")
            insecure=$(extract_rule_parameter "$rule_name" "insecure")
            ;;
    esac

    log_debug "提取的配置参数: mode=$mode, bindDevice=$bindDevice, addr=$addr, url=$url"

    # 检查配置文件中是否存在同类型规则
    local existing_rule=""
    if existing_rule=$(check_existing_outbound_type "$rule_type"); then
        echo ""
        echo -e "${YELLOW}⚠️  类型冲突检测 ⚠️${NC}"
        echo -e "${YELLOW}检测到配置文件中已存在 ${rule_type} 类型规则: ${CYAN}$existing_rule${NC}"
        echo -e "${YELLOW}同类型只能有一个规则在配置文件中生效${NC}"
        echo ""
        echo -e "${BLUE}选择操作：${NC}"
        echo -e "${GREEN}1.${NC} 继续应用并覆盖现有规则 ${CYAN}$existing_rule${NC}"
        echo -e "${RED}2.${NC} 取消应用操作"
        echo ""
        read -p "请选择 [1-2]: " conflict_choice

        case $conflict_choice in
            1)
                echo -e "${BLUE}[INFO]${NC} 将覆盖现有的 $rule_type 规则: $existing_rule"
                echo -e "${BLUE}[INFO]${NC} 继续应用新规则..."
                echo ""
                # 先删除现有的同类型规则
                if ! delete_existing_outbound_from_config "$existing_rule"; then
                    log_warn "删除现有规则失败，将尝试直接覆盖"
                fi
                ;;
            2)
                echo -e "${BLUE}[INFO]${NC} 已取消应用操作"
                return 0
                ;;
            *)
                log_error "无效选择"
                return 1
                ;;
        esac
    fi

    echo -e "${GREEN}准备应用 $rule_type 类型规则: $rule_name${NC}"

    # 直接操作，不创建不必要的备份

    # 生成符合官方标准的outbound配置
    local temp_config
    temp_config=$(create_apply_temp_file)

    if [[ -f "$HYSTERIA_CONFIG" ]] && grep -q "^[[:space:]]*outbounds:" "$HYSTERIA_CONFIG"; then
        # 在现有outbounds中添加新规则 - 修复逻辑错误
        awk -v rule="$rule_name" -v type="$rule_type" \
            -v mode="$mode" -v device="$bindDevice" -v ipv4="$bindIPv4" -v ipv6="$bindIPv6" -v fastopen="$fastOpen" \
            -v addr="$addr" -v user="$username" -v pass="$password" \
            -v url="$url" -v insecure="$insecure" '
        /^[[:space:]]*outbounds:/ {
            print $0
            # 根据官方格式添加完整的outbound配置
            print "  - name: " rule
            print "    type: " type

            if (type == "direct") {
                print "    direct:"
                if (mode != "") print "      mode: " mode
                if (ipv4 != "") print "      bindIPv4: " ipv4
                if (ipv6 != "") print "      bindIPv6: " ipv6
                if (device != "") print "      bindDevice: " device
                if (fastopen != "") print "      fastOpen: " fastopen
            } else if (type == "socks5") {
                print "    socks5:"
                if (addr != "") print "      addr: " addr
                if (user != "") print "      username: " user
                if (pass != "") print "      password: " pass
            } else if (type == "http") {
                print "    http:"
                if (url != "") print "      url: " url
                if (insecure != "") print "      insecure: " insecure
            }
            # 不使用next，继续处理后续行以保留其他现有规则
        }
        !/^[[:space:]]*outbounds:/ { print }
        ' "$HYSTERIA_CONFIG" > "$temp_config"
    else
        # 创建新的outbounds节点
        if [[ -f "$HYSTERIA_CONFIG" ]]; then
            cp "$HYSTERIA_CONFIG" "$temp_config"
        else
            echo "# Hysteria2 配置文件" > "$temp_config"
        fi

        # 添加符合官方标准的outbounds节点
        cat >> "$temp_config" << EOF

# 出站配置
outbounds:
  - name: $rule_name
    type: $rule_type
EOF

        # 根据规则类型添加完整的具体配置
        case "$rule_type" in
            "direct")
                echo "    direct:" >> "$temp_config"
                [[ -n "$mode" ]] && echo "      mode: $mode" >> "$temp_config"
                [[ -n "$bindIPv4" ]] && echo "      bindIPv4: $bindIPv4" >> "$temp_config"
                [[ -n "$bindIPv6" ]] && echo "      bindIPv6: $bindIPv6" >> "$temp_config"
                [[ -n "$bindDevice" ]] && echo "      bindDevice: $bindDevice" >> "$temp_config"
                [[ -n "$fastOpen" ]] && echo "      fastOpen: $fastOpen" >> "$temp_config"
                ;;
            "socks5")
                echo "    socks5:" >> "$temp_config"
                [[ -n "$addr" ]] && echo "      addr: $addr" >> "$temp_config"
                [[ -n "$username" ]] && echo "      username: $username" >> "$temp_config"
                [[ -n "$password" ]] && echo "      password: $password" >> "$temp_config"
                ;;
            "http")
                echo "    http:" >> "$temp_config"
                [[ -n "$url" ]] && echo "      url: $url" >> "$temp_config"
                [[ -n "$insecure" ]] && echo "      insecure: $insecure" >> "$temp_config"
                ;;
        esac
    fi

    # 应用配置
    if [[ -s "$temp_config" ]]; then
        if safe_move_config "$temp_config" "$HYSTERIA_CONFIG"; then
            log_debug "配置文件权限已修复为 644"
        else
            log_error "配置应用失败"
            rm -f "$temp_config"
            return 1
        fi

        log_success "规则 '$rule_name' 已应用到配置文件"

        # 更新状态文件
        if ! grep -q "- $rule_name" "$RULES_STATE" 2>/dev/null; then
            # 尝试使用 sed 直接添加，失败则使用 awk 方式
            if ! sed -i "/applied_rules:/a\\  - $rule_name" "$RULES_STATE" 2>/dev/null; then
                local temp_state="${RULES_STATE}.tmp"
                if awk -v rule="$rule_name" '
                /^applied_rules:/ {
                    print $0
                    print "  - " rule
                    next
                }
                { print }
                ' "$RULES_STATE" > "$temp_state" 2>/dev/null; then
                    if [[ -s "$temp_state" ]]; then
                        mv "$temp_state" "$RULES_STATE" 2>/dev/null || rm -f "$temp_state"
                    else
                        rm -f "$temp_state"
                    fi
                else
                    rm -f "$temp_state"
                fi
            fi
        fi

        log_info "状态已更新"
        log_success "规则应用完成！"

        # 交互式重启确认
        echo ""
        echo -e "${YELLOW}⚠️  配置已更新，需要重启服务生效 ⚠️${NC}"
        echo -e "${BLUE}是否立即重启 Hysteria2 服务？${NC}"
        echo ""
        echo -e "${GREEN}1.${NC} 是，立即重启服务（推荐）"
        echo -e "${YELLOW}2.${NC} 否，稍后手动重启"
        echo ""
        read -p "请选择 [1-2]: " restart_choice

        case $restart_choice in
            1)
                echo ""
                echo -e "${BLUE}[INFO]${NC} 正在重启 Hysteria2 服务..."
                if systemctl restart hysteria-server 2>/dev/null; then
                    echo -e "${GREEN}✅ 服务重启成功，新配置已生效${NC}"
                    # 等待服务启动
                    sleep 2
                    if systemctl is-active hysteria-server >/dev/null 2>&1; then
                        echo -e "${GREEN}✅ 服务运行状态正常${NC}"
                    else
                        echo -e "${RED}⚠️  服务重启后状态异常，请检查配置${NC}"
                        echo -e "${YELLOW}建议执行: journalctl -u hysteria-server -f${NC}"
                    fi
                else
                    echo -e "${RED}❌ 服务重启失败${NC}"
                    echo -e "${YELLOW}请手动重启: systemctl restart hysteria-server${NC}"
                fi
                ;;
            2)
                echo ""
                echo -e "${BLUE}[INFO]${NC} 已跳过自动重启"
                echo -e "${YELLOW}请稍后手动重启服务生效新配置:${NC}"
                echo -e "${CYAN}  systemctl restart hysteria-server${NC}"
                ;;
            *)
                echo ""
                echo -e "${YELLOW}无效选择，已跳过自动重启${NC}"
                echo -e "${YELLOW}请手动重启服务: systemctl restart hysteria-server${NC}"
                ;;
        esac

        return 0
    else
        log_error "配置应用失败"
        rm -f "$temp_config"
        return 1
    fi
}

# 4. 修改出站规则
modify_outbound_rule() {
    init_rules_library

    echo -e "${BLUE}=== 修改出站规则 ===${NC}"
    echo ""

    # 列出规则库中的规则 - 使用可靠的grep方法
    local rules=()
    local rule_count=0

    while IFS= read -r rule_name; do
        if [[ -n "$rule_name" ]]; then
            rules+=("$rule_name")
            ((rule_count++))
            echo "$rule_count. $rule_name"
        fi
    done < <(grep -o "^[[:space:]]\{2\}[a-zA-Z_][a-zA-Z0-9_]*:" "$RULES_LIBRARY" | sed 's/^[[:space:]]\{2\}\([^:]*\):.*/\1/')

    if [[ ${#rules[@]} -eq 0 ]]; then
        echo -e "${YELLOW}没有可修改的规则${NC}"
        wait_for_user
        return
    fi

    echo ""
    read -p "请选择要修改的规则 [1-$rule_count]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt $rule_count ]]; then
        log_error "无效选择"
        return 1
    fi

    local selected_rule="${rules[$((choice-1))]}"

    echo ""
    echo "修改选项："
    echo "1. 修改描述"
    echo "2. 修改配置参数"
    echo ""

    read -p "请选择操作 [1-2]: " modify_choice

    case $modify_choice in
        1)
            # 获取当前描述
            local current_desc=$(awk -v rule="$selected_rule" '
            BEGIN { in_rule = 0 }
            $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; next }
            in_rule && /^[[:space:]]*description:/ {
                gsub(/^[[:space:]]*description:[[:space:]]*"?/, "");
                gsub(/"?[[:space:]]*$/, "");
                print $0;
                exit
            }
            in_rule && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ { in_rule = 0 }
            ' "$RULES_LIBRARY")

            echo "当前描述: $current_desc"
            read -p "新的描述: " new_desc

            if [[ -n "$new_desc" ]]; then
                # 更新描述
                awk -v rule="$selected_rule" -v desc="$new_desc" '
                BEGIN { in_rule = 0 }
                $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; print; next }
                in_rule && /^[[:space:]]*description:/ {
                    gsub(/^[[:space:]]*/, "")
                    indent = substr($0, 1, match($0, /[^ ]/) - 1)
                    print indent "description: \"" desc "\""
                    next
                }
                in_rule && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ { in_rule = 0 }
                { print }
                ' "$RULES_LIBRARY" > "${RULES_LIBRARY}.tmp" && mv "${RULES_LIBRARY}.tmp" "$RULES_LIBRARY"

                log_success "描述已更新"
            fi
            ;;
        2)
            # 修改配置参数
            modify_rule_parameters "$selected_rule"
            ;;
        *)
            log_error "无效选择"
            ;;
    esac

    wait_for_user
}

# 修改规则配置参数
modify_rule_parameters() {
    local rule_name="$1"

    echo ""
    echo -e "${BLUE}=== 修改规则配置参数: ${CYAN}$rule_name${NC} ===${NC}"

    # 获取规则类型
    local rule_type=$(awk -v rule="$rule_name" '
    BEGIN { in_rule = 0 }
    $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; next }
    in_rule && /^[[:space:]]*type:[[:space:]]*/ {
        gsub(/^[[:space:]]*type:[[:space:]]*/, "");
        gsub(/[[:space:]]*$/, "");
        print $0;
        exit
    }
    in_rule && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ { in_rule = 0 }
    ' "$RULES_LIBRARY")

    if [[ -z "$rule_type" ]]; then
        log_error "无法获取规则类型"
        return 1
    fi

    echo -e "${BLUE}规则类型: ${CYAN}$rule_type${NC}"
    echo ""

    case "$rule_type" in
        "direct")
            modify_direct_parameters "$rule_name"
            ;;
        "socks5")
            modify_socks5_parameters "$rule_name"
            ;;
        "http")
            modify_http_parameters "$rule_name"
            ;;
        *)
            log_error "不支持的规则类型: $rule_type"
            return 1
            ;;
    esac
}

# 修改direct类型参数
modify_direct_parameters() {
    local rule_name="$1"

    echo "Direct 类型参数修改："
    echo "1. mode (auto|64|46|6|4)"
    echo "2. bindIPv4"
    echo "3. bindIPv6"
    echo "4. bindDevice"
    echo "5. fastOpen (true|false)"
    echo ""

    read -p "请选择要修改的参数 [1-5]: " param_choice

    local param_name param_value current_value

    case $param_choice in
        1)
            param_name="mode"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            echo "可选值: auto, 64, 46, 6, 4"
            read -p "请输入新的mode值: " param_value
            ;;
        2)
            param_name="bindIPv4"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            read -p "请输入新的bindIPv4值: " param_value
            ;;
        3)
            param_name="bindIPv6"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            read -p "请输入新的bindIPv6值: " param_value
            ;;
        4)
            param_name="bindDevice"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            read -p "请输入新的bindDevice值: " param_value
            ;;
        5)
            param_name="fastOpen"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            echo "可选值: true, false"
            read -p "请输入新的fastOpen值: " param_value
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    if [[ -n "$param_value" ]]; then
        update_rule_config_value "$rule_name" "$param_name" "$param_value"

        # 检查是否需要同步到配置文件
        prompt_config_sync "$rule_name"
    fi
}

# 修改socks5类型参数
modify_socks5_parameters() {
    local rule_name="$1"

    echo "SOCKS5 类型参数修改："
    echo "1. addr"
    echo "2. username"
    echo "3. password"
    echo ""

    read -p "请选择要修改的参数 [1-3]: " param_choice

    local param_name param_value current_value

    case $param_choice in
        1)
            param_name="addr"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            read -p "请输入新的地址 (host:port): " param_value
            ;;
        2)
            param_name="username"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            read -p "请输入新的用户名: " param_value
            ;;
        3)
            param_name="password"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            read -p "请输入新的密码: " param_value
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    if [[ -n "$param_value" ]]; then
        update_rule_config_value "$rule_name" "$param_name" "$param_value"

        # 检查是否需要同步到配置文件
        prompt_config_sync "$rule_name"
    fi
}

# 修改http类型参数
modify_http_parameters() {
    local rule_name="$1"

    echo "HTTP 类型参数修改："
    echo "1. url"
    echo "2. insecure (true|false)"
    echo ""

    read -p "请选择要修改的参数 [1-2]: " param_choice

    local param_name param_value current_value

    case $param_choice in
        1)
            param_name="url"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            read -p "请输入新的URL: " param_value
            ;;
        2)
            param_name="insecure"
            current_value=$(get_rule_config_value "$rule_name" "$param_name")
            echo "当前值: ${current_value:-"未设置"}"
            echo "可选值: true, false"
            read -p "请输入新的insecure值: " param_value
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    if [[ -n "$param_value" ]]; then
        update_rule_config_value "$rule_name" "$param_name" "$param_value"

        # 检查是否需要同步到配置文件
        prompt_config_sync "$rule_name"
    fi
}

# 获取规则配置值
get_rule_config_value() {
    local rule_name="$1"
    local param_name="$2"

    awk -v rule="$rule_name" -v param="$param_name" '
    BEGIN { in_rule = 0; in_config = 0 }
    $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; next }
    in_rule && /^[[:space:]]*config:[[:space:]]*$/ { in_config = 1; next }
    in_rule && in_config && $0 ~ "^[[:space:]]*" param ":[[:space:]]*" {
        gsub(/^[[:space:]]*[^:]*:[[:space:]]*/, "");
        gsub(/[[:space:]]*$/, "");
        gsub(/^"/, ""); gsub(/"$/, "");  # 去除前后引号
        print $0;
        exit
    }
    in_rule && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ && !/^[[:space:]]*config:/ { in_rule = 0 }
    ' "$RULES_LIBRARY"
}

# 更新规则配置值
update_rule_config_value() {
    local rule_name="$1"
    local param_name="$2"
    local param_value="$3"

    # 使用临时文件安全更新
    local temp_file=$(create_temp_file)

    awk -v rule="$rule_name" -v param="$param_name" -v value="$param_value" '
    BEGIN { in_rule = 0; in_config = 0; updated = 0 }
    $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; print; next }
    in_rule && /^[[:space:]]*config:[[:space:]]*$/ { in_config = 1; print; next }
    in_rule && in_config && $0 ~ "^[[:space:]]*" param ":[[:space:]]*" {
        gsub(/^[[:space:]]*/, "")
        indent = substr($0, 1, match($0, /[^ ]/) - 1)
        print indent param ": " value
        updated = 1
        next
    }
    in_rule && in_config && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*/ && !updated {
        # 在config段末尾插入新参数
        gsub(/^[[:space:]]*/, "")
        indent = substr($0, 1, match($0, /[^ ]/) - 1)
        print indent param ": " value
        print
        updated = 1
        next
    }
    in_rule && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ && !/^[[:space:]]*config:/ {
        in_rule = 0; in_config = 0
    }
    { print }
    ' "$RULES_LIBRARY" > "$temp_file"

    if [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$RULES_LIBRARY"
        log_success "参数 $param_name 已更新为: $param_value"
    else
        log_error "参数更新失败"
        rm -f "$temp_file"
        return 1
    fi
}

# 获取配置文件中的所有出站规则名称
get_config_outbound_rules() {
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        return 1
    fi

    # 提取配置文件中所有的 outbound 规则名称
    awk '
    /^[[:space:]]*outbound:[[:space:]]*$/ { in_outbound = 1; next }
    in_outbound && /^[[:space:]]*[a-zA-Z]+:[[:space:]]*$/ && !/^[[:space:]]*(outbound|transport|auth|masquerade|bandwidth):/ { in_outbound = 0 }
    in_outbound && /^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+)$/ {
        match($0, /name:[[:space:]]*([^[:space:]]+)/, arr)
        if (arr[1]) print arr[1]
    }
    ' "$HYSTERIA_CONFIG" 2>/dev/null
}

# 从配置文件中删除指定的出站规则
remove_rule_from_config() {
    local rule_name="$1"

    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        log_error "配置文件不存在"
        return 1
    fi

    local temp_config="/tmp/hysteria_delete_config_$$_$(date +%s).yaml"
    local in_target_rule=false
    local rule_found=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*${rule_name}[[:space:]]*$ ]]; then
            in_target_rule=true
            rule_found=true
            continue
        elif [[ "$in_target_rule" == true ]]; then
            # 检查是否到达下一个规则或段落
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(type|direct|socks5|http|addr|url|mode|username|password|insecure): ]]; then
                in_target_rule=false
                echo "$line" >> "$temp_config"
            fi
            # 在目标规则中的行都跳过
        else
            echo "$line" >> "$temp_config"
        fi
    done < "$HYSTERIA_CONFIG"

    if [[ "$rule_found" == true ]]; then
        if safe_move_config "$temp_config" "$HYSTERIA_CONFIG"; then
            log_success "已从配置文件中删除规则 '$rule_name'"
            return 0
        else
            log_error "配置文件更新失败"
            rm -f "$temp_config"
            return 1
        fi
    else
        log_warn "在配置文件中未找到规则 '$rule_name'"
        rm -f "$temp_config"
        return 1
    fi
}

# 5. 删除出站规则 (增强版)
delete_outbound_rule_new() {
    init_rules_library

    echo -e "${BLUE}=== 删除出站规则 ===${NC}"
    echo ""

    # 收集规则库中的规则
    local library_rules=()
    while IFS= read -r rule_name; do
        if [[ -n "$rule_name" ]]; then
            library_rules+=("$rule_name")
        fi
    done < <(grep -o "^[[:space:]]\{2\}[a-zA-Z_][a-zA-Z0-9_]*:" "$RULES_LIBRARY" | sed 's/^[[:space:]]\{2\}\([^:]*\):.*/\1/')

    # 收集配置文件中的规则
    local config_rules=()
    while IFS= read -r rule_name; do
        if [[ -n "$rule_name" ]]; then
            config_rules+=("$rule_name")
        fi
    done < <(get_config_outbound_rules)

    # 合并去重规则列表
    local all_rules=()
    local rule_sources=()  # 记录规则来源: library/config/both
    local rule_count=0

    # 添加规则库中的规则
    for rule in "${library_rules[@]}"; do
        all_rules+=("$rule")
        rule_sources+=("library")
        ((rule_count++))
    done

    # 添加配置文件中独有的规则
    for rule in "${config_rules[@]}"; do
        local found_in_library=false
        for lib_rule in "${library_rules[@]}"; do
            if [[ "$rule" == "$lib_rule" ]]; then
                found_in_library=true
                # 更新来源为both
                for i in "${!all_rules[@]}"; do
                    if [[ "${all_rules[i]}" == "$rule" ]]; then
                        rule_sources[i]="both"
                        break
                    fi
                done
                break
            fi
        done

        if [[ "$found_in_library" == false ]]; then
            all_rules+=("$rule")
            rule_sources+=("config")
            ((rule_count++))
        fi
    done

    if [[ ${#all_rules[@]} -eq 0 ]]; then
        echo -e "${YELLOW}没有找到任何规则${NC}"
        wait_for_user
        return
    fi

    echo -e "${CYAN}找到以下规则:${NC}"
    echo ""
    printf "%-5s %-25s %-12s %s\n" "编号" "规则名称" "位置" "状态"
    echo "---------------------------------------------------"

    for i in "${!all_rules[@]}"; do
        local rule_name="${all_rules[i]}"
        local source="${rule_sources[i]}"
        local status=""

        # 确定位置显示
        local location_display
        case "$source" in
            "library") location_display="${GREEN}规则库${NC}" ;;
            "config") location_display="${YELLOW}配置文件${NC}" ;;
            "both") location_display="${BLUE}规则库+配置${NC}" ;;
        esac

        # 检查应用状态
        if [[ -f "$HYSTERIA_CONFIG" ]] && grep -q "name:[[:space:]]*[\"']*${rule_name}[\"']*[[:space:]]*$" "$HYSTERIA_CONFIG" 2>/dev/null; then
            status="✅ 已应用"
        else
            status="❌ 未应用"
        fi

        printf "%-5d %-25s %-12s %s\n" "$((i+1))" "$rule_name" "$location_display" "$status"
    done

    echo ""
    echo -e "${YELLOW}说明:${NC}"
    echo "• 规则库: 规则模板，可重复应用"
    echo "• 配置文件: 当前活动的规则"
    echo "• 规则库+配置: 存在于两个位置"
    echo ""

    read -p "请选择要删除的规则编号 [1-$rule_count]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt $rule_count ]]; then
        log_error "无效选择"
        return 1
    fi

    local selected_rule="${all_rules[$((choice-1))]}"
    local selected_source="${rule_sources[$((choice-1))]}"

    echo ""
    echo -e "${RED}⚠️  警告: 即将删除规则 '$selected_rule'${NC}"

    # 根据规则位置给出不同的提示
    case "$selected_source" in
        "library")
            echo -e "${YELLOW}此规则仅存在于规则库中${NC}"
            ;;
        "config")
            echo -e "${YELLOW}此规则仅存在于配置文件中，删除后将立即生效${NC}"
            ;;
        "both")
            echo -e "${YELLOW}此规则同时存在于规则库和配置文件中${NC}"
            echo "选择删除范围:"
            echo "1. 仅从规则库中删除"
            echo "2. 仅从配置文件中删除"
            echo "3. 同时从两个位置删除"
            echo ""
            read -p "请选择 [1-3]: " delete_scope
            ;;
    esac

    echo ""
    read -p "确认删除？ [y/N]: " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}已取消删除操作${NC}"
        return 0
    fi

    local delete_success=false

    # 执行删除操作
    case "$selected_source" in
        "library")
            if delete_rule_from_library "$selected_rule"; then
                delete_success=true
            fi
            ;;
        "config")
            if remove_rule_from_config "$selected_rule"; then
                delete_success=true
                # 从状态文件中移除
                remove_rule_from_state "$selected_rule"
            fi
            ;;
        "both")
            case "$delete_scope" in
                1)
                    if delete_rule_from_library "$selected_rule"; then
                        delete_success=true
                    fi
                    ;;
                2)
                    if remove_rule_from_config "$selected_rule"; then
                        remove_rule_from_state "$selected_rule"
                        delete_success=true
                    fi
                    ;;
                3)
                    local lib_success=false
                    local config_success=false

                    if delete_rule_from_library "$selected_rule"; then
                        lib_success=true
                    fi

                    if remove_rule_from_config "$selected_rule"; then
                        remove_rule_from_state "$selected_rule"
                        config_success=true
                    fi

                    if [[ "$lib_success" == true ]] || [[ "$config_success" == true ]]; then
                        delete_success=true
                    fi
                    ;;
                *)
                    log_error "无效的删除范围选择"
                    return 1
                    ;;
            esac
            ;;
    esac

    if [[ "$delete_success" == true ]]; then
        log_success "规则 '$selected_rule' 删除操作完成"

        # 如果删除了配置文件中的规则，询问是否重启服务
        if [[ "$selected_source" == "config" ]] || [[ "$selected_source" == "both" && ("$delete_scope" == "2" || "$delete_scope" == "3") ]]; then
            echo ""
            read -p "是否重启 Hysteria2 服务以应用更改？ [y/N]: " restart_service
            if [[ $restart_service =~ ^[Yy]$ ]]; then
                if systemctl restart hysteria-server 2>/dev/null; then
                    log_success "服务已重启"
                else
                    log_warn "服务重启失败，请手动重启"
                fi
            fi
        fi
    else
        log_error "规则删除失败"
        return 1
    fi

    wait_for_user
}

# 从规则库中删除规则的辅助函数
delete_rule_from_library() {
    local rule_name="$1"
    local temp_library="/tmp/rules_delete_library_$$_$(date +%s).yaml"
    local in_target_rule=false
    local rule_indent=""
    local rule_found=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*${rule_name}:[[:space:]]*$ ]]; then
            in_target_rule=true
            rule_found=true
            rule_indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
            continue
        elif [[ "$in_target_rule" == true ]]; then
            # 检查是否离开规则
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$ ]]; then
                local line_indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
                if [[ ${#line_indent} -le ${#rule_indent} ]]; then
                    in_target_rule=false
                    echo "$line" >> "$temp_library"
                fi
            elif [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(type|description|config|created_at|updated_at): ]]; then
                in_target_rule=false
                echo "$line" >> "$temp_library"
            fi
            # 在规则中的行都跳过
        else
            echo "$line" >> "$temp_library"
        fi
    done < "$RULES_LIBRARY"

    if [[ "$rule_found" == true ]]; then
        if mv "$temp_library" "$RULES_LIBRARY"; then
            log_success "已从规则库中删除规则 '$rule_name'"
            return 0
        else
            log_error "规则库更新失败"
            rm -f "$temp_library"
            return 1
        fi
    else
        log_warn "在规则库中未找到规则 '$rule_name'"
        rm -f "$temp_library"
        return 1
    fi
}

# 从状态文件中移除规则的辅助函数
remove_rule_from_state() {
    local rule_name="$1"
    local temp_state="${RULES_STATE}.tmp"

    if [[ -f "$RULES_STATE" ]]; then
        awk -v rule="$rule_name" '
        $0 == "  - " rule { next }
        { print }
        ' "$RULES_STATE" > "$temp_state" 2>/dev/null

        if [[ -s "$temp_state" ]]; then
            mv "$temp_state" "$RULES_STATE" 2>/dev/null || rm -f "$temp_state"
        else
            rm -f "$temp_state"
        fi
    fi
}

# ===== 并发安全和临时文件管理函数 =====

# 创建操作锁文件
acquire_operation_lock() {
    local operation="${1:-outbound}"
    local lock_file="/tmp/s-hy2-${operation}-$(whoami).lock"
    local max_wait=30
    local wait_count=0

    while [[ $wait_count -lt $max_wait ]]; do
        if (set -C; echo $$ > "$lock_file") 2>/dev/null; then
            # 成功获取锁
            echo "$lock_file"
            return 0
        fi

        # 检查锁文件是否过期（超过5分钟）
        if [[ -f "$lock_file" ]]; then
            local lock_age
            lock_age=$(($(date +%s) - $(stat -c %Y "$lock_file" 2>/dev/null || echo 0)))
            if [[ $lock_age -gt 300 ]]; then
                # 清理过期锁文件
                rm -f "$lock_file" 2>/dev/null
                continue
            fi
        fi

        sleep 1
        ((wait_count++))
    done

    # 获取锁失败
    return 1
}

# 释放操作锁
release_operation_lock() {
    local lock_file="$1"
    [[ -n "$lock_file" && -f "$lock_file" ]] && rm -f "$lock_file"
}

# 创建标准化的Hysteria临时文件
create_hysteria_temp_file() {
    local prefix="${1:-hysteria}"
    local extension="${2:-yaml}"

    # 使用mktemp确保唯一性和安全性
    local temp_file
    temp_file=$(mktemp "/tmp/${prefix}-XXXXXX.${extension}")
    chmod 600 "$temp_file"

    # 添加到清理列表
    TEMP_FILES="${TEMP_FILES:-} $temp_file"

    echo "$temp_file"
}

# 创建配置文件专用临时文件
create_config_temp_file() {
    create_hysteria_temp_file "hysteria-config" "yaml"
}

# 创建删除操作专用临时文件
create_delete_temp_file() {
    create_hysteria_temp_file "hysteria-delete" "yaml"
}

# 创建应用操作专用临时文件
create_apply_temp_file() {
    create_hysteria_temp_file "hysteria-apply" "yaml"
}

# 配置文件同步提示函数
prompt_config_sync() {
    local rule_name="$1"

    # 检查规则是否已应用到配置文件
    if [[ -f "$HYSTERIA_CONFIG" ]] && grep -q "name:[[:space:]]*[\"']*${rule_name}[\"']*[[:space:]]*$" "$HYSTERIA_CONFIG" 2>/dev/null; then
        echo ""
        echo -e "${YELLOW}⚠️  检测到此规则已应用到配置文件中${NC}"
        echo -e "${YELLOW}是否需要同步更新到配置文件？${NC}"
        echo ""
        read -p "同步更新到配置文件？ [y/N]: " sync_choice

        if [[ $sync_choice =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}正在同步更新到配置文件...${NC}"
            # 调用应用规则函数来同步更新
            if apply_rule_to_config_simple "$rule_name"; then
                echo -e "${GREEN}✅ 配置文件已同步更新${NC}"
                echo -e "${YELLOW}⚠️  配置已更新，需要重启服务生效 ⚠️${NC}"
                echo ""
                ask_restart_service
            else
                echo -e "${RED}❌ 配置文件同步失败${NC}"
            fi
        else
            echo -e "${BLUE}仅更新了规则库，配置文件未变更${NC}"
        fi
    else
        echo -e "${BLUE}✅ 规则库已更新${NC}"
    fi
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    manage_outbound
fi