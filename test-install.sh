#!/bin/bash

# S-Hy2 安装测试脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}S-Hy2 安装测试脚本${NC}"
echo ""

# 测试1: 检查网络连接
echo -e "${BLUE}测试1: 检查网络连接${NC}"
if curl -s --connect-timeout 5 https://raw.githubusercontent.com/sindricn/s-hy2/main/README.md > /dev/null; then
    echo -e "${GREEN}✓ 网络连接正常${NC}"
else
    echo -e "${RED}✗ 网络连接失败${NC}"
    echo "请检查网络设置或防火墙配置"
    exit 1
fi

# 测试2: 检查 GitHub 访问
echo -e "${BLUE}测试2: 检查 GitHub 访问${NC}"
if curl -s --connect-timeout 5 https://github.com/sindricn/s-hy2 > /dev/null; then
    echo -e "${GREEN}✓ GitHub 访问正常${NC}"
else
    echo -e "${YELLOW}⚠ GitHub 访问可能有问题${NC}"
fi

# 测试3: 检查 root 权限
echo -e "${BLUE}测试3: 检查 root 权限${NC}"
if [[ $EUID -eq 0 ]]; then
    echo -e "${GREEN}✓ 具有 root 权限${NC}"
else
    echo -e "${RED}✗ 需要 root 权限${NC}"
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 测试4: 检查系统类型
echo -e "${BLUE}测试4: 检查系统类型${NC}"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo -e "${GREEN}✓ 系统: $PRETTY_NAME${NC}"
else
    echo -e "${RED}✗ 无法检测系统类型${NC}"
    exit 1
fi

# 测试5: 检查必要命令
echo -e "${BLUE}测试5: 检查必要命令${NC}"
commands=("curl" "wget" "mkdir" "chmod" "ln")
for cmd in "${commands[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓ $cmd 可用${NC}"
    else
        echo -e "${RED}✗ $cmd 不可用${NC}"
        missing_commands+=("$cmd")
    fi
done

if [[ ${#missing_commands[@]} -gt 0 ]]; then
    echo -e "${YELLOW}需要安装缺失的命令: ${missing_commands[*]}${NC}"
fi

# 测试6: 测试下载主脚本
echo -e "${BLUE}测试6: 测试下载主脚本${NC}"
temp_file="/tmp/hy2-manager-test.sh"
if curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/hy2-manager.sh -o "$temp_file"; then
    if [[ -f "$temp_file" ]] && [[ -s "$temp_file" ]]; then
        echo -e "${GREEN}✓ 主脚本下载成功${NC}"
        rm -f "$temp_file"
    else
        echo -e "${RED}✗ 主脚本下载失败或文件为空${NC}"
    fi
else
    echo -e "${RED}✗ 主脚本下载失败${NC}"
fi

# 测试7: 测试目录创建权限
echo -e "${BLUE}测试7: 测试目录创建权限${NC}"
test_dir="/opt/s-hy2-test"
if mkdir -p "$test_dir"; then
    echo -e "${GREEN}✓ 目录创建权限正常${NC}"
    rmdir "$test_dir"
else
    echo -e "${RED}✗ 目录创建权限不足${NC}"
fi

# 测试8: 测试符号链接创建权限
echo -e "${BLUE}测试8: 测试符号链接创建权限${NC}"
test_link="/usr/local/bin/s-hy2-test"
test_target="/tmp/test-target"
echo "test" > "$test_target"
if ln -sf "$test_target" "$test_link"; then
    echo -e "${GREEN}✓ 符号链接创建权限正常${NC}"
    rm -f "$test_link" "$test_target"
else
    echo -e "${RED}✗ 符号链接创建权限不足${NC}"
fi

echo ""
echo -e "${CYAN}测试完成!${NC}"
echo ""
echo -e "${YELLOW}如果所有测试都通过，可以运行以下命令安装:${NC}"
echo ""
echo -e "${GREEN}简化版安装 (推荐):${NC}"
echo "curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install-simple.sh | sudo bash"
echo ""
echo -e "${GREEN}完整版安装:${NC}"
echo "curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash"
echo ""
echo -e "${GREEN}调试模式安装:${NC}"
echo "curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash -s -- --debug"
echo ""
