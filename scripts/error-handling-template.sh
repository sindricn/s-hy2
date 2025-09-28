#!/bin/bash

# 标准错误处理模板
# 所有新脚本和重构脚本应该使用这个模板

# ======= 标准错误处理设置 =======

# 加载公共库 (必须)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
else
    echo "错误: 无法加载公共库 common.sh" >&2
    exit 1
fi

# 根据脚本类型选择错误处理模式

# 模式 1: 标准脚本 (推荐用于大多数脚本)
# - 使用 common.sh 的错误处理
# - 支持优雅退出和清理
init_error_handling() {
    enable_error_handling
    log_info "脚本开始执行: ${BASH_SOURCE[1]##*/}"
}

# 模式 2: 严格脚本 (用于安全关键脚本)
# - 立即退出任何错误
# - 适用于: input-validation.sh, secure-download.sh
init_strict_error_handling() {
    set -euo pipefail
    log_info "脚本开始执行 (严格模式): ${BASH_SOURCE[1]##*/}"
}

# 模式 3: 宽松脚本 (用于交互式脚本)
# - 允许某些错误继续执行
# - 适用于: 菜单脚本、用户交互脚本
init_interactive_error_handling() {
    set -uo pipefail
    # 不使用 -e，允许交互式错误处理
    log_info "脚本开始执行 (交互模式): ${BASH_SOURCE[1]##*/}"
}

# ======= 清理函数模板 =======

# 标准清理函数 - 每个脚本都应该实现
cleanup() {
    local exit_code=${1:-0}

    # 在这里添加脚本特定的清理逻辑
    # 例如:
    # - 删除临时文件
    # - 关闭网络连接
    # - 恢复系统状态

    log_debug "清理操作完成 (退出码: $exit_code)"
}

# ======= 使用示例 =======

# 在你的脚本中使用:
#
# #!/bin/bash
# source "$(dirname "${BASH_SOURCE[0]}")/error-handling-template.sh"
#
# # 选择适合的错误处理模式
# init_error_handling  # 或 init_strict_error_handling 或 init_interactive_error_handling
#
# # 实现你的清理函数
# cleanup() {
#     local exit_code=${1:-0}
#     rm -f /tmp/my_temp_file
#     log_debug "清理完成"
# }
#
# # 你的脚本逻辑
# main() {
#     log_info "开始主要功能"
#     # ... 你的代码 ...
# }
#
# main "$@"

# ======= 最佳实践 =======

# 1. 总是使用 init_* 函数之一
# 2. 总是实现 cleanup 函数
# 3. 使用 log_* 函数而不是 echo 输出重要信息
# 4. 对于临时文件，使用 register_temp_file 自动清理
# 5. 对于交互式输入，验证用户输入
# 6. 对于网络操作，添加超时和重试机制

export -f init_error_handling init_strict_error_handling init_interactive_error_handling