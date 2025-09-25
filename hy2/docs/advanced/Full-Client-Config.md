# Full Client Config

This page provides documentation for every field in the client configuration file.

> **NOTE:** One common pattern you'll encounter in both the client & server configurations is the "type selector":

```yaml
example:
  type: a
  a:
    something: something
  b:
    something: something
  c:
    something: something
```

`type` determines which mode to use and which subfields to parse. In this example, the `example` field can be either `a`, `b` or `c`. If `a` is selected, the `a` subfield will be parsed and the `b` and `c` subfields will be ignored.

## Server address

The `server` field specifies the address of the Hysteria server that the client should connect to. The address can be formatted as either `host:port` or just `host`. If the port is omitted, it defaults to 443.

You also have the option to use a Hysteria 2 URI (`hysteria2://`). In this case, because the URI already includes the password and certain other settings, you don't (and can't) specify them separately in the configuration file.

=== "Address"

    ```yaml
    server: example.com
    ```

=== "URI"

    ```yaml
    server: hysteria2://user:pass@example.com/
    ```

## Authentication

```yaml
auth: some_password
```

> **NOTE:** If the server uses the `userpass` authentication, the format must be `username:password`.

## TLS

```yaml
tls:
  sni: another.example.com # (1)!
  insecure: false # (2)!
  pinSHA256: BA:88:45:17:A1... # (3)!
  ca: custom_ca.crt # (4)!
  clientCertificate: client.crt # (5)!
  clientKey: client.key # (6)!
```

1. Server name to use for TLS verification. If omitted, the server name will be extracted from the `server` field.
2. Disable TLS verification.
3. Verify the server's certificate fingerprint. You can obtain the fingerprint of your certificate using openssl: `openssl x509 -noout -fingerprint -sha256 -in your_cert.crt`
4. Use a custom CA certificate for TLS verification.
5. Use a client certificate for mTLS verification.
6. Use a client key for mTLS verification.

## Transport

The `transport` section is for customizing the underlying protocol used by the QUIC connection. Currently the only type available is `udp`, but we reserve it for possible future expansions.

```yaml
transport:
  type: udp # (2)!
  udp:
    hopInterval: 30s # (1)!
```

1. The port hopping interval. This is only relevant if you're using a port hopping address. See [Port Hopping](Port-Hopping.md) for more information.
2. Please read the instructions regarding the "type selector" at the top of this page.

## Obfuscation

By default, the Hysteria protocol mimics HTTP/3. If your network specifically blocks QUIC or HTTP/3 traffic (but not UDP in general), obfuscation can be used to work around this. We currently have an obfuscation implementation called "Salamander" that converts packets into seamingly random bytes with no pattern. This feature requires a password that must be identical on both the client and server sides.

> **NOTE:** Using an incorrect obfuscation password will result in a connection timeout, just as if the server were not running at all. If you experience connection problems, double-check that the password is correct.

```yaml
obfs:
  type: salamander # (2)!
  salamander:
    password: cry_me_a_r1ver # (1)!
```

1. Replace with a strong password of your choice.
2. Please read the instructions regarding the "type selector" at the top of this page.

## QUIC parameters

```yaml
quic:
  initStreamReceiveWindow: 8388608 # (1)!
  maxStreamReceiveWindow: 8388608 # (2)!
  initConnReceiveWindow: 20971520 # (3)!
  maxConnReceiveWindow: 20971520 # (4)!
  maxIdleTimeout: 30s # (5)!
  keepAlivePeriod: 10s # (6)!
  disablePathMTUDiscovery: false # (7)!
  sockopts:
    bindInterface: eth0 # (8)!
    fwmark: 1234 # (9)!
    fdControlUnixSocket: ./test.sock # (10)!
```

