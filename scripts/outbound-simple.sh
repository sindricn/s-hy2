#!/bin/bash

# 极简版本出站规则配置 - 专门解决闪退问题
# 不依赖复杂的日志系统和mktemp命令

# 基本设置 - 不使用strict模式避免意外退出
set -u

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置路径
HYSTERIA_CONFIG="/etc/hysteria/config.yaml"

# 简单的日志函数
simple_log() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"
    echo -e "${color}[${level}]${NC} $message"
}

simple_info() {
    simple_log "INFO" "$BLUE" "$@"
}

simple_warn() {
    simple_log "WARN" "$YELLOW" "$@"
}

simple_error() {
    simple_log "ERROR" "$RED" "$@"
}

simple_success() {
    simple_log "SUCCESS" "$GREEN" "$@"
}

# 极简的临时文件创建
create_simple_temp_file() {
    local temp_file="/tmp/hysteria_$$_$(date +%s).yaml"

    # 直接创建文件
    if echo "# 临时配置文件" > "$temp_file" 2>/dev/null; then
        echo "$temp_file"
        return 0
    else
        simple_error "无法创建临时文件"
        return 1
    fi
}

# 添加Direct出站规则的极简版本
add_direct_simple() {
    local name="${1:-direct_out}"

    simple_info "开始添加Direct出站规则: $name"

    # 检查配置文件
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        simple_error "配置文件不存在: $HYSTERIA_CONFIG"
        return 1
    fi

    simple_info "配置文件存在，继续处理"

    # 创建备份
    local backup_file="/tmp/hysteria_backup_$$_$(date +%s).yaml"
    simple_info "创建备份文件: $backup_file"

    if ! cp "$HYSTERIA_CONFIG" "$backup_file" 2>/dev/null; then
        simple_error "无法创建备份文件"
        return 1
    fi

    simple_success "备份文件创建成功"

    # 创建临时文件
    local temp_file
    temp_file=$(create_simple_temp_file)
    if [[ $? -ne 0 ]] || [[ -z "$temp_file" ]]; then
        simple_error "临时文件创建失败"
        return 1
    fi

    simple_info "临时文件创建成功: $temp_file"

    # 复制原配置
    simple_info "复制原配置到临时文件"
    if ! cp "$HYSTERIA_CONFIG" "$temp_file" 2>/dev/null; then
        simple_error "无法复制配置文件"
        rm -f "$temp_file" "$backup_file" 2>/dev/null
        return 1
    fi

    simple_success "配置文件复制成功"

    # 检查是否已有outbounds节点
    if grep -q "^[[:space:]]*outbounds:" "$temp_file" 2>/dev/null; then
        simple_info "检测到现有outbounds配置，添加新规则"
        # 在文件末尾添加新的outbound项
        cat >> "$temp_file" << EOF

# 新增出站规则 - $name
  - name: $name
    type: direct
    direct:
      mode: auto
EOF
    else
        simple_info "未检测到outbounds配置，创建新节点"
        # 添加完整的outbounds节点
        cat >> "$temp_file" << EOF

# 出站规则配置
outbounds:
  - name: $name
    type: direct
    direct:
      mode: auto
EOF
    fi

    if [[ $? -ne 0 ]]; then
        simple_error "写入配置失败"
        rm -f "$temp_file" "$backup_file" 2>/dev/null
        return 1
    fi

    simple_success "配置内容写入成功"

    # 显示即将应用的配置（最后几行）
    simple_info "新增的配置内容:"
    tail -10 "$temp_file" 2>/dev/null || simple_warn "无法显示配置内容"

    # 尝试验证配置语法（但不因为失败而退出）
    simple_info "尝试验证配置语法"
    if command -v hysteria >/dev/null 2>&1; then
        if hysteria check-config -c "$temp_file" >/dev/null 2>&1; then
            simple_success "配置语法验证通过"
        else
            simple_warn "配置语法验证失败，但继续执行"
            simple_warn "错误详情:"
            hysteria check-config -c "$temp_file" 2>&1 | head -5 || true
        fi
    else
        simple_warn "未找到hysteria命令，跳过语法验证"
    fi

    # 应用配置
    simple_info "应用新配置"
    if mv "$temp_file" "$HYSTERIA_CONFIG" 2>/dev/null; then
        simple_success "配置已成功应用到: $HYSTERIA_CONFIG"
        simple_success "出站规则 '$name' 添加完成"
        rm -f "$backup_file" 2>/dev/null
        return 0
    else
        simple_error "配置应用失败，恢复备份"
        mv "$backup_file" "$HYSTERIA_CONFIG" 2>/dev/null || simple_error "备份恢复也失败了"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# 查看当前配置的极简版本
view_config_simple() {
    simple_info "查看当前出站配置"

    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        simple_error "配置文件不存在: $HYSTERIA_CONFIG"
        return 1
    fi

    echo -e "${BLUE}=== 当前配置文件 ===${NC}"
    echo "文件: $HYSTERIA_CONFIG"
    echo "大小: $(wc -c < "$HYSTERIA_CONFIG" 2>/dev/null || echo "未知") 字节"
    echo ""

    # 检查并显示outbounds配置
    if grep -q "^[[:space:]]*outbounds:" "$HYSTERIA_CONFIG" 2>/dev/null; then
        echo -e "${GREEN}找到出站规则配置:${NC}"
        # 显示outbounds部分
        sed -n '/^[[:space:]]*outbounds:/,/^[[:space:]]*[a-zA-Z]/p' "$HYSTERIA_CONFIG" 2>/dev/null | sed '$d' || {
            simple_warn "无法提取outbounds配置，显示包含outbounds的行:"
            grep -A 20 "outbounds:" "$HYSTERIA_CONFIG" 2>/dev/null || simple_error "grep命令也失败"
        }

        # 统计outbound项数量
        local count
        count=$(grep -c "name:" "$HYSTERIA_CONFIG" 2>/dev/null || echo "0")
        echo ""
        echo -e "${GREEN}共找到 $count 个配置项${NC}"
    else
        echo -e "${YELLOW}未找到出站规则配置${NC}"
        echo "配置文件中没有 'outbounds:' 节点"
    fi

    echo ""
    echo -e "${BLUE}=== 配置文件结束 ===${NC}"
}

# 主菜单
show_simple_menu() {
    echo ""
    echo -e "${GREEN}=== 极简出站规则配置工具 ===${NC}"
    echo "1. 查看当前配置"
    echo "2. 添加Direct出站规则"
    echo "3. 退出"
    echo ""
}

# 主函数
main() {
    while true; do
        show_simple_menu
        read -p "请选择操作 [1-3]: " choice

        case $choice in
            1)
                view_config_simple
                read -p "按回车键继续..."
                ;;
            2)
                echo ""
                read -p "请输入出站规则名称 (直接回车使用 'direct_out'): " rule_name
                rule_name=${rule_name:-direct_out}

                echo ""
                simple_info "准备添加Direct出站规则: $rule_name"
                echo "确认添加此规则到配置文件吗？ [y/N]"
                read -r confirm

                if [[ $confirm =~ ^[Yy]$ ]]; then
                    if add_direct_simple "$rule_name"; then
                        simple_success "出站规则添加完成！"
                    else
                        simple_error "出站规则添加失败！"
                    fi
                else
                    simple_info "操作已取消"
                fi

                read -p "按回车键继续..."
                ;;
            3)
                simple_info "退出极简配置工具"
                break
                ;;
            *)
                simple_warn "无效选择，请重新输入"
                ;;
        esac
    done
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "${GREEN}极简出站规则配置工具启动${NC}"
    echo "版本: 1.0 (故障排除版本)"
    echo "时间: $(date)"
    echo ""
    main
fi