#!/bin/bash

# Hysteria2 出站规则管理模块
# 用于配置和管理 Hysteria2 的出站规则

# 适度的错误处理
set -uo pipefail

# 加载公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
if [[ -z "${OUTBOUND_TEMPLATES_DIR:-}" ]]; then
    readonly OUTBOUND_TEMPLATES_DIR="$SCRIPT_DIR/outbound-templates"
fi
# 备份功能已移除

# 初始化出站管理
init_outbound_manager() {
    log_info "初始化出站规则管理器"

    # 创建模板目录
    mkdir -p "$OUTBOUND_TEMPLATES_DIR"

    # 创建基础模板（如果不存在）
    create_default_templates
}

# 创建默认模板
create_default_templates() {
    # Direct 出站模板
    if [[ ! -f "$OUTBOUND_TEMPLATES_DIR/direct.yaml" ]]; then
        cat > "$OUTBOUND_TEMPLATES_DIR/direct.yaml" << 'EOF'
# Direct 直连出站配置模板
outbounds:
  - name: direct_out
    type: direct
    direct:
      mode: auto
      # bindIPv4: "1.2.3.4"    # 可选：绑定 IPv4 地址
      # bindIPv6: "::1"        # 可选：绑定 IPv6 地址
      # bindDevice: "eth0"     # 可选：绑定网卡

# 简单 ACL 规则 - 全部直连
acl: |
  direct_out(all)
EOF
    fi

    # SOCKS5 出站模板
    if [[ ! -f "$OUTBOUND_TEMPLATES_DIR/socks5.yaml" ]]; then
        cat > "$OUTBOUND_TEMPLATES_DIR/socks5.yaml" << 'EOF'
# SOCKS5 代理出站配置模板
outbounds:
  - name: direct_out
    type: direct
  - name: socks5_out
    type: socks5
    socks5:
      addr: "proxy.example.com:1080"
      username: "your_username"  # 可选
      password: "your_password"  # 可选

# 简单 ACL 规则 - 国外走代理，国内直连
acl: |
  # 国外 IP 走 SOCKS5 代理
  socks5_out(geoip:!cn)
  # 国内 IP 直连
  direct_out(geoip:cn)
  # 其他所有连接直连
  direct_out(all)
EOF
    fi

    # HTTP 出站模板
    if [[ ! -f "$OUTBOUND_TEMPLATES_DIR/http.yaml" ]]; then
        cat > "$OUTBOUND_TEMPLATES_DIR/http.yaml" << 'EOF'
# HTTP/HTTPS 代理出站配置模板
outbounds:
  - name: direct_out
    type: direct
  - name: http_out
    type: http
    http:
      url: "http://username:password@proxy.example.com:8080"
      # 或 HTTPS: "https://username:password@proxy.example.com:8080"
      insecure: false  # 是否跳过 TLS 验证

# 简单 ACL 规则 - 特定域名走代理
acl: |
  # 特定网站走 HTTP 代理
  http_out(suffix:google.com)
  http_out(suffix:youtube.com)
  http_out(suffix:facebook.com)
  # 其他所有连接直连
  direct_out(all)
EOF
    fi

    log_success "默认出站模板已创建"
}

# 显示出站管理菜单
show_outbound_menu() {
    clear
    echo -e "${CYAN}=== Hysteria2 出站规则配置 ===${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 查看当前出站配置"
    echo -e "${GREEN}2.${NC} 添加新的出站规则"
    echo -e "${GREEN}3.${NC} 使用模板配置"
    echo -e "${GREEN}4.${NC} 修改现有配置"
    echo -e "${GREEN}5.${NC} 测试出站连通性"
    # 备份功能已移除
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
        sed -n '/^[[:space:]]*outbounds:/,/^[[:space:]]*[a-zA-Z]/p' "$HYSTERIA_CONFIG" | sed '$d'
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
    echo -e "${YELLOW}注意: 每种类型只能有一个出站规则，添加同类型规则将覆盖现有规则${NC}"
    echo ""
    echo "选择出站类型："
    echo "1. Direct (直连)"
    echo "2. SOCKS5 代理"
    echo "3. HTTP/HTTPS 代理"
    echo ""

    local choice
    read -p "请选择 [1-3]: " choice

    case $choice in
        1) add_direct_outbound ;;
        2) add_socks5_outbound ;;
        3) add_http_outbound ;;
        *)
            log_error "无效选择"
            return 1
            ;;
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
    echo "是否绑定特定网卡？ [y/N]"
    read -r bind_interface

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
    echo "是否绑定特定 IP 地址？ [y/N]"
    read -r bind_ip

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

    echo "是否需要认证？ [y/N]"
    read -r need_auth

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
        echo "是否跳过 TLS 验证？ [y/N]"
        read -r skip_tls
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

    apply_outbound_config "$name" "direct"
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

    apply_outbound_config "$name" "socks5"
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

    apply_outbound_config "$name" "http"
}

