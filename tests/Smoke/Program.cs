// Smoke test for the RPC surface, run against a throw-away copy of the game's data (the real game folder is only read).
// Usage: dotnet run --project tests/Smoke [-- --network]
using System.Text.Json;
using System.Text.Json.Nodes;
using KovaaksPlus;

var tmp = Path.Combine(Path.GetTempPath(), "kplus-smoke-" + Guid.NewGuid().ToString("N")[..8]);
Directory.CreateDirectory(tmp);
Environment.SetEnvironmentVariable("KPLUS_DATA_DIR", Path.Combine(tmp, "data"));
Environment.SetEnvironmentVariable("XDG_DATA_HOME", Path.Combine(tmp, "xdg"));
AppPaths.Ensure();

var real = GamePaths.Detect();
if (real.GamePath == null) { Console.WriteLine("SKIP: no KovaaK's install found"); return 0; }

// Copy the parts of the install the API reads/writes into <tmp>/steamapps/common/FPSAimTrainer.
var fakeRoot = Path.Combine(tmp, "steamapps", "common", "FPSAimTrainer");
void Copy(string rel, bool recurse = true)
{
    var src = Path.Combine(real.GamePath, rel);
    var dst = Path.Combine(fakeRoot, rel);
    if (File.Exists(src)) { Directory.CreateDirectory(Path.GetDirectoryName(dst)!); File.Copy(src, dst, true); return; }
    if (!Directory.Exists(src)) return;
    foreach (var f in Directory.EnumerateFiles(src, "*", recurse ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly))
    {
        var to = Path.Combine(dst, Path.GetRelativePath(src, f));
        Directory.CreateDirectory(Path.GetDirectoryName(to)!);
        File.Copy(f, to, true);
    }
}
foreach (var r in new[] { "FPSAimTrainer/Saved/SaveGames", "FPSAimTrainer/stats", "FPSAimTrainer/crosshairs" }) Copy(r);

int failed = 0, passed = 0;
void Check(string name, bool ok, string detail = "")
{
    if (ok) passed++; else failed++;
    Console.WriteLine($"{(ok ? "PASS" : "FAIL")}  {name}{(detail.Length > 0 ? "  — " + detail : "")}");
}

var host = new FakeHost();
var api = new Api(host, a => a());
var jopt = Json.Options;

async Task<JsonNode?> Call(string method, object? p = null)
{
    var el = p == null ? default : JsonSerializer.SerializeToElement(p, jopt);
    var res = await api.Handle(method, el);
    return res == null ? null : JsonSerializer.SerializeToNode(res, jopt);
}

async Task Expect(string name, Func<Task<bool>> body)
{
    try { Check(name, await body()); }
    catch (Exception e) { Check(name, false, e.GetType().Name + ": " + e.Message); }
}

var network = args.Contains("--network");

await Call("app.saveConfig", new { setupComplete = true, gamePath = fakeRoot, workshopPaths = real.WorkshopPaths, steamId = real.SteamId });
await Expect("app.init is valid", async () => (await Call("app.init"))!["valid"]!.GetValue<bool>());
await Expect("validateGamePath", async () => (await Call("app.validateGamePath", new { path = fakeRoot }))!["valid"]!.GetValue<bool>());

JsonNode? lib = null;
await Expect("library.list", async () => { lib = await Call("library.list"); return lib!["scenarios"]!.AsArray().Count > 0; });
var name0 = lib?["scenarios"]?.AsArray().FirstOrDefault(s => s!["installed"]!.GetValue<bool>())?["name"]?.GetValue<string>();
Console.WriteLine($"      scenarios: {lib?["scenarios"]?.AsArray().Count}, using \"{name0}\"");

if (name0 != null)
{
    await Expect("library.detail", async () => (await Call("library.detail", new { name = name0 }))!["name"]!.GetValue<string>() == name0);
    await Expect("library.setMeta favorite+notes", async () =>
    {
        var d = await Call("library.setMeta", new { name = name0, favorite = true, notes = "smoke" });
        return d!["meta"]!["favorite"]!.GetValue<bool>();
    });
    await Expect("stats.overview", async () => (await Call("stats.overview")) != null);
    await Expect("stats.scenario", async () => (await Call("stats.scenario", new { name = name0 })) != null);
}

await Expect("settings.get", async () => (await Call("settings.get"))!["primary"] != null);