1. The initial QUIC stream receive window size.
2. The maximum QUIC stream receive window size.
3. The initial QUIC connection receive window size.
4. The maximum QUIC connection receive window size.
5. The maximum idle timeout. How long until the client will consider the connection dead if no packets from the server are received.
6. The keep-alive period. How often the client will send a packet to the server to keep the connection alive.
7. Disable QUIC path MTU discovery.
8. (Linux only) Interface name. Forces QUIC packets to be sent through this interface.
9. (Linux only) The `SO_MARK` tag to be added to QUIC packets.
10. (Linux only) Path to a Unix Socket that is listened to by other processes. The Hysteria client will send the file descriptor (FD) used for the QUIC connection as ancillary information to this Unix Socket, allowing the listening process to perform other custom configurations. This option can be used in Android client development; please refer to the [FD Control Protocol](./FD-Control.md) for more details.

The default stream and connection receive window sizes are 8MB and 20MB, respectively. **We do not recommend changing these values unless you fully understand what you are doing.** If you choose to change these values, we recommend keeping the ratio of stream receive window to connection receive window at 2:5.

**Note:** The options under `sockopts` only applies to outbound QUIC connections, not to other possible outbound connections (e.g. DNS queries to resolve the server address).

## Bandwidth

```yaml
bandwidth:
  up: 100 mbps
  down: 200 mbps
```

