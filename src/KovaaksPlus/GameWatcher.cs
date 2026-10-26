using System.Diagnostics;
using System.Text;
using System.Text.RegularExpressions;
using KovaaksPlus.Platform;

namespace KovaaksPlus;

/// <summary>
/// Observes KovaaK's from the outside (process list, keyboard, stats folder, log file) and switches window focus.
/// Nothing is injected into the game process. On Linux the game is a Wine process started by Proton.
/// </summary>
public sealed class GameWatcher : IDisposable
{
    readonly Func<AppConfig> _config;
    readonly Action<Action> _post;       // runs an action on the app's serialised UI/RPC context
    readonly IWindowSystem _ws = WindowSystems.Create();
    readonly X11? _x11 = X11.TryOpen();  // own connection for key polling and key injection
    GamePaths? _paths;

    int _gamePid;
    DateTime _startUtc = DateTime.MinValue;
    Timer? _poll;
    FileSystemWatcher? _statsWatcher;
    readonly HashSet<string> _seenStats = new(StringComparer.OrdinalIgnoreCase);

    // Pause detection runs on its own thread so a busy UI can never add input lag in game.
    KeyWatcher? _keys;
    long _lastPauseTicks;
    long _expectResumeUntilTicks;
    bool _noticeSent;

    long _logPos = -1;
    static readonly Regex StartRx = new(@"Scenario start broadcast: '(.+?)'", RegexOptions.Compiled);

    // Which scenario is loaded comes from several signals; the newest one wins:
    // our own Play button, session.sav (rewritten by the game), finished runs, and the log if it is live.
    FileSystemWatcher? _sessionWatcher;
    DateTime _currentAtUtc = DateTime.MinValue;

    public event Action<bool>? StatusChanged;
    public event Action? PauseDetected;
    public event Action<string>? StatsFileCreated;
    public event Action<string>? ScenarioStarted;
    /// <summary>A one-off message for the user (for example, pause detection needs input-device access).</summary>
    public event Action<string>? Notice;

    public bool IsRunning => _gamePid != 0;
    public int GamePid => _gamePid;
    public string? CurrentScenario { get; private set; }
    public string WindowBackend => _ws.Name;

    public void SetCurrentScenario(string? name, DateTime? atUtc = null)
    {
        var at = atUtc ?? DateTime.UtcNow;
        if (string.IsNullOrWhiteSpace(name) || at < _currentAtUtc) return;
        _currentAtUtc = at;
        if (name == CurrentScenario) return;
        CurrentScenario = name;
        ScenarioStarted?.Invoke(name);
    }

    /// <summary>Re-reads session.sav and adopts its scenario if it was written after our last signal.</summary>
    public void RefreshFromSession()
    {
        var s = SessionSave.Read();
        if (s?.ScenarioName is { Length: > 0 } n && (_gamePid == 0 || s.WrittenUtc >= _startUtc))
            SetCurrentScenario(n, s.WrittenUtc);
    }

    void WatchSession()
    {
        _sessionWatcher?.Dispose();
        _sessionWatcher = null;
        var file = SessionSave.PathFor();
        var dir = Path.GetDirectoryName(file)!;
        if (!Directory.Exists(dir)) return;
        _sessionWatcher = new FileSystemWatcher(dir, "session.sav") { NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.FileName | NotifyFilters.Size };
        void Changed() => _post(async () => { await Task.Delay(250); RefreshFromSession(); });
        _sessionWatcher.Changed += (_, _) => Changed();
        _sessionWatcher.Created += (_, _) => Changed();
        _sessionWatcher.Renamed += (_, _) => Changed();
        _sessionWatcher.EnableRaisingEvents = true;
    }

    public GameWatcher(Action<Action> post, Func<AppConfig> config)
    {
        _post = post;
        _config = config;
    }

    public void Start(GamePaths paths)
    {
        _paths = paths;
        _poll ??= new Timer(_ => _post(() => OnPoll()), null, Timeout.Infinite, Timeout.Infinite);
        _poll.Change(0, 1000);
        WatchStats();
        WatchSession();
        UpdateHook();
    }

    void WatchStats()
    {
        _statsWatcher?.Dispose();
        _statsWatcher = null;
        if (_paths == null || !Directory.Exists(_paths.Stats)) return;
        _statsWatcher = new FileSystemWatcher(_paths.Stats, "*.csv")
        {
            NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite,
            InternalBufferSize = 64 * 1024,
        };
        _statsWatcher.Created += (_, e) => OnStats(e.FullPath);
        _statsWatcher.Renamed += (_, e) => OnStats(e.FullPath);
        _statsWatcher.EnableRaisingEvents = true;
    }

    void OnStats(string path)
    {
        if (!path.EndsWith("Stats.csv", StringComparison.OrdinalIgnoreCase)) return;
        lock (_seenStats) if (!_seenStats.Add(Path.GetFileName(path))) return;
        _post(() => StatsFileCreated?.Invoke(path));
    }

