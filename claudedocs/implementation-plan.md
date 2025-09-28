# 出站规则管理系统实现计划

## 🚀 实现优先级

### Phase 1: 核心基础设施 (高优先级)
```
1. 规则库存储系统
2. 基本CRUD操作
3. 状态管理器
4. 配置应用器
5. 数据验证层
```

### Phase 2: 用户界面 (中优先级)
```
1. 规则库管理UI
2. 规则应用管理UI
3. 批量操作支持
4. 导入/导出功能
5. 配置差异查看
```

### Phase 3: 高级功能 (低优先级)
```
1. 规则模板系统
2. 智能冲突检测
3. 性能优化
4. 高级备份恢复
5. 操作审计日志
```

## 📁 文件结构设计

```
/etc/hysteria/
├── config.yaml                    # 主配置文件
├── rules/                          # 规则管理目录
│   ├── library.yaml               # 规则库
│   ├── applied.yaml               # 应用状态
│   ├── templates.yaml             # 规则模板
│   └── backups/                   # 配置备份
│       ├── config_20250928_103000.yaml
│       └── state_20250928_103000.yaml
└── logs/                          # 日志目录
    └── rule-management.log

scripts/
├── rules/                         # 规则管理脚本目录
│   ├── rule-library.sh           # 规则库管理器
│   ├── rule-state.sh             # 状态管理器
│   ├── config-applier.sh         # 配置应用器
│   ├── rule-validator.sh         # 规则验证器
│   ├── rule-templates.sh         # 模板管理器
│   ├── migration-helper.sh       # 迁移助手
│   └── rule-ui.sh                # 用户界面
└── outbound-manager-v2.sh         # 新版主管理器
```

## 🔧 核心组件实现

### 1. 规则库管理器 (rule-library.sh)

