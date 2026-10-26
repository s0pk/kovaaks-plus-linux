using System.Drawing;
using System.Reflection;
using System.Text.Json;
using Photino.NET;

namespace KovaaksPlus;

/// <summary>What <see cref="Api"/> needs from whatever window shows the UI.</summary>
public interface IAppHost
{
    void Emit(string evt, object? data);
    void BringToFrontForced();
    void SetZoom(double factor);
    void OnGamePathsReady(GamePaths paths);
    string? PickFolder(string title);
    string? PickOpenFile(string title, params (string Name, string[] Extensions)[] filters);
    string? PickSaveFile(string title, string defaultName, params (string Name, string[] Extensions)[] filters);
}

/// <summary>
/// The WebKitGTK host: a Photino window showing the bundled UI. Used when no Chromium-based browser is available
/// (or KPLUS_HOST=webkit); WebKitGTK renders in software or OpenGL only, so <see cref="ChromiumHost"/> is preferred.
/// </summary>
public sealed class AppWindow : HostBase
{
    const string Title = "Kovaak's Plus";

    readonly PhotinoWindow _window;

    static string WindowStatePath => Path.Combine(AppPaths.Root, "window.json");

    record WindowPlacement(int X, int Y, int W, int H, bool Max);

    public AppWindow()
    {
        Server = new UiServer(() => CrosshairDir);

        var dev = Environment.GetEnvironmentVariable("KPLUS_DEV") == "1";
        var w = new PhotinoWindow()
            .SetTitle(Title)
            .SetUseOsDefaultSize(false)
            .SetSize(1440, 900)
            .SetMinSize(1100, 700)
            .SetContextMenuEnabled(dev)
            .SetDevToolsEnabled(dev)
            .SetJavascriptClipboardAccessEnabled(true)
            .SetMediaAutoplayEnabled(true)
            .SetGrantBrowserPermissions(false)
            .SetTemporaryFilesPath(AppPaths.WebViewData);
        TrySetIcon(w);
        if (!RestorePlacement(w)) w.Center();

        w.RegisterWindowCreatedHandler((_, _) => Created = true);
        w.RegisterWebMessageReceivedHandler((_, message) => Receive(message));
        w.RegisterWindowClosingHandler((_, _) =>
        {
            SavePlacement();
            try { Api.Watcher.Dispose(); Api.Stats.Save(); } catch { }
            return false;
        });
        _window = w;
    }

    public void Run()
    {
        Rpc.Run(Api.Start);
        _window.Load(new Uri(Server.Origin + "/index.html"));
        _window.WaitForClose();
        Server.Dispose();
        Rpc.Shutdown();
    }

    static void TrySetIcon(PhotinoWindow w)
    {
        try
        {
            var path = Path.Combine(AppPaths.Cache, "icon.png");
            using var res = Assembly.GetExecutingAssembly().GetManifestResourceStream("wwwroot/assets/logo.png");
            if (res == null) return;
            using (var fs = File.Create(path)) res.CopyTo(fs);
            w.SetIconFile(path);
        }
        catch { }
    }

    protected override void SendRaw(string json) => _window.SendWebMessage(json);

    /// <summary>Brings this window to the front. Wayland compositors refuse a plain request from a background app, so the window
    /// system backend (KWin script, hyprctl, swaymsg, EWMH) does it on our behalf.</summary>
    public override void BringToFrontForced()
    {
        if (!Created) return;
        Task.Run(() =>
        {
            try
            {
                if (_window.Minimized) _window.Invoke(() => _window.SetMinimized(false));
                if (!Api.Watcher.FocusSelf())
                    _window.Invoke(() => { _window.SetTopMost(true); _window.SetTopMost(false); });
            }
            catch { }
        });
    }

    public override void SetZoom(double factor)
    {
        if (!Created) return;
        var pct = (int)Math.Round(Math.Clamp(factor, 0.6, 1.6) * 100);
        try { _window.Invoke(() => _window.SetZoom(pct)); } catch { }
    }

    // ---------------- dialogs (GTK, run on the UI thread) ----------------

    T OnUi<T>(Func<T> f)
    {
        T result = default!;
        _window.Invoke(() => result = f());
        return result;
    }

    public override string? PickFolder(string title)
    {
        var r = OnUi(() => _window.ShowOpenFolder(title, null, false));
        return r is { Length: > 0 } ? r[0] : null;
    }

    public override string? PickOpenFile(string title, params (string Name, string[] Extensions)[] filters)
    {
        var r = OnUi(() => _window.ShowOpenFile(title, null, false, filters));
        return r is { Length: > 0 } ? r[0] : null;
    }

    public override string? PickSaveFile(string title, string defaultName, params (string Name, string[] Extensions)[] filters) =>
        OnUi(() => _window.ShowSaveFile(title, defaultName, filters));

    // ---------------- window placement ----------------
    static bool RestorePlacement(PhotinoWindow w)
    {
        var p = Json.Read<WindowPlacement>(WindowStatePath);
        if (p == null || p.W < 400 || p.H < 300) return false;
        w.SetSize(p.W, p.H);
        // Wayland compositors choose window positions themselves, so a saved position is only meaningful on X11.
        bool wayland = Environment.GetEnvironmentVariable("XDG_SESSION_TYPE") == "wayland";
        if (!wayland) w.SetLocation(new Point(p.X, p.Y));
        if (p.Max) w.SetMaximized(true);
        return !wayland;
    }

    void SavePlacement()
    {
        try
        {
            var size = _window.Size;
            var loc = _window.Location;
            // A maximized window reports its maximized size; keep the old restore size in that case.
            var old = Json.Read<WindowPlacement>(WindowStatePath);
            bool max = _window.Maximized;
            if (max && old != null) Json.Write(WindowStatePath, new WindowPlacement(old.X, old.Y, old.W, old.H, true));
            else Json.Write(WindowStatePath, new WindowPlacement(loc.X, loc.Y, size.Width, size.Height, max));
        }
        catch { }
    }
}
