#!/usr/bin/env bash
# Publish this directory to blas0/homebrew-omjo, the standalone repo Homebrew
# requires for `brew tap blas0/omjo`. This directory is the source of truth;
# the tap repo is a publish target only.
set -euo pipefail

# HTTPS, not SSH — this account authenticates git over https via the gh
# credential helper (`gh auth status` → "Git operations protocol: https").
TAP_REPO="https://github.com/blas0/homebrew-omjo.git"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASK="$SRC/Casks/oh-my-just-open.rb"

[ -f "$CASK" ] || { echo "error: no cask at $CASK" >&2; exit 1; }

VERSION="$(sed -n 's/^[[:space:]]*version "\(.*\)"/\1/p' "$CASK" | head -1)"
[ -n "$VERSION" ] || { echo "error: could not parse version from cask" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone --quiet --depth 1 "$TAP_REPO" "$WORK/tap"
rsync -a --delete --exclude '.git' --exclude 'publish-tap.sh' "$SRC/" "$WORK/tap/"

cd "$WORK/tap"

# The global git identity uses a private address that GitHub's email-privacy
# setting rejects on push. Commit as the noreply address instead.
git config user.name "blas0"
git config user.email "144485528+blas0@users.noreply.github.com"

if git diff --quiet && git diff --cached --quiet; then
  echo "tap already up to date at v$VERSION — nothing to publish"
  exit 0
fi

git add -A
git commit -q -m "chore: publish oh-my-just-open v$VERSION"
git push --quiet origin HEAD
echo "published oh-my-just-open v$VERSION to blas0/homebrew-omjo"
