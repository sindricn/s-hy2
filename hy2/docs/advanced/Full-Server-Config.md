# Full Server Config

This page provides documentation for every field in the server configuration file.

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

## Listen

The `listen` field is the server's listen address. If omitted, the server will listen on `:443` since that's the default HTTP/3 port.

```yaml
listen: :443 # (1)!
```

1. When the IP address is omitted, the server will listen on all interfaces, both IPv4 and IPv6. To listen on IPv4 only, you can use `0.0.0.0:443`. To listen on IPv6 only, you can use `[::]:443`.

## TLS

You can have either `tls` or `acme`, but not both.

=== "TLS"

    ```yaml
    tls: # (1)!
      cert: some.crt
      key: some.key
      sniGuard: strict | disable | dns-san # (2)!
      clientCA: client.crt # (3)!
    ```

    1. Certificates are read on every TLS handshake. This means you can update the files without restarting the server.
    2. Verify the SNI provided by the client. Accept the connection only when it matches what's in the certificate. Terminate the TLS handshake otherwise. <br>
       Set to `strict` to enforce this behavior. <br>
       Set to `disable` to disable this entirely. <br>
       The default is `dns-san`, which enables this feature only when the certificate contains the "Subject Alternative Name" extension with a domain name in it.
    3. Use a client CA for mTLS verification.

=== "ACME"

    ```yaml
    acme:
      domains:
        - domain1.com
        - domain2.org
      email: your@email.net
      ca: zerossl # (1)!
      listenHost: 0.0.0.0 # (2)!
      dir: my_acme_dir # (3)!
      type: http | tls | dns # (4)!
      http:
        altPort: 8888 # (5)!
      tls:
        altPort: 44333 # (6)!
      dns:
        name: gomommy # (7)!
        config:
          key1: value1
          key2: value2
    ```

    1. CA to use. Can be `letsencrypt` or `zerossl`.
    2. Listening address for ACME verification (no port). Defaults to listening on all available interfaces.
    3. Directory to store ACME credentials.
    4. ACME challenge type. Please read the instructions regarding the "type selector" at the top of this page.
    5. Listening port for HTTP challenges.
       (Note: Changing to a port other than 80 requires port forwarding or HTTP reverse proxy, or the challenge will fail!)
    6. Listening port for TLS-ALPN challenges.
       (Note: Changing to a port other than 443 requires port forwarding or TLS reverse proxy, or the challenge will fail!)
    7. DNS provider. For details, refer to [ACME DNS Configuration](ACME-DNS-Config.md).

## Obfuscation

By default, the Hysteria protocol mimics HTTP/3. If your network specifically blocks QUIC or HTTP/3 traffic (but not UDP in general), obfuscation can be used to work around this. We currently have an obfuscation implementation called "Salamander" that converts packets into seamingly random bytes with no pattern. This feature requires a password that must be identical on both the client and server sides.

> **NOTE:** Enabling obfuscation will make your server incompatible with standard QUIC connections and it will no longer function as a valid HTTP/3 server.

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
  maxIncomingStreams: 1024 # (6)!
  disablePathMTUDiscovery: false # (7)!
```

1. The initial QUIC stream receive window size.
2. The maximum QUIC stream receive window size.
3. The initial QUIC connection receive window size.
4. The maximum QUIC connection receive window size.
5. The maximum idle timeout. How long the server will consider the client still connected without any activity.
6. The maximum number of concurrent incoming streams.
7. Disable QUIC path MTU discovery.

The default stream and connection receive window sizes are 8MB and 20MB, respectively. **We do not recommend changing these values unless you fully understand what you are doing.** If you choose to change these values, we recommend keeping the ratio of stream receive window to connection receive window at 2:5.

## Bandwidth

```yaml
bandwidth:
  up: 1 gbps
  down: 1 gbps
