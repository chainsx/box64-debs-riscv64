# box64-rv64-debs

A small GitHub Pages APT repository for Box64 packages built for Debian/Ubuntu `riscv64` systems.

This repository follows the same operating model as `box64-debs`: a scheduled GitHub Action checks the upstream Box64 repository, builds a `.deb` when the upstream commit changes, regenerates APT metadata under `debian/`, signs the repository metadata, and commits the result back to the repository.

## Package

| Package | Architecture | CMake target | Notes |
| --- | --- | --- | --- |
| `box64-rv64` | `riscv64` | `-DRV64=1 -DRV64_DYNAREC=1` | Generic RV64 Linux build with Box64 dynarec enabled. |

Box32 is disabled by default. To enable it, set `ENABLE_BOX32=1` and optionally `ENABLE_BOX32_BINFMT=1` in the build step, then test carefully on your target distribution.

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

## Local test on a riscv64 machine

```bash
sudo ./scripts/install-build-deps.sh
./scripts/build-box64-rv64.sh
./scripts/update-apt-repo.sh
sudo apt install ./debian/box64-rv64_*_riscv64.deb
box64 --version
```

## Notes

The default workflow uses QEMU via `uraimo/run-on-arch-action`, which is convenient but slow for compilation. For regular publishing, a native RISC-V runner is preferable. Use `update-box64-rv64-native.yml` after attaching a self-hosted `riscv64` runner.

Because this builds against the userspace inside the selected riscv64 container, the resulting package inherits that glibc baseline. The default workflow uses Ubuntu 22.04 to avoid requiring newer glibc than necessary for Debian/Ubuntu-family riscv64 targets.
