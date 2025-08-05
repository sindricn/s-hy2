# Hysteria2 卸载指南

本指南详细说明如何正确卸载 Hysteria2 服务器和配置管理脚本。

## 卸载方式对比

| 卸载方式 | 程序文件 | 配置文件 | 证书文件 | 用户账户 | 管理脚本 | 适用场景 |
|---------|---------|---------|---------|---------|---------|---------|
| 方式1: 仅卸载服务器 | ✅ 删除 | ❌ 保留 | ❌ 保留 | ❌ 保留 | ❌ 保留 | 临时卸载、升级、重装 |
| 方式2: 卸载服务器及配置 | ✅ 删除 | ✅ 删除 | ✅ 删除 | ✅ 删除 | ❌ 保留 | 清理配置，保留脚本 |
| 方式3: 卸载所有内容 | ✅ 删除 | ✅ 删除 | ✅ 删除 | ✅ 删除 | ✅ 删除 | 彻底清理、不再使用 |

## 方式一：仅卸载 Hysteria2 服务器

### 适用场景
- 临时卸载，计划重新安装
- 系统升级或重装前的准备
- 保留配置以备后用
- 测试不同版本

### 操作步骤

1. **运行管理脚本**
   ```bash
   sudo s-hy2
   ```

2. **选择卸载选项**
   - 选择 `9. 卸载服务`
   - 选择 `1. 仅卸载 Hysteria2 服务器 (保留配置文件)`

3. **确认卸载**
   - 输入 `y` 确认

### 卸载结果

**删除的内容：**
- `/usr/local/bin/hysteria` - 主程序文件
- `/etc/systemd/system/hysteria-server.service` - 系统服务文件
- `/etc/systemd/system/hysteria-server@.service` - 系统服务模板

**保留的内容：**
- `/etc/hysteria/config.yaml` - 配置文件
- `/etc/hysteria/server.crt` - SSL 证书 (如果存在)
- `/etc/hysteria/server.key` - SSL 私钥 (如果存在)
- `/etc/hysteria/*.backup.*` - 配置备份文件
- `hysteria` 用户账户

### 手动清理 (可选)

如果后续不再需要这些文件，可以手动清理：

```bash
# 删除配置目录
sudo rm -rf /etc/hysteria

# 删除用户账户
sudo userdel -r hysteria

# 清理 systemd 服务残留
sudo rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service
sudo rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service
sudo systemctl daemon-reload
```

## 方式二：卸载 Hysteria2 服务器及配置文件

### 适用场景
- 清理所有配置，但保留管理脚本
- 重新开始全新配置
- 清理测试环境
- 保留脚本便于重新部署

### 操作步骤

1. **运行管理脚本**
   ```bash
   sudo s-hy2
   ```

2. **选择卸载选项**
   - 选择 `9. 卸载服务`
   - 选择 `2. 卸载 Hysteria2 服务器及配置文件`

3. **确认卸载**
   - 输入 `y` 确认

### 卸载结果

**删除的内容：**
- Hysteria2 程序文件
- 所有配置文件和证书
- hysteria 用户账户
- systemd 服务文件
- 端口跳跃 iptables 规则

**保留的内容：**
- 管理脚本 (s-hy2)

## 方式三：卸载脚本及 Hysteria2 服务器和所有文件

### 适用场景
- 不再使用 Hysteria2 和管理脚本
- 彻底清理系统
- 服务器用途完全改变
- 完全移除所有相关文件

### 操作步骤

1. **运行管理脚本**
   ```bash
   sudo s-hy2
   ```

2. **选择完全卸载**
   - 选择 `9. 卸载服务`
   - 选择 `3. 卸载脚本及 Hysteria2 服务器和所有文件`

3. **确认卸载**
   - 输入 `YES` (必须大写) 确认

### 卸载过程

脚本会按以下步骤执行：

1. **清理端口跳跃配置** - 删除 iptables 规则
2. **卸载程序** - 使用官方卸载脚本
3. **删除配置** - 删除 `/etc/hysteria` 目录
4. **删除用户** - 删除 `hysteria` 用户账户
5. **清理服务** - 清理 systemd 服务残留
6. **清理规则残留** - 删除可能的 iptables 规则残留
7. **删除快捷方式** - 删除 s-hy2 和 hy2-manager 命令
8. **删除脚本目录** - 删除 `/opt/s-hy2` 目录

### 卸载结果

**完全删除的内容：**
- 所有程序文件
- 所有配置文件和备份
- 所有 SSL 证书
- hysteria 用户账户
- systemd 服务文件
- 端口跳跃配置和规则
- 管理脚本和快捷命令
- 桌面快捷方式

