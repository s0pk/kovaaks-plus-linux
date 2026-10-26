#!/usr/bin/env bash
# Builds the self-contained single-file Linux binary into ./dist/kovaaks-plus (needs the .NET 8 SDK).
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

dotnet publish "$root/src/KovaaksPlus/KovaaksPlus.csproj" -c Release -r linux-x64 --self-contained true \
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true \
    -p:DebugType=none -o "$tmp" -nologo

mkdir -p "$root/dist"
install -m755 "$tmp/kovaaks-plus" "$root/dist/kovaaks-plus"
echo "Built dist/kovaaks-plus"

# The native Qt Quick UI (needs Qt 6.5+ with Quick, Controls, WebSockets, Svg, Multimedia, cmake and ninja). Without it the app
# falls back to a Chromium app window or WebKitGTK.
if command -v cmake >/dev/null && command -v ninja >/dev/null; then
    cmake -S "$root/ui" -B "$root/ui/build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build "$root/ui/build"
    install -m755 "$root/ui/build/kovaaks-plus-ui" "$root/dist/kovaaks-plus-ui"
    echo "Built dist/kovaaks-plus-ui"
else
    echo "cmake/ninja not found: skipped the native UI (dist/kovaaks-plus-ui). The app will use a browser window instead." >&2
fi
