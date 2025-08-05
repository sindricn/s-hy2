#!/bin/bash

# 测试域名功能修复效果

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}域名测试功能修复验证${NC}"
echo ""

# 检查脚本是否存在
if [[ ! -f "/opt/s-hy2/scripts/domain-test.sh" ]]; then
    echo -e "${RED}错误: 域名测试脚本不存在${NC}"
    echo "请先运行修复脚本:"
    echo "curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/fix-installation.sh | sudo bash"
    exit 1
fi

# 加载域名测试脚本
source /opt/s-hy2/scripts/domain-test.sh

echo -e "${BLUE}测试1: 静默版本域名测试${NC}"
echo "这个测试应该只输出 '延迟 域名' 格式的数据，没有进度信息"
echo ""

# 测试静默版本
echo "--- 静默版本输出 ---"
results=$(test_all_domains_silent | head -5)
echo "$results"
echo "--- 输出结束 ---"
echo ""

# 验证输出格式
echo -e "${BLUE}验证输出格式:${NC}"
valid_lines=0
total_lines=0

while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        total_lines=$((total_lines + 1))
        latency=$(echo "$line" | awk '{print $1}')
        domain=$(echo "$line" | awk '{print $2}')
        
        if [[ "$latency" =~ ^[0-9]+$ ]] && [[ -n "$domain" ]] && [[ ! "$domain" =~ [[:space:]] ]]; then
            echo -e "${GREEN}✓ 有效: $latency ms - $domain${NC}"
            valid_lines=$((valid_lines + 1))
        else
            echo -e "${RED}✗ 无效: $line${NC}"
        fi
    fi
done <<< "$results"

echo ""
echo "统计: $valid_lines/$total_lines 行有效"

if [[ $valid_lines -eq $total_lines ]] && [[ $total_lines -gt 0 ]]; then
    echo -e "${GREEN}✅ 静默版本测试通过${NC}"
else
    echo -e "${RED}❌ 静默版本测试失败${NC}"
fi

echo ""
echo -e "${BLUE}测试2: 带进度版本域名测试${NC}"
echo "这个测试应该显示进度信息，但不影响结果输出"
echo ""

# 测试带进度版本
echo "--- 带进度版本输出 ---"
results_with_progress=$(test_all_domains | head -5)
echo "$results_with_progress"
echo "--- 输出结束 ---"
echo ""

# 比较两个版本的输出
echo -e "${BLUE}比较两个版本的输出:${NC}"
if [[ "$results" == "$results_with_progress" ]]; then
    echo -e "${GREEN}✅ 两个版本输出一致${NC}"
else
    echo -e "${RED}❌ 两个版本输出不一致${NC}"
    echo ""
    echo "静默版本:"
    echo "$results"
    echo ""
    echo "带进度版本:"
    echo "$results_with_progress"
fi

echo ""
echo -e "${BLUE}测试3: 获取最优域名${NC}"
best_domain=$(get_best_domain_name)
echo "最优域名: $best_domain"

if [[ -n "$best_domain" ]] && [[ ! "$best_domain" =~ [[:space:]] ]]; then
    echo -e "${GREEN}✅ 最优域名获取成功${NC}"
else
    echo -e "${RED}❌ 最优域名获取失败${NC}"
fi

echo ""
echo -e "${CYAN}修复验证完成${NC}"
echo ""
echo -e "${YELLOW}如果所有测试都通过，域名测试功能应该已经修复${NC}"
echo -e "${YELLOW}现在可以运行 'sudo s-hy2' 测试交互式域名选择功能${NC}"
