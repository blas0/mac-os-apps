# homebrew-omjo (oh-my-just-open)
<div align="center">
  
[`oh-my-just-open`](https://github.com/blas0/oh-my-just-open) — a minimal macOS default-app manager.

</div>

<div align="center">
<div center>
<img src="https://svgl.app/library/homebrew.svg" width="32">
<img src="https://svgl.app/library/swift.svg" width="32">
</div>
</div>

---

## Installation

```sh
brew tap blas0/omjo
brew install --cask oh-my-just-open
```

That's it. Brew strips the macOS quarantine flag for you, so the app launches normally on first run — no right-click-Open dance.

**Why a separate tap?**

The app ships ad-hoc signed instead of going through Apple's Developer ID + notarization workflow. The official `homebrew/cask` repo requires notarized apps, so the cask lives here instead. Once the upstream app starts notarizing again, this tap may move (or stay — it's lightweight).

**Updates**

The cask sets `auto_updates true`, which tells brew that the app updates itself. [Sparkle](https://sparkle-project.org/) inside the app handles version checks and applies updates in place — `brew upgrade --cask` is a no-op for this app.


**Pull requests**

Submit a PR if you have a feature/suggestion &or a bug discovered.

**Uninstall**

```sh
brew uninstall --cask oh-my-just-open
brew untap blas0/omjo            # optional
```

`brew uninstall --cask --zap oh-my-just-open` also clears preferences and Sparkle's update cache.

<br>

## oh-my-just-open

A more intuitive interface for setting default applications for specific file extensions. 

Yes you can probably just prompt your agent to do so – but that's overrated.



## License

The cask file is MIT-licensed. The app itself is also MIT — see [the upstream repo](https://github.com/blas0/oh-my-just-open/blob/main/LICENSE).
