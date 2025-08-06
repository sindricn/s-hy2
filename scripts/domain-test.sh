#!/bin/bash

# 伪装域名测试脚本 - 优化版本

# 预定义的域名列表
DOMAINS=(
    "www.cloudflare.com"
    "www.apple.com"
    "www.microsoft.com"
    "www.bing.com"
    "www.google.com"
    "developer.apple.com"
    "www.gstatic.com"
    "fonts.gstatic.com"
    "fonts.googleapis.com"
    "res-1.cdn.office.net"
    "res.public.onecdn.static.microsoft"
    "static.cloud.coveo.com"
    "aws.amazon.com"
    "www.aws.com"
    "cloudfront.net"
    "d1.awsstatic.com"
    "cdn.jsdelivr.net"
    "cdn.jsdelivr.org"
    "polyfill-fastly.io"
    "beacon.gtv-pub.com"
    "s7mbrstream.scene7.com"
    "cdn.bizibly.com"
    "www.sony.com"
    "www.nytimes.com"
    "www.w3.org"
    "www.wikipedia.org"
    "ajax.cloudflare.com"
    "www.mozilla.org"
    "www.intel.com"
    "api.snapchat.com"
    "images.unsplash.com"
    "edge-mqtt.facebook.com"
    "video.xx.fbcdn.net"
    "gstatic.cn"
)

# 缓存配置
CACHE_DIR="/tmp/hysteria-domain-cache"
CACHE_EXPIRY=3600  # 1小时缓存
MAX_CONCURRENT_JOBS=8

# 创建缓存目录
mkdir -p "$CACHE_DIR"

# 获取缓存文件路径
get_cache_file() {
    local domain=$1
    echo "$CACHE_DIR/$(echo "$domain" | tr '.' '_')"
}

# 检查缓存是否有效
is_cache_valid() {
    local cache_file=$1
    if [[ -f "$cache_file" ]]; then
        local cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
        local current_time=$(date +%s)
        if [[ $((current_time - cache_time)) -lt $CACHE_EXPIRY ]]; then
            return 0
        fi
    fi
    return 1
}

# 从缓存读取结果
read_from_cache() {
    local cache_file=$1
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi
    return 1
}

# 写入缓存
write_to_cache() {
    local cache_file=$1
    local result=$2
    echo "$result" > "$cache_file"
}

# 清理过期缓存
cleanup_cache() {
    find "$CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null
}

# 智能超时调整
get_adaptive_timeout() {
    local network_quality=$1
    case $network_quality in
        "fast") echo 2 ;;
        "medium") echo 3 ;;
        "slow") echo 5 ;;
        *) echo 3 ;;
    esac
}

# 网络质量检测
detect_network_quality() {
    local start_time=$(date +%s%3N)
    if timeout 2 curl -s --connect-timeout 2 google.com >/dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local latency=$((end_time - start_time))
        
        if [[ $latency -lt 500 ]]; then
            echo "fast"
        elif [[ $latency -lt 1500 ]]; then
            echo "medium"
        else
            echo "slow"
        fi
    else
        echo "slow"
    fi
}

