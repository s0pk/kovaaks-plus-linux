using System.Diagnostics;
using System.Text.Json;
using KovaaksPlus.Platform;

namespace KovaaksPlus;

/// <summary>
/// The native UI: a Qt Quick (QML) program, <c>kovaaks-plus-ui</c>, rendered by Qt's scene graph on Vulkan or OpenGL in a
/// real Wayland/X11 window. This process keeps all the logic and runs headless; the UI is a thin client of <see cref="Api"/>.
/// </summary>
public sealed class QmlHost : SocketHost
{
    readonly string _ui;
    Process? _proc;

    /// <summary>KPLUS_UI_BIN, else kovaaks-plus-ui next to this executable, else on PATH.</summary>
    public static string? FindUi()
    {
        var env = Environment.GetEnvironmentVariable("KPLUS_UI_BIN");
        if (!string.IsNullOrEmpty(env)) return File.Exists(env) ? env : null;
        var next = Path.Combine(AppContext.BaseDirectory, "kovaaks-plus-ui");
        if (File.Exists(next)) return next;
        var exe = Path.Combine(Path.GetDirectoryName(Environment.ProcessPath ?? "") ?? "", "kovaaks-plus-ui");
        if (File.Exists(exe)) return exe;
        return Cli.Exists("kovaaks-plus-ui") ? "kovaaks-plus-ui" : null;
    }

    public QmlHost(string ui) => _ui = ui;

    public void Run()
    {
        Rpc.Run(Api.Start);
        var psi = new ProcessStartInfo(_ui) { UseShellExecute = false };
        psi.ArgumentList.Add("--ws"); psi.ArgumentList.Add($"ws://127.0.0.1:{Server.Port}/ws?t={Token}");
        psi.ArgumentList.Add("--http"); psi.ArgumentList.Add(Server.Origin);
        if (Environment.GetEnvironmentVariable("KPLUS_DEV") == "1") psi.ArgumentList.Add("--dev");
        _proc = Process.Start(psi) ?? throw new InvalidOperationException("Could not start " + _ui);
        Api.Watcher.SelfPid = _proc.Id;
        RunDevScript();
        _proc.WaitForExit();
        try { Api.Watcher.Dispose(); Api.Stats.Save(); } catch { }
        Server.Dispose();
        Rpc.Shutdown();
    }

    /// <summary>
    /// UI development aid (KPLUS_DEV=1 only): KPLUS_DEV_SCRIPT is a JSON array of steps, each {"delay":ms}, {"eval":"js"} (run in the UI)
    /// or {"mark":"name"} (creates KPLUS_DEV_MARKS/name.mark so an outside tool can take a screenshot at that moment).
    /// </summary>
    void RunDevScript()
    {
        var path = Environment.GetEnvironmentVariable("KPLUS_DEV_SCRIPT");
        if (Environment.GetEnvironmentVariable("KPLUS_DEV") != "1" || string.IsNullOrEmpty(path) || !File.Exists(path)) return;
        var marks = Environment.GetEnvironmentVariable("KPLUS_DEV_MARKS") ?? Path.GetTempPath();
        Task.Run(async () =>
        {
            try
            {
                for (int i = 0; i < 200 && !Created; i++) await Task.Delay(100);
                using var doc = JsonDocument.Parse(File.ReadAllText(path));
                foreach (var step in doc.RootElement.EnumerateArray())
                {
                    if (step.TryGetProperty("delay", out var d)) await Task.Delay(d.GetInt32());
                    if (step.TryGetProperty("eval", out var e)) Emit("dev.eval", new { code = e.GetString() });
                    if (step.TryGetProperty("mark", out var m)) { Directory.CreateDirectory(marks); File.WriteAllText(Path.Combine(marks, m.GetString() + ".mark"), ""); }
                }
            }
            catch (Exception ex) { Console.Error.WriteLine("[dev-script] " + ex.Message); }
        });
    }

    // ---------------- window actions ----------------

    public override void BringToFrontForced()
    {
        if (_proc == null) return;
        Task.Run(() => { try { Api.Watcher.FocusSelf(); } catch { } });
    }

    /// <summary>The Qt UI applies the interface scale itself.</summary>
    public override void SetZoom(double factor) => Emit("zoom", new { factor = Math.Clamp(factor, 0.6, 1.6) });

    // ---------------- dialogs: asked of the UI, which shows the platform's native dialog ----------------

    readonly Dictionary<int, TaskCompletionSource<string?>> _dialogs = new();
    int _dialogSeq;

    string? Ask(object request)
    {
        var tcs = new TaskCompletionSource<string?>();
        int id;
        lock (_dialogs) { id = ++_dialogSeq; _dialogs[id] = tcs; }
        Emit("dialog", new { id, request });
        return tcs.Task.GetAwaiter().GetResult();
    }

    protected override bool HandleControlMessage(string raw)
    {
        if (!raw.Contains("\"dialogResult\"")) return false;
        try
        {
            using var doc = JsonDocument.Parse(raw);
            var r = doc.RootElement.GetProperty("dialogResult");
            int id = r.GetProperty("id").GetInt32();
            var path = r.TryGetProperty("path", out var p) && p.ValueKind == JsonValueKind.String ? p.GetString() : null;
            TaskCompletionSource<string?>? tcs;
            lock (_dialogs) { _dialogs.Remove(id, out tcs); }
            tcs?.TrySetResult(path);
        }
        catch { }
        return true;
    }

    public override string? PickFolder(string title) => Ask(new { kind = "folder", title });
    public override string? PickOpenFile(string title, params (string Name, string[] Extensions)[] filters) =>
        Ask(new { kind = "open", title, filters = filters.Select(f => new { name = f.Name, extensions = f.Extensions }) });
    public override string? PickSaveFile(string title, string defaultName, params (string Name, string[] Extensions)[] filters) =>
        Ask(new { kind = "save", title, defaultName, filters = filters.Select(f => new { name = f.Name, extensions = f.Extensions }) });
}