```bash
#!/bin/bash
# 规则库管理器 - 负责规则的CRUD操作

# 规则库路径
readonly RULE_LIBRARY="/etc/hysteria/rules/library.yaml"
readonly RULE_TEMPLATES="/etc/hysteria/rules/templates.yaml"

# 创建规则
rule_create() {
    local name="$1" type="$2" description="$3" config_json="$4"

    # 生成规则ID
    local rule_id="rule_$(date +%s)_$(shuf -i 1000-9999 -n 1)"

    # 验证规则格式
    if ! rule_validate_config "$type" "$config_json"; then
        echo "ERROR: 规则配置验证失败"
        return 1
    fi

    # 检查名称唯一性
    if rule_exists_by_name "$name"; then
        echo "ERROR: 规则名称已存在: $name"
        return 1
    fi

    # 添加到规则库
    rule_library_add_entry "$rule_id" "$name" "$type" "$description" "$config_json"

    echo "SUCCESS: 规则创建成功, ID: $rule_id"
    echo "$rule_id"
}

# 列出所有规则
rule_list() {
    local filter="$1"  # 可选: type|applied|name
    local value="$2"   # 过滤值

    if [[ ! -f "$RULE_LIBRARY" ]]; then
        echo "[]"
        return 0
    fi

    # 根据过滤条件返回规则列表
    case "$filter" in
        "type")
            yq eval ".rules[] | select(.type == \"$value\")" "$RULE_LIBRARY"
            ;;
        "applied")
            # 需要与状态管理器配合
            rule_state_get_applied | jq -r '.[].rule_id' | while read -r rule_id; do
                rule_get "$rule_id"
            done
            ;;
        *)
            yq eval '.rules[]' "$RULE_LIBRARY"
            ;;
    esac
}

# 获取规则详情
rule_get() {
    local rule_id="$1"

    if [[ ! -f "$RULE_LIBRARY" ]]; then
        echo "ERROR: 规则库不存在"
        return 1
    fi

    yq eval ".rules.$rule_id" "$RULE_LIBRARY"
}

# 更新规则
rule_update() {
    local rule_id="$1" field="$2" value="$3"

    # 验证规则存在
    if ! rule_exists "$rule_id"; then
        echo "ERROR: 规则不存在: $rule_id"
        return 1
    fi

    # 创建备份
    cp "$RULE_LIBRARY" "${RULE_LIBRARY}.bak"

    # 更新字段
    case "$field" in
        "name")
            if rule_exists_by_name "$value"; then
                echo "ERROR: 规则名称已存在: $value"
                return 1
            fi
            yq eval ".rules.$rule_id.name = \"$value\"" -i "$RULE_LIBRARY"
            ;;
        "description")
            yq eval ".rules.$rule_id.description = \"$value\"" -i "$RULE_LIBRARY"
            ;;
        "config")
            # JSON格式的配置更新
            yq eval ".rules.$rule_id.config = $value" -i "$RULE_LIBRARY"
            ;;
        *)
            echo "ERROR: 不支持的字段: $field"
            return 1
            ;;
    esac

    # 更新修改时间
    yq eval ".rules.$rule_id.modified = \"$(date -Iseconds)\"" -i "$RULE_LIBRARY"
    yq eval ".metadata.last_modified = \"$(date -Iseconds)\"" -i "$RULE_LIBRARY"

    rm -f "${RULE_LIBRARY}.bak"
    echo "SUCCESS: 规则更新成功"
}

# 删除规则
rule_delete() {
    local rule_id="$1"

    # 检查规则是否已应用
    if rule_state_is_applied "$rule_id"; then
        echo "ERROR: 无法删除已应用的规则，请先取消应用"
        return 1
    fi

    # 创建备份
    cp "$RULE_LIBRARY" "${RULE_LIBRARY}.bak"

    # 删除规则
    yq eval "del(.rules.$rule_id)" -i "$RULE_LIBRARY"

    # 更新元数据
    local total_count=$(yq eval '.rules | keys | length' "$RULE_LIBRARY")
    yq eval ".metadata.total_rules = $total_count" -i "$RULE_LIBRARY"
    yq eval ".metadata.last_modified = \"$(date -Iseconds)\"" -i "$RULE_LIBRARY"

    rm -f "${RULE_LIBRARY}.bak"
    echo "SUCCESS: 规则删除成功"
}

# 辅助函数
rule_exists() {
    local rule_id="$1"
    yq eval ".rules | has(\"$rule_id\")" "$RULE_LIBRARY" | grep -q "true"
}

rule_exists_by_name() {
    local name="$1"
    yq eval ".rules[].name" "$RULE_LIBRARY" | grep -q "^$name$"
}

rule_validate_config() {
    local type="$1" config="$2"

    case "$type" in
        "direct")
            # 验证direct配置格式
            echo "$config" | jq -e '.direct' >/dev/null
            ;;
        "socks5")
            # 验证socks5配置格式
            echo "$config" | jq -e '.socks5.addr' >/dev/null
            ;;
        "http")
            # 验证http配置格式
            echo "$config" | jq -e '.http.url' >/dev/null
            ;;
        *)
            echo "ERROR: 不支持的规则类型: $type"
            return 1
            ;;
    esac
}
```

### 2. 状态管理器 (rule-state.sh)

