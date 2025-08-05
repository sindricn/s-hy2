#!/bin/bash

# Hysteria2 配置管理脚本演示程序
# 此脚本用于演示项目功能，不会实际安装或修改系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 演示标题
print_demo_header() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}      Hysteria2 配置管理脚本 - 功能演示${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
    echo -e "${YELLOW}注意: 这是演示模式，不会实际修改系统${NC}"
    echo ""
}

# 演示菜单
show_demo_menu() {
    echo -e "${BLUE}演示功能列表:${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 项目结构展示"
    echo -e "${GREEN}2.${NC} 配置模板预览"
    echo -e "${GREEN}3.${NC} 域名测试演示"
    echo -e "${GREEN}4.${NC} 一键快速配置演示"
    echo -e "${GREEN}5.${NC} 脚本功能介绍"
    echo -e "${GREEN}6.${NC} 安装流程演示"
    echo -e "${GREEN}7.${NC} 卸载方式说明"
    echo -e "${GREEN}8.${NC} 使用场景说明"
    echo -e "${RED}0.${NC} 退出演示"
    echo ""
    echo -n -e "${BLUE}请选择演示内容 [0-8]: ${NC}"
}

# 项目结构展示
demo_project_structure() {
    echo -e "${BLUE}项目结构展示${NC}"
    echo ""
    echo -e "${CYAN}hy2-manager/${NC}"
    echo -e "├── ${GREEN}hy2-manager.sh${NC}          # 主控制脚本"
    echo -e "├── ${GREEN}install.sh${NC}              # 一键安装脚本"
    echo -e "├── ${BLUE}scripts/${NC}                # 功能模块目录"
    echo -e "│   ├── ${YELLOW}install.sh${NC}         # 安装模块"
    echo -e "│   ├── ${YELLOW}config.sh${NC}          # 配置生成模块"
    echo -e "│   ├── ${YELLOW}service.sh${NC}         # 服务管理模块"
    echo -e "│   ├── ${YELLOW}domain-test.sh${NC}     # 域名测试模块"
    echo -e "│   └── ${YELLOW}advanced.sh${NC}        # 进阶配置模块"
    echo -e "├── ${BLUE}templates/${NC}              # 配置模板目录"
    echo -e "│   ├── ${PURPLE}acme-config.yaml${NC}   # ACME 配置模板"
    echo -e "│   ├── ${PURPLE}self-cert-config.yaml${NC} # 自签名配置模板"
    echo -e "│   ├── ${PURPLE}advanced-config.yaml${NC}  # 高级配置模板"
    echo -e "│   └── ${PURPLE}client-config.yaml${NC}    # 客户端配置示例"
    echo -e "├── ${GREEN}README.md${NC}               # 项目说明"
    echo -e "├── ${GREEN}USAGE.md${NC}                # 使用说明"
    echo -e "└── ${GREEN}PROJECT_OVERVIEW.md${NC}     # 项目总览"
    echo ""
    echo -e "${YELLOW}核心特性:${NC}"
    echo "✓ 模块化设计，易于维护和扩展"
    echo "✓ 丰富的配置模板，适应不同场景"
    echo "✓ 完整的文档体系，便于学习使用"
    echo ""
}

# 配置模板预览
demo_config_templates() {
    echo -e "${BLUE}配置模板预览${NC}"
    echo ""
    
    echo -e "${CYAN}1. ACME 自动证书模式${NC}"
    echo -e "${YELLOW}特点: 自动申请和续期证书，适合生产环境${NC}"
    echo "listen: :443"
    echo "acme:"
    echo "  domains: [your.domain.net]"
    echo "  email: your@email.com"
    echo "auth:"
    echo "  type: password"
    echo "  password: ********"
    echo ""
    
    echo -e "${CYAN}2. 自签名证书模式${NC}"
    echo -e "${YELLOW}特点: 无需域名，快速部署，适合测试环境${NC}"
    echo "listen: :443"
    echo "tls:"
    echo "  cert: /etc/hysteria/server.crt"
    echo "  key: /etc/hysteria/server.key"
    echo "auth:"
    echo "  type: password"
    echo "  password: ********"
    echo ""
    
    echo -e "${CYAN}3. 进阶配置选项${NC}"
    echo -e "${YELLOW}包含: 混淆、带宽限制、ACL 等高级功能${NC}"
    echo "obfs:"
    echo "  type: salamander"
    echo "  salamander:"
    echo "    password: ********"
    echo "bandwidth:"
    echo "  up: 1 gbps"
    echo "  down: 1 gbps"
    echo ""
}

