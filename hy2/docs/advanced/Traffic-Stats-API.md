# Traffic Stats API

If an API secret is set in your configuration, you will need to add the `Authorization` header when making a request.

Example:

```shell
curl -H 'Authorization: secret' http://ip:port/path
```

### GET `/traffic`

This endpoint returns a JSON map of client IDs to their traffic statistics.

Response:

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

You can also use the query parameter `clear` to zero out the statistics after they are returned:

```
/traffic?clear=1
```

### POST `/kick`

This endpoint allows you to kick a list of clients by their IDs.

Request:

```json
["wang", "joe"]
```

> **NOTE:** Due to the reconnect logic built into the client, it will attempt to reconnect after being kicked. To avoid having to repeatedly kick the same client, you should also block the user in your authentication backend.

### GET `/online`

This endpoint returns a JSON map of online clients to the number of connections they have. The connection count here refers to the number of Hysteria client instances ("devices"), NOT the number of active proxy connections.

Response:

```json
{
  "wang": 2,
  "joe": 1
}
```

### GET `/dump/streams`

This endpoint returns a JSON object containing information about each QUIC stream of a Hysteria TCP proxy connection.

Response:

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

1. Stream state. Refer to [the comment here](https://github.com/apernet/hysteria/blob/3e8c20518db0e97ad67b638e85cbe643b26d777a/core/server/config.go#L223-L257) for their meanings.
2. The user of this stream.
3. The ID of the QUIC connection carrying this stream.
4. The ID of this stream within its QUIC connection.
5. The address this stream requested to connect to.
6. The address sniffed from the protocol. If sniffing is not enabled or failed to get an address, this value will be an empty string.
7. The tx bytes of this stream (upload from the client's perspective).
8. The rx bytes of this stream (download from the client's perspective).
9. The time this stream was created.
10. The time this stream last transmitted data.

When making a request to this API, you can add `Accept: text/plain` to the header to get a human-readable output similar to `ss -atn`.

Response:

```
State    Auth           Connection   Stream     TX-Bytes     RX-Bytes     Lifetime  Last-Active Req-Addr         Hooked-Req-Addr
ESTAB    user             BE3E0905        4         3937         4441       3.005s        1.84s 192.0.2.1:80     example.com:80
```
