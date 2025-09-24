#!/bin/bash

# s-hy2 性能监控脚本
# 监控脚本执行性能和系统资源使用

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 加载性能工具
if [[ -f "$SCRIPT_DIR/performance-utils.sh" ]]; then
    source "$SCRIPT_DIR/performance-utils.sh"
fi

# 性能监控配置
MONITOR_LOG="$PROJECT_DIR/logs/performance.log"
BENCHMARK_LOG="$PROJECT_DIR/logs/benchmark.log"

# 创建日志目录
mkdir -p "$(dirname "$MONITOR_LOG")"

# 性能指标
declare -g -A PERFORMANCE_METRICS=()
declare -g -A FUNCTION_TIMINGS=()

# ========== 性能测量函数 ==========

# 开始计时
start_timer() {
    local timer_name="$1"
    PERFORMANCE_METRICS["${timer_name}_start"]=$(date +%s.%N)
}

# 结束计时
end_timer() {
    local timer_name="$1"
    local start_time="${PERFORMANCE_METRICS["${timer_name}_start"]:-}"

    if [[ -n "$start_time" ]]; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        PERFORMANCE_METRICS["${timer_name}_duration"]="$duration"
        echo "$duration"
    else
        echo "0"
    fi
}

# 记录函数执行时间
time_function() {
    local function_name="$1"
    shift

    start_timer "$function_name"
    "$function_name" "$@"
    local result=$?
    local duration
    duration=$(end_timer "$function_name")

    FUNCTION_TIMINGS["$function_name"]="$duration"
    log_performance "函数 $function_name 执行时间: ${duration}秒"

    return $result
}

# 性能日志
log_performance() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] $message" >> "$MONITOR_LOG"
}

# ========== 系统资源监控 ==========

# 获取当前系统资源使用情况
get_system_resources() {
    local cpu_usage memory_usage disk_usage load_avg

    # CPU使用率
    if command -v top >/dev/null 2>&1; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null || echo "0")
    else
        cpu_usage="unknown"
    fi

    # 内存使用率
    if command -v free >/dev/null 2>&1; then
        memory_usage=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}' 2>/dev/null || echo "0")
    else
        memory_usage="unknown"
    fi

    # 磁盘使用率
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo "0")

    # 系统负载
    if [[ -f /proc/loadavg ]]; then
        load_avg=$(cat /proc/loadavg | awk '{print $1}' 2>/dev/null || echo "0")
    else
        load_avg="unknown"
    fi

    cat << EOF
{
  "cpu_usage": "$cpu_usage",
  "memory_usage": "$memory_usage",
  "disk_usage": "$disk_usage",
  "load_average": "$load_avg",
  "timestamp": "$(date +%s)"
}
EOF
}

# 监控脚本执行过程
monitor_script_execution() {
    local script_name="$1"
    local script_path="$2"

    if [[ ! -f "$script_path" ]]; then
        log_performance "错误: 脚本不存在 - $script_path"
        return 1
    fi

    log_performance "开始监控脚本执行: $script_name"

    # 记录开始时的系统资源
    local start_resources
    start_resources=$(get_system_resources)

    # 执行脚本并计时
    start_timer "$script_name"

    local script_output exit_code
    script_output=$(timeout 300 bash "$script_path" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    local duration
    duration=$(end_timer "$script_name")

    # 记录结束时的系统资源
    local end_resources
    end_resources=$(get_system_resources)

    # 生成性能报告
    cat << EOF >> "$MONITOR_LOG"
脚本执行报告:
  脚本名称: $script_name
  执行时间: ${duration}秒
  退出代码: $exit_code
  开始资源: $start_resources
  结束资源: $end_resources
  输出大小: $(echo "$script_output" | wc -c)字节
EOF

    return $exit_code
}

# ========== 性能基准测试 ==========

# 运行性能基准测试
run_performance_benchmark() {
    local test_type="${1:-all}"

    log_performance "开始性能基准测试: $test_type"

    case "$test_type" in
        "disk")
            benchmark_disk_io
            ;;
        "network")
            benchmark_network
            ;;
        "scripts")
            benchmark_script_performance
            ;;
        "all")
            benchmark_disk_io
            benchmark_network
            benchmark_script_performance
            ;;
        *)
            log_performance "未知的基准测试类型: $test_type"
            return 1
            ;;
    esac
}

