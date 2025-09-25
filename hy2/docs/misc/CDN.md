# Can I use a CDN?

Since Hysteria is built on the QUIC protocol and even masquerades as an HTTP/3 server, some users may be tempted to layer a CDN on top. In countries with restrictive internet, such as China or Iran, Cloudflare is often used to circumvent IP bans on servers hosting WebSocket proxies (e.g. v2ray). **However, the short and clear answer to this question is "no". It simply won't work.**

Why? There are several reasons:

First, while Hysteria can masquerade as an HTTP/3 server, as the name implies, this is merely a disguise. It adheres to the standard HTTP/3 protocol only until the Hysteria client successfully authenticates with the correct credentials. After that, the connection switches to a custom proxy protocol that is not supported by Cloudflare or any other CDN.

Second, most, if not all, CDN services do not currently support connecting to the origin server using HTTP/3. These services typically expect the origin server to use TCP-based HTTP/1 or HTTP/2.

Finally, one of the main reasons Hysteria is so fast is because it uses a custom congestion control system along with fine-tuned parameters. Even if you could hypothetically overcome all of the above obstacles, implementing a reverse proxy would negate the speed advantages that Hysteria offers in the first place, since your client would be communicating with the CDN's QUIC implementation instead of Hysteria's optimized version.