# 域名测试演示
demo_domain_test() {
    echo -e "${BLUE}域名测试功能演示${NC}"
    echo ""
    
    echo -e "${YELLOW}预设优质域名列表:${NC}"
    local domains=(
        "www.cloudflare.com"
        "www.apple.com"
        "www.microsoft.com"
        "cdn.jsdelivr.net"
        "fonts.googleapis.com"
    )
    
    echo -e "${CYAN}正在模拟测试域名延迟...${NC}"
    echo ""
    printf "%-5s %-30s %s\n" "排名" "域名" "延迟(ms)"
    echo "----------------------------------------"
    
    for i in "${!domains[@]}"; do
        local latency=$((RANDOM % 200 + 50))
        printf "%-5d %-30s %d ms\n" "$((i+1))" "${domains[$i]}" "$latency"
        sleep 0.5
    done
    
    echo ""
    echo -e "${GREEN}✓ 推荐使用: ${domains[0]} (延迟最低)${NC}"
    echo ""
    echo -e "${YELLOW}功能特点:${NC}"
    echo "• 自动测试多个优质域名"
    echo "• 按延迟排序选择最优"
    echo "• 支持自定义域名测试"
    echo "• 一键更新配置文件"
    echo ""
}

# 一键快速配置演示
demo_quick_setup() {
    echo -e "${BLUE}一键快速配置功能演示${NC}"
    echo ""

    echo -e "${CYAN}🚀 一键快速配置特性${NC}"
    echo ""
    echo -e "${YELLOW}完全自动化:${NC}"
    echo "• 无需手动输入任何参数"
    echo "• 自动检测服务器环境"
    echo "• 智能选择最优配置"
    echo ""

    echo -e "${YELLOW}配置内容:${NC}"
    echo "• 证书方案: 自签名证书 (无需域名)"
    echo "• 伪装域名: 自动测试选择延迟最低"
    echo "• 认证密码: 随机生成 16 位强密码"
    echo "• 混淆密码: 随机生成 16 位强密码"
    echo "• 端口跳跃: 20000-50000 -> 443"
    echo "• 网卡检测: 自动识别默认网络接口"
    echo ""

    echo -e "${CYAN}🔄 配置流程模拟${NC}"
    echo ""

    # 模拟配置过程
    echo -e "${BLUE}步骤 1/7: 获取服务器信息...${NC}"
    sleep 1
    echo "服务器IP: 192.168.1.100"
    echo "网络接口: eth0"
    echo ""

    echo -e "${BLUE}步骤 2/7: 测试最优伪装域名...${NC}"
    sleep 1
    local domains=("www.cloudflare.com" "cdn.jsdelivr.net" "www.apple.com")
    for domain in "${domains[@]}"; do
        local latency=$((RANDOM % 100 + 50))
        echo "测试 $domain ... ${latency}ms"
        sleep 0.3
    done
    echo -e "${GREEN}最优伪装域名: cdn.jsdelivr.net (52ms)${NC}"
    echo ""

    echo -e "${BLUE}步骤 3/7: 生成随机密码...${NC}"
    sleep 1
    echo "认证密码: Kx9mP2nQ8vR5wE7t"
    echo "混淆密码: Hy6bN4jM1sL3xC9z"
    echo ""

    echo -e "${BLUE}步骤 4/7: 生成自签名证书...${NC}"
    sleep 1
    echo "证书生成完成"
    echo ""

    echo -e "${BLUE}步骤 5/7: 生成配置文件...${NC}"
    sleep 1
    echo "配置文件生成完成"
    echo ""

    echo -e "${BLUE}步骤 6/7: 配置端口跳跃...${NC}"
    sleep 1
    echo "端口跳跃配置成功 (20000-50000 -> 443)"
    echo ""

    echo -e "${BLUE}步骤 7/7: 启动服务...${NC}"
    sleep 1
    echo -e "${GREEN}服务启动成功!${NC}"
    echo ""

    echo -e "${CYAN}📋 配置完成信息${NC}"
    echo ""
    echo -e "${YELLOW}服务器信息:${NC}"
    echo "服务器地址: 192.168.1.100:443"
    echo "认证密码: Kx9mP2nQ8vR5wE7t"
    echo "混淆密码: Hy6bN4jM1sL3xC9z"
    echo "伪装域名: cdn.jsdelivr.net"
    echo "端口跳跃: 20000-50000"
    echo ""

    echo -e "${YELLOW}节点链接:${NC}"
    echo "hysteria2://Kx9mP2nQ8vR5wE7t@192.168.1.100:443?sni=cdn.jsdelivr.net&insecure=1&obfs=salamander&obfs-password=Hy6bN4jM1sL3xC9z#Hysteria2-QuickSetup"
    echo ""

    echo -e "${YELLOW}客户端配置:${NC}"
    cat << EOF
server: 192.168.1.100:443
auth: Kx9mP2nQ8vR5wE7t
tls:
  sni: cdn.jsdelivr.net
  insecure: true
obfs:
  type: salamander
  salamander:
    password: Hy6bN4jM1sL3xC9z
socks5:
  listen: 127.0.0.1:1080
http:
  listen: 127.0.0.1:8080
EOF
    echo ""

    echo -e "${GREEN}✅ 一键快速配置演示完成!${NC}"
    echo ""
    echo -e "${YELLOW}优势总结:${NC}"
    echo "• 零配置: 无需任何手动输入"
    echo "• 高安全: 随机密码 + 混淆 + 端口跳跃"
    echo "• 智能化: 自动选择最优伪装域名"
    echo "• 快速部署: 3分钟内完成全部配置"
    echo "• 新手友好: 适合没有技术背景的用户"
    echo ""
}

