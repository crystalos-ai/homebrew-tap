cask "crystal-desktop" do
  version "1.1648.3"
  sha256 "7081682199bbfa86b9e8eec1d1648f2b01d0d34814b26f0b60209b51d8b1c862"

  url "https://github.com/crystalos-ai/homebrew-tap/releases/download/desktop-stable-1.1648.3/Crystal-homebrew.tar.gz"
  name "Crystal Desktop"
  desc "Governed coding agent sessions for your projects"
  homepage "https://crystalos.com/"

  livecheck do
    skip "Release pins are updated only after protected release qualification"
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :ventura

  installer script: {
    executable: "install.sh",
    args:       ["--package", "#{staged_path}/Crystal.pkg", "--upgrade"],
    sudo:       false,
  }

  uninstall script: {
    executable: "uninstall.sh",
    sudo:       false,
  }

  zap script: {
    executable: "remove.sh",
    sudo:       false,
  }

  caveats <<~EOS
    Crystal installs in ~/Applications/Crystal.app for the current user.
    Open it, connect your account, then choose a project and start Claude Code.
    Shell integration and login startup are separate choices inside the app.
    Quit Crystal before brew upgrade --greedy --cask crystal-desktop.
    Package upgrades use Crystal's signed release policy and require normal
    startup afterward to complete health checks. Reinstall reconciles an identical
    app or uses the verified retained predecessor after app-only removal. It never
    erases update history or treats damaged bytes as an authorized predecessor.
    Plain brew uninstall removes Homebrew registration and leaves the app.
    To remove the app too, finish Settings cleanup, quit Crystal, then use
    brew uninstall --zap --cask crystal-desktop. This retains the app outside
    its installation path and preserves sign-in, projects and update history.
  EOS
end
