using System.Runtime.InteropServices;

namespace KovaaksPlus.Platform;

/// <summary>
/// Minimal Xlib/XTest client: EWMH window queries and actions, key-state polling and synthetic key taps.
/// It talks to the X server (or XWayland on a Wayland desktop) over its own connection, so it works whatever
/// toolkit backend the app window itself uses. All calls are serialised with one lock.
/// </summary>
public sealed unsafe class X11 : IDisposable
{
    const string LibX11 = "libX11.so.6", LibXtst = "libXtst.so.6";

    [DllImport(LibX11)] static extern nint XOpenDisplay(string? name);
    [DllImport(LibX11)] static extern int XCloseDisplay(nint d);
    [DllImport(LibX11)] static extern nint XDefaultRootWindow(nint d);
    [DllImport(LibX11)] static extern nint XInternAtom(nint d, string name, int onlyIfExists);
    [DllImport(LibX11)] static extern int XGetWindowProperty(nint d, nint w, nint prop, long offset, long length, int delete, nint reqType,
        out nint actualType, out int actualFormat, out ulong nitems, out ulong bytesAfter, out nint data);
    [DllImport(LibX11)] static extern int XFree(nint p);
    [DllImport(LibX11)] static extern int XSendEvent(nint d, nint w, int propagate, long mask, void* ev);
    [DllImport(LibX11)] static extern int XFlush(nint d);
    [DllImport(LibX11)] static extern int XSync(nint d, int discard);
    [DllImport(LibX11)] static extern int XQueryKeymap(nint d, byte* keys);
    [DllImport(LibX11)] static extern nint XStringToKeysym(string s);
    [DllImport(LibX11)] static extern byte XKeysymToKeycode(nint d, nint keysym);
    [DllImport(LibX11)] static extern nint XSetErrorHandler(nint handler);
    [DllImport(LibXtst)] static extern int XTestFakeKeyEvent(nint d, uint keycode, int isPress, ulong delay);

    delegate int ErrorHandler(nint display, nint ev);
    static readonly ErrorHandler Ignore = (_, _) => 0;   // a window vanishing mid-query must not abort the process
    static bool _handlerSet;

    readonly object _gate = new();
    nint _d;
    nint _root;
    nint _aActive, _aClientList, _aPid, _aClose, _aState, _aHidden, _aName, _aUtf8, _aStringType;

