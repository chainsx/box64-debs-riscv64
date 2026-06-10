#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$ROOT/debian"

: "${GPG_KEY_ID:=}"
: "${GPG_PASSPHRASE:=}"

cd "$REPO_DIR"

rm -f Packages Packages.gz Release Release.gpg InRelease

dpkg-scanpackages --multiversion . /dev/null > Packages
gzip -9 -k -f Packages
apt-ftparchive release . > Release

if [[ -n "$GPG_KEY_ID" ]]; then
  gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" \
    --default-key "$GPG_KEY_ID" -abs -o Release.gpg Release
  gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" \
    --default-key "$GPG_KEY_ID" --clearsign -o InRelease Release

  cd "$ROOT"
  gpg --armor --export "$GPG_KEY_ID" > KEY.gpg
else
  echo "WARNING: GPG_KEY_ID is empty; repository metadata is unsigned." >&2
fi