    void OnPoll()
    {
        bool was = _gamePid != 0;
        if (_gamePid != 0 && !StillGame(_gamePid)) _gamePid = 0;
        if (_gamePid == 0)
        {
            _gamePid = Procs.FindByExe(GamePaths.ProcessName);
            _startUtc = _gamePid != 0 ? Procs.StartTimeUtc(_gamePid) : DateTime.MinValue;
            if (_gamePid != 0) _logPos = -1;
        }
        bool now = _gamePid != 0;
        if (was != now)
        {
            if (!now) { CurrentScenario = null; _currentAtUtc = DateTime.MinValue; }
            else RefreshFromSession();
            StatusChanged?.Invoke(now);
        }
        if (now) TailLog();
    }

    static bool StillGame(int pid) => Procs.Comm(pid) is { } c && c.StartsWith(GamePaths.ProcessName[..15], StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Optional: if the game is actively writing its log, use it to learn which scenario is loaded.
    /// Recent KovaaK's builds stopped writing it, so a log older than the running game is ignored entirely.
    /// </summary>
    void TailLog()
    {
        try
        {
            var log = _paths?.LogFile;
            if (log == null || !File.Exists(log)) return;
            var start = _startUtc;
            var written = File.GetLastWriteTimeUtc(log);
            using var fs = new FileStream(log, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
            if (_logPos < 0)
            {
                // Created/rotated by this game session → read it from the top; otherwise only read what gets appended.
                _logPos = File.GetCreationTimeUtc(log) >= start.AddSeconds(-5) && written >= start ? 0 : fs.Length;
            }
            if (fs.Length < _logPos) _logPos = 0;   // rotated while running
            if (fs.Length == _logPos || written < start) return;
            fs.Seek(_logPos, SeekOrigin.Begin);
            var buf = new byte[Math.Min(fs.Length - _logPos, 1024 * 1024)];
            int n = fs.Read(buf, 0, buf.Length);
            _logPos += n;
            var text = Encoding.UTF8.GetString(buf, 0, n);
            string? last = null;
            foreach (Match m in StartRx.Matches(text)) last = m.Groups[1].Value;
            if (last != null) SetCurrentScenario(last);
        }
        catch { /* log is best-effort */ }
    }

    // ---------------- keyboard (pause detection) ----------------

    public void UpdateHook()
    {
        var cfg = _config();
        var key = KeyMap.TryGet(cfg.PauseKey, out var k) ? k : KeyMap.TryGet("Escape", out var esc) ? esc : default;
        if (cfg.PauseBringsApp)
        {
            if (_keys == null)
            {
                _keys = new KeyWatcher(OnPauseKey, _x11);
                _keys.SetKey(key.Code);
                _keys.Start();
                Task.Delay(4000).ContinueWith(_ => CheckKeyAccess());
            }
            else _keys.SetKey(key.Code);
        }
        else if (_keys != null)
        {
            _keys.Dispose();
            _keys = null;
        }
    }

    void CheckKeyAccess()
    {
        var keys = _keys;
        if (keys?.Warning == null || _noticeSent) return;
        _noticeSent = true;
        Notice?.Invoke(keys.Source == "x11-poll"
            ? "Pause detection is in limited mode (the game must be focused to see the key). For full support add yourself to the \"input\" group: sudo usermod -aG input $USER, then log out and in."
            : "Pause detection can't read the keyboard. Add yourself to the \"input\" group: sudo usermod -aG input $USER, then log out and in.");
    }

    /// <summary>Runs on the key thread for each press of the pause key: must stay tiny and never block.</summary>
    void OnPauseKey()
    {
        int pid = _gamePid;
        if (pid == 0 || _ws.ActivePid() != pid) return;
        long now = DateTime.UtcNow.Ticks;
        if (now < Interlocked.Read(ref _expectResumeUntilTicks))
        {
            // The user is un-pausing the game after we handed focus back — not a new pause.
            Interlocked.Exchange(ref _expectResumeUntilTicks, 0);
        }
        else if (now - Interlocked.Read(ref _lastPauseTicks) > TimeSpan.TicksPerMillisecond * 500)
        {
            Interlocked.Exchange(ref _lastPauseTicks, now);
            // Let the game process its own pause first, then come forward.
            _post(async () => { await Task.Delay(120); RefreshFromSession(); PauseDetected?.Invoke(); });
        }
    }

    // ---------------- actions ----------------

    /// <summary>True when the window system can see a window of the game (or it has been up long enough that we stop waiting).</summary>
    bool GameHasWindow() => _gamePid != 0 && (_ws.HasWindow(_gamePid) || (DateTime.UtcNow - _startUtc).TotalSeconds > 30);

    /// <summary>Hands focus back to KovaaK's. If <paramref name="resuming"/>, the next pause key is treated as "unpause".</summary>
    public bool FocusGame(bool resuming)
    {
        if (_gamePid == 0) return false;
        Interlocked.Exchange(ref _expectResumeUntilTicks, resuming ? DateTime.UtcNow.AddSeconds(4).Ticks : 0);
        return _ws.Activate(_gamePid);
    }

    /// <summary>Raises this app's own window (the compositor decides how; see <see cref="IWindowSystem"/>).</summary>
    public bool FocusSelf() => SelfProcessRoot is { } root ? _ws.Activate(Procs.Tree(root)) : _ws.Activate(SelfPid);

    /// <summary>Process that owns this app's window: this process, or the browser process when the UI runs in Chromium.</summary>
    public int SelfPid { get; set; } = Environment.ProcessId;

    /// <summary>Set when the window belongs to a child process tree (a browser): any process in the tree may own the window.</summary>
    public int? SelfProcessRoot { get; set; }

    /// <summary>
    /// Switches to KovaaK's and, when asked, presses its restart key so the run starts over instead of sitting in
    /// the pause menu / results screen. The key is only sent once KovaaK's is confirmed to be the foreground window.
    /// </summary>
    public async Task<bool> ReturnToGame(bool restart)
    {
        if (!FocusGame(resuming: !restart)) return false;
        if (!restart) return true;
        for (int i = 0; i < 20 && _ws.ActivePid() != _gamePid; i++) await Task.Delay(50);
        await Task.Delay(220);
        if (_ws.ActivePid() != _gamePid) return false;
        await Task.Run(() => KeyInjector.Tap(_x11, RestartKey()));
        return true;
    }

    /// <summary>The configured restart key, or KovaaK's own "ResetSession" bind read from Input.ini when set to auto.</summary>
    public KeyMap.Key RestartKey()
    {
        var cfg = _config().RestartKey;
        if (!string.Equals(cfg, "auto", StringComparison.OrdinalIgnoreCase) && KeyMap.TryGet(cfg, out var k)) return k;
        return DetectRestartKey() ?? (KeyMap.TryGet("R", out var r) ? r : default);
    }

    public static KeyMap.Key? DetectRestartKey()
    {
        try
        {
            var ini = Path.Combine(GamePaths.LocalData, "Saved", "Config", "WindowsNoEditor", "Input.ini");
            if (!File.Exists(ini)) return null;
            var m = Regex.Match(File.ReadAllText(ini), @"ActionName=""ResetSession"",bShift=False,bCtrl=False,bAlt=False,bCmd=False,Key=(\w+)");
            if (!m.Success) return null;
            return KeyMap.TryFromUnreal(m.Groups[1].Value, out var key) ? key : null;
        }
        catch { return null; }
    }

    public void LaunchGame() => Native.OpenUrl($"steam://rungameid/{GamePaths.AppId}");

    /// <summary>
    /// Waits until a just-started KovaaK's has a window, so deep links are not fired at a game
    /// that is still booting.
    /// </summary>
    async Task<bool> WaitUntilResponsive(int timeoutMs)
    {
        var sw = Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds < timeoutMs)
        {
            if (!IsRunning) return false;
            if (GameHasWindow() && (DateTime.UtcNow - _startUtc).TotalSeconds > 8) return true;
            await Task.Delay(400);
        }
        return false;
    }

    /// <summary>Uses KovaaK's own deep link (the same one behind its Discord "Play this scenario" button).</summary>
    public async Task PlayScenario(string name, string mode)
    {
        mode = mode.Equals("freeplay", StringComparison.OrdinalIgnoreCase) ? "freeplay" : "challenge";
        var url = $"steam://run/{GamePaths.AppId}//?action=jump-to-scenario&name={Uri.EscapeDataString(name)}&mode={mode}";
        bool wasRunning = IsRunning;
        if (wasRunning) await WaitUntilResponsive(45000);
        Native.OpenUrl(url);
        SetCurrentScenario(name);
        if (!wasRunning || !_config().FocusGameOnPlay) return;
        await Task.Delay(350);
        FocusGame(false);
    }

    /// <summary>Opens a playlist by share code (KovaaK's "jump-to-playlist" deep link).</summary>
    public async Task PlayPlaylist(string sharecode)
    {
        bool wasRunning = IsRunning;
        if (wasRunning) await WaitUntilResponsive(45000);
        Native.OpenUrl($"steam://run/{GamePaths.AppId}//?action=jump-to-playlist&sharecode={Uri.EscapeDataString(sharecode)}");
        if (!wasRunning || !_config().FocusGameOnPlay) return;
        await Task.Delay(350);
        FocusGame(false);
    }

    /// <summary>Closes the game the polite way (a window close, so it saves its settings), falling back to SIGTERM.</summary>
    public async Task<bool> CloseGameAsync(int timeoutMs = 20000)
    {
        int pid = _gamePid;
        if (pid == 0 || !Procs.Exists(pid)) return true;
        if (!_ws.Close(pid)) Libc.kill(pid, 15);
        var sw = Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds < timeoutMs)
        {
            if (!StillGame(pid)) { OnPoll(); return true; }
            await Task.Delay(250);
        }
        return false;
    }

    public void Dispose()
    {
        _keys?.Dispose();
        _statsWatcher?.Dispose();
        _sessionWatcher?.Dispose();
        _poll?.Dispose();
        _ws.Dispose();
        _x11?.Dispose();
    }
}
