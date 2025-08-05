# Hysteria2 配置管理脚本部署指南

## 快速部署

### 方法一：一键安装（推荐）

```bash
# 一键安装到服务器
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash

# 运行脚本
sudo s-hy2
```

### 方法二：GitHub 克隆安装

```bash
# 克隆仓库
git clone https://github.com/sindricn/s-hy2.git
cd s-hy2

# 运行安装脚本
sudo ./install.sh

# 或直接运行主脚本
sudo ./hy2-manager.sh
```

### 方法二：手动部署

```bash
# 1. 克隆仓库
git clone https://github.com/your-repo/hy2-manager.git
cd hy2-manager

# 2. 设置权限
chmod +x hy2-manager.sh
chmod +x scripts/*.sh

# 3. 创建符号链接（可选）
sudo ln -sf $(pwd)/hy2-manager.sh /usr/local/bin/hy2-manager

# 4. 运行脚本
sudo ./hy2-manager.sh
```

## 使用流程

### 新手推荐流程（一键快速配置）

1. **运行管理脚本**
   ```bash
   sudo s-hy2
   ```

2. **安装 Hysteria2**
   - 选择菜单选项 `1. 安装 Hysteria2`
   - 脚本会自动检测系统环境并安装

3. **一键快速配置**
   - 选择菜单选项 `2. 一键快速配置`
   - 脚本会自动完成所有配置并启动服务

4. **查看节点信息**
   - 选择菜单选项 `8. 节点信息`
   - 获取节点链接和客户端配置

### 高级用户流程（手动配置）

1. **运行管理脚本**
   ```bash
   sudo s-hy2
   ```

2. **安装 Hysteria2**
   - 选择菜单选项 `1. 安装 Hysteria2`

3. **手动配置**
   - 选择菜单选项 `3. 手动配置`
   - 选择配置模式（ACME 或自签名证书）
   - 按提示输入相关信息

4. **启动服务**
   - 选择菜单选项 `4. 管理服务`
   - 选择 `1. 启动服务`
   - 选择 `4. 启用开机自启`

### 配置模式选择

#### ACME 自动证书模式（推荐生产环境）

**优点：**
- 自动申请和续期 SSL 证书
- 高安全性，证书被广泛信任
- 无需手动管理证书

**要求：**
- 拥有有效域名
- 域名已解析到服务器 IP
- 服务器可访问互联网
- 有效的邮箱地址

**配置步骤：**
1. 确保域名解析正确
2. 输入域名（如：example.com）
3. 输入邮箱地址
4. 设置认证密码
5. 选择伪装网站

#### 自签名证书模式（适合测试环境）

**优点：**
- 无需域名，快速部署
- 适合内网或测试环境
- 配置简单

**缺点：**
- 证书不被信任
- 客户端需要忽略证书错误

**配置步骤：**
1. 选择伪装域名
2. 设置认证密码
3. 自动生成证书

## 进阶配置

### 域名优化

使用脚本的域名测试功能选择最优伪装域名：

1. 选择菜单选项 `5. 测试伪装域名`
2. 选择 `2. 交互式选择域名`
3. 等待测试完成，选择延迟最低的域名

### 端口配置

如果默认 443 端口被占用：

1. 选择菜单选项 `6. 进阶配置`
2. 选择 `1. 修改监听端口`
3. 输入新端口号
4. 确保防火墙允许新端口

### 混淆配置

在网络环境较差时启用混淆：

1. 选择菜单选项 `6. 进阶配置`
2. 选择 `2. 添加混淆配置`
3. 设置混淆密码
4. 客户端需要配置相同密码

### 端口跳跃

提高连接稳定性：

1. 选择菜单选项 `6. 进阶配置`
2. 选择 `4. 配置端口跳跃`
3. 选择网络接口
4. 设置端口范围

## 客户端配置

### 基本配置

```yaml
server: your.server.com:443
auth: your_password
tls:
  sni: your.server.com
  insecure: false  # ACME 证书设为 false，自签名设为 true
socks5:
  listen: 127.0.0.1:1080
http:
  listen: 127.0.0.1:8080
```

### 混淆配置（如果服务器启用）

```yaml
obfs:
  type: salamander
  salamander:
    password: your_obfs_password
```

## 防火墙配置

### Ubuntu/Debian (UFW)

```bash
# 允许 Hysteria2 端口
sudo ufw allow 443/udp

# 如果使用自定义端口
sudo ufw allow YOUR_PORT/udp

# 启用防火墙
sudo ufw enable
```

### CentOS/RHEL (firewalld)

