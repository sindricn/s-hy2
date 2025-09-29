#!/bin/bash

# 公共函数库 - 统一错误处理和日志记录
# 为所有脚本提供标准化的错误处理、日志记录和工具函数

# 适度的错误处理 (不使用 -e 避免意外退出)
set -uo pipefail

# 全局变量 (防止重复定义)
if [[ -z "${SCRIPT_NAME:-}" ]]; then
    readonly SCRIPT_NAME="${0##*/}"
fi
if [[ -z "${LOG_DIR:-}" ]]; then
    readonly LOG_DIR="/var/log/s-hy2"
fi
if [[ -z "${LOG_FILE:-}" ]]; then
    readonly LOG_FILE="$LOG_DIR/s-hy2.log"
fi
if [[ -z "${PID_FILE:-}" ]]; then
    readonly PID_FILE="/var/run/s-hy2.pid"
fi

# 颜色定义 (防止与主脚本冲突)
if [[ -z "${RED:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'
fi

# 日志级别 (防止重复定义)
if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then
    readonly LOG_LEVEL_DEBUG=0
    readonly LOG_LEVEL_INFO=1
    readonly LOG_LEVEL_WARN=2
    readonly LOG_LEVEL_ERROR=3
    readonly LOG_LEVEL_FATAL=4
fi

# 当前日志级别 (默认为 INFO)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# 初始化日志系统 - 智能降级版本
init_logging() {
    # 尝试创建系统日志目录
    if [[ $EUID -eq 0 ]] && [[ ! -d "$LOG_DIR" ]]; then
        if mkdir -p "$LOG_DIR" 2>/dev/null; then
            # 成功创建系统日志目录
            :
        else
            # Root用户但无法创建系统目录，降级到/tmp
            LOG_DIR="/tmp/s-hy2"
            LOG_FILE="$LOG_DIR/s-hy2.log"
            mkdir -p "$LOG_DIR" 2>/dev/null
        fi
    elif [[ $EUID -ne 0 ]]; then
        # 非Root用户，使用用户目录
        local user_log_dir="${HOME}/.cache/s-hy2"
        if mkdir -p "$user_log_dir" 2>/dev/null; then
            LOG_DIR="$user_log_dir"
            LOG_FILE="$LOG_DIR/s-hy2.log"
        else
            # 降级到临时目录
            LOG_DIR="/tmp/s-hy2-$(whoami)"
            LOG_FILE="$LOG_DIR/s-hy2.log"
            mkdir -p "$LOG_DIR" 2>/dev/null
        fi
    fi

    # 设置日志文件权限
    if [[ -f "$LOG_FILE" ]]; then
        chmod 644 "$LOG_FILE" 2>/dev/null
    else
        touch "$LOG_FILE" 2>/dev/null && chmod 644 "$LOG_FILE" 2>/dev/null
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

# 标准化错误处理函数
setup_error_handling() {
    # 统一的错误处理设置
    set -uo pipefail

    # 捕获ERR信号并调用错误处理函数
    trap 'handle_script_error $? $LINENO "$BASH_COMMAND" "${FUNCNAME[*]:-main}"' ERR
}

# 错误处理函数
handle_script_error() {
    local exit_code=$1
    local line_number=$2
    local command=$3
    local function_stack=$4

    log_error "脚本执行错误:"
    log_error "  文件: ${BASH_SOURCE[1]:-$0}"
    log_error "  行号: $line_number"
    log_error "  命令: $command"
    log_error "  函数栈: $function_stack"
    log_error "  退出码: $exit_code"

    # 在某些情况下不退出，让调用者处理
    if [[ "${CONTINUE_ON_ERROR:-false}" == "true" ]]; then
        return $exit_code
    fi

    exit $exit_code
}

# 安全执行函数 - 用于可能失败的操作
safe_execute() {
    local command_description="$1"
    shift

    log_info "执行: $command_description"

    if "$@"; then
        log_success "$command_description - 成功"
        return 0
    else
        local exit_code=$?
        log_error "$command_description - 失败 (退出码: $exit_code)"
        return $exit_code
    fi
}

# 标准化脚本初始化函数
init_script() {
    local script_description="${1:-Shell脚本}"

    # 设置错误处理
    setup_error_handling

    # 初始化日志系统
    init_logging

    log_debug "开始执行: $script_description"
    log_debug "脚本路径: ${BASH_SOURCE[1]:-$0}"
    log_debug "执行用户: $(whoami)"
    log_debug "工作目录: $(pwd)"
}

# 等待用户确认
wait_for_user() {
    echo ""
    read -p "按回车键继续..." -r
}

# 检查Hysteria2是否已安装和配置
check_hysteria2_ready() {
    local check_type="${1:-install}"  # install, config, service

    case $check_type in
        "install")
            if ! command -v hysteria >/dev/null 2>&1; then
                log_warn "Hysteria2 未安装"
                echo ""
                echo -e "${YELLOW}提示：${NC}请先安装 Hysteria2"
                echo "  返回主菜单选择 '1. 安装 Hysteria2'"
                echo ""
                wait_for_user
                return 1
            fi
            ;;
        "config")
            if [[ ! -f "/etc/hysteria/config.yaml" ]]; then
                log_warn "Hysteria2 配置文件不存在"
                echo ""
                echo -e "${YELLOW}提示：${NC}请先配置 Hysteria2"
                echo "  1. 返回主菜单选择 '2. 快速配置' 或 '3. 手动配置'"
                echo "  2. 如未安装，请先选择 '1. 安装 Hysteria2'"
                echo ""
                wait_for_user
                return 1
            fi
            ;;
        "service")
            if ! systemctl is-enabled hysteria-server >/dev/null 2>&1; then
                log_warn "Hysteria2 服务未启用"
                echo ""
                echo -e "${YELLOW}提示：${NC}请先启用服务"
                echo "  返回主菜单选择 '7. 服务管理'"
                echo ""
                wait_for_user
                return 1
            fi
            ;;
    esac

    return 0
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

# ===== 用户友好提示函数 =====

# 标准化的操作提示
show_operation_result() {
    local operation="$1"
    local status="$2"  # success, error, warning, info
    local message="$3"

    case $status in
        "success")
            echo -e "${GREEN}✅ $operation 成功${NC}: $message"
            ;;
        "error")
            echo -e "${RED}❌ $operation 失败${NC}: $message"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $operation 警告${NC}: $message"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $operation 信息${NC}: $message"
            ;;
        *)
            echo "$operation: $message"
            ;;
    esac
}

