using System.Text.Json;

namespace KovaaksPlus.Platform;

/// <summary>What the app needs from the desktop: who has focus, and the ability to focus or close a process's window.</summary>
public interface IWindowSystem : IDisposable
{
    string Name { get; }
    /// <summary>Owning process of the focused window, or 0 when unknown (e.g. a window this backend cannot see).</summary>
    int ActivePid();
    bool HasWindow(int pid);
    bool Activate(int pid);
    /// <summary>Activates the window of any of these processes (a browser's window may belong to one of its helper processes).</summary>
    bool Activate(IReadOnlyList<int> pids) => pids.Count > 0 && (pids.Count == 1 ? Activate(pids[0]) : pids.Any(Activate));
    /// <summary>Asks the window to close (like clicking its X button), so the game can save on exit.</summary>
    bool Close(int pid);
}

public static class WindowSystems
{
    /// <summary>Picks the best backend for the running desktop (override with KPLUS_WINDOW_BACKEND=kwin|hyprland|sway|x11|none).</summary>
    public static IWindowSystem Create()
    {
        var forced = (Environment.GetEnvironmentVariable("KPLUS_WINDOW_BACKEND") ?? "auto").ToLowerInvariant();
        var desktop = (Environment.GetEnvironmentVariable("XDG_CURRENT_DESKTOP") ?? "").ToUpperInvariant();
        bool auto = forced == "auto";

        if (forced == "hyprland" || (auto && !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE")) && Cli.Exists("hyprctl")))
            return new HyprlandWindowSystem();
        if (forced == "sway" || (auto && !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("SWAYSOCK")) && Cli.Exists("swaymsg")))
            return new SwayWindowSystem();
        if (forced == "none") return new NullWindowSystem();
        var x = X11.TryOpen();
        if (forced == "kwin" || (auto && desktop.Contains("KDE") && Cli.Exists("busctl")))
            return new KWinWindowSystem(x);
        return x != null ? new X11WindowSystem(x) : new NullWindowSystem();
    }
}

public sealed class NullWindowSystem : IWindowSystem
{
    public string Name => "none";
    public int ActivePid() => 0;
    public bool HasWindow(int pid) => false;
    public bool Activate(int pid) => false;
    public bool Close(int pid) => false;
    public void Dispose() { }
}

/// <summary>EWMH over X11. On Wayland it sees XWayland windows (which is what Proton games are).</summary>
public class X11WindowSystem : IWindowSystem
{
    protected readonly X11 X;
    public X11WindowSystem(X11 x) => X = x;
    public virtual string Name => "x11";

    public virtual int ActivePid() => X.ActivePid();

    X11.Win? Find(int pid)
    {
        // Wine also creates tiny helper windows for the same pid; the real one is listed with a title.
        var all = X.Windows().Where(w => w.Pid == pid).ToList();
        return all.Cast<X11.Win?>().FirstOrDefault(w => w!.Value.Title.Length > 0) ?? all.Cast<X11.Win?>().FirstOrDefault();
    }

    public virtual bool HasWindow(int pid) => Find(pid) != null;

    public virtual bool Activate(int pid) => Find(pid) is { } w && X.Activate(w.Id);

    public virtual bool Close(int pid) => Find(pid) is { } w && X.Close(w.Id);

    public virtual void Dispose() => X.Dispose();
}

/// <summary>
/// KDE Plasma (X11 or Wayland). Focus and close go through a tiny KWin script, which — unlike a client request —
/// is allowed to activate any window, including native Wayland ones. Focus queries use the X11 root properties.
/// </summary>
public sealed class KWinWindowSystem : IWindowSystem
{
    readonly X11? _x;
    readonly X11WindowSystem? _x11;
    int _seq;

    public KWinWindowSystem(X11? x)
    {
        _x = x;
        _x11 = x == null ? null : new X11WindowSystem(x);
    }

    public string Name => "kwin";

    public int ActivePid() => _x?.ActivePid() ?? 0;

    public bool HasWindow(int pid) => _x11?.HasWindow(pid) ?? false;

    const string Template = @"
(function () {
  var pids = %PIDS%;
  var list = workspace.windowList ? workspace.windowList() : workspace.clientList();
  var best = null, area = -1;
  for (var i = 0; i < list.length; i++) {
    var w = list[i];
    if (pids.indexOf(w.pid) < 0 || !w.normalWindow) continue;
    var a = w.width * w.height;
    if (a > area) { best = w; area = a; }
  }
  if (!best) return;
  %BODY%
})();";

    const string ActivateBody = @"
  if (best.minimized) best.minimized = false;
  if ('activeWindow' in workspace) workspace.activeWindow = best; else workspace.activeClient = best;";
    const string CloseBody = "best.closeWindow();";

