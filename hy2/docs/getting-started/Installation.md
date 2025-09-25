# Installation

Like any proxy software, Hysteria consists of a server and a client. Our precompiled executables includes both modes on all platforms. **You can download our latest releases using one of the following options:**

- [Executable files](#executable-files)
- [GitHub Releases](https://github.com/apernet/hysteria/releases)
- [Deployment script for Linux servers](#deployment-script-for-linux-servers)
- [Arch Linux AUR](https://aur.archlinux.org/packages/hysteria)
- [Docker images](#docker-images)
- Use [3rd-party apps](3rd-party-apps.md)
- [Build from source](../developers/Build.md)

## Executable files

> Click on the filename to download. All files are the latest version.

=== ":fontawesome-brands-windows: Windows"

    | File                                                                                                          | Arch   | Note         |
    | ------------------------------------------------------------------------------------------------------------- | ------ | ------------ |
    | [hysteria-windows-amd64.exe](https://download.hysteria.network/app/latest/hysteria-windows-amd64.exe)         | x86-64 |              |
    | [hysteria-windows-amd64-avx.exe](https://download.hysteria.network/app/latest/hysteria-windows-amd64-avx.exe) | x86-64 | Requires AVX |
    | [hysteria-windows-386.exe](https://download.hysteria.network/app/latest/hysteria-windows-386.exe)             | x86    |              |
    | [hysteria-windows-arm64.exe](https://download.hysteria.network/app/latest/hysteria-windows-arm64.exe)         | ARM64  |              |

=== ":fontawesome-brands-apple: macOS"

    | File                                                                                                  | Arch   | Note         |
    | ----------------------------------------------------------------------------------------------------- | ------ | ------------ |
    | [hysteria-darwin-amd64](https://download.hysteria.network/app/latest/hysteria-darwin-amd64)           | x86-64 |              |
    | [hysteria-darwin-amd64-avx](https://download.hysteria.network/app/latest/hysteria-darwin-amd64-avx)   | x86-64 | Requires AVX |
    | [hysteria-darwin-arm64](https://download.hysteria.network/app/latest/hysteria-darwin-arm64)           | ARM64  | M1 or newer  |

=== ":fontawesome-brands-linux: Linux"

    | File                                                                                              | Arch   | Note         |
    | ------------------------------------------------------------------------------------------------- | ------ | ------------ |
    | [hysteria-linux-amd64](https://download.hysteria.network/app/latest/hysteria-linux-amd64)         | x86-64 |              |
    | [hysteria-linux-amd64-avx](https://download.hysteria.network/app/latest/hysteria-linux-amd64-avx) | x86-64 | Requires AVX |
    | [hysteria-linux-386](https://download.hysteria.network/app/latest/hysteria-linux-386)             | x86    |              |
    | [hysteria-linux-arm](https://download.hysteria.network/app/latest/hysteria-linux-arm)             | ARMv7  |              |
    | [hysteria-linux-armv5](https://download.hysteria.network/app/latest/hysteria-linux-armv5)         | ARMv5  |              |
    | [hysteria-linux-arm64](https://download.hysteria.network/app/latest/hysteria-linux-arm64)         | ARM64  |              |
    | [hysteria-linux-s390x](https://download.hysteria.network/app/latest/hysteria-linux-s390x)         | s390x  |              |
    | [hysteria-linux-mipsle](https://download.hysteria.network/app/latest/hysteria-linux-mipsle)       | MIPS   | Little Endian |
    | [hysteria-linux-mipsle-sf](https://download.hysteria.network/app/latest/hysteria-linux-mipsle-sf) | MIPS   | Little Endian, Soft Float |
    | [hysteria-linux-riscv64](https://download.hysteria.network/app/latest/hysteria-linux-riscv64)     | RISC-V 64 |              |

=== ":fontawesome-brands-android: Android"

    > **Note:** These files are not Android app (APK) but Linux ELF executables built with NDK. If you don't know how to use them, please use [3rd-party apps](3rd-party-apps.md) instead.

    | File                                                                                                    | Arch   | Note         |
    | ------------------------------------------------------------------------------------------------------- | ------ | ------------ |
    | [hysteria-android-amd64](https://download.hysteria.network/app/latest/hysteria-android-amd64)           | x86-64 |              |
    | [hysteria-android-386](https://download.hysteria.network/app/latest/hysteria-android-386)               | x86    |              |
    | [hysteria-android-armv7](https://download.hysteria.network/app/latest/hysteria-android-armv7)           | ARMv7  |              |
    | [hysteria-android-arm64](https://download.hysteria.network/app/latest/hysteria-android-arm64)           | ARM64  |              |

=== ":fontawesome-brands-freebsd: FreeBSD"

    | File                                                                                                    | Arch   | Note         |
    | ------------------------------------------------------------------------------------------------------- | ------ | ------------ |
    | [hysteria-freebsd-amd64](https://download.hysteria.network/app/latest/hysteria-freebsd-amd64)           | x86-64 |              |
    | [hysteria-freebsd-amd64-avx](https://download.hysteria.network/app/latest/hysteria-freebsd-amd64-avx)   | x86-64 | Requires AVX |
    | [hysteria-freebsd-386](https://download.hysteria.network/app/latest/hysteria-freebsd-386)               | x86    |              |
    | [hysteria-freebsd-arm](https://download.hysteria.network/app/latest/hysteria-freebsd-arm)               | ARMv7  |              |
    | [hysteria-freebsd-arm64](https://download.hysteria.network/app/latest/hysteria-freebsd-arm64)           | ARM64  |              |

## Deployment script for Linux servers

We provide a bash script that automatically downloads the latest version of Hysteria and configures a systemd service on common Linux distributions.

```bash
bash <(curl -fsSL https://get.hy2.sh/)
```

For more help on this script, see [Server Installation Script](./Server-Installation-Script.md).

## Docker images

Docker Hub: <https://hub.docker.com/r/tobyxdd/hysteria>

### Compose example

```yaml
version: "3.9"
services:
  hysteria:
    image: tobyxdd/hysteria
    container_name: hysteria
    restart: always
    network_mode: "host"
    volumes:
      - acme:/acme
      - ./hysteria.yaml:/etc/hysteria.yaml
    command: ["server", "-c", "/etc/hysteria.yaml"]
volumes:
  acme:
```
