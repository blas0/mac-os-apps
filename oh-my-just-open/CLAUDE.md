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
├── homebrew-tap/                 # SKELETON only — historical; live cask lives in blas0/homebrew-omjo
│   ├── Casks/oh-my-just-open.rb
│   └── README.md
├── polaroids/                    # README screenshots + avatar
├── dist/                         # gitignored — DMG artifact lands here
├── CHANGELOG.md
├── README.md
└── CLAUDE.md                     # this file
```

There are no project secrets to manage. Nothing in `scripts/.env.release*`
is required for the current Homebrew-only flow.

---

## Release & update flow (ad-hoc / unsigned)

This is the flow that ships releases today. Do it from `main` after the
PR for whatever change is being released has merged.

**Hard rule:** never push directly to `main` on either repo. Every
version bump and every cask bump goes through a branch + PR + squash
merge, even single-line edits. The repos enforce this via tooling, and
the rest of this section assumes you're doing it that way.

### 1. Bump the version (PR)

```sh
git checkout main && git pull
git checkout -b chore/release-v1.0.1

# Edit Config/Version.xcconfig:
#   MARKETING_VERSION = 1.0.1        # user-visible (semver)
#   CURRENT_PROJECT_VERSION = 2      # monotonic build counter

git commit -am "chore: release v1.0.1"
git push -u origin chore/release-v1.0.1
gh pr create --title "chore: release v1.0.1" --body "Version bump for v1.0.1."
gh pr merge --squash --delete-branch
git checkout main && git pull
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

Tags can be pushed directly (they're metadata, not branch history):

```sh
git tag -a v1.0.1 -m "Release 1.0.1"
git push origin v1.0.1

gh release create v1.0.1 \
  dist/oh-my-just-open-1.0.1.dmg \
  --title "v1.0.1" \
  --notes "See CHANGELOG.md for details."
```

The Homebrew cask URL points at
`github.com/blas0/oh-my-just-open/releases/download/v$VERSION/...`, and
resolves as soon as the release exists.

### 4. Update the Homebrew tap (PR)

The tap is a **separate GitHub repo**: `blas0/homebrew-omjo` (cloned to
`~/Documents/Code/homebrew-omjo`). It's already initialized and live —
the one-time `gh repo create` / cask seed dance is **historical**; you
should never need it again. End users install via
`brew tap blas0/omjo && brew install --cask oh-my-just-open`.

**Every release:**

```sh
VERSION=1.0.1
DIST_DIR="$APP_REPO_ROOT/dist"
SHA256=$(shasum -a 256 "$DIST_DIR/oh-my-just-open-${VERSION}.dmg" | awk '{print $1}')

cd "$TAP_REPO_ROOT"
git checkout main && git pull
git checkout -b "cask/v${VERSION}"

sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Casks/oh-my-just-open.rb
sed -i '' "s/sha256 \"[a-f0-9]*\"/sha256 \"${SHA256}\"/" Casks/oh-my-just-open.rb

git add Casks/oh-my-just-open.rb
git commit -m "oh-my-just-open ${VERSION}"
git push -u origin "cask/v${VERSION}"

gh pr create --title "oh-my-just-open ${VERSION}" \
  --body "DMG: https://github.com/blas0/oh-my-just-open/releases/tag/v${VERSION}
sha256: \`${SHA256}\`"
gh pr merge --squash --delete-branch
git checkout main && git pull
```

**Do NOT run `brew audit --cask Casks/oh-my-just-open.rb`** — Homebrew
disabled `brew audit [path ...]` in favor of `brew audit [name ...]`.
For ad-hoc tap edits there's no useful pre-merge audit step; the cask
either installs or it doesn't. If you want a smoke test, install from
the tap *after* the PR merges:

```sh
brew untap blas0/omjo && brew tap blas0/omjo   # forces cache refresh
brew install --cask oh-my-just-open
```

That's the entire release cycle. Existing users get the new version via
`brew upgrade --cask oh-my-just-open` (or whenever their `brew upgrade`
cron fires).

**Cache invalidation gotcha:** Homebrew caches the tap on each user's
machine. After a cask bump, a user who already had the tap may need
`brew update` (or `brew untap && brew tap` for a hard refresh) before
the new version shows up. This is normal Homebrew behavior, not a bug.

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
- **PR-only — no direct pushes to `main`.** Both repos. Even one-line
  cask sha bumps and version bumps go through a branch + PR + squash
  merge. The only thing you can push directly to a repo is a tag.

---

## Common gotchas

- `Config/Version.xcconfig` uses ` = ` as the separator (note the
  spaces). The release script's `awk -F' = '` parser depends on that — if
  you reformat the file, update the parser.
- `spctl --assess` failing on the DMG is expected (unsigned). Don't
  treat that as a release blocker.
- The GitHub-Releases "latest" permalink only works once at least one
  release is tagged. v1.0.0 is tagged, so this is no longer a concern
  going forward.
- **Cask sha placeholder gotcha:** the initial cask was seeded with a
  `0000...` sha256 to make the file valid before any DMG existed. If
  you ever re-seed a cask (or copy this pattern for another app),
  remember the sha must be bumped to the real DMG hash *before* anyone
  runs `brew install` against it — otherwise install fails with a
  hash-mismatch even if the DMG is fine.
- **`gh pr merge --delete-branch` deletes the local branch too** on
  recent gh versions, then auto-checks out main. If you see "branch
  not found" trying to delete it manually afterwards, that's why —
  it's already gone.

---

## Pointers

- GitHub repo: `https://github.com/blas0/oh-my-just-open`
- Homebrew tap repo: `https://github.com/blas0/homebrew-omjo`
- Releases (DMGs live here): `https://github.com/blas0/oh-my-just-open/releases`
