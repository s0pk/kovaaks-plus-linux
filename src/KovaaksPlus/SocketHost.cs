using System.Net.WebSockets;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Channels;

namespace KovaaksPlus;

/// <summary>
/// A host whose UI is a separate process (a browser window or the native Qt UI) that talks to us over the loopback
/// WebSocket served by <see cref="UiServer"/>. Only a client holding this run's secret token can connect.
/// </summary>
public abstract class SocketHost : HostBase
{
    protected readonly string Token = Convert.ToHexString(RandomNumberGenerator.GetBytes(24)).ToLowerInvariant();
    Channel<string>? _out;

    protected SocketHost() => Server = new UiServer(() => CrosshairDir) { Token = Token, OnSocket = HandleSocket };

    /// <summary>Messages the host consumes itself instead of passing to the API (for example dialog answers). Return true if handled.</summary>
    protected virtual bool HandleControlMessage(string raw) => false;

    async Task HandleSocket(WebSocket ws)
    {
        var outbox = Channel.CreateUnbounded<string>();
        _out = outbox;
        Created = true;
        var writer = Task.Run(async () =>
        {
            try
            {
                await foreach (var m in outbox.Reader.ReadAllAsync())
                    await ws.SendAsync(Encoding.UTF8.GetBytes(m), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch { /* socket closed */ }
        });

        var buf = new byte[64 * 1024];
        var sb = new StringBuilder();
        try
        {
            while (ws.State == WebSocketState.Open)
            {
                var r = await ws.ReceiveAsync(buf, CancellationToken.None);
                if (r.MessageType == WebSocketMessageType.Close) break;
                sb.Append(Encoding.UTF8.GetString(buf, 0, r.Count));
                if (r.EndOfMessage)
                {
                    var msg = sb.ToString();
                    sb.Clear();
                    if (!HandleControlMessage(msg)) Receive(msg);
                }
            }
        }
        catch { /* client gone */ }
        finally
        {
            outbox.Writer.TryComplete();
            if (ReferenceEquals(_out, outbox)) { Created = false; _out = null; }
            await writer;
        }
    }

    protected override void SendRaw(string json) => _out?.Writer.TryWrite(json);
}
