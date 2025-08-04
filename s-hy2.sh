#!/bin/bash

# Copyright (c) 2025 Your Name
# Licensed under the MIT License

# 检查是否安装了 whiptail
if ! command -v whiptail &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y whiptail
fi

# 函数：生成随机密码
generate_password() {
    openssl rand -base64 12 | tr -d '/+='
}

# 函数：检查域名延迟并返回最低延迟域名
check_domain_latency() {
    domains=(
        www.cloudflare.com www.apple.com www.microsoft.com www.bing.com www.google.com
        developer.apple.com www.gstatic.com fonts.gstatic.com fonts.googleapis.com
        res-1.cdn.office.net res.public.onecdn.static.microsoft static.cloud.coveo.com
        aws.amazon.com www.aws.com cloudfront.net d1.awsstatic.com
        cdn.jsdelivr.net cdn.jsdelivr.org polyfill-fastly.io
        beacon.gtv-pub.com s7mbrstream.scene7.com cdn.bizibly.com
        www.sony.com www.nytimes.com www.w3.org www.wikipedia.org
        ajax.cloudflare.com www.mozilla.org www.intel.com
        api.snapchat.com images.unsplash.com
        edge-mqtt.facebook.com video.xx.fbcdn.net
        gstatic.cn
    )

    latency_output=""
    for d in "${domains[@]}"; do
        t1=$(date +%s%3N)
        timeout 1 openssl s_client -connect "$d:443" -servername "$d" </dev/null &>/dev/null
        if [ $? -eq 0 ]; then
            t2=$(date +%s%3N)
            latency_output+="$((t2 - t1)) $d\n"
        fi
    done
    echo -e "$latency_output" | sort -n | head -n 1 | awk '{print $2}'
}

# 函数：获取默认网卡
get_default_interface() {
    ip -o link | awk '$2 != "lo:" {print $2}' | sed 's/://' | head -n 1
}

# 函数：创建或更新配置文件
create_config_file() {
    local config_file="/etc/hysteria/config.yaml"
    sudo mkdir -p /etc/hysteria
    sudo bash -c "cat > $config_file" <<EOF
listen: :$port

$tls_config

auth:
  type: password
  password: $password

$obfs_config

masquerade:
  type: proxy
  proxy:
    url: https://$masquerade_domain
    rewriteHost: true
EOF
    sudo chown hysteria:hysteria $config_file
    sudo chmod 644 $config_file
}

# 函数：生成节点连接和订阅连接
generate_connection_info() {
    local node_url="hysteria2://$password@$masquerade_domain:$port/?insecure=1#Hysteria2"
    local subscription_url=$(echo -n "$node_url" | base64 -w 0)
    echo -e "节点连接: $node_url\n订阅连接: $subscription_url"
}

# 函数：清理配置文件和服务
cleanup_files() {
    whiptail --title "清理确认" --yesno "是否删除配置文件和用户数据？" 8 60 --yes-button "是" --no-button "否"
    if [ $? -eq 0 ]; then
        sudo rm -rf /etc/hysteria
        sudo userdel -r hysteria 2>/dev/null
        sudo rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service
        sudo rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service
        sudo systemctl daemon-reload
        whiptail --title "清理完成" --msgbox "配置文件和用户数据已删除。" 8 60
    fi
}

# 函数：检查配置文件中是否存在某配置
check_config_exists() {
    local config_file="/etc/hysteria/config.yaml"
    local pattern="$1"
    if [ -f "$config_file" ] && grep -q "$pattern" "$config_file"; then
        return 0
    else
        return 1
    fi
}

# 函数：注释或删除配置块
comment_out_config() {
    local config_file="/etc/hysteria/config.yaml"
    local start_pattern="$1"
    local temp_file=$(mktemp)
    awk -v start="$start_pattern" '
        BEGIN { in_block=0 }
        /^$/ { if (in_block) in_block=0 }
        /^'"$start_pattern"'/ { in_block=1; print "#" $0; next }
        in_block { print "#" $0; next }
        { print }
    ' "$config_file" > "$temp_file"
    sudo mv "$temp_file" "$config_file"
    sudo chown hysteria:hysteria "$config_file"
    sudo chmod 644 "$config_file"
}

