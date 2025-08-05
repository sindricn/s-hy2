#!/bin/bash

# 交互检测测试脚本

echo "=== 交互检测测试 ==="
echo ""

echo "测试方法:"
echo "1. 直接运行: bash test-interactive.sh"
echo "2. 管道运行: echo '' | bash test-interactive.sh"
echo "3. 重定向运行: bash test-interactive.sh < /dev/null"
echo ""

echo "当前检测结果:"

# 方法1: 检查标准输入是否为终端
if [[ -t 0 ]]; then
    echo "✓ 标准输入是终端 (交互模式)"
    INTERACTIVE_1=true
else
    echo "✗ 标准输入不是终端 (非交互模式)"
    INTERACTIVE_1=false
fi

# 方法2: 检查标准输出是否为终端
if [[ -t 1 ]]; then
    echo "✓ 标准输出是终端"
    INTERACTIVE_2=true
else
    echo "✗ 标准输出不是终端"
    INTERACTIVE_2=false
fi

# 方法3: 检查是否有 TERM 环境变量
if [[ -n "$TERM" ]]; then
    echo "✓ TERM 环境变量存在: $TERM"
    INTERACTIVE_3=true
else
    echo "✗ TERM 环境变量不存在"
    INTERACTIVE_3=false
fi

# 方法4: 检查 PS1 变量
if [[ -n "$PS1" ]]; then
    echo "✓ PS1 变量存在 (交互式 shell)"
    INTERACTIVE_4=true
else
    echo "✗ PS1 变量不存在 (非交互式 shell)"
    INTERACTIVE_4=false
fi

echo ""
echo "综合判断:"

# 使用最常用的方法
if [[ -t 0 ]]; then
    echo "🟢 交互模式 - 可以等待用户输入"
    echo ""
    echo -n "请输入 'y' 测试交互功能: "
    read -r response
    if [[ $response =~ ^[Yy]$ ]]; then
        echo "✓ 交互功能正常"
    else
        echo "✗ 用户输入: '$response'"
    fi
else
    echo "🔴 非交互模式 - 不应等待用户输入"
    echo "这通常发生在:"
    echo "  - 通过管道运行: curl ... | bash"
    echo "  - 重定向输入: bash script.sh < file"
    echo "  - 后台运行: bash script.sh &"
    echo "  - cron 任务中运行"
fi

echo ""
echo "环境信息:"
echo "  SHELL: $SHELL"
echo "  TERM: $TERM"
echo "  TTY: $(tty 2>/dev/null || echo 'not a tty')"
echo "  PPID: $PPID"
echo "  Parent process: $(ps -p $PPID -o comm= 2>/dev/null || echo 'unknown')"