```

The bandwidth values on the server side act as speed limits, limiting the maximum rate at which the server will send and receive data (per client). **Note that the server's upload speed is the client's download speed, and vice versa.** You can omit these values or set them to zero on either or both sides, which would mean no limit.

Supported units are:

- `bps` or `b` (bits per second)
- `kbps` or `kb` or `k` (kilobits per second)
- `mbps` or `mb` or `m` (megabits per second)
- `gbps` or `gb` or `g` (gigabits per second)
- `tbps` or `tb` or `t` (terabits per second)

### Ignore client bandwidth

```yaml
ignoreClientBandwidth: false
```

`ignoreClientBandwidth` is a special option that, when enabled, makes the server to disregard any bandwidth hints set by clients, opting to use a more traditional congestion control algorithm (currently BBR) instead. This effectively overrides any bandwidth values set by clients in both directions.

This feature is primarily useful for server owners who prefer congestion fairness over other network traffic, or who do not trust users to accurately set their own bandwidth values.

### Bandwidth negotiation process

The following diagram shows the process of negotiating which congestion control algorithm and bandwidth value to use between the client and server under various configurations.

```mermaid
graph TD;
    ICB{{"Is the server configured with ignoreClientBandwidth: true?"}} -- "Yes" --> BBR[/"Use BBR"/];
    ICB -- "No" --> C_has_BW;
    C_has_BW{{"Is the client configured with bandwidth?"}} -- "No" --> BBR;
    C_has_BW -- "Yes" --> Brutal;
    Brutal["Use Brutal"] --> S_has_BW;
    S_has_BW{{"Is the server configured with bandwidth?"}} -- "No" --> Brutal_C[/"Use client's value"/];
    S_has_BW -- "Yes" --> S_C_CMP;
    S_C_CMP{{"Compare server and client bandwidth values"}} -- "Server greater" --> Brutal_C;
    S_C_CMP -- "Client greater" --> Brutal_S[/"Use server's value"/];

    style BBR fill:#dc322f;
    style Brutal fill:#268bd2;
    style Brutal_C fill:#2aa198;
    style Brutal_S fill:#2aa198;
```

If you are setting up a Hysteria server for personal use, you can simplify it by removing `bandwidth` and `ignoreClientBandwidth` from the server configuration, only specifying the bandwidth in the client configuration:

```mermaid
graph TD;
    S_no_BW["`Ensure the server is **NOT** configured with bandwidth and ignoreClientBandwidth`"] --> C_has_BW;
    C_has_BW{{"Is the client configured with bandwidth?"}} -- "No" --> BBR[/"BBR"/];
    C_has_BW -- "Yes" --> Brutal_C[/"Use Brutal and use client's value"/];

    style BBR fill:#dc322f;
    style Brutal_C fill:#2aa198;
```

### Congestion control details

**(The information in this section is considered internal implementation details of Hysteria and may change between versions)**

Currently, Hysteria has 2 congestion control algorithms:

**BBR:** Originally developed by Google for TCP, we adapted this algorithm for QUIC with minor modifications. BBR is a typical congestion control algorithm, including slow start phases and bandwidth estimation based on RTT variations. It works on its own and does not require bandwidth settings.

**Brutal:** This is Hysteria's custom congestion control algorithm. Unlike BBR, Brutal operates on a fixed rate model and does not reduce its speed in response to packet loss or RTT changes. If it fails to meet the predetermined target rate, the algorithm calculates the rate of packet loss and compensates by increasing speed. This only works if you know (and accurately specify) the theoretical maximum speed of your current connection. It's particularly effective at seizing bandwidth in congested, best-effort delivery networks, hence its name.

> Brutal will also work if you set your bandwidth values below your connection's maximum speed; it will simply serve as a speed limiter. However, DO NOT set it higher than what's possible, as this will result in a slow, unstable connection and wasted data.

Congestion control algorithms controls the sending of data. From the client's point of view, if the user doesn't provide his bandwidth value for download (but provides it for upload), the Hysteria server will send data to the client using BBR, but the client will upload data to the server using Brutal, and vice versa. The client can provide both, so both directions will use Brutal, or neither, so both will use BBR.

The special case, as mentioned above, is when the server has `ignoreClientBandwidth` enabled, in which case both sides will always use BBR, no matter what the client's bandwidth values are.

**The server's bandwidth limit only applies to Brutal at the moment. It has no effect on BBR.**

## Speed Test

```yaml
speedTest: false
```

`speedTest` enables the built-in speed test server. When enabled, clients can test their download and upload speeds with the server. For more information, see the [Speed Test documentation](Speed-Test.md).

## UDP

```yaml
disableUDP: false
```

`disableUDP` disables UDP forwarding, only allowing TCP connections.

```yaml
udpIdleTimeout: 60s
```

`udpIdleTimeout` specifies the amount of time the server will keep a local UDP port open for each UDP session that has no activity. This is conceptually similar to the NAT UDP session timeout.

## Authentication

```yaml
auth:
  type: password | userpass | http | command # (6)!
  password: your_password # (1)!
  userpass: # (2)!
    user1: pass1
    user2: pass2
    user3: pass3
  http:
    url: http://your.backend.com/auth # (3)!
    insecure: false # (4)!
  command: /etc/some_command # (5)!