# 函数：一键快速配置
quick_config() {
    port="443"
    password=$(generate_password)
    obfs_password=$(generate_password)
    masquerade_domain=$(check_domain_latency)
    interface=$(get_default_interface)
    port_range="20000:50000"

    # 生成自签名证书
    whiptail --title "生成证书" --msgbox "正在为域名 $masquerade_domain 生成自签名证书..." 8 60
    sudo mkdir -p /etc/hysteria
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /etc/hysteria/server.key \
        -out /etc/hysteria/server.crt \
        -subj "/CN=$masquerade_domain" \
        -days 3650
    sudo chown hysteria:hysteria /etc/hysteria/server.{key,crt}
    sudo chmod 644 /etc/hysteria/server.{key,crt}
    tls_config="tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key"

    # 注释掉 ACME 配置（如果存在）
    if check_config_exists "acme:"; then
        comment_out_config "acme:"
    fi

    # 设置混淆
    obfs_config="obfs:
  type: salamander
  salamander:
    password: $obfs_password"

    # 设置端口跳跃
    sudo iptables -t nat -A PREROUTING -i "$interface" -p udp --dport "$port_range" -j REDIRECT --to-ports "$port"

    # 创建配置文件
    create_config_file

    # 启用并启动服务
    sudo systemctl enable --now hysteria-server.service
    sudo systemctl restart hysteria-server.service

    # 显示状态和连接信息
    status=$(sudo systemctl status hysteria-server.service)
    connection_info=$(generate_connection_info)
    whiptail --title "配置完成" --msgbox "配置完成！\n密码: $password\n伪装域名: $masquerade_domain\n混淆密码: $obfs_password\n网卡: $interface\n端口范围: $port_range\n\n$connection_info\n\n服务状态:\n$status" 25 80
}

