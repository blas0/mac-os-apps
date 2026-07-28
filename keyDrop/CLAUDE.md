# CLAUDE.md - keyDrop

Agent guide for working on keyDrop. This repo is a native SwiftUI macOS
menu-bar app for local API key storage using macOS Keychain and Touch ID.

## Distribution

keyDrop is distributed as an ad-hoc signed DMG attached to a GitHub Release and
installed through a self-hosted Homebrew tap:

```sh
brew tap blas0/keydrop
brew install --cask keydrop
brew upgrade --cask keydrop
```

There is no Gumroad licensing gate, no Sparkle updater, no R2 appcast, and no
Mac App Store release flow in the active distribution path. Updates ship through
Homebrew.

## Repo Layout

```text
keyDrop/
  keyDrop.xcodeproj/
  keyDrop/                    # app sources
  Config/
    Version.xcconfig          # MARKETING_VERSION + CURRENT_PROJECT_VERSION
    Direct.xcconfig           # Homebrew/ad-hoc distribution config
    MAS.xcconfig              # inactive placeholder
  scripts/
    release-unsigned.sh       # builds the ad-hoc DMG for GitHub Releases
    keydrop.rb.template       # reference cask for blas0/homebrew-keydrop
  homebrew-tap/               # skeleton only; live cask is in the tap repo
```

## Development Checks

Use this build as the cheap validation gate:

```sh
xcodebuild -project keyDrop/keyDrop.xcodeproj \
  -scheme keyDrop-Direct \
  -configuration Debug-Direct \
  build CODE_SIGNING_ALLOWED=NO
```

## Release Flow

Release work happens after the feature/fix PR has merged.

1. Bump `keyDrop/Config/Version.xcconfig`.
   - `MARKETING_VERSION` is the user-visible semver.
   - `CURRENT_PROJECT_VERSION` must increase monotonically.
2. Commit the version bump on a branch and merge it by PR.
3. From a clean `main`, build the DMG:

```sh
./keyDrop/scripts/release-unsigned.sh
```

4. Create the tag and GitHub Release using the command printed by the script.
5. Update the separate `blas0/homebrew-keydrop` tap on its own branch/PR.

Do not tag, create a GitHub Release, or edit the live Homebrew tap unless the
user explicitly asks for release execution.

## Homebrew Tap

The live cask belongs in `blas0/homebrew-keydrop`, not in this app repo. The
`homebrew-tap/` directory here is only a reference skeleton.

The cask URL points at:

```text
https://github.com/blas0/keyDrop/releases/download/v#{version}/keyDrop-#{version}.dmg
```

After building a release DMG, compute its SHA and update the tap cask:

```sh
VERSION=1.1.7
SHA256=$(shasum -a 256 "$APP_REPO_ROOT/keyDrop/dist/keyDrop-${VERSION}.dmg" | awk '{print $1}')
```

## Rules

- Keep changes scoped to the requested behavior.
- Do not restore Gumroad, Sparkle, R2, or Developer ID notarization without a
  fresh user request.
- Do not commit secrets, certificates, `.env.release`, signing material, or
  local machine paths.
- Do not push directly to `main`; use branches and PRs.
- Do not merge PRs, create releases, push tags, or edit the live tap without
  explicit approval.
