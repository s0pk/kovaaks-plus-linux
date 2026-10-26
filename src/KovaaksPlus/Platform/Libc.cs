using System.Runtime.InteropServices;

namespace KovaaksPlus.Platform;

internal static unsafe class Libc
{
    public const int O_RDONLY = 0, O_NONBLOCK = 0x800, O_CLOEXEC = 0x80000;
    public const short POLLIN = 1;
    const int _SC_CLK_TCK = 2;

    [StructLayout(LayoutKind.Sequential)]
    public struct PollFd { public int fd; public short events; public short revents; }

    [DllImport("libc", SetLastError = true)] public static extern int open([MarshalAs(UnmanagedType.LPStr)] string path, int flags);
    [DllImport("libc", SetLastError = true)] public static extern int close(int fd);
    [DllImport("libc", SetLastError = true)] public static extern nint read(int fd, void* buf, nint count);
    [DllImport("libc", SetLastError = true)] public static extern int poll(PollFd* fds, ulong nfds, int timeoutMs);
    [DllImport("libc", SetLastError = true)] public static extern int kill(int pid, int sig);
    [DllImport("libc")] static extern long sysconf(int name);

    public static long ClockTicks => sysconf(_SC_CLK_TCK) is > 0 and var t ? t : 100;
}

/// <summary>Reads /proc: finding the game process and when it started.</summary>
public static class Procs
{
    public static IEnumerable<int> AllPids()
    {
        foreach (var dir in Directory.EnumerateDirectories("/proc"))
            if (int.TryParse(Path.GetFileName(dir), out var pid)) yield return pid;
    }

    public static string? Comm(int pid)
    {
        try { return File.ReadAllText($"/proc/{pid}/comm").TrimEnd('\n'); } catch { return null; }
    }

    public static string? CmdLine(int pid)
    {
        try { return File.ReadAllText($"/proc/{pid}/cmdline").Replace('\0', ' ').TrimEnd(); } catch { return null; }
    }

    /// <summary>The process itself plus every process started below it.</summary>
    public static List<int> Tree(int root)
    {
        var parent = new Dictionary<int, int>();
        foreach (var pid in AllPids())
        {
            try
            {
                var stat = File.ReadAllText($"/proc/{pid}/stat");
                parent[pid] = int.Parse(stat[(stat.LastIndexOf(')') + 2)..].Split(' ')[1]);   // field 4: ppid
            }
            catch { }
        }
        var result = new List<int> { root };
        for (int i = 0; i < result.Count; i++)
            foreach (var kv in parent) if (kv.Value == result[i] && !result.Contains(kv.Key)) result.Add(kv.Key);
        return result;
    }

    public static bool Exists(int pid) => pid > 0 && Directory.Exists($"/proc/{pid}");

    /// <summary>The process that runs the game: Wine names its threads after the .exe, truncated to 15 chars.</summary>
    public static int FindByExe(string exeStem)
    {
        var comm15 = exeStem.Length > 15 ? exeStem[..15] : exeStem;
        foreach (var pid in AllPids())
        {
            var comm = Comm(pid);
            if (comm == null || !comm.StartsWith(comm15, StringComparison.OrdinalIgnoreCase)) continue;
            var cmd = CmdLine(pid);
            if (cmd != null && cmd.Contains(exeStem, StringComparison.OrdinalIgnoreCase)) return pid;
        }
        return 0;
    }

    public static DateTime StartTimeUtc(int pid)
    {
        try
        {
            // Field 22 of /proc/<pid>/stat (clock ticks since boot); the command name in field 2 may contain spaces.
            var stat = File.ReadAllText($"/proc/{pid}/stat");
            var rest = stat[(stat.LastIndexOf(')') + 2)..].Split(' ');
            var ticks = long.Parse(rest[19]);
            long btime = 0;
            foreach (var line in File.ReadLines("/proc/stat"))
                if (line.StartsWith("btime ")) { btime = long.Parse(line.AsSpan(6)); break; }
            return DateTimeOffset.FromUnixTimeSeconds(btime).UtcDateTime.AddSeconds((double)ticks / Libc.ClockTicks);
        }
        catch { return DateTime.MinValue; }
    }
}
