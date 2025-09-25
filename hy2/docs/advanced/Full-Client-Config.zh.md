# 完整客户端配置

本页面提供了关于客户端配置文件中每一个字段的详细说明。

> **注意：** 在客户端和服务端配置中的多处都有 "类型选择" 的配置格式：

```yaml
example:
  type: a
  a:
    something: something
  b:
    something: something
  c:
    something: something
```

`type` 用于确定使用哪种模式以及解析哪些子字段。在这个例子中，`example` 字段可以是 `a`、`b` 或 `c`。如果选择了 `a`，则会解析 `a` 子字段，而 `b` 和 `c` 子字段则会被忽略。

## 服务器地址

`server` 字段用于指定客户端应连接到的 Hysteria 服务器地址。地址可以是 `host:port` 或仅 `host`。如果省略端口，默认为 443。

还可以选择使用 Hysteria 2 URI（`hysteria2://`）。在这种情况下，由于 URI 已经包括密码和一些其他设置，就不需要再在配置中单独指定它们。

=== "地址"

    ```yaml
    server: example.com
    ```

=== "URI"

    ```yaml
    server: hysteria2://user:pass@example.com/
    ```

## 验证

```yaml
auth: some_password
```

> **注意：** 如果服务器使用 `userpass` 验证，格式必须是 `username:password`。

## TLS

```yaml
tls:
  sni: another.example.com # (1)!
  insecure: false # (2)!
  pinSHA256: BA:88:45:17:A1... # (3)!
  ca: custom_ca.crt # (4)!
  clientCertificate: client.crt # (5)!
  clientKey: client.key # (6)!
```

1. 用于 TLS 验证的服务器名称。如果省略，服务器名称将从 `server` 字段中提取。
2. 禁用 TLS 验证。
3. 验证服务器的证书指纹。可以通过 openssl 获取证书指纹：`openssl x509 -noout -fingerprint -sha256 -in your_cert.crt`
4. 使用自定义 CA。
5. 使用客户端证书进行 mTLS 验证。
6. 使用客户端密钥进行 mTLS 验证。

## 传输 (Transport)

`transport` 用于自定义 QUIC 连接使用的底层协议。目前唯一可用的类型是 `udp`，保留类型选项是为了将来可能添加的其他类型。

```yaml
transport:
  type: udp # (2)!
  udp:
    hopInterval: 30s # (1)!
```

1. 端口跳跃间隔。这只在使用多端口地址时才有效。更多信息请参见 [端口跳跃](Port-Hopping.md)。
2. 传输类型。 请阅读页面最上方关于 "类型选择" 配置格式的说明。

## 混淆

默认 Hysteria 协议伪装为 HTTP/3。如果你的网络针对性屏蔽了 QUIC 或 HTTP/3 流量（但允许其他 UDP 流量），可以使用混淆来解决此问题。目前有一个名为 "Salamander" 的混淆实现，将数据包混淆成没有特征的 UDP 包。此功能需要一个混淆密码，密码在客户端和服务端必须相同。

> **注意：** 使用错误的混淆密码将导致无法连接，效果如同服务器没有运行一样。如果遇到连接问题，请先仔细检查混淆密码是否正确。

```yaml
obfs:
  type: salamander # (2)!
  salamander:
    password: cry_me_a_r1ver # (1)!
```

1. 替换为你的混淆密码。
2. 混淆类型。 请阅读页面最上方关于 "类型选择" 配置格式的说明。

## QUIC 参数

```yaml
quic:
  initStreamReceiveWindow: 8388608 # (1)!
  maxStreamReceiveWindow: 8388608 # (2)!
  initConnReceiveWindow: 20971520 # (3)!
  maxConnReceiveWindow: 20971520 # (4)!
  maxIdleTimeout: 30s # (5)!
  keepAlivePeriod: 10s # (6)!
  disablePathMTUDiscovery: false # (7)!
  sockopts:
    bindInterface: eth0 # (8)!
    fwmark: 1234 # (9)!
    fdControlUnixSocket: ./test.sock # (10)!
```

1. 初始的 QUIC 流接收窗口大小。
2. 最大的 QUIC 流接收窗口大小。
3. 初始的 QUIC 连接接收窗口大小。
4. 最大的 QUIC 连接接收窗口大小。
5. 最长空闲超时时间。客户端会在多长时间没有收到任何服务端数据后关闭连接。
6. 心跳包发送间隔。客户端会多久发送一次心跳包以保持连接。
7. 禁用 MTU 探测。
8. （仅限 Linux）接口名称。强制 QUIC 数据包通过此接口发送。
9. （仅限 Linux）要为 QUIC 数据包添加的 `SO_MARK` 标记。
10. （仅限 Linux）由其它进程监听的 Unix Socket 路径。<br>Hysteria 客户端会把 QUIC 连接所使用的文件描述符（File Descriptor）作为辅助信息（Ancillary Message）发送给该 Unix Socket，以便监听进程进行其它自定义的配置。<br>此选项可被用于 Android 客户端开发，请参考 [FD Control 协议](./FD-Control.md) 以了解更多细节。

默认的流和连接接收窗口大小分别为 8MB 和 20MB。**除非你完全明白自己在做什么，否则不建议修改这些值。**如果要改，建议保持流接收窗口与连接接收窗口的比例为 2:5。

**注意：** `sockopts` 项下的子选项目前仅对出站 QUIC 连接有效，对其它出站连接（例如为解析服务端地址而发送的 DNS 查询）无效。

## 带宽

```yaml
bandwidth:
  up: 100 mbps
  down: 200 mbps
```

Hysteria 内置了两套拥塞控制算法（BBR 与 Brutal），**使用哪个由是否提供了带宽值决定。** 如果希望使用 BBR 而不是 Brutal，可以删除整个 `bandwidth` 部分。详细信息请参见 [带宽协商流程](../advanced/Full-Server-Config.md#_6) 与 [拥塞控制细节](../advanced/Full-Server-Config.md#_7)。

> **⚠️ 警告** 带宽值并非越大越好，请务必不要超过你当前网络环境所能达到的最大带宽。否则只会适得其反，导致网络拥塞，连接不稳定。

客户端的实际上传速度将是这里指定的值，和服务器最大下载速度（如果服务器设置中指定了）中最小的值。同理，客户端的实际下载速度将是这里指定的值，和服务器最大上传速度中最小的值。

一个例外是，如果服务器启用了 `ignoreClientBandwidth` 选项，这里指定的值将被忽略。

支持的单位有：

- `bps` 或 `b`（每秒比特数）
- `kbps` 或 `kb` 或 `k`（每秒千比特）
- `mbps` 或 `mb` 或 `m`（每秒兆比特）
- `gbps` 或 `gb` 或 `g`（每秒吉比特）
- `tbps` 或 `tb` 或 `t`（每秒太比特）

## 快速打开 (Fast Open)

Fast Open 可以减少每个连接建立时一个 RTT，但代价是 SOCKS5/HTTP 等代理协议的正确语义。当这个选项启用时，客户端总是立即接受一个连接，不先与服务器确认目的地是否可达。如果服务器随后返回失败或拒绝连接，客户端将关闭连接。

```yaml
fastOpen: true
```

## 懒狗模式 (Lazy)

启用该选项后，客户端只在有传入连接的时候才会连接到服务器。默认行为是在启动时立即连接到服务器。

这个选项对于启动后可能长时间没有传入连接的情况，或者刚启动时网络不一定可用的情况很有用。

```yaml
lazy: true
```

## 代理模式

要使用 Hysteria 客户端，必须至少指定下面中的一个代理模式。

> **提示：**从 2.4.1 版本开始，Hysteria 客户端支持单端口同时支持 SOCKS5 和 HTTP 代理，只需在配置文件中同时配置 `socks5` 和 `http` 并且 `listen` 地址完全相同即可。

### SOCKS5

SOCKS5 代理服务器。支持 TCP 和 UDP。

```yaml
socks5:
  listen: 127.0.0.1:1080 # (1)!
  username: user # (2)!
  password: pass # (3)!
  disableUDP: false # (4)!
```

1. 监听地址。
2. 可选。用于验证的用户名。
3. 可选。用于验证的密码。
4. 可选。禁用 UDP 支持。

### HTTP

HTTP 代理服务器。支持 HTTP 和 HTTPS (CONNECT)。

```yaml
http:
  listen: 127.0.0.1:8080 # (1)!
  username: king # (2)!
  password: kong # (3)!
  realm: martian # (4)!
```

1. 监听地址。
2. 可选。用于验证的用户名。
3. 可选。用于验证的密码。
4. 可选。用于验证的域（realm）。

### TCP 转发

TCP 转发允许你从服务器（或任何远程主机）向客户端转发一个或多个 TCP 端口。这在某些情况下很有用，比如访问服务器本地或者内网的服务。

```yaml
tcpForwarding:
  - listen: 127.0.0.1:6600 # (1)!
    remote: 127.0.0.1:6600 # (2)!
  - listen: 127.0.0.1:6601 # (3)!
    remote: other.machine.internal:6601
```

1. 监听地址。
2. 转发地址。
3. 可以有多个转发规则。

### UDP 转发

UDP 转发允许你从服务器（或任何远程主机）向客户端转发一个或多个 UDP 端口。这在某些情况下很有用，比如访问服务器本地或者内网的服务。

```yaml
udpForwarding:
  - listen: 127.0.0.1:5300 # (1)!
    remote: 127.0.0.1:5300 # (2)!
    timeout: 20s # (3)!
  - listen: 127.0.0.1:5301 # (4)!
    remote: other.machine.internal:5301
    timeout: 20s
```

1. 监听地址。
2. 转发地址。
3. 可选。UDP 会话超时时间。如果省略，默认 60 秒。
4. 可以有多个转发规则。

### TCP TProxy (Linux)

TPROXY（透明代理）是一个仅限 Linux 的特性，允许透明代理 TCP 连接。详细信息请参阅 [配置 TPROXY](TPROXY.md)。

```yaml
tcpTProxy:
  listen: :2500 # (1)!
```

1. 监听地址。

### UDP TProxy (Linux)

TPROXY（透明代理）是一个仅限 Linux 的特性，允许透明代理 UDP 连接。详细信息请参阅 [配置 TPROXY](TPROXY.md)。

```yaml
udpTProxy:
  listen: :2500 # (1)!
  timeout: 20s # (2)!
```

1. 监听地址。
2. 可选。UDP 会话超时时间。如果省略，默认 60 秒。

### TCP Redirect (Linux)

REDIRECT 本质上是一种特殊的 DNAT，目标地址是本机。这种方法早于 TPROXY，是实现 TCP 透明代理的一种较旧方式。如果你的内核支持 TPROXY，我们建议使用 TPROXY 来代替 REDIRECT。

```yaml
tcpRedirect:
  listen: :3500
```

示例：

=== "iptables"

    ```bash
    iptables -t nat -N HYSTERIA
    iptables -t nat -A HYSTERIA -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A HYSTERIA -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A HYSTERIA -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A HYSTERIA -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A HYSTERIA -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A HYSTERIA -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A HYSTERIA -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A HYSTERIA -d 240.0.0.0/4 -j RETURN
    iptables -t nat -A HYSTERIA -p tcp -j REDIRECT --to-ports 3500
    iptables -t nat -A OUTPUT -p tcp -j HYSTERIA
    iptables -t nat -A PREROUTING -p tcp -j HYSTERIA

    ip6tables -t nat -N HYSTERIA
    ip6tables -t nat -A HYSTERIA ! -d 2000::/3 -j RETURN
    ip6tables -t nat -A HYSTERIA -p tcp -j REDIRECT --to-ports 3500
    ip6tables -t nat -A OUTPUT -p tcp -j HYSTERIA
    ip6tables -t nat -A PREROUTING -p tcp -j HYSTERIA
    ```

=== "nftables"

    ```nginx
    define HYSTERIA_REDIRECT_PORT=3500
    define BYPASS_IPV4={
        0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16,
        172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/3
    }
    define BYPASS_IPV6={ ::/128 }

    table inet hysteria_redirect {
      chain prerouting {
        type nat hook prerouting priority filter; policy accept;
        meta l4proto tcp counter jump hysteria
      }

      chain output {
        type nat hook output priority filter; policy accept;
        meta l4proto tcp counter jump hysteria
      }

      chain hysteria {
        ip daddr $BYPASS_IPV4 counter return
        ip6 daddr $BYPASS_IPV6 counter return
        ip6 daddr != 2000::/3 counter return
        meta l4proto tcp counter redirect to :$HYSTERIA_REDIRECT_PORT
      }
    }
    ```

### TUN

TUN 是一个跨平台的透明代理解决方案，在系统中创建虚拟网卡，利用系统路由功能来捕获及重定向流量。目前兼容 Windows、Linux 和 macOS 平台。

不同于常规的三层 VPN 技术（如 WireGuard 和 OpenVPN），Hysteria 的 TUN 模式只能处理 TCP 和 UDP 流量，不支持 ICMP 等其它协议（这意味着不支持 ping 等操作）。其会完全接管 TCP 协议栈以加速 TCP 连接。

与 Hysteria 1 的 TUN 实现相比，Hysteria 2 的 TUN 基于 [sing-tun](https://github.com/SagerNet/sing-tun) 的 "system" 栈，需要在虚拟网卡上配置一个 /30 的 IPv4 地址和一个 /126 的 IPv6 地址。Hysteria 会自动完成网卡、地址和路由规则的配置。

> **注意：** `ipv4Exclude`/`ipv6Exclude` 对于避免形成路由环路非常重要。请见这两个字段的注释以了解更多信息。

```yaml
tun:
  name: "hytun" # (1)!
  mtu: 1500 # (2)!
  timeout: 5m # (3)!
  address: # (4)!
    ipv4: 100.100.100.101/30
    ipv6: 2001::ffff:ffff:ffff:fff1/126
  route: # (5)!
    ipv4: [0.0.0.0/0] # (6)!
    ipv6: ["2000::/3"] # (7)!
    ipv4Exclude: [192.0.2.1/32] # (8)!
    ipv6Exclude: ["2001:db8::1/128"] # (9)!
```

1. TUN 接口的名称。
2. 可选。TUN 接口接受的单个包大小。默认 1500 字节。
3. 可选。UDP 会话超时时间。默认 5 分钟。
4. 可选。要在接口上使用的地址。设置成任意不和你的 LAN 冲突的私有地址即可。默认值如下所示。
5. 可选。路由规则。省略或者置空所有子项将禁用自动添加路由。<br>绝大部分情况下只需配置 `ipv4Exclude` 或者 `ipv6Exclude` 即可。
6. 可选。要代理的 IPv4 前缀。若配置了任何其它子项则默认 `0.0.0.0/0`。
7. 可选。要代理的 IPv6 前缀。由于 YAML 的限制必须加上引号。若配置了任何其它子项则默认 `::/0`。
8. 可选。要排除的 IPv4 前缀。<br>**可填入 Hysteria 服务端的地址来避免形成环路。**<br>如果你希望完全禁用 IPv4 代理，也可在此项中添加 `0.0.0.0/0`。
9. 可选。要排除的 IPv6 前缀。由于 YAML 的限制必须加上引号。<br>**可填入 Hysteria 服务端的地址来避免形成环路。**<br>如果你希望完全禁用 IPv6 代理，也可在此项中添加 `"::/0"`。

注意：Linux 上有时需要禁用 `rp_filter` 才能让一个网卡接收来自其他网卡的流量。

```bash
sysctl net.ipv4.conf.default.rp_filter=2
sysctl net.ipv4.conf.all.rp_filter=2
```

已知的兼容性问题：

| 操作系统            | 问题                                                                                                                                                                                                                                                                                                                                      |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| macOS               | TUN 接口的名称必须是 utun+数字， 例如 `utun123`。                                                                                                                                                                                                                                                                                         |
| Windows Server 2022 | 需要禁用防火墙才能正常使用。                                                                                                                                                                                                                                                                                                              |
| CentOS 7            | 需要禁用防火墙才能正常使用。<br>对于 4.17 之前的内核，自动添加的路由规则将无法正常工作（[原因](https://github.com/torvalds/linux/commit/bfff4862653bb96001ab57c1edd6d03f48e5f035)）， 可将内核升级到 4.17 或更高版本，或者在 Hysteria 客户端启动后执行 `ip rule del from all goto 9010; ip -6 rule del from all goto 9010` 来解决此问题。 |
| FreeBSD             | 无法使用，[不被 sing-tun 支持](https://github.com/SagerNet/sing-tun/blob/v0.2.4/tun_other.go#L10)。                                                                                                                                                                                                                                       |
