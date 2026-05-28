# CLAUDE.md — oh-my-just-open

Agent guide for working on this repo. Read this top-to-bottom before making
changes. The global `~/.claude/CLAUDE.md` still applies; this file adds
project-specific context that overrides nothing but extends everything.

---

## What this app is

SwiftUI macOS 26.2 app that lets users pick the default app for any URL
scheme or file type. Functionally a free clone of OpenIn 4. Bundle ID
`com.neurix.oh-my-just-open`, team `83698ZGFJP` (Neurix), MIT licensed.

In-app updates via **Sparkle 2** (EdDSA-signed appcast).
Distribution: **ad-hoc signed** DMG hosted on Cloudflare R2, plus a
**self-hosted Homebrew tap** at `blas0/homebrew-omjo`.

The Apple Developer Program agreement has expired and isn't renewable
right now, so the release pipeline does **not** notarize. Sparkle's EdDSA
signature is the only integrity check on updates — keep it that way.

---

## Repo layout

```
oh-my-just-open/                  # repo root (== inner dir containing .xcodeproj)
├── oh-my-just-open.xcodeproj/
├── oh-my-just-open/              # app sources
│   ├── oh_my_just_openApp.swift
│   ├── Services/UpdateService.swift   # Sparkle wrapper
│   └── ...
├── Config/
│   ├── Version.xcconfig          # MARKETING_VERSION + CURRENT_PROJECT_VERSION (single source of truth)
│   ├── Distribution.xcconfig     # sandbox + hardened runtime + Info.plist path
│   ├── Sparkle-Info.plist        # SUFeedURL, SUPublicEDKey, update behaviour
│   └── oh-my-just-open.entitlements   # sandbox + Sparkle XPC mach-lookup exceptions
├── scripts/
│   ├── release.sh                # notarized path (needs active Apple Dev agreement)
│   ├── release-unsigned.sh       # ad-hoc path (current shipping path)
│   ├── generate-sparkle-key.sh   # one-time EdDSA key generator
│   ├── ExportOptions.plist       # only used by release.sh
│   ├── .env.release              # gitignored — R2 creds + signing identity
│   └── .env.release.example      # template (committed)
├── homebrew-tap/                 # SKELETON copied into blas0/homebrew-omjo (separate repo)
│   ├── Casks/oh-my-just-open.rb
│   └── README.md
├── Release/
│   └── appcast.xml               # rewritten by release scripts, then committed
├── README.md
└── CLAUDE.md                     # this file
```

Secrets that **must never** be committed:

- `scripts/.env.release` (R2 access key + secret, account ID)
- `~/.omjo-keys/sparkle_eddsa_seed.txt` (Sparkle private seed — outside repo)
- Notary keychain profile `omjo-notary` (in macOS Keychain; not on disk)

If any of those leak into a commit, abort and rotate the credential before
pushing.

---

## Release & update flow (ad-hoc / unsigned — current path)

This is the flow that ships releases today. Do it from `main` after the
PR for whatever change is being released has merged.

### 1. Bump the version

Edit `Config/Version.xcconfig`:

```
MARKETING_VERSION = 1.0.1        # user-visible (semver)
CURRENT_PROJECT_VERSION = 2      # monotonic build counter — Sparkle compares this
```

Sparkle uses `CURRENT_PROJECT_VERSION` (`sparkle:version` in the appcast)
to decide whether an update is newer. It **must** strictly increase every
release. `MARKETING_VERSION` is what users see.

Commit + push:

```sh
git commit -am "chore: release v1.0.1"
git push origin main
```

### 2. Build, sign, upload

```sh
./scripts/release-unsigned.sh
```

What the script does, in order:

