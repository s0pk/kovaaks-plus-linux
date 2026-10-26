using KovaaksPlus.Platform;

namespace KovaaksPlus;

/// <summary>`kovaaks-plus --diagnose`: prints what the app can see and do on this desktop, for setup and bug reports.</summary>
static class Diagnose
{
    public static int Run(string[] args)
    {
        Console.WriteLine($"Kovaak's Plus (Linux) — session: {Environment.GetEnvironmentVariable("XDG_SESSION_TYPE") ?? "?"}, desktop: {Environment.GetEnvironmentVariable("XDG_CURRENT_DESKTOP") ?? "?"}");

        var hostKind = (Environment.GetEnvironmentVariable("KPLUS_HOST") ?? "auto").ToLowerInvariant();
        var qmlUi = hostKind is "auto" or "qml" ? QmlHost.FindUi() : null;
        var browser = qmlUi != null || hostKind == "webkit" ? null : ChromiumHost.FindBrowser();
        Console.WriteLine($"UI host:       {(qmlUi != null ? "native Qt Quick UI (" + qmlUi + ")" : browser != null ? "Chromium app window via " + browser + " (GPU API: " + (Environment.GetEnvironmentVariable("KPLUS_GPU_API") ?? "gl") + "); build the native UI with ./build.sh for a browser-free window" : "WebKitGTK (software/OpenGL; build the native UI with ./build.sh, or install Chrome or Chromium)")}");

        var d = GamePaths.Detect();
        Console.WriteLine($"Steam roots:   {string.Join(", ", GamePaths.SteamRoots())}");
        Console.WriteLine($"KovaaK's:      {d.GamePath ?? "NOT FOUND"}");
        Console.WriteLine($"Workshop:      {(d.WorkshopPaths.Count == 0 ? "none" : string.Join(", ", d.WorkshopPaths))}");
        Console.WriteLine($"Steam account: {d.SteamName ?? "?"} ({d.SteamId ?? "?"})");
        if (d.GamePath != null)
        {
            var p = new GamePaths(d.GamePath, d.WorkshopPaths);
            p.MakeCurrent();
            Console.WriteLine($"Proton data:   {p.LocalDataDir} ({(Directory.Exists(p.LocalDataDir) ? "ok" : "missing: start the game once")})");
            Console.WriteLine($"Restart key:   {GameWatcher.DetectRestartKey()?.Name ?? "not found (will use R)"}");
        }

        var pid = Procs.FindByExe(GamePaths.ProcessName);
        Console.WriteLine($"Game process:  {(pid == 0 ? "not running" : "pid " + pid)}");

        using var ws = WindowSystems.Create();
        Console.WriteLine($"Window system: {ws.Name}");
        Console.WriteLine($"Active window pid: {ws.ActivePid()} (0 = unknown / not visible to this backend)");
        if (pid != 0) Console.WriteLine($"Game window visible: {ws.HasWindow(pid)}");

        using var x = X11.TryOpen();
        Console.WriteLine($"X11 / XWayland: {(x != null ? "available" : "not available")}");

        int readable = 0;
        foreach (var node in Directory.Exists("/dev/input") ? Directory.EnumerateFiles("/dev/input", "event*") : Array.Empty<string>())
        {
            try { using var fs = new FileStream(node, FileMode.Open, FileAccess.Read, FileShare.ReadWrite); readable++; } catch { }
        }
        Console.WriteLine($"Input devices readable: {readable} " + (readable > 0 ? "(pause key works everywhere)" : "(add yourself to the 'input' group for reliable pause detection)"));
        Console.WriteLine($"Key injection: {(x != null ? "XTEST (X11/XWayland)" : Cli.Exists("ydotool") ? "ydotool" : "unavailable")}");

        if (args.Length >= 3 && args[1] == "--key-test" && KeyMap.TryGet(args[2], out var key))
        {
            // Counts presses of one key for a few seconds (nothing else is read or logged).
            int count = 0;
            using var kw = new KeyWatcher(() => Interlocked.Increment(ref count), x);
            kw.SetKey(key.Code);
            kw.Start();
            Console.WriteLine($"\nCounting presses of {key.Name} for 8 seconds — press it now…");
            Thread.Sleep(args.Length > 3 && int.TryParse(args[3], out var secs) ? secs * 1000 : 8000);
            Console.WriteLine($"Key source: {kw.Source}{(kw.Warning != null ? " (warning: " + kw.Warning + ")" : "")}; presses seen: {count}; keyboards open: {kw.DeviceCount}; key events of any kind seen: {kw.KeyEventCount}");
        }

        if (args.Length >= 3 && args[1] == "--tap-test" && KeyMap.TryGet(args[2], out var tapKey))
            Console.WriteLine($"\ntap {tapKey.Name}: {KeyInjector.Tap(x, tapKey)}");

        if (args.Length >= 4 && args[1] == "--window-test")
        {
            Console.WriteLine($"\nwindow-test {args[2]} {args[3]}: " + (args[2] switch
            {
                "activate" => ws.Activate(int.Parse(args[3])),
                "close" => ws.Close(int.Parse(args[3])),
                _ => false,
            }));
            Thread.Sleep(300);
            Console.WriteLine($"Active window pid afterwards: {ws.ActivePid()}");
        }
        return 0;
    }
}
