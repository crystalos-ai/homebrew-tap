# Crystal Desktop Homebrew tap

This is the official public distribution repository for Crystal Desktop.

The release infrastructure is being prepared. No installer or app release is
available here yet. The first release requires a signed, notarized current-user
package and verified installation journeys.

Qualified releases will provide both:

```sh
brew install --cask crystalos-ai/tap/crystal-desktop
```

```sh
curl -q --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/crystalos-ai/homebrew-tap/main/install.sh | /bin/sh -p
```

These commands become usable only after the first release is published.
Existing Crystal installations continue to update through Crystal's updater.

Release assets are immutable. The curl installer and Homebrew cask are updated
atomically after the published package and archive pass public download checks.
