cask "keydrop" do
  version "1.1.6"
  sha256 "REPLACE_WITH_SHA256"

  url "https://github.com/blas0/mac-os-apps/releases/download/keyDrop-v#{version}/keyDrop-#{version}.dmg",
      verified: "github.com/blas0/mac-os-apps/"
  name "keyDrop"
  desc "Local macOS menu-bar vault for API keys"
  homepage "https://github.com/blas0/mac-os-apps/tree/main/keyDrop"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :tahoe"

  app "keyDrop.app"

  zap trash: [
    "~/Library/Preferences/com.neurix.keydrop.plist",
    "~/Library/Application Support/com.neurix.keydrop",
    "~/Library/Caches/com.neurix.keydrop",
  ]
end