```bash
# 允许 Hysteria2 端口
sudo firewall-cmd --permanent --add-port=443/udp

# 如果使用自定义端口
sudo firewall-cmd --permanent --add-port=YOUR_PORT/udp

# 重载配置
sudo firewall-cmd --reload
```

## 监控和维护

### 查看服务状态

```bash
# 使用脚本查看
sudo hy2-manager
# 选择 "3. 管理服务"

# 或直接使用系统命令
sudo systemctl status hysteria-server
```

### 查看日志

```bash
# 实时日志
sudo journalctl -f -u hysteria-server

# 历史日志
sudo journalctl -u hysteria-server --since "1 hour ago"
```

### 配置备份

脚本会自动备份配置文件，手动备份：

```bash
sudo cp /etc/hysteria/config.yaml /etc/hysteria/config.yaml.backup.$(date +%Y%m%d_%H%M%S)
```

## 故障排除

### 常见问题

1. **服务启动失败**
   ```bash
   # 检查配置文件
   sudo hysteria server --config /etc/hysteria/config.yaml --check
   
   # 查看详细日志
   sudo journalctl -u hysteria-server -n 50
   ```

2. **证书申请失败**
   - 检查域名解析：`nslookup your.domain.com`
   - 检查端口开放：`sudo netstat -tulnp | grep :80`
   - 检查防火墙设置

3. **连接失败**
   - 检查服务状态：`sudo systemctl status hysteria-server`
   - 检查端口监听：`sudo netstat -tulnp | grep :443`
   - 验证客户端配置

### 重新配置

如果需要重新配置：

1. 停止服务：选择 "管理服务" -> "停止服务"
2. 重新生成配置：选择 "生成配置文件"
3. 启动服务：选择 "管理服务" -> "启动服务"

## 卸载

### 卸载 Hysteria2

脚本提供两种卸载方式，根据需要选择：

#### 方式一：仅卸载程序 (推荐)

适用于：
- 临时卸载，可能重新安装
- 保留配置以备后用
- 升级或重装系统前备份

操作步骤：
1. 运行 `sudo hy2-manager`
2. 选择 `7. 卸载服务`
3. 选择 `1. 仅卸载程序 (保留配置文件和证书)`
4. 确认卸载

**保留内容：**
- 配置文件：`/etc/hysteria/config.yaml`
- SSL 证书文件
- hysteria 用户账户
- 自定义配置和备份

**手动清理命令：**
```bash
# 如需完全清理，可执行以下命令
sudo rm -rf /etc/hysteria
sudo userdel -r hysteria
sudo rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service
sudo rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service
sudo systemctl daemon-reload
```

#### 方式二：完全卸载

适用于：
- 不再使用 Hysteria2
- 彻底清理系统
- 重新开始配置

操作步骤：
1. 运行 `sudo hy2-manager`
2. 选择 `7. 卸载服务`
3. 选择 `2. 完全卸载 (删除所有文件)`
4. 输入 `YES` 确认

**删除内容：**
- Hysteria2 程序文件
- 所有配置文件和证书
- hysteria 用户账户
- systemd 服务文件
- 端口跳跃 iptables 规则

### 卸载管理脚本

```bash
# 如果使用安装脚本安装
sudo /opt/hy2-manager/install.sh --uninstall

# 或手动删除
sudo rm -rf /opt/hy2-manager
sudo rm -f /usr/local/bin/hy2-manager
```

### 卸载后验证

```bash
# 检查程序是否已删除
which hysteria

# 检查服务是否已停止
sudo systemctl status hysteria-server

# 检查配置目录 (仅程序卸载时可能存在)
ls -la /etc/hysteria

# 检查用户是否存在 (仅程序卸载时可能存在)
id hysteria
```

## 安全建议

1. **使用强密码**：认证密码和混淆密码都应使用强密码
2. **定期更新**：定期更新 Hysteria2 到最新版本
3. **监控日志**：定期检查服务日志，发现异常及时处理
4. **防火墙配置**：只开放必要的端口
5. **证书管理**：ACME 证书会自动续期，自签名证书需要定期更新

## 性能优化

1. **选择最优伪装域名**：使用脚本的域名测试功能
2. **合理设置带宽**：根据服务器带宽设置合理限制
3. **启用混淆**：在网络环境较差时启用混淆
4. **端口跳跃**：在需要时配置端口跳跃提高稳定性

## 技术支持

如遇到问题，请：

1. 查看日志文件
2. 检查配置文件
3. 参考故障排除指南
4. 提交 Issue 到项目仓库
