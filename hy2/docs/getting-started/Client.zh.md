# 客户端

本教程将指导你完成 Hysteria 客户端的配置。与服务端类似，Hysteria 十分灵活，本教程展示的选项只是全部选项的一小部分。我们将重点介绍 HTTP 和 SOCKS5 代理模式。**如需进一步定制，请参考 [完整客户端配置](../advanced/Full-Client-Config.md)。**

这些步骤在 Linux 环境中执行，但在其他平台上类似。

## 前提条件

- 一个能连接的 Hysteria 服务器

## 创建配置文件

假设你已经将可执行文件下载到了一个目录中，名字是 `hysteria-linux-amd64-avx`。在同目录下创建一个 `config.yaml` 文件。

> **注意**： 部分配置项值可能和 YAML 语法冲突。 例如， 类似于 `[2001:db8::1]:443` 的 IPv6 地址+端口会导致配置文件解析失败。 只需将值放在 `""` 中写成 `"[2001:db8::1]:443"` 即可解决这类问题。

**请务必根据你的服务器设置和需求替换这些值。**

```yaml
server: your.domain.net:443 # (1)!

auth: Se7RAuFZ8Lzg # (2)!

bandwidth: # (3)!
  up: 20 mbps
  down: 100 mbps

socks5:
  listen: 127.0.0.1:1080 # (4)!

http:
  listen: 127.0.0.1:8080 # (5)!
```

1. 替换为你服务器的地址
2. 替换为你在服务器上设置的密码
3. 有关带宽的更多信息，请参见[下面](#_4)
4. 替换为你希望 SOCKS5 代理监听的地址
5. 替换为你希望 HTTP 代理监听的地址

### 带宽

Hysteria 内置了两套拥塞控制算法（BBR 与 Brutal），**使用哪个由是否提供了带宽值决定。** 如果希望使用 BBR 而不是 Brutal，可以删除整个 `bandwidth` 部分。详细信息请参见 [带宽协商流程](../advanced/Full-Server-Config.md#_6) 与 [拥塞控制细节](../advanced/Full-Server-Config.md#_7)。

> **⚠️ 警告** 带宽值并非越大越好，请务必不要超过你当前网络环境所能达到的最大带宽。否则只会适得其反，导致网络拥塞，连接不稳定。

### TLS

如果你的服务器使用的是自签名证书，可以在配置文件中指定要信任的 CA，或者使用 `insecure` 选项来完全禁用验证。如果你选择 `insecure` 设置，我们强烈建议配合 `pinSHA256` 选项来验证服务器证书的指纹。

=== "CA"

    ```yaml
    tls:
      ca: ca.crt # (1)!
    ```

    1. 替换为 CA 证书文件的路径

=== "禁用验证"

    ```yaml
    tls:
      insecure: true
    ```

    > **警告：** 单独使用 `insecure` 是不推荐的，因为这会让你的连接容易受到中间人攻击（MITM）。请在下一个标签页查看更好的替代方案。

=== "禁用验证 + pinSHA256"

    ```yaml
    tls:
      insecure: true
      pinSHA256: BA:88:45:17:A1... # (1)!
    ```

    1. 可以使用 openssl 获取你证书的指纹：`openssl x509 -noout -fingerprint -sha256 -in your_cert.crt`

## 运行客户端

通过以下命令启动客户端：

=== "默认文件名（config.yaml）"

    ```bash
    ./hysteria-linux-amd64-avx
    ```

=== "自定义文件名"

    ```bash
    ./hysteria-linux-amd64-avx -c whatever.yaml
    ```

> **提示：** 你也可以使用 `./hysteria-linux-amd64-avx client`，但由于客户端是默认模式，所以这部分可以省略。

> **:fontawesome-brands-windows: Windows 用户：** 你可以通过双击 exe 文件直接启动客户端，前提是你已经将配置文件放在同一目录下并命名为 `config.yaml`。

如果你看到日志显示 "connected to server" 且没有错误，恭喜 🎉！你已成功部署了一个 Hysteria 客户端。

你还会看到一个日志信息 "use this URI to share your server" 包含一个 URI。这个 URI 可以用作客户端配置文件中的 `server` 值。由于它已经包含了密码和一些其他设置，因此不再需要单独指定它们。有关 URI 格式的更多信息，请参考 [URI 格式](../developers/URI-Scheme.md)。

本教程不会详细介绍如何使用 HTTP 或 SOCKS5 代理，因为网上已有大量的教程。对于完全不了解代理的人，我们推荐使用 [ZeroOmega 浏览器插件](https://github.com/zero-peak/ZeroOmega) 作为一个起点。