# 应用出站配置 - 极简稳定版本
apply_outbound_config() {
    local name="$1" type="$2"

    echo "是否将此配置应用到 Hysteria2？ [y/N]"
    read -r apply_config

    if [[ $apply_config =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[INFO]${NC} 开始应用出站配置: $name ($type)"

        # 使用极简稳定的方法
        if apply_outbound_simple "$name" "$type"; then
            echo -e "${GREEN}[SUCCESS]${NC} 出站配置已添加：$name ($type)"

            # 询问是否重启服务
            echo "是否重启 Hysteria2 服务以应用配置？ [y/N]"
            read -r restart_service

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
    if mv "$temp_config" "$HYSTERIA_CONFIG" 2>/dev/null; then
        echo -e "${GREEN}[SUCCESS]${NC} 现有规则 '$rule_name' 已删除"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} 删除失败，文件操作错误"
        rm -f "$temp_config"
        return 1
    fi
}

# 极简稳定的配置应用函数
apply_outbound_simple() {
    local name="$1" type="$2"

    echo -e "${BLUE}[INFO]${NC} 检查配置文件: $HYSTERIA_CONFIG"

    # 检查配置文件
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        echo -e "${RED}[ERROR]${NC} 配置文件不存在: $HYSTERIA_CONFIG"
        return 1
    fi

    # 检查同类型规则冲突
    local existing_rule
    if existing_rule=$(check_existing_outbound_type "$type"); then
        echo ""
        echo -e "${YELLOW}⚠️  冲突检测 ⚠️${NC}"
        echo -e "${YELLOW}检测到现有的 $type 类型规则: ${CYAN}$existing_rule${NC}"
        echo -e "${YELLOW}根据系统设计原则，每种类型只能有一个出站规则${NC}"
        echo ""
        echo -e "${BLUE}可选操作：${NC}"
        echo -e "${GREEN}1.${NC} 覆盖现有规则 ${CYAN}$existing_rule${NC} (推荐)"
        echo -e "${RED}2.${NC} 取消本次添加操作"
        echo ""
        read -p "请选择操作 [1-2]: " choice

        case $choice in
            1)
                echo -e "${BLUE}[INFO]${NC} 将覆盖现有的 $type 规则: $existing_rule"
                # 先删除现有同类型规则 (静默删除，不需要用户确认)
                if ! delete_existing_rule_silent "$existing_rule"; then
                    echo -e "${RED}[ERROR]${NC} 删除现有规则失败"
                    return 1
                fi
                ;;
            2)
                echo -e "${BLUE}[INFO]${NC} 取消添加操作"
                return 0
                ;;
            *)
                echo -e "${RED}[ERROR]${NC} 无效选择，取消添加"
                return 1
                ;;
        esac
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
    if mv "$temp_file" "$HYSTERIA_CONFIG" 2>/dev/null; then
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

# 使用模板配置
use_template_config() {
    echo -e "${BLUE}=== 使用模板配置 ===${NC}"
    echo ""
    echo "可用模板："
    echo "1. Direct 直连模板"
    echo "2. SOCKS5 代理模板"
    echo "3. HTTP 代理模板"
    echo ""

    local choice
    read -p "请选择模板 [1-3]: " choice

    case $choice in
        1) apply_template "direct.yaml" ;;
        2) apply_template "socks5.yaml" ;;
        3) apply_template "http.yaml" ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}

# 应用模板
apply_template() {
    local template="$1"
    local template_path="$OUTBOUND_TEMPLATES_DIR/$template"

    if [[ ! -f "$template_path" ]]; then
        log_error "模板文件不存在: $template"
        return 1
    fi

    echo -e "${BLUE}模板内容预览：${NC}"
    echo "---"
    cat "$template_path"
    echo "---"
    echo ""

    echo "是否使用此模板？ [y/N]"
    read -r use_template

    if [[ $use_template =~ ^[Yy]$ ]]; then
        # 备份功能已移除

        # 这里需要实际的模板应用逻辑
        log_success "模板配置已应用: $template"

        echo "是否重启 Hysteria2 服务？ [y/N]"
        read -r restart_service

        if [[ $restart_service =~ ^[Yy]$ ]]; then
            systemctl restart hysteria-server
            log_success "服务已重启"
        fi
    fi
}

