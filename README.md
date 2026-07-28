# mac-os-apps

Native macOS applications and the Homebrew tap that distributes them.

| Project | What it is |
| --- | --- |
| [`keyDrop`](keyDrop/) | Local, offline-only `API_KEY` storage menu-bar app, built on the macOS Keychain and Secure Enclave. |
| [`oh-my-just-open`](oh-my-just-open/) | Minimal macOS default-app manager. |
| [`homebrew-omjo`](homebrew-omjo/) | Homebrew tap serving the `oh-my-just-open` cask. |

Each project is self-contained: its own `README.md`, `LICENSE`, and `.gitignore`
live in its own directory and apply only to that subtree. Full commit history for
every project was carried into this repository, so `git log -- keyDrop/` reaches
all the way back to that project's first commit.

## Install

```sh
# keyDrop
brew tap blas0/keydrop
brew install --cask keydrop

# oh-my-just-open
brew tap blas0/omjo
brew install --cask oh-my-just-open
```

## A note on the tap

`homebrew-omjo/` is the canonical source for the tap — edit the cask here.

Homebrew resolves `brew tap blas0/omjo` to a standalone repository named
`homebrew-omjo` at the account root, so the tap cannot be served from a
subdirectory. [`blas0/homebrew-omjo`](https://github.com/blas0/homebrew-omjo)
therefore remains a live repository acting purely as the publish target.

After bumping the cask version here, publish it with:

```sh
./homebrew-omjo/publish-tap.sh
```

## Layout

```
mac-os-apps/
├── homebrew-omjo/     # tap source of truth -> published to blas0/homebrew-omjo
├── keyDrop/           # Swift / Xcode app
└── oh-my-just-open/   # Swift / Xcode app
```
