# URI 格式

Hysteria 2 的 URI 格式旨在提供一种简洁的方式来表示连接到 Hysteria 2 服务器所需的必要信息。它包括各种参数，如服务器地址、验证密码、混淆，TLS 设置等。

## 结构

```
hysteria2://[auth@]hostname[:port]/?[key=value]&[key=value]...
```

## 组件

### 协议名

`hysteria2` 或 `hy2`

### 验证

验证密码应在 URI 的 `auth` 中指定。这部分实际上就是标准 URI 格式中的用户名部分，因此如果包含特殊字符，需要进行 [百分号编码](https://datatracker.ietf.org/doc/html/rfc3986#section-2.1)。

一种特殊情况是服务器使用 `userpass` 验证时，`auth` 应格式化为 `username:password`。

### 地址

服务器的地址和可选端口。如果省略端口，则默认为 443。

端口部分支持 [端口跳跃](../advanced/Port-Hopping.md) 的「多端口地址格式」。

### 参数

- `obfs`：要使用的混淆类型。目前只支持 `salamander`。

- `obfs-password`：混淆所需的密码。

- `sni`：用于 TLS 连接的服务器 SNI。

- `insecure`：是否允许不安全的 TLS 连接。接受 `1` 表示 `true`，`0` 表示 `false`。

- `pinSHA256`：服务器证书 SHA-256 指纹。

## 示例

```
hysteria2://letmein@example.com:123,5000-6000/?insecure=1&obfs=salamander&obfs-password=gawrgura&pinSHA256=deadbeef&sni=real.example.com
```

## 注意事项

这个 URI 故意只包含连接到 Hysteria 2 服务器所需的基础信息。尽管第三方实现可以根据需要添加额外的参数，但它们不应假设其他实现能理解这些额外参数。

此外，参数不应包括客户端模式（如 HTTP、SOCKS5 等）或带宽值。用户需要明白这些内容不应该被其他人随意共享和使用，需要每个用户根据自己的情况进行配置。
