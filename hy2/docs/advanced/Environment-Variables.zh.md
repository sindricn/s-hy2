# 环境变量

以下是 Hysteria 支持的环境变量列表（不完整，但应该涵盖大部分重要的）。

| 变量                          | 类型 | 描述                                                                                                     |
| ----------------------------- | ---- | -------------------------------------------------------------------------------------------------------- |
| HYSTERIA_LOG_LEVEL            | 日志 | 日志级别（`debug`, `info` [默认], `warn`, `error`）                                                      |
| HYSTERIA_LOG_FORMAT           | 日志 | 日志格式（`console` [默认], `json`）                                                                     |
| HYSTERIA_BRUTAL_DEBUG         | 日志 | 设置为 `1` 可以每 2 秒打印当前网络信息，如 RTT、丢包率、MTU 等。仅在使用 Brutal 作为拥塞控制算法时适用。 |
| HYSTERIA_BBR_DEBUG            | 日志 | 设置为 `1` 可以输出 BBR 调试信息。仅在使用 BBR 作为拥塞控制算法时适用。                                  |
| HYSTERIA_DISABLE_UPDATE_CHECK | 更新 | 设置为 `1` 以禁用版本更新检查。                                                                          |
| HYSTERIA_ACME_DIR             | TLS  | 用于存储 ACME 证书的目录。如果在配置文件中指定，此值将被忽略。                                           |
| QUIC_GO_DISABLE_GSO           | QUIC | 设置为 `1` 以在 quic-go 中禁用 GSO。可能解决某些系统上的兼容性问题。                                     |
| QUIC_GO_DISABLE_ECN           | QUIC | 设置为 `1` 以在 quic-go 中禁用 ECN。可能解决某些系统上的兼容性问题。                                     |
