# 我不喜欢 YAML 怎么办？

尽管文档使用的都是 YAML，Hysteria 实际上也完全支持 JSON 和 TOML。

## 示例

=== "config.json"

    ```json
    {
      "server": "your.server.net",
      "auth": "i_still_love_jason",
      "bandwidth": {
        "up": "30 mbps",
        "down": "100 mbps"
      },
      "fastOpen": true,
      "lazy": true,
      "socks5": {
        "listen": "127.0.0.1:1080"
      },
      "http": {
        "listen": "127.0.0.1:8080"
      }
    }
    ```

=== "config.toml"

    ```toml
    server = "your.server.net"
    auth = "i_still_love_tom"
    fastOpen = true
    lazy = true

    [bandwidth]
    up = "30 mbps"
    down = "100 mbps"

    [socks5]
    listen = "127.0.0.1:1080"

    [http]
    listen = "127.0.0.1:8080"
    ```

确保文件后缀与你使用的格式匹配。使用以下命令运行客户端：

```bash
./hysteria-linux-amd64-avx -c config.json
# 或者
./hysteria-linux-amd64-avx -c config.toml
```

## 转换

如果你已经有了一个 YAML 配置文件，可以使用 `yq` (https://github.com/mikefarah/yq) 将其转换为 JSON：

```bash
yq config.yaml -o json > config.json
```

也有一些网站可以使用：

- YAML 转 JSON: https://www.convertsimple.com/convert-yaml-to-json/
- YAML 转 TOML: https://www.convertsimple.com/convert-yaml-to-toml/