```bash
#!/bin/bash
# 状态管理器 - 负责规则应用状态的管理

readonly APPLIED_STATE="/etc/hysteria/rules/applied.yaml"
readonly HYSTERIA_CONFIG="/etc/hysteria/config.yaml"
readonly BACKUP_DIR="/etc/hysteria/rules/backups"

# 应用规则到配置
rule_state_apply() {
    local rule_id="$1"

    # 获取规则详情
    local rule_data
    rule_data=$(rule_get "$rule_id")
    if [[ $? -ne 0 ]]; then
        echo "ERROR: 规则不存在: $rule_id"
        return 1
    fi

    local rule_name=$(echo "$rule_data" | yq eval '.name' -)
    local rule_type=$(echo "$rule_data" | yq eval '.type' -)
    local rule_config=$(echo "$rule_data" | yq eval '.config' -)

    # 检查是否已应用
    if rule_state_is_applied "$rule_id"; then
        echo "ERROR: 规则已经应用: $rule_name"
        return 1
    fi

    # 创建配置备份
    rule_state_create_backup "before_apply_$rule_name"

    # 应用规则到配置文件
    if config_applier_add_rule "$rule_name" "$rule_type" "$rule_config"; then
        # 更新应用状态
        rule_state_add_applied "$rule_id" "$rule_name"
        echo "SUCCESS: 规则应用成功: $rule_name"
        return 0
    else
        echo "ERROR: 规则应用失败"
        return 1
    fi
}

# 取消规则应用
rule_state_unapply() {
    local rule_id="$1"

    # 检查是否已应用
    if ! rule_state_is_applied "$rule_id"; then
        echo "ERROR: 规则未应用: $rule_id"
        return 1
    fi

    local rule_name=$(rule_state_get_applied_name "$rule_id")

    # 创建配置备份
    rule_state_create_backup "before_unapply_$rule_name"

    # 从配置文件移除规则
    if config_applier_remove_rule "$rule_name"; then
        # 更新应用状态
        rule_state_remove_applied "$rule_id"
        echo "SUCCESS: 规则取消应用成功: $rule_name"
        return 0
    else
        echo "ERROR: 规则取消应用失败"
        return 1
    fi
}

# 获取已应用规则列表
rule_state_get_applied() {
    if [[ ! -f "$APPLIED_STATE" ]]; then
        echo "[]"
        return 0
    fi

    yq eval '.applied_rules[]' "$APPLIED_STATE"
}

# 检查规则是否已应用
rule_state_is_applied() {
    local rule_id="$1"

    if [[ ! -f "$APPLIED_STATE" ]]; then
        return 1
    fi

    yq eval ".applied_rules[] | select(.rule_id == \"$rule_id\")" "$APPLIED_STATE" | grep -q "rule_id"
}

# 获取已应用规则的名称
rule_state_get_applied_name() {
    local rule_id="$1"
    yq eval ".applied_rules[] | select(.rule_id == \"$rule_id\") | .rule_name" "$APPLIED_STATE"
}

# 添加应用状态记录
rule_state_add_applied() {
    local rule_id="$1" rule_name="$2"

    # 初始化状态文件
    rule_state_init_file

    # 添加应用记录
    local applied_entry=$(cat <<EOF
{
  "rule_id": "$rule_id",
  "rule_name": "$rule_name",
  "applied_at": "$(date -Iseconds)"
}
EOF
)

    yq eval ".applied_rules += [$applied_entry]" -i "$APPLIED_STATE"
    yq eval ".metadata.last_applied = \"$(date -Iseconds)\"" -i "$APPLIED_STATE"
}

# 移除应用状态记录
rule_state_remove_applied() {
    local rule_id="$1"

    yq eval "del(.applied_rules[] | select(.rule_id == \"$rule_id\"))" -i "$APPLIED_STATE"
    yq eval ".metadata.last_applied = \"$(date -Iseconds)\"" -i "$APPLIED_STATE"
}

# 创建配置备份
rule_state_create_backup() {
    local backup_name="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/config_${backup_name}_${timestamp}.yaml"

    mkdir -p "$BACKUP_DIR"
    cp "$HYSTERIA_CONFIG" "$backup_file"

    # 更新备份记录
    yq eval ".backup_config.backup_path = \"$backup_file\"" -i "$APPLIED_STATE"
    yq eval ".backup_config.created_at = \"$(date -Iseconds)\"" -i "$APPLIED_STATE"

    echo "配置备份已创建: $backup_file"
}

# 初始化状态文件
rule_state_init_file() {
    if [[ ! -f "$APPLIED_STATE" ]]; then
        mkdir -p "$(dirname "$APPLIED_STATE")"
        cat > "$APPLIED_STATE" <<EOF
metadata:
  version: "2.0"
  last_applied: "$(date -Iseconds)"
  hysteria_config: "$HYSTERIA_CONFIG"

applied_rules: []

backup_config:
  backup_path: ""
  created_at: ""
EOF
    fi
}
```

### 3. 配置应用器 (config-applier.sh)

