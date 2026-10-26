using System.Runtime.InteropServices;

namespace KovaaksPlus;

static class Program
{
    [DllImport("libglib-2.0.so.0")] static extern void g_set_prgname(string name);
    // Environment.SetEnvironmentVariable does not reach native libraries on Unix; the GTK/WebKit/EGL stack reads the real environment.
    [DllImport("libc", SetLastError = true)] static extern int setenv(string name, string value, int overwrite);

    static int Main(string[] args)
    {
        if (args.Contains("--diagnose")) return Diagnose.Run(args);

        using var single = new SingleInstance();
        if (!single.TryAcquire()) return 0;   // already running: it has been asked to come forward

        AppPaths.Ensure();
        try { g_set_prgname("kovaaks-plus"); } catch { }   // the Wayland app id / X11 class, matching the .desktop file

        // WebKitGTK workarounds, applied only where the user has not already chosen a value:
        //  - the NVIDIA EGL driver attaches an explicit-sync object to the window surface that GTK3 then violates ("no acquire point"), killing the app on Wayland
        //  - the DMABUF renderer shows a blank view on some NVIDIA driver versions; KPLUS_GPU_RENDER=1 keeps it enabled (hardware rendering)
        if (Environment.GetEnvironmentVariable("__NV_DISABLE_EXPLICIT_SYNC") == null) setenv("__NV_DISABLE_EXPLICIT_SYNC", "1", 0);
        if (Environment.GetEnvironmentVariable("KPLUS_GPU_RENDER") != "1" && Environment.GetEnvironmentVariable("WEBKIT_DISABLE_DMABUF_RENDERER") == null)
            setenv("WEBKIT_DISABLE_DMABUF_RENDERER", "1", 0);

        // UI host: the native Qt Quick UI (kovaaks-plus-ui, built by build.sh) when it is installed. KPLUS_HOST=chromium uses a
        // Chromium app window instead, KPLUS_HOST=webkit the built-in WebKitGTK window; "auto" falls back in that order.
        var kind = (Environment.GetEnvironmentVariable("KPLUS_HOST") ?? "auto").ToLowerInvariant();
        var ui = kind is "auto" or "qml" ? QmlHost.FindUi() : null;
        if (kind == "qml" && ui == null) throw new InvalidOperationException("kovaaks-plus-ui not found (build it with ./build.sh, or set KPLUS_UI_BIN)");
        if (ui != null)
        {
            var qml = new QmlHost(ui);
            single.Listen(qml.ActivateFromSecondInstance);
            qml.Run();
            return 0;
        }
        var browser = kind == "webkit" ? null : ChromiumHost.FindBrowser();
        if (browser != null)
        {
            var host = new ChromiumHost(browser);
            single.Listen(host.ActivateFromSecondInstance);
            host.Run();
            return 0;
        }

        var window = new AppWindow();
        single.Listen(window.ActivateFromSecondInstance);
        window.Run();
        return 0;
    }
}
