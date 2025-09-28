#!/bin/bash

# Hysteria2 出站规则库管理器
# 功能: 独立的出站规则存档管理系统
# 特性: CRUD操作、状态管理、规则应用/取消

# 严格错误处理
set -euo pipefail

# 加载公共库
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
else
    echo "错误: 无法加载公共库" >&2
    exit 1
fi

# 规则库配置路径
readonly RULES_DIR="/etc/hysteria/outbound-rules"
readonly RULES_LIBRARY="$RULES_DIR/rules-library.yaml"
readonly RULES_STATE="$RULES_DIR/rules-state.yaml"
readonly HYSTERIA_CONFIG="/etc/hysteria/config.yaml"

# 初始化规则库管理器
init_rules_manager() {
    log_info "初始化出站规则库管理器"

    # 创建规则库目录
    if ! mkdir -p "$RULES_DIR"; then
        log_error "无法创建规则库目录: $RULES_DIR"
        return 1
    fi

    # 初始化规则库文件
    if [[ ! -f "$RULES_LIBRARY" ]]; then
        cat > "$RULES_LIBRARY" << 'EOF'
# Hysteria2 出站规则库
# 独立存储和管理所有出站规则配置

rules:
  # 示例规则
  # direct_china:
  #   type: direct
  #   description: "中国直连"
  #   config:
  #     mode: auto
  #     bindDevice: ""
  #     bindIPv4: ""
  #     bindIPv6: ""
  #   created_at: "2023-01-01T00:00:00Z"
  #   updated_at: "2023-01-01T00:00:00Z"

version: "1.0"
last_modified: "$(date -Iseconds)"
EOF
        log_info "已创建规则库文件: $RULES_LIBRARY"
    fi

    # 初始化状态文件
    if [[ ! -f "$RULES_STATE" ]]; then
        cat > "$RULES_STATE" << 'EOF'
# Hysteria2 出站规则状态管理
# 跟踪哪些规则已应用到配置文件

applied_rules: []
last_sync: ""
config_backup_count: 0
EOF
        log_info "已创建状态文件: $RULES_STATE"
    fi

    log_success "规则库管理器初始化完成"
}

# 显示规则库管理菜单
show_rules_menu() {
    clear
    echo -e "${CYAN}=== Hysteria2 出站规则库管理 ===${NC}"
    echo ""
    echo -e "${GREEN}规则库管理:${NC}"
    echo -e "${GREEN}1.${NC} 查看所有规则"
    echo -e "${GREEN}2.${NC} 添加新规则"
    echo -e "${GREEN}3.${NC} 修改规则"
    echo -e "${GREEN}4.${NC} 删除规则"
    echo ""
    echo -e "${BLUE}应用管理:${NC}"
    echo -e "${BLUE}5.${NC} 查看已应用规则"
    echo -e "${BLUE}6.${NC} 应用规则到配置"
    echo -e "${BLUE}7.${NC} 取消应用规则"
    echo -e "${BLUE}8.${NC} 批量管理应用"
    echo ""
    echo -e "${YELLOW}工具功能:${NC}"
    echo -e "${YELLOW}9.${NC} 导入/导出规则"
    echo -e "${YELLOW}10.${NC} 备份/恢复"
    echo -e "${RED}0.${NC} 返回主菜单"
    echo ""
}

# 查看所有规则
list_all_rules() {
    log_info "查看规则库中的所有规则"

    echo -e "${BLUE}=== 规则库中的所有规则 ===${NC}"
    echo ""

    # 检查是否有规则
    if ! grep -q "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:" "$RULES_LIBRARY" 2>/dev/null; then
        echo -e "${YELLOW}规则库中暂无规则${NC}"
        echo "您可以选择 '添加新规则' 来创建第一个规则"
        echo ""
        wait_for_user
        return
    fi

    # 解析并显示规则列表
    local rule_count=0
    local in_rules_section=false

    while IFS= read -r line; do
        # 检测rules节点
        if [[ "$line" =~ ^[[:space:]]*rules:[[:space:]]*$ ]]; then
            in_rules_section=true
            continue
        fi

        # 离开rules节点
        if [[ "$in_rules_section" == true ]] && [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*: ]]; then
            in_rules_section=false
        fi

        # 在rules节点中，提取规则
        if [[ "$in_rules_section" == true ]] && [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*$ ]]; then
            local rule_name="${BASH_REMATCH[1]}"
            ((rule_count++))

            # 获取规则详细信息
            local rule_type=$(get_rule_field "$rule_name" "type")
            local rule_desc=$(get_rule_field "$rule_name" "description")
            local is_applied=$(is_rule_applied "$rule_name")
            local status_icon="❌"
            local status_text="未应用"

            if [[ "$is_applied" == "true" ]]; then
                status_icon="✅"
                status_text="已应用"
            fi

            echo -e "${GREEN}$rule_count.${NC} ${CYAN}$rule_name${NC} (${YELLOW}$rule_type${NC})"
            echo -e "   描述: $rule_desc"
            echo -e "   状态: $status_icon $status_text"
            echo ""
        fi
    done < "$RULES_LIBRARY"

    if [[ $rule_count -eq 0 ]]; then
        echo -e "${YELLOW}规则库中暂无规则${NC}"
    else
        echo -e "${CYAN}共 $rule_count 个规则${NC}"
    fi

    echo ""
    wait_for_user
}

