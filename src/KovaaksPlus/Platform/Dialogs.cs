namespace KovaaksPlus.Platform;

/// <summary>File dialogs for hosts without a native toolkit window: kdialog on KDE, zenity elsewhere.</summary>
public static class Dialogs
{
    static string Home => Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

    static string? Run(string program, IEnumerable<string> args)
    {
        var (exit, output) = Cli.Run(program, args, timeoutMs: 15 * 60 * 1000);
        var line = output.Trim().Split('\n').FirstOrDefault()?.Trim();
        return exit == 0 && !string.IsNullOrEmpty(line) ? line : null;
    }

    static bool Kde => (Environment.GetEnvironmentVariable("XDG_CURRENT_DESKTOP") ?? "").Contains("KDE", StringComparison.OrdinalIgnoreCase);

    static string? Use(Func<string?> kdialog, Func<string?> zenity)
    {
        if (Kde && Cli.Exists("kdialog")) return kdialog();
        if (Cli.Exists("zenity")) return zenity();
        if (Cli.Exists("kdialog")) return kdialog();
        throw new InvalidOperationException("No file dialog available. Install kdialog or zenity.");
    }

    public static string? PickFolder(string title) => Use(
        () => Run("kdialog", new[] { "--title", title, "--getexistingdirectory", Home }),
        () => Run("zenity", new[] { "--file-selection", "--directory", "--title=" + title }));

    public static string? PickOpenFile(string title, (string Name, string[] Extensions)[] filters) => Use(
        () => Run("kdialog", new[] { "--title", title, "--getopenfilename", Home, KFilter(filters) }),
        () => Run("zenity", new[] { "--file-selection", "--title=" + title }.Concat(filters.Select(ZFilter))));

    public static string? PickSaveFile(string title, string defaultName, (string Name, string[] Extensions)[] filters) => Use(
        () => Run("kdialog", new[] { "--title", title, "--getsavefilename", Path.Combine(Home, defaultName), KFilter(filters) }),
        () => Run("zenity", new[] { "--file-selection", "--save", "--confirm-overwrite", "--title=" + title, "--filename=" + Path.Combine(Home, defaultName) }.Concat(filters.Select(ZFilter))));

    static string KFilter((string Name, string[] Extensions)[] f) =>
        string.Join("\n", f.Select(x => $"{string.Join(" ", x.Extensions.Select(e => "*." + e))}|{x.Name}"));

    static string ZFilter((string Name, string[] Extensions) f) =>
        $"--file-filter={f.Name} | {string.Join(" ", f.Extensions.Select(e => "*." + e))}";
}
