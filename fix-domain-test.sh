#!/bin/bash

# 修复域名测试功能脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/s-hy2"
RAW_URL="https://raw.githubusercontent.com/sindricn/s-hy2/main"

echo -e "${CYAN}修复域名测试功能${NC}"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 需要 root 权限${NC}"
    echo "请使用: sudo bash"
    exit 1
fi

# 检查安装目录
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${RED}错误: S-Hy2 未安装${NC}"
    echo "请先运行安装脚本"
    exit 1
fi

echo -e "${BLUE}正在修复域名测试功能...${NC}"

# 备份原文件
if [[ -f "$INSTALL_DIR/scripts/domain-test.sh" ]]; then
    cp "$INSTALL_DIR/scripts/domain-test.sh" "$INSTALL_DIR/scripts/domain-test.sh.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✓ 已备份原文件${NC}"
fi

# 下载修复后的域名测试脚本
echo -e "${BLUE}下载修复后的域名测试脚本...${NC}"
if curl -fsSL "$RAW_URL/scripts/domain-test.sh" -o "$INSTALL_DIR/scripts/domain-test.sh"; then
    chmod +x "$INSTALL_DIR/scripts/domain-test.sh"
    echo -e "${GREEN}✓ 域名测试脚本更新成功${NC}"
else
    echo -e "${RED}✗ 域名测试脚本下载失败${NC}"
    exit 1
fi

# 同时更新主脚本，确保路径问题也被修复
echo -e "${BLUE}更新主脚本...${NC}"
if curl -fsSL "$RAW_URL/hy2-manager.sh" -o "$INSTALL_DIR/hy2-manager.sh"; then
    chmod +x "$INSTALL_DIR/hy2-manager.sh"
    echo -e "${GREEN}✓ 主脚本更新成功${NC}"
else
    echo -e "${YELLOW}⚠ 主脚本更新失败，但域名测试功能已修复${NC}"
fi

# 验证修复效果
echo -e "${BLUE}验证修复效果...${NC}"

# 加载修复后的脚本
source "$INSTALL_DIR/scripts/domain-test.sh"

# 测试静默版本
echo "测试静默版本域名测试..."
if results=$(test_all_domains_silent 2>/dev/null | head -3); then
    if [[ -n "$results" ]]; then
        echo -e "${GREEN}✓ 静默版本测试成功${NC}"
        
        # 验证输出格式
        valid=true
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                latency=$(echo "$line" | awk '{print $1}')
                domain=$(echo "$line" | awk '{print $2}')
                
                if [[ ! "$latency" =~ ^[0-9]+$ ]] || [[ -z "$domain" ]] || [[ "$domain" =~ [[:space:]] ]]; then
                    valid=false
                    break
                fi
            fi
        done <<< "$results"
        
        if [[ "$valid" == "true" ]]; then
            echo -e "${GREEN}✓ 输出格式验证通过${NC}"
        else
            echo -e "${YELLOW}⚠ 输出格式可能仍有问题${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 静默版本无输出，可能是网络问题${NC}"
    fi
else
    echo -e "${RED}✗ 静默版本测试失败${NC}"
fi

echo ""
echo -e "${CYAN}修复完成！${NC}"
echo ""
echo -e "${YELLOW}现在可以测试域名功能:${NC}"
echo "1. 运行: sudo s-hy2"
echo "2. 选择 '6. 测试伪装域名'"
echo "3. 选择 '2. 交互式选择域名'"
echo ""
echo -e "${YELLOW}如果仍有问题，可以运行验证脚本:${NC}"
echo "curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/test-domain-fix.sh | bash"
