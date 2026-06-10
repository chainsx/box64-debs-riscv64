# box64-rv64-debs

A small GitHub Pages APT repository for Box64 packages built for Debian/Ubuntu `riscv64` systems.

This repository builds `box64-rv64` by cross-compiling from a GitHub-hosted `ubuntu-22.04` x64 runner to `riscv64`. The workflow is manual-only and is triggered with `workflow_dispatch` from the GitHub Actions UI.

## Package

| Package | Architecture | CMake target | Notes |
| --- | --- | --- | --- |
| `box64-rv64` | `riscv64` | `-DRV64=1 -DRV64_DYNAREC=ON` | Generic RV64 Linux build with Box64 dynarec enabled. |

Box32 is disabled by default. To enable it, set `ENABLE_BOX32=1` and optionally `ENABLE_BOX32_BINFMT=1` in the build step, then test carefully on your target distribution.

## GitHub Actions build mode

The default workflow is `.github/workflows/update-box64-rv64.yml`.

It uses:

- `runs-on: ubuntu-22.04`
- `gcc-riscv64-linux-gnu`
- `g++-riscv64-linux-gnu`
- `libc6-dev-riscv64-cross`
- CMake cross options for `riscv64`

It does not use `uraimo/run-on-arch-action`, does not start a QEMU riscv64 container, and does not run the built binary through QEMU.

## User installation

Replace placeholders in `box64-rv64.sources.in`, or create the file directly on the target machine:

```bash
sudo mkdir -p /usr/share/keyrings

wget -qO- https://<GITHUB_USER_OR_ORG>.github.io/<REPO_NAME>/KEY.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/box64-rv64-archive-keyring.gpg

sudo tee /etc/apt/sources.list.d/box64-rv64.sources >/dev/null <<'APT'
Types: deb
URIs: https://<GITHUB_USER_OR_ORG>.github.io/<REPO_NAME>/debian
Suites: ./
Architectures: riscv64
Signed-By: /usr/share/keyrings/box64-rv64-archive-keyring.gpg
APT

sudo apt update
sudo apt install box64-rv64
```

## Manual build from GitHub Actions

Open:

```text
Actions -> Build Box64 RV64 deb repository -> Run workflow
```

Optional inputs:

- `force_rebuild`: rebuild even if upstream Box64 commit has not changed.
- `box64_branch`: upstream Box64 branch or tag. Default is `main`.

## Local cross build on an x86_64 Debian/Ubuntu machine

```bash
sudo ./scripts/install-build-deps.sh
./scripts/build-box64-rv64.sh
./scripts/update-apt-repo.sh
```

The generated package will be placed under `debian/`:

```text
debian/box64-rv64_*_riscv64.deb
```

## Notes

The workflow intentionally uses Ubuntu 22.04 as the build host to avoid linking against a newer glibc baseline than necessary. If your target RISC-V distribution has an older glibc than Ubuntu 22.04, use a matching older sysroot or build on that distribution instead.
