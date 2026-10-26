using System.Text.RegularExpressions;

namespace KovaaksPlus;

/// <summary>
/// Locates KovaaK's, its workshop content and the signed-in Steam account — so setup needs no manual steps.
/// KovaaK's is a Windows game, so on Linux it runs through Proton: the game files sit in the Steam library as usual,
/// but its per-user data (session.sav, Input.ini, logs) lives inside the game's Proton prefix.
/// </summary>
public class GamePaths
{
    public const string AppId = "824270";
    public const string ProcessName = "FPSAimTrainer-Win64-Shipping";

    /// <summary>The Proton prefix's AppData\Local\FPSAimTrainer of the active game install. Used by static helpers.</summary>
    public static string LocalData { get; private set; } = DefaultLocalData(null);

    public string GameRoot { get; }
    public string Content => Path.Combine(GameRoot, "FPSAimTrainer");
    public string Stats => Path.Combine(Content, "stats");
    public string SaveGames => Path.Combine(Content, "Saved", "SaveGames");
    public string Scenarios => Path.Combine(SaveGames, "Scenarios");
    public string Playlists => Path.Combine(SaveGames, "Playlists");
    public string Themes => Path.Combine(SaveGames, "Themes");
    public string Crosshairs => Path.Combine(Content, "crosshairs");
    public string PrimarySettings => Path.Combine(SaveGames, "PrimaryUserSettings.json");
    public string WeaponSettings => Path.Combine(SaveGames, "weaponsettings.ini");
    public string UiSettings => Path.Combine(SaveGames, "UI.json");
    /// <summary>Where this install keeps its per-user data (session.sav, logs, Input.ini): inside the Proton prefix.</summary>
    public string LocalDataDir { get; }
    public string LogFile => Path.Combine(LocalDataDir, "Saved", "Logs", "FPSAimTrainer.log");
    public void MakeCurrent() => LocalData = LocalDataDir;

    public List<string> Workshop { get; }

    public GamePaths(string gameRoot, IEnumerable<string> workshop)
    {
        GameRoot = gameRoot;
        Workshop = workshop.Where(Directory.Exists).ToList();
        LocalDataDir = DefaultLocalData(gameRoot);
    }

    public bool IsValid => Directory.Exists(Content);

    /// <summary>
    /// …/steamapps/common/FPSAimTrainer → …/steamapps/compatdata/824270/pfx/drive_c/users/steamuser/AppData/Local/FPSAimTrainer
    /// (Proton always names the Windows user "steamuser"). Falls back to a Wine prefix in the home folder.
    /// </summary>
    public static string DefaultLocalData(string? gameRoot)
    {
        if (gameRoot != null)
        {
            var common = Directory.GetParent(gameRoot.TrimEnd('/'));
            var steamapps = common?.Parent;
            if (steamapps != null && steamapps.Name.Equals("steamapps", StringComparison.OrdinalIgnoreCase))
            {
                var prefix = Path.Combine(steamapps.FullName, "compatdata", AppId, "pfx", "drive_c", "users");
                foreach (var user in new[] { "steamuser" }.Concat(Directory.Exists(prefix) ? Directory.GetDirectories(prefix).Select(d => Path.GetFileName(d)) : Array.Empty<string>()))
                {
                    var p = Path.Combine(prefix, user, "AppData", "Local", "FPSAimTrainer");
                    if (Directory.Exists(p)) return p;
                }
                return Path.Combine(prefix, "steamuser", "AppData", "Local", "FPSAimTrainer");
            }
        }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".wine", "drive_c", "users",
            Environment.UserName, "AppData", "Local", "FPSAimTrainer");
    }

    static string Home => Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

    /// <summary>Every Steam installation we can find: native, the ~/.steam symlinks, Flatpak and Snap.</summary>
    public static List<string> SteamRoots()
    {
        var xdg = Environment.GetEnvironmentVariable("XDG_DATA_HOME");
        var candidates = new List<string>();
        if (!string.IsNullOrEmpty(xdg)) candidates.Add(Path.Combine(xdg, "Steam"));
        candidates.AddRange(new[]
        {
            Path.Combine(Home, ".local", "share", "Steam"),
            Path.Combine(Home, ".steam", "steam"),
            Path.Combine(Home, ".steam", "root"),
            Path.Combine(Home, ".var", "app", "com.valvesoftware.Steam", ".local", "share", "Steam"),
            Path.Combine(Home, ".var", "app", "com.valvesoftware.Steam", ".steam", "steam"),
            Path.Combine(Home, "snap", "steam", "common", ".local", "share", "Steam"),
        });
        var roots = new List<string>();
        foreach (var c in candidates)
        {
            if (!Directory.Exists(Path.Combine(c, "steamapps"))) continue;
            var real = ResolveLinks(c);
            if (!roots.Contains(real)) roots.Add(real);
        }
        return roots;
    }

    static string ResolveLinks(string path)
    {
        try { return new DirectoryInfo(path).ResolveLinkTarget(true)?.FullName ?? Path.GetFullPath(path); }
        catch { return Path.GetFullPath(path); }
    }

    public static string? SteamRoot() => SteamRoots().FirstOrDefault();

    public static List<string> SteamLibraries()
    {
        var libs = new List<string>();
        foreach (var root in SteamRoots())
        {
            if (!libs.Contains(root)) libs.Add(root);
            var vdf = Path.Combine(root, "steamapps", "libraryfolders.vdf");
            if (!File.Exists(vdf)) continue;
            foreach (Match m in Regex.Matches(File.ReadAllText(vdf), "\"path\"\\s+\"([^\"]+)\""))
            {
                var path = m.Groups[1].Value.Replace(@"\\", @"\");
                if (Directory.Exists(path) && !libs.Contains(path)) libs.Add(ResolveLinks(path));
            }
        }
        return libs.Distinct().ToList();
    }

    public record Detection(string? GamePath, List<string> WorkshopPaths, string? SteamId, string? SteamName);

    public static Detection Detect()
    {
        string? game = null;
        var workshop = new List<string>();
        foreach (var lib in SteamLibraries())
        {
            var g = Path.Combine(lib, "steamapps", "common", "FPSAimTrainer");
            if (game == null && Directory.Exists(Path.Combine(g, "FPSAimTrainer"))) game = g;
            var w = Path.Combine(lib, "steamapps", "workshop", "content", AppId);
            if (Directory.Exists(w)) workshop.Add(w);
        }
        var (id, name) = DetectSteamUser();
        return new Detection(game, workshop, id, name);
    }

    /// <summary>Reads Steam's loginusers.vdf and returns the most recently signed-in account.</summary>
    public static (string? id, string? name) DetectSteamUser()
    {
        string? firstId = null, firstName = null;
        foreach (var root in SteamRoots())
        {
            var file = Path.Combine(root, "config", "loginusers.vdf");
            if (!File.Exists(file)) continue;
            var text = File.ReadAllText(file);
            foreach (Match m in Regex.Matches(text, "\"(7656\\d{13})\"\\s*\\{([^}]*)\\}"))
            {
                var id = m.Groups[1].Value;
                var body = m.Groups[2].Value;
                var name = Regex.Match(body, "\"PersonaName\"\\s+\"([^\"]*)\"").Groups[1].Value;
                firstId ??= id; firstName ??= name;
                if (Regex.IsMatch(body, "\"MostRecent\"\\s+\"1\"")) return (id, name);
            }
        }
        return (firstId, firstName);
    }
}
