# Kovaak's Plus — Linux port

A native Linux port of [Izunalol/kovaaks-plus](https://github.com/Izunalol/kovaaks-plus), a companion app for KovaaK's FPS Aim Trainer. You browse, launch, tag and review everything here, and the game only comes forward while you're aiming.

It runs natively (no Wine). KovaaK's itself is a Windows game, so it runs through Steam Play / Proton as usual; this app sits next to it, watches it from the outside, and talks to Steam.

## Install

Requirements: a recent Linux desktop, Steam with KovaaK's installed, the [.NET 8 SDK](https://dotnet.microsoft.com/download) to build, and for the native window Qt 6.5+ (Quick, Quick Controls, WebSockets, Svg, Multimedia and Wayland; Arch: `qt6-declarative qt6-websockets qt6-svg qt6-multimedia qt6-wayland`) with `cmake` and `ninja` to build it. The UI is a native Qt Quick window with no browser involved. If it isn't built, the app falls back to a Chromium-based browser's app window (Chrome, Chromium, Brave, Edge or Vivaldi), and without one to a built-in WebKitGTK window (`webkit2gtk-4.1` and `gtk3`). File dialogs use the platform's own dialog (or `kdialog`/`zenity` in the browser modes).

```bash
./build.sh      # → dist/kovaaks-plus (self-contained backend) and dist/kovaaks-plus-ui (native Qt window)
./install.sh    # → ~/.local/bin, app menu entry and icon (no root)
kovaaks-plus --diagnose   # shows what the app found and what works on your desktop
```

On first launch it finds KovaaK's (including libraries on other drives, Flatpak and Snap Steam), its Workshop scenarios and your Steam account by itself. Click **Let's go**. Your data lives in `~/.local/share/KovaaksPlus` (override with `KPLUS_DATA_DIR`). Tags, names and presets are plain files; share yours as `.kpack` files (Import / Export page). Packs use the same format as the Windows version.

### Pause key detection: join the `input` group

Pressing Esc in game is detected by reading the keyboard from `/dev/input` (works on X11 and every Wayland compositor; only the one configured key is looked at). That needs read access:

```bash
sudo usermod -aG input $USER   # then log out and back in
```

Without it the app falls back to a limited mode that only sees the key while the game window itself has focus (usually enough with XWayland, but less reliable). `kovaaks-plus --diagnose` tells you which mode you're in.

### Desktop support

| Desktop | Focus / close game | Pause detection | Notes |
|---|---|---|---|
| KDE Plasma (Wayland or X11) | KWin script (tested) | XWayland/X11 focus + evdev (tested) | Reference platform |
| X11 (any WM) | EWMH | works | Some WMs apply focus-stealing prevention |
| Hyprland | `hyprctl` | via `hyprctl` | **Untested** |
| Sway | `swaymsg` | via `swaymsg` | **Untested** |
| GNOME Wayland | EWMH via XWayland only | XWayland only | Mutter refuses to let background apps take focus; expect "ready" notifications instead of a raise |

Force a backend with `KPLUS_WINDOW_BACKEND=kwin|hyprland|sway|x11|none`. The restart key is pressed through XTEST (reaches XWayland, i.e. Proton games); `ydotool` is used as a fallback.

UI host and rendering: the native Qt window is used when `kovaaks-plus-ui` is installed next to the app (`KPLUS_UI_BIN=<path>` points at another build, `KPLUS_GPU_API=opengl|vulkan|software` picks its scene-graph back end); `KPLUS_HOST=chromium` or `KPLUS_HOST=webkit` forces a browser window or the built-in WebKitGTK window instead; `KPLUS_BROWSER=<path>` picks a specific browser; in Chromium `KPLUS_GPU_API=gl|vulkan|software` selects the GPU back end (default `gl`; `vulkan` runs through ANGLE and measured the same on an RTX 4060); `KPLUS_BROWSER_FLAGS="..."` adds extra browser flags. The app talks to its window over a loopback WebSocket protected by a per-run secret token and an origin check.

Environment switches: `KPLUS_DEV=1` (devtools and UI logging), `KPLUS_UI_DIR=<wwwroot>` (edit the UI live), `KPLUS_GPU_RENDER=1` (use WebKit's hardware renderer instead of the software fallback, see below).

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

- **App Settings → Appearance:** theme (7 dark themes), accent and secondary colours, font, interface scale, corners, density, scenario card size, glow, animations, PB highlighting and dimming of earlier runs.
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

## Building from source

```bash
./build.sh                     # release binary → dist/kovaaks-plus
dotnet run --project src/KovaaksPlus            # run from source
dotnet run --project tests/Smoke -- --network   # RPC smoke tests against a temp copy of your game data
```

Project layout (`src/KovaaksPlus`):
- `HostBase.cs`/`SocketHost.cs`: JSON-RPC bridge shared by the UI hosts; `QmlHost.cs` runs the native Qt window, `ChromiumHost.cs` a browser app window, `AppWindow.cs` the Photino (WebKitGTK) fallback
- `UiServer.cs`: loopback server for the UI, thumbnails and crosshairs (supports video seeking)
- `Api.cs`: every UI action
- `GameWatcher.cs`: game process, key watcher, stats watcher and focus switching
- `Platform/`: Linux layer: X11/XTEST, window-system backends (KWin, Hyprland, Sway, EWMH), evdev key watcher, /proc helpers
- `GamePaths.cs`: finds Steam libraries and the game's Proton prefix
- `StatsIndex.cs`, `ScenarioLibrary.cs`, `SettingsManager.cs`, `PackManager.cs`, `EvxlClient.cs`: unchanged logic from upstream
- `wwwroot/`: the web UI used by the browser hosts (plain HTML/CSS/JS modules, no build step)

The native UI lives in `ui/` (Qt Quick / QML, one flat folder of components in `ui/qml`, ported logic in `ui/qml/js`, bundled fonts in `ui/assets`). It speaks the same JSON-RPC to the backend, so both UIs stay in step. Build it on its own with `cmake -S ui -B ui/build -G Ninja && cmake --build ui/build`.

## Look and feel

The Linux port ships its own visual identity, "Range": charcoal and bone, squared frames, large condensed numerals (Big Shoulders Display for headings and scores, Instrument Sans for text). The interface is deliberately colourless so scores, PBs, ranks and scenario art carry the colour. A reticle-style corner bracket marks what is selected, hovered or current. The native UI implements it with design tokens in `ui/qml/Theme.qml`, the web UI with `wwwroot/css/range.css` on top of the upstream `app.css`; the old themes (Midnight, OLED, Nord…) and the font choices in App Settings → Appearance still work. Both fonts are bundled under the SIL Open Font License (`wwwroot/fonts/LICENSE-*.txt`, `ui/assets/LICENSE-*.txt`).

## Notes for this port

- **NVIDIA + Wayland:** the app always sets `__NV_DISABLE_EXPLICIT_SYNC=1` for itself (also used by the Qt window). WebKitGTK crashes at startup with "explicit sync is used, but no acquire point is set" on some NVIDIA drivers. The app sets `__NV_DISABLE_EXPLICIT_SYNC=1` (always) and `WEBKIT_DISABLE_DMABUF_RENDERER=1` (software rendering, the safe default) for itself unless you set them yourself; `KPLUS_GPU_RENDER=1` keeps the hardware renderer.
- KovaaK's per-user files (`session.sav`, `Input.ini`) are read from the game's Proton prefix (`steamapps/compatdata/824270/pfx/...`).
- Native Wayland (non-XWayland) game windows can be focused and closed, but the "is the game focused" check used for pause detection only sees X11/XWayland windows on KDE.
- The upstream project ships no license file; this port is for personal use. Ask the upstream author before redistributing.