# 添加新规则
add_new_rule() {
    log_info "添加新的出站规则"

    echo -e "${BLUE}=== 添加新的出站规则 ===${NC}"
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
            echo -e "${RED}规则名称只能包含字母、数字和下划线，且不能以数字开头${NC}"
            continue
        fi

        # 检查名称是否已存在
        if rule_exists "$rule_name"; then
            echo -e "${RED}规则名称 '$rule_name' 已存在${NC}"
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

    # 收集具体配置
    local config_data=""
    case $rule_type in
        "direct")
            config_data=$(collect_direct_config)
            ;;
        "socks5")
            config_data=$(collect_socks5_config)
            ;;
        "http")
            config_data=$(collect_http_config)
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        log_error "配置收集失败"
        return 1
    fi

    # 保存规则到库
    if save_rule_to_library "$rule_name" "$rule_type" "$rule_desc" "$config_data"; then
        log_success "规则 '$rule_name' 已添加到规则库"
        echo ""
        echo -e "${BLUE}规则已保存，您可以选择：${NC}"
        echo "- 返回主菜单继续管理规则"
        echo "- 立即应用此规则到配置文件"
        echo ""

        read -p "是否立即应用此规则？ [y/N]: " apply_now
        if [[ $apply_now =~ ^[Yy]$ ]]; then
            apply_rule_to_config "$rule_name"
        fi
    else
        log_error "规则保存失败"
        return 1
    fi

    wait_for_user
}

# 收集Direct配置
collect_direct_config() {
    echo ""
    echo -e "${BLUE}配置 Direct 直连参数${NC}"

    local interface ipv4 ipv6

    # 绑定网卡
    read -p "绑定特定网卡 (可选，例: eth0): " interface

    # 绑定IP
    read -p "绑定IPv4地址 (可选): " ipv4
    read -p "绑定IPv6地址 (可选): " ipv6

    # 生成配置数据
    cat << EOF
mode: auto$(if [[ -n "$interface" ]]; then echo "
bindDevice: \"$interface\""; fi)$(if [[ -n "$ipv4" ]]; then echo "
bindIPv4: \"$ipv4\""; fi)$(if [[ -n "$ipv6" ]]; then echo "
bindIPv6: \"$ipv6\""; fi)
EOF
}

# 收集SOCKS5配置
collect_socks5_config() {
    echo ""
    echo -e "${BLUE}配置 SOCKS5 代理参数${NC}"

    local addr username password

    read -p "代理服务器地址:端口 (必填，例: proxy.com:1080): " addr
    if [[ -z "$addr" ]]; then
        echo -e "${RED}代理地址不能为空${NC}" >&2
        return 1
    fi

    read -p "是否需要认证？ [y/N]: " need_auth
    if [[ $need_auth =~ ^[Yy]$ ]]; then
        read -p "用户名: " username
        read -s -p "密码: " password
        echo ""
    fi

    # 生成配置数据
    cat << EOF
addr: "$addr"$(if [[ -n "$username" ]]; then echo "
username: \"$username\"
password: \"$password\""; fi)
EOF
}

