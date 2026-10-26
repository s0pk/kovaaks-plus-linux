using KovaaksPlus.Platform;

namespace KovaaksPlus;

/// <summary>Desktop integration: opening links, revealing files, the trash.</summary>
internal static class Native
{
    /// <summary>Characters that cannot appear in a Windows file name. Kept even on Linux so packs and media names stay portable.</summary>
    public static readonly char[] InvalidNameChars = "<>:\"/\\|?*".Concat(Enumerable.Range(0, 32).Select(i => (char)i)).ToArray();

    public static string SafeFileName(string name) => string.Concat(name.Split(InvalidNameChars));

    /// <summary>Opens a URL (http, https or steam://) with the desktop's registered handler.</summary>
    public static void OpenUrl(string url)
    {
        if (Cli.Exists("xdg-open") && Cli.Spawn("xdg-open", url)) return;
        if (url.StartsWith("steam://", StringComparison.OrdinalIgnoreCase) && Cli.Exists("steam")) { Cli.Spawn("steam", url); return; }
        if (Cli.Exists("gio")) Cli.Spawn("gio", "open", url);
    }

    /// <summary>Shows a file selected in the file manager, or opens a folder.</summary>
    public static void RevealInExplorer(string path)
    {
        if (Directory.Exists(path)) { OpenUrl(path); return; }
        if (!File.Exists(path)) return;
        var uri = new Uri(Path.GetFullPath(path)).AbsoluteUri;
        // org.freedesktop.FileManager1 is implemented by Dolphin, Nautilus, Thunar, Nemo, PCManFM-Qt…
        if (Cli.Exists("busctl") && Cli.Run("busctl", new[] { "--user", "call", "org.freedesktop.FileManager1", "/org/freedesktop/FileManager1",
                "org.freedesktop.FileManager1", "ShowItems", "ass", "1", uri, "" }, 4000).exit == 0) return;
        OpenUrl(Path.GetDirectoryName(Path.GetFullPath(path))!);
    }

    /// <summary>Moves a file to the desktop trash (the Linux Recycle Bin). Throws if it cannot.</summary>
    public static void MoveToTrash(string path)
    {
        if (Cli.Exists("gio") && Cli.Run("gio", new[] { "trash", path }, 10000).exit == 0) return;

        // Fallback: the FreeDesktop trash spec for the home trash directory.
        var dataHome = Environment.GetEnvironmentVariable("XDG_DATA_HOME");
        if (string.IsNullOrEmpty(dataHome)) dataHome = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".local", "share");
        var trash = Path.Combine(dataHome, "Trash");
        Directory.CreateDirectory(Path.Combine(trash, "files"));
        Directory.CreateDirectory(Path.Combine(trash, "info"));
        var baseName = Path.GetFileName(path);
        var name = baseName;
        for (int i = 2; File.Exists(Path.Combine(trash, "files", name)) || File.Exists(Path.Combine(trash, "info", name + ".trashinfo")); i++)
            name = $"{Path.GetFileNameWithoutExtension(baseName)} ({i}){Path.GetExtension(baseName)}";
        var encoded = string.Join("/", Path.GetFullPath(path).Split('/').Select(Uri.EscapeDataString));
        File.WriteAllText(Path.Combine(trash, "info", name + ".trashinfo"),
            $"[Trash Info]\nPath={encoded}\nDeletionDate={DateTime.Now:yyyy-MM-ddTHH:mm:ss}\n");
        File.Move(path, Path.Combine(trash, "files", name));
    }
}
