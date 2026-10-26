using System.Diagnostics;
using KovaaksPlus.Platform;

namespace KovaaksPlus;

/// <summary>
/// Shows the UI in a Chromium-based browser's app window (no tabs or address bar) with its own profile folder.
/// Chromium composites on the GPU (OpenGL, or Vulkan through ANGLE), which is far smoother than WebKitGTK for this UI.
/// The page talks to the app over a WebSocket that only this run's page can open (see <see cref="UiServer"/>).
/// </summary>
public sealed class ChromiumHost : SocketHost
{
    static readonly string[] Candidates =
    {
        "google-chrome-stable", "google-chrome", "chromium", "chromium-browser", "brave-browser", "brave",
        "microsoft-edge-stable", "vivaldi-stable", "vivaldi",
    };

    readonly string _browser;
    Process? _proc;

    public string BrowserName => Path.GetFileName(_browser);

    /// <summary>The browser to use: KPLUS_BROWSER if set, else the first Chromium-based one on PATH.</summary>
    public static string? FindBrowser()
    {
        var env = Environment.GetEnvironmentVariable("KPLUS_BROWSER");
        if (!string.IsNullOrEmpty(env)) return Cli.Exists(env) ? env : null;
        return Candidates.FirstOrDefault(Cli.Exists);
    }

    public ChromiumHost(string browser)
    {
        _browser = browser;
    }

    string Url()
    {
        var dev = Environment.GetEnvironmentVariable("KPLUS_DEV") == "1" ? "&dev=1" : "";
        return $"{Server.Origin}/index.html?t={Token}{dev}";
    }

    List<string> Args()
    {
        var profile = Path.Combine(AppPaths.Root, "chromium");
        Directory.CreateDirectory(profile);
        var args = new List<string>
        {
            "--app=" + Url(),
            "--user-data-dir=" + profile,
            "--class=kovaaks-plus",
            "--window-size=1440,900",
            "--no-first-run", "--no-default-browser-check", "--password-store=basic",
            "--disable-background-networking", "--disable-sync", "--disable-component-update", "--disable-breakpad",
            "--disable-features=Translate,MediaRouter,OptimizationHints,AutofillServerCommunication,GlobalMediaControls",
            "--overscroll-history-navigation=0", "--disable-pinch",
            "--ozone-platform-hint=auto",
            "--autoplay-policy=no-user-gesture-required",
        };
        // GPU back end: KPLUS_GPU_API=gl (default, Chromium's own choice), vulkan (via ANGLE), or software.
        switch ((Environment.GetEnvironmentVariable("KPLUS_GPU_API") ?? "gl").ToLowerInvariant())
        {
            case "vulkan":
                args.Add("--use-angle=vulkan");
                args.Add("--enable-features=Vulkan,DefaultANGLEVulkan,VulkanFromANGLE");
                break;
            case "software":
                args.Add("--disable-gpu");
                break;
        }
        var extra = Environment.GetEnvironmentVariable("KPLUS_BROWSER_FLAGS");
        if (!string.IsNullOrWhiteSpace(extra)) args.AddRange(extra.Split(' ', StringSplitOptions.RemoveEmptyEntries));
        return args;
    }

    public void Run()
    {
        Rpc.Run(Api.Start);
        var psi = new ProcessStartInfo(_browser) { UseShellExecute = false };
        foreach (var a in Args()) psi.ArgumentList.Add(a);
        _proc = Process.Start(psi) ?? throw new InvalidOperationException("Could not start " + _browser);
        Api.Watcher.SelfProcessRoot = _proc.Id;
        _proc.WaitForExit();
        try { Api.Watcher.Dispose(); Api.Stats.Save(); } catch { }
        Server.Dispose();
        Rpc.Shutdown();
    }

    // ---------------- window actions ----------------

    public override void BringToFrontForced()
    {
        if (_proc == null) return;
        Task.Run(() => { try { Api.Watcher.FocusSelf(); } catch { } });
    }

    /// <summary>Zoom is applied by the page itself (CSS zoom), since an app window has no host-side zoom control.</summary>
    public override void SetZoom(double factor) => Emit("zoom", new { factor = Math.Clamp(factor, 0.6, 1.6) });

    public override string? PickFolder(string title) => Dialogs.PickFolder(title);
    public override string? PickOpenFile(string title, params (string Name, string[] Extensions)[] filters) => Dialogs.PickOpenFile(title, filters);
    public override string? PickSaveFile(string title, string defaultName, params (string Name, string[] Extensions)[] filters) => Dialogs.PickSaveFile(title, defaultName, filters);
}
