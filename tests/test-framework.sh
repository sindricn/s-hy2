#!/bin/bash

# s-hy2 测试框架
# 统一的测试执行和报告系统

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 测试配置
TEST_TIMEOUT=300  # 5分钟超时
MAX_PARALLEL_TESTS=4
TEST_LOG_DIR="$SCRIPT_DIR/logs"
TEST_REPORT_FILE="$TEST_LOG_DIR/test-report-$(date +%Y%m%d_%H%M%S).html"

# 创建测试日志目录
mkdir -p "$TEST_LOG_DIR"

# 颜色定义（支持非彩色终端）
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    readonly RED=$(tput setaf 1)
    readonly GREEN=$(tput setaf 2)
    readonly YELLOW=$(tput setaf 3)
    readonly BLUE=$(tput setaf 4)
    readonly CYAN=$(tput setaf 6)
    readonly BOLD=$(tput bold)
    readonly NC=$(tput sgr0)
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

# 测试统计
declare -g TOTAL_TESTS=0
declare -g PASSED_TESTS=0
declare -g FAILED_TESTS=0
declare -g SKIPPED_TESTS=0
declare -g START_TIME
declare -g -A TEST_RESULTS=()
declare -g -A TEST_DURATIONS=()

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_skip() {
    echo -e "${CYAN}[SKIP]${NC} $1" >&2
}

# 测试断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$not_expected" != "$actual" ]]; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  Not Expected: '$not_expected'"
        echo "  Actual:       '$actual'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String not found}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  String: '$haystack'"
        echo "  Should contain: '$needle'"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-File does not exist}"

    if [[ -f "$file_path" ]]; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  File: '$file_path'"
        return 1
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-Command failed}"

    if eval "$command" >/dev/null 2>&1; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  Command: '$command'"
        return 1
    fi
}

assert_command_failure() {
    local command="$1"
    local message="${2:-Command should have failed}"

    if ! eval "$command" >/dev/null 2>&1; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  Command: '$command'"
        return 1
    fi
}

# 运行单个测试
run_test() {
    local test_name="$1"
    local test_function="$2"
    local test_file="${3:-}"

    ((TOTAL_TESTS++))

    local test_start_time=$(date +%s.%N)
    local test_output
    local test_result=0

    echo -n "  Running $test_name... "

    # 捕获测试输出和结果
    if test_output=$(timeout "$TEST_TIMEOUT" bash -c "$test_function" 2>&1); then
        test_result=0
    else
        test_result=$?
    fi

    local test_end_time=$(date +%s.%N)
    local duration=$(echo "$test_end_time - $test_start_time" | bc -l 2>/dev/null || echo "0")
    TEST_DURATIONS["$test_name"]="$duration"

    if [[ $test_result -eq 0 ]]; then
        log_success "$test_name (${duration}s)"
        ((PASSED_TESTS++))
        TEST_RESULTS["$test_name"]="PASS"
    elif [[ $test_result -eq 124 ]]; then
        log_error "$test_name (TIMEOUT after ${TEST_TIMEOUT}s)"
        ((FAILED_TESTS++))
        TEST_RESULTS["$test_name"]="TIMEOUT"
    else
        log_error "$test_name (${duration}s)"
        ((FAILED_TESTS++))
        TEST_RESULTS["$test_name"]="FAIL"

        # 显示失败详情
        if [[ -n "$test_output" ]]; then
            echo "    Error output:" >&2
            echo "$test_output" | sed 's/^/      /' >&2
        fi
    fi
}

# 跳过测试
skip_test() {
    local test_name="$1"
    local reason="${2:-No reason provided}"

    ((TOTAL_TESTS++))
    ((SKIPPED_TESTS++))

    log_skip "$test_name - $reason"
    TEST_RESULTS["$test_name"]="SKIP"
}

# 运行测试套件
run_test_suite() {
    local suite_name="$1"
    local test_file="$2"

    log_info "Running test suite: $suite_name"

    if [[ ! -f "$test_file" ]]; then
        log_error "Test file not found: $test_file"
        return 1
    fi

    # 检查语法
    if ! bash -n "$test_file"; then
        log_error "Syntax error in test file: $test_file"
        return 1
    fi

    # 执行测试文件
    source "$test_file"

    echo ""
}

