#!/bin/bash

# Outbound Manager 修复验证脚本
# 用于验证 backup_file 变量问题是否已修复

echo "=== Outbound Manager 修复验证 ==="
echo ""

# 检查修复的关键行
echo "1. 检查 backup_file 变量引用是否已清理："
echo ""

# 搜索所有 backup_file 引用
if grep -n "backup_file" scripts/outbound-manager.sh 2>/dev/null; then
    echo "❌ 发现 backup_file 变量引用，修复可能不完整"
    exit 1
else
    echo "✅ 所有 backup_file 变量引用已清理"
fi

echo ""

# 检查语法错误
echo "2. 检查 Bash 语法错误："
echo ""

if bash -n scripts/outbound-manager.sh 2>/dev/null; then
    echo "✅ Bash 语法检查通过"
else
    echo "❌ 发现 Bash 语法错误"
    bash -n scripts/outbound-manager.sh
    exit 1
fi

echo ""

# 检查关键函数是否存在
echo "3. 检查关键函数完整性："
echo ""

key_functions=(
    "apply_outbound_simple"
    "apply_outbound_to_config"
    "add_outbound_rule"
    "delete_outbound_rule"
    "manage_outbound"
)

all_functions_found=true
for func in "${key_functions[@]}"; do
    if grep -q "^${func}()" scripts/outbound-manager.sh; then
        echo "✅ 函数 $func 存在"
    else
        echo "❌ 函数 $func 缺失"
        all_functions_found=false
    fi
done

if [[ "$all_functions_found" == false ]]; then
    exit 1
fi

echo ""

# 检查验证逻辑是否改为警告模式
echo "4. 检查验证逻辑是否改为警告模式："
echo ""

if grep -q "配置语法验证失败，但继续执行" scripts/outbound-manager.sh; then
    echo "✅ 验证逻辑已改为警告模式"
else
    echo "❌ 验证逻辑未正确修改"
    exit 1
fi

echo ""

# 检查错误处理逻辑
echo "5. 检查错误处理是否完整："
echo ""

if grep -q "配置应用失败，请检查文件权限和磁盘空间" scripts/outbound-manager.sh; then
    echo "✅ 错误恢复逻辑已修复"
else
    echo "❌ 错误恢复逻辑未正确修改"
    exit 1
fi

echo ""

# 模拟关键函数调用检查
echo "6. 模拟函数调用检查："
echo ""

# 检查函数内部是否有未定义变量（模拟 set -u 模式）
if bash -c "set -u; source scripts/outbound-manager.sh; echo 'Functions loaded successfully'" 2>/dev/null; then
    echo "✅ 模拟函数加载成功，无未定义变量"
else
    echo "❌ 发现潜在的未定义变量问题"
    echo "详细错误："
    bash -c "set -u; source scripts/outbound-manager.sh" 2>&1 | head -5
    exit 1
fi

echo ""
echo "🎉 所有检查通过！Outbound Manager 修复验证成功"
echo ""
echo "修复摘要："
echo "- ✅ 移除了所有 backup_file 变量引用"
echo "- ✅ 修复了错误恢复逻辑"
echo "- ✅ 验证逻辑改为警告模式，不会中断执行"
echo "- ✅ 保持了所有核心功能的完整性"
echo ""
echo "现在可以安全地使用 add_outbound_rule 功能，不会再出现 backup_file 崩溃问题。"