string? presetId = null;
await Expect("presets.capture", async () => { var r = await Call("presets.capture", new { name = "Smoke preset", categories = new[] { "sens", "crosshair" } }); presetId = r!["id"]!.GetValue<string>(); return presetId != null; });
await Expect("presets.list", async () => (await Call("presets.list"))!.AsArray().Count == 1);
await Expect("presets.save rename", async () => (await Call("presets.save", new { id = presetId, name = "Renamed" }))!["name"]!.GetValue<string>() == "Renamed");
await Expect("presets.apply (game not running)", async () => (await Call("presets.apply", new { id = presetId, restart = false }))!["applied"]!.GetValue<bool>());
await Expect("settings backups exist", async () => (await Call("settings.backups"))!.AsArray().Count >= 1);
await Expect("settings.apply patch", async () =>
{
    var before = File.ReadAllText(Path.Combine(fakeRoot, "FPSAimTrainer/Saved/SaveGames/PrimaryUserSettings.json"));
    var r = await Call("settings.apply", new { restart = false, primary = new { floatSettings = new Dictionary<string, double> { ["EFloatSettingId::XSens"] = 1.2345 } } });
    var after = File.ReadAllText(Path.Combine(fakeRoot, "FPSAimTrainer/Saved/SaveGames/PrimaryUserSettings.json"));
    return r!["applied"]!.GetValue<bool>() && after.Contains("1.2345") && JsonNode.Parse(after) != null;
});
await Expect("settings.restore", async () =>
{
    var id = (await Call("settings.backups"))!.AsArray().Last()!["id"]!.GetValue<string>();
    return (await Call("settings.restore", new { id, restart = false }))!["applied"]!.GetValue<bool>();
});

// Packs: export → preview → import (identical is skipped; after deleting the file it is installed again).
if (name0 != null)
{
    var kpack = Path.Combine(tmp, "test.kpack");
    await Expect("packs.export", async () => (await Call("packs.export", new { name = "Smoke", path = kpack, scenarios = new[] { name0 }, presets = new[] { presetId } }))!["scenarios"]!.GetValue<int>() == 1);
    await Expect("packs.pickImport (preview)", async () => (await Call("packs.pickImport", new { path = kpack }))!["scenarios"]!.AsArray().Count == 1);
    var sce = Directory.GetFiles(Path.Combine(fakeRoot, "FPSAimTrainer/Saved/SaveGames/Scenarios"), "*.sce").FirstOrDefault(f => Path.GetFileNameWithoutExtension(f) == name0);
    if (sce != null)
    {
        File.Delete(sce);
        await Call("library.rescan");
        await Expect("packs.import reinstalls deleted scenario", async () => (await Call("packs.import", new { path = kpack, scenarios = new[] { name0 }, presets = Array.Empty<string>(), overwrite = false }))!["installed"]!.GetValue<int>() == 1 && File.Exists(sce));
    }
}

// Media: save, scan for unused files, send to the trash.
string? media = null;
var png = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";
await Expect("media.saveDataUrl", async () => { media = (await Call("media.saveDataUrl", new { dataUrl = png, owner = "scenario:Test:Name", target = "thumbnail" }))!.GetValue<string>(); return File.Exists(Api.MediaFull(media)); });
await Expect("media.scanUnused finds it", async () => (await Call("media.scanUnused"))!["files"]!.AsArray().Any(f => f!["path"]!.GetValue<string>() == media));
await Expect("media.cleanUnused trashes it", async () =>
{
    var r = await Call("media.cleanUnused", new { files = new[] { media }, clearMissing = false });
    return r!["deleted"]!.GetValue<int>() == 1 && !File.Exists(Api.MediaFull(media!));
});
await Expect("MediaFull refuses traversal", async () => { try { Api.MediaFull("../config.json"); return false; } catch (InvalidOperationException) { return true; } });
await Expect("MediaFull refuses sibling-prefix", async () => { try { Api.MediaFull("../media-evil/x.png"); return false; } catch (InvalidOperationException) { return true; } });

if (network)
{
    // The catalog is fetched in the background on first use; wait for it like the UI does.
    async Task<JsonNode?> WaitCatalog()
    {
        for (int i = 0; i < 90; i++)
        {
            var c = await Call("evxl.catalog");
            if (c!["benchmarks"]!.AsArray().Count > 10) return c;
            await Task.Delay(1000);
        }
        return await Call("evxl.catalog");
    }
    await Expect("evxl.catalog", async () => (await WaitCatalog())!["benchmarks"]!.AsArray().Count > 10);
    await Expect("evxl.benchmark", async () =>
    {
        var cat = await WaitCatalog();
        var id = cat!["benchmarks"]!.AsArray()[0]!["id"]!.GetValue<int>();
        return (await Call("evxl.benchmark", new { id }))!["categories"] != null;
    });
    await Expect("lb.friends", async () => (await Call("lb.friends")) != null);
}

Console.WriteLine($"\n{passed} passed, {failed} failed  (temp: {tmp})");
try { api.Watcher.Dispose(); } catch { }
try { Directory.Delete(tmp, true); } catch { }
return failed == 0 ? 0 : 1;

sealed class FakeHost : IAppHost
{
    public void Emit(string evt, object? data) { }
    public void BringToFrontForced() { }
    public void SetZoom(double factor) { }
    public void OnGamePathsReady(GamePaths paths) { }
    public string? PickFolder(string title) => null;
    public string? PickOpenFile(string title, params (string Name, string[] Extensions)[] filters) => null;
    public string? PickSaveFile(string title, string defaultName, params (string Name, string[] Extensions)[] filters) => null;
}
