namespace KovaaksPlus.Platform;

/// <summary>
/// Key names as the settings UI and KovaaK's use them (the Windows virtual-key names the original app stored, so
/// config.json files stay interchangeable) mapped to Linux evdev codes and X11 keysym names.
/// </summary>
public static class KeyMap
{
    public readonly record struct Key(string Name, int Code, string Keysym);

    static readonly Dictionary<string, Key> ByName = Build();

    static Dictionary<string, Key> Build()
    {
        var d = new Dictionary<string, Key>(StringComparer.OrdinalIgnoreCase);
        void Add(string name, int code, string? keysym = null) => d[name] = new Key(name, code, keysym ?? name);

        Add("Escape", 1);
        for (int i = 0; i < 10; i++) Add("D" + i, i == 0 ? 11 : 1 + i, i.ToString());
        Add("Back", 14, "BackSpace");
        Add("Tab", 15);
        const string row1 = "QWERTYUIOP", row2 = "ASDFGHJKL", row3 = "ZXCVBNM";
        for (int i = 0; i < row1.Length; i++) Add(row1[i].ToString(), 16 + i, char.ToLowerInvariant(row1[i]).ToString());
        for (int i = 0; i < row2.Length; i++) Add(row2[i].ToString(), 30 + i, char.ToLowerInvariant(row2[i]).ToString());
        for (int i = 0; i < row3.Length; i++) Add(row3[i].ToString(), 44 + i, char.ToLowerInvariant(row3[i]).ToString());
        Add("Return", 28);
        Add("Enter", 28, "Return");
        Add("Space", 57);
        Add("Oemtilde", 41, "grave");
        Add("LShiftKey", 42, "Shift_L");
        Add("RShiftKey", 54, "Shift_R");
        Add("LControlKey", 29, "Control_L");
        Add("LMenu", 56, "Alt_L");
        Add("Capital", 58, "Caps_Lock");
        Add("Add", 78, "KP_Add");
        Add("Subtract", 74, "KP_Subtract");
        Add("Multiply", 55, "KP_Multiply");
        Add("Divide", 98, "KP_Divide");
        Add("Up", 103); Add("Left", 105); Add("Right", 106); Add("Down", 108);
        Add("Home", 102); Add("End", 107); Add("Insert", 110); Add("Delete", 111);
        Add("PageUp", 104, "Prior"); Add("Next", 109); Add("PageDown", 109, "Next");
        for (int i = 1; i <= 10; i++) Add("F" + i, 58 + i);
        Add("F11", 87); Add("F12", 88);
        for (int i = 13; i <= 24; i++) Add("F" + i, 170 + i);
        return d;
    }

    public static bool TryGet(string? name, out Key key)
    {
        key = default;
        return !string.IsNullOrWhiteSpace(name) && ByName.TryGetValue(name.Trim(), out key);
    }

    /// <summary>KovaaK's (Unreal) key names from Input.ini → our key names.</summary>
    public static bool TryFromUnreal(string name, out Key key)
    {
        var unreal = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["SpaceBar"] = "Space", ["Enter"] = "Return", ["BackSpace"] = "Back", ["Tilde"] = "Oemtilde",
            ["Zero"] = "D0", ["One"] = "D1", ["Two"] = "D2", ["Three"] = "D3", ["Four"] = "D4",
            ["Five"] = "D5", ["Six"] = "D6", ["Seven"] = "D7", ["Eight"] = "D8", ["Nine"] = "D9",
            ["LeftShift"] = "LShiftKey", ["RightShift"] = "RShiftKey", ["LeftControl"] = "LControlKey", ["LeftAlt"] = "LMenu",
            ["CapsLock"] = "Capital", ["Escape"] = "Escape",
        };
        return TryGet(unreal.GetValueOrDefault(name, name), out key);
    }
}
