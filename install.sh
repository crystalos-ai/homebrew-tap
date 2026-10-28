#!/bin/sh -p
# Use /bin/sh -p when piping this script; privileged shell startup ignores
# exported functions and startup hooks without changing the installing UID.
# Rendered from reviewed release metadata. Runtime arguments never select a URL,
# digest, signing identity or different release. Existing app changes use C5.
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
LC_ALL=C
export PATH LC_ALL
unset BASH_ENV ENV CDPATH CURL_HOME CURL_CA_BUNDLE SSL_CERT_FILE SSL_CERT_DIR
umask 077

readonly VERSION='1.1648.3'
readonly CHANNEL='stable'
readonly PACKAGE_URL='https://github.com/crystalos-ai/homebrew-tap/releases/download/desktop-stable-1.1648.3/Crystal.pkg'
readonly PACKAGE_SHA256='f8f8ebdf88dc45e11fe2b9dd4ad0321636ff39ee48977cb0740d49a0a15cf04e'
readonly PACKAGE_SIZE='67991469'
readonly TEAM_ID='2G38T3TR52'
readonly APP_SOURCE='c9d7a4e7c636048f4a775849789c2742fd2dca3b'
readonly APP_GRAPH_SHA256='a09cc3865815f7eac06cb63087fcc3880c3196bdedb698067cb1e17e82d1222f'