# 函数：手动配置
manual_config() {
    # 证书配置
    cert_choice=$(whiptail --title "证书类型" --menu "选择证书类型：" 10 60 2 \
        "1" "ACME（自动域名证书）" \
        "2" "自签名证书" 3>&1 1>&2 2>&3)

    if [ "$cert_choice" = "1" ]; then
        domain=$(whiptail --title "域名" --inputbox "请输入您的域名（例如：your.domain.net）：" 8 60 3>&1 1>&2 2>&3)
        email=$(whiptail --title "邮箱" --inputbox "请输入您的邮箱（例如：your@email.com）：" 8 60 3>&1 1>&2 2>&3)
        tls_config="acme:
  domains:
    - $domain
  email: $email"
        # 注释掉 tls 配置（如果存在）
        if check_config_exists "tls:"; then
            comment_out_config "tls:"
        fi
    elif [ "$cert_choice" = "2" ]; then
        cert_domain=$(whiptail --title "证书域名" --inputbox "请输入自签名证书的域名（例如：cdn.jsdelivr.net）：" 8 60 3>&1 1>&2 2>&3)
        whiptail --title "生成证书" --msgbox "正在生成自签名证书..." 8 60
        sudo mkdir -p /etc/hysteria
        openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
            -keyout /etc/hysteria/server.key \
            -out /etc/hysteria/server.crt \
            -subj "/CN=$cert_domain" \
            -days 3650
        sudo chown hysteria:hysteria /etc/hysteria/server.{key,crt}
        sudo chmod 644 /etc/hysteria/server.{key,crt}
        tls_config="tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key"
        # 注释掉 acme 配置（如果存在）
        if check_config_exists "acme:"; then
            comment_out_config "acme:"
        fi
    fi

    # 密码配置
    password=$(generate_password)
    if whiptail --title "密码" --yesno "使用默认密码（$password）？" 8 60 --yes-button "是" --no-button "否"; then
        : # 保留默认密码
    else
        password=$(whiptail --title "自定义密码" --inputbox "请输入自定义密码：" 8 60 3>&1 1>&2 2>&3)
    fi

    # 伪装域名配置
    if whiptail --title "伪装域名" --yesno "配置伪装域名？" 8 60 --yes-button "是" --no-button "否"; then
        domain_choice=$(whiptail --title "伪装域名" --menu "配置伪装域名：" 12 60 3 \
            "1" "使用默认（news.ycombinator.com）" \
            "2" "从低延迟域名中选择" \
            "3" "输入自定义域名" 3>&1 1>&2 2>&3)
        masquerade_domain="news.ycombinator.com"
        if [ "$domain_choice" = "2" ]; then
            latency_results=$(check_domain_latency)
            masquerade_domain=$(whiptail --title "选择域名" --menu "请选择一个域名：\n$latency_results" 20 60 10 \
                $(echo "$latency_results" | awk '{print $1 " " $1}') 3>&1 1>&2 2>&3)
        elif [ "$domain_choice" = "3" ]; then
            masquerade_domain=$(whiptail --title "自定义域名" --inputbox "请输入自定义伪装域名：" 8 60 3>&1 1>&2 2>&3)
        fi
    else
        masquerade_domain="news.ycombinator.com"
    fi

    # 端口配置
    port="443"
    if whiptail --title "端口" --yesno "使用默认端口 443？" 8 60 --yes-button "是" --no-button "否"; then
        : # 保留默认端口
    else
        port=$(whiptail --title "自定义端口" --inputbox "请输入自定义端口：" 8 60 3>&1 1>&2 2>&3)
    fi

    # 混淆配置
    obfs_config=""
    if whiptail --title "混淆" --yesno "启用混淆？" 8 60 --yes-button "是" --no-button "否"; then
        obfs_password=$(generate_password)
        if whiptail --title "混淆密码" --yesno "使用默认混淆密码（$obfs_password）？" 8 60 --yes-button "是" --no-button "否"; then
            : # 保留默认混淆密码
        else
            obfs_password=$(whiptail --title "自定义混淆密码" --inputbox "请输入自定义混淆密码：" 8 60 3>&1 1>&2 2>&3)
        fi
        obfs_config="obfs:
  type: salamander
  salamander:
    password: $obfs_password"
    fi

    # 端口跳跃配置
    if whiptail --title "端口跳跃" --yesno "启用端口跳跃？" 8 60 --yes-button "是" --no-button "否"; then
        interface=$(get_default_interface)
        if whiptail --title "网络接口" --yesno "使用默认网卡（$interface）？" 8 60 --yes-button "是" --no-button "否"; then
            : # 保留默认网卡
        else
            interface=$(whiptail --title "网络接口" --inputbox "请输入网络接口：" 8 60 3>&1 1>&2 2>&3)
        fi
        port_range="20000:50000"
        if whiptail --title "端口范围" --yesno "使用默认端口范围（20000:50000）？" 8 60 --yes-button "是" --no-button "否"; then
            : # 保留默认端口范围
        else
            port_range=$(whiptail --title "端口范围" --inputbox "请输入端口范围（例如：20000:50000）：" 8 60 3>&1 1>&2 2>&3)
        fi
        sudo iptables -t nat -A PREROUTING -i "$interface" -p udp --dport "$port_range" -j REDIRECT --to-ports "$port"
    fi

    # 创建配置文件
    create_config_file

    # 启用并启动服务
    sudo systemctl enable --now hysteria-server.service
    sudo systemctl restart hysteria-server.service

    # 显示状态和连接信息
    status=$(sudo systemctl status hysteria-server.service)
    connection_info=$(generate_connection_info)
    whiptail --title "配置完成" --msgbox "配置完成！\n$connection_info\n\n服务状态:\n$status" 25 80
}

