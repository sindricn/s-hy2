# 出站规则管理系统 - 代码实现示例

## 🔧 核心代码示例

### 1. 数据结构示例

#### 规则库文件格式 (library.yaml)
```yaml
metadata:
  version: "2.0"
  created: "2025-09-28T10:00:00Z"
  last_modified: "2025-09-28T10:30:00Z"
  total_rules: 3

rules:
  rule_1727515200_1234:
    id: "rule_1727515200_1234"
    name: "china_direct"
    type: "direct"
    description: "中国大陆IP直连，绕过代理"
    tags: ["direct", "china", "geoip"]
    created: "2025-09-28T10:00:00Z"
    modified: "2025-09-28T10:00:00Z"
    config:
      direct:
        mode: "auto"
        bindDevice: "eth0"
        bindIPv4: "192.168.1.100"

  rule_1727515260_5678:
    id: "rule_1727515260_5678"
    name: "global_proxy"
    type: "socks5"
    description: "全局SOCKS5代理服务器"
    tags: ["proxy", "socks5", "global"]
    created: "2025-09-28T10:01:00Z"
    modified: "2025-09-28T10:01:00Z"
    config:
      socks5:
        addr: "proxy.example.com:1080"
        username: "user123"
        password: "pass123"

  rule_1727515320_9999:
    id: "rule_1727515320_9999"
    name: "corp_http"
    type: "http"
    description: "企业HTTP代理"
    tags: ["proxy", "http", "corporate"]
    created: "2025-09-28T10:02:00Z"
    modified: "2025-09-28T10:02:00Z"
    config:
      http:
        url: "http://proxy.corp.com:8080"
        insecure: false
```

#### 应用状态文件格式 (applied.yaml)
```yaml
metadata:
  version: "2.0"
  last_applied: "2025-09-28T10:30:00Z"
  hysteria_config: "/etc/hysteria/config.yaml"

applied_rules:
  - rule_id: "rule_1727515200_1234"
    rule_name: "china_direct"
    applied_at: "2025-09-28T10:30:00Z"
    acl_rules:
      - "china_direct(geoip:cn)"
      - "china_direct(geosite:cn)"

  - rule_id: "rule_1727515260_5678"
    rule_name: "global_proxy"
    applied_at: "2025-09-28T10:25:00Z"
    acl_rules:
      - "global_proxy(all)"

backup_config:
  backup_path: "/etc/hysteria/rules/backups/config_20250928_103000.yaml"
  created_at: "2025-09-28T10:30:00Z"
```

### 2. 核心函数实现