# 收集HTTP配置
collect_http_config() {
    echo ""
    echo -e "${BLUE}配置 HTTP/HTTPS 代理参数${NC}"

    local url insecure

    read -p "代理URL (必填，例: http://user:pass@proxy.com:8080): " url
    if [[ -z "$url" ]]; then
        echo -e "${RED}代理URL不能为空${NC}" >&2
        return 1
    fi

    if [[ "$url" =~ ^https:// ]]; then
        read -p "是否跳过TLS验证？ [y/N]: " skip_tls
        if [[ $skip_tls =~ ^[Yy]$ ]]; then
            insecure="true"
        else
            insecure="false"
        fi
    fi

    # 生成配置数据
    cat << EOF
url: "$url"$(if [[ -n "$insecure" ]]; then echo "
insecure: $insecure"; fi)
EOF
}

# 保存规则到库
save_rule_to_library() {
    local rule_name="$1"
    local rule_type="$2"
    local rule_desc="$3"
    local config_data="$4"

    # 创建临时文件
    local temp_file="/tmp/rules_add_$$_$(date +%s).yaml"

    # 读取现有规则库并插入新规则
    local in_rules_section=false
    local rules_end_found=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 检测rules节点
        if [[ "$line" =~ ^[[:space:]]*rules:[[:space:]]*$ ]]; then
            in_rules_section=true
            echo "$line" >> "$temp_file"
            continue
        fi

        # 在rules节点中，寻找合适位置插入
        if [[ "$in_rules_section" == true ]] && [[ ! "$rules_end_found" == true ]]; then
            # 检查是否离开rules节点
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*: ]]; then
                # 在离开rules节点前插入新规则
                cat >> "$temp_file" << EOF

  # 新增规则 - $rule_name
  $rule_name:
    type: $rule_type
    description: "$rule_desc"
    config:
$(echo "$config_data" | sed 's/^/      /')
    created_at: "$(date -Iseconds)"
    updated_at: "$(date -Iseconds)"
EOF
                rules_end_found=true
                in_rules_section=false
            fi
        fi

        echo "$line" >> "$temp_file"
    done < "$RULES_LIBRARY"

    # 如果在文件末尾仍在rules节点中，在末尾添加
    if [[ "$in_rules_section" == true ]] && [[ ! "$rules_end_found" == true ]]; then
        cat >> "$temp_file" << EOF

  # 新增规则 - $rule_name
  $rule_name:
    type: $rule_type
    description: "$rule_desc"
    config:
$(echo "$config_data" | sed 's/^/      /')
    created_at: "$(date -Iseconds)"
    updated_at: "$(date -Iseconds)"
EOF
    fi

    # 更新last_modified
    sed -i "s/last_modified: .*/last_modified: \"$(date -Iseconds)\"/" "$temp_file"

    # 原子替换
    if mv "$temp_file" "$RULES_LIBRARY"; then
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# 检查规则是否存在
rule_exists() {
    local rule_name="$1"
    grep -q "^[[:space:]]*$rule_name:[[:space:]]*$" "$RULES_LIBRARY" 2>/dev/null
}

# 获取规则字段值
get_rule_field() {
    local rule_name="$1"
    local field="$2"

    # 使用awk提取字段值
    awk -v rule="$rule_name" -v field="$field" '
    BEGIN { in_rule = 0; found = 0 }
    $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; next }
    in_rule && $0 ~ "^[[:space:]]*" field ":" {
        gsub(/^[[:space:]]*'"$field"':[[:space:]]*"?/, "")
        gsub(/"?[[:space:]]*$/, "")
        print $0
        found = 1
        exit
    }
    in_rule && $0 ~ "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$" { in_rule = 0 }
    ' "$RULES_LIBRARY" 2>/dev/null || echo ""
}

# 检查规则是否已应用
is_rule_applied() {
    local rule_name="$1"
    grep -q "- $rule_name" "$RULES_STATE" 2>/dev/null
}

# 应用规则到配置
apply_rule_to_config() {
    local rule_name="$1"

    if [[ ! $(rule_exists "$rule_name") ]]; then
        log_error "规则 '$rule_name' 不存在"
        return 1
    fi

    if [[ $(is_rule_applied "$rule_name") == "true" ]]; then
        log_warn "规则 '$rule_name' 已经应用"
        return 0
    fi

    log_info "应用规则 '$rule_name' 到配置文件"

    # 获取规则信息
    local rule_type=$(get_rule_field "$rule_name" "type")
    local rule_config=$(extract_rule_config "$rule_name")

    # 备份当前配置
    if ! backup_config; then
        log_error "配置备份失败"
        return 1
    fi

    # 应用规则到配置文件
    if insert_rule_to_hysteria_config "$rule_name" "$rule_type" "$rule_config"; then
        # 更新状态
        if update_applied_state "add" "$rule_name"; then
            log_success "规则 '$rule_name' 已成功应用"

            # 询问是否重启服务
            read -p "是否重启 Hysteria2 服务以应用配置？ [y/N]: " restart_service
            if [[ $restart_service =~ ^[Yy]$ ]]; then
                if systemctl restart hysteria-server 2>/dev/null; then
                    log_success "服务已重启"
                else
                    log_error "服务重启失败"
                fi
            fi
        else
            log_error "状态更新失败"
            return 1
        fi
    else
        log_error "规则应用失败"
        return 1
    fi
}

# 提取规则配置
extract_rule_config() {
    local rule_name="$1"

    awk -v rule="$rule_name" '
    BEGIN { in_rule = 0; in_config = 0 }
    $0 ~ "^[[:space:]]*" rule ":[[:space:]]*$" { in_rule = 1; next }
    in_rule && $0 ~ "^[[:space:]]*config:[[:space:]]*$" { in_config = 1; next }
    in_rule && in_config && $0 ~ "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$" { in_config = 0; in_rule = 0 }
    in_rule && $0 ~ "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$" { in_rule = 0 }
    in_config { print $0 }
    ' "$RULES_LIBRARY"
}

# 备份配置
backup_config() {
    local backup_file="$RULES_DIR/config_backup_$(date +%Y%m%d_%H%M%S).yaml"

    if cp "$HYSTERIA_CONFIG" "$backup_file"; then
        log_debug "配置已备份到: $backup_file"

        # 更新备份计数
        local backup_count=$(grep -c "^applied_rules:" "$RULES_STATE" 2>/dev/null || echo "0")
        sed -i "s/config_backup_count: .*/config_backup_count: $((backup_count + 1))/" "$RULES_STATE"

        return 0
    else
        return 1
    fi
}

# 插入规则到Hysteria配置
insert_rule_to_hysteria_config() {
    local rule_name="$1"
    local rule_type="$2"
    local rule_config="$3"

    # 创建临时文件
    local temp_config="/tmp/hysteria_apply_$$_$(date +%s).yaml"

    # 检查是否已有outbounds节点
    if grep -q "^[[:space:]]*outbounds:" "$HYSTERIA_CONFIG"; then
        # 插入到现有outbounds
        insert_to_existing_outbounds "$rule_name" "$rule_type" "$rule_config" > "$temp_config"
    else
        # 创建新的outbounds节点
        cp "$HYSTERIA_CONFIG" "$temp_config"
        cat >> "$temp_config" << EOF

# 出站规则配置
outbounds:
  - name: $rule_name
    type: $rule_type
    $rule_type:
$(echo "$rule_config" | sed 's/^/      /')
EOF
    fi

    # 应用配置
    if mv "$temp_config" "$HYSTERIA_CONFIG"; then
        return 0
    else
        rm -f "$temp_config"
        return 1
    fi
}

# 插入到现有outbounds
insert_to_existing_outbounds() {
    local rule_name="$1"
    local rule_type="$2"
    local rule_config="$3"

    local in_outbounds=false
    local inserted=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 检测outbounds节点
        if [[ "$line" =~ ^[[:space:]]*outbounds: ]]; then
            in_outbounds=true
            echo "$line"
            continue
        fi

        # 在outbounds中寻找插入位置
        if [[ "$in_outbounds" == true ]] && [[ "$inserted" == false ]]; then
            # 遇到其他顶级节点，插入新规则
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*- ]]; then
                cat << EOF

  # 应用的规则 - $rule_name
  - name: $rule_name
    type: $rule_type
    $rule_type:
$(echo "$rule_config" | sed 's/^/      /')
EOF
                inserted=true
                in_outbounds=false
            fi
        fi

        echo "$line"
    done < "$HYSTERIA_CONFIG"

    # 如果在文件末尾仍在outbounds中，添加到末尾
    if [[ "$in_outbounds" == true ]] && [[ "$inserted" == false ]]; then
        cat << EOF

  # 应用的规则 - $rule_name
  - name: $rule_name
    type: $rule_type
    $rule_type:
$(echo "$rule_config" | sed 's/^/      /')
EOF
    fi
}

# 更新应用状态
update_applied_state() {
    local action="$1"  # add 或 remove
    local rule_name="$2"

    local temp_state="/tmp/rules_state_$$_$(date +%s).yaml"

    case $action in
        "add")
            # 添加到applied_rules列表
            awk -v rule="$rule_name" '
            /^applied_rules:/ {
                print $0
                print "  - " rule
                next
            }
            { print }
            ' "$RULES_STATE" > "$temp_state"
            ;;
        "remove")
            # 从applied_rules列表移除
            awk -v rule="$rule_name" '
            $0 == "  - " rule { next }
            { print }
            ' "$RULES_STATE" > "$temp_state"
            ;;
        *)
            return 1
            ;;
    esac

    # 更新同步时间
    sed -i "s/last_sync: .*/last_sync: \"$(date -Iseconds)\"/" "$temp_state"

    # 应用更改
    if mv "$temp_state" "$RULES_STATE"; then
        return 0
    else
        rm -f "$temp_state"
        return 1
    fi
}