dry_run=false
verbose=false
governed_update=false
existing_install=false
local_package=
work_dir=
command_pid=
refuse() { printf 'Crystal: %s\n' "$1" >&2; exit 1; }
note() { printf '%s\n' "$1"; }
detail() { if [ "$verbose" = true ]; then note "$1"; fi; }
update_guidance() {
    # Read only a bounded prefix. Never echo raw native stderr: network errors
    # can include private paths or URLs. Recognized reasons select fixed advice.
    /usr/bin/head -c 8192 "$1" 2>/dev/null | /usr/bin/awk '
        BEGIN {
            upgrade="crystal-edge: desktop package upgrade is unsupported: "
            idle="crystal-edge: current-user package idle check is unsupported: "
            reasons[upgrade "another update or unresolved recovery owns this installation"]="pending"
            reasons[upgrade "open Crystal to confirm its installed release or finish the pending update first"]="pending"
            reasons[upgrade "governed activation did not complete; retained recovery state remains"]="pending"
            reasons[upgrade "activation readback differs; do not retry or remove retained recovery files"]="pending"
            reasons[upgrade "activation readback could not be authenticated"]="pending"
            reasons[idle "a launch still has unresolved work; reconcile the exact attempt before repair/removal"]="work"
            reasons[idle "publication transaction is unresolved; resume its exact project before removal/repair"]="work"
            reasons[idle "a current or legacy edge is listening; no managed edge will be stopped"]="running"
            reasons[idle "an edge owns this user\047s listener; finish work and quit before changing the app"]="running"
            reasons[upgrade "installed app cannot be authenticated; use explicit repair"]="repair"
            reasons[upgrade "same-release differences require explicit repair; downgrade is refused"]="repair"
            reasons[upgrade "current stable release authority is unavailable or invalid"]="authority"
            reasons[upgrade "current stable authority does not name this exact eligible package"]="authority"
            reasons[upgrade "stable release authority expired during staging"]="authority"
            reasons[upgrade "stable release authority changed during staging"]="authority"
            reasons[upgrade "installed and setup release authority differ"]="authority"
        }
        $0 in reasons { found[reasons[$0]]=1 }
        END {
            print "Crystal package update details:"
            if (found["pending"]) print "  A previous update needs attention. Open Crystal to finish or inspect it before retrying. Keep retained recovery files."
            else if (found["work"]) print "  Open Crystal and use Reconcile completed work in Settings before trying this package operation again."
            else if (found["running"]) print "  Quit Crystal, including its menu bar app, before trying the same package operation. Managed services will not be stopped."
            else if (found["repair"]) print "  The installed app needs repair. Open the signed setup app for this release and choose Settings > App package > Repair with this setup app."
            else if (found["authority"]) print "  This package is not currently authorized for the installed app. Open Crystal to inspect its release status and use the current published package."
            else print "  Crystal did not provide a recognized update reason. Open Crystal to inspect release status before retrying."
        }
    ' >&2 || :
}
usage() {
    printf '%s\n' 'Install the pinned Crystal release for your current macOS account.' \
      'Usage: install.sh [--dry-run] [--verbose] [--no-modify-path]' \
      '                  [--version VERSION] [--channel stable|dogfood]' \
      '                  [--package /absolute/path/to/Crystal.pkg]' \
      '  --help             Show this help without changing anything.' \
      '  --dry-run          Check this Mac and print the plan; do not download or install.' \
      '  --verbose          Print the pinned package source and verification steps.' \
      '  --version VALUE    Require the pinned version (no release switching).' \
      '  --channel VALUE    Require the pinned channel (no channel switching).' \
      '  --no-modify-path   Accepted explicitly; shell profiles are never modified.' \
      '  --upgrade          Reconcile or update an existing app through the signed Crystal release policy.' \
      '  --package PATH     Use bundled package bytes with the same immutable pin and checks.'
}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help) usage; exit 0 ;;
        --dry-run) dry_run=true; shift ;;
        --verbose) verbose=true; shift ;;
        --no-modify-path) shift ;;
        --upgrade) governed_update=true; shift ;;
        --version)
            [ "$#" -ge 2 ] || refuse '--version needs a value.'
            [ "$2" = "$VERSION" ] || refuse 'This script installs only its pinned version. Get the matching published installer.'
            shift 2 ;;
        --channel)
            [ "$#" -ge 2 ] || refuse '--channel needs stable or dogfood.'
            case "$2" in stable|dogfood) ;; *) refuse '--channel must be stable or dogfood.' ;; esac
            [ "$2" = "$CHANNEL" ] || refuse 'This script installs only its pinned channel. Get the matching published installer.'
            shift 2 ;;
        --package)
            [ "$#" -ge 2 ] || refuse '--package needs an absolute file path.'
            [ -z "$local_package" ] || refuse '--package may be given only once.'
            case "$2" in /*) ;; *) refuse '--package needs an absolute file path.' ;; esac
            local_package=$2; shift 2 ;;
        *) refuse 'Unknown option. Use --help to see supported options.' ;;
    esac
done

# The renderer validates before substitution; these also refuse incomplete or
# inconsistent templates. Inputs are data, never eval or command fragments.
printf '%s\n' "$VERSION" | /usr/bin/grep -Eq '^[0-9][A-Za-z0-9.+-]{0,63}$' || refuse 'This installer has invalid release metadata.'
case "$CHANNEL" in stable|dogfood) ;; *) refuse 'This installer has invalid channel metadata.' ;; esac
printf '%s\n' "$PACKAGE_URL" | /usr/bin/grep -Eq '^https://[A-Za-z0-9.-]+(:[0-9]+)?/[-A-Za-z0-9._~/%+]+$' || refuse 'This installer has an invalid package URL.'
printf '%s\n' "$PACKAGE_SHA256" | /usr/bin/grep -Eq '^[0-9a-f]{64}$' || refuse 'This installer has an invalid package digest.'
printf '%s\n' "$APP_SOURCE" | /usr/bin/grep -Eq '^[0-9a-f]{40}$' || refuse 'This installer has an invalid app source.'
printf '%s\n' "$APP_GRAPH_SHA256" | /usr/bin/grep -Eq '^[0-9a-f]{64}$' || refuse 'This installer has an invalid app graph.'
printf '%s\n' "$TEAM_ID" | /usr/bin/grep -Eq '^[A-Z0-9]{10}$' || refuse 'This installer has an invalid signing team.'
case "$PACKAGE_SIZE" in ''|*[!0-9]*|0*) refuse 'This installer has an invalid package size.' ;; esac
[ "${#PACKAGE_SIZE}" -le 10 ] && [ "$PACKAGE_SIZE" -le 1073741824 ] || refuse 'This installer package exceeds the supported size limit.'

[ "$(/usr/bin/uname -s)" = Darwin ] || refuse 'Crystal Desktop requires macOS 13 or later.'
case "$(/usr/bin/uname -m)" in
  arm64) ;;
  *) refuse 'This Crystal release requires native Apple silicon. Intel and Rosetta execution are not supported.' ;;
esac
os_version=$(/usr/bin/sw_vers -productVersion) || refuse 'Cannot check the macOS version.'
os_major=${os_version%%.*}
case "$os_major" in ''|*[!0-9]*) refuse 'Cannot check the macOS version.' ;; esac
[ "${#os_major}" -le 3 ] && [ "$os_major" -ge 13 ] || refuse 'Crystal Desktop requires macOS 13 or later.'
install_uid=$(/usr/bin/id -u) || refuse 'Cannot verify the installing user.'
case "$install_uid" in ''|0*|*[!0-9]*) refuse 'Run this installer as your own account, without sudo.' ;; esac
install_user=$(/usr/bin/id -un) || refuse 'Cannot verify the installing user.'
case "$install_user" in ''|*[!A-Za-z0-9._-]*) refuse 'Cannot verify the installing user.' ;; esac
account=$(/usr/bin/dscl -plist /Search -read "/Users/$install_user" NFSHomeDirectory UniqueID) || refuse 'Cannot read the account home directory.'
home_marked=$(printf '%s' "$account" | /usr/bin/plutil -extract 'dsAttrTypeStandard:NFSHomeDirectory.0' raw -expect string -n -o - - && printf '.') || refuse 'Cannot read the account home directory.'
install_home=${home_marked%.}
uid_marked=$(printf '%s' "$account" | /usr/bin/plutil -extract 'dsAttrTypeStandard:UniqueID.0' raw -expect string -n -o - - && printf '.') || refuse 'Cannot verify your home directory owner.'
account_uid=${uid_marked%.}
[ "$account_uid" = "$install_uid" ] || refuse 'Your account and home directory do not match.'
case "$install_home" in /) refuse 'Your home directory is unavailable.' ;; /*) ;; *) refuse 'Your home directory is unavailable.' ;; esac
case "$install_home" in *'
'*) refuse 'Your home directory contains unsupported control characters.' ;; esac
if printf '%s' "$install_home" | /usr/bin/grep -q '[[:cntrl:]]'; then refuse 'Your home directory contains unsupported control characters.'; fi
safe_directory() {
    [ -d "$1" ] && [ ! -L "$1" ] || return 1
    physical=$(CDPATH='' cd -P "$1" && pwd -P) || return 1
    [ "$physical" = "$1" ] || return 1
    metadata=$(/usr/bin/stat -f '%u %Lp' "$1") || return 1
    owner=${metadata%% *}
    mode=${metadata#* }
    [ "$owner" = "$install_uid" ] || return 1
    case "$mode" in [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) ;; *) return 1 ;; esac
    [ "$((0$mode & 022))" -eq 0 ]
}
safe_directory "$install_home" || refuse 'Your home must be a real, private, user-owned folder.'
applications=$install_home/Applications
if [ -e "$applications" ] || [ -L "$applications" ]; then
    safe_directory "$applications" || refuse 'Your Applications folder must be a real, private, user-owned folder.'
fi
# App retirement retains C5 state. An empty app path must not turn a governed
# reinstall into a first install or permit a different/downgraded release.
history_parent=$install_home
for history_part in Library 'Application Support' CrystalOS; do
    history_parent=$history_parent/$history_part
    if [ -e "$history_parent" ] || [ -L "$history_parent" ]; then
        safe_directory "$history_parent" || refuse 'Existing Crystal history cannot be inspected safely. Use the signed setup app for governed repair.'
    fi
done
if [ -e "$history_parent/desktop" ] || [ -L "$history_parent/desktop" ]; then
    if [ "$governed_update" = false ]; then
        refuse 'Crystal update history is retained. Open a signed setup app for the exact authorized release and choose Settings → App package → Repair with this setup app. Fresh installation never resets update or recovery history.'
    fi
    existing_install=true
fi
destination=$applications/Crystal.app
if [ -e "$destination" ] || [ -L "$destination" ]; then
    if [ "$governed_update" = false ]; then
        refuse "$destination already exists. If this is a working Crystal app, open it and use its update controls. Otherwise, inspect this path before retrying; this installer never replaces or deletes an existing entry."
    fi
    safe_directory "$destination" || refuse 'The existing app entry is unsafe. Inspect it before using a signed setup app for repair.'
    existing_install=true
fi
if [ -n "$local_package" ]; then
    case "$local_package" in /*) ;; *) refuse '--package needs an absolute file path.' ;; esac
    case "$local_package" in *'
'*) refuse 'The package path contains unsupported control characters.' ;; esac
    if printf '%s' "$local_package" | /usr/bin/grep -q '[[:cntrl:]]'; then refuse 'The package path contains unsupported control characters.'; fi
    [ -f "$local_package" ] && [ ! -L "$local_package" ] || refuse 'The bundled package must be a regular file, not a symbolic link.'
    [ "$(/usr/bin/stat -f '%z' "$local_package")" = "$PACKAGE_SIZE" ] || refuse 'The bundled package size does not match this installer.'
fi

note "Crystal $VERSION · $CHANNEL"
note "Install location: $destination"
detail 'Installs for your account without changing shell profiles or login startup.'
detail 'The package checks that the destination is still empty and Crystal is closed.'
detail "Package: $PACKAGE_URL"
detail "App source: $APP_SOURCE"
detail "Expected package: $PACKAGE_SIZE bytes · SHA-256 $PACKAGE_SHA256"
if [ "$dry_run" = true ]; then
    note 'Dry run complete. Nothing was downloaded, copied or installed.'
    exit 0
fi

cleanup() {
    if [ -n "$command_pid" ]; then
        kill -TERM "$command_pid" 2>/dev/null || :
        # Bound cleanup for this invocation's tracked child PID. Do not use
        # process groups, and stop signaling once this child is observed gone.
        child_running=true
        for _ in 1 2; do
            if ! kill -0 "$command_pid" 2>/dev/null; then child_running=false; break; fi
            /bin/sleep 1
        done
        if [ "$child_running" = true ] && kill -0 "$command_pid" 2>/dev/null; then
            kill -KILL "$command_pid" 2>/dev/null || :
        fi
        wait "$command_pid" 2>/dev/null || :
    fi
    if [ -n "$work_dir" ]; then /bin/rm -rf "$work_dir"; fi
}
trap cleanup 0
trap 'note "Installation interrupted. Any completed Installer changes were not rolled back." >&2; exit 129' HUP
trap 'note "Installation interrupted. Any completed Installer changes were not rolled back." >&2; exit 130' INT
trap 'note "Installation interrupted. Any completed Installer changes were not rolled back." >&2; exit 143' TERM
work_dir=$(/usr/bin/mktemp -d /private/tmp/crystal-install.XXXXXXXX) || refuse 'Cannot create a private download folder.'
temporary_name=${work_dir#/private/tmp/crystal-install.}
case "$temporary_name" in ''|*[!A-Za-z0-9]*) work_dir=; refuse 'Cannot verify the private download folder.' ;; esac
[ "$work_dir" != "$temporary_name" ] && [ "${#temporary_name}" -eq 8 ] || { work_dir=; refuse 'Cannot verify the private download folder.'; }
safe_directory "$work_dir" || refuse 'The private download folder is unsafe.'
package=$work_dir/Crystal.pkg
# curl's size check may rely on Content-Length on older macOS. A per-child
# kernel file cap also bounds chunked downloads (512/1024-byte shell units),
# followed by exact size and digest checks before any package is executed.
file_blocks=$(((PACKAGE_SIZE + 511) / 512))
if [ -n "$local_package" ]; then
    detail 'Copying the bundled package to a private verification folder.'
    (ulimit -f "$file_blocks"; exec /bin/cp -P "$local_package" "$package") &
else
    note 'Downloading the pinned package…'
    download_progress=--silent
    if [ -t 2 ]; then download_progress=--progress-bar; fi
    (ulimit -f "$file_blocks"; exec /usr/bin/curl -q --fail "$download_progress" --show-error --location \
        --proto '=https' --proto-redir '=https' --tlsv1.2 \
        --connect-timeout 20 --max-time 300 --max-filesize "$PACKAGE_SIZE" \
        --output "$package" --url "$PACKAGE_URL") &
fi
command_pid=$!
if wait "$command_pid"; then command_pid=; else command_pid=; refuse 'Package transfer did not finish. Nothing was installed; retry this same installer.'; fi
[ -f "$package" ] && [ ! -L "$package" ] || refuse 'The downloaded package is not a regular file.'
[ "$(/usr/bin/stat -f '%z' "$package")" = "$PACKAGE_SIZE" ] || refuse 'Package size verification failed. Nothing was installed.'
hash_output=$(/usr/bin/shasum -a 256 "$package") || refuse 'Cannot verify the package digest.'
[ "${hash_output%% *}" = "$PACKAGE_SHA256" ] || refuse 'Package digest verification failed. Nothing was installed.'
detail 'Package bytes match. Checking the Apple installer signature and Gatekeeper.'
if ! /usr/sbin/pkgutil --check-signature "$package" > "$work_dir/signature.txt" 2>&1; then
    refuse 'The package signature is not trusted. Nothing was installed.'
fi
# Only the first certificate in the validated chain is the signing leaf.
# Never accept a matching Team string elsewhere in certificate/report text.
/usr/bin/awk -v team="$TEAM_ID" '
    /^[[:space:]]*Certificate Chain:[[:space:]]*$/ { chains++; chain=1; next }
    chain && /^[[:space:]]*1[.][[:space:]]/ {
        leaves++; line=$0; sub(/^[[:space:]]*1[.][[:space:]]*/, "", line)
        suffix=" (" team ")"
        if (index(line, "Developer ID Installer: ")==1 && length(line)>length("Developer ID Installer: ")+length(suffix) && substr(line,length(line)-length(suffix)+1)==suffix) valid++
    }
    END { exit !(chains==1 && leaves==1 && valid==1) }
