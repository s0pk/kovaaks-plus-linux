namespace KovaaksPlus.Platform;

/// <summary>Taps a key as if typed (the game reads real key events). X11 XTEST first — it reaches XWayland windows too — then ydotool.</summary>
public static class KeyInjector
{
    public static bool Tap(X11? x, KeyMap.Key key)
    {
        if (x != null)
        {
            var kc = x.KeycodeFor(key.Keysym, key.Code);
            if (x.FakeKey(kc, true))
            {
                Thread.Sleep(35);
                x.FakeKey(kc, false);
                return true;
            }
        }
        if (Cli.Exists("ydotool"))
            return Cli.Run("ydotool", new[] { "key", $"{key.Code}:1", $"{key.Code}:0" }).exit == 0;
        return false;
    }
}
