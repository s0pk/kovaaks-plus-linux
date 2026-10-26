using System.Runtime.InteropServices;

namespace KovaaksPlus.Platform;

/// <summary>
/// Notices presses of one key, system-wide, without injecting anything into the game.
/// Primary source: the kernel's evdev keyboards (/dev/input/event*), which works on X11 and every Wayland compositor but
/// needs read access (membership of the "input" group). Fallback: polling the X server's key state, which needs no
/// permissions and sees keys exactly while an X11/XWayland window — i.e. a Proton game — has keyboard focus.
/// Only the one configured key is ever looked at; everything else is discarded immediately.
/// </summary>
public sealed unsafe class KeyWatcher : IDisposable
{
    readonly Action _onPress;
    readonly X11? _x11;
    Thread? _thread;
    volatile bool _stop;
    volatile int _code;

    public string Source { get; private set; } = "none";
    /// <summary>Diagnostics only: how many keyboards are open and how many key events (of any key) they delivered. No key identities are kept.</summary>
    public int DeviceCount { get; private set; }
    public long KeyEventCount { get; private set; }
    /// <summary>Set when the preferred source (evdev) is unavailable and a hint should be shown to the user.</summary>
    public string? Warning { get; private set; }

    public KeyWatcher(Action onPress, X11? x11)
    {
        _onPress = onPress;
        _x11 = x11;
    }

    public void SetKey(int evdevCode) => _code = evdevCode;

    public void Start()
    {
        if (_thread != null) return;
        _stop = false;
        _thread = new Thread(Run) { IsBackground = true, Name = "KeyWatcher", Priority = ThreadPriority.AboveNormal };
        _thread.Start();
    }

    public void Stop()
    {
        _stop = true;
        _thread?.Join(1500);
        _thread = null;
    }

    public void Dispose() => Stop();

    // ---------------- evdev ----------------

    static List<string> KeyboardNodes()
    {
        var nodes = new List<string>();
        try
        {
            // Each device block lists its handlers ("kbd event3") and which key bits it supports.
            string? handlers = null, keys = null;
            foreach (var line in File.ReadLines("/proc/bus/input/devices").Append(""))
            {
                if (line.Length == 0)
                {
                    if (handlers != null && handlers.Contains("kbd") && keys != null && HasEscAndLetters(keys))
                        foreach (var h in handlers.Split(' ')) if (h.StartsWith("event")) nodes.Add("/dev/input/" + h);
                    handlers = keys = null;
                }
                else if (line.StartsWith("H: Handlers=")) handlers = line[12..];
                else if (line.StartsWith("B: KEY=")) keys = line[7..];
            }
        }
        catch { }
        return nodes;
    }

    /// <summary>The KEY bitmap is printed as space-separated hex words, most significant first.</summary>
    static bool HasEscAndLetters(string keyBits)
    {
        var words = keyBits.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        // Bits 0-63 are the last word on 64-bit kernels: KEY_ESC is bit 1, KEY_A is bit 30.
        if (words.Length == 0) return false;
        try { var low = Convert.ToUInt64(words[^1], 16); return (low & (1UL << 1)) != 0 && (low & (1UL << 30)) != 0; }
        catch { return false; }
    }

    void Run()
    {
        var fds = new Dictionary<int, string>();
        long lastScan = 0;
        var evBuf = stackalloc byte[24 * 64];
        var pfds = stackalloc Libc.PollFd[64];

        while (!_stop)
        {
            if (Environment.TickCount64 - lastScan > 3000)
            {
                lastScan = Environment.TickCount64;
                foreach (var node in Environment.GetEnvironmentVariable("KPLUS_KEY_SOURCE") == "x11" ? new List<string>() : KeyboardNodes())
                {
                    if (fds.ContainsValue(node) || fds.Count >= 64) continue;
                    var fd = Libc.open(node, Libc.O_RDONLY | Libc.O_NONBLOCK | Libc.O_CLOEXEC);
                    if (fd >= 0) fds[fd] = node;
                }
                DeviceCount = fds.Count;
                if (fds.Count > 0) { Source = "evdev"; Warning = null; }
                else if (_x11 != null) { Source = "x11-poll"; Warning ??= "no-input-access"; }
                else { Source = "none"; Warning ??= "no-input-access"; }
            }

            if (fds.Count == 0)
            {
                if (_x11 != null) PollX11();
                else Thread.Sleep(500);
                continue;
            }

            int n = 0;
            foreach (var fd in fds.Keys) { pfds[n].fd = fd; pfds[n].events = Libc.POLLIN; pfds[n].revents = 0; n++; }
            if (Libc.poll(pfds, (ulong)n, 250) <= 0) continue;
            for (int i = 0; i < n; i++)
            {
                if (pfds[i].revents == 0) continue;
                var fd = pfds[i].fd;
                var got = Libc.read(fd, evBuf, 24 * 64);
                if (got < 0 && Marshal.GetLastWin32Error() == 11 /*EAGAIN*/) continue;
                if (got <= 0)
                {
                    // Unplugged (ENODEV) or otherwise gone: forget it; a rescan picks it up again if it returns.
                    Libc.close(fd); fds.Remove(fd);
                    continue;
                }
                for (int off = 0; off + 24 <= got; off += 24)
                {
                    // struct input_event { timeval(16); u16 type; u16 code; s32 value; }
                    var type = *(ushort*)(evBuf + off + 16);
                    var code = *(ushort*)(evBuf + off + 18);
                    var value = *(int*)(evBuf + off + 20);
                    if (type == 1 && value == 1) KeyEventCount++;
                    if (type == 1 && value == 1 && code == _code) Fire();
                }
            }
        }
        foreach (var fd in fds.Keys) Libc.close(fd);
    }

    // ---------------- X11 polling fallback ----------------

    readonly byte[] _map = new byte[32];
    bool _wasDown;

    void PollX11()
    {
        Thread.Sleep(8);
        if (_x11 == null || !_x11.QueryKeymap(_map)) return;
        int kc = _code + 8;
        bool down = (_map[kc >> 3] & (1 << (kc & 7))) != 0;
        if (down && !_wasDown) Fire();
        _wasDown = down;
    }

    void Fire()
    {
        try { _onPress(); } catch { }
    }
}
