#!/bin/bash
# cursorspacex installer
#
#   curl -fsSL https://csx.lou15.com/install.sh | bash
#   curl -fsSL https://csx.lou15.com/install.sh | bash -s uninstall
#
# What it does, and nothing more:
#   1. downloads the latest release zip from github.com/Louistuis/cursorspacex
#   2. copies CursorSpaceX.app into /Applications (asks for your password once)
#   3. clears the download quarantine flag, because the app is open source and
#      not notarized by Apple, so Gatekeeper would otherwise block it
#   4. opens it
set -euo pipefail

REPO="Louistuis/cursorspacex"
APP="CursorSpaceX.app"
DEST="${CURSORSPACEX_DEST:-/Applications}"
URL="${CURSORSPACEX_URL:-https://github.com/$REPO/releases/latest/download/CursorSpaceX.zip}"

b=$'\033[1m'; d=$'\033[2m'; g=$'\033[32m'; r=$'\033[31m'; n=$'\033[0m'
say()  { printf "  %s\n" "$*"; }
fail() { printf "\n  ${r}%s${n}\n\n" "$*"; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "cursorspacex is a mac app."
ver="$(sw_vers -productVersion)"
[ "${ver%%.*}" -ge 26 ] || fail "cursorspacex needs macOS 26 (Tahoe) or newer. this mac runs $ver."

# Only ask for a password when the destination needs it.
SUDO=""
if [ ! -w "$DEST" ] || { [ -e "$DEST/$APP" ] && [ ! -w "$DEST/$APP" ]; }; then SUDO="sudo"; fi

quit_app() {
    osascript -e 'tell application id "com.lou15.cursorspacex" to quit' >/dev/null 2>&1 || true
    pkill -x CursorSpaceX >/dev/null 2>&1 || true
    sleep 0.5
}

printf "\n  ${b}cursorspacex${n}\n\n"

if [ "${1:-}" = "uninstall" ]; then
    if [ -x "$DEST/$APP/Contents/MacOS/CursorSpaceX" ]; then
        say "putting the stock cursor back…"
        "$DEST/$APP/Contents/MacOS/CursorSpaceX" --uninstall-cleanup >/dev/null 2>&1 || true
    fi
    quit_app
    if [ -e "$DEST/$APP" ]; then
        [ -n "$SUDO" ] && say "your mac password removes the app (nothing shows while you type)."
        $SUDO rm -rf "$DEST/$APP"
    fi
    rm -rf "$HOME/Library/Application Support/CursorSpaceX"
    defaults delete com.lou15.cursorspacex >/dev/null 2>&1 || true
    printf "\n  ${g}✓${n} cursorspacex is gone. thanks for trying it.\n\n"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "downloading the latest release…"
curl -fL --progress-bar "$URL" -o "$TMP/CursorSpaceX.zip" || fail "the download failed. check your connection and try again."
ditto -x -k "$TMP/CursorSpaceX.zip" "$TMP/x" || fail "the download looks broken. try again."
[ -d "$TMP/x/$APP" ] || fail "the download didn't contain the app. try again."

quit_app
if [ -n "$SUDO" ]; then
    say "installing to $DEST."
    say "${b}type your mac password and press return${n} ${d}(nothing shows while you type, that's normal)${n}"
    sudo -v || fail "no password, no install. run the line again when you're ready."
fi
$SUDO rm -rf "$DEST/$APP"
$SUDO ditto "$TMP/x/$APP" "$DEST/$APP"
$SUDO xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

installed="$(defaults read "$DEST/$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "")"
printf "\n  ${g}✓${n} cursorspacex ${installed} is in ${DEST}. opening it now.\n\n"
[ "${CURSORSPACEX_NO_OPEN:-}" = "1" ] || open "$DEST/$APP"
