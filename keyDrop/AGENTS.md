# keyDrop Agent Instructions

keyDrop is a SwiftUI macOS menu-bar app for local API key storage. It stores
secrets in macOS Keychain and uses Touch ID or the user's Mac password for
retrieval.

## Active Distribution Model

- Install path: Homebrew cask.
- Tap: `blas0/homebrew-keydrop`.
- Release artifact: ad-hoc signed DMG attached to a GitHub Release.
- Update path: `brew upgrade --cask keydrop`.
- Inactive/removed paths: Gumroad licensing, Sparkle updates, Cloudflare R2
  appcast publishing, Mac App Store distribution.

## Required Validation

For app changes, run:

```sh
xcodebuild -project keyDrop/keyDrop.xcodeproj \
  -scheme keyDrop-Direct \
  -configuration Debug-Direct \
  build CODE_SIGNING_ALLOWED=NO
```

For release-script changes, run:

```sh
./keyDrop/scripts/release-unsigned.sh --dry-run
```

## Release Checklist

Only run the real release flow when explicitly asked.

1. Merge the app change first.
2. Bump `keyDrop/Config/Version.xcconfig` on a release branch.
3. Run `./keyDrop/scripts/release-unsigned.sh` from a clean `main`.
4. Create the tag and GitHub Release printed by the script.
5. Update `Casks/keydrop.rb` in `blas0/homebrew-keydrop` by PR.

## Safety

- Leave local certificates, signing keys, and `.env` files untouched.
- Do not commit secrets, local paths, or generated build artifacts.
- Do not reintroduce Gumroad, Sparkle, R2, or notarized Developer ID release
  assumptions without explicit direction.
- Do not merge PRs, push tags, create GitHub Releases, or modify the live tap
  without explicit approval.
