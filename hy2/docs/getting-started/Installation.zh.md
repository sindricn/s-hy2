# 安装

像其他代理软件一样，Hysteria 由服务端和客户端组成。我们的可执行文件在所有平台上都包括这两种模式。**可以通过以下几种方式之一获取最新版本：**

- [下载可执行文件](#_2)
- [GitHub Releases](https://github.com/apernet/hysteria/releases)
- [Linux 服务端部署脚本](#linux)
- [Arch Linux AUR](https://aur.archlinux.org/packages/hysteria)
- [Docker 镜像](#docker)
- 使用 [第三方应用](3rd-party-apps.md)
- [自行从源码编译](../developers/Build.md)

## 下载可执行文件

> 点击文件名下载，版本为目前最新版本。

=== ":fontawesome-brands-windows: Windows"

    | 文件                                                                                                          | 架构   | 注意            |
    | ------------------------------------------------------------------------------------------------------------- | ------ | --------------- |
    | [hysteria-windows-amd64.exe](https://download.hysteria.network/app/latest/hysteria-windows-amd64.exe)         | x86-64 |                 |
    | [hysteria-windows-amd64-avx.exe](https://download.hysteria.network/app/latest/hysteria-windows-amd64-avx.exe) | x86-64 | 需要 AVX 指令集 |
    | [hysteria-windows-386.exe](https://download.hysteria.network/app/latest/hysteria-windows-386.exe)             | x86    |                 |
    | [hysteria-windows-arm64.exe](https://download.hysteria.network/app/latest/hysteria-windows-arm64.exe)         | ARM64  |                 |

=== ":fontawesome-brands-apple: macOS"

    | 文件                                                                                                | 架构   | 注意            |
    | --------------------------------------------------------------------------------------------------- | ------ | --------------- |
    | [hysteria-darwin-amd64](https://download.hysteria.network/app/latest/hysteria-darwin-amd64)         | x86-64 |                 |
    | [hysteria-darwin-amd64-avx](https://download.hysteria.network/app/latest/hysteria-darwin-amd64-avx) | x86-64 | 需要 AVX 指令集 |
    | [hysteria-darwin-arm64](https://download.hysteria.network/app/latest/hysteria-darwin-arm64)         | ARM64  | M1 或更新       |

=== ":fontawesome-brands-linux: Linux"

    | 文件                                                                                              | 架构   | 注意                   |
    | ------------------------------------------------------------------------------------------------- | ------ | ---------------------- |
    | [hysteria-linux-amd64](https://download.hysteria.network/app/latest/hysteria-linux-amd64)         | x86-64 |                        |
    | [hysteria-linux-amd64-avx](https://download.hysteria.network/app/latest/hysteria-linux-amd64-avx) | x86-64 | 需要 AVX 指令集        |
    | [hysteria-linux-386](https://download.hysteria.network/app/latest/hysteria-linux-386)             | x86    |                        |
    | [hysteria-linux-arm](https://download.hysteria.network/app/latest/hysteria-linux-arm)             | ARMv7  |                        |
    | [hysteria-linux-armv5](https://download.hysteria.network/app/latest/hysteria-linux-armv5)         | ARMv5  |                        |
    | [hysteria-linux-arm64](https://download.hysteria.network/app/latest/hysteria-linux-arm64)         | ARM64  |                        |
    | [hysteria-linux-s390x](https://download.hysteria.network/app/latest/hysteria-linux-s390x)         | s390x  |                        |
    | [hysteria-linux-mipsle](https://download.hysteria.network/app/latest/hysteria-linux-mipsle)       | MIPS   | 小端序                 |
    | [hysteria-linux-mipsle-sf](https://download.hysteria.network/app/latest/hysteria-linux-mipsle-sf) | MIPS   | 小端序，无硬件浮点支持 |
    | [hysteria-linux-riscv64](https://download.hysteria.network/app/latest/hysteria-linux-riscv64)     | RISC-V 64 |                        |

=== ":fontawesome-brands-android: Android"

    > **注意：** 这里的文件并不是可以直接安装的 Android app (APK) 而是 NDK 编译的 Linux ELF 可执行文件。如果你不知道如何使用，请使用 [第三方应用](3rd-party-apps.md)。

    | 文件                                                                                          | 架构   | 注意 |
    | --------------------------------------------------------------------------------------------- | ------ | ---- |
    | [hysteria-android-amd64](https://download.hysteria.network/app/latest/hysteria-android-amd64) | x86-64 |      |
    | [hysteria-android-386](https://download.hysteria.network/app/latest/hysteria-android-386)     | x86    |      |
    | [hysteria-android-armv7](https://download.hysteria.network/app/latest/hysteria-android-armv7) | ARMv7  |      |
    | [hysteria-android-arm64](https://download.hysteria.network/app/latest/hysteria-android-arm64) | ARM64  |      |

=== ":fontawesome-brands-freebsd: FreeBSD"

    | 文件                                                                                                  | 架构   | 注意            |
    | ----------------------------------------------------------------------------------------------------- | ------ | --------------- |
    | [hysteria-freebsd-amd64](https://download.hysteria.network/app/latest/hysteria-freebsd-amd64)         | x86-64 |                 |
    | [hysteria-freebsd-amd64-avx](https://download.hysteria.network/app/latest/hysteria-freebsd-amd64-avx) | x86-64 | 需要 AVX 指令集 |
    | [hysteria-freebsd-386](https://download.hysteria.network/app/latest/hysteria-freebsd-386)             | x86    |                 |
    | [hysteria-freebsd-arm](https://download.hysteria.network/app/latest/hysteria-freebsd-arm)             | ARMv7  |                 |
    | [hysteria-freebsd-arm64](https://download.hysteria.network/app/latest/hysteria-freebsd-arm64)         | ARM64  |                 |

## Linux 服务端部署脚本

我们提供了一个 bash 脚本，可以在常见的 Linux 发行版上自动下载最新版本的 Hysteria 并配置 systemd 服务：

```bash
bash <(curl -fsSL https://get.hy2.sh/)
```

关于此脚本的更多帮助， 请参阅 [服务端安装脚本](./Server-Installation-Script.md)。

## Docker 镜像

Docker Hub: <https://hub.docker.com/r/tobyxdd/hysteria>

### Compose 示例

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
