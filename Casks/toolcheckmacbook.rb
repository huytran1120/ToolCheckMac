cask "toolcheckmacbook" do
  version "1.3.4"
  sha256 "68a483984f278454287c71d243d7bf9a56220ce3560dbc8f72254a876c8dd962"

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
