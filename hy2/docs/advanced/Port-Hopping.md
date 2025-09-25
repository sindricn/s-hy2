# Port Hopping

Users in China sometimes report that their ISPs block or throttle persistent UDP connections. However, these restrictions often only apply to the specific port being used. Port hopping can be used as a workaround for this situation.

## Client

The Hysteria client supports a special multi-port address format:

```python
example.com:1234,5678,9012 # (1)!
example.com:20000-50000 # (2)!
example.com:1234,5000-6000,7044,8000-9000 # (3)!
```

1. Multiple individual ports.
2. A range of ports.
3. A combination of both.

There is no limit to the number of ports you can specify.

The client will randomly select one of the specified ports for the initial connection and will periodically switch to a different port. The option for controlling the interval is `hopInterval` in the `transport` section:

```yaml
transport:
  udp:
    hopInterval: 30s # (1)!
```

1. 30s is the default. It must be at least 5s.

Assuming the server is reachable on all the ports you specified, the hopping process is transparent to the upper layers and should not cause any data loss/disconnection.

## Server

The Hysteria server does not have built-in support for listening on multiple ports, so you cannot use the above format as a listening address on the server side. **We recommend using iptables or nftables DNAT to forward the ports to the server's listening port.**

=== "iptables"

    ```bash
    # IPv4
    iptables -t nat -A PREROUTING -i eth0 -p udp --dport 20000:50000 -j REDIRECT --to-ports 443
    # IPv6
    ip6tables -t nat -A PREROUTING -i eth0 -p udp --dport 20000:50000 -j REDIRECT --to-ports 443
    ```

=== "nftables"

    ```nginx
    define INGRESS_INTERFACE="eth0"
    define PORT_RANGE=20000-50000
    define HYSTERIA_SERVER_PORT=443

    table inet hysteria_porthopping {
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        iifname $INGRESS_INTERFACE udp dport $PORT_RANGE counter redirect to :$HYSTERIA_SERVER_PORT
      }
    }
    ```

In this example, the server listens on port 443, but the client can connect to any port in the range 20000-50000.
