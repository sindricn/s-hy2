#!/bin/bash

# Hysteria2 出站规则管理模块 - 调试版本
# 专门用于诊断闪退问题

# 启用调试模式
set -x  # 显示每个执行的命令
exec > >(tee -a /tmp/outbound-debug.log) 2>&1  # 同时输出到日志文件

echo "========== 调试模式启动 $(date) =========="
echo "脚本路径: ${BASH_SOURCE[0]}"
echo "当前工作目录: $(pwd)"
echo "用户: $(whoami)"
echo "系统信息: $(uname -a)"

# 检查bash版本
echo "Bash版本: $BASH_VERSION"

# 检查关键命令
echo "========== 检查系统命令 =========="
for cmd in mktemp date chmod cp mv rm touch; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✓ $cmd 可用: $(which $cmd)"
        "$cmd" --version 2>/dev/null | head -1 || echo "  (无版本信息)"
    else
        echo "✗ $cmd 不可用"
    fi
done

# 加载公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "脚本目录: $SCRIPT_DIR"

if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    echo "加载公共库: $SCRIPT_DIR/common.sh"
    source "$SCRIPT_DIR/common.sh"
else
    echo "错误: 无法加载公共库 $SCRIPT_DIR/common.sh"
    exit 1
fi

# 测试日志函数
echo "========== 测试日志函数 =========="
log_info "测试 log_info 函数"
log_warn "测试 log_warn 函数"
log_error "测试 log_error 函数"
log_debug "测试 log_debug 函数" || echo "log_debug 函数不存在或失败"

# 配置路径
if [[ -z "${HYSTERIA_CONFIG:-}" ]]; then
    readonly HYSTERIA_CONFIG="/etc/hysteria/config.yaml"
fi

echo "配置文件路径: $HYSTERIA_CONFIG"
if [[ -f "$HYSTERIA_CONFIG" ]]; then
    echo "✓ 配置文件存在"
    echo "配置文件权限: $(ls -la "$HYSTERIA_CONFIG")"
    echo "配置文件前10行:"
    head -10 "$HYSTERIA_CONFIG" 2>/dev/null || echo "无法读取配置文件内容"
else
    echo "✗ 配置文件不存在"
fi

# 测试临时文件创建的各种方法
echo "========== 测试临时文件创建 =========="

# 方法1: mktemp -t
echo "测试方法1: mktemp -t"
if temp1=$(mktemp -t hysteria_test_XXXXXX.yaml 2>/dev/null); then
    echo "✓ mktemp -t 成功: $temp1"
    rm -f "$temp1"
else
    echo "✗ mktemp -t 失败"
fi

# 方法2: mktemp /tmp/
echo "测试方法2: mktemp /tmp/"
if temp2=$(mktemp /tmp/hysteria_test_XXXXXX.yaml 2>/dev/null); then
    echo "✓ mktemp /tmp/ 成功: $temp2"
    rm -f "$temp2"
else
    echo "✗ mktemp /tmp/ 失败"
fi

# 方法3: 手动创建
echo "测试方法3: 手动创建"
temp3="/tmp/hysteria_manual_$$_$(date +%s).yaml"
if touch "$temp3" 2>/dev/null; then
    echo "✓ 手动创建成功: $temp3"
    rm -f "$temp3"
else
    echo "✗ 手动创建失败: $temp3"
fi

# 简化的临时文件创建函数
create_simple_temp() {
    local temp_file="/tmp/hysteria_simple_$$_$(date +%s).yaml"
    echo "尝试创建: $temp_file"

    if touch "$temp_file" 2>/dev/null; then
        echo "临时文件创建成功: $temp_file"
        echo "$temp_file"
        return 0
    else
        echo "临时文件创建失败: $temp_file"
        return 1
    fi
}

# 测试简化配置应用函数
test_simple_config_apply() {
    echo "========== 测试简化配置应用 =========="

    local name="${1:-test_direct}"
    local type="${2:-direct}"

    echo "测试参数: name=$name, type=$type"

    # 检查配置文件
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        echo "错误: 配置文件不存在: $HYSTERIA_CONFIG"
        return 1
    fi

    # 创建临时文件
    local temp_config
    echo "步骤1: 创建临时文件"
    temp_config=$(create_simple_temp)
    if [[ $? -ne 0 ]] || [[ -z "$temp_config" ]]; then
        echo "错误: 创建临时文件失败"
        return 1
    fi

    # 复制配置
    echo "步骤2: 复制配置文件"
    if ! cp "$HYSTERIA_CONFIG" "$temp_config"; then
        echo "错误: 复制配置文件失败"
        rm -f "$temp_config"
        return 1
    fi

    # 添加简单的outbound配置
    echo "步骤3: 添加配置内容"
    cat >> "$temp_config" << EOF

# 测试出站规则 - $name ($type)
outbounds:
  - name: $name
    type: $type
    ${type}:
      mode: auto
EOF

    if [[ $? -ne 0 ]]; then
        echo "错误: 写入配置内容失败"
        rm -f "$temp_config"
        return 1
    fi

    echo "步骤4: 显示生成的配置"
    echo "--- 临时配置文件内容 ---"
    cat "$temp_config"
    echo "--- 配置文件结束 ---"

    # 验证语法（如果hysteria可用）
    echo "步骤5: 验证配置语法"
    if command -v hysteria >/dev/null 2>&1; then
        echo "检测到hysteria命令，开始语法验证"
        if hysteria check-config -c "$temp_config" 2>/dev/null; then
            echo "✓ 配置语法验证通过"
        else
            echo "✗ 配置语法验证失败"
            echo "错误详情:"
            hysteria check-config -c "$temp_config" 2>&1 || true
            rm -f "$temp_config"
            return 1
        fi
    else
        echo "未检测到hysteria命令，跳过语法验证"
    fi

    # 应用配置（仅在调试模式下显示，不实际应用）
    echo "步骤6: 配置准备完毕"
    echo "如果这是实际运行，现在会将配置应用到: $HYSTERIA_CONFIG"
    echo "临时文件将被移动到目标位置"

    # 清理
    rm -f "$temp_config"
    echo "✓ 调试测试完成"
    return 0
}

echo "========== 开始调试测试 =========="
test_simple_config_apply "debug_test" "direct"
echo "========== 调试完成 $(date) =========="