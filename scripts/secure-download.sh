#!/bin/bash

# 安全下载和文件验证模块
# 防止恶意文件下载和远程代码执行

# 严格错误处理
set -euo pipefail

# 安全下载配置 (防止重复定义)
if [[ -z "${DOWNLOAD_TIMEOUT:-}" ]]; then
    readonly DOWNLOAD_TIMEOUT=30
    readonly MAX_FILE_SIZE=$((10 * 1024 * 1024))  # 10MB
    readonly ALLOWED_PROTOCOLS=("https")
    readonly USER_AGENT="s-hy2-secure-downloader/1.0"
fi

# 临时目录
if [[ -z "${SECURE_TEMP_DIR:-}" ]]; then
    readonly SECURE_TEMP_DIR="/tmp/s-hy2-secure-$$"
fi

# 清理函数
cleanup_temp_files() {
    if [[ -d "$SECURE_TEMP_DIR" ]]; then
        rm -rf "$SECURE_TEMP_DIR"
    fi
}

# 设置清理陷阱
trap cleanup_temp_files EXIT

# 创建安全临时目录
create_secure_temp_dir() {
    mkdir -p "$SECURE_TEMP_DIR"
    chmod 700 "$SECURE_TEMP_DIR"
}

# 验证URL安全性
validate_url_secure() {
    local url="$1"

    # 检查协议
    local protocol="${url%%://*}"
    local is_allowed=false

    for allowed in "${ALLOWED_PROTOCOLS[@]}"; do
        if [[ "$protocol" == "$allowed" ]]; then
            is_allowed=true
            break
        fi
    done

    if [[ "$is_allowed" != "true" ]]; then
        echo "不安全的协议: $protocol" >&2
        return 1
    fi

    # 检查URL格式
    if [[ ! "$url" =~ ^https://[a-zA-Z0-9.-]+(/.*)?$ ]]; then
        echo "URL格式不正确" >&2
        return 1
    fi

    # 防止本地文件访问
    if [[ "$url" =~ file://|localhost|127\.0\.0\.1|0\.0\.0\.0 ]]; then
        echo "禁止访问本地资源" >&2
        return 1
    fi

    return 0
}

# 安全下载文件
download_file_secure() {
    local url="$1"
    local output_file="$2"
    local expected_hash="${3:-}"

    # 验证URL
    if ! validate_url_secure "$url"; then
        return 1
    fi

    # 创建安全临时目录
    create_secure_temp_dir

    # 临时文件路径
    local temp_file="$SECURE_TEMP_DIR/download.tmp"

    echo "正在安全下载: $url"

    # 使用curl安全下载
    if ! curl \
        --silent \
        --show-error \
        --fail \
        --location \
        --max-time "$DOWNLOAD_TIMEOUT" \
        --max-filesize "$MAX_FILE_SIZE" \
        --user-agent "$USER_AGENT" \
        --proto "=https" \
        --tlsv1.2 \
        --cert-status \
        --output "$temp_file" \
        "$url"; then
        echo "下载失败: $url" >&2
        return 1
    fi

    # 验证文件大小
    local file_size
    file_size=$(stat -c%s "$temp_file" 2>/dev/null || echo 0)

    if [[ $file_size -eq 0 ]]; then
        echo "下载的文件为空" >&2
        return 1
    fi

    if [[ $file_size -gt $MAX_FILE_SIZE ]]; then
        echo "文件大小超过限制 ($MAX_FILE_SIZE bytes)" >&2
        return 1
    fi

    # 验证文件哈希（如果提供）
    if [[ -n "$expected_hash" ]]; then
        local actual_hash
        actual_hash=$(sha256sum "$temp_file" | cut -d' ' -f1)

        if [[ "$actual_hash" != "$expected_hash" ]]; then
            echo "文件哈希验证失败" >&2
            echo "期望: $expected_hash" >&2
            echo "实际: $actual_hash" >&2
            return 1
        fi

        echo "文件哈希验证通过: $actual_hash"
    fi

    # 移动到目标位置
    if ! mv "$temp_file" "$output_file"; then
        echo "无法移动文件到目标位置: $output_file" >&2
        return 1
    fi

    # 设置安全权限
    chmod 644 "$output_file"

    echo "文件安全下载完成: $output_file"
    return 0
}

# 下载并验证shell脚本
download_script_secure() {
    local url="$1"
    local output_file="$2"
    local expected_hash="${3:-}"

    # 下载文件
    if ! download_file_secure "$url" "$output_file" "$expected_hash"; then
        return 1
    fi

    # 验证shell脚本语法
    if ! bash -n "$output_file"; then
        echo "脚本语法检查失败: $output_file" >&2
        rm -f "$output_file"
        return 1
    fi

    # 检查危险命令
    local dangerous_patterns=(
        "rm -rf /"
        "dd if="
        "mkfs"
        "fdisk"
        "format"
        "> /dev/"
        "curl.*|.*sh"
        "wget.*|.*sh"
        "eval.*\$"
        "exec.*\$"
    )

    for pattern in "${dangerous_patterns[@]}"; do
        if grep -q "$pattern" "$output_file"; then
            echo "脚本包含危险命令: $pattern" >&2
            rm -f "$output_file"
            return 1
        fi
    done

    # 设置执行权限
    chmod 755 "$output_file"

    echo "脚本安全验证通过: $output_file"
    return 0
}

# 安全执行下载的脚本
execute_downloaded_script_secure() {
    local script_file="$1"
    shift
    local args=("$@")

    # 验证脚本存在
    if [[ ! -f "$script_file" ]]; then
        echo "脚本文件不存在: $script_file" >&2
        return 1
    fi

    # 验证脚本权限
    if [[ ! -x "$script_file" ]]; then
        echo "脚本没有执行权限: $script_file" >&2
        return 1
    fi

    # 记录执行日志
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 安全执行脚本: $script_file ${args[*]}" >&2

    # 在受限环境中执行
    timeout 300 bash "$script_file" "${args[@]}"
}

# 获取文件的SHA256哈希
get_file_hash() {
    local file="$1"

    if [[ -f "$file" ]]; then
        sha256sum "$file" | cut -d' ' -f1
    else
        echo "文件不存在: $file" >&2
        return 1
    fi
}

# 验证已知的官方文件哈希
verify_official_hash() {
    local file="$1"
    local file_type="$2"

    # 官方文件哈希数据库（示例）
    case "$file_type" in
        "hysteria2-install")
            # 这里应该是官方安装脚本的已知哈希值
            # 实际使用时需要从官方获取并定期更新
            local known_hashes=(
                "placeholder_hash_1"
                "placeholder_hash_2"
            )
            ;;
        *)
            echo "未知文件类型: $file_type" >&2
            return 1
            ;;
    esac

    local file_hash
    file_hash=$(get_file_hash "$file")

    for known_hash in "${known_hashes[@]}"; do
        if [[ "$file_hash" == "$known_hash" ]]; then
            echo "文件哈希验证通过: $file_hash"
            return 0
        fi
    done

    echo "文件哈希不在已知列表中: $file_hash" >&2
    return 1
}

# 导出函数
export -f validate_url_secure
export -f download_file_secure
export -f download_script_secure
export -f execute_downloaded_script_secure
export -f get_file_hash
export -f verify_official_hash