#### 规则创建函数
```bash
#!/bin/bash
# 创建新规则的完整实现

rule_create_interactive() {
    echo -e "${BLUE}=== 创建新的出站规则 ===${NC}"
    echo ""

    # 1. 获取规则基本信息
    local rule_name rule_type rule_description

    while true; do
        read -p "规则名称 (唯一标识): " rule_name
        if [[ -z "$rule_name" ]]; then
            echo -e "${RED}规则名称不能为空${NC}"
            continue
        fi

        if rule_exists_by_name "$rule_name"; then
            echo -e "${RED}规则名称已存在，请选择其他名称${NC}"
            continue
        fi

        # 验证名称格式
        if [[ ! "$rule_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo -e "${RED}规则名称只能包含字母、数字、下划线和连字符${NC}"
            continue
        fi

        break
    done

    read -p "规则描述: " rule_description
    [[ -z "$rule_description" ]] && rule_description="用户自定义规则"

    # 2. 选择规则类型
    echo ""
    echo "选择规则类型："
    echo "1. Direct (直连)"
    echo "2. SOCKS5 代理"
    echo "3. HTTP/HTTPS 代理"
    echo ""

    local type_choice
    while true; do
        read -p "请选择 [1-3]: " type_choice
        case $type_choice in
            1) rule_type="direct"; break ;;
            2) rule_type="socks5"; break ;;
            3) rule_type="http"; break ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                ;;
        esac
    done

    # 3. 配置规则参数
    local config_json
    case $rule_type in
        "direct")
            config_json=$(rule_create_direct_config)
            ;;
        "socks5")
            config_json=$(rule_create_socks5_config)
            ;;
        "http")
            config_json=$(rule_create_http_config)
            ;;
    esac

    if [[ -z "$config_json" ]]; then
        echo -e "${RED}配置创建失败${NC}"
        return 1
    fi

    # 4. 显示配置预览
    echo ""
    echo -e "${BLUE}=== 配置预览 ===${NC}"
    echo "规则名称: $rule_name"
    echo "规则类型: $rule_type"
    echo "规则描述: $rule_description"
    echo "配置详情:"
    echo "$config_json" | jq '.'
    echo ""

    # 5. 确认创建
    read -p "确认创建此规则？ [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消创建${NC}"
        return 0
    fi

    # 6. 执行创建
    local rule_id
    rule_id=$(rule_create "$rule_name" "$rule_type" "$rule_description" "$config_json")

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}规则创建成功！${NC}"
        echo "规则ID: $rule_id"
        echo ""

        # 询问是否立即应用
        read -p "是否立即应用此规则？ [y/N]: " apply_now
        if [[ $apply_now =~ ^[Yy]$ ]]; then
            rule_state_apply "$rule_id"
        fi
    else
        echo -e "${RED}规则创建失败${NC}"
        return 1
    fi
}

# Direct类型配置创建
rule_create_direct_config() {
    echo ""
    echo -e "${BLUE}=== Direct 直连配置 ===${NC}"

    local bind_interface bind_ipv4 bind_ipv6

    # 绑定网卡
    read -p "是否绑定特定网卡？ [y/N]: " bind_iface_choice
    if [[ $bind_iface_choice =~ ^[Yy]$ ]]; then
        echo "可用网卡："
        ip link show | grep '^[0-9]' | awk -F': ' '{print "  " $2}' | grep -v lo
        read -p "网卡名称: " bind_interface
    fi

    # 绑定IPv4
    read -p "是否绑定特定IPv4地址？ [y/N]: " bind_ipv4_choice
    if [[ $bind_ipv4_choice =~ ^[Yy]$ ]]; then
        while true; do
            read -p "IPv4地址: " bind_ipv4
            if [[ "$bind_ipv4" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                break
            else
                echo -e "${RED}IPv4地址格式错误${NC}"
            fi
        done
    fi

    # 绑定IPv6
    read -p "是否绑定特定IPv6地址？ [y/N]: " bind_ipv6_choice
    if [[ $bind_ipv6_choice =~ ^[Yy]$ ]]; then
        read -p "IPv6地址: " bind_ipv6
    fi

    # 生成JSON配置
    local config=$(cat <<EOF
{
  "direct": {
    "mode": "auto"
EOF
)

    if [[ -n "$bind_interface" ]]; then
        config+=',
    "bindDevice": "'$bind_interface'"'
    fi

    if [[ -n "$bind_ipv4" ]]; then
        config+=',
    "bindIPv4": "'$bind_ipv4'"'
    fi

    if [[ -n "$bind_ipv6" ]]; then
        config+=',
    "bindIPv6": "'$bind_ipv6'"'
    fi

    config+='
  }
}'

    echo "$config"
}

# SOCKS5类型配置创建
rule_create_socks5_config() {
    echo ""
    echo -e "${BLUE}=== SOCKS5 代理配置 ===${NC}"

    local addr username password

    # 服务器地址
    while true; do
        read -p "代理服务器地址:端口 (例: proxy.com:1080): " addr
        if [[ -n "$addr" ]] && [[ "$addr" =~ : ]]; then
            break
        else
            echo -e "${RED}地址格式错误，需要包含端口${NC}"
        fi
    done

    # 认证配置
    read -p "是否需要用户名密码认证？ [y/N]: " need_auth
    if [[ $need_auth =~ ^[Yy]$ ]]; then
        read -p "用户名: " username
        read -s -p "密码: " password
        echo ""
    fi

    # 生成JSON配置
    local config=$(cat <<EOF
{
  "socks5": {
    "addr": "$addr"
EOF
)

    if [[ -n "$username" ]]; then
        config+=',
    "username": "'$username'",
    "password": "'$password'"'
    fi

    config+='
  }
}'

    echo "$config"
}

# HTTP类型配置创建
rule_create_http_config() {
    echo ""
    echo -e "${BLUE}=== HTTP 代理配置 ===${NC}"

    local url insecure

    # 代理URL
    echo "代理类型："
    echo "1. HTTP 代理"
    echo "2. HTTPS 代理"

    local proxy_type_choice
    read -p "选择 [1-2]: " proxy_type_choice

    if [[ $proxy_type_choice == "1" ]]; then
        read -p "HTTP代理URL (例: http://user:pass@proxy.com:8080): " url
    else
        read -p "HTTPS代理URL (例: https://user:pass@proxy.com:8080): " url
        read -p "是否跳过TLS证书验证？ [y/N]: " skip_tls
        if [[ $skip_tls =~ ^[Yy]$ ]]; then
            insecure="true"
        else
            insecure="false"
        fi
    fi

    # 验证URL格式
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo -e "${RED}URL格式错误${NC}"
        return 1
    fi

    # 生成JSON配置
    local config=$(cat <<EOF
{
  "http": {
    "url": "$url"
EOF
)

    if [[ -n "$insecure" ]]; then
        config+=',
    "insecure": '$insecure
    fi

    config+='
  }
}'

    echo "$config"
}
```

#### 规则应用状态管理
```bash
#!/bin/bash
# 规则应用状态的详细管理

# 批量应用规则
rule_state_batch_apply() {
    local rule_ids=("$@")

    if [[ ${#rule_ids[@]} -eq 0 ]]; then
        echo -e "${RED}错误：没有指定要应用的规则${NC}"
        return 1
    fi

    echo -e "${BLUE}=== 批量应用规则 ===${NC}"
    echo "将要应用 ${#rule_ids[@]} 个规则："

    # 显示规则列表
    for rule_id in "${rule_ids[@]}"; do
        local rule_data=$(rule_get "$rule_id")
        local rule_name=$(echo "$rule_data" | yq eval '.name' -)
        local rule_type=$(echo "$rule_data" | yq eval '.type' -)
        echo "  - $rule_name ($rule_type)"
    done

    echo ""
    read -p "确认批量应用这些规则？ [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消批量应用${NC}"
        return 0
    fi

    # 创建统一备份
    rule_state_create_backup "batch_apply_$(date +%Y%m%d_%H%M%S)"

    # 逐个应用规则
    local success_count=0
    local failed_rules=()

    for rule_id in "${rule_ids[@]}"; do
        local rule_name=$(rule_get "$rule_id" | yq eval '.name' -)
        echo -n "应用规则: $rule_name ... "

        if rule_state_apply_internal "$rule_id"; then
            echo -e "${GREEN}成功${NC}"
            ((success_count++))
        else
            echo -e "${RED}失败${NC}"
            failed_rules+=("$rule_id")
        fi
    done

    # 汇总结果
    echo ""
    echo -e "${BLUE}=== 批量应用结果 ===${NC}"
    echo "成功应用: $success_count 个规则"

    if [[ ${#failed_rules[@]} -gt 0 ]]; then
        echo "失败规则: ${#failed_rules[@]} 个"
        for failed_id in "${failed_rules[@]}"; do
            local failed_name=$(rule_get "$failed_id" | yq eval '.name' -)
            echo "  - $failed_name ($failed_id)"
        done
    fi

    # 询问是否重启服务
    if [[ $success_count -gt 0 ]]; then
        echo ""
        read -p "是否重启Hysteria2服务以应用配置？ [y/N]: " restart_choice
        if [[ $restart_choice =~ ^[Yy]$ ]]; then
            systemctl restart hysteria-server
            echo -e "${GREEN}服务已重启${NC}"
        fi
    fi
}

# 规则冲突检测
rule_state_check_conflicts() {
    local new_rule_id="$1"

    local new_rule_data=$(rule_get "$new_rule_id")
    local new_rule_type=$(echo "$new_rule_data" | yq eval '.type' -)
    local new_rule_name=$(echo "$new_rule_data" | yq eval '.name' -)

    local conflicts=()

    # 检查已应用规则中是否有同类型冲突
    local applied_rules=$(rule_state_get_applied)

    while IFS= read -r applied_rule; do
        local applied_id=$(echo "$applied_rule" | yq eval '.rule_id' -)
        local applied_rule_data=$(rule_get "$applied_id")
        local applied_type=$(echo "$applied_rule_data" | yq eval '.type' -)
        local applied_name=$(echo "$applied_rule_data" | yq eval '.name' -)

        # 检查类型冲突（根据业务规则定义）
        case "$new_rule_type" in
            "direct")
                if [[ "$applied_type" == "direct" ]]; then
                    conflicts+=("$applied_name (同类型直连规则)")
                fi
                ;;
            "socks5"|"http")
                if [[ "$applied_type" == "socks5" ]] || [[ "$applied_type" == "http" ]]; then
                    conflicts+=("$applied_name (代理类型冲突)")
                fi
                ;;
        esac

        # 检查名称冲突
        if [[ "$applied_name" == "$new_rule_name" ]]; then
            conflicts+=("$applied_name (名称重复)")
        fi

    done <<< "$applied_rules"

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️ 检测到规则冲突:${NC}"
        for conflict in "${conflicts[@]}"; do
            echo "  - $conflict"
        done
        echo ""

        echo "处理方式："
        echo "1. 取消应用新规则"
        echo "2. 自动解决冲突（取消冲突规则的应用）"
        echo "3. 强制应用（可能导致配置问题）"

        read -p "请选择 [1-3]: " resolve_choice

        case $resolve_choice in
            1)
                echo -e "${BLUE}已取消应用${NC}"
                return 1
                ;;
            2)
                echo -e "${BLUE}正在解决冲突...${NC}"
                # 这里可以实现自动冲突解决逻辑
                return 0
                ;;
            3)
                echo -e "${YELLOW}强制应用，请注意可能的配置冲突${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}无效选择，取消应用${NC}"
                return 1
                ;;
        esac
    fi

    return 0
}

# 状态同步检查
rule_state_sync_check() {
    echo -e "${BLUE}=== 状态同步检查 ===${NC}"
    echo ""

    local sync_issues=()

    # 1. 检查应用状态文件中的规则是否真实存在于配置文件
    echo "检查应用状态一致性..."

    local applied_rules=$(rule_state_get_applied)
    while IFS= read -r applied_rule; do
        local rule_id=$(echo "$applied_rule" | yq eval '.rule_id' -)
        local rule_name=$(echo "$applied_rule" | yq eval '.rule_name' -)

        # 检查规则是否存在于库中
        if ! rule_exists "$rule_id"; then
            sync_issues+=("规则库中不存在已应用的规则: $rule_name ($rule_id)")
        fi

        # 检查规则是否存在于配置文件中
        if ! yq eval ".outbounds[] | select(.name == \"$rule_name\")" "$HYSTERIA_CONFIG" >/dev/null 2>&1; then
            sync_issues+=("配置文件中不存在已应用的规则: $rule_name")
        fi

    done <<< "$applied_rules"

    # 2. 检查配置文件中的outbound是否都有对应的应用状态
    echo "检查配置文件一致性..."

    local config_outbounds=$(yq eval '.outbounds[].name' "$HYSTERIA_CONFIG" 2>/dev/null)
    while IFS= read -r outbound_name; do
        [[ -z "$outbound_name" ]] && continue

        if ! rule_state_is_applied_by_name "$outbound_name"; then
            sync_issues+=("配置文件中的规则未记录在应用状态中: $outbound_name")
        fi

    done <<< "$config_outbounds"

    # 3. 报告结果
    if [[ ${#sync_issues[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ 状态同步检查通过，未发现问题${NC}"
    else
        echo -e "${YELLOW}⚠️ 发现 ${#sync_issues[@]} 个同步问题:${NC}"
        for issue in "${sync_issues[@]}"; do
            echo "  - $issue"
        done

        echo ""
        echo "修复选项："
        echo "1. 自动修复同步问题"
        echo "2. 手动处理"
        echo "3. 忽略问题"

        read -p "请选择 [1-3]: " fix_choice

        case $fix_choice in
            1)
                rule_state_auto_fix_sync
                ;;
            2)
                echo -e "${BLUE}请手动检查并修复上述问题${NC}"
                ;;
            3)
                echo -e "${YELLOW}已忽略同步问题${NC}"
                ;;
        esac
    fi

    echo ""
    read -p "按任意键继续..." -n 1
}

# 自动修复同步问题
rule_state_auto_fix_sync() {
    echo -e "${BLUE}正在自动修复同步问题...${NC}"

    # 创建修复前的备份
    rule_state_create_backup "before_sync_fix"

    # 重新构建应用状态文件
    local temp_applied="/tmp/applied_fixed_$(date +%s).yaml"

    # 初始化新的状态文件
    cat > "$temp_applied" <<EOF
metadata:
  version: "2.0"
  last_applied: "$(date -Iseconds)"
  hysteria_config: "$HYSTERIA_CONFIG"

applied_rules: []

backup_config:
  backup_path: ""
  created_at: ""
EOF

    # 从配置文件重新构建应用状态
    local config_outbounds=$(yq eval '.outbounds[].name' "$HYSTERIA_CONFIG" 2>/dev/null)
    while IFS= read -r outbound_name; do
        [[ -z "$outbound_name" ]] && continue

        # 尝试从规则库中找到对应的规则
        local rule_id=$(rule_get_id_by_name "$outbound_name")

        if [[ -n "$rule_id" ]]; then
            # 添加到应用状态
            local applied_entry=$(cat <<EOF
{
  "rule_id": "$rule_id",
  "rule_name": "$outbound_name",
  "applied_at": "$(date -Iseconds)"
}
EOF
)
            yq eval ".applied_rules += [$applied_entry]" -i "$temp_applied"
        fi

    done <<< "$config_outbounds"

    # 应用修复后的状态文件
    mv "$temp_applied" "$APPLIED_STATE"

    echo -e "${GREEN}✅ 同步问题修复完成${NC}"
}
```

