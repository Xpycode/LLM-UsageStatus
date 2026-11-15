cask "llm-usagestatus" do
  version "0.3.0"
  sha256 "29701e0cb31e86c7fbb85de88abbe462fb254dde814a14bd7b230b43999dd0b0"

  url "https://github.com/Xpycode/LLM-UsageStatus/releases/download/v#{version}/LLM-UsageStatus-#{version}.dmg"
  name "LLM Usage Status"
  desc "HUD panel showing Codex, Claude Code and Mistral Vibe usage"
  homepage "https://github.com/Xpycode/LLM-UsageStatus"

  livecheck do
    url "https://raw.githubusercontent.com/Xpycode/LLM-UsageStatus/main/appcast.xml"
    strategy :sparkle, &:short_version
  end

  auto_updates true
  depends_on macos: :sequoia

  app "LLM-UsageStatus.app"

  uninstall quit: "com.sim.LLM-UsageStatus"

  zap trash: [
    "~/Library/Application Support/LLM-UsageStatus",
    "~/Library/Preferences/com.sim.LLM-UsageStatus.plist",
  ]

  caveats <<~EOS
    LLM Usage Status has no Dock icon. Press Control-Option-Command-L to show the panel.
    It reads usage for whichever of Codex, Claude Code and Mistral Vibe are installed.
  EOS
end
