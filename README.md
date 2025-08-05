# Hysteria2 配置管理脚本

一个用于简化 Hysteria2 服务器配置和管理的交互式脚本工具。

## 功能特性

- 🚀 **一键安装/卸载** Hysteria2 服务器
- ⚙️ **交互式配置生成** 支持 ACME 自动证书和自签名证书
- 🌐 **智能伪装域名选择** 自动测试延迟选择最优域名
- 🔧 **进阶配置支持** 端口修改、混淆密码、端口跳跃
- 📊 **服务管理** 状态查看、日志查询、服务重启
- 📝 **配置模板** 预设多种常用配置模板

## 快速开始

### 一键安装 (推荐)

```bash
# 一键安装到服务器
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash

# 运行脚本
sudo s-hy2
```

### 手动安装

```bash
# 下载脚本
wget https://raw.githubusercontent.com/sindricn/s-hy2/main/hy2-manager.sh

# 添加执行权限
chmod +x hy2-manager.sh

# 运行脚本
sudo ./hy2-manager.sh
```

## 使用说明

运行脚本后会显示交互式菜单，包含以下选项：

1. **安装 Hysteria2** - 自动下载并安装 Hysteria2 服务器
2. **一键快速配置** - 自动配置自签名证书+混淆+端口跳跃
3. **手动配置** - 交互式生成配置文件 (ACME/自签名)
4. **管理服务** - 启动/停止/重启/查看状态
5. **查看日志** - 查看服务运行日志
6. **测试伪装域名** - 测试并选择最优伪装域名
7. **进阶配置** - 端口跳跃、混淆等高级设置
8. **节点信息** - 显示节点链接、订阅链接和客户端配置
9. **卸载服务** - 提供两种卸载方式：
   - 仅卸载程序 (保留配置文件和证书)
   - 完全卸载 (删除所有文件)

## 配置模式

### 一键快速配置 (推荐新手)
- **自动化程度**: 完全自动化，无需手动输入
- **证书方案**: 自签名证书 (无需域名)
- **伪装域名**: 自动测试选择延迟最低的域名
- **安全特性**: 自动生成认证密码和混淆密码
- **网络优化**: 自动配置端口跳跃 (20000-50000)
- **网卡检测**: 自动识别网络接口
- **适用场景**: 快速部署、测试环境、新手用户

### ACME 自动证书模式
- 自动申请和续期 SSL 证书
- 需要有效域名和邮箱
- 推荐用于生产环境

### 自签名证书模式
- 生成自签名证书
- 无需域名，快速部署
- 适合测试环境

## 目录结构

```
s-hy2/
├── hy2-manager.sh          # 主脚本
├── quick-install.sh        # 一键安装脚本
├── scripts/                # 功能脚本目录
│   ├── install.sh         # 安装脚本
│   ├── config.sh          # 配置生成脚本 (含一键快速配置)
│   ├── service.sh         # 服务管理脚本
│   ├── domain-test.sh     # 域名测试脚本
│   ├── advanced.sh        # 进阶配置脚本
│   └── node-info.sh       # 节点信息脚本
├── templates/             # 配置模板目录
│   ├── acme-config.yaml   # ACME 配置模板
│   ├── self-cert-config.yaml # 自签名配置模板
│   ├── advanced-config.yaml  # 高级配置模板
│   └── client-config.yaml    # 客户端配置示例
└── README.md              # 说明文档
```

## 快捷命令

安装完成后，可以使用以下命令快速启动：

```bash
# 推荐使用 (简短易记)
sudo s-hy2

# 或者使用完整命令
sudo hy2-manager
```

## 系统要求

- Linux 系统 (Ubuntu/Debian/CentOS/RHEL/Fedora)
- Root 权限
- 网络连接
- 至少 100MB 可用空间

## 快速开始示例

### 完整部署流程
```bash
# 1. 一键安装
curl -fsSL https://raw.githubusercontent.com/your-repo/s-hy2/main/quick-install.sh | sudo bash

# 2. 启动脚本
sudo s-hy2

# 3. 按菜单操作
# 选择 1 -> 安装 Hysteria2
# 选择 2 -> 一键快速配置
# 选择 8 -> 查看节点信息
```

### 预期输出
```
=== Hysteria2 一键快速配置 ===

步骤 1/7: 获取服务器信息...
服务器IP: 192.168.1.100
网络接口: eth0

步骤 2/7: 测试最优伪装域名...
最优伪装域名: cdn.jsdelivr.net

步骤 3/7: 生成随机密码...
认证密码: Kx9mP2nQ8vR5wE7t
混淆密码: Hy6bN4jM1sL3xC9z

步骤 4/7: 生成自签名证书...
证书生成完成

步骤 5/7: 生成配置文件...
配置文件生成完成

步骤 6/7: 配置端口跳跃...
端口跳跃配置成功 (20000-50000 -> 443)

步骤 7/7: 启动服务...
服务启动成功!

=== 配置完成 ===
节点链接: hysteria2://Kx9mP2nQ8vR5wE7t@192.168.1.100:443?sni=cdn.jsdelivr.net&insecure=1&obfs=salamander&obfs-password=Hy6bN4jM1sL3xC9z#Hysteria2-QuickSetup
```

## 常见问题

### Q: 一键快速配置包含哪些功能？
A: 自动获取服务器IP、测试最优伪装域名、生成随机密码、创建自签名证书、配置混淆和端口跳跃、启动服务。

### Q: 如何获取节点连接信息？
A: 运行 `sudo s-hy2`，选择菜单 "8. 节点信息"，可查看节点链接、订阅链接和客户端配置。

### Q: 支持哪些操作系统？
A: Ubuntu 18.04+、Debian 9+、CentOS 7+、RHEL 7+、Fedora 30+。

### Q: 如何卸载？
A: 运行脚本选择 "9. 卸载服务"，提供"仅卸载程序"和"完全卸载"两种方式。

## 许可证

MIT License
