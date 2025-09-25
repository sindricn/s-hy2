---
title: 更新日志
hide:
  - navigation
---

## 2.6.3

- 新增 mTLS 客户端证书验证
- 修复 tun 模式下一个内存泄漏问题
- 修复使用 systemd-resolved 的 Linux 设备上 tun 模式 DNS 解析失败的问题
- 修复一个 ACL 中协议/端口不匹配的规则被错误应用到其他连接的 bug
- 移除许可协议不兼容的 DoH 库，改为自行实现
- 修复一个 UDP session 处理的线程安全问题

## 2.6.2

- quic-go 更新到 v0.52.0
  - 现在 TLS 握手时会对 ClientHello 进行分片，可绕过部分防火墙的 SNI 过滤
- 客户端模式的 `--qr` 参数已不推荐使用，可用 share 子命令生成共享链接与二维码

## 2.6.1

- 服务端 direct outbound 支持 TCP Fast Open
- `version` 子命令的输出中将 `LibVersion` 改为 `Libraries`
- 伪装代理网站回源支持禁用 TLS 验证 (`insecure`)
- 修复在 Linux 上 `ipv6.disable=1` 时 tun 无法正常工作的 bug
- 添加对 `LoongArch64` 的支持 (64 位龙芯)
- quic-go 更新到 v0.49.0
- `userpass` 认证中的用户名不再区分大小写

## 2.6.0

> 此版本包含重要修复，强烈建议更新

- 修复一个端口跳跃范围包含 65535 时客户端启动会卡死的 bug
- 流量统计 API 新增 `/dump/streams` 接口，用于获取当前所有 QUIC 流的信息
- quic-go 更新到 v0.48.1
- `version` 子命令新增工具链和 quic-go 版本信息
- 客户端新增 `share` 子命令，用于生成分享链接和二维码
- 服务端现在会验证 `masquerade.proxy.url` 字段是否为有效的 HTTP 或 HTTPS URL

## 2.5.2

- 服务端现在默认会在客户端发送的 SNI 与证书不匹配时终止 TLS 握手，并在 `tls` 中新增了 `sniGuard` 选项用于控制此行为
- 修复了 sniff 无法嗅探分片后的 QUIC 包的问题
- quic-go 更新到 v0.47.0

## 2.5.1

- 修复了 HTTP 嗅探中一个导致所有非标准端口 (非 80) 连接会发生错误的问题
- 修复了客户端解析分享链接时未对认证密码部分进行转义的问题
- quic-go 更新到 v0.46.0

## 2.5.0

- 新增 ACME DNS 验证支持，支持 Cloudflare, GoDaddy, Name.com 等多个常见服务商
- 新增服务端协议嗅探 (Sniff)，支持 HTTP, TLS (HTTPS) 和 QUIC (HTTP/3) 协议
- 修复测速命令中速度显示单位转换不准确的问题 (1024 -> 1000)

## 2.4.5

- 修复 BBR 中的一些逻辑问题，并新增 `HYSTERIA_BBR_DEBUG` 环境变量用于输出 BBR 调试信息
- 修复 HTTP 代理对某些程序的兼容性问题
- quic-go 更新到 v0.44.0

## 2.4.4

> 此版本包含重要修复，强烈建议更新

- 修复 2.4.2-2.4.3 中 quic-go 存在的一个内存泄漏问题
- 流量统计 API 新增 GET `/online` 接口，用于查询当前在线用户与其连接数
- 客户端退出时将优雅关闭 QUIC 连接，服务端无需再等待超时

## 2.4.3

> 此版本包含重要修复，强烈建议更新

- 修复上个版本引入的一个导致 UDP 转发无法正常工作的 bug

## 2.4.2

- 对 Brutal 进行了细微调整，提升在高速下的性能
- 当使用本地证书时，服务端会在启动时检查文件是否能被正常访问，避免访问错误在接受客户端连接时才出现。
- quic-go 更新到 v0.43.0

## 2.4.1

- 客户端现已支持在同一端口上同时监听 HTTP 和 SOCKS5，只需将它们的 `listen` 地址设置为相同即可
- 客户端在 `quic` 下新增了 `sockopts` 部分，允许用户为出站的 QUIC 连接绑定指定网卡、设置 fwmark 和 FD control socket 路径。此功能主要用于 Android 代理应用的开发。

## 2.4.0

- 客户端新增 TUN 模式，支持 Windows, Linux 和 macOS
- ACL 端口匹配支持范围 (如 `reject(all, udp/40000-50000)`)
- 服务端 ACME 配置新增 `listenHost` 字段，用于指定接收验证请求的监听地址
- quic-go 更新到 v0.42.0
- 被代理的连接的错误日志级别由 error 降低到 warning

## 2.3.0

- 客户端新增速度测试子命令，以及对应的服务端支持
- 如果 GeoIP/GeoSite 数据库加载失败，会自动尝试重新下载
- 改进了 SOCKS5 出站错误信息的显示
- 修复了在 FreeBSD 上双栈监听地址实际上只监听 IPv6 的 bug

## 2.2.4

> 此版本包含重要修复，强烈建议更新

- **[重要]** 修复一个连接超时会阻塞其他连接建立的 bug
- quic-go 更新到 v0.41.0

## 2.2.3

- 修复了即使显式使用 IPv4/IPv6 监听地址（如 `0.0.0.0:443` 或 `[::]:443`）仍会同时监听 IPv4/IPv6 的问题
- 开启懒狗模式的情况下，服务器域名解析推迟到需要连接时
- 每次 TLS 握手时都会重新读取本地证书，以便用户能够在不重启服务器的情况下更新文件

## 2.2.2

- 修复了上个版本引入的一个导致客户端无法自动重连的 bug
- ACL 新增 `suffix:` 支持，用来匹配一个域名和其所有子域名 (例如 `reject(suffix:baidu.com)`)

## 2.2.1

- 添加了 GeoIP 和 GeoSite 自动更新功能（ACL 下的 `geoUpdateInterval` 字段，默认为一周）
- 客户端现在在连接到服务器后会显示握手信息，目前包括 UDP 转发是否开启和协商的传输速率
- 带宽单位换算（Kbps/Mbps/Gbps/Tbps）从 1024 改为 1000
- 添加了 RISC-V (riscv64) 支持
- quic-go 更新到 v0.40.0

## 2.2.0

- ACL 新增 GeoSite 支持 (GeoIP 和 GeoSite 现在都使用 v2ray 的 "dat" 格式数据库)
- ACL 新增对非英文域名 (IDN) 的支持 (例如 `v6_only(战狼*.中国)`)
- 伪装 (masquerade) proxy 模式添加 WebSocket 支持
- 流量统计 API 新增基于密钥 (secret) 的认证
- 修复某些 Linux 系统上的兼容性问题

## 2.1.1

> 此版本包含重要修复，强烈建议更新

- 修复一个通过构造特殊的 UDP message 包可以导致服务端崩溃的问题
- 修复 FreeBSD 上的兼容性问题
- Windows 用户现在可以通过双击 exe 文件直接启动程序了

## 2.1.0

- 修复 BBR 内存泄漏问题
- 微调 Brutal 拥塞控制
- 伪装 (masquerade) 新增字符串 (string) 模式
- 出站 (outbound) 新增 HTTP/HTTPS 代理

## 2.0.4

- 优化并修复 Brutal 拥塞控制中的一些问题
- 修复 BBR 在特定条件下导致连接卡死且 CPU 占用飙升的问题
- 修复两个线程安全问题
- 新增 `HYSTERIA_BRUTAL_DEBUG` 环境变量，开启后可输出当前延迟、丢包率、MTU 等信息

## 2.0.3

> 此版本包含重要修复，强烈建议更新

- **[重要]** 修复在使用 BBR (即客户端不写带宽，或服务端开启了 `ignoreClientBandwidth`) 的情况下，由于 BBR 实现的 bug 导致无法准确判断带宽上限，发包速率过快的问题。
- 修复 ZeroSSL 缺少 EAB 无法获取证书的问题

## 2.0.2

- 修复在某些设备上由于不支持 GSO 导致的无法连接/断流问题
- 新增 HTTP/HTTPS (TCP) 伪装服务器
- 新增 Android 构建

## 2.0.1

- 新增 TCP Redirect 模式
- 在日志中输出伪装模式收到的 HTTP 请求 (debug 级别)
- 新增环境变量 `HYSTERIA_ACME_DIR`，用于设置 ACME 目录的位置

## 2.0.0

这是 Hysteria 2 的第一个稳定版本。几乎完全重写了 Hysteria 原有的代码，包括新的协议、新的功能和各种改进。