' "$work_dir/signature.txt" || refuse 'The package was not signed by the pinned Crystal installer team. Nothing was installed.'
/usr/sbin/spctl --assess --type install "$package" > "$work_dir/gatekeeper.txt" 2>&1 || refuse 'macOS did not accept this package for installation. Nothing was installed.'
if [ "$existing_install" = true ]; then
    note 'Verified. Checking the existing app through the Crystal release policy…'
    # Expanding the pinned signed package never runs its scripts. Only the fixed
    # signed setup helper may mutate an existing app, through the C5 owner.
    /usr/sbin/pkgutil --expand-full "$package" "$work_dir/expanded" > "$work_dir/expand.txt" 2>&1 || refuse 'The pinned setup package could not be inspected. The app was not replaced.'
    setup=$work_dir/expanded/Crystal-component.pkg/Payload/Crystal.app
    for directory in "$setup" "$setup/Contents" "$setup/Contents/Helpers" "$setup/Contents/Resources"; do
        safe_directory "$directory" || refuse 'The expanded setup app is unsafe. The app was not replaced.'
    done
    helper=$setup/Contents/Helpers/crystal-edge
    info=$setup/Contents/Info.plist
    provenance=$setup/Contents/Resources/package-provenance.json
    for file in "$helper" "$info" "$provenance" "$setup/Contents/Resources/bootstrap.json"; do
        [ -f "$file" ] && [ ! -L "$file" ] || refuse 'The setup app is incomplete. The app was not replaced.'
    done
    [ -x "$helper" ] || refuse 'The setup helper cannot run. The app was not replaced.'
    setup_identifier=$(/usr/bin/plutil -extract CFBundleIdentifier raw -expect string -n -o - "$info" && printf '.') || refuse 'The setup app identity is unavailable.'
    setup_version=$(/usr/bin/plutil -extract CFBundleVersion raw -expect string -n -o - "$info" && printf '.') || refuse 'The setup app version is unavailable.'
    setup_source=$(/usr/bin/plutil -extract source_revision raw -expect string -n -o - "$provenance" && printf '.') || refuse 'The sealed setup app source is unavailable.'
    setup_release=$(/usr/bin/plutil -extract release_id raw -expect string -n -o - "$provenance" && printf '.') || refuse 'The sealed setup release is unavailable.'
    [ "$setup_identifier" = 'com.crystalos.desktop.' ] && [ "$setup_version" = "$VERSION." ] && [ "$setup_source" = "$APP_SOURCE." ] || refuse 'The setup app does not match this pinned release.'
    /usr/bin/codesign --verify --deep --strict --all-architectures "$setup" > "$work_dir/setup-verify.txt" 2>&1 || refuse 'The setup app signature is invalid.'
    /usr/bin/codesign -d --verbose=4 "$setup" > "$work_dir/setup-identity.txt" 2>&1 || refuse 'The setup app signing identity is unavailable.'
    /usr/bin/awk -v team="$TEAM_ID" '/^TeamIdentifier=/ { count++; if ($0 == "TeamIdentifier=" team) valid++ } END { exit !(count==1 && valid==1) }' "$work_dir/setup-identity.txt" || refuse 'The setup app belongs to another signing team.'
    /usr/sbin/spctl --assess --type execute "$setup" > "$work_dir/setup-gatekeeper.txt" 2>&1 || refuse 'macOS did not accept the setup app.'
    # The helper independently verifies the entire pinned app graph and fresh
    # C5 signatures before deciding reconciliation versus a governed upgrade.
    # It receives no inherited app credentials or path/tool overrides.
    # Do not apply RLIMIT_FSIZE here: the C5 stager writes the signed disk image
    # and app. The trusted helper emits a small receipt, bounded below.
    (exec /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C \
        "$helper" desktop-package upgrade --desktop-bootstrap "$setup/Contents/Resources/bootstrap.json" \
        --expected-app-graph "$APP_GRAPH_SHA256" --expected-app-source "$APP_SOURCE") > "$work_dir/update.json" 2> "$work_dir/update-error.txt" &
    command_pid=$!
    if wait "$command_pid"; then command_pid=; else
        command_pid=
        update_guidance "$work_dir/update-error.txt"
        refuse 'Crystal could not confirm the package update. Open Crystal to inspect its release status before retrying; no rollback or remote cleanup is claimed.'
    fi
    [ "$(/usr/bin/stat -f '%z' "$work_dir/update.json")" -le 65536 ] || refuse 'The update response exceeded its bound. Inspect Crystal before retrying.'
    result_schema=$(/usr/bin/plutil -extract schema_version raw -expect integer -n -o - "$work_dir/update.json") || refuse 'The package update response is incomplete.'
    result_state=$(/usr/bin/plutil -extract state raw -expect string -n -o - "$work_dir/update.json") || refuse 'The package update response is incomplete.'
    result_path=$(/usr/bin/plutil -extract canonical_app raw -expect string -n -o - "$work_dir/update.json" && printf '.') || refuse 'The package update response is incomplete.'
    result_release=$(/usr/bin/plutil -extract release_id raw -expect string -n -o - "$work_dir/update.json" && printf '.') || refuse 'The package update response is incomplete.'
    result_health=$(/usr/bin/plutil -extract health_verified raw -expect bool -n -o - "$work_dir/update.json") || refuse 'The package update response is incomplete.'
    result_graph=$(/usr/bin/plutil -extract app_graph_sha256 raw -expect string -n -o - "$work_dir/update.json") || refuse 'The package update graph is unavailable.'
    result_source=$(/usr/bin/plutil -extract app_source raw -expect string -n -o - "$work_dir/update.json") || refuse 'The package update source is unavailable.'
    result_manifest=$(/usr/bin/plutil -extract manifest_sha256 raw -expect string -n -o - "$work_dir/update.json") || refuse 'The package update manifest is unavailable.'
    result_generation=$(/usr/bin/plutil -extract desired_generation raw -expect integer -n -o - "$work_dir/update.json") || refuse 'The package update generation is unavailable.'
    result_changed=$(/usr/bin/plutil -extract app_changed raw -expect bool -n -o - "$work_dir/update.json") || refuse 'The package update result is incomplete.'
    [ "$result_schema" = 1 ] && [ "$result_path" = "$destination." ] && [ "$result_release" = "$setup_release" ] && [ "$result_health" = false ] || refuse 'The package update result differs from the requested release. Inspect Crystal before retrying.'
    [ "$result_graph" = "$APP_GRAPH_SHA256" ] && [ "$result_source" = "$APP_SOURCE" ] || refuse 'The package update graph or source differs from this installer.'
    printf '%s\n' "$result_manifest" | /usr/bin/grep -Eq '^[0-9a-f]{64}$' || refuse 'The package update manifest is invalid.'
    printf '%s\n' "$result_generation" | /usr/bin/grep -Eq '^[1-9][0-9]{0,19}$' || refuse 'The package update generation is invalid.'
    case "$result_state:$result_changed" in reconciled:false|updated_pending_health:true|reinstalled_pending_health:true) ;; *) refuse 'Crystal did not confirm the requested package operation.' ;; esac
    safe_directory "$destination" || refuse 'The canonical app is unavailable after the package operation.'
    /usr/bin/codesign --verify --deep --strict --all-architectures "$destination" > "$work_dir/installed-verify.txt" 2>&1 || refuse 'The canonical app signature could not be rechecked. Inspect Crystal before retrying.'
    installed_version=$(/usr/bin/plutil -extract CFBundleVersion raw -expect string -n -o - "$destination/Contents/Info.plist" && printf '.') || refuse 'The installed app version is unavailable.'
    [ "$installed_version" = "$VERSION." ] || refuse 'The installed version differs from the requested package. Inspect Crystal before retrying.'
    note "Crystal $VERSION package is registered at: $destination"
    note 'Open Crystal to complete its normal startup and health checks. Package registration does not verify app or project health.'
    exit 0