```bash
#!/bin/bash
# 配置应用器 - 负责将规则应用到Hysteria2配置文件

# 添加规则到配置文件
config_applier_add_rule() {
    local rule_name="$1" rule_type="$2" rule_config="$3"

    # 创建临时配置文件
    local temp_config="/tmp/hysteria_apply_$(date +%s).yaml"
    cp "$HYSTERIA_CONFIG" "$temp_config"

    # 检查是否存在outbounds节点
    if ! yq eval '.outbounds' "$temp_config" >/dev/null 2>&1; then
        # 创建outbounds节点
        yq eval '.outbounds = []' -i "$temp_config"
    fi

    # 构建规则配置
    local rule_yaml
    case "$rule_type" in
        "direct")
            rule_yaml=$(echo "$rule_config" | yq eval '{name: "'$rule_name'", type: "direct", direct: .direct}' -)
            ;;
        "socks5")
            rule_yaml=$(echo "$rule_config" | yq eval '{name: "'$rule_name'", type: "socks5", socks5: .socks5}' -)
            ;;
        "http")
            rule_yaml=$(echo "$rule_config" | yq eval '{name: "'$rule_name'", type: "http", http: .http}' -)
            ;;
        *)
            echo "ERROR: 不支持的规则类型: $rule_type"
            rm -f "$temp_config"
            return 1
            ;;
    esac

    # 添加规则到outbounds
    yq eval ".outbounds += [$rule_yaml]" -i "$temp_config"

    # 验证配置文件格式
    if ! yq eval '.' "$temp_config" >/dev/null 2>&1; then
        echo "ERROR: 生成的配置文件格式错误"
        rm -f "$temp_config"
        return 1
    fi

    # 原子性更新配置文件
    if mv "$temp_config" "$HYSTERIA_CONFIG"; then
        echo "规则已添加到配置文件: $rule_name"
        return 0
    else
        echo "ERROR: 配置文件更新失败"
        rm -f "$temp_config"
        return 1
    fi
}

# 从配置文件移除规则
config_applier_remove_rule() {
    local rule_name="$1"

    # 创建临时配置文件
    local temp_config="/tmp/hysteria_remove_$(date +%s).yaml"
    cp "$HYSTERIA_CONFIG" "$temp_config"

    # 移除指定规则
    yq eval "del(.outbounds[] | select(.name == \"$rule_name\"))" -i "$temp_config"

    # 如果outbounds为空，删除整个节点
    local outbounds_count=$(yq eval '.outbounds | length' "$temp_config")
    if [[ "$outbounds_count" == "0" ]]; then
        yq eval 'del(.outbounds)' -i "$temp_config"
    fi

    # 移除相关ACL规则
    config_applier_remove_acl_rules "$rule_name" "$temp_config"

    # 验证配置文件格式
    if ! yq eval '.' "$temp_config" >/dev/null 2>&1; then
        echo "ERROR: 生成的配置文件格式错误"
        rm -f "$temp_config"
        return 1
    fi

    # 原子性更新配置文件
    if mv "$temp_config" "$HYSTERIA_CONFIG"; then
        echo "规则已从配置文件移除: $rule_name"
        return 0
    else
        echo "ERROR: 配置文件更新失败"
        rm -f "$temp_config"
        return 1
    fi
}

# 移除ACL规则
config_applier_remove_acl_rules() {
    local rule_name="$1" config_file="$2"

    # 移除inline ACL中的规则引用
    yq eval "del(.acl.inline[] | select(. | test(\"$rule_name\")))" -i "$config_file"

    # 如果inline ACL为空，删除ACL节点
    local acl_count=$(yq eval '.acl.inline | length' "$config_file" 2>/dev/null || echo "0")
    if [[ "$acl_count" == "0" ]]; then
        yq eval 'del(.acl)' -i "$config_file"
    fi
}

# 批量应用规则
config_applier_batch_apply() {
    local rule_ids=("$@")

    for rule_id in "${rule_ids[@]}"; do
        if ! rule_state_apply "$rule_id"; then
            echo "ERROR: 批量应用在规则 $rule_id 处失败"
            return 1
        fi
    done

    echo "SUCCESS: 批量应用完成，共应用 ${#rule_ids[@]} 个规则"
}

# 验证最终配置
config_applier_validate() {
    local config_file="${1:-$HYSTERIA_CONFIG}"

    # YAML格式验证
    if ! yq eval '.' "$config_file" >/dev/null 2>&1; then
        echo "ERROR: YAML格式错误"
        return 1
    fi

    # 基本结构验证
    if yq eval '.outbounds[]' "$config_file" 2>/dev/null | grep -q "name:"; then
        # 检查规则名称唯一性
        local names=$(yq eval '.outbounds[].name' "$config_file" | sort)
        local unique_names=$(echo "$names" | uniq)

        if [[ "$names" != "$unique_names" ]]; then
            echo "ERROR: 规则名称重复"
            return 1
        fi
    fi

    echo "配置文件验证通过"
    return 0
}
```

## 🎮 用户界面组件

### 4. 用户界面管理器 (rule-ui.sh)

