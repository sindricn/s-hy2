#!/bin/bash

# 配置加载器
# 统一的配置管理和环境设置

# 默认配置文件路径
DEFAULT_CONFIG_PATHS=(
    "$(dirname "${BASH_SOURCE[0]}")/../config/app.conf"
    "/etc/s-hy2/app.conf"
    "$HOME/.config/s-hy2/app.conf"
    "./config/app.conf"
)

# 已加载的配置文件标记
CONFIG_LOADED=${CONFIG_LOADED:-false}

# 加载配置文件
load_config() {
    if [[ "$CONFIG_LOADED" == "true" ]]; then
        return 0
    fi

    local config_file=""
    local custom_config="${1:-}"

    # 如果指定了自定义配置文件
    if [[ -n "$custom_config" ]]; then
        if [[ -f "$custom_config" ]]; then
            config_file="$custom_config"
        else
            echo "警告: 指定的配置文件不存在: $custom_config" >&2
            return 1
        fi
    else
        # 查找默认配置文件
        for path in "${DEFAULT_CONFIG_PATHS[@]}"; do
            if [[ -f "$path" ]]; then
                config_file="$path"
                break
            fi
        done
    fi

    if [[ -z "$config_file" ]]; then
        echo "警告: 未找到配置文件，使用默认设置" >&2
        setup_default_config
        return 1
    fi

    # 验证配置文件
    if ! validate_config_file "$config_file"; then
        echo "错误: 配置文件验证失败: $config_file" >&2
        return 1
    fi

    # 加载配置文件
    if source "$config_file"; then
        CONFIG_LOADED=true
        CONFIG_FILE_PATH="$config_file"
        echo "配置文件已加载: $config_file" >&2

        # 应用配置后处理
        apply_config_post_processing
        return 0
    else
        echo "错误: 无法加载配置文件: $config_file" >&2
        return 1
    fi
}

# 验证配置文件
validate_config_file() {
    local config_file="$1"

    # 检查文件是否可读
    if [[ ! -r "$config_file" ]]; then
        echo "配置文件不可读: $config_file" >&2
        return 1
    fi

    # 检查文件大小（防止恶意文件）
    local file_size
    file_size=$(stat -c%s "$config_file" 2>/dev/null || echo 0)
    if [[ $file_size -gt 65536 ]]; then  # 64KB
        echo "配置文件过大: $config_file" >&2
        return 1
    fi

    # 基本语法检查
    if ! bash -n "$config_file" >/dev/null 2>&1; then
        echo "配置文件语法错误: $config_file" >&2
        return 1
    fi

    # 检查危险命令
    if grep -qE '`|\$\(|\|\||&&|;|>|<|\||rm |dd |mkfs|fdisk' "$config_file"; then
        echo "配置文件包含危险命令: $config_file" >&2
        return 1
    fi

    return 0
}

# 设置默认配置
setup_default_config() {
    echo "使用默认配置设置..." >&2

    # 项目信息
    PROJECT_NAME=${PROJECT_NAME:-"s-hy2"}
    PROJECT_VERSION=${PROJECT_VERSION:-"1.1.2"}
    PROJECT_REPO_URL=${PROJECT_REPO_URL:-"https://github.com/sindricn/s-hy2"}
    PROJECT_RAW_URL=${PROJECT_RAW_URL:-"https://raw.githubusercontent.com/sindricn/s-hy2/main"}

    # 基本设置
    DEFAULT_LISTEN_PORT=${DEFAULT_LISTEN_PORT:-443}
    MAX_CONCURRENT_JOBS=${MAX_CONCURRENT_JOBS:-8}
    DEFAULT_DOWNLOAD_TIMEOUT=${DEFAULT_DOWNLOAD_TIMEOUT:-30}
    MAX_FILE_SIZE=${MAX_FILE_SIZE:-10485760}

    # 目录设置
    HYSTERIA_CONFIG_DIR=${HYSTERIA_CONFIG_DIR:-"/etc/hysteria"}
    HYSTERIA_LOG_DIR=${HYSTERIA_LOG_DIR:-"/var/log/hysteria"}
    BACKUP_DIR=${BACKUP_DIR:-"/var/backups/s-hy2"}

    # 安全设置
    ENABLE_SECURE_MODE=${ENABLE_SECURE_MODE:-true}
    ENABLE_INPUT_VALIDATION=${ENABLE_INPUT_VALIDATION:-true}
    ENABLE_DOWNLOAD_VERIFICATION=${ENABLE_DOWNLOAD_VERIFICATION:-true}

    # 日志设置
    LOG_LEVEL=${LOG_LEVEL:-1}
    ENABLE_FILE_LOGGING=${ENABLE_FILE_LOGGING:-true}

    CONFIG_LOADED=true
}

# 配置后处理
apply_config_post_processing() {
    # 处理数组变量
    if [[ -n "${MASQUERADE_DOMAINS_STR:-}" ]]; then
        IFS=' ' read -ra MASQUERADE_DOMAINS <<< "$MASQUERADE_DOMAINS_STR"
    fi

    if [[ -n "${SUPPORTED_OS_STR:-}" ]]; then
        IFS=' ' read -ra SUPPORTED_OS <<< "$SUPPORTED_OS_STR"
    fi

    if [[ -n "${REQUIRED_COMMANDS_STR:-}" ]]; then
        IFS=' ' read -ra REQUIRED_COMMANDS <<< "$REQUIRED_COMMANDS_STR"
    fi

    # 验证关键配置
    validate_critical_config

    # 创建必要目录
    create_required_directories

    # 设置环境变量
    export PROJECT_NAME PROJECT_VERSION
    export HYSTERIA_CONFIG_DIR HYSTERIA_LOG_DIR
    export LOG_LEVEL ENABLE_SECURE_MODE
}

# 验证关键配置
validate_critical_config() {
    # 验证端口设置
    if [[ ! "$DEFAULT_LISTEN_PORT" =~ ^[0-9]+$ ]] ||
       [[ $DEFAULT_LISTEN_PORT -lt 1 ]] ||
       [[ $DEFAULT_LISTEN_PORT -gt 65535 ]]; then
        echo "警告: 默认端口设置无效，使用443" >&2
        DEFAULT_LISTEN_PORT=443
    fi

    # 验证并发数设置
    if [[ ! "$MAX_CONCURRENT_JOBS" =~ ^[0-9]+$ ]] ||
       [[ $MAX_CONCURRENT_JOBS -lt 1 ]] ||
       [[ $MAX_CONCURRENT_JOBS -gt 50 ]]; then
        echo "警告: 并发数设置无效，使用8" >&2
        MAX_CONCURRENT_JOBS=8
    fi

    # 验证日志级别
    if [[ ! "$LOG_LEVEL" =~ ^[0-4]$ ]]; then
        echo "警告: 日志级别无效，使用默认级别1" >&2
        LOG_LEVEL=1
    fi
}

# 创建必要目录
create_required_directories() {
    local dirs=(
        "$HYSTERIA_CONFIG_DIR"
        "$HYSTERIA_LOG_DIR"
        "$BACKUP_DIR"
        "${CERT_DIR:-$HYSTERIA_CONFIG_DIR/certs}"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if mkdir -p "$dir" 2>/dev/null; then
                echo "创建目录: $dir" >&2
            else
                echo "警告: 无法创建目录: $dir" >&2
            fi
        fi
    done
}

# 获取配置值
get_config() {
    local key="$1"
    local default_value="${2:-}"

    # 确保配置已加载
    if [[ "$CONFIG_LOADED" != "true" ]]; then
        load_config
    fi

    # 获取配置值
    local value="${!key:-$default_value}"
    echo "$value"
}

# 设置配置值
set_config() {
    local key="$1"
    local value="$2"

    # 动态设置变量
    declare -g "$key"="$value"

    # 如果有配置文件，可以选择性地写回
    if [[ -n "${CONFIG_FILE_PATH:-}" ]] && [[ "$ENABLE_CONFIG_PERSISTENCE" == "true" ]]; then
        update_config_file "$key" "$value"
    fi
}

# 更新配置文件
update_config_file() {
    local key="$1"
    local value="$2"
    local config_file="${CONFIG_FILE_PATH:-}"

    if [[ -z "$config_file" ]] || [[ ! -w "$config_file" ]]; then
        return 1
    fi

    # 创建备份
    cp "$config_file" "${config_file}.bak.$(date +%s)"

    # 更新配置
    if grep -q "^$key=" "$config_file"; then
        sed -i "s/^$key=.*/$key=\"$value\"/" "$config_file"
    else
        echo "$key=\"$value\"" >> "$config_file"
    fi
}

# 显示当前配置
show_config() {
    if [[ "$CONFIG_LOADED" != "true" ]]; then
        load_config
    fi

    echo "=== 当前配置 ==="
    echo "配置文件: ${CONFIG_FILE_PATH:-"默认设置"}"
    echo "项目名称: $PROJECT_NAME"
    echo "项目版本: $PROJECT_VERSION"
    echo "默认端口: $DEFAULT_LISTEN_PORT"
    echo "最大并发: $MAX_CONCURRENT_JOBS"
    echo "安全模式: $ENABLE_SECURE_MODE"
    echo "日志级别: $LOG_LEVEL"
    echo "配置目录: $HYSTERIA_CONFIG_DIR"
    echo "日志目录: $HYSTERIA_LOG_DIR"
}

# 导出函数
export -f load_config get_config set_config show_config

# 如果作为模块导入，自动加载配置
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    load_config
fi