# 如何构建 Hysteria

Hysteria 使用一个基于 Python 的自定义构建系统，名为 "Hyperbole"。要使用 Hyperbole，需要安装以下依赖：

- Python 3
- Go 工具链
- Git

假设你已经 clone 了 Hysteria 的仓库。转到代码根目录，运行以下其中一个命令：

```bash
python hyperbole.py build # (1)!
# 或者
python hyperbole.py build -r # (2)!
# 或者
python hyperbole.py build -p # (3)!
```

1. 为当前的平台构建调试版本。
2. 为当前的平台构建发布版本。
3. 为当前的平台构建带有 pprof 支持的调试版本。

要为其他平台构建，使用 `HY_APP_PLATFORMS` 环境变量：

```bash
export HY_APP_PLATFORMS="linux/amd64,windows/amd64,darwin/amd64"
```

> **注意：** Hyperbole 是一个内部工具，可能会经常更改。请阅读代码以了解所有可用选项和其他信息。

## 对于贡献者

在提交代码前，请确保安装了 `gofumpt`，然后运行以下命令：

```bash
python hyperbole.py format
python hyperbole.py tidy
```

如果更改了任何 mock 的 interface，请安装 `mockery` 并在提交前运行以下命令更新 mock：

```bash
python hyperbole.py mockgen
```

提交之前，请确保运行了修改了的模块的测试：

```bash
python hyperbole.py test # (1)
# 或者
python hyperbole.py test core # (2)
```

1. 运行所有测试。
2. 只运行 `core` 的测试。

> **注意：** 某些测试也需要 Python 3，以及一些第三方包。如果遇到错误，请安装它们再试一次。
