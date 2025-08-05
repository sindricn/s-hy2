# Hysteria2 配置管理脚本使用说明

## 快速开始

### 方法一：一键安装（推荐）

```bash
# 一键安装到服务器
curl -fsSL https://raw.githubusercontent.com/sindricn/s-hy2/main/quick-install.sh | sudo bash

# 运行脚本
sudo s-hy2
```

### 方法二：手动安装

```bash
# 下载脚本
wget https://raw.githubusercontent.com/sindricn/s-hy2/main/hy2-manager.sh

# 添加执行权限
chmod +x hy2-manager.sh

# 运行脚本
sudo ./hy2-manager.sh
```

## 使用流程

### 新手推荐流程 (一键快速配置)

1. **运行管理脚本**
   ```bash
   sudo s-hy2
   ```

2. **安装 Hysteria2**
   - 选择菜单选项 `1. 安装 Hysteria2`
   - 脚本会自动检测系统环境并安装

3. **一键快速配置**
   - 选择菜单选项 `2. 一键快速配置`
   - 脚本会自动执行以下步骤：
     - 获取服务器公网IP和网络接口
     - 测试并选择最优伪装域名
     - 生成随机认证密码和混淆密码
     - 生成自签名证书
     - 配置端口跳跃 (20000-50000)
     - 启动服务并设置开机自启

4. **查看节点信息**
   - 选择菜单选项 `8. 节点信息`
   - 获取节点链接、订阅链接和客户端配置

### 高级用户流程 (手动配置)

1. **安装 Hysteria2** - 选择菜单选项 `1. 安装 Hysteria2`
2. **手动配置** - 选择菜单选项 `3. 手动配置`
3. **管理服务** - 选择菜单选项 `4. 管理服务`

## 详细功能说明

### 安装功能

脚本会自动：
- 检查系统环境
- 更新系统包
- 安装必要依赖
- 下载并安装 Hysteria2
- 创建配置目录

### 配置生成

支持两种配置模式：

#### ACME 自动证书模式 (推荐)
- **优点**: 自动申请和续期证书，安全性高
- **要求**: 需要有效域名，域名需解析到服务器
- **适用**: 生产环境

配置步骤：
1. 输入域名 (如: example.com)
2. 输入邮箱地址
3. 设置认证密码
4. 选择伪装网站

#### 自签名证书模式
- **优点**: 无需域名，快速部署
- **缺点**: 证书不被信任，需要客户端忽略证书错误
- **适用**: 测试环境

配置步骤：
1. 选择伪装域名
2. 设置认证密码
3. 自动生成自签名证书

### 伪装域名优化

脚本提供智能域名选择功能：

1. **自动测试**: 测试预设的优质域名列表
2. **延迟排序**: 按延迟从低到高排序
3. **交互选择**: 可手动选择最优域名
4. **自定义测试**: 支持测试自定义域名

预设域名包括：
- Cloudflare CDN
- Google 服务
- Microsoft 服务
- Apple 服务
- AWS 服务
- 其他知名 CDN

### 服务管理

提供完整的服务管理功能：

#### 服务操作
- **启动服务**: `systemctl start hysteria-server`
- **停止服务**: `systemctl stop hysteria-server`
- **重启服务**: `systemctl restart hysteria-server`
- **开机自启**: `systemctl enable hysteria-server`

#### 状态查看
- 服务运行状态
- 端口监听状态
- 进程信息
- 配置文件状态

#### 日志管理
- 实时日志查看
- 历史日志查询
- 按时间筛选
- 按行数限制

### 进阶配置

#### 端口修改
- 修改默认 443 端口
- 检查端口占用
- 自动更新配置
- 防火墙提醒

#### 混淆配置
- 添加 Salamander 混淆
- 自动生成混淆密码
- 移除混淆配置
- 客户端配置提醒

#### 端口跳跃
- 自动检测网卡
- 配置端口范围
- 生成 iptables 规则
- 规则持久化

## 配置文件说明

### 基本配置项

```yaml
# 监听端口
listen: :443

# 认证配置
auth:
  type: password
  password: your_password

# 伪装配置
masquerade:
  type: proxy
  proxy:
    url: https://example.com/
    rewriteHost: true
```

### 高级配置项

```yaml
# 混淆配置
obfs:
  type: salamander
  salamander:
    password: obfs_password

# 带宽限制
bandwidth:
  up: 1 gbps
  down: 1 gbps

# ACL 访问控制
acl: /etc/hysteria/acl.txt
```

## 卸载说明

脚本提供两种卸载方式：

### 方式一：仅卸载程序 (推荐)

这种方式只删除 Hysteria2 程序文件，保留配置文件和证书：

1. 选择菜单选项 `7. 卸载服务`
2. 选择 `1. 仅卸载程序 (保留配置文件和证书)`
3. 确认卸载

**保留的文件：**
- 配置文件：`/etc/hysteria/config.yaml`
- SSL 证书：`/etc/hysteria/server.crt` 和 `/etc/hysteria/server.key`
- 用户账户：`hysteria`

**如需完全清理，可手动执行：**
```bash
# 删除配置文件和证书
sudo rm -rf /etc/hysteria

# 删除用户账户
sudo userdel -r hysteria

# 清理 systemd 服务残留
sudo rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service
sudo rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service
sudo systemctl daemon-reload
```

### 方式二：完全卸载

这种方式删除所有 Hysteria2 相关文件：

1. 选择菜单选项 `7. 卸载服务`
2. 选择 `2. 完全卸载 (删除所有文件)`
3. 输入 `YES` 确认

**删除的内容：**
- Hysteria2 程序文件
- 所有配置文件和证书
- hysteria 用户账户
- systemd 服务文件
- 端口跳跃 iptables 规则

## 故障排除

### 常见问题

1. **服务启动失败**
   - 检查配置文件语法
   - 查看服务日志
   - 确认端口未被占用

2. **证书申请失败**
   - 确认域名解析正确
   - 检查防火墙设置
   - 验证邮箱地址

3. **连接失败**
   - 检查防火墙规则
   - 确认端口开放
   - 验证客户端配置

### 日志查看

```bash
# 查看服务状态
systemctl status hysteria-server

# 查看实时日志
journalctl -f -u hysteria-server

# 查看历史日志
journalctl -u hysteria-server --since "1 hour ago"
```

### 配置验证

```bash
# 验证配置文件语法
hysteria server --config /etc/hysteria/config.yaml --check

# 测试配置文件
hysteria server --config /etc/hysteria/config.yaml --test
```

## 安全建议

1. **使用强密码**: 认证密码和混淆密码都应使用强密码
2. **定期更新**: 定期更新 Hysteria2 到最新版本
3. **监控日志**: 定期检查服务日志，发现异常及时处理
4. **防火墙配置**: 只开放必要的端口
5. **证书管理**: ACME 证书会自动续期，自签名证书需要定期更新

## 性能优化

1. **选择最优伪装域名**: 使用脚本的域名测试功能
2. **合理设置带宽**: 根据服务器带宽设置合理限制
3. **启用混淆**: 在网络环境较差时启用混淆
4. **端口跳跃**: 在需要时配置端口跳跃提高稳定性

## 客户端配置

服务器配置完成后，需要在客户端配置相应参数：

- 服务器地址和端口
- 认证密码
- 混淆密码 (如果启用)
- 忽略证书错误 (自签名证书模式)

具体客户端配置请参考 Hysteria2 官方文档。
