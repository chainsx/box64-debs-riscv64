#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ca-certificates \
  git \
  build-essential \
  make \
  cmake \
  ninja-build \
  pkg-config \
  python3 \
  debhelper \
  devscripts \
  dpkg-dev \
  fakeroot \
  file \
  gzip \
  xz-utils \
  apt-utils \
  gnupg \
  gcc-riscv64-linux-gnu \
  g++-riscv64-linux-gnu \
  binutils-riscv64-linux-gnu \
  libc6-dev-riscv64-cross