# 主规则库管理函数
manage_rules_library() {
    init_rules_manager

    while true; do
        show_rules_menu

        local choice
        read -p "请选择操作 [0-10]: " choice

        case $choice in
            1) list_all_rules ;;
            2) add_new_rule ;;
            3) modify_rule ;;
            4) delete_rule ;;
            5) list_applied_rules ;;
            6) apply_rule_interactive ;;
            7) unapply_rule_interactive ;;
            8) batch_manage_rules ;;
            9) import_export_rules ;;
            10) backup_restore_rules ;;
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

# 修改规则
modify_rule() {
    log_info "修改规则库中的规则"

    echo -e "${BLUE}=== 修改规则 ===${NC}"
    echo ""

    # 列出所有规则供选择
    local rules=($(list_rule_names))
    if [[ ${#rules[@]} -eq 0 ]]; then
        echo -e "${YELLOW}规则库中暂无规则可修改${NC}"
        wait_for_user
        return
    fi

    echo "选择要修改的规则："
    for i in "${!rules[@]}"; do
        local rule_name="${rules[$i]}"
        local rule_type=$(get_rule_field "$rule_name" "type")
        local rule_desc=$(get_rule_field "$rule_name" "description")
        echo "$((i+1)). ${rule_name} (${rule_type}) - ${rule_desc}"
    done
    echo ""

    local choice
    read -p "请选择规则 [1-${#rules[@]}]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#rules[@]} ]]; then
        log_error "无效选择"
        return 1
    fi

    local selected_rule="${rules[$((choice-1))]}"

    echo ""
    echo "修改选项："
    echo "1. 修改描述"
    echo "2. 修改配置参数"
    echo "3. 重新配置规则"
    echo ""

    read -p "请选择操作 [1-3]: " modify_choice

    case $modify_choice in
        1) modify_rule_description "$selected_rule" ;;
        2) modify_rule_config "$selected_rule" ;;
        3) reconfigure_rule "$selected_rule" ;;
        *)
            log_error "无效选择"
            ;;
    esac
}

