# box64-rv64-debs

A small GitHub Pages APT repository for Box64 packages built for Debian/Ubuntu `riscv64` systems.

This repository builds `box64-rv64` by cross-compiling from a GitHub-hosted `ubuntu-22.04` x64 runner to `riscv64`. The workflow is manual-only and is triggered with `workflow_dispatch` from the GitHub Actions UI.

## Package

| Package | Architecture | CMake target | Notes |
| --- | --- | --- | --- |
| `box64-rv64` | `riscv64` | `-DRV64=1 -DRV64_DYNAREC=ON` | Generic RV64 Linux build with Box64 dynarec enabled. |

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
sudo apt install box64
```

## Local cross build on an x86_64 Debian/Ubuntu machine

```bash
sudo ./scripts/install-build-deps.sh
./scripts/build-box64-rv64.sh
./scripts/update-apt-repo.sh
```

The generated package will be placed under `debian/`:

```text
debian/box64*_riscv64.deb
```
