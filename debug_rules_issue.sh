#!/bin/bash

# 规则库问题诊断脚本
# 帮助诊断查看和新增功能的不一致问题

echo "=== Hysteria2 出站规则库诊断脚本 ==="
echo "时间: $(date)"
echo ""

# 1. 检查规则库文件位置
echo "1. 检查规则库文件位置"
source scripts/outbound-manager.sh >/dev/null 2>&1

# 初始化规则库并获取路径
init_rules_library >/dev/null 2>&1
echo "   规则库路径: $RULES_LIBRARY"
echo "   规则库目录: $RULES_DIR"
echo "   文件是否存在: $(test -f "$RULES_LIBRARY" && echo "存在" || echo "不存在")"

if [[ -f "$RULES_LIBRARY" ]]; then
    echo "   文件大小: $(wc -c < "$RULES_LIBRARY") 字节"
    echo "   文件行数: $(wc -l < "$RULES_LIBRARY") 行"
fi
echo ""

# 2. 手动解析规则
echo "2. 手动解析规则库中的规则"
if [[ -f "$RULES_LIBRARY" ]]; then
    echo "   直接解析规则名称:"
    grep -A 100 "^rules:" "$RULES_LIBRARY" | grep "^  [a-zA-Z_][a-zA-Z0-9_]*:" | sed 's/^  \([^:]*\):.*/   - \1/' | nl -v0 -s': ' | sed 's/0:/  /'

    echo ""
    echo "   规则计数: $(grep -A 100 "^rules:" "$RULES_LIBRARY" | grep "^  [a-zA-Z_][a-zA-Z0-9_]*:" | wc -l)"
else
    echo "   规则库文件不存在"
fi
echo ""

# 3. 测试查看功能
echo "3. 测试查看功能输出"
echo "   运行 view_outbound_rules 的规则库部分:"
view_outbound_rules 2>/dev/null | sed -n '/📚 规则库中的规则/,/^$/p' | head -10
echo ""

# 4. 测试重复检测功能
echo "4. 测试重复检测功能"
if [[ -f "$RULES_LIBRARY" ]]; then
    first_rule=$(grep -A 100 "^rules:" "$RULES_LIBRARY" | grep "^  [a-zA-Z_][a-zA-Z0-9_]*:" | head -1 | sed 's/^  \([^:]*\):.*/\1/')
    if [[ -n "$first_rule" ]]; then
        echo "   测试规则: $first_rule"
        echo "   重复检测结果:"
        if grep -q "^[[:space:]]\{2\}$first_rule:[[:space:]]*$" "$RULES_LIBRARY" 2>/dev/null; then
            echo "   ✅ 正确检测到重复"
        else
            echo "   ❌ 未检测到重复"
        fi
    else
        echo "   无规则可测试"
    fi
fi
echo ""

# 5. 检查函数是否使用相同的文件
echo "5. 验证查看和新增功能使用相同的规则库文件"
echo "   查看功能使用的文件: $RULES_LIBRARY"

# 模拟新增功能的文件路径
init_rules_library >/dev/null 2>&1
echo "   新增功能使用的文件: $RULES_LIBRARY"

if [[ "$RULES_LIBRARY" == "$RULES_LIBRARY" ]]; then
    echo "   ✅ 两个功能使用相同的规则库文件"
else
    echo "   ❌ 两个功能使用不同的规则库文件"
fi
echo ""

# 6. 检查文件权限
echo "6. 检查文件权限"
if [[ -f "$RULES_LIBRARY" ]]; then
    echo "   文件权限: $(ls -l "$RULES_LIBRARY" | awk '{print $1}')"
    echo "   文件所有者: $(ls -l "$RULES_LIBRARY" | awk '{print $3":"$4}')"
    echo "   是否可读: $(test -r "$RULES_LIBRARY" && echo "是" || echo "否")"
    echo "   是否可写: $(test -w "$RULES_LIBRARY" && echo "是" || echo "否")"
fi
echo ""

# 7. 最终建议
echo "7. 诊断建议"
if [[ -f "$RULES_LIBRARY" ]]; then
    rule_count=$(grep -A 100 "^rules:" "$RULES_LIBRARY" | grep "^  [a-zA-Z_][a-zA-Z0-9_]*:" | wc -l)
    if [[ $rule_count -gt 0 ]]; then
        echo "   ✅ 规则库正常，包含 $rule_count 个规则"
        echo "   📋 如果查看功能仍显示无规则，请尝试:"
        echo "      1. 重新运行 outbound-manager.sh"
        echo "      2. 检查是否有其他程序锁定文件"
        echo "      3. 重启终端会话"
    else
        echo "   ⚠️  规则库文件存在但无有效规则"
    fi
else
    echo "   ❌ 规则库文件不存在，需要重新初始化"
fi

echo ""
echo "=== 诊断完成 ==="