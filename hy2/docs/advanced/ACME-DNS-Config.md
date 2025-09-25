# ACME DNS Config

ACME DNS can obtain certificates through the DNS service provider API. This function does not rely on specific ports (does not occupy 80/443) and external access.

## Service Provider Support

Currently, ACME DNS configuration supports only a few popular DNS service providers, and a sample configuration for these service providers is as follows.

> Note: The following documentation only lists the configuration options for each DNS service provider. Due to limited development resources, the values that should be filled in for the configuration options need to be researched by the user, and we have only tested the Cloudflare configuration.

### Cloudflare

```yaml
acme:
  domains:
    - "*.example.com"
  email: your@email.address
  type: dns
  dns:
    name: cloudflare
    config:
      cloudflare_api_token: Dxabckw9dB_jYBdi89kgyaS8wRjqqSsd679urScKOBP
```

### Duck DNS

```yaml
acme:
  domains:
    - "*.example.com"
  email: your@email.address
  type: dns
  dns:
    name: duckdns
    config:
      duckdns_api_token: Dxabckw9dB_jYBdi89kgyaS8wRjqqSsd679urScKOBP
      duckdns_override_domain: abc.example.com
```

### Gandi.net

```yaml
acme:
  domains:
    - "*.example.com"
  email: your@email.address
  type: dns
  dns:
    name: gandi
    config:
      gandi_api_token: Dxabckw9dB_jYBdi89kgyaS8wRjqqSsd679urScKOBP
```

### Godaddy

```yaml
acme:
  domains:
    - "*.example.com"
  email: your@email.address
  type: dns
  dns:
    name: godaddy
    config:
      godaddy_api_token: Dxabckw9dB_jYBdi89kgyaS8wRjqqSsd679urScKOBP
```

### Name.com

```yaml
acme:
  domains:
    - "*.example.com"
  email: your@email.address
  type: dns
  dns:
    name: namedotcom
    config:
      namedotcom_token: Dxabckw9dB_jYBdi89kgyaS8wRjqqSsd679urScKOBP
      namedotcom_user: user
      namedotcom_server: api.name.com
```

### Vultr

```yaml
acme:
  domains:
    - "*.example.com"
  email: your@email.address
  type: dns
  dns:
    name: vultr
    config:
      vultr_api_token: Dxabckw9dB_jYBdi89kgyaS8wRjqqSsd679urScKOBP
```

## Handling Multiple Domains

Currently ACME DNS is configured to work for all domains in `domains`, i.e. **if you are using ACME DNS to apply for a certificate, please ensure that all domains in `domains` are using the same domain name service provider.**

## Unsupported Providers

If you are using a DNS provider that is not currently supported, you can still point your domain's DNS management servers to a supported provider, such as Cloudflare; this means: **you can purchase a domain name from Provider A and manage it through Provider B, and still use ACME DNS functionality.**