    public static X11? TryOpen()
    {
        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("DISPLAY"))) return null;
        try
        {
            var d = XOpenDisplay(null);
            if (d == 0) return null;
            var x = new X11(d);
            return x;
        }
        catch (DllNotFoundException) { return null; }
        catch (EntryPointNotFoundException) { return null; }
    }

    X11(nint d)
    {
        _d = d;
        if (!_handlerSet) { XSetErrorHandler(Marshal.GetFunctionPointerForDelegate(Ignore)); _handlerSet = true; }
        _root = XDefaultRootWindow(d);
        _aActive = XInternAtom(d, "_NET_ACTIVE_WINDOW", 0);
        _aClientList = XInternAtom(d, "_NET_CLIENT_LIST", 0);
        _aPid = XInternAtom(d, "_NET_WM_PID", 0);
        _aClose = XInternAtom(d, "_NET_CLOSE_WINDOW", 0);
        _aState = XInternAtom(d, "_NET_WM_STATE", 0);
        _aHidden = XInternAtom(d, "_NET_WM_STATE_HIDDEN", 0);
        _aName = XInternAtom(d, "_NET_WM_NAME", 0);
        _aUtf8 = XInternAtom(d, "UTF8_STRING", 0);
        _aStringType = 31; // XA_STRING
    }

    public void Dispose()
    {
        lock (_gate) { if (_d != 0) XCloseDisplay(_d); _d = 0; }
    }

    // ---------------- properties ----------------

    /// <summary>Reads a 32-bit-format property as an array of unsigned longs (Xlib returns them as C longs).</summary>
    ulong[] GetLongs(nint window, nint prop, long maxItems = 4096)
    {
        if (XGetWindowProperty(_d, window, prop, 0, maxItems, 0, 0, out _, out var fmt, out var n, out _, out var data) != 0 || data == 0)
            return Array.Empty<ulong>();
        try
        {
            if (fmt != 32 || n == 0) return Array.Empty<ulong>();
            var res = new ulong[n];
            for (ulong i = 0; i < n; i++) res[i] = ((ulong*)data)[i];
            return res;
        }
        finally { XFree(data); }
    }

    string? GetString(nint window, nint prop, nint type)
    {
        if (XGetWindowProperty(_d, window, prop, 0, 1024, 0, type, out _, out var fmt, out var n, out _, out var data) != 0 || data == 0) return null;
        try { return fmt == 8 && n > 0 ? Marshal.PtrToStringUTF8(data, (int)n) : null; }
        finally { XFree(data); }
    }

    int WindowPid(nint w)
    {
        var v = GetLongs(w, _aPid, 1);
        return v.Length > 0 ? (int)v[0] : 0;
    }

    public readonly record struct Win(nint Id, int Pid, string Title);

    string Title(nint w) => GetString(w, _aName, _aUtf8) ?? GetString(w, 39 /*XA_WM_NAME*/, _aStringType) ?? "";

    public List<Win> Windows()
    {
        lock (_gate)
        {
            if (_d == 0) return new();
            return GetLongs(_root, _aClientList).Select(w => new Win((nint)w, WindowPid((nint)w), Title((nint)w))).ToList();
        }
    }

    /// <summary>The window the window manager reports as active (0 when none, or when a non-X11 client has focus).</summary>
    public nint ActiveWindow()
    {
        lock (_gate)
        {
            if (_d == 0) return 0;
            var v = GetLongs(_root, _aActive, 1);
            return v.Length > 0 ? (nint)v[0] : 0;
        }
    }

    /// <summary>Owning process of the active X11 window, or 0.</summary>
    public int ActivePid()
    {
        lock (_gate)
        {
            if (_d == 0) return 0;
            var v = GetLongs(_root, _aActive, 1);
            return v.Length > 0 && v[0] != 0 ? WindowPid((nint)v[0]) : 0;
        }
    }

    public bool IsMinimized(nint w)
    {
        lock (_gate) return _d != 0 && GetLongs(w, _aState).Contains((ulong)_aHidden);
    }

    // ---------------- EWMH actions ----------------

    bool Message(nint window, nint type, long d0, long d1 = 0, long d2 = 0, long d3 = 0, long d4 = 0)
    {
        var ev = stackalloc long[24];
        for (int i = 0; i < 24; i++) ev[i] = 0;
        *(int*)ev = 33;                    // ClientMessage
        ev[3] = _d;
        ev[4] = window;
        ev[5] = type;
        *(int*)(ev + 6) = 32;              // format
        ev[7] = d0; ev[8] = d1; ev[9] = d2; ev[10] = d3; ev[11] = d4;
        const long mask = (1L << 20) | (1L << 19);   // SubstructureRedirect | SubstructureNotify
        var ok = XSendEvent(_d, _root, 0, mask, ev) != 0;
        XFlush(_d);
        return ok;
    }

    /// <summary>Asks the window manager to activate a window (source 2 = pager/tool, which most WMs honour).</summary>
    public bool Activate(nint w)
    {
        lock (_gate) return _d != 0 && Message(w, _aActive, 2, 0, 0);
    }

    public bool Close(nint w)
    {
        lock (_gate) return _d != 0 && Message(w, _aClose, 0, 2);
    }

    // ---------------- keyboard ----------------

    /// <summary>Snapshot of the 256-bit pressed-key map (X keycode = evdev code + 8).</summary>
    public bool QueryKeymap(byte[] keys32)
    {
        lock (_gate)
        {
            if (_d == 0) return false;
            fixed (byte* p = keys32) XQueryKeymap(_d, p);
            return true;
        }
    }

    public int KeycodeFor(string keysym, int evdevFallback)
    {
        lock (_gate)
        {
            if (_d == 0) return evdevFallback + 8;
            var ks = XStringToKeysym(keysym);
            var kc = ks == 0 ? (byte)0 : XKeysymToKeycode(_d, ks);
            return kc != 0 ? kc : evdevFallback + 8;
        }
    }

    public bool FakeKey(int xKeycode, bool press)
    {
        lock (_gate)
        {
            if (_d == 0) return false;
            var ok = XTestFakeKeyEvent(_d, (uint)xKeycode, press ? 1 : 0, 0) != 0;
            XFlush(_d);
            return ok;
        }
    }
}