# 测试单个域名延迟（优化版本）
test_domain_latency() {
    local domain=$1
    local timeout_val=${2:-3}
    local attempts=${3:-2}  # 默认尝试2次
    local results=()
    
    # 检查缓存
    local cache_file=$(get_cache_file "$domain")
    if is_cache_valid "$cache_file"; then
        read_from_cache "$cache_file"
        return 0
    fi
    
    # 多次测试取最佳结果
    for ((i=1; i<=attempts; i++)); do
        local start_time=$(date +%s%3N)
        
        if timeout "$timeout_val" openssl s_client -connect "$domain:443" -servername "$domain" </dev/null >/dev/null 2>&1; then
            local end_time=$(date +%s%3N)
            local latency=$((end_time - start_time))
            results+=($latency)
        fi
    done
    
    # 如果有成功的测试结果，返回最小值
    if [[ ${#results[@]} -gt 0 ]]; then
        local min_latency=$(printf '%s\n' "${results[@]}" | sort -n | head -1)
        local result="$min_latency $domain"
        
        # 写入缓存
        write_to_cache "$cache_file" "$result"
        echo "$result"
        return 0
    fi
    
    return 1
}

# 并发测试所有域名（静默版本）
test_all_domains_concurrent_silent() {
    local results_file=$(mktemp)
    local job_count=0
    local total=${#DOMAINS[@]}
    local completed=0
    
    # 检测网络质量并调整超时
    local network_quality=$(detect_network_quality)
    local timeout_val=$(get_adaptive_timeout "$network_quality")
    
    # 并发测试域名
    for domain in "${DOMAINS[@]}"; do
        # 限制并发数
        while [[ $(jobs -r | wc -l) -ge $MAX_CONCURRENT_JOBS ]]; do
            sleep 0.1
        done
        
        # 启动后台任务
        (
            if result=$(test_domain_latency "$domain" "$timeout_val" 1); then
                echo "$result" >> "$results_file"
            fi
        ) &
    done
    
    # 等待所有任务完成
    wait
    
    # 返回排序结果
    if [[ -s "$results_file" ]]; then
        sort -n "$results_file"
        local exit_code=0
    else
        local exit_code=1
    fi
    
    rm -f "$results_file"
    return $exit_code
}

# 并发测试所有域名（带进度显示）
test_all_domains_concurrent() {
    local results_file=$(mktemp)
    local progress_file=$(mktemp)
    local total=${#DOMAINS[@]}
    local completed=0
    
    echo -e "${BLUE}正在并发测试 $total 个域名的延迟...${NC}" >&2
    echo -e "${BLUE}网络质量: $(detect_network_quality | tr 'a-z' 'A-Z')${NC}" >&2
    echo "" >&2
    
    # 检测网络质量并调整超时
    local network_quality=$(detect_network_quality)
    local timeout_val=$(get_adaptive_timeout "$network_quality")
    
    # 启动进度监控
    {
        while [[ $completed -lt $total ]]; do
            completed=$(cat "$progress_file" 2>/dev/null | wc -l)
            local percentage=$(( (completed * 100) / total ))
            printf "\r${BLUE}进度: %d/%d (%d%%) - 已完成测试${NC}" $completed $total $percentage >&2
            sleep 0.2
        done
        echo "" >&2
    } &
    local monitor_pid=$!
    
    # 并发测试域名
    for domain in "${DOMAINS[@]}"; do
        # 限制并发数
        while [[ $(jobs -r | wc -l) -ge $MAX_CONCURRENT_JOBS ]]; do
            sleep 0.1
        done
        
        # 启动后台任务
        (
            if result=$(test_domain_latency "$domain" "$timeout_val" 1); then
                echo "$result" >> "$results_file"
            fi
            echo "1" >> "$progress_file"  # 标记任务完成
        ) &
    done
    
    # 等待所有任务完成
    wait
    
    # 停止进度监控
    kill $monitor_pid 2>/dev/null
    wait $monitor_pid 2>/dev/null
    
    echo "" >&2
    echo -e "${GREEN}测试完成!${NC}" >&2
    echo "" >&2
    
    # 返回排序结果
    if [[ -s "$results_file" ]]; then
        sort -n "$results_file"
        local exit_code=0
    else
        local exit_code=1
    fi
    
    # 清理临时文件
    rm -f "$results_file" "$progress_file"
    return $exit_code
}

# 显示测试结果（优化版本）
show_test_results() {
    echo -e "${CYAN}域名延迟测试结果 (前10名):${NC}"
    echo ""
    
    # 清理过期缓存
    cleanup_cache
    
    local results=$(test_all_domains_concurrent)
    
    if [[ -z "$results" ]]; then
        echo -e "${RED}所有域名测试失败，请检查网络连接${NC}"
        return 1
    fi
    
    printf "%-5s %-30s %-8s %s\n" "排名" "域名" "延迟(ms)" "评级"
    echo "------------------------------------------------"
    
    local rank=1
    echo "$results" | head -n 10 | while read -r latency domain; do
        # 延迟评级
        local rating
        if [[ $latency -lt 50 ]]; then
            rating="${GREEN}极佳${NC}"
        elif [[ $latency -lt 100 ]]; then
            rating="${GREEN}优秀${NC}"
        elif [[ $latency -lt 200 ]]; then
            rating="${YELLOW}良好${NC}"
        elif [[ $latency -lt 500 ]]; then
            rating="${YELLOW}一般${NC}"
        else
            rating="${RED}较差${NC}"
        fi
        
        printf "%-5d %-30s %-8d %b\n" "$rank" "$domain" "$latency" "$rating"
        rank=$((rank + 1))
    done
}

# 获取最优域名（优化版本）
get_best_domain() {
    local best_result=$(test_all_domains_concurrent_silent | head -n 1)
    if [[ -n "$best_result" ]]; then
        local domain=$(echo "$best_result" | awk '{print $2}')
        echo "https://$domain/"
    else
        echo "https://news.ycombinator.com/"
    fi
}

# 获取最优域名名称
get_best_domain_name() {
    local best_result=$(test_all_domains_concurrent_silent | head -n 1)
    if [[ -n "$best_result" ]]; then
        echo "$best_result" | awk '{print $2}'
    else
        echo "cdn.jsdelivr.net"
    fi
}

# 域名稳定性测试（新增功能）
test_domain_stability() {
    local domain=$1
    local test_count=${2:-5}
    local results=()
    
    echo -e "${BLUE}测试域名 $domain 的稳定性 (${test_count}次)...${NC}"
    
    for ((i=1; i<=test_count; i++)); do
        printf "\r测试进度: $i/$test_count"
        if result=$(test_domain_latency "$domain" 3 1); then
            local latency=$(echo "$result" | awk '{print $1}')
            results+=($latency)
        fi
        sleep 0.5
    done
    
    echo ""
    
    if [[ ${#results[@]} -gt 0 ]]; then
        local min_latency=$(printf '%s\n' "${results[@]}" | sort -n | head -1)
        local max_latency=$(printf '%s\n' "${results[@]}" | sort -n | tail -1)
        local avg_latency=$(printf '%s\n' "${results[@]}" | awk '{sum+=$1} END {printf "%.0f", sum/NR}')
        local success_rate=$(( (${#results[@]} * 100) / test_count ))
        
        echo -e "${GREEN}稳定性测试结果:${NC}"
        echo "成功率: ${success_rate}%"
        echo "最小延迟: ${min_latency}ms"
        echo "最大延迟: ${max_latency}ms"
        echo "平均延迟: ${avg_latency}ms"
        
        # 稳定性评级
        local stability_variance=$((max_latency - min_latency))
        if [[ $stability_variance -lt 50 ]] && [[ $success_rate -eq 100 ]]; then
            echo -e "稳定性评级: ${GREEN}极佳${NC}"
        elif [[ $stability_variance -lt 100 ]] && [[ $success_rate -ge 80 ]]; then
            echo -e "稳定性评级: ${GREEN}良好${NC}"
        elif [[ $success_rate -ge 60 ]]; then
            echo -e "稳定性评级: ${YELLOW}一般${NC}"
        else
            echo -e "稳定性评级: ${RED}较差${NC}"
        fi
    else
        echo -e "${RED}稳定性测试失败${NC}"
    fi
}

# 交互式域名选择（优化版本）
interactive_domain_selection() {
    echo -e "${BLUE}域名延迟测试和选择${NC}"
    echo ""

    echo -e "${BLUE}正在测试域名延迟，请稍候...${NC}"
    local results=$(test_all_domains_concurrent_silent | head -n 15)

    if [[ -z "$results" ]]; then
        echo -e "${RED}域名测试失败，使用默认域名${NC}"
        echo "默认域名: news.ycombinator.com"
        read -p "按回车键继续..."
        return
    fi

    echo ""
    echo -e "${CYAN}可用域名列表:${NC}"
    echo ""
    printf "%-5s %-30s %-8s %s\n" "编号" "域名" "延迟(ms)" "评级"
    echo "------------------------------------------------"

    local domains_array=()
    local index=1

    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local latency=$(echo "$line" | awk '{print $1}')
            local domain=$(echo "$line" | awk '{print $2}')

            if [[ "$latency" =~ ^[0-9]+$ ]] && [[ -n "$domain" ]] && [[ ! "$domain" =~ [[:space:]] ]]; then
                # 延迟评级
                local rating
                if [[ $latency -lt 100 ]]; then
                    rating="${GREEN}优秀${NC}"
                elif [[ $latency -lt 200 ]]; then
                    rating="${YELLOW}良好${NC}"
                else
                    rating="${RED}一般${NC}"
                fi
                
                printf "%-5d %-30s %-8d %b\n" "$index" "$domain" "$latency" "$rating"
                domains_array+=("$domain")
                index=$((index + 1))
            fi
        fi
    done <<< "$results"
    
    echo ""
    echo -e "${GREEN}0.${NC} 使用默认域名 (news.ycombinator.com)"
    echo -e "${BLUE}s.${NC} 测试选定域名的稳定性"
    echo ""
    echo -n -e "${BLUE}请选择域名编号 [0-${#domains_array[@]}/s]: ${NC}"
    read -r choice
    
    if [[ "$choice" == "s" ]]; then
        echo -n -e "${BLUE}请输入要测试稳定性的域名编号: ${NC}"
        read -r stability_choice
        if [[ "$stability_choice" =~ ^[0-9]+$ ]] && [[ $stability_choice -ge 1 ]] && [[ $stability_choice -le ${#domains_array[@]} ]]; then
            local test_domain="${domains_array[$((stability_choice-1))]}"
            test_domain_stability "$test_domain"
        fi
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#domains_array[@]} ]]; then
        local selected_domain="${domains_array[$((choice-1))]}"
        echo -e "${GREEN}已选择: $selected_domain${NC}"
        
        if [[ -f "$CONFIG_PATH" ]]; then
            echo -n -e "${BLUE}是否更新当前配置文件中的伪装域名? [y/N]: ${NC}"
            read -r update_config
            if [[ $update_config =~ ^[Yy]$ ]]; then
                update_masquerade_domain "$selected_domain"
            fi
        fi
    else
        echo -e "${BLUE}使用默认域名: news.ycombinator.com${NC}"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 更新配置文件中的伪装域名（增加验证）
update_masquerade_domain() {
    local new_domain=$1
    local new_url="https://$new_domain/"
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo -e "${RED}配置文件不存在${NC}"
        return 1
    fi
    
    # 验证域名格式
    if [[ ! "$new_domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
        echo -e "${RED}域名格式无效${NC}"
        return 1
    fi
    
    # 备份配置文件（带校验和）
    local backup_file="$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_PATH" "$backup_file"
    sha256sum "$CONFIG_PATH" > "${backup_file}.checksum" 2>/dev/null
    
    # 更新伪装URL
    if sed -i.bak "s|url: https://.*|url: $new_url|g" "$CONFIG_PATH"; then
        echo -e "${GREEN}配置文件已更新${NC}"
        echo -e "${YELLOW}新的伪装域名: $new_url${NC}"
        echo -e "${BLUE}备份文件: $backup_file${NC}"
        
        # 验证配置文件语法
        if command -v hysteria >/dev/null && hysteria server --config "$CONFIG_PATH" --check 2>/dev/null; then
            echo -e "${GREEN}配置文件语法验证通过${NC}"
        else
            echo -e "${YELLOW}警告: 无法验证配置文件语法${NC}"
        fi
        
        # 询问是否重启服务
        if systemctl is-active --quiet hysteria-server.service 2>/dev/null; then
            echo -n -e "${BLUE}是否重启服务以应用新配置? [y/N]: ${NC}"
            read -r restart_service
            if [[ $restart_service =~ ^[Yy]$ ]]; then
                if systemctl restart hysteria-server.service; then
                    echo -e "${GREEN}服务已重启${NC}"
                else
                    echo -e "${RED}服务重启失败，正在恢复配置...${NC}"
                    cp "$backup_file" "$CONFIG_PATH"
                fi
            fi
        fi
    else
        echo -e "${RED}配置文件更新失败${NC}"
        rm -f "$backup_file" "${backup_file}.checksum"
        return 1
    fi
}

# 批量测试自定义域名（优化版本）
test_custom_domains() {
    echo -e "${BLUE}测试自定义域名${NC}"
    echo ""
    echo "请输入要测试的域名，每行一个，输入空行结束:"
    echo "提示: 可以输入 'file:域名文件路径' 来从文件加载域名"
    
    local custom_domains=()
    while true; do
        echo -n "域名: "
        read -r domain
        if [[ -z "$domain" ]]; then
            break
        fi
        
        # 支持从文件读取域名
        if [[ "$domain" =~ ^file: ]]; then
            local file_path="${domain#file:}"
            if [[ -f "$file_path" ]]; then
                while IFS= read -r line; do
                    [[ -n "$line" ]] && custom_domains+=("$line")
                done < "$file_path"
                echo "已从 $file_path 加载 $((${#custom_domains[@]})) 个域名"
            else
                echo -e "${RED}文件不存在: $file_path${NC}"
            fi
        else
            custom_domains+=("$domain")
        fi
    done
    
    if [[ ${#custom_domains[@]} -eq 0 ]]; then
        echo -e "${YELLOW}未输入任何域名${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    echo ""
    echo -e "${BLUE}开始并发测试 ${#custom_domains[@]} 个自定义域名...${NC}"
    echo ""
    printf "%-30s %-10s %s\n" "域名" "延迟(ms)" "状态"
    echo "------------------------------------------------"
    
    local results_file=$(mktemp)
    local network_quality=$(detect_network_quality)
    local timeout_val=$(get_adaptive_timeout "$network_quality")
    
    # 并发测试自定义域名
    for domain in "${custom_domains[@]}"; do
        while [[ $(jobs -r | wc -l) -ge $MAX_CONCURRENT_JOBS ]]; do
            sleep 0.1
        done
        
        (
            if result=$(test_domain_latency "$domain" "$timeout_val" 1); then
                local latency=$(echo "$result" | awk '{print $1}')
                printf "%-30s %-10d %s\n" "$domain" "$latency" "${GREEN}成功${NC}"
                echo "$result" >> "$results_file"
            else
                printf "%-30s %-10s %s\n" "$domain" "-" "${RED}失败${NC}"
            fi
        ) &
    done
    
    wait
    
    if [[ -s "$results_file" ]]; then
        echo ""
        local best=$(sort -n "$results_file" | head -n 1)
        local best_domain=$(echo "$best" | awk '{print $2}')
        local best_latency=$(echo "$best" | awk '{print $1}')
        echo -e "${GREEN}最优域名: $best_domain (${best_latency}ms)${NC}"
        
        echo ""
        echo -n -e "${BLUE}是否使用最优域名更新配置? [y/N]: ${NC}"
        read -r update_choice
        if [[ $update_choice =~ ^[Yy]$ ]]; then
            update_masquerade_domain "$best_domain"
        fi
    fi
    
    rm -f "$results_file"
    echo ""
    read -p "按回车键继续..."
}

# 缓存管理功能（新增）
manage_cache() {
    echo -e "${BLUE}域名测试缓存管理${NC}"
    echo ""
    
    local cache_count=$(find "$CACHE_DIR" -type f 2>/dev/null | wc -l)
    local cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    
    echo "缓存目录: $CACHE_DIR"
    echo "缓存文件数: $cache_count"
    echo "缓存大小: ${cache_size:-0}"
    echo ""
    
    echo -e "${GREEN}1.${NC} 清理过期缓存"
    echo -e "${GREEN}2.${NC} 清理所有缓存"
    echo -e "${GREEN}3.${NC} 查看缓存详情"
    echo -e "${RED}0.${NC} 返回"
    echo ""
    echo -n -e "${BLUE}请选择操作 [0-3]: ${NC}"
    read -r choice
    
    case $choice in
        1)
            cleanup_cache
            echo -e "${GREEN}过期缓存已清理${NC}"
            ;;
        2)
            rm -rf "$CACHE_DIR"/*
            echo -e "${GREEN}所有缓存已清理${NC}"
            ;;
        3)
            echo -e "${BLUE}缓存文件列表:${NC}"
            find "$CACHE_DIR" -type f -exec ls -lh {} \; 2>/dev/null
            ;;
        0)
            return
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
}

# 主测试函数（优化版本）
test_masquerade_domains() {
    while true; do
        echo -e "${BLUE}伪装域名测试 - 优化版本${NC}"
        echo ""
        echo -e "${GREEN}1.${NC} 测试预设域名并显示结果"
        echo -e "${GREEN}2.${NC} 交互式选择域名"
        echo -e "${GREEN}3.${NC} 测试自定义域名"
        echo -e "${GREEN}4.${NC} 快速获取最优域名"
        echo -e "${GREEN}5.${NC} 域名稳定性测试"
        echo -e "${GREEN}6.${NC} 缓存管理"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-6]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                show_test_results
                echo ""
                read -p "按回车键继续..."
                ;;
            2)
                interactive_domain_selection
                ;;
            3)
                test_custom_domains
                ;;
            4)
                echo -e "${BLUE}正在获取最优域名...${NC}"
                best_domain=$(get_best_domain_name)
                best_url=$(get_best_domain)
                echo -e "${GREEN}最优域名: $best_domain${NC}"
                echo -e "${GREEN}完整URL: $best_url${NC}"
                echo ""
                read -p "按回车键继续..."
                ;;
            5)
                echo -n -e "${BLUE}请输入要测试的域名: ${NC}"
                read -r test_domain
                if [[ -n "$test_domain" ]]; then
                    test_domain_stability "$test_domain"
                fi
                echo ""
                read -p "按回车键继续..."
                ;;
            6)
                manage_cache
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选项${NC}"
                sleep 1
                ;;
        esac
    done
}
