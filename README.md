# Crystal Desktop

Install the published Crystal release for the current macOS user.

## Install

```sh
brew install --cask crystalos-ai/tap/crystal-desktop
```

Or download and run the reviewed installer:

```sh
/bin/sh -p -s -- <<'CRYSTAL_BOOTSTRAP'
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
LC_ALL=C
export PATH LC_ALL
unset BASH_ENV ENV CDPATH CURL_HOME CURL_CA_BUNDLE SSL_CERT_FILE SSL_CERT_DIR
umask 077
bootstrap_dir=
finish() {
  status=$?
  trap - 0 HUP INT TERM
  if [ -n "$bootstrap_dir" ]; then /bin/rm -rf "$bootstrap_dir"; fi
  exit "$status"
}
trap finish 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
bootstrap_dir=$(/usr/bin/mktemp -d /private/tmp/crystal-bootstrap.XXXXXXXX) || exit 1
suffix=${bootstrap_dir#/private/tmp/crystal-bootstrap.}
case "$suffix" in ''|*[!A-Za-z0-9]*) bootstrap_dir=; exit 1 ;; esac
if [ "${#suffix}" -ne 8 ] || [ "$bootstrap_dir" = "$suffix" ] || [ ! -d "$bootstrap_dir" ] || [ -L "$bootstrap_dir" ]; then bootstrap_dir=; exit 1; fi
if [ "$(CDPATH='' cd -P "$bootstrap_dir" && pwd -P)" != "$bootstrap_dir" ]; then bootstrap_dir=; exit 1; fi
printf '%s\n' 'Downloading the Crystal installer...'
fetch_status=0
(ulimit -f 256; exec /usr/bin/curl -q --fail --silent --show-error --location \
  --proto '=https' --proto-redir '=https' --tlsv1.2 \
  --connect-timeout 20 --max-time 60 --max-filesize 131072 \
  --output "$bootstrap_dir/install.sh" \
  --url https://raw.githubusercontent.com/crystalos-ai/homebrew-tap/main/install.sh) || fetch_status=$?
if [ "$fetch_status" -ne 0 ]; then
  printf '%s\n' 'Crystal: Installer download failed. No installer was run; retry the same command.' >&2
  exit "$fetch_status"
fi
script=$bootstrap_dir/install.sh
if [ ! -f "$script" ] || [ -L "$script" ] || [ ! -s "$script" ]; then
  printf '%s\n' 'Crystal: The installer download is empty or unsafe. Nothing was run.' >&2
  exit 1
fi
size=$(/usr/bin/wc -c < "$script" | /usr/bin/tr -d '[:space:]')
case "$size" in ''|*[!0-9]*) exit 1 ;; esac
if [ "$size" -gt 131072 ] || [ "$(/usr/bin/head -n 1 "$script")" != '#!/bin/sh -p' ] || [ "$(/usr/bin/tail -n 1 "$script")" != '# Crystal installer complete' ]; then
  printf '%s\n' 'Crystal: The installer download is incomplete or unexpected. Nothing was run.' >&2
  exit 1
fi
if ! /bin/sh -p -n "$script"; then
  printf '%s\n' 'Crystal: The installer download is not a complete shell script. Nothing was run.' >&2
  exit 1
fi
/bin/sh -p "$script" "$@"
CRYSTAL_BOOTSTRAP
```

The bootstrap completes a bounded private download before running it; a failed
or incomplete download never starts the installer. To preview changes or see
detailed output, add `--dry-run` or `--verbose` after `--` on the block's first
line. Homebrew remains the primary installation path.

Requires macOS 13 or later on native Apple silicon only, and an invitation to
a provisioned Crystal workspace. Public self-service signup is not offered.
Intel and Rosetta execution are not supported for this first release; Intel
qualification remains NOT RUN. A universal payload is not Intel qualification.
The installer checks exact package bytes, Developer ID Installer identity and
Gatekeeper acceptance, then installs into `~/Applications/Crystal.app` without
sudo. Installation does not sign in or change shell startup files. Open Crystal
to connect your workspace; terminal setup and startup at login are explicit
choices inside the app.

## Upgrade and reinstall

Finish sessions and use **Settings → App package → Reconcile completed work**
before quitting Crystal. Then run:

```sh
brew upgrade --greedy --cask crystal-desktop
```

Direct-installer users select the same governed path with `--upgrade` after
`--` on the bootstrap block's first line, or `/bin/sh -p install.sh --upgrade`
with the downloaded reviewed script. Existing app changes require Crystal's
current signed native update authority; a Homebrew pin does not override it.
Open the installed app afterward to finish normal startup and health checks.
Installer completion alone is not successful app activation.

`brew reinstall --cask crystal-desktop` reconciles an identical verified app
without replacing it or resetting history. After verified app-only removal,
installing the current published package again uses the exact retained signed
predecessor and fresh native update authority, preserves rollback and leaves
normal startup health pending. Unknown history never falls back to Installer
overwrite.

## Remove registration or the app

`brew uninstall --cask crystal-desktop` removes Homebrew registration only.
It leaves the app, user state and macOS Installer receipts unchanged and does
not stop running work.

Before app-only removal, open the installed app once and finish any pending
update or recovery. For guarded removal, finish your sessions and open
**Settings → App package → Remove app only…**. Crystal checks idle work and
coordinates removal of its own unchanged terminal and startup setup before
moving the verified app to `~/Applications/.crystal-removed`. Quit this copy
when the app confirms removal, then remove Homebrew registration separately
with `brew uninstall --cask crystal-desktop`.

Alternatively, finish sessions and reconcile completed work in Settings,
remove Crystal's owned terminal integration with **Remove setup…**, turn off
**Open Crystal when I log in**, and quit Crystal. Then run
`brew uninstall --zap --cask crystal-desktop` to request the same guarded
app-only retention. The helper independently refuses busy, changed or unsafe
state. The separate **Prepare removal…** action is a cleanup-and-disconnect
flow, not the app-only retention action.

App-only removal preserves sign-in, projects, session records, Installer
receipts and update history. It does not erase all data, certify remote cleanup
or stop organization-managed services. Keep the retained app and private
removal receipt for a governed reinstall.

## Recovery

If the app is damaged, ownership is unknown or a removal was interrupted,
stop and inspect the existing recovery state using a fresh signed Crystal
setup app for the exact currently authorized release. Settings → App package
offers **Repair with this setup app…** only when its authority and ownership
checks permit it. An explicitly retained UNVERIFIED copy is not a reinstall
predecessor. Do not erase update history or overwrite an app to bypass a refusal.
For connection or policy errors, run `crystal doctor` and share its check IDs
with your workspace administrator; installation does not grant workspace access.