```bash
#!/bin/bash
# 用户界面管理器 - 提供友好的交互界面

# 主菜单
rule_ui_main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== Hysteria2 出站规则管理 v2.0 ===${NC}"
        echo ""
        echo -e "${GREEN}规则库管理：${NC}"
        echo -e "${GREEN} 1.${NC} 查看规则库"
        echo -e "${GREEN} 2.${NC} 创建新规则"
        echo -e "${GREEN} 3.${NC} 编辑规则"
        echo -e "${GREEN} 4.${NC} 删除规则"
        echo -e "${GREEN} 5.${NC} 导入/导出规则"
        echo ""
        echo -e "${CYAN}应用管理：${NC}"
        echo -e "${CYAN} 6.${NC} 查看应用状态"
        echo -e "${CYAN} 7.${NC} 应用规则"
        echo -e "${CYAN} 8.${NC} 取消应用规则"
        echo -e "${CYAN} 9.${NC} 批量操作"
        echo ""
        echo -e "${YELLOW}系统功能：${NC}"
        echo -e "${YELLOW}10.${NC} 配置备份恢复"
        echo -e "${YELLOW}11.${NC} 状态同步检查"
        echo -e "${YELLOW}12.${NC} 迁移旧配置"
        echo ""
        echo -e "${RED} 0.${NC} 返回主菜单"
        echo ""

        read -p "请选择操作 [0-12]: " choice

        case $choice in
            1) rule_ui_view_library ;;
            2) rule_ui_create_rule ;;
            3) rule_ui_edit_rule ;;
            4) rule_ui_delete_rule ;;
            5) rule_ui_import_export ;;
            6) rule_ui_view_applied ;;
            7) rule_ui_apply_rule ;;
            8) rule_ui_unapply_rule ;;
            9) rule_ui_batch_operations ;;
            10) rule_ui_backup_restore ;;
            11) rule_ui_sync_check ;;
            12) rule_ui_migrate_config ;;
            0) break ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                sleep 1
                ;;
        esac
    done
}

# 查看规则库
rule_ui_view_library() {
    clear
    echo -e "${BLUE}=== 规则库 ===${NC}"
    echo ""

    local rules_json=$(rule_list)
    if [[ "$rules_json" == "[]" ]]; then
        echo -e "${YELLOW}规则库为空${NC}"
        echo ""
        read -p "按任意键继续..." -n 1
        return
    fi

    echo -e "${GREEN}当前规则列表：${NC}"
    echo ""

    # 使用表格格式显示规则
    printf "%-4s %-20s %-10s %-8s %-30s\n" "序号" "规则名称" "类型" "状态" "描述"
    echo "────────────────────────────────────────────────────────────────────"

    local count=1
    echo "$rules_json" | jq -r '.[] | [.id, .name, .type, .description] | @csv' | \
    while IFS=',' read -r id name type desc; do
        # 移除CSV引号
        id=$(echo "$id" | tr -d '"')
        name=$(echo "$name" | tr -d '"')
        type=$(echo "$type" | tr -d '"')
        desc=$(echo "$desc" | tr -d '"')

        # 检查应用状态
        local status="未应用"
        if rule_state_is_applied "$id"; then
            status="${GREEN}已应用${NC}"
        else
            status="${YELLOW}未应用${NC}"
        fi

        printf "%-4s %-20s %-10s %-8s %-30s\n" "$count" "$name" "$type" "$status" "$desc"
        ((count++))
    done

    echo ""
    read -p "按任意键继续..." -n 1
}
```

## 📋 总结

这个新架构设计提供了：

### ✅ **核心优势**
- **关注点分离**：规则库、状态管理、配置应用完全解耦
- **完整CRUD**：规则的创建、读取、更新、删除全生命周期管理
- **状态追踪**：独立的应用状态管理，清晰的规则应用记录
- **原子操作**：配置更新的原子性保证，支持回滚
- **向后兼容**：保留现有功能，支持渐进式迁移

### 🎯 **解决的问题**
1. ❌ 出站规则直接耦合在配置中 → ✅ 独立规则库管理
2. ❌ 无法进行CRUD操作 → ✅ 完整的规则生命周期管理
3. ❌ 缺少应用/取消机制 → ✅ 灵活的规则应用状态管理
4. ❌ 管理复杂度高 → ✅ 直观的用户界面和批量操作

### 🚀 **实施路径**
1. **Phase 1**: 实现核心基础设施（规则库、状态管理）
2. **Phase 2**: 开发用户界面和基本操作
3. **Phase 3**: 添加高级功能和优化

这个架构为Hysteria2出站规则管理提供了现代化、可扩展的解决方案，显著提升了用户体验和系统可维护性。