# 生成HTML测试报告
generate_html_report() {
    local report_file="$1"
    local end_time=$(date +%s.%N)
    local total_duration=$(echo "$end_time - $START_TIME" | bc -l 2>/dev/null || echo "0")

    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>s-hy2 测试报告</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { color: #333; margin-bottom: 10px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric { background: #f8f9fa; padding: 20px; border-radius: 6px; text-align: center; border-left: 4px solid #007bff; }
        .metric.pass { border-left-color: #28a745; }
        .metric.fail { border-left-color: #dc3545; }
        .metric.skip { border-left-color: #ffc107; }
        .metric-value { font-size: 2em; font-weight: bold; margin-bottom: 5px; }
        .metric-label { color: #666; font-size: 0.9em; }
        .test-list { margin-top: 30px; }
        .test-item { padding: 15px; margin-bottom: 10px; border-radius: 6px; display: flex; justify-content: space-between; align-items: center; }
        .test-pass { background-color: #d4edda; border-left: 4px solid #28a745; }
        .test-fail { background-color: #f8d7da; border-left: 4px solid #dc3545; }
        .test-skip { background-color: #fff3cd; border-left: 4px solid #ffc107; }
        .test-timeout { background-color: #f8d7da; border-left: 4px solid #6c757d; }
        .test-name { font-weight: 500; }
        .test-duration { font-size: 0.9em; color: #666; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; text-align: center; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 s-hy2 Hysteria2 测试报告</h1>
            <p>生成时间: $(date)</p>
            <p>总耗时: ${total_duration}秒</p>
        </div>

        <div class="summary">
            <div class="metric">
                <div class="metric-value">$TOTAL_TESTS</div>
                <div class="metric-label">总测试数</div>
            </div>
            <div class="metric pass">
                <div class="metric-value">$PASSED_TESTS</div>
                <div class="metric-label">通过</div>
            </div>
            <div class="metric fail">
                <div class="metric-value">$FAILED_TESTS</div>
                <div class="metric-label">失败</div>
            </div>
            <div class="metric skip">
                <div class="metric-value">$SKIPPED_TESTS</div>
                <div class="metric-label">跳过</div>
            </div>
        </div>

        <div class="test-list">
            <h3>测试详情</h3>
EOF

    # 添加测试结果
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$test_name]}"
        local duration="${TEST_DURATIONS[$test_name]:-0}"
        local css_class="test-pass"
        local icon="✅"

        case "$result" in
            "FAIL") css_class="test-fail"; icon="❌" ;;
            "SKIP") css_class="test-skip"; icon="⏭️" ;;
            "TIMEOUT") css_class="test-timeout"; icon="⏰" ;;
        esac

        cat >> "$report_file" << EOF
            <div class="test-item $css_class">
                <span class="test-name">$icon $test_name</span>
                <span class="test-duration">${duration}s</span>
            </div>
EOF
    done

    cat >> "$report_file" << EOF
        </div>

        <div class="footer">
            <p>📊 测试通过率: $(( PASSED_TESTS * 100 / (TOTAL_TESTS == 0 ? 1 : TOTAL_TESTS) ))%</p>
            <p>🔧 s-hy2 Hysteria2 自动化测试框架</p>
        </div>
    </div>
</body>
</html>
EOF

    log_info "HTML报告已生成: $report_file"
}

# 打印测试摘要
print_summary() {
    local end_time=$(date +%s.%N)
    local total_duration=$(echo "$end_time - $START_TIME" | bc -l 2>/dev/null || echo "0")

    echo ""
    echo "=========================================="
    echo "             测试结果摘要"
    echo "=========================================="
    echo ""
    echo "总测试数: $TOTAL_TESTS"
    echo "通过: ${GREEN}$PASSED_TESTS${NC}"
    echo "失败: ${RED}$FAILED_TESTS${NC}"
    echo "跳过: ${YELLOW}$SKIPPED_TESTS${NC}"
    echo "总耗时: ${total_duration}秒"
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✅ 所有测试通过！${NC}"
        return 0
    else
        echo -e "${RED}❌ 有 $FAILED_TESTS 个测试失败${NC}"
        return 1
    fi
}

# 清理测试环境
cleanup_test_env() {
    log_info "清理测试环境..."

    # 清理临时文件
    find "$TEST_LOG_DIR" -name "*.tmp" -mtime +7 -delete 2>/dev/null || true

    # 限制日志文件数量
    find "$TEST_LOG_DIR" -name "test-report-*.html" | sort -r | tail -n +11 | xargs rm -f 2>/dev/null || true
}

# 主函数
main() {
    START_TIME=$(date +%s.%N)

    echo -e "${CYAN}=========================================="
    echo -e "        s-hy2 测试框架启动"
    echo -e "==========================================${NC}"
    echo ""

    # 检查依赖
    local missing_deps=()
    command -v timeout >/dev/null || missing_deps+=("timeout")
    command -v bc >/dev/null || missing_deps+=("bc")

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "缺少依赖: ${missing_deps[*]}"
        log_warn "某些功能可能不可用"
    fi

    # 运行所有测试套件
    local test_files=("$SCRIPT_DIR"/test-*.sh)

    if [[ ${#test_files[@]} -eq 1 && ! -f "${test_files[0]}" ]]; then
        log_warn "未找到测试文件"
        return 0
    fi

    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" && "$test_file" != "${BASH_SOURCE[0]}" ]]; then
            local suite_name=$(basename "$test_file" .sh)
            run_test_suite "$suite_name" "$test_file"
        fi
    done

    # 生成报告
    generate_html_report "$TEST_REPORT_FILE"
    print_summary
    cleanup_test_env

    # 返回适当的退出码
    [[ $FAILED_TESTS -eq 0 ]]
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi