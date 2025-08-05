# S-Hy2 故障排除指南

## 安装问题

### 问题1: 安装脚本直接退出

**症状**: 运行安装命令后，显示安装界面但立即退出

**可能原因**:
1. 网络连接问题
2. GitHub 访问受限
3. 权限不足
4. 系统不兼容

**解决方案**:

#### 步骤1: 运行测试脚本
```bash
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/test-install.sh | sudo bash
```

#### 步骤2: 使用简化版安装
```bash
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install-simple.sh | sudo bash
```

#### 步骤3: 使用调试模式
```bash
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash -s -- --debug
```

#### 步骤4: 手动安装
```bash
# 1. 创建目录
sudo mkdir -p /opt/s-hy2/scripts /opt/s-hy2/templates

# 2. 下载主脚本
sudo curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/hy2-manager.sh -o /opt/s-hy2/hy2-manager.sh

# 3. 设置权限
sudo chmod +x /opt/s-hy2/hy2-manager.sh

# 4. 创建快捷方式
sudo ln -sf /opt/s-hy2/hy2-manager.sh /usr/local/bin/s-hy2

# 5. 测试运行
sudo s-hy2
```

### 问题2: 网络连接失败

**症状**: 提示网络连接失败或下载失败

**解决方案**:

#### 方案1: 检查网络连接
```bash
# 测试基本网络连接
ping -c 3 8.8.8.8

# 测试 HTTPS 连接
curl -I https://www.google.com

# 测试 GitHub 连接
curl -I https://github.com
```

#### 方案2: 使用代理
```bash
# 如果有 HTTP 代理
export http_proxy=http://proxy.example.com:8080
export https_proxy=http://proxy.example.com:8080

# 然后重新运行安装命令
```

#### 方案3: 使用镜像源
```bash
# 使用 Gitee 镜像 (如果有的话)
# 或者下载到本地后手动安装
```

### 问题3: 权限不足

**症状**: 提示权限不足或无法创建文件/目录

**解决方案**:

#### 检查 root 权限
```bash
# 确保使用 sudo
sudo whoami  # 应该显示 root

# 检查 sudo 配置
sudo -l
```

#### 检查目录权限
```bash
# 检查 /opt 目录权限
ls -la /opt

# 检查 /usr/local/bin 目录权限
ls -la /usr/local/bin
```

### 问题4: 系统不兼容

**症状**: 提示系统类型检测失败

**支持的系统**:
- Ubuntu 18.04+
- Debian 9+
- CentOS 7+
- RHEL 7+
- Fedora 30+

**解决方案**:
```bash
# 检查系统信息
cat /etc/os-release

# 检查内核版本
uname -a

# 如果系统不在支持列表中，可以尝试手动安装
```

## 运行问题

### 问题1: 命令找不到

**症状**: 运行 `s-hy2` 提示命令找不到

**解决方案**:
```bash
# 检查符号链接
ls -la /usr/local/bin/s-hy2

# 检查 PATH 环境变量
echo $PATH

# 手动创建符号链接
sudo ln -sf /opt/s-hy2/hy2-manager.sh /usr/local/bin/s-hy2

# 或者直接运行完整路径
sudo /opt/s-hy2/hy2-manager.sh
```

### 问题2: 脚本运行错误

**症状**: 脚本运行时出现错误或异常退出

**解决方案**:

#### 检查脚本完整性
```bash
# 检查主脚本是否存在且可执行
ls -la /opt/s-hy2/hy2-manager.sh

# 检查脚本内容
head -10 /opt/s-hy2/hy2-manager.sh
```

#### 检查依赖脚本
```bash
# 检查功能脚本
ls -la /opt/s-hy2/scripts/

# 重新下载缺失的脚本
sudo curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/scripts/install.sh -o /opt/s-hy2/scripts/install.sh
sudo chmod +x /opt/s-hy2/scripts/install.sh
```

### 问题3: 菜单选项错误

**症状**: 选择菜单选项后提示错误或无响应

**解决方案**:
```bash
# 重新下载最新版本
sudo curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/hy2-manager.sh -o /opt/s-hy2/hy2-manager.sh
sudo chmod +x /opt/s-hy2/hy2-manager.sh
```

## Hysteria2 相关问题

### 问题1: Hysteria2 安装失败

**解决方案**:
```bash
# 手动安装 Hysteria2
bash <(curl -fsSL https://get.hy2.sh/)

# 检查安装结果
which hysteria
hysteria version
```

### 问题2: 服务启动失败

**解决方案**:
```bash
# 检查服务状态
sudo systemctl status hysteria-server

# 查看详细日志
sudo journalctl -u hysteria-server -f

# 检查配置文件
sudo cat /etc/hysteria/config.yaml

# 验证配置文件语法
sudo hysteria server --config /etc/hysteria/config.yaml --check
```

### 问题3: 端口被占用

**解决方案**:
```bash
# 检查端口占用
sudo netstat -tulnp | grep :443

# 查找占用进程
sudo lsof -i :443

# 停止占用进程或更换端口
```

## 网络问题

### 问题1: 防火墙阻止

**解决方案**:
```bash
# Ubuntu/Debian
sudo ufw allow 443/udp
sudo ufw status

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=443/udp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

### 问题2: 端口跳跃失败

**解决方案**:
```bash
# 检查 iptables 规则
sudo iptables -t nat -L PREROUTING

# 检查网络接口
ip link show

# 手动添加规则
sudo iptables -t nat -A PREROUTING -i eth0 -p udp --dport 20000:50000 -j REDIRECT --to-ports 443
```

## 日志和调试

### 启用详细日志
```bash
# 查看系统日志
sudo journalctl -f

# 查看 Hysteria2 日志
sudo journalctl -u hysteria-server -f

# 启用调试模式
sudo HYSTERIA_DEBUG=1 /opt/s-hy2/hy2-manager.sh
```

### 收集诊断信息
```bash
# 系统信息
uname -a
cat /etc/os-release

# 网络信息
ip addr show
ip route show

# 服务信息
sudo systemctl status hysteria-server
sudo netstat -tulnp | grep hysteria

# 配置信息
sudo ls -la /etc/hysteria/
sudo cat /etc/hysteria/config.yaml
```

## 获取帮助

如果以上方法都无法解决问题，请：

1. **收集错误信息**: 记录完整的错误消息和日志
2. **提供系统信息**: 包括操作系统版本、内核版本等
3. **描述操作步骤**: 详细说明执行了哪些操作
4. **提交 Issue**: 在 GitHub 仓库提交详细的问题报告

**GitHub 仓库**: https://github.com/sindricn/s-hy2

**常用命令汇总**:
```bash
# 测试安装环境
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/test-install.sh | sudo bash

# 简化安装
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install-simple.sh | sudo bash

# 调试安装
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash -s -- --debug

# 手动运行
sudo /opt/s-hy2/hy2-manager.sh

# 重新安装
sudo rm -rf /opt/s-hy2 /usr/local/bin/s-hy2 /usr/local/bin/hy2-manager
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install-simple.sh | sudo bash
```
