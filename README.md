# s-hy2 Hysteria2 自动化管理平台

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

企业级Hysteria2服务器自动化部署、配置管理和运维平台

</div>

## 🌟 项目特色

### 🎯 核心功能
- **🚀 一键部署** - 自动化Hysteria2服务器安装和配置
- **⚙️ 智能配置** - 支持ACME自动证书和自签名证书
- **🔧 模块化架构** - 16个专业化脚本模块，职责分离清晰
- **🛡️ 企业级安全** - 多层次安全防护，标准化错误处理
- **📊 智能监控** - 实时性能监控和健康检查
- **🎨 友好界面** - 中文交互式菜单，操作简单直观

### 🆕 新增特性 (v1.1.0)
- **🌐 出站规则** - 支持Direct、SOCKS5、HTTP三种出站模式
- **🛡️ 防火墙管理** - 自动检测并管理多种防火墙类型


## 📋 功能清单

### 🔧 核心管理功能
| 功能 | 状态 | 描述 |
|------|------|------|
| 🚀 **安装管理** | ✅ | 一键安装/卸载Hysteria2服务器 |
| ⚙️ **配置管理** | ✅ | 快速配置、手动配置、修改配置 |
| 🌐 **域名管理** | ✅ | 服务器域名配置和解析验证 |
| 🔐 **证书管理** | ✅ | 自签名证书、自定义证书管理 |
| 🔧 **服务管理** | ✅ | 启动/停止/重启/状态监控 |
| 📱 **订阅链接** | ✅ | 多客户端订阅链接生成 |
| 🌐 **出站配置** | 🆕 | 支持多种出站代理模式 |
| 🛡️ **防火墙管理** | 🆕 | 自动防火墙检测和端口管理 |


## 🚀 快速开始

### 📦 一键安装

```bash
# 一键安装到服务器
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash

# 启动管理界面
sudo s-hy2
```

### 🔧 手动安装

```bash
# 克隆仓库
git clone https://github.com/sindricn/s-hy2.git
cd s-hy2

# 设置执行权限
chmod +x hy2-manager.sh scripts/*.sh

# 运行主脚本
sudo ./hy2-manager.sh
```

## 📋 使用指南

### 🎯 主菜单功能

```
========================================
     Hysteria2 配置管理脚本 v1.1.0
========================================

请选择操作:

 1. 安装 Hysteria2
 2. 快速配置
 3. 手动配置
 4. 修改配置
 5. 域名管理
 6. 证书管理
 7. 服务管理
 8. 订阅链接
 9. 出站规则配置    🆕
10. 防火墙管理       🆕
11. 卸载服务
12. 关于脚本
 0. 退出
```

### 🌐 出站规则管理

支持三种出站模式，满足不同网络环境需求：

#### 📡 Direct 直连模式
```bash
# 选择菜单项 9 -> 1
# 适用于简单的直连需求
# 支持网卡绑定和IP绑定
```

#### 🔌 SOCKS5 代理模式
```bash
# 选择菜单项 9 -> 2
# 支持用户名密码认证
# 国内外分流配置
```

#### 🌐 HTTP 代理模式
```bash
# 选择菜单项 9 -> 3
# 支持HTTPS代理
# 特定域名代理规则
```

### 🛡️ 防火墙管理

自动检测并管理以下防火墙类型：

- **firewalld** (CentOS/RHEL/Fedora)
- **ufw** (Ubuntu/Debian)
- **iptables** (通用Linux)
- **nftables** (现代Linux)

```bash
# 选择菜单项 10
# 1. 检测防火墙类型
# 2. 开放端口
# 3. 查看状态
# 4. 连接测试
```


### 📝 获取支持
1. 运行诊断脚本: `./scripts/post-deploy-check.sh`
2. 提交[Issue](https://github.com/sindricn/s-hy2/issues)

## 🤝 贡献指南

### 🔧 开发环境
```bash
# 克隆开发分支
git clone -b develop https://github.com/sindricn/s-hy2.git

# 语法检查
for script in *.sh scripts/*.sh; do bash -n "$script"; done
```

## 📄 更新日志

### v1.1.0 (2024-09-23)
🆕 **新功能**
- 出站规则管理（支持具体参数修改）
- 防火墙自动检测和管理
- 部署后健康检查
- 性能监控和优化


### v1.0.0 (2024-08-01)
🎉 **初始版本**
- 基础Hysteria2部署功能
- 配置文件管理
- 服务控制
- 域名解析测试

## 📜 许可证

本项目采用 [MIT 许可证](LICENSE) 开源。

## 💖 致谢

感谢 [Hysteria](https://hysteria.network/) 项目提供优秀的网络代理解决方案。

---

<div align="center">

**🔥 如果这个项目对你有帮助，请给个 Star ⭐**

[报告问题](https://github.com/sindricn/s-hy2/issues) • [提出建议](https://github.com/sindricn/s-hy2/discussions)

</div>