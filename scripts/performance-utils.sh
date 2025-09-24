#!/bin/bash

# 性能优化工具库
# 提供缓存、批处理和优化的系统调用

set -euo pipefail

# 性能缓存
declare -g -A PERFORMANCE_CACHE=()
declare -g -A CACHE_TIMESTAMPS=()
declare -g CACHE_TTL=300  # 5分钟缓存过期

# 批处理命令队列
declare -g -a BATCH_COMMANDS=()
declare -g BATCH_SIZE=10

# 系统信息缓存
declare -g -A SYSTEM_INFO_CACHE=()

# ========== 缓存管理 ==========

# 获取缓存键
get_cache_key() {
    local prefix="$1"
    shift
    echo "$prefix:$(printf '%s:' "$@" | sed 's/:$//')"
}

# 检查缓存是否有效
is_cache_valid() {
    local key="$1"
    local current_time=$(date +%s)
    local cache_time="${CACHE_TIMESTAMPS[$key]:-0}"

    [[ $((current_time - cache_time)) -lt $CACHE_TTL ]]
}

# 设置缓存
set_cache() {
    local key="$1"
    local value="$2"

    PERFORMANCE_CACHE["$key"]="$value"
    CACHE_TIMESTAMPS["$key"]=$(date +%s)
}

# 获取缓存
get_cache() {
    local key="$1"

    if [[ -n "${PERFORMANCE_CACHE[$key]:-}" ]] && is_cache_valid "$key"; then
        echo "${PERFORMANCE_CACHE[$key]}"
        return 0
    else
        return 1
    fi
}

# 清理过期缓存
cleanup_cache() {
    local current_time=$(date +%s)

    for key in "${!CACHE_TIMESTAMPS[@]}"; do
        local cache_time="${CACHE_TIMESTAMPS[$key]}"
        if [[ $((current_time - cache_time)) -ge $CACHE_TTL ]]; then
            unset PERFORMANCE_CACHE["$key"]
            unset CACHE_TIMESTAMPS["$key"]
        fi
    done
}

# ========== 系统信息缓存 ==========

# 获取系统信息（缓存版本）
get_system_info_cached() {
    local info_type="$1"
    local cache_key="system_info:$info_type"

    if get_cache "$cache_key" >/dev/null; then
        get_cache "$cache_key"
        return 0
    fi

    local value
    case "$info_type" in
        "os_release")
            if [[ -f /etc/os-release ]]; then
                value=$(cat /etc/os-release)
            else
                value="unknown"
            fi
            ;;
        "cpu_count")
            value=$(nproc 2>/dev/null || echo "1")
            ;;
        "memory_total")
            value=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0")
            ;;
        "disk_space")
            value=$(df -h / 2>/dev/null | awk 'NR==2 {print $4}' || echo "unknown")
            ;;
        "kernel_version")
            value=$(uname -r 2>/dev/null || echo "unknown")
            ;;
        *)
            value="unknown"
            ;;
    esac

    set_cache "$cache_key" "$value"
    echo "$value"
}

# ========== 网络检查优化 ==========

# 批量端口检查
check_ports_batch() {
    local ports=("$@")
    local results=()

    # 使用ss命令批量检查（比多次netstat快）
    if command -v ss >/dev/null; then
        local listening_ports
        listening_ports=$(ss -tuln 2>/dev/null | awk '{print $5}' | grep -oE '[0-9]+$' | sort -u)

        for port in "${ports[@]}"; do
            if echo "$listening_ports" | grep -q "^$port$"; then
                results+=("$port:used")
            else
                results+=("$port:free")
            fi
        done
    else
        # 降级到传统方法
        for port in "${ports[@]}"; do
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                results+=("$port:used")
            else
                results+=("$port:free")
            fi
        done
    fi

    printf '%s\n' "${results[@]}"
}

# ========== 文件操作优化 ==========

# 大文件处理优化
process_large_file() {
    local file_path="$1"
    local operation="$2"
    local chunk_size="${3:-1048576}"  # 1MB 默认块大小

    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    case "$operation" in
        "checksum")
            # 使用块读取计算大文件校验和
            if command -v sha256sum >/dev/null; then
                sha256sum "$file_path" | cut -d' ' -f1
            else
                # 降级方案
                openssl dgst -sha256 "$file_path" | cut -d' ' -f2
            fi
            ;;
        "line_count")
            # 优化的行数统计
            wc -l < "$file_path"
            ;;
        "size")
            # 获取文件大小
            stat --format='%s' "$file_path" 2>/dev/null || \
            stat -f%z "$file_path" 2>/dev/null || \
            wc -c < "$file_path"
            ;;
        *)
            return 1
            ;;
    esac
}

# 批量文件操作
batch_file_operations() {
    local operation="$1"
    shift
    local files=("$@")

    case "$operation" in
        "exists")
            for file in "${files[@]}"; do
                [[ -f "$file" ]] && echo "$file:exists" || echo "$file:missing"
            done
            ;;
        "size")
            for file in "${files[@]}"; do
                if [[ -f "$file" ]]; then
                    local size
                    size=$(process_large_file "$file" "size")
                    echo "$file:$size"
                else
                    echo "$file:missing"
                fi
            done
            ;;
        "permissions")
            stat --format='%n:%a' "${files[@]}" 2>/dev/null || \
            for file in "${files[@]}"; do
                if [[ -f "$file" ]]; then
                    local perms
                    perms=$(stat -f%Mp%Lp "$file" 2>/dev/null || echo "unknown")
                    echo "$file:$perms"
                else
                    echo "$file:missing"
                fi
            done
            ;;
    esac
}

