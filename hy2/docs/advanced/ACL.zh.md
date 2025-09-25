# ACL

ACL 是 Hysteria 服务端中一个非常强大的功能，可以用来自定义处理客户端请求的方式，往往配合出站规则（outbounds）使用。例如，可以使用 ACL 来屏蔽某些地址，或者针对不同网站使用不同的出口。

## 语法

一个有效的 ACL 规则必须符合以下格式之一：

- `outbound(address)`
- `outbound(address, proto/port)`
- `outbound(address, proto/port, hijack_address)`
- `# 这是一条注释`

### 地址类型

`address` 字段可以是以下几种之一：

- 单一 IPv4/IPv6 地址，例如 `1.1.1.1` 或 `2606:4700:4700::1111`
- IPv4/IPv6 CIDR，例如 `73.0.0.0/8` 或 `2001:db8::/32`
- 域名，例如 `example.com` （不包括子域名）
- 通配域名，例如 `*.example.com` 或 `*.google.*`
- 域名后缀，例如 `suffix:example.com` （匹配 `example.com` 及其所有子域名）
- GeoIP 国家代码，例如 `geoip:cn` 或 `geoip:us`
- GeoSite 分类，例如 `geosite:netflix` 或 `geosite:google` （支持标签，例如 `geosite:google@cn`）
- `all` - 匹配所有地址。通常放在最后作为其他所有连接的默认出站规则。

> 要查看可用的 GeoSite 分类，可以参考这里：
>
> - https://github.com/Loyalsoldier/v2ray-rules-dat
> - https://github.com/v2fly/domain-list-community/tree/master/data

### Proto/port

- `tcp` 或 `tcp/*` - 匹配所有 TCP 端口
- `udp` 或 `udp/*` - 匹配所有 UDP 端口
- `tcp/80` - 匹配 TCP 端口 80
- `udp/53` - 匹配 UDP 端口 53
- `udp/20000-30000` - 匹配 UDP 端口 20000 到 30000
- `*/443` - 匹配 TCP 和 UDP 端口 443
- `*`、`*/*` 或省略 - 匹配所有协议和所有端口

### 劫持地址 (Hijack address)

当指定了劫持地址时，匹配此规则的连接将被劫持到指定的地址。劫持地址必须是 IPv4/IPv6 地址，不能是域名。

## 匹配行为

### 域名和 IP 匹配

当处理基于域名的请求时，Hysteria 首先会解析该域名，然后尝试匹配域名和 IP 规则。**换句话说，基于 IP 地址的规则将适用于所有最终指向该 IP 的连接，无论客户端请求是用的域名还是 IP。**

### 规则顺序

规则保证按从上到下的顺序进行匹配。使用第一个匹配请求的规则。如果没有规则匹配，将使用默认出站（出站列表中的第一个）。

## 内置出站

除非在出站列表中明确地进行了覆盖（同名），否则 Hysteria 内置以下出站：

- `direct` - 使用默认配置（`auto`，无绑定）的本地出站
- `reject` - 拒绝连接
- `default` - 使用出站列表中的第一个出站；如果列表为空，等同于 `direct`

## 示例

假设有以下出站列表：

```yaml
outbounds:
  - name: v4_only
    type: direct
    direct:
      mode: 4
  - name: v6_only
    type: direct
    direct:
      mode: 6
  - name: some_proxy
    type: socks5
    socks5:
      addr: ohno.moe:1080
```

```python
# 为 Google 使用 v6_only 出站
v6_only(suffix:google.com)

# 为 Twitter 使用 v4_only 出站
v4_only(suffix:twitter.com)

# 为 ipinfo.io 使用 some_proxy 出站
some_proxy(ipinfo.io)

# 也支持非英语 IDN 域名
v6_only(战狼*.中国)

# 屏蔽 QUIC 协议
reject(all, udp/443)

# 屏蔽 SMTP 协议
reject(all, tcp/25)

# 屏蔽中国和朝鲜
reject(geoip:cn)
reject(geoip:kp)

# 屏蔽 Facebook 和 Google Ads
reject(geosite:facebook)
reject(geosite:google@ads)

# 屏蔽一些 IP 范围
reject(73.0.0.0/8)
reject(2601::/20)

# 将 8.8.8.8 劫持到 1.1.1.1 并使用默认（第一个）出站
default(8.8.8.8, *, 1.1.1.1)

# 将 8.8.4.4 劫持到 1.1.1.1 并使用默认（第一个）出站，但仅限 UDP 53
default(8.8.4.4, udp/53, 1.1.1.1)

# 直连所有其他地址
direct(all)
```

> **注意：** ACL 也可以不配合出站规则单独使用。无论有没有出站列表，内置出站都会存在。例如，可以单纯通过 `reject` 屏蔽一些地址。

```python
reject(geoip:cn)
reject(geosite:facebook)
reject(10.0.0.0/8)
reject(172.16.0.0/12)
reject(192.168.0.0/16)
reject(fc00::/7)
```