# 磁盘IO基准测试
benchmark_disk_io() {
    local test_file="/tmp/s-hy2-disk-test"
    local test_size="100M"

    log_performance "磁盘IO基准测试开始"

    # 写入测试
    start_timer "disk_write"
    if command -v dd >/dev/null 2>&1; then
        dd if=/dev/zero of="$test_file" bs=1M count=100 conv=fsync 2>/dev/null || true
    fi
    local write_time
    write_time=$(end_timer "disk_write")

    # 读取测试
    start_timer "disk_read"
    if [[ -f "$test_file" ]]; then
        dd if="$test_file" of=/dev/null bs=1M 2>/dev/null || true
    fi
    local read_time
    read_time=$(end_timer "disk_read")

    # 清理
    rm -f "$test_file" 2>/dev/null || true

    log_performance "磁盘IO测试结果: 写入=${write_time}秒, 读取=${read_time}秒"
}

# 网络基准测试
benchmark_network() {
    log_performance "网络基准测试开始"

    # DNS解析测试
    start_timer "dns_resolve"
    if nslookup google.com >/dev/null 2>&1; then
        local dns_status="success"
    else
        local dns_status="failed"
    fi
    local dns_time
    dns_time=$(end_timer "dns_resolve")

    # 连接测试
    start_timer "network_connection"
    if timeout 5 bash -c 'echo >/dev/tcp/8.8.8.8/53' 2>/dev/null; then
        local conn_status="success"
    else
        local conn_status="failed"
    fi
    local conn_time
    conn_time=$(end_timer "network_connection")

    log_performance "网络测试结果: DNS解析=${dns_time}秒($dns_status), 连接测试=${conn_time}秒($conn_status)"
}

# 脚本性能基准测试
benchmark_script_performance() {
    log_performance "脚本性能基准测试开始"

    local scripts_to_test=(
        "common.sh"
        "input-validation.sh"
        "config-loader.sh"
    )

    for script in "${scripts_to_test[@]}"; do
        local script_path="$SCRIPT_DIR/$script"

        if [[ -f "$script_path" ]]; then
            # 语法检查性能
            start_timer "syntax_check_$script"
            bash -n "$script_path" 2>/dev/null || true
            local syntax_time
            syntax_time=$(end_timer "syntax_check_$script")

            log_performance "脚本 $script 语法检查时间: ${syntax_time}秒"

            # 如果是库文件，测试加载时间
            if [[ "$script" == "common.sh" || "$script" == *.sh ]]; then
                start_timer "source_$script"
                (source "$script_path" 2>/dev/null || true) >/dev/null 2>&1
                local source_time
                source_time=$(end_timer "source_$script")

                log_performance "脚本 $script 加载时间: ${source_time}秒"
            fi
        fi
    done
}

# ========== 性能分析 ==========

