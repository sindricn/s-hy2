#!/bin/bash

# Hysteria2出站规则配置修复脚本
# 解决配置不完整和语法验证失败问题

# 配置文件路径
HYSTERIA_CONFIG="/etc/hysteria/config.yaml"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 完整稳定的配置应用函数
apply_outbound_complete() {
    local name="$1" type="$2"

    echo -e "${BLUE}[INFO]${NC} 🔧 开始添加完整的出站规则配置"
    echo -e "${BLUE}[INFO]${NC} 规则名称: $name"
    echo -e "${BLUE}[INFO]${NC} 规则类型: $type"

    # 检查配置文件
    if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
        echo -e "${RED}[ERROR]${NC} ❌ 配置文件不存在: $HYSTERIA_CONFIG"
        return 1
    fi

    # 创建备份
    local backup_file="/tmp/hysteria_backup_$(date +%s).yaml"
    echo -e "${BLUE}[INFO]${NC} 📦 创建配置备份: $backup_file"

    if ! cp "$HYSTERIA_CONFIG" "$backup_file" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} ❌ 无法创建备份文件"
        return 1
    fi

    # 创建临时文件
    local temp_file="/tmp/hysteria_temp_$(date +%s).yaml"
    echo -e "${BLUE}[INFO]${NC} 📝 创建临时配置文件: $temp_file"

    if ! cp "$HYSTERIA_CONFIG" "$temp_file" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} ❌ 无法创建临时文件"
        rm -f "$backup_file" 2>/dev/null
        return 1
    fi

    # 添加完整的出站配置（包含ACL规则）
    echo -e "${BLUE}[INFO]${NC} ⚙️ 添加完整的出站配置"

    if grep -q "^[[:space:]]*outbounds:" "$temp_file" 2>/dev/null; then
        echo -e "${BLUE}[INFO]${NC} 🔍 检测到现有outbounds配置，追加新规则"

        case $type in
            "direct")
                cat >> "$temp_file" << EOF

  # 新增出站规则 - $name (Direct)
  - name: $name
    type: direct
    direct:
      mode: auto
      # bindDevice: "eth0"     # 可选：绑定网络接口
      # bindIPv4: "0.0.0.0"    # 可选：绑定IPv4地址
      # bindIPv6: "::"         # 可选：绑定IPv6地址
EOF
                ;;
            "socks5")
                cat >> "$temp_file" << EOF

  # 新增出站规则 - $name (SOCKS5)
  - name: $name
    type: socks5
    socks5:
      addr: "${SOCKS5_ADDR:-127.0.0.1:1080}"
EOF
                if [[ -n "${SOCKS5_USERNAME:-}" ]]; then
                    echo "      username: \"$SOCKS5_USERNAME\"" >> "$temp_file"
                    echo "      password: \"$SOCKS5_PASSWORD\"" >> "$temp_file"
                fi
                ;;
        esac

        # 检查并添加ACL规则
        echo -e "${BLUE}[INFO]${NC} 🛠️ 处理ACL路由规则"
        if ! grep -q "^[[:space:]]*acl:" "$temp_file" 2>/dev/null; then
            echo -e "${BLUE}[INFO]${NC} 📋 创建ACL规则以使用新的出站规则"
            cat >> "$temp_file" << EOF

# ACL规则 - 路由配置
acl: |
  # 使用新增的出站规则 $name 处理中国网站
  $name(geosite:cn)
  # 其他流量使用直连
  direct(all)
EOF
        else
            echo -e "${YELLOW}[WARN]${NC} ⚠️ 已存在ACL规则，请手动配置以使用新的出站规则 '$name'"
        fi

    else
        echo -e "${BLUE}[INFO]${NC} 🆕 未检测到outbounds配置，创建完整的配置节点"
        case $type in
            "direct")
                cat >> "$temp_file" << EOF

# 出站规则配置
outbounds:
  - name: $name
    type: direct
    direct:
      mode: auto
      # bindDevice: "eth0"     # 可选：绑定网络接口
      # bindIPv4: "0.0.0.0"    # 可选：绑定IPv4地址
      # bindIPv6: "::"         # 可选：绑定IPv6地址

# ACL规则 - 路由配置
acl: |
  # 使用 $name 进行直连
  $name(all)
EOF
                ;;
            "socks5")
                cat >> "$temp_file" << EOF

# 出站规则配置
outbounds:
  - name: $name
    type: socks5
    socks5:
      addr: "${SOCKS5_ADDR:-127.0.0.1:1080}"