# 修改规则描述
modify_rule_description() {
    local rule_name="$1"
    local current_desc=$(get_rule_field "$rule_name" "description")

    echo -e "${BLUE}=== 修改规则描述 ===${NC}"
    echo "规则名称: ${CYAN}$rule_name${NC}"
    echo "当前描述: ${YELLOW}$current_desc${NC}"
    echo ""

    read -p "请输入新的描述: " new_desc
    if [[ -z "$new_desc" ]]; then
        log_error "描述不能为空"
        return 1
    fi

    if update_rule_field "$rule_name" "description" "\"$new_desc\""; then
        log_success "规则描述已更新"
    else
        log_error "描述更新失败"
    fi

    wait_for_user
}

# 修改规则配置
modify_rule_config() {
    local rule_name="$1"
    local rule_type=$(get_rule_field "$rule_name" "type")

    echo -e "${BLUE}=== 修改规则配置 ===${NC}"
    echo "规则名称: ${CYAN}$rule_name${NC}"
    echo "规则类型: ${YELLOW}$rule_type${NC}"
    echo ""

    case $rule_type in
        "direct")
            modify_direct_config "$rule_name"
            ;;
        "socks5")
            modify_socks5_config "$rule_name"
            ;;
        "http")
            modify_http_config "$rule_name"
            ;;
        *)
            log_error "不支持的规则类型: $rule_type"
            return 1
            ;;
    esac
}