Hysteria has two built-in congestion control algorithms (BBR & Brutal). **Which one to use depends on whether bandwidth information is provided.** If you want to use BBR instead of Brutal, you can delete the entire `bandwidth` section. For more details, see [Bandwidth negotiation process](../advanced/Full-Server-Config.md#bandwidth-negotiation-process) and [Congestion control details](../advanced/Full-Server-Config.md#congestion-control-details).

> **⚠️ Warning** Higher bandwidth values are not always better; be very careful not to exceed the maximum bandwidth that your current network can support. Doing so will backfire, causing network congestion and unstable connections.

The client's actual upload speed will be the lesser of the value specified here and the server's maximum download speed (if set by the server). Similarly, the client's actual download speed will be the lesser of the value specified here and the server's maximum upload speed (if set by the server).

One exception is that if the server has enabled the `ignoreClientBandwidth` option, the values specified here will be ignored.

Supported units are:

- `bps` or `b` (bits per second)
- `kbps` or `kb` or `k` (kilobits per second)
- `mbps` or `mb` or `m` (megabits per second)
- `gbps` or `gb` or `g` (gigabits per second)
- `tbps` or `tb` or `t` (terabits per second)

## Fast Open

Fast Open can shave one roundtrip time (RTT) off each connection, but at the cost of the correct semantics of SOCKS5/HTTP proxy protocols. When this is enabled, the client always immediately accepts a connection without confirming with the server that the destination is reachable. If the server then fails or rejects the connection, the client will simply close the connection without sending any data back to the proxy client.

```yaml
fastOpen: true
```

## Lazy

When enabled, the client is "lazy" in the sense that it will only attempt to connect to the server if there is an incoming connection from one of the enabled client modes. This differs from the default behavior, where the client attempts to connect to the server as soon as it starts up.

The `lazy` option can be useful if you're unsure when you'll use the client and want to avoid idle connections. It's also useful if your Internet connection might not be ready when you start the Hysteria client.

```yaml
lazy: true
```

## Modes

To use the Hysteria client, you must at least specify one of the following modes:

> **Tips:** Starting with version 2.4.1, the Hysteria client can support both SOCKS5 and HTTP protocols on a single port. Just have both `socks5` and `http` in the configuration and make sure their `listen` addresses are exactly the same.

### SOCKS5

A SOCKS5 proxy server that can be used with any SOCKS5-compatible application. Supports both TCP and UDP.

```yaml
socks5:
  listen: 127.0.0.1:1080 # (1)!
  username: user # (2)!
  password: pass # (3)!
  disableUDP: false # (4)!
```

1. The address to listen on.
2. Optional. The username to require for authentication.
3. Optional. The password to require for authentication.
4. Optional. Disable UDP support.

### HTTP

An HTTP proxy server that can be used with any HTTP proxy-compatible application. Supports both plaintext HTTP and HTTPS (CONNECT).

```yaml
http:
  listen: 127.0.0.1:8080 # (1)!
  username: king # (2)!
  password: kong # (3)!
  realm: martian # (4)!
```

1. The address to listen on.
2. Optional. The username to require for authentication.
3. Optional. The password to require for authentication.
4. Optional. The realm to require for authentication.

### TCP Forwarding

TCP Forwarding allows you to forward one or more TCP ports from the server (or any remote host) to the client. This is useful, for example, if you want to access a service that is only available on the server's network.

```yaml
tcpForwarding:
  - listen: 127.0.0.1:6600 # (1)!
    remote: 127.0.0.1:6600 # (2)!
  - listen: 127.0.0.1:6601 # (3)!
    remote: other.machine.internal:6601
```

1. The address to listen on.
2. The address to forward to.
3. You can have one or more forwarding rules.

### UDP Forwarding

UDP Forwarding allows you to forward one or more UDP ports from the server (or any remote host) to the client. This is useful, for example, if you want to access a service that is only available on the server's network.

```yaml
udpForwarding:
  - listen: 127.0.0.1:5300 # (1)!
    remote: 127.0.0.1:5300 # (2)!
    timeout: 20s # (3)!
  - listen: 127.0.0.1:5301 # (4)!
    remote: other.machine.internal:5301
    timeout: 20s
```

1. The address to listen on.
2. The address to forward to.
3. Optional. The timeout for each UDP session. If omitted, the default timeout is 60 seconds.
4. You can have one or more forwarding rules.

### TCP TProxy (Linux only)

TPROXY (transparent proxy) is a Linux-specific feature that allows you to transparently proxy TCP connections. For information, please refer to [Setting up TPROXY](TPROXY.md).

```yaml
tcpTProxy:
  listen: :2500 # (1)!
```

1. The address to listen on.

### UDP TProxy (Linux only)

TPROXY (transparent proxy) is a Linux-specific feature that allows you to transparently proxy UDP connections. For information, please refer to [Setting up TPROXY](TPROXY.md).

```yaml
udpTProxy:
  listen: :2500 # (1)!
  timeout: 20s # (2)!
```

1. The address to listen on.
2. Optional. The timeout for each UDP session. If omitted, the default timeout is 60 seconds.

### TCP Redirect (Linux only)

REDIRECT is essentially a special case of DNAT where the destination address is localhost. This method predates TPROXY as an older way to implement a TCP transparent proxy. We recommend using TPROXY instead if your kernel supports it.

```yaml
tcpRedirect:
  listen: :3500
```

Example:

=== "iptables"

    ```bash
    iptables -t nat -N HYSTERIA
    iptables -t nat -A HYSTERIA -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A HYSTERIA -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A HYSTERIA -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A HYSTERIA -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A HYSTERIA -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A HYSTERIA -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A HYSTERIA -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A HYSTERIA -d 240.0.0.0/4 -j RETURN
    iptables -t nat -A HYSTERIA -p tcp -j REDIRECT --to-ports 3500
    iptables -t nat -A OUTPUT -p tcp -j HYSTERIA
    iptables -t nat -A PREROUTING -p tcp -j HYSTERIA

    ip6tables -t nat -N HYSTERIA
    ip6tables -t nat -A HYSTERIA ! -d 2000::/3 -j RETURN
    ip6tables -t nat -A HYSTERIA -p tcp -j REDIRECT --to-ports 3500
    ip6tables -t nat -A OUTPUT -p tcp -j HYSTERIA
    ip6tables -t nat -A PREROUTING -p tcp -j HYSTERIA
    ```

=== "nftables"

    ```nginx
    define HYSTERIA_REDIRECT_PORT=3500
    define BYPASS_IPV4={
        0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16,
        172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/3
    }
    define BYPASS_IPV6={ ::/128 }

    table inet hysteria_redirect {
      chain prerouting {
        type nat hook prerouting priority filter; policy accept;
        meta l4proto tcp counter jump hysteria
      }

      chain output {
        type nat hook output priority filter; policy accept;
        meta l4proto tcp counter jump hysteria
      }

      chain hysteria {
        ip daddr $BYPASS_IPV4 counter return
        ip6 daddr $BYPASS_IPV6 counter return
        ip6 daddr != 2000::/3 counter return
        meta l4proto tcp counter redirect to :$HYSTERIA_REDIRECT_PORT
      }
    }
    ```

### TUN

TUN mode is a cross-platform transparent proxy solution that creates a virtual network interface in the system and uses the system's routes to capture and redirect traffic. It currently works on Windows, Linux, and macOS.

Unlike traditional L3 VPNs (such as WireGuard and OpenVPN), Hysteria's TUN mode can only handle TCP and UDP and does not support other protocols including ICMP (e.g. ping). It also takes control of the TCP stack to speed up TCP connections.

Compared to Hysteria 1's implementation, Hysteria 2's TUN is based on [sing-tun](https://github.com/SagerNet/sing-tun)'s "system" stack, requiring a /30 IPv4 address and a /126 IPv6 address to be configured on the interface. Hysteria will automatically set up the network interface, addresses, and routes.

> **NOTE:** `ipv4Exclude`/`ipv6Exclude` is important to avoid getting a routing loop. See the comments for these fields for more information.

```yaml
tun:
  name: "hytun" # (1)!
  mtu: 1500 # (2)!
  timeout: 5m # (3)!
  address: # (4)!
    ipv4: 100.100.100.101/30
    ipv6: 2001::ffff:ffff:ffff:fff1/126
  route: # (5)!
    ipv4: [0.0.0.0/0] # (6)!
    ipv6: ["2000::/3"] # (7)!
    ipv4Exclude: [192.0.2.1/32] # (8)!
    ipv6Exclude: ["2001:db8::1/128"] # (9)!
```

1. Name of the TUN interface.
2. Optional. The maximum packet size accepted by the TUN interface. The default is 1500 bytes.
3. Optional. UDP session timeout. The default is 5 minutes.
4. Optional. Addresses to use on the interface. Set to any private address that does not conflict with your LAN. The defaults are as shown.
5. Optional. Routing rules. Omitting or skipping all fields means that no routes will be added automatically. In most cases, just having `ipv4Exclude` or `ipv6Exclude` is enough.
6. Optional. IPv4 prefix to proxy. If any other field is configured, the default is `0.0.0.0/0`.
7. Optional. IPv6 prefix to proxy. Due to YAML limitations, quotes are required. If any other field is configured, the default is `::/0`.
8. Optional. IPv4 prefix to exclude. **Add your Hysteria server address here to avoid a routing loop.** If you want to disable IPv4 proxying completely, you can also put `0.0.0.0/0` here.
9. Optional. IPv6 prefix to exclude. Due to YAML limitations, quotes are required. **Add your Hysteria server address here to avoid a routing loop.** If you want to disable IPv6 proxying completely, you can also put `"::/0"` here.

Note: On Linux, it is sometimes necessary to disable `rp_filter` to allow an interface to receive traffic from other interfaces.

```bash
sysctl net.ipv4.conf.default.rp_filter=2
sysctl net.ipv4.conf.all.rp_filter=2
```

Known compatibility issues:

| OS                  | Issue                                                                                                                                                                                                                                                                                                                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| macOS               | The name of the TUN interface must be utun followed by a number, for example `utun123`.                                                                                                                                                                                                                                                                                            |
| Windows Server 2022 | Windows Firewall must be disabled for this to work.                                                                                                                                                                                                                                                                                                                                |
| CentOS 7            | Firewall must be disabled for this to work. For kernels before 4.17, the automatically added routes will not work properly ([reason](https://github.com/torvalds/linux/commit/bfff4862653bb96001ab57c1edd6d03f48e5f035)). Upgrade the kernel to 4.17 or higher, or execute `ip rule del from all goto 9010; ip -6 rule del from all goto 9010` after starting the Hysteria client. |
| FreeBSD             | [Not supported](https://github.com/SagerNet/sing-tun/blob/v0.2.4/tun_other.go#L10)                                                                                                                                                                                                                                                                                                 |
