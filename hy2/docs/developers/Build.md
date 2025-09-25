# How to build Hysteria

Hysteria has its own Python-based build system called "Hyperbole". To use Hyperbole, you will need the following requirements:

- Python 3
- Go toolchain
- Git

Assume that you have cloned the Hysteria repository. Go to the repository's root directory and run one of the following commands:

```bash
python hyperbole.py build # (1)!
# or
python hyperbole.py build -r # (2)!
# or
python hyperbole.py build -p # (3)!
```

1. This will build the debug version for your current platform.
2. This will build the release version for your current platform.
3. This will build the debug version with pprof support for your current platform.

To build for other platforms, use the `HY_APP_PLATFORMS` environment variable:

```bash
export HY_APP_PLATFORMS="linux/amd64,windows/amd64,darwin/amd64"
```

> **NOTE:** Hyperbole is an internal tool and may change frequently. Read the source code for all available options and other information.

## For contributors

Make sure you have `gofumpt` installed and run the following commands before committing:

```bash
python hyperbole.py format
python hyperbole.py tidy
```

If you changed any interface that has a mock, install `mockery` and run the following command before committing:

```bash
python hyperbole.py mockgen
```

You should also at least test the modules you've changed:

```bash
python hyperbole.py test # (1)!
# or
python hyperbole.py test core # (2)!
```

1. This will run all tests.
2. This will run tests for the `core` module only.

> **NOTE:** Some tests also require Python 3 and even some third-party packages. If you encounter errors, install them and try again.
