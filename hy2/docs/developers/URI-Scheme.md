# URI Scheme

The Hysteria 2 URI scheme is designed to provide a compact representation of the necessary information for connecting to a Hysteria 2 server. It captures various parameters such as server address, authentication details, obfuscation type and parameters, TLS settings.

## Structure

```
hysteria2://[auth@]hostname[:port]/?[key=value]&[key=value]...
```

## Components

### Scheme

`hysteria2` or `hy2`

### Auth

Authentication credentials should be specified in the `auth` component of the URI. This is essentially the username part of the standard URI format, and therefore needs to be [percent-encoded](https://datatracker.ietf.org/doc/html/rfc3986#section-2.1) if it contains special characters.

A special case is when the server uses the `userpass` authentication, in which case the `auth` component should be formatted as `username:password`.

### Hostname

The hostname and optional port of the server. If the port is omitted, it defaults to 443.

The port part supports the "multi-port" format mentioned in [Port Hopping](../advanced/Port-Hopping.md).

### Query parameters

- `obfs`: The type of obfuscation to be used. Current only `salamander` is supported.

- `obfs-password`: The password required for the specified obfuscation type, if applicable.

- `sni`: Server Name Indication to be used for TLS connections.

- `insecure`: Determines if insecure TLS connections are allowed. Accepts boolean values "1" for true and "0" for false.

- `pinSHA256`: The pinned SHA-256 fingerprint of the server's certificate.

## Example

```
hysteria2://letmein@example.com:123,5000-6000/?insecure=1&obfs=salamander&obfs-password=gawrgura&pinSHA256=deadbeef&sni=real.example.com
```

## Implementation notes

The URI is intentionally designed to contain only the essential information needed to connect to a Hysteria 2 server. While third-party implementations are free to add additional parameters if necessary, they must not assume that other implementations will understand them.

Furthermore, the parameters should never include client modes (HTTP, SOCKS5, etc.) or bandwidth values. Users should be aware that these things are not meant to be shared and used blindly by others, as they are specific to each user and should be configured accordingly.