# 函数：修改配置
modify_config() {
    while true; do
        modify_choice=$(whiptail --title "修改配置" --menu "请选择要修改的配置项：" 15 60 4 \
            "1" "证书配置" \
            "2" "伪装域名配置" \
            "3" "混淆密码配置" \
            "4" "端口跳跃配置" 3>&1 1>&2 2>&3)

        case $modify_choice in
            1)
                # 证书配置
                if check_config_exists "acme:" || check_config_exists "tls:"; then
                    action=$(whiptail --title "证书配置" --menu "当前存在证书配置，请选择操作：" 10 60 2 \
                        "1" "修改证书配置" \
                        "2" "删除证书配置" 3>&1 1>&2 2>&3)
                    if [ "$action" = "2" ]; then
                        if check_config_exists "acme:"; then
                            comment_out_config "acme:"
                        fi
                        if check_config_exists "tls:"; then
                            comment_out_config "tls:"
                        fi
                        whiptail --title "删除完成" --msgbox "证书配置已删除，请重新运行配置或重启服务。" 8 60
                        continue
                    fi
                fi
                cert_choice=$(whiptail --title "证书类型" --menu "选择证书类型：" 10 60 2 \
                    "1" "ACME（自动域名证书）" \
                    "2" "自签名证书" 3>&1 1>&2 2>&3)
                if [ "$cert_choice" = "1" ]; then
                    domain=$(whiptail --title "域名" --inputbox "请输入您的域名（例如：your.domain.net）：" 8 60 3>&1 1>&2 2>&3)
                    email=$(whiptail --title "邮箱" --inputbox "请输入您的邮箱（例如：your@email.com）：" 8 60 3>&1 1>&2 2>&3)
                    tls_config="acme:
  domains:
    - $domain
  email: $email"
                    if check_config_exists "tls:"; then
                        comment_out_config "tls:"
                    fi
                elif [ "$cert_choice" = "2" ]; then
                    cert_domain=$(whiptail --title "证书域名" --inputbox "请输入自签名证书的域名（例如：cdn.jsdelivr.net）：" 8 60 3>&1 1>&2 2>&3)
                    whiptail --title "生成证书" --msgbox "正在生成自签名证书..." 8 60
                    sudo mkdir -p /etc/hysteria
                    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
                        -keyout /etc/hysteria/server.key \
                        -out /etc/hysteria/server.crt \
                        -subj "/CN=$cert_domain" \
                        -days 3650
                    sudo chown hysteria:hysteria /etc/hysteria/server.{key,crt}
                    sudo chmod 644 /etc/hysteria/server.{key,crt}
                    tls_config="tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key"
                    if check_config_exists "acme:"; then
                        comment_out_config "acme:"
                    fi
                fi
                create_config_file
                sudo systemctl restart hysteria-server.service
                whiptail --title "修改完成" --msgbox "证书配置已更新，请检查服务状态。" 8 60
            ;;
            2)
                # 伪装域名配置
                if check_config_exists "masquerade:"; then
                    action=$(whiptail --title "伪装域名配置" --menu "当前存在伪装域名配置，请选择操作：" 10 60 2 \
                        "1" "修改伪装域名" \
                        "2" "删除伪装域名" 3>&1 1>&2 2>&3)
                    if [ "$action" = "2" ]; then
                        comment_out_config "masquerade:"
                        whiptail --title "删除完成" --msgbox "伪装域名配置已删除，请重新运行配置或重启服务。" 8 60
                        continue
                    fi
                fi
                domain_choice=$(whiptail --title "伪装域名" --menu "配置伪装域名：" 12 60 3 \
                    "1" "使用默认（news.ycombinator.com）" \
                    "2" "从低延迟域名中选择" \
                    "3" "输入自定义域名" 3>&1 1>&2 2>&3)
                masquerade_domain="news.ycombinator.com"
                if [ "$domain_choice" = "2" ]; then
                    latency_results=$(check_domain_latency)
                    masquerade_domain=$(whiptail --title "选择域名" --menu "请选择一个域名：\n$latency_results" 20 60 10 \
                        $(echo "$latency_results" | awk '{print $1 " " $1}') 3>&1 1>&2 2>&3)
                elif [ "$domain_choice" = "3" ]; then
                    masquerade_domain=$(whiptail --title "自定义域名" --inputbox "请输入自定义伪装域名：" 8 60 3>&1 1>&2 2>&3)
                fi
                create_config_file
                sudo systemctl restart hysteria-server.service
                whiptail --title "修改完成" --msgbox "伪装域名配置已更新，请检查服务状态。" 8 60
            ;;
            3)
                # 混淆密码配置
                if check_config_exists "obfs:"; then
                    action=$(whiptail --title "混淆密码配置" --menu "当前存在混淆配置，请选择操作：" 10 60 2 \
                        "1" "修改混淆密码" \
                        "2" "删除混淆配置" 3>&1 1>&2 2>&3)
                    if [ "$action" = "2" ]; then
                        comment_out_config "obfs:"
                        obfs_config=""
                        create_config_file
                        sudo systemctl restart hysteria-server.service
                        whiptail --title "删除完成" --msgbox "混淆配置已删除，请检查服务状态。" 8 60
                        continue
                    fi
                fi
                obfs_password=$(generate_password)
                if whiptail --title "混淆密码" --yesno "使用默认混淆密码（$obfs_password）？" 8 60 --yes-button "是" --no-button "否"; then
                    : # 保留默认混淆密码
                else
                    obfs_password=$(whiptail --title "自定义混淆密码" --inputbox "请输入自定义混淆密码：" 8 60 3>&1 1>&2 2>&3)
                fi
                obfs_config="obfs:
  type: salamander
  salamander:
    password: $obfs_password"
                create_config_file
                sudo systemctl restart hysteria-server.service
                whiptail --title "修改完成" --msgbox "混淆密码配置已更新，请检查服务状态。" 8 60
            ;;
            4)
                # 端口跳跃配置
                if check_config_exists "iptables.*PREROUTING"; then
                    action=$(whiptail --title "端口跳跃配置" --menu "当前存在端口跳跃配置，请选择操作：" 10 60 2 \
                        "1" "修改端口跳跃" \
                        "2" "删除端口跳跃" 3>&1 1>&2 2>&3)
                    if [ "$action" = "2" ]; then
                        sudo iptables -t nat -F PREROUTING
                        whiptail --title "删除完成" --msgbox "端口跳跃配置已删除，请检查服务状态。" 8 60
                        continue
                    fi
                fi
                interface=$(get_default_interface)
                if whiptail --title "网络接口" --yesno "使用默认网卡（$interface）？" 8 60 --yes-button "是" --no-button "否"; then
                    : # 保留默认网卡
                else
                    interface=$(whiptail --title "网络接口" --inputbox "请输入网络接口：" 8 60 3>&1 1>&2 2>&3)
                fi
                port_range="20000:50000"
                if whiptail --title "端口范围" --yesno "使用默认端口范围（20000:50000）？" 8 60 --yes-button "是" --no-button "否"; then
                    : # 保留默认端口范围
                else
                    port_range=$(whiptail --title "端口范围" --inputbox "请输入端口范围（例如：20000:50000）：" 8 60 3>&1 1>&2 2>&3)
                fi
                sudo iptables -t nat -A PREROUTING -i "$interface" -p udp --dport "$port_range" -j REDIRECT --to-ports "$port"
                whiptail --title "修改完成" --msgbox "端口跳跃配置已更新，请检查服务状态。" 8 60
            ;;
            *)
                break
            ;;
        esac
    done
}

