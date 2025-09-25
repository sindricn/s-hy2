# About HTTP/3

HTTP/3 based on QUIC is increasingly supported by many websites and major CDNs. However, despite the fact that Hysteria itself is based on QUIC, **we don't recommend using Hysteria to proxy HTTP/3 traffic (when it's possible to use HTTP/2 or lower).**

## Why

Hysteria is designed to forward TCP traffic over QUIC, using a modified congestion control algorithm to maximize throughput rather than minimize packet loss. While Hysteria does support UDP, it does not reduce the packet loss of UDP itself. Simply put, you won't experience any "speed-up" effects when using Hysteria to proxy UDP-based protocols such as HTTP/3. The connection speed in this scenario depends solely on the congestion control algorithms of the web server and the browser's own QUIC implementation (typically Cubic, Reno, or BBR).

> The same dilemma applies to basically any other proxy protocol, and is not a design or implementation problem specific to Hysteria.

In addition, QUIC encrypts all transmission control information, such as sequence numbers, acknowledgments, etc., that would traditionally be in clear text. This encryption makes it impossible to implement something conceptually similar to a TCP transparent proxy to replace the original congestion control at either end of the connection.

## Solution

Currently, all sites and applications use QUIC only as an "upgrade" option. If the network doesn't support it (e.g. UDP is blocked), it will fall back to HTTP/2 or lower (which uses TCP).

If you are using Chrome or Firefox with an HTTP/SOCKS5 proxy on a PC, the browser has effectively disabled HTTP/3 by itself because the HTTP proxy cannot support UDP forwarding. As for SOCKS5, while it theoretically supports UDP, it is not implemented in Chrome and Firefox.

**If you are using a VPN client like Shadowrocket, SagerNet on your phone (or tun on your PC), it is recommended to manually disable HTTP/3 using one of the following methods.**

- Chrome: Go to `chrome://flags/`, find `Experimental QUIC protocol` and toggle it to `Disabled`.
- Firefox: Go to `about:config`, find `network.http.http3.enable` and toggle it to `false`.
- Block UDP port 443 with an ACL rule. `reject(all, udp/443)`