fi
note 'Verified. Installing Crystal for your account…'
/usr/sbin/installer -pkg "$package" -target CurrentUserHomeDirectory > "$work_dir/installer.txt" 2>&1 &
command_pid=$!
if wait "$command_pid"; then command_pid=; else
    command_pid=
    note 'Apple Installer details (last 12 lines):' >&2
    # Diagnostics are displayed as bounded, printable text, never commands.
    # Surface the package guard's recovery advice before private logs are removed.
    /usr/bin/tail -n 12 "$work_dir/installer.txt" | /usr/bin/awk '
        { line=substr($0,1,400); gsub(/[^[:print:]]/, "?", line)
          if (line !~ /^[[:space:]]*$/) print "  " line }
    ' >&2 || :
    refuse 'Apple Installer did not finish. Check ~/Applications/Crystal.app before retrying; partial installation is not claimed to be rolled back.'
fi
# Installer success alone does not prove that the current-user app was written.
# Check the canonical bundle without launching it or changing any installed files.
installed_app_present() {
    for directory in "$destination" "$destination/Contents" "$destination/Contents/MacOS"; do
        safe_directory "$directory" || return 1
    done
    info=$destination/Contents/Info.plist
    executable=$destination/Contents/MacOS/Crystal
    [ -f "$info" ] && [ ! -L "$info" ] && [ -f "$executable" ] && [ ! -L "$executable" ] && [ -x "$executable" ] || return 1
    identifier=$(/usr/bin/plutil -extract CFBundleIdentifier raw -expect string -n -o - "$info" 2>/dev/null && printf '.') || return 1
    main_executable=$(/usr/bin/plutil -extract CFBundleExecutable raw -expect string -n -o - "$info" 2>/dev/null && printf '.') || return 1
    installed_version=$(/usr/bin/plutil -extract CFBundleVersion raw -expect string -n -o - "$info" 2>/dev/null && printf '.') || return 1
    [ "$identifier" = 'com.crystalos.desktop.' ] && [ "$main_executable" = 'Crystal.' ] && [ "$installed_version" = "$VERSION." ]
}
installed_app_present || refuse "Apple Installer finished, but a complete Crystal $VERSION app was not found at $destination. Inspect this location before retrying; this installer never removes a partial installation."
note "Installed Crystal at: $destination"
note 'Next steps:'
note '  1. Open Crystal:'
# Show a copyable command; expand HOME only when the customer runs it.
# shellcheck disable=SC2016
note '  open "$HOME/Applications/Crystal.app"'
note '  2. Sign in to your Crystal account.'
note '  3. Choose a project.'
note '  4. Start your first Claude session.'
note 'Terminal commands are optional in Settings.'
# Crystal installer complete
