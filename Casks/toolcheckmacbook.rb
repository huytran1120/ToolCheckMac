cask "toolcheckmacbook" do
  version "1.3.2"
  sha256 "f5765d663fe9d2f5ad58d251ade1f8ca3ad92971824615578af780b1e5477106"

  url "https://github.com/huytran1120/ToolCheckMac/releases/download/v#{version}/ToolCheckMacBook-v#{version}.dmg"
  name "ToolCheckMacBook"
  desc "All-in-one native offline macOS hardware inspection and diagnostic tool"
  homepage "https://huytran1120.github.io/ToolCheckMac/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: ">= :sonoma"

  app "ToolCheckMacBook.app"

  zap trash: [
    "~/Library/Preferences/com.toolcheckmacbook.plist",
    "~/Library/Saved Application State/com.toolcheckmacbook.savedState",
  ]
end