# 分析性能瓶颈
analyze_performance_bottlenecks() {
    log_performance "开始性能瓶颈分析"

    # 分析函数执行时间
    if [[ ${#FUNCTION_TIMINGS[@]} -gt 0 ]]; then
        log_performance "函数执行时间分析:"

        # 排序并显示最慢的函数
        for func in "${!FUNCTION_TIMINGS[@]}"; do
            echo "${FUNCTION_TIMINGS[$func]} $func"
        done | sort -nr | head -10 | while read -r duration function; do
            log_performance "  慢函数: $function (${duration}秒)"
        done
    fi

    # 检查资源使用情况
    local current_resources
    current_resources=$(get_system_resources)
    log_performance "当前系统资源: $current_resources"

    # 建议优化措施
    suggest_optimizations
}

# 建议性能优化措施
suggest_optimizations() {
    local suggestions=()

    # 检查CPU使用率
    local cpu_usage
    cpu_usage=$(get_system_resources | grep -o '"cpu_usage": "[^"]*"' | cut -d'"' -f4 | sed 's/%//')

    if [[ "$cpu_usage" != "unknown" && $(echo "$cpu_usage > 80" | bc -l 2>/dev/null) == "1" ]]; then
        suggestions+=("CPU使用率过高($cpu_usage%)，考虑减少并发操作")
    fi

    # 检查内存使用率
    local memory_usage
    memory_usage=$(get_system_resources | grep -o '"memory_usage": "[^"]*"' | cut -d'"' -f4)

    if [[ "$memory_usage" != "unknown" && $(echo "$memory_usage > 90" | bc -l 2>/dev/null) == "1" ]]; then
        suggestions+=("内存使用率过高($memory_usage%)，考虑优化内存使用")
    fi

    # 输出建议
    if [[ ${#suggestions[@]} -gt 0 ]]; then
        log_performance "性能优化建议:"
        for suggestion in "${suggestions[@]}"; do
            log_performance "  - $suggestion"
        done
    else
        log_performance "系统性能正常，无特别优化建议"
    fi
}

# ========== 报告生成 ==========

# 生成性能报告
generate_performance_report() {
    local report_file="${1:-$PROJECT_DIR/logs/performance-report.html}"

    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>s-hy2 性能监控报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        .header { text-align: center; color: #333; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { background: #f8f9fa; padding: 15px; border-radius: 6px; border-left: 4px solid #007bff; }
        .metric-value { font-size: 1.5em; font-weight: bold; }
        .metric-label { color: #666; }
        .chart { margin: 20px 0; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 4px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 s-hy2 性能监控报告</h1>
            <p>生成时间: $(date)</p>
        </div>

        <div class="metrics">
            <div class="metric">
                <div class="metric-value">$(get_system_info_cached "cpu_count")</div>
                <div class="metric-label">CPU核心数</div>
            </div>
            <div class="metric">
                <div class="metric-value">$(get_system_info_cached "memory_total")MB</div>
                <div class="metric-label">总内存</div>
            </div>
            <div class="metric">
                <div class="metric-value">$(get_system_info_cached "disk_space")</div>
                <div class="metric-label">可用磁盘空间</div>
            </div>
        </div>

        <h2>📈 性能指标</h2>
        <pre>
$(get_system_resources)
        </pre>

        <h2>🔧 性能建议</h2>
        <pre>
$(suggest_optimizations 2>&1)
        </pre>

        <h2>📝 详细日志</h2>
        <pre>
$(tail -50 "$MONITOR_LOG" 2>/dev/null || echo "暂无日志数据")
        </pre>
    </div>
</body>
</html>
EOF

    log_performance "性能报告已生成: $report_file"
}

# ========== 主函数 ==========

# 主监控函数
main() {
    local action="${1:-monitor}"

    case "$action" in
        "monitor")
            log_performance "开始性能监控"
            analyze_performance_bottlenecks
            ;;
        "benchmark")
            run_performance_benchmark "${2:-all}"
            ;;
        "report")
            generate_performance_report "$2"
            ;;
        "script")
            if [[ -n "${2:-}" ]]; then
                monitor_script_execution "$(basename "$2")" "$2"
            else
                echo "用法: $0 script <script_path>"
                return 1
            fi
            ;;
        *)
            echo "用法: $0 {monitor|benchmark|report|script}"
            echo "  monitor     - 运行性能监控"
            echo "  benchmark   - 运行性能基准测试"
            echo "  report      - 生成性能报告"
            echo "  script      - 监控特定脚本执行"
            return 1
            ;;
    esac
}

# 如果直接运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi