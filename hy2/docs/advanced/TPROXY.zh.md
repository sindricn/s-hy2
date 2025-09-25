# 配置 TPROXY

TProxy 是仅在 Linux 上可用的一种透明代理， 它同时支持 TCP 和 UDP。

## 避免环路

> 如果不需要代理本机（运行 Hysteria 客户端的设备自身）的流量， 则可跳过此章节。

在需要代理本机流量的情况下， 为了避免 Hysteria 的流量出现环路，
我们应该将 Hysteria 自身的流量与被代理的流量区分开，
最佳的方式是使用专用的用户运行 Hysteria 客户端，
然后在 iptables 或 nftables 中使用基于用户的匹配。

> 我们也建议一键安装脚本以及 Linux 发行版打包时使用专用用户执行 Hysteria，
> 并参考这个章节进行配置。

1.  创建专用于运行 Hysteria 客户端的用户。

    ```bash
    useradd --system hysteria
    ```

2.  给 Hysteria 客户端配置正常运行所需的
    [`capabilities(7)`](https://man7.org/linux/man-pages/man7/capabilities.7.html)。

    ```bash
    setcap CAP_NET_ADMIN,CAP_NET_BIND_SERVICE+ep /path/to/hysteria # (1)!
    ```

    1. 改成实际上的 Hysteria 安装路径。

    每次手动更新 Hysteria 客户端后都需要执行此操作。

3.  将 Hysteria 客户端配置成使用这个专用用户启动。

    如果手动运行 Hysteria 客户端：

    ```bash
    sudo -u hysteria /path/to/hysteria -c config.yaml
    ```

    或者， 如果使用 systemd 管理 Hysteria 服务，
    也可以在这个服务的 systemd 配置中的 `[Service]` 下添加 `User=hysteria`。

## 配置客户端

> 在之后的示例中， 我们将使用 `2500` 作为 TProxy 的监听端口， 你也可以换用其他端口。

在客户端配置中添加下面几行：

=== "代理 TCP 和 UDP"

    ```yaml
    tcpTProxy:
        listen: :2500 # (1)!

    udpTProxy:
        listen: :2500
    ```

    1. 如果同时需要 IPv4 和 IPv6 支持， 请不要在 `:` 的前面添加监听的 IP 地址。

=== "仅代理 TCP"

    ```yaml
    tcpTProxy:
        listen: :2500 # (1)!
    ```

    1. 如果同时需要 IPv4 和 IPv6 支持， 请不要在 `:` 的前面添加监听的 IP 地址。

## 配置路由规则

这个步骤 **不可省略**。 请勿遗漏这个步骤， 否则 TProxy 将不会工作。

> 每次开机都需要执行这些命令， 除非进行持久化。

> 在之后的示例中， 我们将使用 `0x1` 作为 TProxy 策略路由规则的 fwmark，
> 使用 `100` 作为 TProxy 路由表的 Table ID， 你也可以换用其他值。

```bash
# IPv4
ip rule add fwmark 0x1 lookup 100
ip route add local default dev lo table 100

# IPv6
ip -6 rule add fwmark 0x1 lookup 100
ip -6 route add local default dev lo table 100
```

## 配置 iptables 或者 nftables

> 每次开机都需要执行这些命令， 除非进行持久化。

=== "iptables (IPv4)"

    ```bash
    iptables -t mangle -N HYSTERIA

    # 跳过已经由 TProxy 接管的流量 (1)
    iptables -t mangle -A HYSTERIA -p tcp -m socket --transparent -j MARK --set-mark 0x1
    iptables -t mangle -A HYSTERIA -p udp -m socket --transparent -j MARK --set-mark 0x1
    iptables -t mangle -A HYSTERIA -m socket -j RETURN

    # 绕过私有和特殊 IPv4 地址 (3)
    iptables -t mangle -A HYSTERIA -d 0.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA -d 10.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA -d 169.254.0.0/16 -j RETURN
    iptables -t mangle -A HYSTERIA -d 172.16.0.0/12 -j RETURN
    iptables -t mangle -A HYSTERIA -d 192.168.0.0/16 -j RETURN
    iptables -t mangle -A HYSTERIA -d 224.0.0.0/4 -j RETURN
    iptables -t mangle -A HYSTERIA -d 240.0.0.0/4 -j RETURN

    # 重定向流量到 TProxy 端口
    iptables -t mangle -A HYSTERIA -p tcp -j TPROXY --on-port 2500 --on-ip 127.0.0.1 --tproxy-mark 0x1
    iptables -t mangle -A HYSTERIA -p udp -j TPROXY --on-port 2500 --on-ip 127.0.0.1 --tproxy-mark 0x1 # (4)!

    # 启用上述规则
    iptables -t mangle -A PREROUTING -j HYSTERIA

    # === 代理本机流量 - 开始 === (2)

    iptables -t mangle -N HYSTERIA_MARK

    # 通过匹配用户来避免环路
    iptables -t mangle -A HYSTERIA_MARK -m owner --uid-owner hysteria -j RETURN

    # 绕过局域网和特殊 IPv4 地址
    iptables -t mangle -A HYSTERIA_MARK -d 0.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 10.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 169.254.0.0/16 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 172.16.0.0/12 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 192.168.0.0/16 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 224.0.0.0/4 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 240.0.0.0/4 -j RETURN

    # 重路由 OUTPUT 链流量到 PREROUTING 链
    iptables -t mangle -A HYSTERIA_MARK -p tcp -j MARK --set-mark 0x1
    iptables -t mangle -A HYSTERIA_MARK -p udp -j MARK --set-mark 0x1

    # 启用上述规则
    iptables -t mangle -A OUTPUT -j HYSTERIA_MARK

    # === 代理本机流量 - 结束 ===
    ```

    1. 如果默认路由的接口上有由运营商分配的公网 IPv4 地址，
       省略这些规则会导致本机流量代理异常。

    2. 以下规则是配置本机流量代理时的 **额外** 规则。
       即使只需要代理本机流量， 这一行之前的规则是必须的。
       如果只需要局域网代理， 请省略这一行之后的规则。

    3. 在代理本机流量（启用 OUTPUT 链规则）的情况下，
       如果需要通过由运营商分配的公网 IPv4 地址访问这台路由器， 则需要配置额外的规则。

    4. 如果不需要代理 UDP 流量， 则可以删除所有带有 `-p udp` 的规则。

=== "iptables (IPv6)"

    ```bash
    ip6tables -t mangle -N HYSTERIA

    # 跳过已经由 TProxy 接管的流量 (1)
    ip6tables -t mangle -A HYSTERIA -p tcp -m socket --transparent -j MARK --set-mark 0x1
    ip6tables -t mangle -A HYSTERIA -p udp -m socket --transparent -j MARK --set-mark 0x1
    ip6tables -t mangle -A HYSTERIA -m socket -j RETURN

    # 仅对公网 IPv6 启用代理 (3)
    ip6tables -t mangle -A HYSTERIA ! -d 2000::/3 -j RETURN

    # 重定向流量到 TProxy 端口
    ip6tables -t mangle -A HYSTERIA -p tcp -j TPROXY --on-port 2500 --on-ip ::1 --tproxy-mark 0x1
    ip6tables -t mangle -A HYSTERIA -p udp -j TPROXY --on-port 2500 --on-ip ::1 --tproxy-mark 0x1 # (4)!

    # 启用上述规则
    ip6tables -t mangle -A PREROUTING -j HYSTERIA

    # === 代理本机流量 - 开始 === (2)

    ip6tables -t mangle -N HYSTERIA_MARK

    # 通过匹配用户来避免环路
    ip6tables -t mangle -A HYSTERIA_MARK -m owner --uid-owner hysteria -j RETURN

    # 仅对公网 IPv6 启用代理
    ip6tables -t mangle -A HYSTERIA_MARK ! -d 2000::/3 -j RETURN

    # 重路由 OUTPUT 链流量到 PREROUTING 链
    ip6tables -t mangle -A HYSTERIA_MARK -p tcp -j MARK --set-mark 0x1
    ip6tables -t mangle -A HYSTERIA_MARK -p udp -j MARK --set-mark 0x1

    # 启用上述规则
    ip6tables -t mangle -A OUTPUT -j HYSTERIA_MARK

    # === 代理本机流量 - 结束 ===
    ```

    1. 如果默认路由的接口上有由运营商分配的公网 IPv6 地址，
       省略这些规则会导致本机流量代理异常。

    2. 以下规则是配置本机流量代理时的 **额外** 规则。
       即使只需要代理本机流量， 这一行之前的规则是必须的。
       如果只需要局域网代理， 请省略这一行之后的规则。

    3. 在代理本机流量（启用 OUTPUT 链规则）的情况下，
       如果需要通过由运营商分配的公网 IPv6 地址访问这台路由器， 则需要配置额外的规则。

    4. 如果不需要代理 UDP 流量， 则可以删除所有带有 `-p udp` 的规则。

=== "nftables"

    ```nginx
    define TPROXY_MARK=0x1
    define HYSTERIA_USER=hysteria
    define HYSTERIA_TPROXY_PORT=2500

    # 需要代理的协议类型 (4)
    define TPROXY_L4PROTO={ tcp, udp }

    # 需要绕过的地址 (3)
    define BYPASS_IPV4={
        0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16,
        172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/3
    }
    define BYPASS_IPV6={ ::/128 }

    table inet hysteria_tproxy {
      chain prerouting {
        type filter hook prerouting priority mangle; policy accept;

        # 跳过已经由 TProxy 接管的流量 (1)
        meta l4proto $TPROXY_L4PROTO socket transparent 1 counter mark set $TPROXY_MARK
        socket transparent 0 socket wildcard 0 counter return

        # 绕过私有和特殊 IP 地址
        ip daddr $BYPASS_IPV4 counter return
        ip6 daddr $BYPASS_IPV6 counter return

        # 仅对公网 IPv6 地址启用代理
        ip6 daddr != 2000::/3 counter return

        # 重定向流量到 TProxy 端口
        meta l4proto $TPROXY_L4PROTO counter tproxy to :$HYSTERIA_TPROXY_PORT meta mark set $TPROXY_MARK accept
      }
    }

    # 代理本机流量 (2)
    table inet hysteria_tproxy_local {
      chain output {
        type route hook output priority mangle; policy accept;

        # 通过匹配用户来避免环路
        meta skuid $HYSTERIA_USER counter return

        # 绕过私有和特殊 IP 地址
        ip daddr $BYPASS_IPV4 counter return
        ip6 daddr $BYPASS_IPV6 counter return

        # 仅对公网 IPv6 地址启用代理
        ip6 daddr != 2000::/3 counter return

        # 重路由 OUTPUT 链流量到 PREROUTING 链
        meta l4proto $TPROXY_L4PROTO counter meta mark set $TPROXY_MARK
      }
    }
    ```

    1. 如果默认路由的接口上有由运营商分配的公网 IP 地址，
       省略这些规则会导致本机流量代理异常。

    2. 以下 table 是配置本机流量代理时的 **额外** table。
       即使只需要代理本机流量， 这一行之前的 table 也是必须的。
       如果只需要局域网代理， 请省略这一行之后的 table。

    3. 在代理本机流量（启用 OUTPUT 链规则）的情况下，
       如果需要通过由运营商分配的公网 IP 地址访问这台路由器， 则需要将分配的 IP 加入到 bypass 列表中。

    4. 如果不需要代理 UDP 流量， 则可以将下面这行更改为 define TPROXY_L4PROTO=tcp。

## 延伸阅读

- [XRay 使用指南 - TProxy 透明代理](https://xtls.github.io/document/level-2/tproxy_ipv4_and_ipv6.html)
- [XRay 使用指南 - 透明代理通过 gid 规避 Xray 流量](https://xtls.github.io/document/level-2/iptables_gid.html)
- [新 V2Ray 白话文指南 - 透明代理(TProxy)](https://guide.v2fly.org/app/tproxy.html)