# ========== 进程管理优化 ==========

# 批量进程检查
check_processes_batch() {
    local process_names=("$@")
    local results=()

    # 一次性获取所有进程信息
    local all_processes
    all_processes=$(ps aux 2>/dev/null | awk '{print $11}' | sort -u)

    for process in "${process_names[@]}"; do
        if echo "$all_processes" | grep -q "$process"; then
            results+=("$process:running")
        else
            results+=("$process:stopped")
        fi
    done

    printf '%s\n' "${results[@]}"
}

# ========== 网络连接优化 ==========

# 优化的连接测试
test_connection_optimized() {
    local host="$1"
    local port="${2:-80}"
    local timeout="${3:-5}"

    # 使用缓存避免重复测试
    local cache_key
    cache_key=$(get_cache_key "connection" "$host" "$port")

    if get_cache "$cache_key" >/dev/null; then
        get_cache "$cache_key"
        return $?
    fi

    local result
    if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        result="success"
        set_cache "$cache_key" "$result"
        echo "$result"
        return 0
    else
        result="failed"
        set_cache "$cache_key" "$result"
        echo "$result"
        return 1
    fi
}

# ========== 命令批处理 ==========

# 添加命令到批处理队列
add_to_batch() {
    local command="$1"
    BATCH_COMMANDS+=("$command")

    # 自动执行批处理（当队列满时）
    if [[ ${#BATCH_COMMANDS[@]} -ge $BATCH_SIZE ]]; then
        execute_batch
    fi
}

# 执行批处理命令
execute_batch() {
    if [[ ${#BATCH_COMMANDS[@]} -eq 0 ]]; then
        return 0
    fi

    # 并行执行命令（限制并发数）
    local max_concurrent=4
    local concurrent=0

    for command in "${BATCH_COMMANDS[@]}"; do
        if [[ $concurrent -ge $max_concurrent ]]; then
            wait  # 等待一些任务完成
            concurrent=0
        fi

        eval "$command" &
        ((concurrent++))
    done

    wait  # 等待所有任务完成

    # 清空队列
    BATCH_COMMANDS=()
}

# 强制执行剩余批处理
flush_batch() {
    execute_batch
}

# ========== 配置文件优化 ==========

# 缓存配置解析
parse_config_cached() {
    local config_file="$1"
    local cache_key
    cache_key=$(get_cache_key "config" "$config_file")

    if get_cache "$cache_key" >/dev/null; then
        eval "$(get_cache "$cache_key")"
        return 0
    fi

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    local config_content
    config_content=$(grep -E '^[A-Z_]+=.*' "$config_file" | sed 's/^/export /')

    set_cache "$cache_key" "$config_content"
    eval "$config_content"
}

# ========== 日志优化 ==========

# 批量日志写入
declare -g -a LOG_BUFFER=()
declare -g LOG_BUFFER_SIZE=50

buffered_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    LOG_BUFFER+=("[$timestamp] [$level] $message")

    if [[ ${#LOG_BUFFER[@]} -ge $LOG_BUFFER_SIZE ]]; then
        flush_log_buffer
    fi
}

flush_log_buffer() {
    if [[ ${#LOG_BUFFER[@]} -eq 0 ]]; then
        return 0
    fi

    local log_file="${LOG_FILE:-/tmp/s-hy2.log}"

    # 批量写入日志
    printf '%s\n' "${LOG_BUFFER[@]}" >> "$log_file"

    # 清空缓冲区
    LOG_BUFFER=()
}

# ========== 清理和维护 ==========

# 性能统计
get_performance_stats() {
    cat << EOF
性能缓存统计:
- 缓存条目数: ${#PERFORMANCE_CACHE[@]}
- 批处理队列长度: ${#BATCH_COMMANDS[@]}
- 日志缓冲区大小: ${#LOG_BUFFER[@]}
- 缓存TTL: ${CACHE_TTL}秒

系统资源:
- CPU核心数: $(get_system_info_cached "cpu_count")
- 内存总量: $(get_system_info_cached "memory_total")MB
- 可用磁盘空间: $(get_system_info_cached "disk_space")
EOF
}

# 清理所有缓存和缓冲区
cleanup_performance() {
    flush_batch
    flush_log_buffer
    cleanup_cache

    PERFORMANCE_CACHE=()
    CACHE_TIMESTAMPS=()
    BATCH_COMMANDS=()
    LOG_BUFFER=()
}

# 设置性能参数
set_performance_config() {
    local cache_ttl="${1:-300}"
    local batch_size="${2:-10}"
    local log_buffer_size="${3:-50}"

    CACHE_TTL="$cache_ttl"
    BATCH_SIZE="$batch_size"
    LOG_BUFFER_SIZE="$log_buffer_size"
}

# 退出时清理
trap cleanup_performance EXIT