# 脚本功能介绍
demo_script_features() {
    echo -e "${BLUE}脚本功能详细介绍${NC}"
    echo ""
    
    echo -e "${CYAN}🚀 安装管理${NC}"
    echo "• 一键安装 Hysteria2 服务器"
    echo "• 自动检测系统环境和依赖"
    echo "• 预安装检查和端口冲突检测"
    echo "• 完整卸载功能"
    echo ""
    
    echo -e "${CYAN}⚙️ 配置生成${NC}"
    echo "• 交互式配置向导"
    echo "• ACME 和自签名两种证书模式"
    echo "• 自动生成安全密码"
    echo "• 智能伪装域名选择"
    echo ""
    
    echo -e "${CYAN}📊 服务管理${NC}"
    echo "• 实时服务状态监控"
    echo "• 启动/停止/重启操作"
    echo "• 开机自启管理"
    echo "• 详细日志查看"
    echo ""
    
    echo -e "${CYAN}🔧 进阶配置${NC}"
    echo "• 端口修改和冲突检测"
    echo "• 混淆配置管理"
    echo "• 端口跳跃设置"
    echo "• iptables 规则自动化"
    echo ""
    
    echo -e "${CYAN}🌐 域名优化${NC}"
    echo "• 批量域名延迟测试"
    echo "• 智能选择最优伪装域名"
    echo "• 自定义域名测试"
    echo "• 配置文件自动更新"
    echo ""
}

