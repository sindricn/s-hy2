# What if I hate YAML?

Even though our documentation uses YAML, Hysteria has full support for JSON and TOML as well.

## Examples

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

Make sure the file extension matches the format you're using. Run the client with the following command:

```bash
./hysteria-linux-amd64-avx -c config.json
# or
./hysteria-linux-amd64-avx -c config.toml
```

## Conversion

If you already have a YAML configuration file, you can convert it to JSON using `yq` (https://github.com/mikefarah/yq):

```bash
yq config.yaml -o json > config.json
```

There are also some websites:

- YAML to JSON: https://www.convertsimple.com/convert-yaml-to-json/
- YAML to TOML: https://www.convertsimple.com/convert-yaml-to-toml/