| Step | Action |
|------|--------|
| 0 | Git pre-flight: clean tree, on `main`, in sync with `origin`, tag `v$VERSION` doesn't exist |
| 1 | Clean `build/` |
| 2 | `xcodebuild archive` with `CODE_SIGN_IDENTITY=-` (ad-hoc) |
| 3 | Copy `.app` out of the `.xcarchive`, re-sign with `codesign --force --deep --options runtime --sign -`, then verify with `codesign --verify --deep --strict` |
| 4 | (notarize step — skipped) |
| 5 | Build DMG via `hdiutil`, ad-hoc sign the DMG |
| 6 | `ditto -c -k --keepParent` → Sparkle ZIP |
| 7 | EdDSA sign the ZIP via Sparkle's `sign_update` against `~/.omjo-keys/sparkle_eddsa_seed.txt` — **fails the build** if the key or `sign_update` binary isn't found |
| 8 | Prepend a new `<item>` block into `Release/appcast.xml` (inserted right after `<language>`) |
| 9 | Upload to R2: `releases/$ZIP_NAME`, `releases/$DMG_NAME`, `releases/oh-my-just-open-latest.dmg` (stable pointer, `max-age=300`), and `appcast.xml` at the bucket root (`max-age=300`) |

Flags: `--dry-run` (no side effects), `--skip-upload` (build only, no R2).

### 3. Tag, push, GitHub release

The script prints the exact commands at the end. Concretely:

```sh
git add Release/appcast.xml
git commit -m "release: v1.0.1"
git tag -a v1.0.1 -m "Release 1.0.1"
git push origin main --tags

gh release create v1.0.1 \
  Release/oh-my-just-open-1.0.1.dmg \
  --title "v1.0.1" \
  --notes "See CHANGELOG.md for details."
```

### 4. Update the Homebrew tap

The tap is a **separate GitHub repo**: `blas0/homebrew-omjo` (cloned to
`~/Documents/Code/homebrew-omjo`). End users install via
`brew tap blas0/omjo && brew install --cask oh-my-just-open`.

One-time setup (only the first time, ever):

```sh
gh repo create <YOUR_GH_USER>/homebrew-omjo --public --description "Homebrew tap for oh-my-just-open"
cd "$REPO_PARENT"   # parent dir where you keep checkouts
git clone git@github.com:<YOUR_GH_USER>/homebrew-omjo.git
cd homebrew-omjo
mkdir -p Casks
cp "$APP_REPO_ROOT/homebrew-tap/Casks/oh-my-just-open.rb" Casks/
# Author a top-level README for the tap repo (the skeleton README is for
# developers of *this* repo, not for tap users — write a short one here).
git add . && git commit -m "Initial cask for oh-my-just-open" && git push
```

**Every release after that:**

```sh
VERSION=1.0.1
RELEASE_DIR="$APP_REPO_ROOT/Release"
SHA256=$(shasum -a 256 "$RELEASE_DIR/oh-my-just-open-${VERSION}.dmg" | awk '{print $1}')

cd "$TAP_REPO_ROOT"
# Update the cask in place. The cask file has exactly one `version "..."`
# line and one `sha256 "..."` line, so sed is safe.
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Casks/oh-my-just-open.rb
sed -i '' "s/sha256 \"[a-f0-9]*\"/sha256 \"${SHA256}\"/" Casks/oh-my-just-open.rb

# Audit before pushing — catches typos, missing fields, bad URLs.
brew audit --cask Casks/oh-my-just-open.rb

# Optional: local install test from the file path.
brew install --cask --force ./Casks/oh-my-just-open.rb
brew uninstall --cask oh-my-just-open    # clean up after the test

git add Casks/oh-my-just-open.rb
git commit -m "oh-my-just-open ${VERSION}"
git push
```

That's the entire release cycle. The cask `auto_updates true` directive
tells brew that Sparkle handles in-place upgrades, so users who already
installed via brew get future versions through the in-app updater rather
than `brew upgrade`.

### Verification

After step 2 (before tagging) — sanity-check the artifacts:

```sh
codesign -dv --verbose=4 build/export/oh-my-just-open.app  # expect "Signature=adhoc"
hdiutil verify Release/oh-my-just-open-1.0.1.dmg
curl -sI https://pub-06563b7bc8e246b69c21fe5af1f67b88.r2.dev/releases/oh-my-just-open-latest.dmg  # expect 200
curl -s https://pub-06563b7bc8e246b69c21fe5af1f67b88.r2.dev/appcast.xml | head -40  # confirm new <item>
```

