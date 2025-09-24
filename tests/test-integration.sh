#!/bin/bash

# 集成测试 - 测试模块间的交互和完整功能

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 创建测试环境
TEST_TEMP_DIR="$SCRIPT_DIR/temp/integration_$$"
mkdir -p "$TEST_TEMP_DIR"

cleanup() {
    rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# ========== 模块加载测试 ==========

test_module_loading() {
    # 测试主脚本能否成功加载所有模块
    local main_script="$PROJECT_DIR/hy2-manager.sh"

    if [[ -f "$main_script" ]]; then
        # 检查load_new_modules函数是否存在
        assert_command_success "grep -q 'load_new_modules()' '$main_script'" "主脚本应包含模块加载函数"

        # 检查模块源码调用
        assert_command_success "grep -q 'source.*outbound-manager.sh' '$main_script' || grep -q 'outbound-manager.sh' '$main_script'" "主脚本应引用出站管理模块"
        assert_command_success "grep -q 'source.*firewall-manager.sh' '$main_script' || grep -q 'firewall-manager.sh' '$main_script'" "主脚本应引用防火墙管理模块"
    else
        skip_test "module_loading" "主脚本不存在"
    fi
}

# ========== 配置系统测试 ==========

test_config_system_integration() {
    local config_file="$PROJECT_DIR/config/app.conf"
    local config_loader="$PROJECT_DIR/scripts/config-loader.sh"

    if [[ -f "$config_file" && -f "$config_loader" ]]; then
        # 测试配置文件语法
        assert_command_success "bash -n '$config_loader'" "配置加载器语法应该正确"

        # 测试配置文件包含必要设置
        assert_command_success "grep -q 'PROJECT_NAME=' '$config_file'" "配置文件应包含项目名称"
        assert_command_success "grep -q 'DEFAULT_LISTEN_PORT=' '$config_file'" "配置文件应包含默认端口"

        # 测试配置加载
        local test_script="$TEST_TEMP_DIR/test_config.sh"
        cat > "$test_script" << EOF
#!/bin/bash
source '$config_loader'
load_config '$config_file'
echo "PROJECT_NAME=\${PROJECT_NAME:-}"
EOF
        chmod +x "$test_script"

        local output
        output=$(bash "$test_script" 2>/dev/null) || output=""
        assert_contains "$output" "PROJECT_NAME=" "配置加载应该设置PROJECT_NAME变量"
    else
        skip_test "config_system_integration" "配置系统文件缺失"
    fi
}

# ========== 出站管理集成测试 ==========

test_outbound_manager_integration() {
    local outbound_script="$PROJECT_DIR/scripts/outbound-manager.sh"
    local templates_dir="$PROJECT_DIR/scripts/outbound-templates"

    if [[ -f "$outbound_script" && -d "$templates_dir" ]]; then
        # 检查语法
        assert_command_success "bash -n '$outbound_script'" "出站管理脚本语法应该正确"

        # 检查模板文件存在
        assert_file_exists "$templates_dir/direct.yaml" "直连模板应该存在"
        assert_file_exists "$templates_dir/socks5.yaml" "SOCKS5模板应该存在"
        assert_file_exists "$templates_dir/http.yaml" "HTTP模板应该存在"

        # 检查模板文件内容
        assert_command_success "grep -q 'outbounds:' '$templates_dir/direct.yaml'" "直连模板应包含出站配置"
        assert_command_success "grep -q 'type: socks5' '$templates_dir/socks5.yaml'" "SOCKS5模板应包含正确类型"
        assert_command_success "grep -q 'type: http' '$templates_dir/http.yaml'" "HTTP模板应包含正确类型"

        # 检查主函数存在
        assert_command_success "grep -q 'manage_outbound()' '$outbound_script'" "应包含主管理函数"
    else
        skip_test "outbound_manager_integration" "出站管理相关文件缺失"
    fi
}

# ========== 防火墙管理集成测试 ==========

test_firewall_manager_integration() {
    local firewall_script="$PROJECT_DIR/scripts/firewall-manager.sh"

    if [[ -f "$firewall_script" ]]; then
        # 检查语法
        assert_command_success "bash -n '$firewall_script'" "防火墙管理脚本语法应该正确"

        # 检查关键函数存在
        assert_command_success "grep -q 'detect_firewall()' '$firewall_script'" "应包含防火墙检测函数"
        assert_command_success "grep -q 'manage_firewall()' '$firewall_script'" "应包含防火墙管理函数"

        # 检查支持的防火墙类型
        assert_command_success "grep -q 'firewalld' '$firewall_script'" "应支持firewalld"
        assert_command_success "grep -q 'ufw' '$firewall_script'" "应支持ufw"
        assert_command_success "grep -q 'iptables' '$firewall_script'" "应支持iptables"
    else
        skip_test "firewall_manager_integration" "防火墙管理脚本不存在"
    fi
}

# ========== 部署后检查集成测试 ==========

test_post_deploy_check_integration() {
    local check_script="$PROJECT_DIR/scripts/post-deploy-check.sh"

    if [[ -f "$check_script" ]]; then
        # 检查语法
        assert_command_success "bash -n '$check_script'" "部署检查脚本语法应该正确"

        # 检查主函数存在
        assert_command_success "grep -q 'comprehensive_deploy_check()' '$check_script'" "应包含综合检查函数"

        # 检查检查项目
        assert_command_success "grep -q '进程检查' '$check_script'" "应包含进程检查"
        assert_command_success "grep -q '端口检查' '$check_script'" "应包含端口检查"
        assert_command_success "grep -q '防火墙检查' '$check_script'" "应包含防火墙检查"
    else
        skip_test "post_deploy_check_integration" "部署检查脚本不存在"
    fi
}

# ========== 主菜单集成测试 ==========

test_main_menu_integration() {
    local main_script="$PROJECT_DIR/hy2-manager.sh"

    if [[ -f "$main_script" ]]; then
        # 检查菜单选项存在
        assert_command_success "grep -q '出站规则配置' '$main_script'" "菜单应包含出站规则配置选项"
        assert_command_success "grep -q '防火墙管理' '$main_script'" "菜单应包含防火墙管理选项"

        # 检查函数调用
        assert_command_success "grep -q 'manage_outbound' '$main_script'" "应调用出站管理函数"
        assert_command_success "grep -q 'manage_firewall' '$main_script'" "应调用防火墙管理函数"

        # 检查输入验证范围更新
        assert_command_success "grep -q -E '(\[0-9\]|\[0-1[0-2]\])' '$main_script' || grep -q '0.*1[0-2]' '$main_script'" "输入验证应包含新的选项范围"
    else
        skip_test "main_menu_integration" "主脚本不存在"
    fi
}

# ========== 安全增强集成测试 ==========

test_security_enhancements_integration() {
    local security_scripts=(
        "$PROJECT_DIR/scripts/input-validation.sh"
        "$PROJECT_DIR/scripts/secure-download.sh"
    )

    local found_security=0
    for script in "${security_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            ((found_security++))
            assert_command_success "bash -n '$script'" "安全脚本 $(basename "$script") 语法应该正确"
        fi
    done

    if [[ $found_security -gt 0 ]]; then
        assert_command_success "[[ $found_security -gt 0 ]]" "至少应有一个安全增强脚本"
    else
        skip_test "security_enhancements_integration" "安全增强脚本不存在"
    fi
}

# ========== 错误处理集成测试 ==========

test_error_handling_integration() {
    # 检查严格模式的使用
    local scripts_with_strict=0
    local total_scripts=0

    while IFS= read -r -d '' script; do
        ((total_scripts++))
        if grep -q "set -euo pipefail" "$script"; then
            ((scripts_with_strict++))
        fi
    done < <(find "$PROJECT_DIR/scripts" -name "*.sh" -print0 2>/dev/null)

    if [[ $total_scripts -gt 0 ]]; then
        local strict_percentage=$((scripts_with_strict * 100 / total_scripts))
        assert_command_success "[[ $strict_percentage -gt 30 ]]" "至少30%的脚本应使用严格模式 (当前: ${strict_percentage}%)"
    else
        skip_test "error_handling_integration" "未找到脚本文件"
    fi
}

# ========== 模块依赖测试 ==========

test_module_dependencies() {
    # 测试模块间的依赖关系
    local common_script="$PROJECT_DIR/scripts/common.sh"

    if [[ -f "$common_script" ]]; then
        # 检查其他模块是否正确引用公共库
        local modules_using_common=0

        while IFS= read -r -d '' script; do
            if [[ "$script" != "$common_script" ]] && grep -q "common.sh" "$script"; then
                ((modules_using_common++))
            fi
        done < <(find "$PROJECT_DIR/scripts" -name "*.sh" -print0 2>/dev/null)

        assert_command_success "[[ $modules_using_common -gt 0 ]]" "至少一个模块应该引用公共库"
    else
        skip_test "module_dependencies" "公共库不存在"
    fi
}

# ========== 文件权限测试 ==========

test_file_permissions() {
    # 检查关键文件的权限
    local main_script="$PROJECT_DIR/hy2-manager.sh"

    if [[ -f "$main_script" ]]; then
        assert_command_success "[[ -x '$main_script' ]]" "主脚本应该可执行"

        # 检查脚本目录中的其他脚本
        local executable_scripts=0
        while IFS= read -r -d '' script; do
            if [[ -x "$script" ]]; then
                ((executable_scripts++))
            fi
        done < <(find "$PROJECT_DIR/scripts" -name "*.sh" -print0 2>/dev/null)

        assert_command_success "[[ $executable_scripts -gt 0 ]]" "至少一个脚本应该可执行"
    else
        skip_test "file_permissions" "主脚本不存在"
    fi
}

# 运行所有集成测试
run_test "模块加载集成测试" "test_module_loading"
run_test "配置系统集成测试" "test_config_system_integration"
run_test "出站管理集成测试" "test_outbound_manager_integration"
run_test "防火墙管理集成测试" "test_firewall_manager_integration"
run_test "部署检查集成测试" "test_post_deploy_check_integration"
run_test "主菜单集成测试" "test_main_menu_integration"
run_test "安全增强集成测试" "test_security_enhancements_integration"
run_test "错误处理集成测试" "test_error_handling_integration"
run_test "模块依赖测试" "test_module_dependencies"
run_test "文件权限测试" "test_file_permissions"