```

1. Replace with a strong password of your choice.
2. A map of username-password pairs.
3. The URL of the backend server that handles authentication.
4. Disable TLS verification for the backend server (only applies to HTTPS URLs).
5. The path to the command that handles authentication.
6. Please read the instructions regarding the "type selector" at the top of this page.

### HTTP authentication

When using HTTP authentication, the server will send a `POST` request to the backend server with the following JSON body when a client attempts to connect:

```json
{
  "addr": "123.123.123.123:44556", // (1)!
  "auth": "something_something", // (2)!
  "tx": 123456 // (3)!
}
```

1. The client's IP address and port.
2. The client's authentication payload.
3. The tx rate (in bytes per second). Tx as seen by the server; corresponds to the rx (download) rate of the client.

Your endpoint must respond with a JSON object with the following fields:

```json
{
  "ok": true, // (1)!
  "id": "john_doe" // (2)!
}
```

1. Whether to allow this client to connect.
2. The client's unique identifier. This is used in logs and traffic statistics API.

> **NOTE:** The HTTP status code must be 200 for the authentication to be considered successful.

### Command authentication

When using command authentication, the server will execute the specified command with the following arguments when a client attempts to connect:

```bash
/etc/some_command addr auth tx # (1)!
```

1. The definition of each argument is the same as in the HTTP authentication section above.

The command must print the client's unique identifier to `stdout` and return with exit code 0 if the client is allowed to connect, or return with a non-zero exit code if the client is rejected.

If the command fails to execute, the client will be rejected.

## Resolver

You can specify what resolver (DNS server) to use to resolve domain names in client requests.

```yaml
resolver:
  type: udp | tcp | tls | https # (8)!
  tcp:
    addr: 8.8.8.8:53 # (1)!
    timeout: 4s # (2)!
  udp:
    addr: 8.8.4.4:53 # (3)!
    timeout: 4s
  tls:
    addr: 1.1.1.1:853 # (4)!
    timeout: 10s
    sni: cloudflare-dns.com # (5)!
    insecure: false # (6)!
  https:
    addr: 1.1.1.1:443 # (7)!
    timeout: 10s
    sni: cloudflare-dns.com
    insecure: false
```

1. The address of the TCP resolver.
2. The timeout for DNS queries.
3. The address of the UDP resolver.
4. The address of the TLS resolver.
5. The SNI to use for the TLS resolver.
6. Disable TLS verification for the TLS resolver.
7. The address of the HTTPS resolver.
8. Please read the instructions regarding the "type selector" at the top of this page.

If omitted, Hysteria will use the system's default resolver.

## Protocol Sniffing

Due to factors such as the client's inbound (e.g., TUN mode) and configuration, Hysteria sometimes can't get the domain name of the destination address and only gets the IP. But the IP the client and server get for the same domain might be different, and the ACL's domain rules can't match IP requests. By enabling protocol sniffing, the server can use DPI to extract the domain name from the connection (for supported protocols) and convert the IP request to a domain one.

Currently supported protocols are:

- HTTP - Host in the header
- TLS (HTTPS) - SNI
- QUIC (HTTP/3) - SNI

```yaml
sniff:
  enable: true # (1)!
  timeout: 2s # (2)!
  rewriteDomain: false # (3)!
  tcpPorts: 80,443,8000-9000 # (4)!
  udpPorts: all # (5)!
