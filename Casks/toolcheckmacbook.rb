cask "toolcheckmacbook" do
  version "1.2.0"
  sha256 "35e80d6035cfbb2e951ea2b1382fa0d461dbe5bd70f43859a35da33b6ffaea4b"

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
