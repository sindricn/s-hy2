# 服务端安装脚本

Hysteria 项目提供了一个 bash 脚本， 可以在常见的 Linux 发行版上维护（安装、升级、卸载） Hysteria 及其 systemd 服务。

> **注意：** 官方的安装脚本旨在实现与包管理器类似的安装效果， 仅会生成示例配置文件。
> 仍需手动完成 [服务端配置](./Server.md)， 才能正常启动服务。
>
> 如需能够一键安装、配置、启动 Hysteria 服务端的「傻瓜式」脚本， 请通过搜索引擎寻找第三方的「Hysteria 2 一键脚本」。

## 环境要求

Hysteria 本身并无 Linux 发行版相关的要求，
但安装脚本在设计上仅在满足下列条件的 Linux 系统上运行：

- 基于 systemd 管理服务（通过 `systemctl` 命令）
- 安装有以下程序， 并且不是通过 busybox 提供。
  - [GNU Coreutils 工具集](https://zh.wikipedia.org/wiki/GNU%E6%A0%B8%E5%BF%83%E5%B7%A5%E5%85%B7%E7%BB%84)
  - `bash`
  - `grep`
  - `curl`

对于新购 VPS 的用户，建议使用发布不超过 2 年的主流发行版稳定版本。 **请避免使用 CentOS 7**。

如果不熟悉 Linux 发行版， 推荐以下选择：

- Debian 11 或更高版本
- Ubuntu 22.04 LTS 或更高的 LTS 版本
- Rocky Linux 8 或更高版本
- CentOS Stream 8 或更高版本
- Fedora 37 或更高版本

**不支持** 的发行版：

- OpenWrt
- Alpine Linux
- NixOS

## 常用操作

### 安装或升级

安装或升级到最新版本。

```sh
bash <(curl -fsSL https://get.hy2.sh/)
```

安装或升级为指定版本，不进行版本检查。

```sh
bash <(curl -fsSL https://get.hy2.sh/) --version v2.6.3
```

### 卸载

移除 Hysteria 及相关服务。

```sh
bash <(curl -fsSL https://get.hy2.sh/) --remove
```

## 进阶操作

### 安装本地文件

如果 VPS 与 GitHub Release 连接不畅， 可以手动将 Hysteria 可执行文件传输到 VPS 上进行安装。

```sh
bash <(curl -fsSL https://get.hy2.sh/) --local /path/to/hysteria-linux-amd64
```

### 指定架构

主要用于安装 AVX 版本。

```sh
ARCHITECTURE=amd64-avx bash <(curl -fsSL https://get.hy2.sh/)
```

### 指定用户

如果不希望处理权限问题（通常是因为使用其它程序生成和管理证书所致），
可以通过以下命令， 将 Hysteria 的 systemd 服务配置成使用 root 用户运行。

```sh
HYSTERIA_USER=root bash <(curl -fsSL https://get.hy2.sh/)
```

如需重置此项设置， 可移除 Hysteria 再重新安装， 也可执行以下命令。

```sh
HYSTERIA_USER=hysteria bash <(curl -fsSL https://get.hy2.sh/)
```

## 杂项

### 编辑配置文件

```sh
nano /etc/hysteria/config.yaml
```

### 服务管理

设置开机自启， 并立即启动服务。

```sh
systemctl enable --now hysteria-server.service
```

重启服务， 通常在修改配置文件后执行。

```sh
systemctl restart hysteria-server.service
```

查询服务状态。

```sh
systemctl status hysteria-server.service
```

### 日志

查询服务端日志。

```sh
journalctl --no-pager -e -u hysteria-server.service
```
