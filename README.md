# box64-rv64-debs

A small GitHub Pages APT repository for Box64 packages built for Debian/Ubuntu `riscv64` systems.

This repository builds Box64 packages by cross-compiling from a GitHub-hosted `ubuntu-22.04` x64 runner to `riscv64`. The workflow is manual-only and is triggered with `workflow_dispatch` from the GitHub Actions UI.

## Package

| Package | Architecture | CMake target | Notes |
| --- | --- | --- | --- |
| `box64` | `riscv64` | `-DRV64=1 -DRV64_DYNAREC=ON` | Generic RV64GC Linux build with Box64 dynarec enabled. |
| `box64-rv64gcv` | `riscv64` | `-DRV64=1 -DRV64_DYNAREC=ON`, `-march=rv64gcv` | RVV/RV64GCV build for systems whose CPU, kernel and userspace support the RISC-V Vector extension. It installs the same `/usr/bin/box64` binary path and therefore conflicts with `box64`. |

`box64-rv64gcv` is not a new Debian architecture; it is still a `riscv64` package. APT will not automatically verify whether the target CPU supports RVV, so install it only on RVV-capable hardware such as SpacemiT K3-class systems.

## User installation

Replace placeholders in `box64-rv64.sources.in`, or create the file directly on the target machine:

```bash
sudo mkdir -p /usr/share/keyrings

wget -qO- https://chainsx.github.io/box64-debs-riscv64/KEY.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/box64-rv64-archive-keyring.gpg

sudo tee /etc/apt/sources.list.d/box64-rv64.sources >/dev/null <<'APT'
Types: deb
URIs: https://chainsx.github.io/box64-debs-riscv64/debian
Suites: ./
Architectures: riscv64
Signed-By: /usr/share/keyrings/box64-rv64-archive-keyring.gpg
APT

sudo apt update
```

Install the generic RV64GC build:

```bash
sudo apt install box64
```

Or install the RVV/RV64GCV build:

```bash
sudo apt install box64-rv64gcv
```

## Local cross build on an x86_64 Debian/Ubuntu machine

```bash
sudo ./scripts/install-build-deps.sh
BUILD_PACKAGES=all ./scripts/build-box64-rv64.sh
./scripts/update-apt-repo.sh
```

Build only one package when needed:

```bash
BUILD_PACKAGES=box64 ./scripts/build-box64-rv64.sh
BUILD_PACKAGES=box64-rv64gcv ./scripts/build-box64-rv64.sh
```

The generated packages will be placed under `debian/`:

```text
debian/box64_*_riscv64.deb
debian/box64-rv64gcv_*_riscv64.deb
```
