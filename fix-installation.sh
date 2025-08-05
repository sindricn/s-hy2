#!/bin/bash

# S-Hy2 安装修复脚本
# 用于修复已安装但有问题的 s-hy2

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
INSTALL_DIR="/opt/s-hy2"
BIN_DIR="/usr/local/bin"
RAW_URL="https://raw.githubusercontent.com/sindricn/s-hy2/main"

echo -e "${CYAN}S-Hy2 安装修复脚本${NC}"
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 需要 root 权限${NC}"
    echo "请使用: sudo bash"
    exit 1
fi

# 诊断当前安装状态
echo -e "${BLUE}诊断当前安装状态...${NC}"

echo "1. 检查安装目录:"
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "   ${GREEN}✓ 安装目录存在: $INSTALL_DIR${NC}"
    ls -la "$INSTALL_DIR"
else
    echo -e "   ${RED}✗ 安装目录不存在: $INSTALL_DIR${NC}"
fi

echo ""
echo "2. 检查主脚本:"
if [[ -f "$INSTALL_DIR/hy2-manager.sh" ]]; then
    echo -e "   ${GREEN}✓ 主脚本存在${NC}"
    ls -la "$INSTALL_DIR/hy2-manager.sh"
else
    echo -e "   ${RED}✗ 主脚本不存在${NC}"
fi

echo ""
echo "3. 检查功能脚本目录:"
if [[ -d "$INSTALL_DIR/scripts" ]]; then
    echo -e "   ${GREEN}✓ 功能脚本目录存在${NC}"
    echo "   目录内容:"
    ls -la "$INSTALL_DIR/scripts/"
else
    echo -e "   ${RED}✗ 功能脚本目录不存在${NC}"
fi

echo ""
echo "4. 检查快捷方式:"
if [[ -L "$BIN_DIR/s-hy2" ]]; then
    echo -e "   ${GREEN}✓ s-hy2 快捷方式存在${NC}"
    echo "   链接目标: $(readlink "$BIN_DIR/s-hy2")"
else
    echo -e "   ${RED}✗ s-hy2 快捷方式不存在${NC}"
fi

echo ""
echo -e "${YELLOW}开始修复...${NC}"

# 创建必要目录
echo -e "${BLUE}1. 创建必要目录...${NC}"
mkdir -p "$INSTALL_DIR/scripts" "$INSTALL_DIR/templates"
echo -e "${GREEN}✓ 目录创建完成${NC}"

# 下载主脚本
echo -e "${BLUE}2. 下载/更新主脚本...${NC}"
if curl -fsSL "$RAW_URL/hy2-manager.sh" -o "$INSTALL_DIR/hy2-manager.sh"; then
    chmod +x "$INSTALL_DIR/hy2-manager.sh"
    echo -e "${GREEN}✓ 主脚本下载成功${NC}"
else
    echo -e "${RED}✗ 主脚本下载失败${NC}"
    exit 1
fi

# 下载功能脚本
echo -e "${BLUE}3. 下载/更新功能脚本...${NC}"
scripts=(
    "install.sh"
    "config.sh"
    "service.sh"
    "domain-test.sh"
    "advanced.sh"
    "node-info.sh"
)

success=0
total=${#scripts[@]}

for script in "${scripts[@]}"; do
    echo "   下载 $script..."
    if curl -fsSL "$RAW_URL/scripts/$script" -o "$INSTALL_DIR/scripts/$script"; then
        chmod +x "$INSTALL_DIR/scripts/$script"
        echo -e "   ${GREEN}✓ $script${NC}"
        ((success++))
    else
        echo -e "   ${RED}✗ $script${NC}"
    fi
done

echo -e "${GREEN}✓ 功能脚本下载完成 ($success/$total)${NC}"

# 下载配置模板
echo -e "${BLUE}4. 下载/更新配置模板...${NC}"
templates=(
    "acme-config.yaml"
    "self-cert-config.yaml"
    "advanced-config.yaml"
    "client-config.yaml"
)

template_success=0
template_total=${#templates[@]}

for template in "${templates[@]}"; do
    echo "   下载 $template..."
    if curl -fsSL "$RAW_URL/templates/$template" -o "$INSTALL_DIR/templates/$template"; then
        echo -e "   ${GREEN}✓ $template${NC}"
        ((template_success++))
    else
        echo -e "   ${RED}✗ $template${NC}"
    fi
done

echo -e "${GREEN}✓ 配置模板下载完成 ($template_success/$template_total)${NC}"

# 修复快捷方式
echo -e "${BLUE}5. 修复快捷方式...${NC}"
rm -f "$BIN_DIR/s-hy2" "$BIN_DIR/hy2-manager"
if ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/s-hy2" && \
   ln -sf "$INSTALL_DIR/hy2-manager.sh" "$BIN_DIR/hy2-manager"; then
    echo -e "${GREEN}✓ 快捷方式修复成功${NC}"
else
    echo -e "${YELLOW}⚠ 快捷方式创建失败，可直接运行: $INSTALL_DIR/hy2-manager.sh${NC}"
fi

# 验证修复结果
echo -e "${BLUE}6. 验证修复结果...${NC}"

required_files=(
    "$INSTALL_DIR/hy2-manager.sh"
    "$INSTALL_DIR/scripts/install.sh"
    "$INSTALL_DIR/scripts/config.sh"
    "$INSTALL_DIR/scripts/service.sh"
)

missing=0
for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "   ${GREEN}✓ $(basename "$file")${NC}"
    else
        echo -e "   ${RED}✗ $(basename "$file")${NC}"
        ((missing++))
    fi
done

echo ""
if [[ $missing -eq 0 ]]; then
    echo -e "${GREEN}🎉 修复完成！所有关键文件都已就位${NC}"
    echo ""
    echo -e "${YELLOW}现在可以运行:${NC}"
    echo "  sudo s-hy2"
    echo ""
    
    # 询问是否立即测试
    echo -n -e "${YELLOW}是否立即测试运行 s-hy2? [y/N]: ${NC}"
    read -r test_run
    if [[ $test_run =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}正在启动 s-hy2...${NC}"
        exec "$INSTALL_DIR/hy2-manager.sh"
    fi
else
    echo -e "${RED}❌ 修复未完全成功，仍缺少 $missing 个关键文件${NC}"
    echo ""
    echo -e "${YELLOW}建议:${NC}"
    echo "1. 检查网络连接"
    echo "2. 重新运行完整安装:"
    echo "   curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/install-fixed.sh | sudo bash"
    exit 1
fi

echo -e "${BLUE}修复完成！${NC}"
