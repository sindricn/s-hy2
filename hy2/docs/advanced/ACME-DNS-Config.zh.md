# ACME DNS 配置

ACME DNS 可以实现通过 DNS 服务商 API 来获取证书, 该功能不依赖特定端口 (不占用 80/443) 和外部访问。

## 服务商支持

目前 ACME DNS 配置仅支持几个流行的 DNS 服务商, 这些服务商配置样例如下:

> 注意: 以下文档仅列出每个 DNS 服务商的配置选项, 由于开发资源有限, 配置选项应填写的值需要用户自行查找, 我们仅测试了 Cloudflare 配置.

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

## 域名匹配

目前 ACME DNS 配置针对 `domains` 内所有域名生效, 也就是说 **如果使用 ACME DNS 申请证书, 请保证 `domains` 内所有域名都使用同一个域名服务商.**

## 未支持的服务商

如果您正在使用当前尚未支持的 DNS 服务商, 您仍然可以将域名的 DNS 管理服务器指向已支持的服务商, 例如 Cloudflare; 这意味着: **您可以在 A 服务商购买域名并通过 B 服务商管理, 这样就仍然可以使用 ACME DNS 功能.**
