# FD Control Protocol

> This feature is mainly used for developing Android proxy apps.

The Hysteria client supports sending the file descriptor (fd) of outbound QUIC connections to any process listening on `fdControlUnixSocket`.

**Note:** `fdControlUnixSocket` is currently only effective for outbound QUIC connections. Third-party Android clients using this feature will need to handle additional DNS resolution requests for the Hysteria server domain, or make sure that the `server` option in the Hysteria client config is an IP address, not a domain.

## Roles

- Server: The third-party process listening on `fdControlUnixSocket`, e.g., the main process of an Android app.
- Client: The Hysteria client process.

## Server Implementation

1. Listen to a path-based Unix Socket, which must be of type `SOCK_STREAM`.
2. Use `accept(2)` to accept connections initiated by the client.
3. Receive a single `fd` sent by the client via `recvmsg(2)`.
4. Process the `fd` received in step 3 (e.g., by calling `VpnService.protect()`) and then close the `fd`.
5. Respond to the client with a single byte, notifying the client to continue operations. It is advised to respond with `'\x01'` under normal conditions; other values are currently undefined.
6. Close the connection established in step 2 - each connection only processes one `fd`.

## References

- [Server implementation by Nekobox](https://github.com/MatsuriDayo/libneko/blob/5277a5bfc889ee7a89462695b0e678c1bd4909b1/protect_server/protect_server_linux.go) (Go)
- [Server used for unit testing in Hysteria](https://github.com/apernet/hysteria/blob/6b5486fc09d22c3fb4a1cc78c799c8cfe81e6dce/app/internal/sockopts/fd_control_unix_socket_test.py) (Python)
