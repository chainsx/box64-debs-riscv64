#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
BOX64_BRANCH="v0.4.2"
FORCE_REBUILD="${FORCE_REBUILD:-false}"
PKG_MAINTAINER="${PKG_MAINTAINER:-Box64 RV64 Maintainer <noreply@example.com>}"

mkdir -p "$ROOT/work"
mkdir -p "$ROOT/debian"

rm -rf "$ROOT/work/box64" "$ROOT/work/build" "$ROOT/work/pkgroot"

git clone --depth=1 --branch "$BOX64_BRANCH" https://github.com/ptitSeb/box64.git "$ROOT/work/box64"

UPSTREAM_COMMIT="$(git -C "$ROOT/work/box64" rev-parse HEAD)"
OLD_COMMIT=""

if [[ -f "$ROOT/commit.txt" ]]; then
  OLD_COMMIT="$(cat "$ROOT/commit.txt")"
fi

if [[ "$FORCE_REBUILD" != "true" && "$UPSTREAM_COMMIT" == "$OLD_COMMIT" ]]; then
  echo "Upstream Box64 commit has not changed: $UPSTREAM_COMMIT"
  touch "$ROOT/exited_successfully.txt"
  exit 0
fi

RISCV_CC="$(command -v riscv64-linux-gnu-gcc)"
RISCV_CXX="$(command -v riscv64-linux-gnu-g++)"
RISCV_AR="$(command -v riscv64-linux-gnu-ar)"
RISCV_RANLIB="$(command -v riscv64-linux-gnu-ranlib)"
RISCV_STRIP="$(command -v riscv64-linux-gnu-strip)"
RISCV_NM="$(command -v riscv64-linux-gnu-nm)"
RISCV_OBJCOPY="$(command -v riscv64-linux-gnu-objcopy)"
RISCV_OBJDUMP="$(command -v riscv64-linux-gnu-objdump)"

echo "Using RISC-V cross toolchain:"
echo "CC      = $RISCV_CC"
echo "CXX     = $RISCV_CXX"
echo "AR      = $RISCV_AR"
echo "RANLIB  = $RISCV_RANLIB"
echo "STRIP   = $RISCV_STRIP"

cmake -S "$ROOT/work/box64" -B "$ROOT/work/build" \
  -G Ninja \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
  -DCMAKE_C_COMPILER="$RISCV_CC" \
  -DCMAKE_CXX_COMPILER="$RISCV_CXX" \
  -DCMAKE_AR="$RISCV_AR" \
  -DCMAKE_RANLIB="$RISCV_RANLIB" \
  -DCMAKE_STRIP="$RISCV_STRIP" \
  -DCMAKE_NM="$RISCV_NM" \
  -DCMAKE_OBJCOPY="$RISCV_OBJCOPY" \
  -DCMAKE_OBJDUMP="$RISCV_OBJDUMP" \
  -DCMAKE_FIND_ROOT_PATH=/usr/riscv64-linux-gnu \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DRV64=1 \
  -DRV64_DYNAREC=ON

cmake --build "$ROOT/work/build" --parallel "$(nproc)"

PKG_VERSION="${BOX64_BRANCH}.$(date -u +%Y%m%d).${UPSTREAM_COMMIT:0:8}"
PKG_NAME="box64"
PKG_DIR="$ROOT/work/pkgroot"
DEB_FILE="$ROOT/debian/${PKG_NAME}_${PKG_VERSION}_riscv64.deb"

DESTDIR="$PKG_DIR" cmake --install "$ROOT/work/build"

mkdir -p "$PKG_DIR/DEBIAN"

cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Section: utils
Priority: optional
Architecture: riscv64
Maintainer: $PKG_MAINTAINER
Depends: libc6
Description: Box64 x86_64 userspace emulator for RISC-V 64
 Box64 lets you run x86_64 Linux programs on non-x86_64 Linux systems.
 This package is cross-compiled for riscv64 with RV64 dynarec enabled.
EOF

chmod -R go-w "$PKG_DIR"

dpkg-deb --root-owner-group --build "$PKG_DIR" "$DEB_FILE"

echo "$UPSTREAM_COMMIT" > "$ROOT/commit.txt"

echo "Built package:"
ls -lh "$DEB_FILE"
