#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
BOX64_BRANCH="${BOX64_BRANCH:-v0.4.2}"
FORCE_REBUILD="${FORCE_REBUILD:-false}"
BUILD_PACKAGES="${BUILD_PACKAGES:-all}"
PKG_MAINTAINER="${PKG_MAINTAINER:-Box64 RV64 Maintainer <noreply@example.com>}"

mkdir -p "$ROOT/work" "$ROOT/debian"
rm -rf "$ROOT/work/box64-src" "$ROOT/work/build-"* "$ROOT/work/pkgroot-"* "$ROOT/work/src-"*

git clone --depth=1 --branch "$BOX64_BRANCH" https://github.com/ptitSeb/box64.git "$ROOT/work/box64-src"

UPSTREAM_COMMIT="$(git -C "$ROOT/work/box64-src" rev-parse HEAD)"
UPSTREAM_SHORT="${UPSTREAM_COMMIT:0:8}"
SAFE_BRANCH="$(printf '%s' "$BOX64_BRANCH" | tr '/ ' '__')"
OLD_COMMIT=""

if [[ -f "$ROOT/commit.txt" ]]; then
  OLD_COMMIT="$(cat "$ROOT/commit.txt")"
fi

case "$BUILD_PACKAGES" in
  all)
    TARGET_PACKAGES=("box64" "box64-rv64gcv")
    ;;
  box64)
    TARGET_PACKAGES=("box64")
    ;;
  box64-rv64gcv|rv64gcv)
    TARGET_PACKAGES=("box64-rv64gcv")
    ;;
  *)
    echo "ERROR: BUILD_PACKAGES must be one of: all, box64, box64-rv64gcv" >&2
    exit 2
    ;;
esac

all_requested_packages_exist() {
  local pkg
  for pkg in "${TARGET_PACKAGES[@]}"; do
    if ! compgen -G "$ROOT/debian/${pkg}_*${SAFE_BRANCH}.${UPSTREAM_SHORT}_riscv64.deb" >/dev/null; then
      return 1
    fi
  done
  return 0
}

if [[ "$FORCE_REBUILD" != "true" && "$UPSTREAM_COMMIT" == "$OLD_COMMIT" ]] && all_requested_packages_exist; then
  echo "Upstream Box64 commit has not changed and requested packages already exist: $UPSTREAM_COMMIT"
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

printf 'Using RISC-V cross toolchain:\n'
printf '  CC      = %s\n' "$RISCV_CC"
printf '  CXX     = %s\n' "$RISCV_CXX"
printf '  AR      = %s\n' "$RISCV_AR"
printf '  RANLIB  = %s\n' "$RISCV_RANLIB"
printf '  STRIP   = %s\n' "$RISCV_STRIP"

configure_and_build_package() {
  local pkg_name="$1"
  local march="$2"
  local description_suffix="$3"

  local src_dir="$ROOT/work/src-${pkg_name}"
  local build_dir="$ROOT/work/build-${pkg_name}"
  local pkg_dir="$ROOT/work/pkgroot-${pkg_name}"

  rm -rf "$src_dir" "$build_dir" "$pkg_dir"
  mkdir -p "$src_dir" "$build_dir" "$pkg_dir"
  cp -a "$ROOT/work/box64-src/." "$src_dir/"

  if [[ "$march" == "rv64gcv" ]]; then
    # Box64 v0.4.2 sets -march=rv64gc internally for RV64 builds.
    # For the RVV package, patch that internal RV64 baseline to rv64gcv.
    sed -i 's/-march=rv64gc/-march=rv64gcv/g' "$src_dir/CMakeLists.txt"
  fi

  cmake -S "$src_dir" -B "$build_dir" \
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

  cmake --build "$build_dir" --parallel "$(nproc)"
  DESTDIR="$pkg_dir" cmake --install "$build_dir"

  local pkg_version
  pkg_version="$(date -u +%Y%m%d).${SAFE_BRANCH}.${UPSTREAM_SHORT}"
  local deb_file="$ROOT/debian/${pkg_name}_${pkg_version}_riscv64.deb"

  mkdir -p "$pkg_dir/DEBIAN"

  local relationship_fields=""
  if [[ "$pkg_name" == "box64" ]]; then
    relationship_fields="Conflicts: box64-rv64gcv
Replaces: box64-rv64gcv"
  else
    relationship_fields="Provides: box64
Conflicts: box64
Replaces: box64"
  fi

  cat > "$pkg_dir/DEBIAN/control" <<CONTROL
Package: $pkg_name
Version: $pkg_version
Section: utils
Priority: optional
Architecture: riscv64
Maintainer: $PKG_MAINTAINER
Depends: libc6
$relationship_fields
Description: Box64 x86_64 userspace emulator for RISC-V 64
 Box64 lets you run x86_64 Linux programs on non-x86_64 Linux systems.
 $description_suffix
CONTROL

  chmod -R go-w "$pkg_dir"
  dpkg-deb --root-owner-group --build "$pkg_dir" "$deb_file"

  echo "Built package:"
  ls -lh "$deb_file"
}

for pkg in "${TARGET_PACKAGES[@]}"; do
  case "$pkg" in
    box64)
      configure_and_build_package \
        "box64" \
        "rv64gc" \
        "This package is cross-compiled for generic RV64GC with Box64 RV64 dynarec enabled."
      ;;
    box64-rv64gcv)
      configure_and_build_package \
        "box64-rv64gcv" \
        "rv64gcv" \
        "This package is cross-compiled for RV64GCV/RVV-capable systems with Box64 RV64 dynarec enabled."
      ;;
  esac
done

echo "$UPSTREAM_COMMIT" > "$ROOT/commit.txt"
