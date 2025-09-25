# Setting up TPROXY

TPROXY is a transparent proxy framework available only on Linux, supporting both TCP and UDP protocols.

## Avoiding Loops

> Skip this section if you don't need to proxy traffic from the device itself that is running the Hysteria client.

In scenarios where the device's own traffic needs to be proxied, to avoid traffic loops with Hysteria, it's essential to separate the Hysteria client's own traffic from the traffic that's being proxied. The best way to achieve this is to run the Hysteria client as a dedicated user and then perform user-based matching in iptables or nftables.

> We also recommend running Hysteria as a dedicated user when using one-click installation scripts and Linux distribution packages, and to configure it according to this section.

1.  Create a dedicated user specifically for running the Hysteria client.

    ```bash
    useradd --system hysteria
    ```

2.  Grant the necessary [`capabilities(7)`](https://man7.org/linux/man-pages/man7/capabilities.7.html) for the Hysteria client to operate normally.

    ```bash
    setcap CAP_NET_ADMIN,CAP_NET_BIND_SERVICE+ep /path/to/hysteria # (1)!
    ```

    1. Replace with the actual installation path of Hysteria.

    You'll need to perform this step each time you manually update the Hysteria client.

3.  Configure the Hysteria client to start as this dedicated user.

    If running the Hysteria client manually:

    ```bash
    sudo -u hysteria /path/to/hysteria -c config.yaml
    ```

    Alternatively, if you're using systemd to manage the Hysteria service, you can add `User=hysteria` under the `[Service]` section in the systemd configuration for the service.

## Configuring the Client

> In the examples that follow, we will use `2500` as the listening port for TProxy. Feel free to use a different port if you wish.

Add the following lines to your client configuration:

=== "Proxy Both TCP and UDP"

    ```yaml
    tcpTProxy:
        listen: :2500 # (1)!

    udpTProxy:
        listen: :2500
    ```

    1. If you need support for both IPv4 and IPv6, do not add an IP address before the `:`.

=== "Proxy TCP Only"

    ```yaml
    tcpTProxy:
        listen: :2500 # (1)!
    ```

    1. If you need support for both IPv4 and IPv6, do not add an IP address before the `:`.

## Configuring Routing Rules

This step is **not optional**. Do not skip this step; otherwise TProxy will not work.

> You will need to run these commands every time the system boots unless you make them persistent.

> In the following examples, we will use `0x1` as the fwmark for TProxy policy routing rules and `100` as the Table ID for the TProxy routing table. Feel free to use different values if you wish.

```bash
# IPv4
ip rule add fwmark 0x1 lookup 100
ip route add local default dev lo table 100

# IPv6
ip -6 rule add fwmark 0x1 lookup 100
ip -6 route add local default dev lo table 100
```

## Configuring iptables or nftables

> You will need to run these commands every time the system boots, unless you make them persistent.

=== "iptables (IPv4)"

    ```bash
    iptables -t mangle -N HYSTERIA

    # Skip traffic already handled by TProxy (1)
    iptables -t mangle -A HYSTERIA -p tcp -m socket --transparent -j MARK --set-mark 0x1
    iptables -t mangle -A HYSTERIA -p udp -m socket --transparent -j MARK --set-mark 0x1
    iptables -t mangle -A HYSTERIA -m socket -j RETURN

    # Skip private and special IPv4 addresses (3)
    iptables -t mangle -A HYSTERIA -d 0.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA -d 10.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA -d 169.254.0.0/16 -j RETURN
    iptables -t mangle -A HYSTERIA -d 172.16.0.0/12 -j RETURN
    iptables -t mangle -A HYSTERIA -d 192.168.0.0/16 -j RETURN
    iptables -t mangle -A HYSTERIA -d 224.0.0.0/4 -j RETURN
    iptables -t mangle -A HYSTERIA -d 240.0.0.0/4 -j RETURN

    # Redirect traffic to the TProxy port
    iptables -t mangle -A HYSTERIA -p tcp -j TPROXY --on-port 2500 --on-ip 127.0.0.1 --tproxy-mark 0x1
    iptables -t mangle -A HYSTERIA -p udp -j TPROXY --on-port 2500 --on-ip 127.0.0.1 --tproxy-mark 0x1 # (4)!

    # Enable the above rules
    iptables -t mangle -A PREROUTING -j HYSTERIA

    # === Proxy Local Traffic - Start === (2)

    iptables -t mangle -N HYSTERIA_MARK

    # Match user to prevent loops
    iptables -t mangle -A HYSTERIA_MARK -m owner --uid-owner hysteria -j RETURN

    # Skip LAN and special IPv4 addresses
    iptables -t mangle -A HYSTERIA_MARK -d 0.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 10.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 169.254.0.0/16 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 172.16.0.0/12 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 192.168.0.0/16 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 224.0.0.0/4 -j RETURN
    iptables -t mangle -A HYSTERIA_MARK -d 240.0.0.0/4 -j RETURN

    # Mark traffic to re-route it to PREROUTING
    iptables -t mangle -A HYSTERIA_MARK -p tcp -j MARK --set-mark 0x1
    iptables -t mangle -A HYSTERIA_MARK -p udp -j MARK --set-mark 0x1

    # Enable the above rules
    iptables -t mangle -A OUTPUT -j HYSTERIA_MARK

    # === Proxy Local Traffic - End ===
    ```

    1. If the interface for the default route has a public IPv4 address assigned by your ISP, omitting these rules will result in abnormal proxy behavior for local traffic.

    2. The following rules are **additional** rules for configuring proxy for local traffic. The rules before this line are still mandatory even if you only need to proxy local traffic. If you only need to proxy traffic within the local network, you can skip the rules after this line.

    3. When proxying local traffic (enabling OUTPUT chain rules), additional rules are needed if you require access to this router via a public IPv4 address assigned by your ISP.

    4. If you do not need to proxy UDP traffic, you can remove all rules that include `-p udp`.

=== "iptables (IPv6)"

    ```bash
    ip6tables -t mangle -N HYSTERIA

    # Skip traffic already handled by TProxy (1)
    ip6tables -t mangle -A HYSTERIA -p tcp -m socket --transparent -j MARK --set-mark 0x1
    ip6tables -t mangle -A HYSTERIA -p udp -m socket --transparent -j MARK --set-mark 0x1
    ip6tables -t mangle -A HYSTERIA -m socket -j RETURN

    # Only proxy public IPv6 addresses (3)
    ip6tables -t mangle -A HYSTERIA ! -d 2000::/3 -j RETURN

    # Redirect traffic to the TProxy port
    ip6tables -t mangle -A HYSTERIA -p tcp -j TPROXY --on-port 2500 --on-ip ::1 --tproxy-mark 0x1
    ip6tables -t mangle -A HYSTERIA -p udp -j TPROXY --on-port 2500 --on-ip ::1 --tproxy-mark 0x1 # (4)!

    # Enable the above rules
    ip6tables -t mangle -A PREROUTING -j HYSTERIA

    # === Proxy Local Traffic - Start === (2)

    ip6tables -t mangle -N HYSTERIA_MARK

    # Match user to prevent loops
    ip6tables -t mangle -A HYSTERIA_MARK -m owner --uid-owner hysteria -j RETURN

    # Only proxy public IPv6 addresses
    ip6tables -t mangle -A HYSTERIA_MARK ! -d 2000::/3 -j RETURN

    # Mark traffic to re-route it to PREROUTING
    ip6tables -t mangle -A HYSTERIA_MARK -p tcp -j MARK --set-mark 0x1
    ip6tables -t mangle -A HYSTERIA_MARK -p udp -j MARK --set-mark 0x1

    # Enable the above rules
    ip6tables -t mangle -A OUTPUT -j HYSTERIA_MARK

    # === Proxy Local Traffic - End ===
    ```

    1. If the interface for the default route has a public IPv6 address assigned by your ISP, omitting these rules will result in abnormal proxy behavior for local traffic.

    2. The following rules are **additional** rules for configuring proxy for local traffic. The rules before this line are still mandatory even if you only need to proxy local traffic. If you only need to proxy traffic within the local network, you can skip the rules after this line.

    3. When proxying local traffic (enabling OUTPUT chain rules), additional rules are needed if you require access to this router via a public IPv6 address assigned by your ISP.

    4. If you do not need to proxy UDP traffic, you can remove all rules that include `-p udp`.

=== "nftables"

    ```nginx
    define TPROXY_MARK=0x1
    define HYSTERIA_USER=hysteria
    define HYSTERIA_TPROXY_PORT=2500

    # Protocols to proxy (4)
    define TPROXY_L4PROTO={ tcp, udp }

    # Bypass addresses (3)
    define BYPASS_IPV4={
        0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16,
        172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/3
    }
    define BYPASS_IPV6={ ::/128 }

    table inet hysteria_tproxy {
      chain prerouting {
        type filter hook prerouting priority mangle; policy accept;

        # Bypass traffic already handled by TProxy (1)
        meta l4proto $TPROXY_L4PROTO socket transparent 1 counter mark set $TPROXY_MARK
        socket transparent 0 socket wildcard 0 counter return

        # Bypass private and special IP addresses
        ip daddr $BYPASS_IPV4 counter return
        ip6 daddr $BYPASS_IPV6 counter return

        # Only proxy public IPv6 addresses
        ip6 daddr != 2000::/3 counter return

        # Redirect traffic to the TProxy port
        meta l4proto $TPROXY_L4PROTO counter tproxy to :$HYSTERIA_TPROXY_PORT meta mark set $TPROXY_MARK accept
      }
    }

    # Proxy local traffic (2)
    table inet hysteria_tproxy_local {
      chain output {
        type route hook output priority mangle; policy accept;

        # Match user to prevent loops
        meta skuid $HYSTERIA_USER counter return

        # Bypass private and special IP addresses
        ip daddr $BYPASS_IPV4 counter return
        ip6 daddr $BYPASS_IPV6 counter return

        # Only proxy public IPv6 addresses
        ip6 daddr != 2000::/3 counter return

        # Redirect OUTPUT traffic to PREROUTING
        meta l4proto $TPROXY_L4PROTO counter meta mark set $TPROXY_MARK
      }
    }
    ```

    1. If the interface for the default route has a public IP address, omitting these rules will result in incorrect proxy behavior for local traffic.

    2. The following table is the **additional** table for proxying local traffic. The table before this is still mandatory even if you only need to proxy local traffic. If you only need to proxy traffic within the network (but not the local device itself), you can skip this one.

    3. When proxying local traffic (having OUTPUT chain rules), if you still need to access this router via the public IP address assigned by your ISP, please add the IP address to the bypass list.

    4. If you don't want to proxy UDP traffic, you can change the line below to `define TPROXY_L4PROTO=tcp`.

## References

- [XRay User Guide - TProxy Transparent Proxy](https://xtls.github.io/document/level-2/tproxy_ipv4_and_ipv6.html)
- [XRay User Guide - Bypassing XRay Traffic Through gid with Transparent Proxy](https://xtls.github.io/document/level-2/iptables_gid.html)
- [New V2Ray Plain Language Guide - Transparent Proxy (TProxy)](https://guide.v2fly.org/app/tproxy.html)
