#!/bin/bash

# 临时文件管理最佳实践指南
# 展示如何正确使用 common.sh 的临时文件管理功能

# 加载公共库
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ======= 推荐的临时文件使用方式 =======

# 方式 1: 使用 create_temp_file (推荐)
demo_create_temp_file() {
    echo "=== 使用 create_temp_file 创建安全临时文件 ==="

    # 创建临时文件，自动设置安全权限并注册清理
    local temp_file
    temp_file=$(create_temp_file)

    echo "临时文件已创建: $temp_file"
    echo "文件权限: $(ls -l "$temp_file" | awk '{print $1}')"

    # 使用临时文件
    echo "一些临时数据" > "$temp_file"
    echo "临时文件内容: $(cat "$temp_file")"

    # 不需要手动删除 - 脚本退出时自动清理
}

# 方式 2: 使用 create_temp_dir (推荐)
demo_create_temp_dir() {
    echo "=== 使用 create_temp_dir 创建安全临时目录 ==="

    # 创建临时目录，自动设置安全权限并注册清理
    local temp_dir
    temp_dir=$(create_temp_dir)

    echo "临时目录已创建: $temp_dir"
    echo "目录权限: $(ls -ld "$temp_dir" | awk '{print $1}')"

    # 使用临时目录
    echo "临时文件1" > "$temp_dir/file1.txt"
    echo "临时文件2" > "$temp_dir/file2.txt"
    echo "目录内容: $(ls "$temp_dir")"

    # 不需要手动删除 - 脚本退出时自动清理
}

# ======= 不推荐的方式 (仅用于对比) =======

# 不推荐: 手动管理临时文件
demo_manual_temp_file() {
    echo "=== 不推荐: 手动管理临时文件 ==="

    # 问题:
    # 1. 权限可能不安全
    # 2. 容易忘记清理
    # 3. 异常退出时可能泄露
    local temp_file="/tmp/manual_temp_$$_$(date +%s).txt"

    echo "手动临时文件: $temp_file"
    echo "数据" > "$temp_file"

    # 需要记住手动删除
    rm -f "$temp_file"
}

# ======= 在现有脚本中集成临时文件管理 =======

# 如果你有现有的脚本使用手动临时文件，可以这样迁移:
migrate_existing_script() {
    echo "=== 迁移现有脚本的示例 ==="

    # 原来的代码 (不推荐):
    # local old_temp="/tmp/myapp_$$_$(date +%s).tmp"
    # echo "data" > "$old_temp"
    # # ... 使用文件 ...
    # rm -f "$old_temp"

    # 迁移后的代码 (推荐):
    local new_temp
    new_temp=$(create_temp_file)
    echo "data" > "$new_temp"
    # ... 使用文件 ...
    # 自动清理，无需手动删除

    echo "迁移完成，临时文件: $new_temp"
}

# ======= 复杂场景的处理 =======

# 场景: 需要特定扩展名的临时文件
demo_temp_with_extension() {
    echo "=== 带扩展名的临时文件 ==="

    local temp_file
    temp_file=$(create_temp_file)

    # 创建带扩展名的链接
    local yaml_temp="${temp_file}.yaml"
    ln -s "$temp_file" "$yaml_temp"

    # 使用带扩展名的文件
    echo "key: value" > "$yaml_temp"
    echo "YAML 临时文件: $yaml_temp"

    # 注册额外的清理
    TEMP_FILES="${TEMP_FILES:-} $yaml_temp"
}

# 场景: 需要在特定目录创建临时文件
demo_temp_in_specific_dir() {
    echo "=== 在特定目录创建临时文件 ==="

    local work_dir="/tmp/myapp"
    mkdir -p "$work_dir"

    # 在工作目录中创建临时文件
    local temp_file
    temp_file=$(mktemp -p "$work_dir")
    chmod 600 "$temp_file"

    # 注册清理
    TEMP_FILES="${TEMP_FILES:-} $temp_file"

    echo "特定目录的临时文件: $temp_file"
    echo "数据" > "$temp_file"
}

# ======= 错误处理和清理 =======

# 实现自定义清理函数
cleanup() {
    local exit_code=${1:-0}

    echo "开始自定义清理..."

    # 先调用标准清理 (来自 common.sh)
    # 这会自动清理所有注册的临时文件和目录

    # 添加其他清理逻辑
    echo "执行额外的清理操作..."

    echo "清理完成 (退出码: $exit_code)"
}

# ======= 运行演示 =======

main() {
    enable_error_handling
    log_info "开始临时文件管理演示"

    demo_create_temp_file
    echo ""

    demo_create_temp_dir
    echo ""

    demo_manual_temp_file
    echo ""

    migrate_existing_script
    echo ""

    demo_temp_with_extension
    echo ""

    demo_temp_in_specific_dir
    echo ""

    log_info "演示完成，等待清理..."
    sleep 1

    # 脚本退出时，所有临时文件将自动清理
}

# ======= 使用说明 =======

# 在你的脚本中:
# 1. source common.sh
# 2. 使用 create_temp_file 或 create_temp_dir
# 3. 实现自定义的 cleanup 函数（可选）
# 4. 调用 enable_error_handling 启用自动清理

# 如果脚本作为模块运行，不执行 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi