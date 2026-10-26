# Kovaak's Plus for Linux

A native Linux port of [Kovaak's Plus](https://github.com/Izunalol/kovaaks-plus), a companion app for KovaaK's FPS Aim Trainer. You browse, launch, tag and review everything in the app, and the game only comes forward while you're aiming.

- **No Wine, no browser.** The interface is a native Qt Quick window; a small .NET backend watches the game from the outside and talks to Steam.
- KovaaK's itself is a Windows game, so it still runs through Steam Play / Proton as usual. This app sits next to it.
- Scenario library with tags, presets and thumbnails, run statistics, benchmarks with the same ranks and energy as [evxl.app](https://evxl.app), leaderboards, a results screen with PB celebration, and `.kpack` sharing (compatible with the Windows version).

Original project: [Izunalol/kovaaks-plus](https://github.com/Izunalol/kovaaks-plus) (Windows, C#/WebView2). This port is shared with the original author's permission.

Tested on CachyOS with KDE Plasma 6 (Wayland) and an NVIDIA GPU. Other setups are listed under [Desktop support](#desktop-support).

## Install

### 1. Dependencies

| What | Needed for | Arch / CachyOS / Manjaro |
|---|---|---|
| Steam with KovaaK's installed | the game (Proton) | `steam` |
| .NET 8 SDK | building the backend (the built app is self-contained) | `dotnet-sdk-8.0` |
| CMake 3.21+, Ninja, a C++20 compiler | building the Qt window | `cmake ninja gcc` |
| Qt 6.5+: base, declarative (Quick, Controls, Dialogs, Shapes), websockets, svg, multimedia | the window (build and run) | `qt6-base qt6-declarative qt6-websockets qt6-svg qt6-multimedia qt6-multimedia-ffmpeg qt6-wayland qt6-shadertools` |
| libX11 and libXtst | sending the restart key to the game (XWayland/X11) | `libx11 libxtst` |
| A desktop portal for your desktop (file dialogs) | Browse / Save dialogs | `xdg-desktop-portal-kde`, `-gnome`, `-gtk`, `-hyprland` … |

Optional:
- `ydotool`: fallback for sending the restart key.
- A Chromium-based browser or `webkit2gtk-4.1` + `gtk3`: only used if the Qt window isn't built (see [UI hosts](#ui-hosts)).

Other distributions (not tested, package names are the usual ones):
- **Fedora:** `dotnet-sdk-8.0 cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwebsockets-devel qt6-qtsvg-devel qt6-qtmultimedia-devel qt6-qtwayland libX11 libXtst`
- **Debian 13 / Ubuntu 24.04+:** `dotnet-sdk-8.0 cmake ninja-build g++ qt6-base-dev qt6-declarative-dev qt6-websockets-dev qt6-svg-dev qt6-multimedia-dev qt6-wayland libx11-6 libxtst6 qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-dialogs qml6-module-qtquick-shapes qml6-module-qtquick-window qml6-module-qtmultimedia`

The pre-6.5 Qt in older distributions will not work.

### 2. Build and install

```bash
git clone https://github.com/s0pk/kovaaks-plus-linux.git
cd kovaaks-plus-linux
./build.sh      # → dist/kovaaks-plus (backend) and dist/kovaaks-plus-ui (Qt window)
./install.sh    # → ~/.local/bin, app menu entry and icon (no root needed)
kovaaks-plus --diagnose   # shows what the app found and what works on your desktop
```

Make sure `~/.local/bin` is on your `PATH`, or start it from the app menu ("Kovaak's Plus").

If `./build.sh` can't find `cmake` or `ninja` it still builds the backend and the app falls back to a browser window; install them and run it again to get the native window.

To uninstall: delete `~/.local/bin/kovaaks-plus`, `~/.local/bin/kovaaks-plus-ui`, `~/.local/share/applications/kovaaks-plus.desktop` and the icon `~/.local/share/icons/hicolor/256x256/apps/kovaaks-plus.png`. Your data stays in `~/.local/share/KovaaksPlus` until you remove it.

### 3. First launch

Start **Kovaak's Plus**. It finds KovaaK's by itself (including libraries on other drives, Flatpak and Snap Steam), its Workshop scenarios and your Steam account. Check the three ticks and click **Let's go**. Your data lives in `~/.local/share/KovaaksPlus` (override with `KPLUS_DATA_DIR`). Tags, names and presets are plain files; share yours as `.kpack` files (Import / Export page, or drop a file on the window). Packs use the same format as the Windows version.

In KovaaK's, set the display mode to **Windowed Fullscreen** so switching between the game and this app is instant, and leave **Pause on loss of focus** on.

### 4. Pause key detection: join the `input` group

Pressing Esc in game is detected by reading the keyboard from `/dev/input` (works on X11 and every Wayland compositor; only the one configured key is looked at). That needs read access:

```bash
sudo usermod -aG input $USER   # then log out and back in
```

Without it the app falls back to a limited mode that only sees the key while the game window itself has focus (usually enough with XWayland, but less reliable). `kovaaks-plus --diagnose` tells you which mode you're in.

## Desktop support

| Desktop | Focus / close game | Pause detection | Notes |
|---|---|---|---|
| KDE Plasma (Wayland or X11) | KWin script (tested) | XWayland/X11 focus + evdev (tested) | Reference platform |
| X11 (any WM) | EWMH | works | Some WMs apply focus-stealing prevention |
| Hyprland | `hyprctl` | via `hyprctl` | **Untested** |
| Sway | `swaymsg` | via `swaymsg` | **Untested** |
| GNOME Wayland | EWMH via XWayland only | XWayland only | Mutter refuses to let background apps take focus; expect "ready" notifications instead of a raise |

Force a backend with `KPLUS_WINDOW_BACKEND=kwin|hyprland|sway|x11|none`. The restart key is pressed through XTEST (reaches XWayland, i.e. Proton games); `ydotool` is used as a fallback. Native Wayland (non-XWayland) game windows can be focused and closed, but the "is the game focused" check used for pause detection only sees X11/XWayland windows on KDE.

## UI hosts

The backend can show its interface in three ways, tried in this order:
1. **Native Qt window** (`kovaaks-plus-ui`, installed next to `kovaaks-plus`). The default.
2. A **Chromium-based browser's app window** (Chrome, Chromium, Brave, Edge or Vivaldi) with its own profile.
3. A built-in **WebKitGTK window** (`webkit2gtk-4.1`, `gtk3`).

Force one with `KPLUS_HOST=qml|chromium|webkit`. The window talks to the backend over a loopback WebSocket protected by a per-run secret token and an origin check.

### Environment variables

| Variable | Effect |
|---|---|
| `KPLUS_DATA_DIR` | where app data is stored (default `~/.local/share/KovaaksPlus`) |
| `KPLUS_HOST` | `qml`, `chromium` or `webkit` |
| `KPLUS_UI_BIN` | path to a specific `kovaaks-plus-ui` build |
| `KPLUS_GPU_API` | Qt window: `opengl`, `vulkan` or `software`. Chromium: `gl`, `vulkan` or `software` |
| `KPLUS_BROWSER`, `KPLUS_BROWSER_FLAGS` | pick a browser / extra flags for the Chromium host |
| `KPLUS_WINDOW_BACKEND` | `kwin`, `hyprland`, `sway`, `x11` or `none` |
| `KPLUS_KEY_SOURCE=x11` | skip evdev and read the pause key through X11 |
| `KPLUS_DEV=1` | developer logging (and `KPLUS_UI_DIR=<wwwroot>` to edit the web UI live) |

## Troubleshooting

- **`module "QtQuick.Dialogs" is not installed` (or another QML module):** the Qt declarative package is missing or too old; install the packages from the table above.
- **Blank or frozen window on NVIDIA:** the app already sets `__NV_DISABLE_EXPLICIT_SYNC=1` for itself. Try `KPLUS_GPU_API=software kovaaks-plus`, and `kovaaks-plus --diagnose`.
- **Esc is not detected / the app doesn't come forward on pause:** join the `input` group (above) and check `--diagnose`.
- **Video previews are blank:** install the Qt multimedia FFmpeg backend (`qt6-multimedia-ffmpeg` on Arch).
- **File dialogs look wrong or don't open:** install the desktop portal for your desktop (`xdg-desktop-portal-kde`, `-gnome`, `-gtk`).
- **"The Qt window isn't being used":** `kovaaks-plus --diagnose` prints which host was picked; `kovaaks-plus-ui` must be in the same folder as `kovaaks-plus` or on `PATH`.

## How the window switching works

| You do | What happens |
|---|---|
| Click **Play** on any scenario | Launches it with KovaaK's own deep link (`steam://run/824270//?action=jump-to-scenario&name=…&mode=challenge`) and brings the game forward |
| Press **Esc** in game (configurable) | Kovaak's Plus comes forward with a "Paused" bar. Click **Resume** or press **Space** to go back |
| A run ends | KovaaK's writes a stats CSV, the app picks it up and comes forward with your results, PB comparison and benchmark rank. A new PB gets the gold screen and confetti |

Tips:
- Use **Windowed Fullscreen** in KovaaK's so switching is instant (Proton: exclusive fullscreen also works but switches slower).
- Keep KovaaK's **Pause on loss of focus** ON (it is by default).

The pause bar shows the scenario that's loaded. It knows this from:
- the scenario you launched from the app
- KovaaK's `session.sav`, which the game rewrites while running
- your last finished run

### Going back to KovaaK's

Under App Settings → Returning to KovaaK's you can choose what Space does:
- **From the pause bar:** restart the run (default), or continue where you paused.
- **On the results screen:** restart the run (default), play the next scenario in the queue, or just switch back.

The app restarts a run by pressing your restart key for you (default **R**; set it to match your in-game bind). It only presses it once KovaaK's is confirmed to be in front.

The queue is the list you launched from: a benchmark difficulty, a calculator plan, or the scenarios currently shown in the library. **N** on the results screen always plays the next scenario in the queue.

## Organising scenarios

- **Hover** a scenario to see its preview without opening the side panel. In grid view it plays over the card; in lists and tables (library list, Home, Statistics, benchmark tables) it pops up beside the cursor. Turn it off under App Settings → Appearance → Preview on hover.
- **Right-click** any scenario, anywhere: play, favorite, hide, edit tags, rename, set a thumbnail, set a default preset, open its leaderboard, export.
- **Tags:** right-click a tag in the sidebar, or hover it and click the pencil. You can rename it, recolour it, change its category, give it a **default thumbnail** and a **default preset**, or delete it. A scenario without its own thumbnail uses its tags' thumbnails, split diagonally when several tags have one.
- **Auto-tag** (Scenarios → Auto-tag) proposes tags from:
  - evxl.app's aim-type classification (~2,000 scenarios)
  - the scenario's in-game tags (synonyms like Track/Tracking and OW/Overwatch are merged)
  - in-game difficulty
  - benchmark membership

  When a proposal looks like a tag you already have, it asks whether to use that tag or create a new one.
- **Default presets** can be set per scenario, or per tag as a fallback. When you press Play and your current settings differ, the app asks (or, if you choose, applies automatically): it closes KovaaK's, applies the preset, and relaunches straight into the scenario. You can change this under App Settings → Default presets.

## Calculators

- **Benchmark (Rank calculator card, collapsed by default; click its header):** pick a target rank, an energy, or a leaderboard position. It lists the cheapest set of improvements to get there, one scenario per weak subcategory, with exact scores and play buttons. Energy benchmarks raise your weakest subcategories first, because energy is a harmonic mean.
- **Rank lines on score charts:** if a scenario belongs to a benchmark, its score history (side panel and results screen) shows that benchmark's rank thresholds as coloured lines and bands: the rank below your worst run, every rank inside your range, and the next one above your best. Use the picker above the chart to switch benchmark or turn the lines off; your choice is remembered.
- **Scenario (details panel or right-click → Calculator):** enter a target score, a rank, or a leaderboard position / top %. It shows the score needed, the gain over your PB, the rank, and an estimated global position.

## Customising

- **App Settings → Appearance:** theme (8 dark themes), accent and secondary colours, font, interface scale, corners, density, scenario card size, glow, animations, PB highlighting and dimming of earlier runs.
- **Benchmark → Table settings (sliders icon):** evxl-style layout options such as density, bar style, skew, radii, category shading, rank-column colours, a per-subcategory gradient behind the scores and energy, font, text size, separate contrast for rank and score text, leaderboard position, progress %, and simplified names.
- **Manage tags:** drag tags by their handle, or use the arrows, to reorder them or move them between groups. Groups can be reordered too. Tag order decides sidebar order, and which tag's thumbnail and preset win.

## Leaderboards

- **Benchmarks:** Global, Friends, Country and country averages (from evxl.app), plus per-scenario boards.
- **Scenarios:** Global (KovaaK's official board), Friends (your Steam friends who play KovaaK's) and My position (located live on the board). Available in the details panel, the right-click menu and every benchmark row.
- **End of run:** where the new score would place globally (estimated live) and how you rank among friends.

**Viewing other players:** click anyone on a leaderboard (benchmark, scenario or end of run) to open their benchmarks in the Benchmarks tab, with their KovaaK's scores, ranks and energy. You can also use **Find player** on the Benchmarks page (or the gear menu on a benchmark) and search by Steam name, KovaaK's username, SteamID64, or a Steam / evxl.app profile link. Right-click a leaderboard row to open their evxl.app or Steam profile instead.

Star a player (in the picker, on the Viewing banner, or by right-clicking a leaderboard row) to add them to **Favorites**. Favorites show as quick chips at the top of the Benchmarks pages. The picker also lists your **Steam friends** who are on evxl.app; type to filter them, or press Enter to search everyone. It's temporary: leaving the Benchmarks tab or relaunching the app switches back to you. Their scores are never written to your offline cache.

The app never injects into or reads the game's memory. It watches the stats folder, the process list and the pause key (evdev keyboard reads on their own thread).

## Why settings changes still restart KovaaK's

The game keeps its settings in memory and rewrites `PrimaryUserSettings.json` constantly (one older game log shows about 1,900 saves). Any edit made from outside is overwritten almost straight away. The game does have an internal `ReloadAndApplyActiveSettings` function, but nothing outside the game can trigger it: there's no key bind, console command or deep link for it. So applying settings or a preset still means closing the game, writing the file and relaunching, straight into the scenario if you launched one.

## What it stores, and where

All app data lives in `~/.local/share/KovaaksPlus` and never inside the game's folders:
- `library.json`: custom names, tags, notes, favorites, thumbnails
- `presets/`: settings presets
- `media/`: thumbnails, previews and tag icons, one folder per item (`media/scenarios/<scenario>/`, `media/tags/<tag>/`, `media/presets/<preset>/`). App Settings → Data → Thumbnails & icons opens it.
- `backups/`: automatic snapshots of KovaaK's settings, taken before every change
- `cache/`: stats index and benchmark data

**Cleaning up:** replacing or removing a thumbnail leaves the old file in media/. App Settings → Data → **Clean up unused files** scans for files no scenario, tag or preset uses, lets you pick which to remove, and sends them to the Trash. It also removes empty folders, and can clear links to files that were deleted by hand. Turn on **Clean up automatically on launch** to do this quietly each time the app starts (off by default).

Scenario files are never renamed or edited. The only time the app writes into KovaaK's folders:
- **Applying settings or a preset.** It edits `PrimaryUserSettings.json`, `weaponsettings.ini` and `UI.json` after backing them up. If KovaaK's is running, the app closes it, applies the change and relaunches it, because the game rewrites these files on exit.
- **Importing a pack.** It adds the pack's `.sce` files to the Scenarios folder. Identical files are skipped, and replaced files are backed up first.

## Benchmarks

Benchmarks work like evxl.app: one entry per benchmark, difficulties as tabs, the same category and subcategory layout, threshold cells, and energy.

- **Overall ranks** are calculated locally with evxl's own formulas (basic, vt-energy, generic-energy, generic-energy-uncapped, complete), using your local PBs, so a new PB shows up immediately. For evxl's rarer custom scoring methods, the overall rank comes from evxl's server.
- **Where the data comes from:**
  - Thresholds and server scores: KovaaK's public webapp backend.
  - Catalog, profile ranks, friends and scenario classification: [evxl.app's API](https://api.evxl.app/documentation).
  - Benchmark grouping, layouts and scoring methods: evxl.app's site config, because the documented API has no endpoint for them. If the site changes, names fall back to the `rank-counts` endpoint.

## Building and developing

```bash
./build.sh                                        # release build → dist/
dotnet run --project src/KovaaksPlus              # run the backend from source
cmake -S ui -B ui/build -G Ninja && cmake --build ui/build   # just the Qt window → ui/build/kovaaks-plus-ui
dotnet run --project tests/Smoke -- --network     # RPC smoke tests against a temp copy of your game data
```

When running the backend from source, point it at a freshly built window with `KPLUS_UI_BIN=$PWD/ui/build/kovaaks-plus-ui`.

Project layout:
- `src/KovaaksPlus/`: the .NET backend
  - `Api.cs`: every UI action (JSON-RPC)
  - `HostBase.cs`, `SocketHost.cs`: RPC bridge shared by the UI hosts; `QmlHost.cs` runs the Qt window, `ChromiumHost.cs` a browser window, `AppWindow.cs` the WebKitGTK window
  - `UiServer.cs`: loopback server (RPC socket, thumbnails, crosshairs)
  - `GameWatcher.cs`: game process, key watcher, stats watcher and focus switching
  - `Platform/`: Linux layer: X11/XTEST, window backends (KWin, Hyprland, Sway, EWMH), evdev key watcher, /proc helpers
  - `GamePaths.cs`: finds Steam libraries and the game's Proton prefix
  - `StatsIndex.cs`, `ScenarioLibrary.cs`, `SettingsManager.cs`, `PackManager.cs`, `EvxlClient.cs`: logic from the original project
  - `wwwroot/`: the web UI used by the browser hosts (plain HTML/CSS/JS, no build step)
- `ui/`: the native Qt Quick window. All components sit in one folder, `ui/qml` (Qt resolves siblings by directory), logic ported from the web UI is in `ui/qml/js`, bundled fonts and sounds in `ui/assets`.
- `tests/Smoke`: RPC smoke tests.
- `packaging/`: desktop entry and icon.

## Look and feel

The Linux port ships its own visual identity, "Range": charcoal and bone, squared frames, large condensed numerals (Big Shoulders Display for headings and scores, Instrument Sans for text). The interface is deliberately colourless so scores, PBs, ranks and scenario art carry the colour. A reticle-style corner bracket marks what is selected, hovered or current. The native UI implements it with design tokens in `ui/qml/Theme.qml`, the web UI with `wwwroot/css/range.css`. The themes (Midnight, OLED, Nord…) and accent colours in App Settings → Appearance still work. Both fonts are bundled under the SIL Open Font License (`ui/assets/LICENSE-*.txt`).

## Notes

- KovaaK's per-user files (`session.sav`, `Input.ini`) are read from the game's Proton prefix (`steamapps/compatdata/824270/pfx/...`).
- Not yet verified on a real desktop: video previews in the Qt window, Hyprland and Sway support, drag-and-drop of `.kpack` files onto the window.

## Credits

Kovaak's Plus is by [Izunalol](https://github.com/Izunalol); this is a Linux port of it. Benchmark data comes from [evxl.app](https://evxl.app) and KovaaK's.
