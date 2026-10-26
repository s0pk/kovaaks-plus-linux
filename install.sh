#!/usr/bin/env bash
# Installs the built binary (./dist/kovaaks-plus, see build.sh) for the current user: no root needed.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
[ -x "$root/dist/kovaaks-plus" ] || { echo "Run ./build.sh first." >&2; exit 1; }

install -Dm755 "$root/dist/kovaaks-plus"            "$HOME/.local/bin/kovaaks-plus"
[ -x "$root/dist/kovaaks-plus-ui" ] && install -Dm755 "$root/dist/kovaaks-plus-ui" "$HOME/.local/bin/kovaaks-plus-ui" || echo "No native UI built (dist/kovaaks-plus-ui): the browser window will be used."
install -Dm644 "$root/packaging/kovaaks-plus.png"    "$HOME/.local/share/icons/hicolor/256x256/apps/kovaaks-plus.png"
install -Dm644 "$root/packaging/kovaaks-plus.desktop" "$HOME/.local/share/applications/kovaaks-plus.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
echo "Installed. Launch 'Kovaak's Plus' from your app menu, or run: kovaaks-plus"
echo "Check your setup with: kovaaks-plus --diagnose"