## 卸载验证

### 检查程序是否已删除
```bash
# 检查程序文件
which hysteria
# 应该显示: hysteria not found

# 检查命令是否可用
hysteria --version
# 应该显示: command not found
```

### 检查服务状态
```bash
# 检查服务状态
sudo systemctl status hysteria-server
# 应该显示: Unit hysteria-server.service could not be found

# 检查服务文件
ls -la /etc/systemd/system/hysteria-server*
# 应该显示: No such file or directory
```

### 检查配置文件 (仅程序卸载时)
```bash
# 检查配置目录
ls -la /etc/hysteria/
# 仅程序卸载: 显示配置文件
# 完全卸载: No such file or directory
```

### 检查用户账户 (仅程序卸载时)
```bash
# 检查用户是否存在
id hysteria
# 仅程序卸载: 显示用户信息
# 完全卸载: no such user
```

### 检查端口监听
```bash
# 检查端口是否还在监听
sudo netstat -tulnp | grep :443
# 应该没有 hysteria 相关的监听
```

## 重新安装

### 从方式1卸载后重新安装

由于配置文件保留，重新安装后可以直接使用：

```bash
# 重新安装
sudo s-hy2
# 选择 "1. 安装 Hysteria2"

# 启动服务
sudo s-hy2
# 选择 "4. 管理服务" -> "1. 启动服务"
```

### 从方式2卸载后重新安装

需要重新配置：

```bash
# 安装程序
sudo s-hy2
# 选择 "1. 安装 Hysteria2"

# 一键快速配置
sudo s-hy2
# 选择 "2. 一键快速配置"
```

### 从方式3卸载后重新安装

需要重新安装脚本和配置：

```bash
# 重新安装脚本
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash

# 运行脚本
sudo s-hy2

# 安装 Hysteria2
# 选择 "1. 安装 Hysteria2"

# 一键快速配置
# 选择 "2. 一键快速配置"
```

## 卸载管理脚本

如果不再需要配置管理脚本：

```bash
# 方法1: 使用脚本内置卸载功能 (推荐)
sudo s-hy2
# 选择 "9. 卸载服务" -> "3. 卸载脚本及 Hysteria2 服务器和所有文件"

# 方法2: 使用安装脚本卸载
sudo /opt/s-hy2/install.sh --uninstall

# 方法3: 手动删除
sudo rm -rf /opt/s-hy2
sudo rm -f /usr/local/bin/hy2-manager
sudo rm -f /usr/local/bin/s-hy2
sudo rm -f ~/Desktop/S-Hy2-Manager.desktop  # 如果创建了桌面快捷方式
```

## 故障排除

### 卸载失败

如果卸载过程中出现错误：

1. **检查网络连接**
   ```bash
   curl -I https://get.hy2.sh/
   ```

2. **手动停止服务**
   ```bash
   sudo systemctl stop hysteria-server
   sudo systemctl disable hysteria-server
   ```

3. **手动删除文件**
   ```bash
   sudo rm -f /usr/local/bin/hysteria
   sudo rm -f /etc/systemd/system/hysteria-server*
   sudo systemctl daemon-reload
   ```

### 残留文件清理

如果发现有残留文件：

```bash
# 查找所有相关文件
sudo find / -name "*hysteria*" 2>/dev/null

# 查找相关进程
ps aux | grep hysteria

# 查找相关端口
sudo netstat -tulnp | grep hysteria
```

### 权限问题

如果遇到权限问题：

```bash
# 确保以 root 权限运行
sudo su -

# 强制删除文件
sudo rm -rf /etc/hysteria
sudo userdel -f hysteria 2>/dev/null
```

## 注意事项

1. **备份重要数据** - 卸载前备份重要的配置文件
2. **确认卸载方式** - 根据实际需求选择合适的卸载方式
3. **检查依赖服务** - 确保没有其他服务依赖 Hysteria2
4. **防火墙规则** - 卸载后可能需要手动清理防火墙规则
5. **客户端配置** - 卸载后记得更新客户端配置

## 常见问题

**Q: 卸载后还能恢复配置吗？**
A: 如果选择"仅卸载程序"，配置文件会保留，重新安装后可以直接使用。

**Q: 完全卸载后如何恢复？**
A: 完全卸载后无法自动恢复，需要重新配置。建议卸载前备份配置文件。

**Q: 卸载会影响其他服务吗？**
A: 正常情况下不会，但如果有自定义的 iptables 规则可能需要手动清理。

**Q: 如何确认卸载是否成功？**
A: 按照"卸载验证"部分的步骤检查各项内容是否已删除。
