using System.Text.Json;

namespace KovaaksPlus;

/// <summary>
/// Everything a UI host shares: the single RPC thread, the <see cref="Api"/>, and the JSON message protocol with the page
/// (requests in, responses and events out, with events queued until the page starts talking).
/// A host only supplies the transport (<see cref="SendRaw"/>) and the window-specific actions.
/// </summary>
public abstract class HostBase : IAppHost
{
    protected readonly RpcContext Rpc = new();
    protected UiServer Server = null!;
    readonly Queue<string> _pending = new();
    readonly object _gate = new();
    bool _ready;
    protected string? CrosshairDir;

    /// <summary>True once the transport can deliver messages to the page.</summary>
    protected volatile bool Created;

    public Api Api { get; }

    protected HostBase() => Api = new Api(this, a => Rpc.Run(a));

    protected abstract void SendRaw(string json);
    public abstract void BringToFrontForced();
    public abstract void SetZoom(double factor);
    public abstract string? PickFolder(string title);
    public abstract string? PickOpenFile(string title, params (string Name, string[] Extensions)[] filters);
    public abstract string? PickSaveFile(string title, string defaultName, params (string Name, string[] Extensions)[] filters);

    /// <summary>Handles one request from the page, on the RPC thread.</summary>
    protected void Receive(string raw) => Rpc.Post(_ => { _ = OnMessage(raw); }, null);

    async Task OnMessage(string raw)
    {
        int id = 0;
        try
        {
            using var doc = JsonDocument.Parse(raw);
            var root = doc.RootElement;
            id = root.GetProperty("id").GetInt32();
            // The page is up and listening once it starts talking: release anything queued for it.
            MarkReady();
            var method = root.GetProperty("method").GetString()!;
            var p = root.TryGetProperty("params", out var pp) ? pp.Clone() : default;
            var result = await Api.Handle(method, p);
            Post(JsonSerializer.Serialize(new { id, result }, Json.Compact));
        }
        catch (Exception ex)
        {
            var msg = ex is AggregateException ae ? ae.InnerException?.Message ?? ex.Message : ex.Message;
            Post(JsonSerializer.Serialize(new { id, error = msg }, Json.Compact));
        }
    }

    void MarkReady()
    {
        List<string> flush;
        lock (_gate)
        {
            if (_ready) return;
            _ready = true;
            flush = _pending.ToList();
            _pending.Clear();
        }
        foreach (var m in flush) SafeSend(m);
    }

    void Post(string json)
    {
        lock (_gate)
        {
            if (!_ready || !Created)
            {
                if (_pending.Count < 500) _pending.Enqueue(json);
                return;
            }
        }
        SafeSend(json);
    }

    void SafeSend(string json)
    {
        try { SendRaw(json); } catch { /* window closing */ }
    }

    /// <summary>Pushes an event to the UI (thread-safe).</summary>
    public void Emit(string evt, object? data)
    {
        try { Post(JsonSerializer.Serialize(new { @event = evt, data }, Json.Compact)); } catch { /* window closing */ }
    }

    /// <summary>Exposes the game's crosshair images to the UI (read-only) once the install folder is known.</summary>
    public void OnGamePathsReady(GamePaths paths) =>
        CrosshairDir = Directory.Exists(paths.Crosshairs) ? paths.Crosshairs : null;

    /// <summary>Called when a second copy of the app is started: show this one instead.</summary>
    public void ActivateFromSecondInstance() => BringToFrontForced();
}
