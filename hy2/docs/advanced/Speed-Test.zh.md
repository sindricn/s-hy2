# 速度测试

Hysteria（自 2.3.0 版本起）内置了一个速度测试工具，允许客户端与服务器进行下载和上传测速，前提是 [服务器在其配置中启用了速度测试支持](Full-Server-Config.md#_7)。

=== "默认配置 (config.yaml)"

    ```bash
    ./hysteria-linux-amd64-avx speedtest
    ```

=== "自定义文件名"

    ```bash
    ./hysteria-linux-amd64-avx speedtest -c whatever.yaml
    ```

> **注意：** 测速工具像正常代理模式一样，依然会遵守你在配置文件中的带宽设置。如果使用了 Brutal 拥塞控制，它不会为你探测带宽。

默认情况下会在两个方向上传输 100 MB 来测试下载和上传速度。可以使用以下 flags 修改行为：

```
Usage:
  hysteria speedtest [flags]

Flags:
      --data-size uint32   Data size for download and upload tests (default 104857600)
  -h, --help               help for speedtest
      --skip-download      Skip download test
      --skip-upload        Skip upload test
      --use-bytes          Use bytes per second instead of bits per second
```

速度测试连接由服务器内部处理，因此不受 ACL 和出站规则等的影响。但是速度测试产生的流量仍会计入该用户的流量统计中。