`spctl --assess --type install Release/*.dmg` will say *rejected
(Unnotarized)* — that's **expected** and not a failure.

In-app update path: install the previous version, lower the local
`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` for testing, launch, "Check
for Updates…" should detect the new appcast entry.

---

## When the Apple Dev agreement comes back

If/when the Apple Developer Program agreement is renewed, switch back to
`./scripts/release.sh` (notarized path). The notarized DMG passes
Gatekeeper without any user friction, and the Homebrew tap can stay as-is
or migrate to the official `homebrew/cask` repo (which requires
notarization).

The two scripts share the same `.env.release`, same version source, same
appcast format, and same EdDSA key — so switching is a one-line change in
the docs, nothing else.

---

## Hard rules (project-specific)

- **Never write secrets into the repo.** Not in commits, not in error
  messages, not in PR descriptions, not in this file. R2 credentials,
  Sparkle private key, notary password all live outside `git ls-files`.
- **Never identify the maintainer's personal accounts in committed files
  or git history.** Only the Neurix-branded identity is permitted in
  anything that ships: signing identity `Neurix (83698ZGFJP)`, contact
  email `matthew@neurix.co`, GitHub org/user handle that owns the public
  repos. Any other personal usernames, legacy email aliases, or local
  user paths (`/Users/<name>/...`) must be scrubbed before commit — use
  `~/`, `$HOME`, or a named variable instead.
- **Don't bump `CURRENT_PROJECT_VERSION` non-monotonically.** Sparkle uses
  it as the ordering key; going down strands existing users.
- **Don't ship a Sparkle update without an EdDSA signature.**
  `release-unsigned.sh` enforces this — don't add a flag to bypass it.
- **Don't notarize from this script-set right now.** The Apple agreement
  is expired; calls to `notarytool submit` will 403. Use
  `release-unsigned.sh` until the agreement is renewed.
- **Tag format is `v<MARKETING_VERSION>`** (`v1.0.1`, not `1.0.1` or
  `release-1.0.1`). The Homebrew cask's `livecheck` and the appcast both
  assume that.
- **Don't edit the tap cask file from this repo.** The skeleton under
  `homebrew-tap/` is a template only. The live cask is in
  `blas0/homebrew-omjo`; edit it there, commit there, push there.

---

## Common gotchas

- `Config/Version.xcconfig` uses ` = ` as the separator (note the
  spaces). The release script's `awk -F' = '` parser depends on that — if
  you reformat the file, update the parser.
- `scripts/.env.release.example` contains a quoted `SIGNING_IDENTITY` —
  the parens in `Neurix (83698ZGFJP)` are subshell syntax in bash, so the
  quotes are load-bearing.
- The xcconfig `https:/$()/...` trick exists because `//` is the xcconfig
  comment marker. Don't "fix" it.
- Sparkle's `sign_update` binary lives inside `DerivedData/.../
  SourcePackages/artifacts/sparkle/Sparkle/bin/`. If the script can't
  find it, build the project once in Xcode to resolve the SwiftPM
  package, then re-run.
- `spctl --assess` failing on the DMG is expected (unsigned). Don't
  treat that as a release blocker.

---

## Pointers

- Live appcast: `https://pub-06563b7bc8e246b69c21fe5af1f67b88.r2.dev/appcast.xml`
- Latest DMG (stable URL): `https://pub-06563b7bc8e246b69c21fe5af1f67b88.r2.dev/releases/oh-my-just-open-latest.dmg`
- GitHub repo: `https://github.com/blas0/oh-my-just-open`
- Homebrew tap repo (to-be-created): `https://github.com/blas0/homebrew-omjo`
- Sparkle docs: `https://sparkle-project.org/documentation/`
- Cloudflare R2 bucket: `oh-my-just-open` (account ID lives in `scripts/.env.release`, not in this file)
