using System.Net.Sockets;

namespace KovaaksPlus;

/// <summary>Only one copy runs: a second launch asks the first to come forward (over a Unix socket) and exits.</summary>
public sealed class SingleInstance : IDisposable
{
    readonly string _path;
    Socket? _listener;

    public SingleInstance()
    {
        var dir = Environment.GetEnvironmentVariable("XDG_RUNTIME_DIR");
        if (string.IsNullOrEmpty(dir) || !Directory.Exists(dir)) dir = Path.GetTempPath();
        _path = Path.Combine(dir, "kovaaks-plus" + (Environment.GetEnvironmentVariable("KPLUS_INSTANCE") is { Length: > 0 } id ? "-" + id : "") + ".sock");
    }

    /// <summary>True if this is the first instance (and the socket is now ours); false after notifying the running one.</summary>
    public bool TryAcquire()
    {
        try
        {
            using var probe = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified);
            probe.Connect(new UnixDomainSocketEndPoint(_path));
            probe.Send("show\n"u8.ToArray());
            return false;
        }
        catch (SocketException) { /* nobody is listening: stale file or first run */ }

        try { File.Delete(_path); } catch { }
        _listener = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified);
        _listener.Bind(new UnixDomainSocketEndPoint(_path));
        _listener.Listen(4);
        return true;
    }

    public void Listen(Action onShow)
    {
        var l = _listener;
        if (l == null) return;
        new Thread(() =>
        {
            while (true)
            {
                try
                {
                    using var c = l.Accept();
                    var buf = new byte[16];
                    c.ReceiveTimeout = 500;
                    c.Receive(buf);
                    onShow();
                }
                catch (ObjectDisposedException) { return; }
                catch { /* ignore a bad client */ }
            }
        }) { IsBackground = true, Name = "kplus-single" }.Start();
    }

    public void Dispose()
    {
        try { _listener?.Dispose(); File.Delete(_path); } catch { }
    }
}
