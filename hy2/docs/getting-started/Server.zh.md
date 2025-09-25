# 服务端

本教程提供了部署 Hysteria 服务器的快速指南。请注意 Hysteria 十分灵活，这里展示的选项只是全部选项的一小部分。**如需进一步定制，请参考 [完整服务端配置](../advanced/Full-Server-Config.md)。**

这些步骤在 Linux 环境中执行，但在其他平台上类似。

## 前提条件

- 一个有公网 IP 地址的服务器（IPv4 和 IPv6 均可）
- 一个指向服务器 IP 地址的域名（顶级域名或子域名均可）

## 创建配置文件

假设你已经将可执行文件下载到了一个目录中，名字是 `hysteria-linux-amd64-avx`。在同目录下创建一个 `config.yaml` 文件。

根据你是想使用 ACME 自动获取域名的 TLS 证书，还是使用自己的证书，你可以使用以下其中一个模板。

**请确保用你自己的值（特别是密码）替换这些示例内容。**

=== "ACME 自动获取证书"

    ```yaml
    # listen: :443 (1)

    acme:
      domains:
        - your.domain.net # (2)!
      email: your@email.com # (3)!

    auth:
      type: password
      password: Se7RAuFZ8Lzg # (4)!

    masquerade: # (5)!
      type: proxy
      proxy:
        url: https://news.ycombinator.com/ # (6)!
        rewriteHost: true
    ```

    1. 服务器默认在 443 端口监听。如果你想更改端口，取消这行注释。如果只指定了端口号（没有地址），如示例中所示，它将默认同时监听 IPv4 和 IPv6。要仅监听 IPv4，可以使用 `0.0.0.0:443`。要仅监听 IPv6，可以使用 `[::]:443`。
    2. 用你的域名替换
    3. 用你的邮件地址替换
    4. 选择一个强密码进行替换
    5. 关于伪装（masquerade）的更多信息请看下面
    6. 替换为你想伪装成的网站的 URL

=== "自有证书"

    ```yaml
    # listen: :443 (1)

    tls:
      cert: your_cert.crt # (2)!
      key: your_key.key # (3)!

    auth:
      type: password
      password: Se7RAuFZ8Lzg # (4)!

    masquerade: # (5)!
      type: proxy
      proxy:
        url: https://news.ycombinator.com/ # (6)!
        rewriteHost: true
    ```

    1. 服务器默认在 443 端口监听。如果你想更改端口，取消这行注释。如果只指定了端口号（没有地址），如示例中所示，它将默认同时监听 IPv4 和 IPv6。要仅监听 IPv4，可以使用 `0.0.0.0:443`。要仅监听 IPv6，可以使用 `[::]:443`。
    2. 替换为你的证书文件路径
    3. 替换为你的密钥文件路径
    4. 选择一个强密码进行替换
    5. 关于伪装（masquerade）的更多信息请看下面
    6. 替换为你想伪装成的网站的 URL

### 伪装 (Masquerade)

Hysteria 抵抗审查的关键之一就是它能伪装成标准的 HTTP/3 流量。这意味着数据包不仅对中间设备（middleboxes）看起来像是 HTTP/3，服务器还会像普通网站服务器一样真的响应 HTTP 请求。然而，这意味着你的服务器必须实际提供一些内容，以便看起来是真实的。

为了实现这一点，我们的示例使用反向代理模式从另一个网站 "盗取" 内容。请确保将 URL 更改为你想模仿的网站。Hysteria 还提供了几种其他方式来提供内容；有关更多信息，请参阅 [完整服务端配置 - 伪装部分](../advanced/Full-Server-Config.md#masquerade)。

**如果审查不是你需要担心的问题，可以从配置文件中完全删除 `masquerade` 部分。这种情况下，Hysteria 将对所有 HTTP 请求始终返回 404 Not Found 。**

## 运行服务器

**由于 Hysteria 默认在 443 端口监听，你可能需要使用 `cap_net_bind_service` 或以 root 用户运行。**

以下命令授予可执行文件 `cap_net_bind_service` 权限：

```bash
sudo setcap cap_net_bind_service=+ep ./hysteria-linux-amd64-avx
```

使用以下命令启动服务器：

=== "默认文件名 (config.yaml)"

    ```bash
    ./hysteria-linux-amd64-avx server
    ```

=== "自定义文件名"

    ```bash
    ./hysteria-linux-amd64-avx server -c whatever.yaml
    ```

如果你看到 "server up and running" 的日志消息，并且没有遇到错误，恭喜 🎉！你已成功部署了一个 Hysteria 服务器。

接下来，你可以继续阅读 [客户端教程](Client.md) 来配置客户端。