# 主菜单
while true; do
    choice=$(whiptail --title "Hysteria2 配置菜单" --menu "请选择一个选项：" 18 60 7 \
        "1" "安装 Hysteria2" \
        "2" "一键快速配置" \
        "3" "手动配置" \
        "4" "修改配置" \
        "5" "卸载 Hysteria2" \
        "6" "清理配置文件" \
        "7" "检查服务状态" \
        "8" "退出" 3>&1 1>&2 2>&3)

    case $choice in
        1)
            whiptail --title "安装 Hysteria2" --msgbox "正在安装 Hysteria2..." 8 60
            bash <(curl -fsSL https://get.hy2.sh/)
            whiptail --title "安装完成" --msgbox "Hysteria2 已安装，请选择配置选项。" 8 60
        ;;
        2)
            if ! command -v hysteria &>/dev/null; then
                whiptail --title "安装 Hysteria2" --msgbox "正在安装 Hysteria2..." 8 60
                bash <(curl -fsSL https://get.hy2.sh/)
            fi
            quick_config
        ;;
        3)
            if ! command -v hysteria &>/dev/null; then
                whiptail --title "安装 Hysteria2" --msgbox "正在安装 Hysteria2..." 8 60
                bash <(curl -fsSL https://get.hy2.sh/)
            fi
            manual_config
        ;;
        4)
            if [ ! -f "/etc/hysteria/config.yaml" ]; then
                whiptail --title "错误" --msgbox "未找到配置文件，请先进行配置！" 8 60
                continue
            fi
            modify_config
        ;;
        5)
            if whiptail --title "卸载 Hysteria2" --yesno "卸载 Hysteria2 程序？（配置文件将保留）" 8 60 --yes-button "是" --no-button "否"; then
                bash <(curl -fsSL https://get.hy2.sh/) --remove
                whiptail --title "卸载完成" --msgbox "Hysteria2 已卸载。使用“清理配置文件”选项可删除配置文件和用户数据。" 8 60
            fi
        ;;
        6)
            cleanup_files
        ;;
        7)
            status=$(sudo systemctl status hysteria-server.service)
            whiptail --title "服务状态" --msgbox "$status" 20 80
        ;;
        8)
            exit 0
        ;;
        *)
            exit 1
        ;;
    esac
done