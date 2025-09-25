# Server Installation Script

We provide a bash script that can maintain (install, upgrade, uninstall) Hysteria and its systemd service on common Linux distributions.

> **Note:** This official script aims to achieve effects similar to package managers and will only generate example configuration files.
> Manual [server configuration](./Server.md) is still required to start the service properly.
>
> If you need a "foolproof" script that can effortlessly install, configure, and start the Hysteria server, please search for third-party "Hysteria 2 scripts" via search engines.

## Environment Requirements

Hysteria itself has no specific requirements related to Linux distributions,
but the script is designed to run on systems that meet the following conditions:

- Services are managed based on systemd (via the `systemctl` command)
- The following programs are installed and NOT provided through busybox.
  - [GNU Coreutils tools](https://en.wikipedia.org/wiki/GNU_Core_Utilities)
  - `bash`
  - `grep`
  - `curl`

For new VPS users, please use stable versions of mainstream distributions released within the last 2 years. **Avoid using CentOS 7**.

If you are unfamiliar with Linux distributions, we recommend the following options:

- Debian 11 or higher
- Ubuntu 22.04 LTS or higher LTS versions
- Rocky Linux 8 or higher
- CentOS Stream 8 or higher
- Fedora 37 or higher

**Unsupported** distributions:

- OpenWrt
- Alpine Linux
- NixOS

## Common Operations

### Install or Upgrade

Install or upgrade to the latest version.

```sh
bash <(curl -fsSL https://get.hy2.sh/)
```

Install or upgrade to a specified version.

```sh
bash <(curl -fsSL https://get.hy2.sh/) --version v2.6.3
```

### Uninstall

Remove Hysteria and its service.

```sh
bash <(curl -fsSL https://get.hy2.sh/) --remove
```

## Advanced

### Install from Local File

If your VPS cannot connect to GitHub Release, you can manually transfer the Hysteria executable file to the VPS for installation.

```sh
bash <(curl -fsSL https://get.hy2.sh/) --local /path/to/hysteria-linux-amd64
```

### Specify Architecture

Mainly for installing the AVX version.

```sh
ARCHITECTURE=amd64-avx bash <(curl -fsSL https://get.hy2.sh/)
```

### Specify User

If you want to avoid handling permission issues (usually due to using other programs to generate and manage certificates),
you can configure Hysteria's systemd service to run as root with the following command.

```sh
HYSTERIA_USER=root bash <(curl -fsSL https://get.hy2.sh/)
```

To reset this setting, you can remove Hysteria and reinstall it, or you can execute the following command.

```sh
HYSTERIA_USER=hysteria bash <(curl -fsSL https://get.hy2.sh/)
```

## Miscellaneous

### Edit Configuration File

```sh
nano /etc/hysteria/config.yaml
```

### Service Management

Enable the service at startup and start it immediately.

```sh
systemctl enable --now hysteria-server.service
```

Restart the service, usually after modifying the configuration file.

```sh
systemctl restart hysteria-server.service
```

Check the service status.

```sh
systemctl status hysteria-server.service
```

### Logs

View server logs.

```sh
journalctl --no-pager -e -u hysteria-server.service
```