# 删除规则
delete_rule() {
    log_info "删除规则库中的规则"

    echo -e "${BLUE}=== 删除规则 ===${NC}"
    echo ""

    # 列出所有规则供选择
    local rules=($(list_rule_names))
    if [[ ${#rules[@]} -eq 0 ]]; then
        echo -e "${YELLOW}规则库中暂无规则可删除${NC}"
        wait_for_user
        return
    fi

    echo "选择要删除的规则："
    for i in "${!rules[@]}"; do
        local rule_name="${rules[$i]}"
        local rule_type=$(get_rule_field "$rule_name" "type")
        local is_applied=$(is_rule_applied "$rule_name")
        local status_text="未应用"
        if [[ "$is_applied" == "true" ]]; then
            status_text="已应用"
        fi
        echo "$((i+1)). ${rule_name} (${rule_type}) - ${status_text}"
    done
    echo ""

    local choice
    read -p "请选择规则 [1-${#rules[@]}]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#rules[@]} ]]; then
        log_error "无效选择"
        return 1
    fi

    local selected_rule="${rules[$((choice-1))]}"

    # 确认删除
    echo ""
    echo -e "${RED}⚠️  警告: 即将删除规则 '$selected_rule'${NC}"

    # 检查是否已应用
    if [[ $(is_rule_applied "$selected_rule") == "true" ]]; then
        echo -e "${YELLOW}此规则当前已应用到配置文件中${NC}"
        echo -e "${YELLOW}删除规则将同时从配置文件中移除${NC}"
    fi

    echo ""
    read -p "确认删除？ [y/N]: " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}已取消删除操作${NC}"
        return 0
    fi

    # 如果规则已应用，先从配置中移除
    if [[ $(is_rule_applied "$selected_rule") == "true" ]]; then
        log_info "从配置文件中移除规则"
        if ! unapply_rule_from_config "$selected_rule"; then
            log_error "无法从配置中移除规则，删除操作已终止"
            return 1
        fi
    fi

    # 从规则库中删除
    if remove_rule_from_library "$selected_rule"; then
        log_success "规则 '$selected_rule' 已删除"
    else
        log_error "规则删除失败"
        return 1
    fi

    wait_for_user
}

# 查看已应用规则
list_applied_rules() {
    log_info "查看已应用的规则"

    echo -e "${BLUE}=== 已应用的规则 ===${NC}"
    echo ""

    # 读取已应用规则列表
    local applied_rules=($(awk '/^applied_rules:$/,/^[a-zA-Z_]/ { if ($0 ~ "^  - ") { gsub(/^  - /, ""); print $0 } }' "$RULES_STATE" 2>/dev/null))

    if [[ ${#applied_rules[@]} -eq 0 ]]; then
        echo -e "${YELLOW}当前没有已应用的规则${NC}"
        echo ""
        wait_for_user
        return
    fi

    echo -e "${GREEN}已应用规则列表:${NC}"
    for i in "${!applied_rules[@]}"; do
        local rule_name="${applied_rules[$i]}"
        local rule_type=$(get_rule_field "$rule_name" "type")
        local rule_desc=$(get_rule_field "$rule_name" "description")

        echo "$((i+1)). ${CYAN}$rule_name${NC} (${YELLOW}$rule_type${NC})"
        echo "   描述: $rule_desc"
        echo ""
    done

    local last_sync=$(grep "last_sync:" "$RULES_STATE" | cut -d'"' -f2)
    echo -e "${BLUE}最后同步时间: ${last_sync:-未知}${NC}"
    echo ""
    wait_for_user
}

# 交互式应用规则
apply_rule_interactive() {
    log_info "应用规则到配置文件"

    echo -e "${BLUE}=== 应用规则到配置 ===${NC}"
    echo ""

    # 获取未应用的规则
    local unapplied_rules=()
    local all_rules=($(list_rule_names))

    for rule in "${all_rules[@]}"; do
        if [[ $(is_rule_applied "$rule") != "true" ]]; then
            unapplied_rules+=("$rule")
        fi
    done

    if [[ ${#unapplied_rules[@]} -eq 0 ]]; then
        echo -e "${YELLOW}所有规则都已应用，没有可应用的规则${NC}"
        wait_for_user
        return
    fi

    echo "选择要应用的规则："
    for i in "${!unapplied_rules[@]}"; do
        local rule_name="${unapplied_rules[$i]}"
        local rule_type=$(get_rule_field "$rule_name" "type")
        local rule_desc=$(get_rule_field "$rule_name" "description")
        echo "$((i+1)). ${rule_name} (${rule_type}) - ${rule_desc}"
    done
    echo ""

    local choice
    read -p "请选择规则 [1-${#unapplied_rules[@]}]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#unapplied_rules[@]} ]]; then
        log_error "无效选择"
        return 1
    fi

    local selected_rule="${unapplied_rules[$((choice-1))]}"

    # 应用规则
    apply_rule_to_config "$selected_rule"
}

# 交互式取消应用规则
unapply_rule_interactive() {
    log_info "取消应用规则"

    echo -e "${BLUE}=== 取消应用规则 ===${NC}"
    echo ""

    # 读取已应用规则列表
    local applied_rules=($(awk '/^applied_rules:$/,/^[a-zA-Z_]/ { if ($0 ~ "^  - ") { gsub(/^  - /, ""); print $0 } }' "$RULES_STATE" 2>/dev/null))

    if [[ ${#applied_rules[@]} -eq 0 ]]; then
        echo -e "${YELLOW}当前没有已应用的规则可取消${NC}"
        wait_for_user
        return
    fi

    echo "选择要取消应用的规则："
    for i in "${!applied_rules[@]}"; do
        local rule_name="${applied_rules[$i]}"
        local rule_type=$(get_rule_field "$rule_name" "type")
        local rule_desc=$(get_rule_field "$rule_name" "description")
        echo "$((i+1)). ${rule_name} (${rule_type}) - ${rule_desc}"
    done
    echo ""

    local choice
    read -p "请选择规则 [1-${#applied_rules[@]}]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#applied_rules[@]} ]]; then
        log_error "无效选择"
        return 1
    fi

    local selected_rule="${applied_rules[$((choice-1))]}"

    # 确认取消应用
    echo ""
    echo -e "${YELLOW}确认取消应用规则 '$selected_rule'？${NC}"
    read -p "此操作将从配置文件中移除该规则 [y/N]: " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}已取消操作${NC}"
        return 0
    fi

    # 取消应用规则
    unapply_rule_from_config "$selected_rule"
}

# 批量管理规则
batch_manage_rules() {
    log_info "批量管理规则应用"

    echo -e "${BLUE}=== 批量规则管理 ===${NC}"
    echo ""
    echo "1. 批量应用规则"
    echo "2. 批量取消应用规则"
    echo "3. 应用所有规则"
    echo "4. 取消应用所有规则"
    echo "0. 返回"
    echo ""

    local choice
    read -p "请选择操作 [0-4]: " choice

    case $choice in
        1) batch_apply_rules ;;
        2) batch_unapply_rules ;;
        3) apply_all_rules ;;
        4) unapply_all_rules ;;
        0) return 0 ;;
        *)
            log_error "无效选择"
            ;;
    esac
}

# 导入导出规则 (占位符)
import_export_rules() {
    echo -e "${YELLOW}功能开发中...${NC}"
    wait_for_user
}

# 备份恢复规则 (占位符)
backup_restore_rules() {
    echo -e "${YELLOW}功能开发中...${NC}"
    wait_for_user
}

# 辅助函数

# 列出所有规则名称
list_rule_names() {
    awk '
    BEGIN { in_rules = 0 }
    /^[[:space:]]*rules:[[:space:]]*$/ { in_rules = 1; next }
    in_rules && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ {
        gsub(/^[[:space:]]*/, "")
        gsub(/:[[:space:]]*$/, "")
        print $0
    }
    in_rules && /^[[:space:]]*[a-zA-Z]+:[[:space:]]*$/ && !/^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:/ { in_rules = 0 }
    ' "$RULES_LIBRARY" 2>/dev/null
}

# 更新规则字段
update_rule_field() {
    local rule_name="$1"
    local field="$2"
    local new_value="$3"

    local temp_file="/tmp/rules_update_$$_$(date +%s).yaml"
    local in_rule=false
    local in_config=false
    local field_updated=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 检测规则开始
        if [[ "$line" =~ ^[[:space:]]*${rule_name}:[[:space:]]*$ ]]; then
            in_rule=true
            echo "$line" >> "$temp_file"
            continue
        fi

        # 在规则中处理
        if [[ "$in_rule" == true ]]; then
            # 检查是否离开规则
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$ ]]; then
                in_rule=false
                in_config=false
                echo "$line" >> "$temp_file"
                continue
            fi

            # 检测config节点
            if [[ "$line" =~ ^[[:space:]]*config:[[:space:]]*$ ]]; then
                in_config=true
                echo "$line" >> "$temp_file"
                continue
            fi

            # 更新字段
            if [[ "$line" =~ ^[[:space:]]*${field}:[[:space:]]* ]]; then
                local indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
                echo "${indent}${field}: ${new_value}" >> "$temp_file"
                field_updated=true
                continue
            fi
        fi

        echo "$line" >> "$temp_file"
    done < "$RULES_LIBRARY"

    # 应用更改
    if mv "$temp_file" "$RULES_LIBRARY"; then
        # 更新修改时间
        sed -i "s/last_modified: .*/last_modified: \"$(date -Iseconds)\"/" "$RULES_LIBRARY"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# 取消应用规则
unapply_rule_from_config() {
    local rule_name="$1"

    if [[ $(is_rule_applied "$rule_name") != "true" ]]; then
        log_warn "规则 '$rule_name' 未应用"
        return 0
    fi

    log_info "从配置文件中移除规则 '$rule_name'"

    # 备份配置
    if ! backup_config; then
        log_error "配置备份失败"
        return 1
    fi

    # 从配置文件中移除规则
    if remove_rule_from_hysteria_config "$rule_name"; then
        # 更新状态
        if update_applied_state "remove" "$rule_name"; then
            log_success "规则 '$rule_name' 已从配置中移除"

            # 询问是否重启服务
            read -p "是否重启 Hysteria2 服务以应用配置？ [y/N]: " restart_service
            if [[ $restart_service =~ ^[Yy]$ ]]; then
                if systemctl restart hysteria-server 2>/dev/null; then
                    log_success "服务已重启"
                else
                    log_error "服务重启失败"
                fi
            fi
        else
            log_error "状态更新失败"
            return 1
        fi
    else
        log_error "规则移除失败"
        return 1
    fi
}

# 从配置文件中移除规则
remove_rule_from_hysteria_config() {
    local rule_name="$1"

    local temp_config="/tmp/hysteria_remove_$$_$(date +%s).yaml"
    local in_outbound_rule=false
    local in_acl_section=false
    local acl_base_indent=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        local should_keep=true

        # 检测outbound规则块
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*${rule_name}[[:space:]]*$ ]]; then
            in_outbound_rule=true
            should_keep=false
        elif [[ "$in_outbound_rule" == true ]]; then
            # 在outbound规则块中，检查是否结束
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(type|direct|socks5|http|addr|url|mode|username|password|insecure): ]]; then
                in_outbound_rule=false
                should_keep=true
            else
                should_keep=false
            fi
        fi

        # 检测ACL节点
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

            # 在ACL节点中删除包含目标规则名的行
            if [[ "$in_acl_section" == true ]] && [[ "$line" =~ ${rule_name} ]]; then
                should_keep=false
            fi
        fi

        # 写入保留的行
        if [[ "$should_keep" == true ]]; then
            echo "$line" >> "$temp_config"
        fi
    done < "$HYSTERIA_CONFIG"

    # 应用配置
    if mv "$temp_config" "$HYSTERIA_CONFIG"; then
        return 0
    else
        rm -f "$temp_config"
        return 1
    fi
}