# 安装流程演示
demo_installation_flow() {
    echo -e "${BLUE}安装流程演示${NC}"
    echo ""
    
    echo -e "${CYAN}步骤 1: 下载安装脚本${NC}"
    echo "wget https://raw.githubusercontent.com/your-repo/hy2-manager/main/install.sh"
    echo "chmod +x install.sh"
    echo ""
    
    echo -e "${CYAN}步骤 2: 运行安装脚本${NC}"
    echo "sudo ./install.sh"
    echo ""
    echo -e "${YELLOW}安装过程:${NC}"
    echo "✓ 检测系统环境"
    echo "✓ 安装必要依赖"
    echo "✓ 下载脚本文件"
    echo "✓ 创建命令快捷方式"
    echo "✓ 设置执行权限"
    echo ""
    
    echo -e "${CYAN}步骤 3: 运行管理脚本${NC}"
    echo "sudo hy2-manager"
    echo ""
    echo -e "${YELLOW}使用流程:${NC}"
    echo "1. 选择 '安装 Hysteria2'"
    echo "2. 选择 '生成配置文件'"
    echo "3. 选择 '管理服务' -> '启动服务'"
    echo "4. 配置客户端连接"
    echo ""
}

# 卸载方式说明
demo_uninstall_options() {
    echo -e "${BLUE}卸载方式详细说明${NC}"
    echo ""

    echo -e "${CYAN}📋 卸载方式对比${NC}"
    echo ""
    printf "%-20s %-8s %-8s %-8s %-8s %-8s %-15s\n" "卸载方式" "程序" "配置" "证书" "用户" "脚本" "适用场景"
    echo "----------------------------------------------------------------------------------------"
    printf "%-20s %-8s %-8s %-8s %-8s %-8s %-15s\n" "1.仅卸载服务器" "✅删除" "❌保留" "❌保留" "❌保留" "❌保留" "临时卸载、升级"
    printf "%-20s %-8s %-8s %-8s %-8s %-8s %-15s\n" "2.卸载服务器及配置" "✅删除" "✅删除" "✅删除" "✅删除" "❌保留" "清理配置"
    printf "%-20s %-8s %-8s %-8s %-8s %-8s %-15s\n" "3.卸载所有内容" "✅删除" "✅删除" "✅删除" "✅删除" "✅删除" "彻底清理"
    echo ""

    echo -e "${CYAN}🔧 方式一：仅卸载 Hysteria2 服务器${NC}"
    echo ""
    echo -e "${YELLOW}适用场景:${NC}"
    echo "• 临时卸载，计划重新安装"
    echo "• 系统升级或重装前的准备"
    echo "• 保留配置以备后用"
    echo "• 测试不同版本"
    echo ""
    echo -e "${YELLOW}操作步骤:${NC}"
    echo "1. sudo s-hy2"
    echo "2. 选择 '9. 卸载服务'"
    echo "3. 选择 '1. 仅卸载 Hysteria2 服务器'"
    echo "4. 确认卸载"
    echo ""
    echo -e "${YELLOW}保留内容:${NC}"
    echo "• /etc/hysteria/ - 配置文件和证书"
    echo "• hysteria 用户账户"
    echo "• s-hy2 管理脚本"
    echo ""

    echo -e "${CYAN}🗑️ 方式二：卸载 Hysteria2 服务器及配置文件${NC}"
    echo ""
    echo -e "${YELLOW}适用场景:${NC}"
    echo "• 清理所有配置，但保留管理脚本"
    echo "• 重新开始全新配置"
    echo "• 清理测试环境"
    echo ""
    echo -e "${YELLOW}操作步骤:${NC}"
    echo "1. sudo s-hy2"
    echo "2. 选择 '9. 卸载服务'"
    echo "3. 选择 '2. 卸载 Hysteria2 服务器及配置文件'"
    echo "4. 确认卸载"
    echo ""
    echo -e "${YELLOW}保留内容:${NC}"
    echo "• s-hy2 管理脚本"
    echo ""

    echo -e "${CYAN}💥 方式三：卸载脚本及 Hysteria2 服务器和所有文件${NC}"
    echo ""
    echo -e "${YELLOW}适用场景:${NC}"
    echo "• 不再使用 Hysteria2 和管理脚本"
    echo "• 彻底清理系统"
    echo "• 服务器用途完全改变"
    echo ""
    echo -e "${YELLOW}操作步骤:${NC}"
    echo "1. sudo s-hy2"
    echo "2. 选择 '9. 卸载服务'"
    echo "3. 选择 '3. 卸载脚本及 Hysteria2 服务器和所有文件'"
    echo "4. 输入 'YES' 确认"
    echo ""
    echo -e "${YELLOW}删除内容:${NC}"
    echo "• 所有程序文件和配置"
    echo "• hysteria 用户账户"
    echo "• s-hy2 管理脚本"
    echo "• 所有快捷命令"
    echo ""

    echo -e "${CYAN}🔍 卸载验证${NC}"
    echo ""
    echo -e "${YELLOW}检查命令:${NC}"
    echo "# 检查程序是否删除"
    echo "which hysteria"
    echo ""
    echo "# 检查服务状态"
    echo "sudo systemctl status hysteria-server"
    echo ""
    echo "# 检查配置文件 (方式1可能存在)"
    echo "ls -la /etc/hysteria/"
    echo ""
    echo "# 检查用户账户 (方式1可能存在)"
    echo "id hysteria"
    echo ""
    echo "# 检查管理脚本 (方式1和2存在)"
    echo "which s-hy2"
    echo ""
    echo -e "${YELLOW}重新安装:${NC}"
    echo "curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash"
    echo ""
}

