using System.Collections.Concurrent;

namespace KovaaksPlus;

/// <summary>
/// One dedicated thread that runs every RPC call and game event, in order — the role the WinForms UI thread played in
/// the original, so the API code never has to worry about two requests touching the same state at once.
/// </summary>
public sealed class RpcContext : SynchronizationContext
{
    readonly BlockingCollection<(SendOrPostCallback fn, object? state)> _queue = new();
    readonly Thread _thread;

    public RpcContext()
    {
        _thread = new Thread(Loop) { IsBackground = true, Name = "kplus-rpc" };
        _thread.Start();
    }

    public override void Post(SendOrPostCallback d, object? state)
    {
        try { _queue.Add((d, state)); } catch (InvalidOperationException) { /* shutting down */ }
    }

    public override void Send(SendOrPostCallback d, object? state)
    {
        if (Thread.CurrentThread == _thread) { d(state); return; }
        using var done = new ManualResetEventSlim();
        Exception? error = null;
        Post(_ => { try { d(state); } catch (Exception e) { error = e; } finally { done.Set(); } }, null);
        done.Wait();
        if (error != null) throw error;
    }

    public void Run(Action action) => Post(_ => action(), null);

    void Loop()
    {
        SetSynchronizationContext(this);
        foreach (var (fn, state) in _queue.GetConsumingEnumerable())
        {
            try { fn(state); }
            catch (Exception e) { Console.Error.WriteLine("[kplus] unhandled: " + e); }
        }
    }

    public void Shutdown() => _queue.CompleteAdding();
}
