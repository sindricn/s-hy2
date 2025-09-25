# Server

This tutorial provides a quick guide to deploying a Hysteria server using a recommended setup. Please note that Hysteria is highly flexible and the options presented here are only a subset of what is available. **For further customization, please refer to [Full Server Config](../advanced/Full-Server-Config.md).**

The steps were performed in a Linux environment, but should be similar on other platforms.

## Prerequisites

- A server with a public IP address (both IPv4 and IPv6 are ok)
- A domain name pointing to the server's IP address (both top-level and subdomains are ok)

## Creating configuration file

Assuming you have already downloaded the executable for your platform into a directory, say `hysteria-linux-amd64-avx`. Create a `config.yaml` file in the same directory.

Depending on whether you want to use ACME to automatically obtain a TLS certificate for your domain or use your own, you can use one of the following templates.

**Be sure to replace the values (especially the password) with your own.**

=== "ACME"

    ```yaml
    # listen: :443 (1)

    acme:
      domains:
        - your.domain.net # (2)!
      email: your@email.com # (3)!

    auth:
      type: password
      password: Se7RAuFZ8Lzg # (4)!

    masquerade: # (5)!
      type: proxy
      proxy:
        url: https://news.ycombinator.com/ # (6)!
        rewriteHost: true
    ```

    1. The server listens on port 443 by default. Uncomment this line if you want to change the port. If only a port number is specified (without an address), as in the example, it will listen on both IPv4 and IPv6 by default. To listen on IPv4 only, you can use `0.0.0.0:443`. To listen on IPv6 only, you can use `[::]:443`.
    2. Replace with your domain name
    3. Replace with your email address
    4. Replace with a strong password of your choice
    5. See below for more information on masquerade
    6. Replace with the URL of the website you want to masquerade as

=== "Own certificate"

    ```yaml
    # listen: :443 (1)

    tls:
      cert: your_cert.crt # (2)!
      key: your_key.key # (3)!

    auth:
      type: password
      password: Se7RAuFZ8Lzg # (4)!

    masquerade: # (5)!
      type: proxy
      proxy:
        url: https://news.ycombinator.com/ # (6)!
        rewriteHost: true
    ```

    1. The server listens on port 443 by default. Uncomment this line if you want to change the port. If only a port number is specified (without an address), as in the example, it will listen on both IPv4 and IPv6 by default. To listen on IPv4 only, you can use `0.0.0.0:443`. To listen on IPv6 only, you can use `[::]:443`.
    2. Replace with the path to your certificate file
    3. Replace with the path to your key file
    4. Replace with a strong password of your choice
    5. See below for more information on masquerade
    6. Replace with the URL of the website you want to masquerade as

### Masquerade

One of the keys to Hysteria's censorship resistance is its ability to masquerade as standard HTTP/3 traffic. This means that not only do the packets appear as HTTP/3 to middleboxes, but the server also responds to HTTP requests like a regular web server. However, this means that your server must actually serve some content to make it appear authentic to potential censors.

To accomplish this, our example uses reverse proxy mode to "steal" content from another website. Be sure to change the URL to a website you want to emulate. Hysteria also provides several other modes for serving content; please refer to the [Masquerade section of Full Server Config](../advanced/Full-Server-Config.md#masquerade) for more information.

**If censorship is not a concern, you can remove the `masquerade` section from the configuration file altogether. In this case, Hysteria will always return "404 Not Found" for all HTTP requests.**

## Running the server

**Since Hysteria listens on port 443 by default, you may need to run it with `cap_net_bind_service` capability or as root.**

The following command grants the capability to the executable:

```bash
sudo setcap cap_net_bind_service=+ep ./hysteria-linux-amd64-avx
```

Start the server by the following command:

=== "Default filename (config.yaml)"

    ```bash
    ./hysteria-linux-amd64-avx server
    ```

=== "Custom filename"

    ```bash
    ./hysteria-linux-amd64-avx server -c whatever.yaml
    ```

If you see the log message "server up and running" and no errors, congratulations 🎉! You have successfully deployed a Hysteria server.

Next, you can proceed to the [client tutorial](Client.md) to set up a client.
