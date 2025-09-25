# 流量统计 API

如果配置中设置了 API secret，调用时需要在请求头加上 `Authorization` 标头。

请求：

```shell
curl -H 'Authorization: secret' http://ip:port/path
```

### GET `/traffic`

此接口返回一个 JSON map，是每个用户的流量信息。

响应：

```json
{
  "wang": {
    "tx": 514,
    "rx": 4017
  },
  "joe": {
    "tx": 7790,
    "rx": 446623
  }
}
```

还可以使用参数 `clear` 在返回统计数据后将其清零：

```
/traffic?clear=1
```

### POST `/kick`

此接口可以提交一个要踢下线的用户列表。

请求：

```json
["wang", "joe"]
```

> **注意：** 由于客户端内置了重连逻辑，被踢出后将尝试重新连接。为了避免需要反复踢出同一个用户，应该同时在验证后端中屏蔽该用户。

### GET `/online`

此接口返回一个 JSON map，是当前在线的用户与其对应的连接数。这里的连接数指的是 Hysteria 客户端实例的数量（可以理解为设备数），而非代理连接数。

响应：

```json
{
  "wang": 2,
  "joe": 1
}
```

### GET `/dump/streams`

此接口返回一个 JSON 对象， 反映当前由 Hysteria 代理的 TCP 流的详细信息。

响应：

```json
{
  "streams": [
    {
      "state": "estab", // (1)!
      "auth": "user", // (2)!
      "connection": 3191736581, // (3)!
      "stream": 4, // (4)!
      "req_addr": "192.0.2.1:80", // (5)!
      "hooked_req_addr": "example.com:80", // (6)!
      "tx": 3937, // (7)!
      "rx": 4441, // (8)!
      "initial_at": "2024-11-08T16:07:45.956956773+09:00", // (9)!
      "last_active_at": "2024-11-08T16:07:47.121503203+09:00" // (10)!
    }
  ]
}
```

1. 流状态，请参考 [此处的注释](https://github.com/apernet/hysteria/blob/3e8c20518db0e97ad67b638e85cbe643b26d777a/core/server/config.go#L223-L257) 以了解它们对应的含义。
2. 使用这个流的用户。
3. 承载这个流的 QUIC 连接的标识。
4. 这个流在 QUIC 连接中的标识。
5. 这个流请求连接到的原始地址。
6. 协议嗅探出来的地址，如果协议嗅探没有启用或者没有嗅探到地址，则这个值会是空字符串。
7. 这个流的流量统计信息（客户端角度的上传）。
8. 这个流的流量统计信息（客户端角度的下载）。
9. 这个流的创建时间。
10. 这个流最近一次传输数据的时间。

在请求这个 API 时， 如果在请求头中额外加上 `Accept: text/plain`， 可以获得类似于 `ss -atn` 的人类可读输出。

响应：

```
State    Auth           Connection   Stream     TX-Bytes     RX-Bytes     Lifetime  Last-Active Req-Addr         Hooked-Req-Addr
ESTAB    user             BE3E0905        4         3937         4441       3.005s        1.84s 192.0.2.1:80     example.com:80
```
