# 关于 HTTP/3

基于 QUIC 的 HTTP/3 正在得到越来越多网站和 CDN 的支持。不过，尽管 Hysteria 本身就是基于 QUIC 的，**我们并不推荐使用 Hysteria 代理 HTTP/3 流量（如果能选 HTTP/2 或更低版本的情况下）**。

## 为什么

Hysteria 的设计思路是使用修改过的拥塞控制算法来最大化吞吐量，而并非降低丢包率。虽然 Hysteria 支持 UDP，但它不能降低 UDP 本身的丢包率。换句话说，当使用 Hysteria 来代理基于 UDP 的协议，比如 HTTP/3 时，不会有任何“加速”效果。这种情况下，连接速度取决于 Web 服务器和浏览器自己的 QUIC 的拥塞控制算法。（通常是 Cubic、Reno 或 BBR）

> 这个问题对于其他代理协议同样存在，并不是 Hysteria 特有的设计或实现问题。

此外，QUIC 加密了所有的传输控制信息，比如 Seq, ACK 等（这些信息在 TCP 是明文的）。这种加密使得类似于通过 TCP 透明代理以替换连接两端拥塞控制的方案也无法实现。

## 解决方案

目前所有网站和应用程序只将 QUIC 用作“升级”选项。如果网络不支持（例如 UDP 不通），会自动回退到使用 TCP 的 HTTP/2 或更低版本。

如果你在 PC 上使用 Chrome 或 Firefox，并且用的是 HTTP/SOCKS5 代理，浏览器一般已经自动禁用了 HTTP/3，因为 HTTP 代理本身就不支持 UDP 转发。至于 SOCKS5，虽然理论上支持 UDP，但 Chrome 和 Firefox 并未实现这一点，所以也不会使用 UDP 的 HTTP/3。

**如果你是在手机上使用像 Shadowrocket、SagerNet 这样的 VPN 客户端（或在 PC 上使用 tun 模式），建议使用以下其中一种方法手动禁用 HTTP/3。**

- Chrome：进入 `chrome://flags/`，找到 `Experimental QUIC protocol` 将其切换为 `Disabled`。
- Firefox：进入 `about:config`，找到 `network.http.http3.enable` 将其切换为 `false`。
- 使用 ACL 规则阻止 UDP 端口 443。`reject(all, udp/443)`