# 标准化的冲突提示
show_conflict_prompt() {
    local item_type="$1"
    local existing_item="$2"
    local new_item="$3"

    echo ""
    echo -e "${YELLOW}⚠️  冲突检测 ⚠️${NC}"
    echo -e "${YELLOW}检测到现有的 ${item_type}: ${CYAN}$existing_item${NC}"
    echo -e "${YELLOW}正在尝试添加: ${CYAN}$new_item${NC}"
    echo ""
    echo -e "${BLUE}选择操作：${NC}"
    echo -e "${GREEN}1.${NC} 继续并覆盖现有项"
    echo -e "${RED}2.${NC} 取消操作"
    echo ""
}

# 标准化的确认提示
show_confirmation_prompt() {
    local action="$1"
    local target="$2"

    echo ""
    echo -e "${YELLOW}⚠️  确认操作 ⚠️${NC}"
    echo -e "${YELLOW}即将执行: ${CYAN}$action${NC}"
    echo -e "${YELLOW}目标: ${CYAN}$target${NC}"
    echo ""
    read -p "确认执行此操作？ [y/N]: " confirm
    [[ $confirm =~ ^[Yy]$ ]]
}

export -f show_operation_result show_conflict_prompt show_confirmation_prompt

# 自动初始化
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # 被作为模块导入时自动初始化
    init_logging
    setup_error_handling
fi