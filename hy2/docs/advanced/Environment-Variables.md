# Environment Variables

The following is a (partial, but should cover most of the important ones) list of environment variables that can be used to configure Hysteria.

| Variable                      | Type    | Description                                                                                                                                                      |
| ----------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| HYSTERIA_LOG_LEVEL            | Logging | Log level (`debug`, `info` [default], `warn`, `error`)                                                                                                           |
| HYSTERIA_LOG_FORMAT           | Logging | Log format (`console` [default], `json`)                                                                                                                         |
| HYSTERIA_BRUTAL_DEBUG         | Logging | Set to `1` to print information such as current RTT, packet loss, MTU, etc. every 2 seconds. Only applies when using Brutal as the congestion control algorithm. |
| HYSTERIA_BBR_DEBUG            | Logging | Set to `1` to print BBR debug information. Only applies when using BBR as the congestion control algorithm.                                                      |
| HYSTERIA_DISABLE_UPDATE_CHECK | Update  | Set to `1` to disable version update checks.                                                                                                                     |
| HYSTERIA_ACME_DIR             | TLS     | The directory to store ACME certificates in. If specified in the config file, this value will be ignored.                                                        |
| QUIC_GO_DISABLE_GSO           | QUIC    | Set to `1` to disable GSO (Generic Segmentation Offload) in quic-go. May solve compatibility issues on some systems.                                             |
| QUIC_GO_DISABLE_ECN           | QUIC    | Set to `1` to disable ECN (Explicit Congestion Notification) in quic-go. May solve compatibility issues on some systems.                                         |
