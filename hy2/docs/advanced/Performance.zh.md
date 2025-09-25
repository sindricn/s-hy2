# 性能优化

以下是影响传输速度的常见因素：

- 客户端与服务器之间的连接质量
- CPU、网卡等的处理能力
- 系统缓冲区大小
- 流控制接收窗口大小
- 进程优先级

> QUIC 作为一种更新、更复杂、在用户态执行的协议，自然会比成熟、高度优化的内核 TCP 实现需要更多的处理能力。如果想提高传输速度，不要运行在树莓派或极便宜的 VPS 上。

前两点超出了本文档的范围，但后三点可以通过调优来提高性能。

## 系统缓冲区大小

### Linux

```bash
# 将发送、接收两个缓冲区都设置为 16 MB
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
```

### BSD/macOS

```bash
sysctl -w kern.ipc.maxsockbuf=20971520
sysctl -w net.inet.udp.recvspace=16777216
# BSD 上不存在 UDP 发送缓冲区，因此没有 "sendspace" 可设置
```

## 流控制接收窗口大小

Hysteria 在客户端和服务器配置中都有以下 QUIC 流控制接收窗口参数：

```yaml
quic:
  initStreamReceiveWindow: 26843545 # (1)!
  maxStreamReceiveWindow: 26843545 # (2)!
  initConnReceiveWindow: 67108864 # (3)!
  maxConnReceiveWindow: 67108864 # (4)!
```

1. 每个流的初始接收窗口大小。这是在发送方必须等待接收方消耗掉数据之前可以接收的数据量。默认值是 8 MB。
2. 接收窗口大小有一个自动调节机制，该机制会根据需要增加窗口大小，但不会超过此值。默认值是 8 MB。
3. 连接的初始接收窗口大小。这是所有流的总接收窗口大小。默认值是 20 MB。
4. 接收窗口大小有一个自动调节机制，该机制会根据需要增加窗口大小，但不会超过此值。默认值是 20 MB。

可以根据你的使用情景提高或者降低这些值。**强烈建议保持接近 2/5 的流/连接接收窗口比例。** 这样可以防止一个或两个阻塞的流卡死整个连接。

## 进程优先级

在 CPU 资源紧缺的设备上， 高负载下可能会出现延迟抖动， 可通过提高进程优先级来缓解。

### 通过 systemd

适用于 Linux。

创建 `/etc/systemd/system/hysteria-server.service.d/priority.conf` 并填入以下内容。

```ini
[Service]
CPUSchedulingPolicy=rr
CPUSchedulingPriority=99
```

使用以下命令重载 systemd 配置文件并重启服务。

```bash
systemctl daemon-reload
systemctl restart hysteria-server.service
```

### 通过 chrt

适用于 Linux 和 FreeBSD。 在 FreeBSD 上需安装 `util-linux` 且最高优先级为 31 而不是 99。

```bash
# 在每次服务启动之后执行
chrt -r 99 $(pidof hysteria)

# 或者， 使用下面的命令启动服务
chrt -r 99 hysteria server -c /path/to/config.yaml
```
