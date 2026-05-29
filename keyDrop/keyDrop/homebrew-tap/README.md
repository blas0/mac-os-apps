# homebrew-tap skeleton

This directory is a reference template for the separate Homebrew tap repo:
`github.com/blas0/homebrew-keydrop`.

The live cask should be edited in that tap repo, not from this app repo. End
users install with:

```sh
brew tap blas0/keydrop
brew install --cask keydrop
```

Per release:

```sh
VERSION=1.1.7
SHA256=$(shasum -a 256 "$APP_REPO_ROOT/dist/keyDrop-${VERSION}.dmg" | awk '{print $1}')

cd "$TAP_REPO_ROOT"
git checkout main && git pull
git checkout -b "cask/v${VERSION}"

sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Casks/keydrop.rb
sed -i '' "s/sha256 \"[a-f0-9]*\"/sha256 \"${SHA256}\"/" Casks/keydrop.rb

git add Casks/keydrop.rb
git commit -m "keyDrop ${VERSION}"
git push -u origin "cask/v${VERSION}"
```