```

1. Whether to enable protocol sniffing.
2. Sniffing timeout. If the protocol/domain cannot be determined within this time, the original address will be used to initiate the connection.
3. Whether to rewrite requests that are already in domain name form. If enabled, requests with the target address already in domain name form will still be sniffed.
4. List of TCP ports. Only TCP requests on these ports will be sniffed.
5. List of UDP ports. Only UDP requests on these ports will be sniffed.

> **Note:** If no port list is provided, all ports will be sniffed by default. The format of the port list is the same as port hopping, supporting multiple single ports and port ranges (inclusive) separated by commas.

## ACL

ACL, often used in combination with outbounds, is a very powerful feature of the Hysteria server that allows you to customize the way client's requests are handled. For example, you can use ACL to block certain addresses, or to use different outbounds for different websites.

For details on syntax, usage and other information, please refer to the [ACL documentation](ACL.md).

You can have either `file` or `inline`, but not both.

=== "File"

    ```yaml
    acl:
      file: some.txt # (1)!
      # geoip: geoip.dat (2)
      # geosite: geosite.dat (3)
      # geoUpdateInterval: 168h (4)
    ```

    1. The path to the ACL file.
    2. Optional. Uncomment to enable. The path to the GeoIP database file. **If this field is omitted, Hysteria will automatically download the latest database to your working directory.**
    3. Optional. Uncomment to enable. The path to the GeoSite database file. **If this field is omitted, Hysteria will automatically download the latest database to your working directory.**
    4. Optional. The interval at which to refresh the GeoIP/GeoSite databases. 168 hours (1 week) by default. Only applies if the GeoIP/GeoSite databases are automatically downloaded. (Check the note below for more information.)

=== "Inline"

    ```yaml
    acl:
      inline: # (1)!
        - reject(suffix:v2ex.com)
        - reject(all, udp/443)
        - reject(geoip:cn)
        - reject(geosite:netflix)
      # geoip: geoip.dat (2)
      # geosite: geosite.dat (3)
      # geoUpdateInterval: 168h (4)
    ```

    1. The list of inline ACL rules.
    2. Optional. Uncomment to enable. The path to the GeoIP database file. **If this field is omitted, Hysteria will automatically download the latest database to your working directory.**
    3. Optional. Uncomment to enable. The path to the GeoSite database file. **If this field is omitted, Hysteria will automatically download the latest database to your working directory.**
    4. Optional. The interval at which to refresh the GeoIP/GeoSite databases. 168 hours (1 week) by default. Only applies if the GeoIP/GeoSite databases are automatically downloaded. (Check the note below for more information.)

> **NOTE:** Hysteria currently uses the protobuf-based "dat" format for geoip/geosite data originating from v2ray. If you don't need any customization, you can omit the `geoip` or `geosite` fields and let Hysteria automatically download the latest version (from <https://github.com/Loyalsoldier/v2ray-rules-dat>) to your working directory. The files will only be downloaded and used if your ACL has at least one rule that uses this feature.

> **NOTE:** Hysteria currently only downloads the GeoIP/GeoSite databases once at startup. You will need to use external tools to periodically restart the Hysteria server in order to update the databases regularly through `geoUpdateInterval`. This may change in future versions.

## Outbounds

Outbounds are used to define the "exit" through which a connection should be routed. For example, when [combined with ACL](ACL.md), you can route all traffic except Netflix directly through the local interface, while routing Netflix traffic through a SOCKS5 proxy.

Currently, Hysteria supports the following outbound types:

- `direct`: Direct connection through the local interface.
- `socks5`: SOCKS5 proxy.
- `http`: HTTP/HTTPS proxy.

> **NOTE:** HTTP/HTTPS proxies do not support UDP at the protocol level. Sending UDP traffic to HTTP outbounds will result in rejection.

**If you do not use ACL, all connections will always be routed through the first ("default") outbound in the list, and all other outbounds will be ignored.**

```yaml
outbounds:
  - name: my_outbound_1 # (1)!
    type: direct # (7)!
  - name: my_outbound_2
    type: socks5
    socks5:
      addr: shady.proxy.ru:1080 # (2)!
      username: hackerman # (3)!
      password: Elliot Alderson # (4)!
  - name: my_outbound_3
    type: http
    http:
      url: http://username:password@sketchy-proxy.cc:8081 # (5)!
      insecure: false # (6)!
```

1. The name of the outbound. This is used in ACL rules.
2. The address of the SOCKS5 proxy.
3. Optional. The username for the SOCKS5 proxy, if authentication is required.
4. Optional. The password for the SOCKS5 proxy, if authentication is required.
5. The URL of the HTTP/HTTPS proxy. (Can be `http://` or `https://`)
6. Optional. Whether to disable TLS verification. Applies to HTTPS proxies only.
7. Please read the instructions regarding the "type selector" at the top of this page.

### Customizing `direct` outbound

The direct outbound has a few additional options that can be used to customize its behavior:

> **NOTE:** The options `bindIPv4`, `bindIPv6`, and `bindDevice` are mutually exclusive. You can either specify `bindIPv4` and/or `bindIPv6` without `bindDevice`, or use `bindDevice` without `bindIPv4` and `bindIPv6`.

```yaml
outbounds:
  - name: hoho
    type: direct
    direct:
      mode: auto # (1)!
      bindIPv4: 2.4.6.8 # (2)!
      bindIPv6: 0:0:0:0:0:ffff:0204:0608 # (3)!
      bindDevice: eth233 # (4)!
      fastOpen: false # (5)!
```