# 使用场景说明
demo_use_cases() {
    echo -e "${BLUE}使用场景说明${NC}"
    echo ""
    
    echo -e "${CYAN}🏠 个人用户${NC}"
    echo "• 搭建个人代理服务器"
    echo "• 学习网络技术"
    echo "• 家庭网络优化"
    echo "• 游戏加速"
    echo ""
    
    echo -e "${CYAN}🏢 企业用户${NC}"
    echo "• 分支机构网络连接"
    echo "• 内网穿透"
    echo "• 远程办公支持"
    echo "• 网络安全加固"
    echo ""
    
    echo -e "${CYAN}👨‍💻 开发者${NC}"
    echo "• 开发环境搭建"
    echo "• 网络调试工具"
    echo "• 性能测试"
    echo "• API 接口测试"
    echo ""
    
    echo -e "${CYAN}🎓 教育机构${NC}"
    echo "• 网络技术教学"
    echo "• 实验环境搭建"
    echo "• 学生项目支持"
    echo "• 研究用途"
    echo ""
}

# 主演示循环
main_demo() {
    while true; do
        print_demo_header
        show_demo_menu
        
        read -r choice
        
        case $choice in
            1)
                echo ""
                demo_project_structure
                read -p "按回车键继续..."
                ;;
            2)
                echo ""
                demo_config_templates
                read -p "按回车键继续..."
                ;;
            3)
                echo ""
                demo_domain_test
                read -p "按回车键继续..."
                ;;
            4)
                echo ""
                demo_quick_setup
                read -p "按回车键继续..."
                ;;
            5)
                echo ""
                demo_script_features
                read -p "按回车键继续..."
                ;;
            6)
                echo ""
                demo_installation_flow
                read -p "按回车键继续..."
                ;;
            7)
                echo ""
                demo_uninstall_options
                read -p "按回车键继续..."
                ;;
            8)
                echo ""
                demo_use_cases
                read -p "按回车键继续..."
                ;;
            0)
                echo ""
                echo -e "${GREEN}感谢观看 Hysteria2 配置管理脚本演示!${NC}"
                echo ""
                echo -e "${YELLOW}如需实际使用，请运行:${NC}"
                echo "sudo ./hy2-manager.sh"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 运行演示
main_demo
