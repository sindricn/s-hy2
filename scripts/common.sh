#!/bin/bash

# 公共函数库 - 统一错误处理和日志记录
# 为所有脚本提供标准化的错误处理、日志记录和工具函数

# 严格错误处理
set -euo pipefail

# 全局变量
readonly SCRIPT_NAME="${0##*/}"
readonly LOG_DIR="/var/log/s-hy2"
readonly LOG_FILE="$LOG_DIR/s-hy2.log"
readonly PID_FILE="/var/run/s-hy2.pid"

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 日志级别
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# 当前日志级别 (默认为 INFO)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# 初始化日志系统
init_logging() {
    # 创建日志目录
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" || {
            echo "警告: 无法创建日志目录 $LOG_DIR" >&2
            return 1
        }
    fi

    # 设置日志文件权限
    if [[ -f "$LOG_FILE" ]]; then
        chmod 644 "$LOG_FILE"
    else
        touch "$LOG_FILE" && chmod 644 "$LOG_FILE"
    fi
}

# 统一的日志记录函数
log_message() {
    local level="$1"
    local level_num="$2"
    local color="$3"
    shift 3
    local message="$*"

    # 检查日志级别
    if [[ $level_num -lt $LOG_LEVEL ]]; then
        return 0
    fi

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # 控制台输出（带颜色）
    echo -e "${color}[${level}]${NC} $message" >&2

    # 文件输出（无颜色）
    if [[ -w "$LOG_FILE" ]] 2>/dev/null; then
        echo "[$timestamp] [$SCRIPT_NAME:$$] [$level] $message" >> "$LOG_FILE"
    fi
}

# 各级别日志函数
log_debug() {
    log_message "DEBUG" $LOG_LEVEL_DEBUG "$CYAN" "$@"
}

log_info() {
    log_message "INFO" $LOG_LEVEL_INFO "$BLUE" "$@"
}

log_warn() {
    log_message "WARN" $LOG_LEVEL_WARN "$YELLOW" "$@"
}

log_error() {
    log_message "ERROR" $LOG_LEVEL_ERROR "$RED" "$@"
}

log_fatal() {
    log_message "FATAL" $LOG_LEVEL_FATAL "$RED" "$@"
}

log_success() {
    log_message "SUCCESS" $LOG_LEVEL_INFO "$GREEN" "$@"
}

# 错误处理函数
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"

    log_error "$message"

    # 执行清理
    if command -v cleanup >/dev/null 2>&1; then
        cleanup "$exit_code"
    fi

    exit "$exit_code"
}

# 设置错误陷阱
setup_error_handling() {
    # 捕获各种信号
    trap 'handle_error $? $LINENO' ERR
    trap 'handle_signal INT "中断信号"' INT
    trap 'handle_signal TERM "终止信号"' TERM
    trap 'handle_signal HUP "挂起信号"' HUP
}

# 错误处理器
handle_error() {
    local exit_code=$1
    local line_number=$2

    log_error "脚本执行失败: 退出码 $exit_code, 行号 $line_number"

    # 显示调用栈
    local i=0
    while [[ ${FUNCNAME[$i]} ]]; do
        log_debug "调用栈 $i: ${FUNCNAME[$i]} (${BASH_SOURCE[$i]}:${BASH_LINENO[$i]})"
        ((i++))
    done

    # 执行清理
    if command -v cleanup >/dev/null 2>&1; then
        cleanup "$exit_code"
    fi

    exit "$exit_code"
}

# 信号处理器
handle_signal() {
    local signal="$1"
    local description="$2"

    log_info "接收到 $description ($signal), 正在清理..."

    # 执行清理
    if command -v cleanup >/dev/null 2>&1; then
        cleanup 130
    fi

    exit 130
}

# 默认清理函数
cleanup() {
    local exit_code="${1:-0}"

    log_debug "执行清理操作 (退出码: $exit_code)"

    # 清理临时文件
    if [[ -n "${TEMP_FILES:-}" ]]; then
        for temp_file in $TEMP_FILES; do
            if [[ -f "$temp_file" ]]; then
                rm -f "$temp_file"
                log_debug "删除临时文件: $temp_file"
            fi
        done
    fi

    # 清理临时目录
    if [[ -n "${TEMP_DIRS:-}" ]]; then
        for temp_dir in $TEMP_DIRS; do
            if [[ -d "$temp_dir" ]]; then
                rm -rf "$temp_dir"
                log_debug "删除临时目录: $temp_dir"
            fi
        done
    fi

    # 清理进程文件
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi
}

# 创建安全临时文件
create_temp_file() {
    local temp_file
    temp_file=$(mktemp)
    chmod 600 "$temp_file"

    # 添加到清理列表
    TEMP_FILES="${TEMP_FILES:-} $temp_file"

    echo "$temp_file"
}

# 创建安全临时目录
create_temp_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)
    chmod 700 "$temp_dir"

    # 添加到清理列表
    TEMP_DIRS="${TEMP_DIRS:-} $temp_dir"

    echo "$temp_dir"
}

# 检查命令是否存在
require_command() {
    local cmd="$1"
    local package="${2:-$cmd}"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        error_exit "缺少必要的命令: $cmd (请安装 $package)"
    fi
}

# 检查文件是否可读
require_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        error_exit "文件不存在: $file"
    fi

    if [[ ! -r "$file" ]]; then
        error_exit "文件不可读: $file"
    fi
}

# 检查目录是否可写
require_writable_dir() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        error_exit "目录不存在: $dir"
    fi

    if [[ ! -w "$dir" ]]; then
        error_exit "目录不可写: $dir"
    fi
}

# 检查root权限
require_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "此脚本需要root权限运行"
    fi
}

# 等待用户确认
wait_for_user() {
    echo ""
    read -p "按回车键继续..." -r
}

# 显示进度条
show_progress() {
    local current="$1"
    local total="$2"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))

    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%$((width - completed))s" | tr ' ' '-'
    printf "] %d%% (%d/%d)" "$percentage" "$current" "$total"
}

# 并发控制
init_semaphore() {
    local max_jobs="$1"
    local semaphore_pipe="/tmp/semaphore.$$"

    mkfifo "$semaphore_pipe"
    exec 3<>"$semaphore_pipe"

    for ((i=0; i<max_jobs; i++)); do
        echo "token" >&3
    done

    # 添加到清理列表
    TEMP_FILES="${TEMP_FILES:-} $semaphore_pipe"
}

acquire_semaphore() {
    read -u 3
}

release_semaphore() {
    echo "token" >&3
}

# 网络连接检查
check_internet_connection() {
    local test_urls=(
        "https://www.google.com"
        "https://github.com"
        "https://www.cloudflare.com"
    )

    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 5 --max-time 10 "$url" >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

# 导出函数供其他脚本使用
export -f init_logging
export -f log_debug log_info log_warn log_error log_fatal log_success
export -f error_exit setup_error_handling cleanup
export -f create_temp_file create_temp_dir
export -f require_command require_file require_writable_dir require_root
export -f wait_for_user show_progress
export -f init_semaphore acquire_semaphore release_semaphore
export -f check_internet_connection

# 自动初始化
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # 被作为模块导入时自动初始化
    init_logging
    setup_error_handling
fi