# 从规则库中删除规则
remove_rule_from_library() {
    local rule_name="$1"

    local temp_file="/tmp/rules_delete_$$_$(date +%s).yaml"
    local in_rule=false
    local in_config=false
    local rule_indent=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 检测目标规则开始
        if [[ "$line" =~ ^[[:space:]]*${rule_name}:[[:space:]]*$ ]]; then
            in_rule=true
            rule_indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
            continue
        fi

        # 在规则中，检查是否结束
        if [[ "$in_rule" == true ]]; then
            # 遇到同级或更高级的项目，规则结束
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$ ]]; then
                local line_indent=$(echo "$line" | sed 's/[a-zA-Z].*//')
                if [[ ${#line_indent} -le ${#rule_indent} ]]; then
                    in_rule=false
                    echo "$line" >> "$temp_file"
                fi
            elif [[ "$line" =~ ^[[:space:]]*[a-zA-Z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*(type|description|config|created_at|updated_at): ]]; then
                in_rule=false
                echo "$line" >> "$temp_file"
            fi
            # 在规则中的行都跳过（不写入）
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$RULES_LIBRARY"

    # 应用更改
    if mv "$temp_file" "$RULES_LIBRARY"; then
        # 更新修改时间
        sed -i "s/last_modified: .*/last_modified: \"$(date -Iseconds)\"/" "$RULES_LIBRARY"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# 批量应用规则 (占位符)
batch_apply_rules() {
    echo -e "${YELLOW}批量应用功能开发中...${NC}"
    wait_for_user
}

# 批量取消应用规则 (占位符)
batch_unapply_rules() {
    echo -e "${YELLOW}批量取消应用功能开发中...${NC}"
    wait_for_user
}

# 应用所有规则 (占位符)
apply_all_rules() {
    echo -e "${YELLOW}应用所有规则功能开发中...${NC}"
    wait_for_user
}

# 取消应用所有规则 (占位符)
unapply_all_rules() {
    echo -e "${YELLOW}取消应用所有规则功能开发中...${NC}"
    wait_for_user
}

# 重新配置规则 (占位符)
reconfigure_rule() {
    local rule_name="$1"
    echo -e "${YELLOW}重新配置功能开发中...${NC}"
    wait_for_user
}

# 修改Direct配置 (占位符)
modify_direct_config() {
    local rule_name="$1"
    echo -e "${YELLOW}修改Direct配置功能开发中...${NC}"
    wait_for_user
}

# 修改SOCKS5配置 (占位符)
modify_socks5_config() {
    local rule_name="$1"
    echo -e "${YELLOW}修改SOCKS5配置功能开发中...${NC}"
    wait_for_user
}

# 修改HTTP配置 (占位符)
modify_http_config() {
    local rule_name="$1"
    echo -e "${YELLOW}修改HTTP配置功能开发中...${NC}"
    wait_for_user
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    manage_rules_library
fi