EOF
                if [[ -n "${SOCKS5_USERNAME:-}" ]]; then
                    echo "      username: \"$SOCKS5_USERNAME\"" >> "$temp_file"
                    echo "      password: \"$SOCKS5_PASSWORD\"" >> "$temp_file"
                fi
                cat >> "$temp_file" << EOF

# ACL规则 - 路由配置
acl: |
  # 使用 $name 代理所有流量
  $name(all)
EOF
                ;;
        esac
    fi

    # 验证配置语法（严格验证）
    echo -e "${BLUE}[INFO]${NC} 🔍 验证配置语法"
    if command -v hysteria >/dev/null 2>&1; then
        local validation_output
        validation_output=$(hysteria check-config -c "$temp_file" 2>&1)
        local validation_result=$?

        if [[ $validation_result -eq 0 ]]; then
            echo -e "${GREEN}[SUCCESS]${NC} ✅ 配置语法验证通过"
        else
            echo -e "${RED}[ERROR]${NC} ❌ 配置语法验证失败"
            echo -e "${RED}错误详情:${NC}"
            echo "----------------------------------------"
            echo "$validation_output"
            echo "----------------------------------------"
            echo -e "${YELLOW}[WARN]${NC} ⚠️ 应用此配置可能导致Hysteria2无法启动"
            echo -e "${YELLOW}是否仍要继续应用配置？ [y/N]${NC}"
            read -r force_apply
            if [[ ! $force_apply =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}[INFO]${NC} 🚫 操作已取消，配置未应用"
                rm -f "$temp_file" "$backup_file" 2>/dev/null
                return 1
            fi
            echo -e "${YELLOW}[WARN]${NC} ⚠️ 用户选择强制应用配置"
        fi
    else
        echo -e "${YELLOW}[WARN]${NC} ⚠️ 未找到hysteria命令，跳过语法验证"
        echo -e "${YELLOW}[WARN]${NC} 强烈建议在生产环境中安装hysteria进行配置验证"
    fi

    # 显示配置预览
    echo -e "${BLUE}[INFO]${NC} 📋 配置预览（新增部分）："
    echo -e "${GREEN}===================${NC}"
    tail -25 "$temp_file" 2>/dev/null | head -20
    echo -e "${GREEN}===================${NC}"

    # 应用配置
    echo -e "${BLUE}[INFO]${NC} 🚀 应用新配置"
    if mv "$temp_file" "$HYSTERIA_CONFIG" 2>/dev/null; then
        echo -e "${GREEN}[SUCCESS]${NC} ✅ 配置已成功应用到: $HYSTERIA_CONFIG"
        echo -e "${GREEN}[SUCCESS]${NC} 🎉 出站规则 '$name' ($type) 添加完成"

        # 提示用户重启服务
        echo -e "${BLUE}[INFO]${NC} 💡 建议重启Hysteria2服务以应用新配置："
        echo -e "${BLUE}    sudo systemctl restart hysteria-server${NC}"

        rm -f "$backup_file" 2>/dev/null
        return 0
    else
        echo -e "${RED}[ERROR]${NC} ❌ 配置应用失败，恢复备份"
        mv "$backup_file" "$HYSTERIA_CONFIG" 2>/dev/null || echo -e "${RED}[ERROR]${NC} 备份恢复也失败了"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# 主函数
main() {
    echo -e "${GREEN}🔧 Hysteria2出站规则配置修复工具${NC}"
    echo -e "${GREEN}版本: 2.0 (完整配置版本)${NC}"
    echo -e "${GREEN}时间: $(date)${NC}"
    echo ""

    if [[ $# -lt 2 ]]; then
        echo "用法: $0 <规则名称> <规则类型>"
        echo "示例: $0 my_direct direct"
        echo "示例: $0 my_proxy socks5"
        exit 1
    fi

    local rule_name="$1"
    local rule_type="$2"

    echo -e "${BLUE}[INFO]${NC} 准备添加出站规则："
    echo -e "${BLUE}[INFO]${NC} 名称: $rule_name"
    echo -e "${BLUE}[INFO]${NC} 类型: $rule_type"
    echo ""

    if apply_outbound_complete "$rule_name" "$rule_type"; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} 🎉 出站规则配置完成！"
        echo -e "${GREEN}[SUCCESS]${NC} ✅ 现在可以查看配置并重启服务了"
    else
        echo ""
        echo -e "${RED}[ERROR]${NC} ❌ 出站规则配置失败！"
        echo -e "${RED}[ERROR]${NC} 请检查错误信息并重试"
        exit 1
    fi
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi