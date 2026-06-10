#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export DEBIAN_FRONTEND=noninteractive

: "${BOX64_REPO:=https://github.com/ptitSeb/box64.git}"
: "${BOX64_BRANCH:=main}"
: "${PKG_NAME:=box64-rv64}"
: "${PKG_MAINTAINER:=Box64 RV64 Maintainer <noreply@example.com>}"
: "${KEEP_BUILDS:=4}"
: "${ENABLE_BOX32:=0}"
: "${ENABLE_BOX32_BINFMT:=0}"
: "${FORCE_REBUILD:=0}"
: "${DEB_DEPENDS:=libc6 (>= 2.35), libgcc-s1}"

is_true() {
  case "${1,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

mkdir -p "$ROOT/debian" "$ROOT/work"
rm -f "$ROOT/exited_successfully.txt"

LAST_COMMIT="$(cat "$ROOT/commit.txt" 2>/dev/null || true)"

rm -rf "$ROOT/work/box64" "$ROOT/work/pkgroot" "$ROOT/work/build"
git clone --depth=1 --branch "$BOX64_BRANCH" "$BOX64_REPO" "$ROOT/work/box64"

cd "$ROOT/work/box64"
COMMIT="$(git rev-parse --short=7 HEAD)"

if [[ "$COMMIT" == "$LAST_COMMIT" ]] && ! is_true "$FORCE_REBUILD"; then
  echo "Box64 is already up to date at $COMMIT."
  touch "$ROOT/exited_successfully.txt"
  exit 0
fi

MAJOR="$(awk '/#define BOX64_MAJOR/{print $3}' src/box64version.h)"
MINOR="$(awk '/#define BOX64_MINOR/{print $3}' src/box64version.h)"
REVISION="$(awk '/#define BOX64_REVISION/{print $3}' src/box64version.h)"
BOX64_VERSION="${MAJOR}.${MINOR}.${REVISION}"
DEB_VERSION="${BOX64_VERSION}+$(date -u +%Y%m%d).${COMMIT}"

if is_true "$FORCE_REBUILD"; then
  echo "Force rebuild requested."
fi

echo "Building ${PKG_NAME} ${DEB_VERSION} for riscv64 by cross compilation"

cmake_opts=(
  -G Ninja
  -DCMAKE_SYSTEM_NAME=Linux
  -DCMAKE_SYSTEM_PROCESSOR=riscv64
  -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc
  -DCMAKE_CXX_COMPILER=riscv64-linux-gnu-g++
  -DCMAKE_AR=riscv64-linux-gnu-ar
  -DCMAKE_RANLIB=riscv64-linux-gnu-ranlib
  -DCMAKE_STRIP=riscv64-linux-gnu-strip
  -DCMAKE_FIND_ROOT_PATH=/usr/riscv64-linux-gnu
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
  -DCMAKE_INSTALL_PREFIX=/usr
  -DRV64=1
  -DRV64_DYNAREC=ON
)

if is_true "$ENABLE_BOX32"; then
  cmake_opts+=( -DBOX32=ON )
fi

if is_true "$ENABLE_BOX32_BINFMT"; then
  cmake_opts+=( -DBOX32_BINFMT=ON )
fi

cmake -S "$ROOT/work/box64" -B "$ROOT/work/build" "${cmake_opts[@]}"
cmake --build "$ROOT/work/build" --parallel "$(nproc)"

PKGROOT="$ROOT/work/pkgroot"
rm -rf "$PKGROOT"
DESTDIR="$PKGROOT" cmake --install "$ROOT/work/build"

install -d "$PKGROOT/DEBIAN" "$PKGROOT/usr/share/doc/$PKG_NAME"
cp "$ROOT/work/box64/README.md" "$PKGROOT/usr/share/doc/$PKG_NAME/README.md" || true
cp "$ROOT/work/box64/LICENSE" "$PKGROOT/usr/share/doc/$PKG_NAME/copyright" || true

if [[ -f "$ROOT/work/box64/docs/CHANGELOG.md" ]]; then
  cp "$ROOT/work/box64/docs/CHANGELOG.md" "$PKGROOT/usr/share/doc/$PKG_NAME/changelog.md"
  gzip -9 -n -f "$PKGROOT/usr/share/doc/$PKG_NAME/changelog.md"
fi

BOX64_BIN="$(find "$PKGROOT" -type f -name box64 | head -n1 || true)"
if [[ -z "$BOX64_BIN" ]]; then
  echo "ERROR: box64 binary not found after install" >&2
  find "$PKGROOT" -maxdepth 5 -type f >&2 || true
  exit 1
fi

if ! file "$BOX64_BIN" | grep -qi 'risc-v'; then
  echo "ERROR: built box64 is not a RISC-V ELF binary:" >&2
  file "$BOX64_BIN" >&2
  exit 1
fi

INSTALLED_SIZE="$(du -ks "$PKGROOT" | awk '{print $1}')"

cat > "$PKGROOT/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${DEB_VERSION}
Section: utils
Priority: optional
Architecture: riscv64
Maintainer: ${PKG_MAINTAINER}
Depends: ${DEB_DEPENDS}
Installed-Size: ${INSTALLED_SIZE}
Homepage: https://github.com/ptitSeb/box64
Description: Box64 x86_64 userspace emulator for RISC-V 64
 Box64 lets you run x86_64 Linux programs on non-x86_64 Linux systems.
 This package is cross-compiled for riscv64 with RV64 dynarec enabled.
EOF

cat > "$PKGROOT/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if command -v systemctl >/dev/null 2>&1; then
  systemctl restart systemd-binfmt.service >/dev/null 2>&1 || true
fi
exit 0
POSTINST
chmod 0755 "$PKGROOT/DEBIAN/postinst"

OUT="$ROOT/debian/${PKG_NAME}_${DEB_VERSION}_riscv64.deb"
dpkg-deb --root-owner-group --build "$PKGROOT" "$OUT"

echo "$COMMIT" > "$ROOT/commit.txt"

# Keep only the newest packages for this package name to prevent the GitHub Pages branch from growing indefinitely.
ls -1t "$ROOT"/debian/${PKG_NAME}_*_riscv64.deb 2>/dev/null | tail -n +$((KEEP_BUILDS + 1)) | xargs -r rm -f

rm -rf "$ROOT/work/box64" "$ROOT/work/pkgroot" "$ROOT/work/build"

echo "Built $OUT"