1. See the explanation below.
2. The local IPv4 address to bind to.
3. The local IPv6 address to bind to.
4. The local network interface to bind to.
5. Enable TCP fast open.

The available `mode` values are:

- `auto`: Default. Dual-stack "happy eyeballs" mode. The client will attempt to connect to the destination using both IPv4 and IPv6 addresses (if available), and use the first one that succeeds.
- `64`: Always use IPv6 if available, otherwise use IPv4.
- `46`: Always use IPv4 if available, otherwise use IPv6.
- `6`: Always use IPv6. Fail if no IPv6 address is available.
- `4`: Always use IPv4. Fail if no IPv4 address is available.

## Traffic Stats API (HTTP)

The Traffic Stats API allows you to query the server's traffic statistics and kick clients using an HTTP API. For endpoints and usage, please refer to the [Traffic Stats API documentation](Traffic-Stats-API.md).

```yaml
trafficStats:
  listen: :9999 # (1)!
  secret: some_secret # (2)!
```

1. The address to listen on.
2. The secret key to use for authentication. Attach this to the `Authorization` header in your HTTP requests.

> **NOTE:** If you don't set a secret, anyone with access to your API listening address will be able to see traffic stats and kick users. We strongly recommend setting a secret, or at least using ACL to block users from accessing the API.

## Masquerade

One of the keys to Hysteria's censorship resistance is its ability to masquerade as standard HTTP/3 traffic. This means that not only do the packets appear as HTTP/3 to middleboxes, but the server also responds to HTTP requests like a regular web server. However, this means that your server must actually serve some content to make it appear authentic to potential censors.

**If censorship is not a concern, you can omit the `masquerade` section entirely. In this case, Hysteria will always return "404 Not Found" for all HTTP requests.**

Currently, Hysteria provides the following masquerade modes:

- `file`: Act as a static file server, serving files from a directory.
- `proxy`: Act as a reverse proxy, serving content from another website.
- `string`: Act as a server that always returns a user-supplied string.

```yaml
masquerade:
  type: file | proxy | string # (7)!
  file:
    dir: /www/masq # (1)!
  proxy:
    url: https://some.site.net # (2)!
    rewriteHost: true # (3)!
    insecure: false # (4)!
  string:
    content: hello stupid world # (5)!
    headers: # (6)!
      content-type: text/plain
      custom-stuff: ice cream so good
    statusCode: 200 # (7)!
```

1. The directory to serve files from.
2. The URL of the website to proxy.
3. Whether to rewrite the `Host` header to match the proxied website. This is required if the target web server uses `Host` to determine which site to serve.
4. Disable TLS verification for the proxied website.
5. The string to return.
6. Optional. The headers to return.
7. Optional. The status code to return. 200 by default.
8. Please read the instructions regarding the "type selector" at the top of this page.

You can test your masquerade configuration by starting Chrome with a special flag (to force QUIC):

```bash
chrome --origin-to-force-quic-on=your.site.com:443 # (1)!
```

1. Replace with the domain name of your server.

> **NOTE:** Before you start Chrome with the flag, make sure you've completely shut it down so that no Chrome process is still running in the background. Otherwise, the flag will not take effect.

Then visit `https://your.site.com` to verify that it works as expected.

### HTTP/HTTPS Masquerading

Websites that support HTTP/3 usually offer it as an upgrade option, also providing TCP-based HTTP/HTTPS on ports 80/443. If you want to mimic this behavior, you can use the `listenHTTP` and `listenHTTPS` options to enable HTTP/HTTPS masquerading. In this case, you don't need to launch Chrome with the special flag mentioned above; you can test it by accessing the site as you would with any other website.

```yaml
masquerade:
  # ... (your other options from above)
  listenHTTP: :80 # (1)!
  listenHTTPS: :443 # (2)!
  forceHTTPS: true # (3)!
```

1. HTTP (TCP) listen address.
2. HTTPS (TCP) listen address.
3. Whether to force HTTPS. If enabled, all HTTP requests will be redirected to HTTPS.

> **Note:** There is no evidence that any government or commercial firewalls are using "missing TCP HTTP/HTTPS" as a means of detecting Hysteria servers. This feature is only provided for users who want to "go the extra mile". And if so, there's no reason to listen on ports other than the default 80/443 (although Hysteria does allow it).
