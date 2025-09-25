# FD Control 协议

> 此特性主要用于 Android 代理客户端开发。

Hysteria 客户端使用此协议将出站 QUIC 连接的文件描述符（File Descriptor，下称 `fd`）发送给监听 `fdControlUnixSocket` 的进程。

**注意：** `fdControlUnixSocket` 目前仅对出站 QUIC 连接生效。使用此特性实现第三方 Android 客户端需要对 Hysteria 服务端域名的 DNS 解析请求进行额外的处理，或者确保在 Hysteria 客户端配置的 `server` 选项中填入 IP 地址。

## 角色

- 服务端： 监听 `fdControlUnixSocket` 的第三方进程，例如 Android 客户端主进程。
- 客户端： Hysteria 客户端进程。

## 服务端实现步骤

1. 监听一个基于路径的 Unix Socket， 类型必须为 `SOCK_STREAM`。
2. 使用 `accept(2)` 接受由客户端发起的连接。
3. 通过 `recvmsg(2)` 接收由客户端发送的单个 `fd`。
4. 对第 3 步接收到的 `fd` 进行处理（例如调用 `VpnService.protect()`），并关闭该 `fd`。
5. 向客户端回应单个字节，通知客户端继续操作。建议在一切正常的情况下回应 `'\x01'`，其它响应值的行为暂未定义。
6. 关闭由第 2 步建立的连接，每个连接仅处理一个 `fd`。

## 参考样例

- [Nekobox 的服务端实现](https://github.com/MatsuriDayo/libneko/blob/5277a5bfc889ee7a89462695b0e678c1bd4909b1/protect_server/protect_server_linux.go) (Go)
- [Hysteria 中用于单元测试的服务端](https://github.com/apernet/hysteria/blob/6b5486fc09d22c3fb4a1cc78c799c8cfe81e6dce/app/internal/sockopts/fd_control_unix_socket_test.py) (Python)
