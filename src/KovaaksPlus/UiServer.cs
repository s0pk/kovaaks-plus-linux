using System.Net;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Reflection;

namespace KovaaksPlus;

/// <summary>
/// Serves the UI to the embedded browser over loopback HTTP: the bundled web files, plus read-only views of the media
/// folder (/media/) and the game's crosshair images (/crosshair/). A real HTTP origin (instead of a custom URL scheme)
/// gives the page working video seeking and normal resource loading. It carries no API: all actions go through the
/// window's private message channel, so other programs or web pages cannot drive the app through this port.
/// </summary>
public sealed class UiServer : IDisposable
{
    readonly HttpListener _listener = new();
    readonly Func<string?> _crosshairDir;
    readonly string? _devDir;
    readonly CancellationTokenSource _cts = new();
    /// <summary>When set, /ws upgrades to a WebSocket for the page's RPC (used by the Chromium host).</summary>
    public string? Token { get; set; }
    public Func<WebSocket, Task>? OnSocket { get; set; }
    public int Port { get; }
    public string Origin => $"http://127.0.0.1:{Port}";

    static readonly Dictionary<string, string> Mime = new(StringComparer.OrdinalIgnoreCase)
    {
        [".html"] = "text/html; charset=utf-8", [".js"] = "text/javascript; charset=utf-8", [".css"] = "text/css; charset=utf-8",
        [".svg"] = "image/svg+xml", [".png"] = "image/png", [".jpg"] = "image/jpeg", [".jpeg"] = "image/jpeg", [".gif"] = "image/gif",
        [".webp"] = "image/webp", [".bmp"] = "image/bmp", [".json"] = "application/json", [".woff2"] = "font/woff2",
        [".ico"] = "image/x-icon", [".mp3"] = "audio/mpeg", [".wav"] = "audio/wav", [".ogg"] = "audio/ogg",
        [".mp4"] = "video/mp4", [".webm"] = "video/webm",
    };

    // Embedded files are named like "wwwroot/js/views/home.js"; index them by URL path.
    static readonly Dictionary<string, string> Embedded = Assembly.GetExecutingAssembly().GetManifestResourceNames()
        .Where(n => n.StartsWith("wwwroot", StringComparison.Ordinal))
        .ToDictionary(n => n.Replace('\\', '/')["wwwroot/".Length..], n => n, StringComparer.OrdinalIgnoreCase);

    public UiServer(Func<string?> crosshairDir)
    {
        _crosshairDir = crosshairDir;
        var dev = Environment.GetEnvironmentVariable("KPLUS_UI_DIR");
        _devDir = !string.IsNullOrEmpty(dev) && Directory.Exists(dev) ? Path.GetFullPath(dev) : null;

        // Pick a free loopback port (the page origin changes per launch; the UI keeps nothing in origin-bound storage).
        for (int attempt = 0; ; attempt++)
        {
            var probe = new TcpListener(IPAddress.Loopback, 0);
            probe.Start();
            var port = ((IPEndPoint)probe.LocalEndpoint).Port;
            probe.Stop();
            try
            {
                _listener.Prefixes.Clear();
                _listener.Prefixes.Add($"http://127.0.0.1:{port}/");
                _listener.Start();
                Port = port;
                break;
            }
            catch (HttpListenerException) when (attempt < 10) { }
        }
        _ = Task.Run(AcceptLoop);
    }

    async Task AcceptLoop()
    {
        while (!_cts.IsCancellationRequested)
        {
            HttpListenerContext ctx;
            try { ctx = await _listener.GetContextAsync(); }
            catch { return; }
            if (ctx.Request.IsWebSocketRequest) _ = Task.Run(() => HandleSocket(ctx));
            else _ = Task.Run(() => Handle(ctx));
        }
    }

    /// <summary>
    /// The RPC channel for browser hosts. Only the page this app opened may connect: it must present the per-run secret token
    /// and, if they are a browser, come from this server's own origin, so no other web page or local program can drive the app through the port.
    /// </summary>
    async Task HandleSocket(HttpListenerContext ctx)
    {
        var req = ctx.Request;
        bool ok = Token != null && OnSocket != null && req.Url!.AbsolutePath == "/ws"
                  && req.Headers["Host"] == $"127.0.0.1:{Port}" && (req.Headers["Origin"] is null || req.Headers["Origin"] == Origin)
                  && System.Security.Cryptography.CryptographicOperations.FixedTimeEquals(
                      System.Text.Encoding.UTF8.GetBytes(req.QueryString["t"] ?? ""), System.Text.Encoding.UTF8.GetBytes(Token));
        if (!ok) { Fail(ctx.Response, 403); return; }
        try
        {
            var wsc = await ctx.AcceptWebSocketAsync(null);
            await OnSocket!(wsc.WebSocket);
        }
        catch { try { ctx.Response.Abort(); } catch { } }
    }

