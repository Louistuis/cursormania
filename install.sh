#!/bin/bash
# cursormania installer
#
#   curl -fsSL https://csx.lou15.com/install.sh | bash
#   curl -fsSL https://csx.lou15.com/install.sh | bash -s uninstall
#
# What it does, and nothing more:
#   1. downloads the latest release zip from github.com/Louistuis/cursormania
#   2. copies CursorMania.app into /Applications (asks for your password once)
#   3. clears the download quarantine flag, because the app is open source and
#      not notarized by Apple, so Gatekeeper would otherwise block it
#   4. opens it
set -euo pipefail

REPO="Louistuis/cursormania"
APP="CursorMania.app"
DEST="${CURSORMANIA_DEST:-/Applications}"
URL="${CURSORMANIA_URL:-https://github.com/$REPO/releases/latest/download/CursorMania.zip}"

b=$'\033[1m'; d=$'\033[2m'; g=$'\033[32m'; r=$'\033[31m'; n=$'\033[0m'
say()  { printf "  %s\n" "$*"; }
fail() { printf "\n  ${r}%s${n}\n\n" "$*"; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "cursormania is a mac app."
ver="$(sw_vers -productVersion)"
[ "${ver%%.*}" -ge 26 ] || fail "cursormania needs macOS 26 (Tahoe) or newer. this mac runs $ver."

# Only ask for a password when the destination needs it.
SUDO=""
OLD="CursorSpaceX.app"   # cursormania was called cursorspacex until 0.3.0
if [ ! -w "$DEST" ] || { [ -e "$DEST/$APP" ] && [ ! -w "$DEST/$APP" ]; } || { [ -e "$DEST/$OLD" ] && [ ! -w "$DEST/$OLD" ]; }; then SUDO="sudo"; fi

quit_app() {
    osascript -e 'tell application id "com.lou15.cursorspacex" to quit' >/dev/null 2>&1 || true
    pkill -x CursorMania >/dev/null 2>&1 || true
    pkill -x CursorSpaceX >/dev/null 2>&1 || true   # the app's old name
    sleep 0.5
}

printf "\n  ${b}cursormania${n}\n\n"

if [ "${1:-}" = "uninstall" ]; then
    if [ -x "$DEST/$APP/Contents/MacOS/CursorMania" ]; then
        say "putting the stock cursor back…"
        "$DEST/$APP/Contents/MacOS/CursorMania" --uninstall-cleanup >/dev/null 2>&1 || true
    fi
    quit_app
    if [ -e "$DEST/$APP" ]; then
        [ -n "$SUDO" ] && say "your mac password removes the app (nothing shows while you type)."
        $SUDO rm -rf "$DEST/$APP"
    fi
    [ -e "$DEST/$OLD" ] && $SUDO rm -rf "$DEST/$OLD"
    rm -rf "$HOME/Library/Application Support/CursorSpaceX"
    defaults delete com.lou15.cursorspacex >/dev/null 2>&1 || true
    printf "\n  ${g}✓${n} cursormania is gone. thanks for trying it.\n\n"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "downloading the latest release…"
curl -fL --progress-bar "$URL" -o "$TMP/CursorMania.zip" || fail "the download failed. check your connection and try again."
ditto -x -k "$TMP/CursorMania.zip" "$TMP/x" || fail "the download looks broken. try again."
[ -d "$TMP/x/$APP" ] || fail "the download didn't contain the app. try again."

quit_app
if [ -n "$SUDO" ]; then
    say "installing to $DEST."
    say "${b}type your mac password and press return${n} ${d}(nothing shows while you type, that's normal)${n}"
    sudo -v || fail "no password, no install. run the line again when you're ready."
fi
$SUDO rm -rf "$DEST/$APP" "$DEST/$OLD"
$SUDO ditto "$TMP/x/$APP" "$DEST/$APP"
$SUDO xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

installed="$(defaults read "$DEST/$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "")"
printf "\n  ${g}✓${n} cursormania ${installed} is in ${DEST}. opening it now.\n\n"
[ "${CURSORMANIA_NO_OPEN:-}" = "1" ] || open "$DEST/$APP"
