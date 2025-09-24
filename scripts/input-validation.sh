#!/bin/bash

# 输入验证安全模块
# 防止命令注入和恶意输入

# 严格错误处理
set -euo pipefail

# 安全的域名验证
validate_domain_secure() {
    local domain="$1"
    local max_length=253

    # 长度检查
    if [[ ${#domain} -gt $max_length ]]; then
        echo "域名长度超过限制 ($max_length 字符)" >&2
        return 1
    fi

    # 基本字符检查 - 只允许字母、数字、点和连字符
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        echo "域名包含非法字符" >&2
        return 1
    fi

    # 标准域名格式验证
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        echo "域名格式不正确" >&2
        return 1
    fi

    # 防止特殊字符注入
    if [[ "$domain" == *'$()'* ]] || [[ "$domain" == *'`'* ]] || [[ "$domain" == *';'* ]] || [[ "$domain" == *'&&'* ]] || [[ "$domain" == *'||'* ]]; then
        echo "域名包含危险字符" >&2
        return 1
    fi

    return 0
}

# 安全的邮箱验证
validate_email_secure() {
    local email="$1"
    local max_length=254

    # 长度检查
    if [[ ${#email} -gt $max_length ]]; then
        echo "邮箱长度超过限制 ($max_length 字符)" >&2
        return 1
    fi

    # 基本字符检查
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "邮箱格式不正确" >&2
        return 1
    fi

    # 防止命令注入
    if [[ "$email" == *'$()'* ]] || [[ "$email" == *'`'* ]] || [[ "$email" == *';'* ]] || [[ "$email" == *'&&'* ]] || [[ "$email" == *'||'* ]]; then
        echo "邮箱包含危险字符" >&2
        return 1
    fi

    return 0
}

# 安全的端口验证
validate_port_secure() {
    local port="$1"

    # 检查是否为纯数字
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "端口必须为数字" >&2
        return 1
    fi

    # 端口范围检查
    if [[ $port -lt 1 ]] || [[ $port -gt 65535 ]]; then
        echo "端口范围必须在 1-65535 之间" >&2
        return 1
    fi

    return 0
}

# 安全的密码验证
validate_password_secure() {
    local password="$1"
    local min_length=8
    local max_length=128

    # 长度检查
    if [[ ${#password} -lt $min_length ]]; then
        echo "密码长度至少需要 $min_length 字符" >&2
        return 1
    fi

    if [[ ${#password} -gt $max_length ]]; then
        echo "密码长度不能超过 $max_length 字符" >&2
        return 1
    fi

    # 防止命令注入字符
    if [[ "$password" == *'$()'* ]] || [[ "$password" == *'`'* ]] || [[ "$password" == *';'* ]] || [[ "$password" == *'&&'* ]] || [[ "$password" == *'||'* ]]; then
        echo "密码包含危险字符" >&2
        return 1
    fi

    return 0
}

# 安全的数字输入验证
validate_number_secure() {
    local number="$1"
    local min_val="${2:-0}"
    local max_val="${3:-999999}"

    # 检查是否为纯数字
    if [[ ! "$number" =~ ^[0-9]+$ ]]; then
        echo "输入必须为数字" >&2
        return 1
    fi

    # 范围检查
    if [[ $number -lt $min_val ]] || [[ $number -gt $max_val ]]; then
        echo "数字范围必须在 $min_val-$max_val 之间" >&2
        return 1
    fi

    return 0
}

# 安全的文件路径验证
validate_filepath_secure() {
    local filepath="$1"

    # 防止路径遍历攻击
    if [[ "$filepath" == *'..'* ]] || [[ "$filepath" == *'//'* ]]; then
        echo "文件路径包含危险字符" >&2
        return 1
    fi

    # 防止命令注入
    if [[ "$filepath" == *'$()'* ]] || [[ "$filepath" == *'`'* ]] || [[ "$filepath" == *';'* ]] || [[ "$filepath" == *'&&'* ]] || [[ "$filepath" == *'||'* ]]; then
        echo "文件路径包含危险字符" >&2
        return 1
    fi

    # 检查路径长度
    if [[ ${#filepath} -gt 4096 ]]; then
        echo "文件路径过长" >&2
        return 1
    fi

    return 0
}

# 安全的用户输入读取函数
read_input_secure() {
    local prompt="$1"
    local validator="$2"
    local max_attempts=3
    local attempt=1
    local input

    while [[ $attempt -le $max_attempts ]]; do
        echo -n "$prompt: "
        read -r input

        # 空输入检查
        if [[ -z "$input" ]]; then
            echo "输入不能为空" >&2
            ((attempt++))
            continue
        fi

        # 调用验证函数
        if "$validator" "$input"; then
            echo "$input"
            return 0
        fi

        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            echo "请重新输入 (剩余尝试次数: $((max_attempts - attempt + 1)))"
        fi
    done

    echo "输入验证失败，已达到最大尝试次数" >&2
    return 1
}

# 清理和转义用户输入
sanitize_input() {
    local input="$1"

    # 移除前后空白字符
    input=$(echo "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # 转义特殊字符
    input=$(echo "$input" | sed 's/[`$();]/\\&/g')

    echo "$input"
}

# 安全的命令执行函数
execute_command_secure() {
    local cmd=("$@")

    # 记录命令执行日志
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行命令: ${cmd[*]}" >&2

    # 使用数组形式执行命令，防止命令注入
    "${cmd[@]}"
}

# 导出函数供其他脚本使用
export -f validate_domain_secure
export -f validate_email_secure
export -f validate_port_secure
export -f validate_password_secure
export -f validate_number_secure
export -f validate_filepath_secure
export -f read_input_secure
export -f sanitize_input
export -f execute_command_secure