    public bool Activate(int pid) => Activate(new[] { pid });

    public bool Activate(IReadOnlyList<int> pids)
    {
        var ok = RunScript(Template.Replace("%PIDS%", "[" + string.Join(",", pids) + "]").Replace("%BODY%", ActivateBody));
        return ok || pids.Any(p => _x11?.Activate(p) ?? false);
    }

    public bool Close(int pid)
    {
        var ok = RunScript(Template.Replace("%PIDS%", "[" + pid + "]").Replace("%BODY%", CloseBody));
        return ok || (_x11?.Close(pid) ?? false);
    }

    bool RunScript(string source)
    {
        var id = Interlocked.Increment(ref _seq);
        var name = $"kplus-{Environment.ProcessId}-{id}";
        var dir = Path.Combine(AppPaths.Cache, "kwin");
        var file = Path.Combine(dir, name + ".js");
        try
        {
            Directory.CreateDirectory(dir);
            File.WriteAllText(file, source);
            var (exit, output) = Cli.Run("busctl", new[] { "--user", "call", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "loadScript", "ss", file, name });
            // "i 7": KWin 6 exposes the script object at /Scripting/Script7.
            var parts = output.Trim().Split(' ');
            if (exit != 0 || parts.Length < 2 || !int.TryParse(parts[1], out var scriptId) || scriptId < 0) return false;
            var (runExit, _) = Cli.Run("busctl", new[] { "--user", "call", "org.kde.KWin", $"/Scripting/Script{scriptId}", "org.kde.kwin.Script", "run" });
            Thread.Sleep(60);   // let the script finish before it is unloaded
            Cli.Run("busctl", new[] { "--user", "call", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "unloadScript", "s", name });
            return runExit == 0;
        }
        catch { return false; }
        finally { try { File.Delete(file); } catch { } }
    }

    public void Dispose() => _x?.Dispose();
}

/// <summary>Hyprland, through hyprctl. Sees native Wayland and XWayland windows alike.</summary>
public sealed class HyprlandWindowSystem : IWindowSystem
{
    public string Name => "hyprland";

    static JsonElement? Json(params string[] args)
    {
        var (exit, output) = Cli.Run("hyprctl", new[] { "-j" }.Concat(args));
        if (exit != 0 || string.IsNullOrWhiteSpace(output)) return null;
        try { return JsonDocument.Parse(output).RootElement.Clone(); } catch { return null; }
    }

    public int ActivePid() => Json("activewindow") is { ValueKind: JsonValueKind.Object } w && w.TryGetProperty("pid", out var p) ? p.GetInt32() : 0;

    public bool HasWindow(int pid) =>
        Json("clients") is { ValueKind: JsonValueKind.Array } list && list.EnumerateArray().Any(c => c.TryGetProperty("pid", out var p) && p.GetInt32() == pid && c.TryGetProperty("mapped", out var m) && m.GetBoolean());

    public bool Activate(int pid) => Cli.Run("hyprctl", new[] { "dispatch", "focuswindow", $"pid:{pid}" }).exit == 0;

    public bool Close(int pid) => Cli.Run("hyprctl", new[] { "dispatch", "closewindow", $"pid:{pid}" }).exit == 0;

    public void Dispose() { }
}

/// <summary>Sway, through swaymsg.</summary>
public sealed class SwayWindowSystem : IWindowSystem
{
    public string Name => "sway";

    static IEnumerable<JsonElement> Walk(JsonElement n)
    {
        yield return n;
        foreach (var key in new[] { "nodes", "floating_nodes" })
            if (n.TryGetProperty(key, out var kids) && kids.ValueKind == JsonValueKind.Array)
                foreach (var k in kids.EnumerateArray())
                    foreach (var d in Walk(k)) yield return d;
    }

    static List<JsonElement> Tree()
    {
        var (exit, output) = Cli.Run("swaymsg", new[] { "-t", "get_tree" });
        if (exit != 0) return new();
        try { return Walk(JsonDocument.Parse(output).RootElement.Clone()).ToList(); } catch { return new(); }
    }

    static int Pid(JsonElement n) => n.TryGetProperty("pid", out var p) && p.ValueKind == JsonValueKind.Number ? p.GetInt32() : 0;

    public int ActivePid() => Tree().Where(n => n.TryGetProperty("focused", out var f) && f.ValueKind == JsonValueKind.True).Select(Pid).FirstOrDefault();

    public bool HasWindow(int pid) => Tree().Any(n => Pid(n) == pid);

    public bool Activate(int pid) => Cli.Run("swaymsg", new[] { $"[pid={pid}] focus" }).exit == 0;

    public bool Close(int pid) => Cli.Run("swaymsg", new[] { $"[pid={pid}] kill" }).exit == 0;

    public void Dispose() { }
}