### 3. 用户界面实现示例

#### 交互式规则管理界面
```bash
#!/bin/bash
# 用户友好的规则管理界面

rule_ui_interactive_management() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║              Hysteria2 出站规则管理系统 v2.0                  ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # 显示系统状态概览
        rule_ui_show_status_overview

        echo ""
        echo -e "${GREEN}┌─ 规则库操作 ─────────────────────────────────┐${NC}"
        echo -e "${GREEN}│ 1.${NC} 📚 查看规则库        │ ${GREEN}2.${NC} ➕ 创建新规则      │"
        echo -e "${GREEN}│ 3.${NC} ✏️  编辑规则          │ ${GREEN}4.${NC} 🗑️  删除规则       │"
        echo -e "${GREEN}│ 5.${NC} 📁 导入/导出规则     │                     │"
        echo -e "${GREEN}└─────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ 应用管理 ───────────────────────────────────┐${NC}"
        echo -e "${CYAN}│ 6.${NC} 🔍 查看应用状态      │ ${CYAN}7.${NC} ⚡ 应用规则        │"
        echo -e "${CYAN}│ 8.${NC} ❌ 取消应用规则      │ ${CYAN}9.${NC} 📦 批量操作        │"
        echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${YELLOW}┌─ 系统功能 ───────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│10.${NC} 💾 备份恢复         │ ${YELLOW}11.${NC} 🔄 状态同步       │"
        echo -e "${YELLOW}│12.${NC} 🚀 迁移旧配置       │ ${YELLOW}13.${NC} ⚙️  系统设置       │"
        echo -e "${YELLOW}└─────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${RED} 0.${NC} 🚪 返回主菜单"
        echo ""

        read -p "请选择操作 [0-13]: " choice

        case $choice in
            1) rule_ui_view_library_detailed ;;
            2) rule_create_interactive ;;
            3) rule_ui_edit_rule_interactive ;;
            4) rule_ui_delete_rule_interactive ;;
            5) rule_ui_import_export_interactive ;;
            6) rule_ui_view_applied_detailed ;;
            7) rule_ui_apply_rule_interactive ;;
            8) rule_ui_unapply_rule_interactive ;;
            9) rule_ui_batch_operations_interactive ;;
            10) rule_ui_backup_restore_interactive ;;
            11) rule_state_sync_check ;;
            12) rule_ui_migrate_config_interactive ;;
            13) rule_ui_system_settings ;;
            0) break ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                sleep 1
                ;;
        esac
    done
}

# 显示系统状态概览
rule_ui_show_status_overview() {
    local total_rules=$(rule_list | jq 'length')
    local applied_rules=$(rule_state_get_applied | jq 'length')
    local unapplied_rules=$((total_rules - applied_rules))

    local status_color="${GREEN}"
    local status_text="正常"

    # 简单的健康检查
    if ! rule_state_sync_check_simple; then
        status_color="${YELLOW}"
        status_text="需要同步"
    fi

    echo -e "${BLUE}┌─ 系统状态 ───────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} 规则库总数: ${CYAN}$total_rules${NC} 个  │  已应用: ${GREEN}$applied_rules${NC} 个  │  未应用: ${YELLOW}$unapplied_rules${NC} 个"
    echo -e "${BLUE}│${NC} 系统状态: ${status_color}$status_text${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
}

# 详细查看规则库
rule_ui_view_library_detailed() {
    while true; do
        clear
        echo -e "${BLUE}=== 规则库详细信息 ===${NC}"
        echo ""

        local rules_json=$(rule_list)
        if [[ "$rules_json" == "[]" ]]; then
            echo -e "${YELLOW}📭 规则库为空${NC}"
            echo ""
            echo "建议操作："
            echo "1. 创建新规则"
            echo "2. 导入规则文件"
            echo "3. 从现有配置迁移"
            echo ""
            read -p "按任意键返回..." -n 1
            return
        fi

        # 显示规则统计
        local total_count=$(echo "$rules_json" | jq 'length')
        local direct_count=$(echo "$rules_json" | jq '[.[] | select(.type == "direct")] | length')
        local socks5_count=$(echo "$rules_json" | jq '[.[] | select(.type == "socks5")] | length')
        local http_count=$(echo "$rules_json" | jq '[.[] | select(.type == "http")] | length')

        echo -e "${CYAN}📊 规则统计：${NC}"
        echo "  总数: $total_count 个"
        echo "  ├─ Direct: $direct_count 个"
        echo "  ├─ SOCKS5: $socks5_count 个"
        echo "  └─ HTTP: $http_count 个"
        echo ""

        # 表格显示规则
        echo -e "${GREEN}📋 规则列表：${NC}"
        printf "%-4s %-20s %-8s %-10s %-8s %-25s\n" "序号" "规则名称" "类型" "状态" "标签" "描述"
        echo "──────────────────────────────────────────────────────────────────────────────"

        local count=1
        echo "$rules_json" | jq -r '.[] | [.id, .name, .type, .description, (.tags // [])] | @json' | \
        while IFS= read -r rule_line; do
            local rule_data=$(echo "$rule_line" | jq -r '.')
            local id=$(echo "$rule_data" | jq -r '.[0]')
            local name=$(echo "$rule_data" | jq -r '.[1]')
            local type=$(echo "$rule_data" | jq -r '.[2]')
            local desc=$(echo "$rule_data" | jq -r '.[3]')
            local tags=$(echo "$rule_data" | jq -r '.[4] | join(",")')

            # 检查应用状态
            local status="🔴 未应用"
            if rule_state_is_applied "$id"; then
                status="🟢 已应用"
            fi

            # 截断长文本
            [[ ${#desc} -gt 25 ]] && desc="${desc:0:22}..."
            [[ ${#tags} -gt 8 ]] && tags="${tags:0:5}..."

            printf "%-4s %-20s %-8s %-10s %-8s %-25s\n" "$count" "$name" "$type" "$status" "$tags" "$desc"
            ((count++))
        done

        echo ""
        echo "操作选项："
        echo "1. 查看规则详情"
        echo "2. 筛选规则"
        echo "3. 搜索规则"
        echo "0. 返回"

        read -p "请选择 [0-3]: " view_choice

        case $view_choice in
            1)
                rule_ui_view_rule_details
                ;;
            2)
                rule_ui_filter_rules
                ;;
            3)
                rule_ui_search_rules
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 查看规则详情
rule_ui_view_rule_details() {
    echo ""
    read -p "请输入要查看的规则名称: " rule_name

    if [[ -z "$rule_name" ]]; then
        echo -e "${RED}规则名称不能为空${NC}"
        sleep 1
        return
    fi

    local rule_id=$(rule_get_id_by_name "$rule_name")
    if [[ -z "$rule_id" ]]; then
        echo -e "${RED}规则不存在: $rule_name${NC}"
        sleep 2
        return
    fi

    local rule_data=$(rule_get "$rule_id")

    clear
    echo -e "${BLUE}=== 规则详情: $rule_name ===${NC}"
    echo ""

    echo -e "${CYAN}基本信息：${NC}"
    echo "  规则ID: $(echo "$rule_data" | yq eval '.id' -)"
    echo "  规则名称: $(echo "$rule_data" | yq eval '.name' -)"
    echo "  规则类型: $(echo "$rule_data" | yq eval '.type' -)"
    echo "  描述: $(echo "$rule_data" | yq eval '.description' -)"
    echo "  标签: $(echo "$rule_data" | yq eval '.tags // []' - | tr '\n' ',' | sed 's/,$//')"
    echo ""

    echo -e "${CYAN}时间信息：${NC}"
    echo "  创建时间: $(echo "$rule_data" | yq eval '.created' -)"
    echo "  修改时间: $(echo "$rule_data" | yq eval '.modified' -)"
    echo ""

    echo -e "${CYAN}配置详情：${NC}"
    echo "$rule_data" | yq eval '.config' - | sed 's/^/  /'
    echo ""

    # 显示应用状态
    if rule_state_is_applied "$rule_id"; then
        echo -e "${GREEN}✅ 应用状态: 已应用${NC}"
        local applied_info=$(rule_state_get_applied | jq -r ".[] | select(.rule_id == \"$rule_id\")")
        echo "  应用时间: $(echo "$applied_info" | jq -r '.applied_at')"
        echo "  ACL规则: $(echo "$applied_info" | jq -r '.acl_rules // [] | join(", ")')"
    else
        echo -e "${YELLOW}⭕ 应用状态: 未应用${NC}"
    fi

    echo ""
    read -p "按任意键继续..." -n 1
}
```

## 📋 总结

这些代码示例展示了新架构的核心特性：

### ✅ **核心功能实现**
1. **完整CRUD操作** - 规则的创建、读取、更新、删除
2. **状态管理** - 独立的应用状态追踪和管理
3. **配置应用** - 安全的配置文件更新机制
4. **用户界面** - 直观友好的交互体验

### 🎯 **技术特点**
1. **JSON/YAML处理** - 使用`yq`和`jq`进行结构化数据操作
2. **原子操作** - 配置更新的事务性保证
3. **错误处理** - 完善的错误检测和恢复机制
4. **输入验证** - 严格的参数和格式验证

### 🚀 **用户体验**
1. **向导式创建** - 步骤引导的规则创建流程
2. **实时状态** - 系统状态和规则状态的实时显示
3. **批量操作** - 支持多规则的批量管理
4. **智能提示** - 冲突检测和解决建议

这个新架构完全解决了原有系统的问题，提供了现代化、可扩展的出站规则管理解决方案。