    void Handle(HttpListenerContext ctx)
    {
        var res = ctx.Response;
        try
        {
            var req = ctx.Request;
            // Refuse requests that arrive under another host name (DNS-rebinding protection).
            if (req.Headers["Host"] != $"127.0.0.1:{Port}") { Fail(res, 403); return; }
            if (req.HttpMethod != "GET" && req.HttpMethod != "HEAD") { Fail(res, 405); return; }

            var path = Uri.UnescapeDataString(req.Url!.AbsolutePath);
            if (path.Contains('\0')) { Fail(res, 400); return; }
            string? file = null;
            if (path.StartsWith("/media/")) file = Under(AppPaths.Media, path[7..]);
            else if (path.StartsWith("/crosshair/") && _crosshairDir() is { } ch) file = Under(ch, path[11..]);
            else
            {
                var rel = path.TrimStart('/');
                if (rel.Length == 0) rel = "index.html";
                if (_devDir != null) file = Under(_devDir, rel);
                else if (Embedded.TryGetValue(rel, out var resName))
                {
                    var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(resName)!;
                    Send(res, req, stream, stream.Length, Path.GetExtension(rel), cache: false);
                    return;
                }
            }
            if (file == null || !File.Exists(file)) { Fail(res, 404); return; }
            using var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            Send(res, req, fs, fs.Length, Path.GetExtension(file), cache: false);
        }
        catch { try { Fail(res, 500); } catch { } }
    }

    /// <summary>Resolves a relative URL path inside a root folder, refusing anything that escapes it.</summary>
    static string? Under(string root, string rel)
    {
        var full = Path.GetFullPath(Path.Combine(root, rel));
        var prefix = Path.GetFullPath(root).TrimEnd('/') + "/";
        return full.StartsWith(prefix, StringComparison.Ordinal) ? full : null;
    }

    static void Send(HttpListenerResponse res, HttpListenerRequest req, Stream body, long length, string ext, bool cache)
    {
        res.ContentType = Mime.GetValueOrDefault(ext, "application/octet-stream");
        res.Headers["Cache-Control"] = cache ? "max-age=3600" : "no-cache";
        res.Headers["X-Content-Type-Options"] = "nosniff";
        res.Headers["Accept-Ranges"] = "bytes";
        long start = 0, end = length - 1;
        res.StatusCode = 200;
        var range = req.Headers["Range"];
        if (range != null && range.StartsWith("bytes=") && length > 0)
        {
            var spec = range[6..].Split(',')[0].Split('-');
            long s = 0, e = length - 1;
            bool ok = true;
            if (spec[0].Length == 0 && long.TryParse(spec[1], out var suffix)) s = Math.Max(0, length - suffix);   // "-N": last N bytes
            else
            {
                ok = long.TryParse(spec[0], out s);
                if (ok && spec.Length > 1 && spec[1].Length > 0) ok = long.TryParse(spec[1], out e);
            }
            if (!ok || s > e || s >= length)
            {
                res.StatusCode = 416;
                res.Headers["Content-Range"] = $"bytes */{length}";
                res.Close();
                return;
            }
            start = s; end = Math.Min(e, length - 1);
            res.StatusCode = 206;
            res.Headers["Content-Range"] = $"bytes {start}-{end}/{length}";
        }
        res.ContentLength64 = end - start + 1;
        if (req.HttpMethod != "HEAD")
        {
            if (body.CanSeek) body.Seek(start, SeekOrigin.Begin);
            var buf = new byte[64 * 1024];
            long left = end - start + 1;
            while (left > 0)
            {
                int n = body.Read(buf, 0, (int)Math.Min(buf.Length, left));
                if (n <= 0) break;
                res.OutputStream.Write(buf, 0, n);
                left -= n;
            }
        }
        res.Close();
    }

    static void Fail(HttpListenerResponse res, int code)
    {
        res.StatusCode = code;
        res.ContentLength64 = 0;
        res.Close();
    }

    public void Dispose()
    {
        _cts.Cancel();
        try { _listener.Close(); } catch { }
    }
}
