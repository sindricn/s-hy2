#!/bin/bash

# Hysteria2 服务管理脚本 - 简化版本

# 加载公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
else
    # 如果无法加载公共库，则使用本地颜色定义
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m' # No Color
fi

# 启动服务
start_service() {
    echo -e "${BLUE}启动 Hysteria2 服务...${NC}"
    
    if systemctl start hysteria-server.service; then
        echo -e "${GREEN}服务启动成功${NC}"
    else
        echo -e "${RED}服务启动失败${NC}"
    fi
}

# 停止服务
stop_service() {
    echo -e "${BLUE}停止 Hysteria2 服务...${NC}"
    
    if systemctl stop hysteria-server.service; then
        echo -e "${GREEN}服务停止成功${NC}"
    else
        echo -e "${RED}服务停止失败${NC}"
    fi
}

# 重启服务
restart_service() {
    echo -e "${BLUE}重启 Hysteria2 服务...${NC}"
    
    if systemctl restart hysteria-server.service; then
        echo -e "${GREEN}服务重启成功${NC}"
    else
        echo -e "${RED}服务重启失败${NC}"
    fi
}

# 启用服务
enable_service() {
    echo -e "${BLUE}启用 Hysteria2 服务 (开机自启)...${NC}"
    
    if systemctl enable hysteria-server.service; then
        echo -e "${GREEN}服务已设置为开机自启${NC}"
    else
        echo -e "${RED}服务启用失败${NC}"
    fi
}

# 禁用服务
disable_service() {
    echo -e "${BLUE}禁用 Hysteria2 服务 (取消开机自启)...${NC}"
    
    if systemctl disable hysteria-server.service; then
        echo -e "${GREEN}服务已取消开机自启${NC}"
    else
        echo -e "${RED}服务禁用失败${NC}"
    fi
}

# 查看服务状态
check_service_status() {
    echo -e "${CYAN}=== 服务状态 ===${NC}"
    
    if systemctl is-active --quiet hysteria-server.service; then
        echo -e "${GREEN}✅ 服务状态: 运行中${NC}"
    else
        echo -e "${RED}❌ 服务状态: 已停止${NC}"
    fi
    
    if systemctl is-enabled --quiet hysteria-server.service; then
        echo -e "${GREEN}✅ 开机自启: 已启用${NC}"
    else
        echo -e "${YELLOW}⚠️  开机自启: 已禁用${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}服务详细状态:${NC}"
    systemctl status hysteria-server.service --no-pager -l
}

# 主服务管理函数
manage_hysteria_service() {
    while true; do
        clear
        echo -e "${CYAN}=== Hysteria2 服务管理 ===${NC}"
        echo ""
        
        # 显示当前服务状态
        if systemctl is-active --quiet hysteria-server.service; then
            echo -e "${GREEN}✅ 服务状态: 运行中${NC}"
        else
            echo -e "${RED}❌ 服务状态: 已停止${NC}"
        fi
        
        if systemctl is-enabled --quiet hysteria-server.service; then
            echo -e "${GREEN}✅ 开机自启: 已启用${NC}"
        else
            echo -e "${YELLOW}⚠️  开机自启: 已禁用${NC}"
        fi
        
        echo ""
        echo -e "${YELLOW}服务操作:${NC}"
        echo -e "${GREEN}1.${NC} 启动服务"
        echo -e "${GREEN}2.${NC} 停止服务"
        echo -e "${GREEN}3.${NC} 重启服务"
        echo -e "${GREEN}4.${NC} 启用开机自启"
        echo -e "${GREEN}5.${NC} 禁用开机自启"
        echo -e "${GREEN}6.${NC} 查看详细状态"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo ""
        echo -n -e "${BLUE}请选择操作 [0-6]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                start_service
                echo ""
                ;;
            2)
                stop_service
                echo ""
                ;;
            3)
                restart_service
                echo ""
                ;;
            4)
                enable_service
                echo ""
                ;;
            5)
                disable_service
                echo ""
                ;;
            6)
                check_service_status
                echo ""
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选项${NC}"
                sleep 1
                ;;
        esac
        
        if [[ $choice -ne 0 ]]; then
            echo ""
            echo -e "${YELLOW}按回车键继续...${NC}"
            read -r
        fi
    done
}