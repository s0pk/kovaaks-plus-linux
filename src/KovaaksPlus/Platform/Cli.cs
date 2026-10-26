using System.Diagnostics;

namespace KovaaksPlus.Platform;

/// <summary>Runs small helper programs (xdg-open, busctl, hyprctl…) without a shell.</summary>
public static class Cli
{
    public static bool Exists(string program)
    {
        if (program.Contains('/')) return File.Exists(program);
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(':', StringSplitOptions.RemoveEmptyEntries))
            if (File.Exists(Path.Combine(dir, program))) return true;
        return false;
    }

    public static (int exit, string output) Run(string program, IEnumerable<string> args, int timeoutMs = 3000)
    {
        try
        {
            var psi = new ProcessStartInfo(program)
            {
                RedirectStandardOutput = true, RedirectStandardError = true, RedirectStandardInput = true,
                UseShellExecute = false, CreateNoWindow = true,
            };
            foreach (var a in args) psi.ArgumentList.Add(a);
            using var p = Process.Start(psi);
            if (p == null) return (-1, "");
            p.StandardInput.Close();
            var stdout = p.StandardOutput.ReadToEndAsync();
            p.StandardError.ReadToEndAsync();
            if (!p.WaitForExit(timeoutMs))
            {
                try { p.Kill(true); } catch { }
                return (-1, "");
            }
            return (p.ExitCode, stdout.GetAwaiter().GetResult());
        }
        catch { return (-1, ""); }
    }

    /// <summary>Starts a detached program and returns immediately (used for xdg-open and similar launchers).</summary>
    public static bool Spawn(string program, params string[] args)
    {
        try
        {
            var psi = new ProcessStartInfo(program) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true,
                RedirectStandardOutput = true, RedirectStandardError = true };
            foreach (var a in args) psi.ArgumentList.Add(a);
            var p = Process.Start(psi);
            if (p == null) return false;
            p.StandardInput.Close();
            p.OutputDataReceived += (_, _) => { };
            p.ErrorDataReceived += (_, _) => { };
            p.BeginOutputReadLine();
            p.BeginErrorReadLine();
            return true;
        }
        catch { return false; }
    }
}
