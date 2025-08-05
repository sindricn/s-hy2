#!/bin/bash

# 伪装域名测试脚本

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

# 测试单个域名延迟
test_domain_latency() {
    local domain=$1
    local timeout=${2:-3}
    
    local start_time=$(date +%s%3N)
    
    if timeout $timeout openssl s_client -connect "$domain:443" -servername "$domain" </dev/null &>/dev/null; then
        local end_time=$(date +%s%3N)
        local latency=$((end_time - start_time))
        echo "$latency $domain"
        return 0
    else
        return 1
    fi
}

# 测试所有域名并排序
test_all_domains() {
    local results=()
    local total=${#DOMAINS[@]}
    local current=0
    
    echo -e "${BLUE}正在测试 $total 个域名的延迟...${NC}"
    echo ""
    
    for domain in "${DOMAINS[@]}"; do
        current=$((current + 1))
        printf "\r${BLUE}进度: $current/$total - 测试 $domain${NC}"
        
        if result=$(test_domain_latency "$domain" 3); then
            results+=("$result")
        fi
    done
    
    echo ""
    echo ""
    
    if [[ ${#results[@]} -eq 0 ]]; then
        echo -e "${RED}所有域名测试失败，请检查网络连接${NC}"
        return 1
    fi
    
    # 排序结果
    printf '%s\n' "${results[@]}" | sort -n
}

# 显示测试结果
show_test_results() {
    echo -e "${CYAN}域名延迟测试结果 (前10名):${NC}"
    echo ""
    printf "%-5s %-30s %s\n" "排名" "域名" "延迟(ms)"
    echo "----------------------------------------"
    
    local rank=1
    test_all_domains | head -n 10 | while read -r latency domain; do
        printf "%-5d %-30s %d ms\n" "$rank" "$domain" "$latency"
        rank=$((rank + 1))
    done
}

# 获取最优域名 (返回完整URL)
get_best_domain() {
    local best_result=$(test_all_domains | head -n 1)
    if [[ -n "$best_result" ]]; then
        local domain=$(echo "$best_result" | awk '{print $2}')
        echo "https://$domain/"
    else
        echo "https://news.ycombinator.com/"
    fi
}

# 获取最优域名名称
get_best_domain_name() {
    local best_result=$(test_all_domains | head -n 1)
    if [[ -n "$best_result" ]]; then
        echo "$best_result" | awk '{print $2}'
    else
        echo "cdn.jsdelivr.net"
    fi
}

# 交互式域名选择
interactive_domain_selection() {
    echo -e "${BLUE}域名延迟测试和选择${NC}"
    echo ""
    
    # 显示测试结果
    local results=$(test_all_domains | head -n 10)
    
    if [[ -z "$results" ]]; then
        echo -e "${RED}域名测试失败，使用默认域名${NC}"
        echo "默认域名: news.ycombinator.com"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${CYAN}可用域名列表:${NC}"
    echo ""
    printf "%-5s %-30s %s\n" "编号" "域名" "延迟(ms)"
    echo "----------------------------------------"
    
    local domains_array=()
    local index=1
    
    while read -r latency domain; do
        printf "%-5d %-30s %d ms\n" "$index" "$domain" "$latency"
        domains_array+=("$domain")
        index=$((index + 1))
    done <<< "$results"
    
    echo ""
    echo -e "${GREEN}0.${NC} 使用默认域名 (news.ycombinator.com)"
    echo ""
    echo -n -e "${BLUE}请选择域名编号 [0-${#domains_array[@]}]: ${NC}"
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#domains_array[@]} ]]; then
        local selected_domain="${domains_array[$((choice-1))]}"
        echo -e "${GREEN}已选择: $selected_domain${NC}"
        
        # 更新配置文件中的伪装域名
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

# 更新配置文件中的伪装域名
update_masquerade_domain() {
    local new_domain=$1
    local new_url="https://$new_domain/"
    
    if [[ -f "$CONFIG_PATH" ]]; then
        # 备份配置文件
        cp "$CONFIG_PATH" "$CONFIG_PATH.backup.$(date +%Y%m%d_%H%M%S)"
        
        # 更新伪装URL
        sed -i "s|url: https://.*|url: $new_url|g" "$CONFIG_PATH"
        
        echo -e "${GREEN}配置文件已更新${NC}"
        echo -e "${YELLOW}新的伪装域名: $new_url${NC}"
        
        # 询问是否重启服务
        if systemctl is-active --quiet hysteria-server.service; then
            echo -n -e "${BLUE}是否重启服务以应用新配置? [y/N]: ${NC}"
            read -r restart_service
            if [[ $restart_service =~ ^[Yy]$ ]]; then
                systemctl restart hysteria-server.service
                echo -e "${GREEN}服务已重启${NC}"
            fi
        fi
    else
        echo -e "${RED}配置文件不存在${NC}"
    fi
}

# 批量测试自定义域名
test_custom_domains() {
    echo -e "${BLUE}测试自定义域名${NC}"
    echo ""
    echo "请输入要测试的域名，每行一个，输入空行结束:"
    
    local custom_domains=()
    while true; do
        echo -n "域名: "
        read -r domain
        if [[ -z "$domain" ]]; then
            break
        fi
        custom_domains+=("$domain")
    done
    
    if [[ ${#custom_domains[@]} -eq 0 ]]; then
        echo -e "${YELLOW}未输入任何域名${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    echo ""
    echo -e "${BLUE}测试结果:${NC}"
    echo ""
    printf "%-30s %s\n" "域名" "延迟(ms)"
    echo "----------------------------------------"
    
    local results=()
    for domain in "${custom_domains[@]}"; do
        if result=$(test_domain_latency "$domain" 5); then
            local latency=$(echo "$result" | awk '{print $1}')
            printf "%-30s %d ms\n" "$domain" "$latency"
            results+=("$result")
        else
            printf "%-30s %s\n" "$domain" "超时/失败"
        fi
    done
    
    if [[ ${#results[@]} -gt 0 ]]; then
        echo ""
        local best=$(printf '%s\n' "${results[@]}" | sort -n | head -n 1)
        local best_domain=$(echo "$best" | awk '{print $2}')
        local best_latency=$(echo "$best" | awk '{print $1}')
        echo -e "${GREEN}最优域名: $best_domain (${best_latency}ms)${NC}"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 主测试函数
test_masquerade_domains() {
    while true; do
        echo -e "${BLUE}伪装域名测试${NC}"
        echo ""
        echo -e "${GREEN}1.${NC} 测试预设域名并显示结果"
        echo -e "${GREEN}2.${NC} 交互式选择域名"
        echo -e "${GREEN}3.${NC} 测试自定义域名"
        echo -e "${GREEN}4.${NC} 快速获取最优域名"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-4]: ${NC}"
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
