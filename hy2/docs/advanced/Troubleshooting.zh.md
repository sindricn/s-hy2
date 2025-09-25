# 故障排除

以下是在配置客户端或服务器时可能遇到的一些常见问题，以及建议的排查步骤。

## failed to initialize client (connect error: timeout: no recent network activity)

客户端无法连接到服务器。最常见的原因有：

- 服务器没有运行
- 端口被防火墙阻塞（除了系统，许多提供商在面板中有单独的防火墙设置）
- 服务器在不同的地址或端口上运行
- 服务器监听的网络对客户端不可访问
- 域名没有解析到正确的 IP 地址
- 混淆设置不正确
- 服务端 Linux 内核版本太旧（不建议使用 CentOS 7）， 请参考
  [[1]](https://github.com/apernet/hysteria/issues/810#issuecomment-1807690164)
  [[2]](https://blog.yywq.me/article/39f87fd6-1c3e-4826-90d9-5d031393ca8d)
  以了解更多细节

## failed to initialize client (authentication error, HTTP status code: 404)

客户端被服务器拒绝。最常见的原因有：

- 密码不正确
- 连接到了错误的服务器
- 服务器的验证设置配置错误

## failed to initialize client (connect error: CRYPTO_ERROR 0x12a (local): tls: failed to verify certificate: x509: certificate signed by unknown authority)

客户端认为服务器的证书无效。最常见的原因有：

- 服务器使用了自签名证书，而你没有将其添加到客户端的受信任的 CA 中，或没有使用 `insecure` 选项。
- 系统的信任 CA 中缺少签署服务器证书的 CA。
- 你正被中间人攻击（[man-in-the-middle attack](https://en.wikipedia.org/wiki/Man-in-the-middle_attack)）。

## failed to load server config (invalid config: listen: listen udp :443: bind: permission denied)

服务器没有权限绑定到指定的端口。可以执行以下操作之一：

- 以 root 用户身份运行
- 给可执行文件 `cap_net_bind_service` 能力：`sudo setcap cap_net_bind_service=+ep ./hysteria-linux-amd64-avx`