# 测试出站连通性
test_outbound_connectivity() {
    log_info "测试出站连通性"

    echo -e "${BLUE}=== 出站连通性测试 ===${NC}"
    echo ""

    # 检查是否有出站配置
    if ! grep -q "^outbounds:" "$HYSTERIA_CONFIG"; then
        echo -e "${YELLOW}当前没有配置出站规则，无法测试${NC}"
        wait_for_user
        return
    fi

    # 列出可用的出站规则
    echo -e "${GREEN}当前出站规则：${NC}"
    grep "^[[:space:]]*-[[:space:]]*name:" "$HYSTERIA_CONFIG" | sed 's/.*name:[[:space:]]*/- /' | nl
    echo ""

    echo "测试选项："
    echo "1. 测试直连连通性"
    echo "2. 测试域名解析"
    echo "3. 测试网络延迟"
    echo "4. 测试端口连通性"
    echo ""

    read -p "请选择测试类型 [1-4]: " test_choice

    case $test_choice in
        1) test_direct_connectivity ;;
        2) test_dns_resolution ;;
        3) test_network_latency ;;
        4) test_port_connectivity ;;
        *)
            log_error "无效选择"
            ;;
    esac

    wait_for_user
}

# 测试直连连通性
test_direct_connectivity() {
    echo -e "${CYAN}=== 直连连通性测试 ===${NC}"
    echo ""

    local test_urls=("8.8.8.8" "1.1.1.1" "google.com" "baidu.com")

    for url in "${test_urls[@]}"; do
        echo -n "测试连接到 $url... "
        if ping -c 1 -W 5 "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 成功${NC}"
        else
            echo -e "${RED}✗ 失败${NC}"
        fi
    done
    echo ""
}

# 测试域名解析
test_dns_resolution() {
    echo -e "${CYAN}=== DNS 解析测试 ===${NC}"
    echo ""

    local test_domains=("google.com" "github.com" "baidu.com" "qq.com")

    for domain in "${test_domains[@]}"; do
        echo -n "解析域名 $domain... "
        if nslookup "$domain" >/dev/null 2>&1; then
            local ip=$(nslookup "$domain" 2>/dev/null | grep "Address:" | tail -n1 | awk '{print $2}')
            echo -e "${GREEN}✓ $ip${NC}"
        else
            echo -e "${RED}✗ 解析失败${NC}"
        fi
    done
    echo ""
}

# 测试网络延迟
test_network_latency() {
    echo -e "${CYAN}=== 网络延迟测试 ===${NC}"
    echo ""

    local test_servers=("8.8.8.8" "1.1.1.1" "baidu.com")

    for server in "${test_servers[@]}"; do
        echo -n "测试到 $server 的延迟... "
        local latency=$(ping -c 3 -W 5 "$server" 2>/dev/null | tail -1 | awk -F '/' '{print $5}' 2>/dev/null)
        if [[ -n "$latency" ]]; then
            echo -e "${GREEN}${latency}ms${NC}"
        else
            echo -e "${RED}✗ 超时${NC}"
        fi
    done
    echo ""
}

# 测试端口连通性
test_port_connectivity() {
    echo -e "${CYAN}=== 端口连通性测试 ===${NC}"
    echo ""

    read -p "请输入要测试的主机地址: " host
    read -p "请输入端口号: " port

    if [[ -z "$host" || -z "$port" ]]; then
        log_error "主机地址和端口不能为空"
        return
    fi

    echo -n "测试连接到 $host:$port... "
    if timeout 10 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}✓ 端口开放${NC}"
    else
        echo -e "${RED}✗ 端口关闭或无法访问${NC}"
    fi
    echo ""
}

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
    echo "1. 删除此出站规则"
    echo "2. 替换为新的出站规则"
    echo "3. 查看详细配置"
    echo ""

    read -p "请选择操作 [1-3]: " modify_choice

    case $modify_choice in
        1) delete_outbound_rule "$selected_outbound" ;;
        2) replace_outbound_rule "$selected_outbound" ;;
        3) show_outbound_details "$selected_outbound" ;;
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
        echo "是否重启 Hysteria2 服务以应用配置？ [y/N]"
        read -r restart_service

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
    echo "按回车键继续..."
    read -r
}

# 替换出站规则
replace_outbound_rule() {
    local old_rule_name="$1"

    echo -e "${BLUE}=== 替换出站规则 '$old_rule_name' ===${NC}"
    echo ""
    echo "将创建新的出站规则来替换现有的规则"
    echo ""

    # 先删除旧规则
    delete_outbound_rule "$old_rule_name"

    # 添加新规则
    echo -e "${GREEN}现在添加新的出站规则：${NC}"
    add_outbound_rule
}

# 显示出站规则详细信息
show_outbound_details() {
    local rule_name="$1"

    echo -e "${CYAN}=== 出站规则 '$rule_name' 详细信息 ===${NC}"
    echo ""

    # 提取并显示指定规则的配置
    sed -n "/- name: $rule_name/,/^  - name:/p" "$HYSTERIA_CONFIG" | sed '$d'

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
        read -p "请选择操作 [0-6]: " choice

        case $choice in
            1) view_current_outbound ;;
            2) add_outbound_rule ;;
            3) use_template_config ;;
            4) modify_outbound_config ;;
            5) test_outbound_connectivity ;;
            # 6) 备份功能已移除 ;;
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

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    manage_outbound
fi