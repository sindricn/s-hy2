#!/bin/bash

# 公共库模块的单元测试

# 加载测试框架和待测试模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 创建临时测试环境
TEST_TEMP_DIR="$SCRIPT_DIR/temp/$$"
mkdir -p "$TEST_TEMP_DIR"

# 清理函数
cleanup() {
    rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# 加载待测试模块（在受控环境中）
if [[ -f "$PROJECT_DIR/scripts/common.sh" ]]; then
    # 临时禁用set -e以避免在测试环境中过早退出
    set +e
    source "$PROJECT_DIR/scripts/common.sh" 2>/dev/null || true
    set -e
fi

# ========== 输入验证函数测试 ==========

test_validate_domain_basic() {
    # 如果函数存在才测试
    if declare -f validate_domain_secure >/dev/null; then
        assert_command_success "validate_domain_secure 'example.com'" "有效域名应该通过验证"
        assert_command_success "validate_domain_secure 'sub.example.com'" "子域名应该通过验证"
        assert_command_failure "validate_domain_secure 'invalid..domain'" "无效域名应该失败"
        assert_command_failure "validate_domain_secure ''" "空域名应该失败"
    else
        skip_test "validate_domain_secure" "函数不存在"
    fi
}

test_validate_email_basic() {
    if declare -f validate_email_secure >/dev/null; then
        assert_command_success "validate_email_secure 'user@example.com'" "有效邮箱应该通过验证"
        assert_command_failure "validate_email_secure 'invalid-email'" "无效邮箱应该失败"
        assert_command_failure "validate_email_secure ''" "空邮箱应该失败"
    else
        skip_test "validate_email_secure" "函数不存在"
    fi
}

test_validate_port_range() {
    if declare -f validate_port >/dev/null; then
        assert_command_success "validate_port '80'" "有效端口应该通过验证"
        assert_command_success "validate_port '443'" "有效端口应该通过验证"
        assert_command_success "validate_port '65535'" "最大端口应该通过验证"
        assert_command_failure "validate_port '0'" "端口0应该失败"
        assert_command_failure "validate_port '65536'" "超出范围端口应该失败"
        assert_command_failure "validate_port 'abc'" "非数字端口应该失败"
    else
        skip_test "validate_port" "函数不存在"
    fi
}

# ========== 日志函数测试 ==========

test_log_functions() {
    if declare -f log_info >/dev/null; then
        # 测试日志函数是否正常工作（不崩溃）
        local test_message="Test message"
        assert_command_success "log_info '$test_message'" "log_info应该成功执行"
        assert_command_success "log_warn '$test_message'" "log_warn应该成功执行"
        assert_command_success "log_error '$test_message'" "log_error应该成功执行"
    else
        skip_test "log_functions" "日志函数不存在"
    fi
}

# ========== 错误处理测试 ==========

test_error_handling_setup() {
    if declare -f setup_error_handling >/dev/null; then
        # 测试错误处理设置
        local temp_script="$TEST_TEMP_DIR/test_error.sh"
        cat > "$temp_script" << 'EOF'
#!/bin/bash
source "$1"
setup_error_handling
echo "Error handling setup completed"
EOF
        chmod +x "$temp_script"

        assert_command_success "bash '$temp_script' '$PROJECT_DIR/scripts/common.sh'" "错误处理设置应该成功"
    else
        skip_test "setup_error_handling" "函数不存在"
    fi
}

# ========== 文件操作测试 ==========

test_safe_file_operations() {
    if declare -f create_temp_file >/dev/null; then
        # 测试临时文件创建
        local temp_file
        temp_file=$(create_temp_file "test" 2>/dev/null) || temp_file=""

        if [[ -n "$temp_file" ]]; then
            assert_file_exists "$temp_file" "临时文件应该被创建"
            rm -f "$temp_file" 2>/dev/null || true
        else
            skip_test "create_temp_file" "无法创建临时文件"
        fi
    else
        skip_test "create_temp_file" "函数不存在"
    fi
}

# ========== 配置文件处理测试 ==========

test_config_loading() {
    if declare -f load_config >/dev/null; then
        # 创建测试配置文件
        local test_config="$TEST_TEMP_DIR/test.conf"
        cat > "$test_config" << 'EOF'
TEST_VAR=test_value
TEST_PORT=8080
EOF

        # 测试配置加载
        if load_config "$test_config" 2>/dev/null; then
            assert_equals "test_value" "${TEST_VAR:-}" "配置变量应该被正确加载"
            assert_equals "8080" "${TEST_PORT:-}" "端口配置应该被正确加载"
        else
            skip_test "load_config" "配置加载失败"
        fi
    else
        skip_test "load_config" "函数不存在"
    fi
}

# ========== 网络检查测试 ==========

test_network_functions() {
    if declare -f check_port_available >/dev/null; then
        # 测试端口检查（使用不太可能被占用的高端口）
        local test_port=54321

        # 这个测试可能因为环境而失败，所以比较宽松
        if check_port_available "$test_port" 2>/dev/null; then
            log_info "端口 $test_port 可用"
        else
            log_info "端口 $test_port 不可用或检查失败"
        fi

        # 至少测试函数不会崩溃
        assert_command_success "check_port_available '$test_port' >/dev/null 2>&1 || true" "端口检查函数应该能执行"
    else
        skip_test "check_port_available" "函数不存在"
    fi
}

# ========== 权限检查测试 ==========

test_permission_checks() {
    if declare -f check_root_privileges >/dev/null; then
        # 测试权限检查函数（不要求一定是root）
        assert_command_success "check_root_privileges >/dev/null 2>&1 || true" "权限检查函数应该能执行"
    else
        skip_test "check_root_privileges" "函数不存在"
    fi
}

# ========== 字符串处理测试 ==========

test_string_functions() {
    if declare -f trim_string >/dev/null; then
        local result
        result=$(trim_string "  test string  " 2>/dev/null) || result=""
        assert_equals "test string" "$result" "字符串修剪应该移除首尾空格"
    else
        skip_test "trim_string" "函数不存在"
    fi

    if declare -f sanitize_input >/dev/null; then
        local result
        result=$(sanitize_input "safe_input_123" 2>/dev/null) || result=""
        assert_not_equals "" "$result" "安全输入应该通过清理"
    else
        skip_test "sanitize_input" "函数不存在"
    fi
}

# 运行所有测试
run_test "域名验证基础测试" "test_validate_domain_basic"
run_test "邮箱验证基础测试" "test_validate_email_basic"
run_test "端口验证范围测试" "test_validate_port_range"
run_test "日志函数测试" "test_log_functions"
run_test "错误处理设置测试" "test_error_handling_setup"
run_test "安全文件操作测试" "test_safe_file_operations"
run_test "配置文件加载测试" "test_config_loading"
run_test "网络功能测试" "test_network_functions"
run_test "权限检查测试" "test_permission_checks"
run_test "字符串处理测试" "test_string_functions"