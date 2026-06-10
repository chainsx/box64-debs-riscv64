#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export DEBIAN_FRONTEND=noninteractive

: "${BOX64_REPO:=https://github.com/ptitSeb/box64.git}"
: "${BOX64_BRANCH:=main}"
: "${PKG_NAME:=box64-rv64}"
: "${PKG_MAINTAINER:=Your Name <you@example.com>}"
: "${KEEP_BUILDS:=4}"
: "${ENABLE_BOX32:=0}"
: "${ENABLE_BOX32_BINFMT:=0}"

mkdir -p "$ROOT/debian" "$ROOT/work"
rm -f "$ROOT/exited_successfully.txt"

LAST_COMMIT="$(cat "$ROOT/commit.txt" 2>/dev/null || true)"
rm -rf "$ROOT/work/box64" "$ROOT/work/pkgroot"

git clone --depth=1 --branch "$BOX64_BRANCH" "$BOX64_REPO" "$ROOT/work/box64"
cd "$ROOT/work/box64"

COMMIT="$(git rev-parse --short=7 HEAD)"
if [[ "$COMMIT" == "$LAST_COMMIT" ]]; then
  echo "Box64 is already up to date at $COMMIT."
  touch "$ROOT/exited_successfully.txt"
  exit 0
fi

MAJOR="$(awk '/#define BOX64_MAJOR/{print $3}' src/box64version.h)"
MINOR="$(awk '/#define BOX64_MINOR/{print $3}' src/box64version.h)"
REVISION="$(awk '/#define BOX64_REVISION/{print $3}' src/box64version.h)"
BOX64_VERSION="${MAJOR}.${MINOR}.${REVISION}"
DEB_VERSION="${BOX64_VERSION}+$(date -u +%Y%m%d).${COMMIT}"

echo "Building ${PKG_NAME} ${DEB_VERSION} for riscv64"

cmake_opts=(
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
  -DCMAKE_INSTALL_PREFIX=/usr
  -DRV64=1
  -DRV64_DYNAREC=1
)

if [[ "$ENABLE_BOX32" == "1" ]]; then
  cmake_opts+=( -DBOX32=ON )
fi
if [[ "$ENABLE_BOX32_BINFMT" == "1" ]]; then
  cmake_opts+=( -DBOX32_BINFMT=ON )
fi

mkdir -p build
cd build
cmake .. "${cmake_opts[@]}"
cmake --build . --parallel "$(nproc)"

PKGROOT="$ROOT/work/pkgroot"
rm -rf "$PKGROOT"
DESTDIR="$PKGROOT" cmake --install .

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
  find "$PKGROOT" -maxdepth 4 -type f >&2 || true
  exit 1
fi

DEPENDS="$(dpkg-shlibdeps -O -e"$BOX64_BIN" 2>/dev/null | sed 's/^shlibs:Depends=//' || true)"
if [[ -z "$DEPENDS" ]]; then
  # Fallback for minimal riscv64 containers. Prefer dpkg-shlibdeps output when available.
  DEPENDS="libc6 (>= 2.35), libgcc-s1"
fi

INSTALLED_SIZE="$(du -ks "$PKGROOT" | awk '{print $1}')"
cat > "$PKGROOT/DEBIAN/control" <<CONTROL
Package: ${PKG_NAME}
Version: ${DEB_VERSION}
Section: utils
Priority: optional
Architecture: riscv64
Maintainer: ${PKG_MAINTAINER}
Installed-Size: ${INSTALLED_SIZE}
Depends: ${DEPENDS}
Provides: box64
Conflicts: box64, qemu-user-static
Replaces: box64
Homepage: https://github.com/ptitSeb/box64
Description: Box64 x86_64 userspace emulator for RV64 Linux
 Box64 lets x86_64 Linux programs run on non-x86_64 64-bit little-endian Linux systems.
 This package is built for riscv64 with RV64 and RV64_DYNAREC enabled.
CONTROL

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

rm -rf "$ROOT/work/box64" "$ROOT/work/pkgroot"
echo "Built $OUT"
