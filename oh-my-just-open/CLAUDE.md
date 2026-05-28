# CLAUDE.md — oh-my-just-open

Agent guide for working on this repo. Read this top-to-bottom before making
changes. The global `~/.claude/CLAUDE.md` still applies; this file adds
project-specific context that overrides nothing but extends everything.

---

## What this app is

SwiftUI macOS 26.2 app that lets users pick the default app for any URL
scheme or file type. Functionally a free clone of OpenIn 4. Bundle ID
`com.neurix.oh-my-just-open`, team `83698ZGFJP` (Neurix), MIT licensed.

Distribution: **ad-hoc signed** DMG attached to a GitHub Release, surfaced
to users via a **self-hosted Homebrew tap** at `blas0/homebrew-omjo`.
There is no in-app updater — `brew upgrade --cask oh-my-just-open` is the
update channel. The Apple Developer Program agreement is currently
inactive, so the release pipeline does **not** notarize.

---

## Repo layout

```
oh-my-just-open/                  # repo root (== inner dir containing .xcodeproj)
├── oh-my-just-open.xcodeproj/
├── oh-my-just-open/              # app sources
│   ├── oh_my_just_openApp.swift
│   └── ...
├── Config/
│   ├── Version.xcconfig          # MARKETING_VERSION + CURRENT_PROJECT_VERSION (single source of truth)
│   ├── Distribution.xcconfig     # sandbox + hardened runtime
│   └── oh-my-just-open.entitlements   # sandbox
├── scripts/
│   ├── release-unsigned.sh       # build the DMG (ad-hoc signed)
│   ├── oh-my-just-open.rb.template   # reference cask (live cask lives in blas0/homebrew-omjo)
│   └── .env.release.example      # placeholder; no env vars needed for the current flow
├── homebrew-tap/                 # SKELETON copied into blas0/homebrew-omjo (separate repo)
│   ├── Casks/oh-my-just-open.rb
│   └── README.md
├── dist/                         # gitignored — DMG artifact lands here
├── README.md
└── CLAUDE.md                     # this file
```

There are no project secrets to manage. Nothing in `scripts/.env.release*`
is required for the current Homebrew-only flow.

---

## Release & update flow (ad-hoc / unsigned)

This is the flow that ships releases today. Do it from `main` after the
PR for whatever change is being released has merged.

### 1. Bump the version

Edit `Config/Version.xcconfig`:

```
MARKETING_VERSION = 1.0.1        # user-visible (semver)
CURRENT_PROJECT_VERSION = 2      # monotonic build counter
```

Commit + push:

```sh
git commit -am "chore: release v1.0.1"
git push origin main
```

### 2. Build the DMG

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
| 4 | Build DMG via `hdiutil`, ad-hoc sign the DMG |

The script prints the next-step commands (tag, push, GitHub release, cask
bump) at the end with the computed sha256 baked in.

Flag: `--dry-run` (no side effects).

### 3. Tag, push, GitHub release

```sh
git tag -a v1.0.1 -m "Release 1.0.1"
git push origin main --tags

gh release create v1.0.1 \
  dist/oh-my-just-open-1.0.1.dmg \
  --title "v1.0.1" \
  --notes "See CHANGELOG.md for details."
```

The Homebrew cask URL points at
`github.com/blas0/oh-my-just-open/releases/download/v$VERSION/...`, and
the README's "Direct download" link uses
`github.com/blas0/oh-my-just-open/releases/latest/download/oh-my-just-open.dmg`
— both update automatically once the release exists.

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
git add . && git commit -m "Initial cask for oh-my-just-open" && git push
```

**Every release after that:**

```sh
VERSION=1.0.1
DIST_DIR="$APP_REPO_ROOT/dist"
SHA256=$(shasum -a 256 "$DIST_DIR/oh-my-just-open-${VERSION}.dmg" | awk '{print $1}')

cd "$TAP_REPO_ROOT"
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Casks/oh-my-just-open.rb
sed -i '' "s/sha256 \"[a-f0-9]*\"/sha256 \"${SHA256}\"/" Casks/oh-my-just-open.rb

brew audit --cask Casks/oh-my-just-open.rb
brew install --cask --force ./Casks/oh-my-just-open.rb
brew uninstall --cask oh-my-just-open    # cleanup after the test

git add Casks/oh-my-just-open.rb
git commit -m "oh-my-just-open ${VERSION}"
git push
```

That's the entire release cycle. Existing users get the new version via
`brew upgrade --cask oh-my-just-open` (or whenever their `brew upgrade`
cron fires).

### Verification

After step 2 (before tagging) — sanity-check the artifacts:

```sh
codesign -dv --verbose=4 build/export/oh-my-just-open.app  # expect "Signature=adhoc"
hdiutil verify dist/oh-my-just-open-1.0.1.dmg
```

`spctl --assess --type install dist/*.dmg` will say *rejected
(Unnotarized)* — that's **expected** and not a failure.

---

## When the Apple Dev agreement comes back

If/when the Apple Developer Program agreement is renewed, we can add a
notarized variant of the release script (Developer ID signing + `xcrun
notarytool submit` + `xcrun stapler staple`) and migrate the cask off
the self-hosted tap toward the official `homebrew/cask` repo (which
requires notarization). Until then, the ad-hoc + tap path is the only
shipping path.

---

## Hard rules (project-specific)

- **Never identify the maintainer's personal accounts in committed files
  or git history.** Only the Neurix-branded identity is permitted in
  anything that ships: signing identity `Neurix (83698ZGFJP)`, contact
  email `matthew@neurix.co`, GitHub org/user handle that owns the public
  repos. Any other personal usernames, legacy email aliases, or local
  user paths (`/Users/<name>/...`) must be scrubbed before commit — use
  `~/`, `$HOME`, or a named variable instead.
- **Don't bump `CURRENT_PROJECT_VERSION` non-monotonically.** Keep it
  strictly increasing — easier on future-us if we ever wire an in-app
  updater back in.
- **Tag format is `v<MARKETING_VERSION>`** (`v1.0.1`, not `1.0.1` or
  `release-1.0.1`). The Homebrew cask's `livecheck` and the GitHub
  Releases "latest" permalink both depend on that.
- **Don't edit the tap cask file from this repo.** The skeleton under
  `homebrew-tap/` is a template only. The live cask is in
  `blas0/homebrew-omjo`; edit it there, commit there, push there.

---

## Common gotchas

- `Config/Version.xcconfig` uses ` = ` as the separator (note the
  spaces). The release script's `awk -F' = '` parser depends on that — if
  you reformat the file, update the parser.
- `spctl --assess` failing on the DMG is expected (unsigned). Don't
  treat that as a release blocker.
- The GitHub-Releases "latest" permalink only works once at least one
  release is tagged. Until then, the README's direct-download link 404s.

---

## Pointers

- GitHub repo: `https://github.com/blas0/oh-my-just-open`
- Homebrew tap repo: `https://github.com/blas0/homebrew-omjo`
- Releases (DMGs live here): `https://github.com/blas0/oh-my-just-open/releases`
