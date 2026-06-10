#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  ca-certificates git build-essential gcc g++ make cmake python3 \
  debhelper devscripts dpkg-dev fakeroot file gzip xz-utils \
  apt-utils gnupg
