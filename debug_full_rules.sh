#!/bin/bash

# 完整的规则库逻辑调试
echo "=== 完整规则库逻辑调试 ==="

# 设置测试环境
export RULES_DIR="/tmp/full-test-rules"
export RULES_LIBRARY="$RULES_DIR/rules-library.yaml"
export RULES_STATE="$RULES_DIR/rules-state.yaml"

# 清理并创建测试环境
rm -rf "$RULES_DIR"
mkdir -p "$RULES_DIR"

# 创建真实的规则库文件（就像init_rules_library创建的）
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

# 手动添加一个规则，模拟用户添加
cat >> "$RULES_LIBRARY" << 'EOF'
  existing_rule:
    type: direct
    description: "已存在的规则"
    config:
      mode: auto
      bindDevice: eth0
    created_at: "2023-01-01T00:00:00Z"
    updated_at: "2023-01-01T00:00:00Z"
EOF

# 更新last_modified
sed -i 's/last_modified: ""/last_modified: "2023-01-01T00:00:00Z"/' "$RULES_LIBRARY"

echo "1. 当前规则库内容："
cat "$RULES_LIBRARY"
echo ""

echo "2. 测试重复检测逻辑："
rule_name="existing_rule"
echo "检测规则：$rule_name"

# 当前脚本使用的重复检测逻辑
if grep -q "^[[:space:]]*$rule_name:[[:space:]]*$" "$RULES_LIBRARY" 2>/dev/null; then
    echo "✅ 重复检测：找到规则（应该阻止添加）"
else
    echo "❌ 重复检测：未找到规则（会错误允许重复添加）"
fi

echo "3. 测试规则获取逻辑："
echo "使用脚本中的获取逻辑查找规则："

# 模拟view_outbound_rules中的获取逻辑
local in_rules_section=0
while IFS= read -r line; do
    # 检查是否进入rules节点
    if [[ "$line" =~ ^[[:space:]]*rules:[[:space:]]*$ ]]; then
        in_rules_section=1
        continue
    fi

    # 如果遇到顶级节点且不是rules，退出rules节点
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*$ ]] && [[ "$in_rules_section" == "1" ]]; then
        local key="${BASH_REMATCH[1]}"
        if [[ "$key" != "rules" ]]; then
            in_rules_section=0
        fi
    fi

    # 在rules节点内且为2级缩进的规则名
    if [[ "$in_rules_section" == "1" && "$line" =~ ^[[:space:]]{2}([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*$ ]]; then
        local rule_name="${BASH_REMATCH[1]}"
        echo "找到规则: $rule_name"
    fi
done < "$RULES_LIBRARY"

echo ""
echo "4. 问题分析："
echo "如果重复检测工作但获取失败，那么问题可能在获取逻辑中。"

# 清理
rm -rf "$RULES_DIR"