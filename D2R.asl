// =====================================================================
//  Diablo II: Resurrected autosplitter for LiveSplit
//  Built for D2R 3.4.95032. Offline single player only.
//
//  Memory access is read-only, but use it OFFLINE only. Blizzard has
//  banned memory-reading tools in online play. See README.md.
//
//  The script locates the game's unit hash table at runtime (code
//  signature, with a data-section scan as fallback). It does not use
//  fixed addresses, so small patches should not break it.
//  The struct offsets below were confirmed on a live 3.4.95032 game
//  (unit table signature, area chain, stats, difficulty, loading
//  pointer), and boss splits were tested in the full game.
//  If something breaks after a patch, these are the numbers to check.
// =====================================================================

state("D2R") {}
state("D2RLoader") {}

startup
{
    refreshRate = 30;

    // ---------------------------------------------------------------
    //  Memory layout
    // ---------------------------------------------------------------
    // This instruction indexes the client unit hash table; the 32-bit
    // value right after the matched bytes is the table's RVA.
    vars.UnitTableSig  = "48 03 C7 49 8B 8C C6";
    vars.UnitTableDisp = 7;

    var off = new Dictionary<string, int>();
    off["Unit.Type"]       = 0x00;  // 0 player, 1 monster, 2 object, 3 missile, 4 item, 5 tile
    off["Unit.TxtFileNo"]  = 0x04;  // class / monster id
    off["Unit.Id"]         = 0x08;  // hash bucket = id & 127
    off["Unit.Mode"]       = 0x0C;
    off["Unit.Act"]        = 0x20;
    off["Unit.Path"]       = 0x38;
    off["Unit.Stats"]      = 0x88;
    off["Unit.Next"]       = 0x150; // 0x150 and 0x158 are both followed (sources disagree)
    off["Path.Room1"]      = 0x20;
    off["Room1.Room2"]     = 0x18;
    off["Room2.Level"]     = 0x90;
    off["Level.No"]        = 0x1F8;
    off["Act.Misc"]        = 0x70;  // 3.4.95032 (older tools used 0x78); +/- 8 tried as fallback
    off["Misc.Difficulty"] = 0x830;
    off["Misc.Act"]        = 0x858; // back pointer to Act, used to validate
    off["Stats.Array"]     = 0x30;
    off["Stats.Count"]     = 0x38;
    vars.Off = off;

    // Loading screens: this byte is 1 while a loading screen is up (joining a game, act
    // changes, save & exit) and 0 otherwise, including in menus. Found by probe runs on a
    // live game. (A pointer at +0x1E4EC70 also tracks loads but comes back ~0.5 s too early.)
    // It's a fixed address, so it must be re-found for each game version.
    var loadRva = new Dictionary<string, int>();
    loadRva["3.4.95032"] = 0x1EFC158;
    vars.LoadRvaByVersion = loadRva;

    const int TYPE_BLOCK = 0x400;   // 128 buckets * 8 bytes per unit type
    const int STAT_LEVEL = 12;
    const int STAT_EXP   = 13;
    const int PMODE_DEATH = 0, PMODE_DEAD = 17;   // player modes
    const int MMODE_DEATH = 0, MMODE_DEAD = 12;   // monster modes
    vars.MModeDeath = MMODE_DEATH;
    vars.MModeDead  = MMODE_DEAD;

    // ---------------------------------------------------------------
    //  Split events
    //  kind 0 = enter area <id>
    //  kind 1 = boss <id> (monster txtFileNo) seen alive, then dead, in area <area>
    //  kind 2 = all three Ancients seen alive, then dead (Arreat Summit)
    // ---------------------------------------------------------------
    var ev = new List<object[]>();
    Action<int, string, string, int, int, int, bool> E =
        (act, key, label, kind, id, area, def) => ev.Add(new object[] { act, key, label, kind, id, area, def });

    E(1, "den",         "Enter the Den of Evil",               0,   8,   0, false);
    E(1, "bloodraven",  "Kill Blood Raven",                    1, 267,  17, false);
    E(1, "tristram",    "Enter Tristram",                      0,  38,   0, false);
    E(1, "tower",       "Enter the Forgotten Tower",           0,  20,   0, false);
    E(1, "monastery",   "Enter the Monastery Gate",            0,  26,   0, false);
    E(1, "jail",        "Enter Jail Level 1",                  0,  29,   0, false);
    E(1, "catacombs",   "Enter Catacombs Level 1",             0,  34,   0, false);
    E(1, "cata4",       "Enter Catacombs Level 4",             0,  37,   0, false);
    E(1, "andariel",    "Kill Andariel",                       1, 156,  37, true);

    E(2, "lut",         "Arrive in Lut Gholein",               0,  40,   0, true);
    E(2, "radament",    "Kill Radament",                       1, 229,  49, false);
    E(2, "halls",       "Enter Halls of the Dead Level 3",     0,  60,   0, false);
    E(2, "viper",       "Enter Claw Viper Temple Level 2",     0,  61,   0, false);
    E(2, "maggot",      "Enter Maggot Lair Level 3",           0,  64,   0, false);
    E(2, "arcane",      "Enter the Arcane Sanctuary",          0,  74,   0, false);
    E(2, "summoner",    "Kill the Summoner",                   1, 250,  74, false);
    E(2, "canyon",      "Enter the Canyon of the Magi",        0,  46,   0, false);
    E(2, "lair",        "Enter Duriel's Lair",                 0,  73,   0, false);
    E(2, "duriel",      "Kill Duriel",                         1, 211,  73, true);

    E(3, "docks",       "Arrive in Kurast Docks",              0,  75,   0, true);
    E(3, "travincal",   "Enter Travincal",                     0,  83,   0, false);
    E(3, "durance1",    "Enter Durance of Hate Level 1",       0, 100,   0, false);
    E(3, "durance3",    "Enter Durance of Hate Level 3",       0, 102,   0, false);
    E(3, "mephisto",    "Kill Mephisto",                       1, 242, 102, true);

    E(4, "pandemonium", "Arrive in the Pandemonium Fortress",  0, 103,   0, true);
    E(4, "izual",       "Kill Izual",                          1, 256, 105, false);
    E(4, "riverflame",  "Enter the River of Flame",            0, 107,   0, false);
    E(4, "chaos",       "Enter the Chaos Sanctuary",           0, 108,   0, false);
    E(4, "diablo",      "Kill Diablo",                         1, 243, 108, true);

    E(5, "harrogath",   "Arrive in Harrogath",                 0, 109,   0, true);
    E(5, "nihlathak",   "Kill Nihlathak",                      1, 526, 124, false);
    E(5, "summit",      "Enter the Arreat Summit",             0, 120,   0, false);
    E(5, "ancients",    "Defeat the Ancients",                 2,   0, 120, false);
    E(5, "wsk1",        "Enter Worldstone Keep Level 1",       0, 128,   0, false);
    E(5, "wsk2",        "Enter Worldstone Keep Level 2",       0, 129,   0, false);
    E(5, "wsk3",        "Enter Worldstone Keep Level 3",       0, 130,   0, false);
    E(5, "throne",      "Enter the Throne of Destruction",     0, 131,   0, false);
    E(5, "chamber",     "Enter the Worldstone Chamber",        0, 132,   0, false);
    E(5, "baal",        "Kill Baal",                           1, 544, 132, true);
    vars.Events = ev;
    vars.Ancients = new int[] { 540, 541, 542 };

    // ---------------------------------------------------------------
    //  Settings
    // ---------------------------------------------------------------
    settings.Add("start", true, "Start: a new level 1 character enters the game");
    settings.SetToolTip("start", "Starts when a character with 0 experience appears in the Rogue Encampment on Normal.");
    settings.Add("start_any", false, "Start: entering any game (practice)");
    settings.Add("reset", false, "Reset: a new level 1 character enters the game");
    settings.SetToolTip("reset", "Resets a running timer when you create and enter a fresh character, then starts again.");
    settings.Add("loads", true, "Load removal: pause game time during loading screens");
    settings.SetToolTip("loads", "Pauses Game Time while a loading screen is up: joining a game, act changes, save & exit.\nOnly works on game versions listed in the script (3.4.95032). Compare against Game Time to use it.");
    settings.Add("menus", false, "Also pause game time in menus (no character loaded)");
    settings.SetToolTip("menus", "Pauses Game Time at character select and other menus too. Leaderboards usually count menu time, so leave this off unless your category says otherwise.");

    string[] diffs = { "Normal", "Nightmare", "Hell" };
    string[] roman = { "", "I", "II", "III", "IV", "V" };
    settings.Add("splits", true, "Splits (each one fires once per run and difficulty)");
    for (int d = 0; d < 3; d++)
    {
        string dk = "d" + d;
        settings.Add(dk, d == 0, diffs[d], "splits");
        for (int a = 1; a <= 5; a++)
            settings.Add(dk + "_act" + a, true, "Act " + roman[a], dk);
        foreach (object[] e in ev)
            settings.Add(dk + "_" + (string)e[1], (bool)e[6], (string)e[2], dk + "_act" + (int)e[0]);
    }
    settings.Add("debug", false, "Debug log (view it with DebugView)");

    // ---------------------------------------------------------------
    //  Helpers
    // ---------------------------------------------------------------
    vars.Clock = Stopwatch.StartNew();
    vars.Log = (Action<string>)(msg => print("[D2R] " + msg));

    Func<long, bool> isPtr = v => v >= 0x10000 && v < 0x800000000000L && (v & 7) == 0;
    Func<Process, long, int, byte[]> rb = (p, a, n) =>
    {
        if (a < 0x10000 || n <= 0) return null;
        try { return p.ReadBytes(new IntPtr(a), n); } catch { return null; }
    };
    Func<Process, long, long> r64 = (p, a) => { var b = rb(p, a, 8); return b == null ? 0L : BitConverter.ToInt64(b, 0); };
    Func<Process, long, long> r32 = (p, a) => { var b = rb(p, a, 4); return b == null ? -1L : (long)BitConverter.ToUInt32(b, 0); };
    Func<Process, long, int>  r16 = (p, a) => { var b = rb(p, a, 2); return b == null ? -1 : (int)BitConverter.ToUInt16(b, 0); };
    vars.IsPtr = isPtr; vars.RB = rb; vars.R64 = r64; vars.R32 = r32;

    // Reads a large range in 1 MB chunks; unreadable chunks are retried per 4 KB page and left zeroed.
    Func<Process, long, int, byte[]> readRange = (p, start, size) =>
    {
        var all = new byte[size];
        const int CH = 0x100000;
        for (int pos = 0; pos < size; pos += CH)
        {
            int len = Math.Min(CH, size - pos);
            var b = rb(p, start + pos, len);
            if (b != null) { Buffer.BlockCopy(b, 0, all, pos, len); continue; }
            for (int pg = 0; pg < len; pg += 0x1000)
            {
                var q = rb(p, start + pos + pg, Math.Min(0x1000, len - pg));
                if (q != null) Buffer.BlockCopy(q, 0, all, pos + pg, q.Length);
            }
        }
        return all;
    };

    // Byte pattern search ("??" = wildcard, first byte must be fixed). Returns absolute addresses.
    Func<byte[], long, string, List<long>> findSig = (mem, baseAddr, sig) =>
    {
        string[] parts = sig.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        var pat = new int[parts.Length];
        for (int i = 0; i < parts.Length; i++) pat[i] = parts[i].StartsWith("?") ? -1 : Convert.ToInt32(parts[i], 16);
        var hits = new List<long>();
        int last = mem.Length - pat.Length;
        for (int i = 0; i <= last; i++)
        {
            if (mem[i] != pat[0]) continue;
            int j = 1;
            while (j < pat.Length && (pat[j] < 0 || mem[i + j] == pat[j])) j++;
            if (j == pat.Length) hits.Add(baseAddr + i);
        }
        return hits;
    };

    // Module info array: [base, textStart, textSize, dataStart, dataSize]
    Func<Process, long[], long> sigTable = (p, m) =>
    {
        if (m[2] <= 0) return 0;
        byte[] text = readRange(p, m[1], (int)m[2]);
        foreach (long hit in findSig(text, m[1], (string)vars.UnitTableSig))
        {
            int at = (int)(hit - m[1]) + (int)vars.UnitTableDisp;
            if (at + 4 > text.Length) continue;
            long table = m[0] + BitConverter.ToInt32(text, at);
            if (table >= m[3] && table + 6 * TYPE_BLOCK <= m[3] + m[4]) return table;
        }
        return 0;
    };

    // Fallback: find the table by its shape in the data section. Needs a loaded character.
    Func<Process, long[], long> heurTable = (p, m) =>
    {
        if (m[4] <= 0) return 0;
        byte[] data = readRange(p, m[3], (int)m[4]);
        int nq = data.Length / 8;
        var bad = new int[nq + 1];
        var nz  = new int[nq + 1];
        for (int q = 0; q < nq; q++)
        {
            long v = BitConverter.ToInt64(data, q * 8);
            bad[q + 1] = bad[q] + ((v != 0 && !isPtr(v)) ? 1 : 0);
            nz[q + 1]  = nz[q] + (v != 0 ? 1 : 0);
        }
        const int W = 5 * 128;   // player, monster, object, missile, item blocks
        for (int q = 0; q + W <= nq; q++)
        {
            if (bad[q + W] - bad[q] != 0) continue;
            int pc = nz[q + 128] - nz[q];
            if (pc < 1 || pc > 16) continue;
            if (nz[q + 256] - nz[q + 128] < 1) continue;   // monsters / NPCs
            if (nz[q + 640] - nz[q + 512] < 1) continue;   // items
            bool okP = false, okM = false;
            for (int b = 0; b < 128 && !(okP && okM); b++)
            {
                long u = BitConverter.ToInt64(data, (q + b) * 8);
                if (!okP && u != 0) { var h = rb(p, u, 0x10); if (h != null && BitConverter.ToUInt32(h, 0) == 0 && (BitConverter.ToUInt32(h, 8) & 127) == b) okP = true; }
                long mo = BitConverter.ToInt64(data, (q + 128 + b) * 8);
                if (!okM && mo != 0) { var h = rb(p, mo, 0x10); if (h != null && BitConverter.ToUInt32(h, 0) == 1 && (BitConverter.ToUInt32(h, 8) & 127) == b) okM = true; }
            }
            if (okP && okM) return m[3] + (long)q * 8;
        }
        return 0;
    };
    vars.SigTable = sigTable;
    vars.HeurTable = heurTable;

    // All units of one type. Each unit must match its bucket (id & 127), which
    // filters out wrong pointers when following both candidate "next" fields.
    Func<Process, long, int, List<long>> units = (p, table, type) =>
    {
        var found = new List<long>();
        byte[] heads = rb(p, table + type * TYPE_BLOCK, TYPE_BLOCK);
        if (heads == null) return found;
        var seen = new HashSet<long>();
        var stack = new Stack<long>();
        for (int b = 0; b < 128; b++)
        {
            long h = BitConverter.ToInt64(heads, b * 8);
            if (!isPtr(h)) continue;
            stack.Push(h);
            while (stack.Count > 0 && found.Count < 2048)
            {
                long u = stack.Pop();
                if (!isPtr(u)) continue;
                byte[] hd = rb(p, u, 0x10);
                if (hd == null || BitConverter.ToUInt32(hd, 0) != type || (BitConverter.ToUInt32(hd, 8) & 127) != b) continue;
                if (!seen.Add(u)) continue;
                found.Add(u);
                byte[] nx = rb(p, u + off["Unit.Next"], 0x10);
                if (nx != null) { stack.Push(BitConverter.ToInt64(nx, 0)); stack.Push(BitConverter.ToInt64(nx, 8)); }
            }
        }
        return found;
    };
    vars.Units = units;

    Func<Process, long, int> readArea = (p, u) =>
    {
        long path = r64(p, u + off["Unit.Path"]);     if (!isPtr(path)) return 0;
        long r1   = r64(p, path + off["Path.Room1"]);  if (!isPtr(r1))   return 0;
        long r2   = r64(p, r1 + off["Room1.Room2"]);   if (!isPtr(r2))   return 0;
        long lvl  = r64(p, r2 + off["Room2.Level"]);   if (!isPtr(lvl))  return 0;
        long no   = r32(p, lvl + off["Level.No"]);
        return (no > 0 && no < 256) ? (int)no : 0;
    };
    vars.ReadArea = readArea;

    // The local character. 3.4 keeps several player units even in single player, and corpses
    // are player units too, so prefer a living unit that is actually placed in an area.
    vars.FindPlayer = (Func<Process, long, long>)((p, table) =>
    {
        long alive = 0, any = 0;
        foreach (long u in units(p, table, 0))
        {
            if (any == 0) any = u;
            long mode = r32(p, u + off["Unit.Mode"]);
            if (mode == PMODE_DEATH || mode == PMODE_DEAD) continue;
            if (readArea(p, u) > 0) return u;
            if (alive == 0) alive = u;
        }
        return alive != 0 ? alive : any;
    });

    // 0 Normal, 1 Nightmare, 2 Hell, -1 unknown
    vars.ReadDiff = (Func<Process, long, int>)((p, u) =>
    {
        long act = r64(p, u + off["Unit.Act"]);
        if (!isPtr(act)) return -1;
        int[] cands = { off["Act.Misc"], off["Act.Misc"] - 8, off["Act.Misc"] + 8 };
        foreach (int c in cands)
        {
            long misc = r64(p, act + c);
            if (!isPtr(misc) || r64(p, misc + off["Misc.Act"]) != act) continue;
            int d = r16(p, misc + off["Misc.Difficulty"]);
            if (d >= 0 && d <= 2) return d;
        }
        return -1;
    });

    // { character level, experience }; level is 0 when the stat list can't be read.
    // Stats with value 0 are not stored, so a missing experience stat means 0.
    vars.ReadStats = (Func<Process, long, long[]>)((p, u) =>
    {
        var res = new long[] { 0, 0 };
        long sl = r64(p, u + off["Unit.Stats"]);            if (!isPtr(sl)) return res;
        long arr = r64(p, sl + off["Stats.Array"]);
        int cnt = r16(p, sl + off["Stats.Count"]);
        if (!isPtr(arr) || cnt <= 0 || cnt > 512) return res;
        byte[] b = rb(p, arr, cnt * 8);                     if (b == null) return res;
        for (int i = 0; i < cnt; i++)
        {
            int code = BitConverter.ToUInt16(b, i * 8 + 2);
            long val = BitConverter.ToUInt32(b, i * 8 + 4);
            if (code == STAT_LEVEL) res[0] = val;
            else if (code == STAT_EXP) res[1] = val;
        }
        if (res[0] < 1 || res[0] > 99) res[0] = 0;
        return res;
    });

    // ---------------------------------------------------------------
    //  Per-run state
    // ---------------------------------------------------------------
    vars.Done    = new HashSet<string>();
    vars.Pending = new Queue<string>();
    vars.Boss    = new Dictionary<string, int>();   // 1 = seen alive, 2 = died after being seen alive
    vars.ResetRun = (Action)(() => { vars.Done.Clear(); vars.Pending.Clear(); vars.Boss.Clear(); });
    vars.OnStart = (EventHandler)((s, e) => vars.ResetRun());
    timer.OnStart += vars.OnStart;
}

shutdown
{
    timer.OnStart -= vars.OnStart;
}

init
{
    vars.Table = 0L;
    vars.TableFrom = "";
    vars.NextSigScan = 0L;
    vars.NextHeurScan = 0L;
    vars.InGame = false;    vars.OldInGame = false;
    vars.Area = 0;          vars.OldArea = 0;
    vars.RawArea = 0;
    vars.Diff = -1;
    vars.Level = 0L;        vars.Exp = 0L;
    vars.Player = 0L;
    vars.EnteredAt = 0L;    vars.EntryPending = false;
    vars.FreshAt = -100000L; vars.GuessAt = -100000L; vars.JoinAt = -100000L;
    vars.Tick = 0;
    vars.WarnedStats = false; vars.WarnedArea = false;

    var mod = modules.FirstOrDefault(x => x.ModuleName.Equals("D2R.exe", StringComparison.OrdinalIgnoreCase)) ?? modules.First();
    long b = (long)mod.BaseAddress;
    byte[] hdr = game.ReadBytes(mod.BaseAddress, 0x1000);
    if (hdr == null) throw new Exception("D2R: module header not readable yet");

    long[] m = { b, 0, 0, 0, 0 };
    int pe = BitConverter.ToInt32(hdr, 0x3C);
    int nsec = BitConverter.ToUInt16(hdr, pe + 6);
    int sec = pe + 24 + BitConverter.ToUInt16(hdr, pe + 20);
    for (int i = 0; i < nsec && sec + i * 40 + 40 <= hdr.Length; i++)
    {
        int s = sec + i * 40;
        string name = Encoding.ASCII.GetString(hdr, s, 8).TrimEnd('\0');
        int vsize = BitConverter.ToInt32(hdr, s + 8), va = BitConverter.ToInt32(hdr, s + 12);
        if (name == ".text") { m[1] = b + va; m[2] = vsize; }
        if (name == ".data") { m[3] = b + va; m[4] = vsize; }
    }
    if (m[2] == 0 || m[4] == 0)
    {
        // Unknown layout: scan the whole module for both.
        m[1] = b; m[2] = mod.ModuleMemorySize; m[3] = b; m[4] = mod.ModuleMemorySize;
    }
    vars.Mod = m;

    try { version = FileVersionInfo.GetVersionInfo(mod.FileName).FileVersion; } catch { version = ""; }
    vars.Log("Attached to " + game.ProcessName + " " + version + " (module " + mod.ModuleName + " at 0x" + b.ToString("X") + ")");

    int lr;
    vars.LoadAddr = ((Dictionary<string, int>)vars.LoadRvaByVersion).TryGetValue(version ?? "", out lr) ? b + lr : 0L;
    vars.Loading = false;
    if (vars.LoadAddr == 0)
        vars.Log("Load removal is not available for game version " + version + " (splits still work). The loading-screen address needs to be found again for this version.");
}

update
{
    long now = vars.Clock.ElapsedMilliseconds;
    bool dbg = settings["debug"];
    long[] m = vars.Mod;
    long table = vars.Table;
    Func<Process, long, int, byte[]> rb = vars.RB;

    // ---- loading screen (flag byte 1 = loading; unreadable or any other value = not loading)
    bool loading = false;
    long loadAddr = vars.LoadAddr;
    if (loadAddr != 0)
    {
        byte[] lb = rb(game, loadAddr, 1);
        loading = lb != null && lb[0] == 1;
    }
    if (dbg && loading != vars.Loading) vars.Log(loading ? "Loading screen" : "Loading done");
    vars.Loading = loading;

    // ---- locate the unit hash table ----
    if (table == 0 && now >= vars.NextSigScan)
    {
        // The code is encrypted on disk and decrypted while the game starts, so retry for a while.
        vars.NextSigScan = now + 3000;
        Func<Process, long[], long> sigTable = vars.SigTable;
        table = sigTable(game, m);
        if (table != 0) { vars.Table = table; vars.TableFrom = "signature"; vars.Log("Unit table at D2R.exe+0x" + (table - m[0]).ToString("X") + " (signature)"); }
    }

    Func<Process, long, long> findPlayer = vars.FindPlayer;
    long player = table != 0 ? findPlayer(game, table) : 0;

    if (player == 0 && now >= vars.NextHeurScan)
    {
        // No character visible: either we're in a menu, or the table address is wrong. A shape
        // scan of the data section only succeeds while a character is loaded, so it is cheap to try.
        vars.NextHeurScan = now + (table == 0 ? 1000 : 5000);
        Func<Process, long[], long> heurTable = vars.HeurTable;
        long t = heurTable(game, m);
        if (t != 0 && t != table)
        {
            vars.Log("Unit table at D2R.exe+0x" + (t - m[0]).ToString("X") + " (data scan" + (table != 0 ? ", replaces signature result" : "") + ")");
            vars.Table = table = t; vars.TableFrom = "scan";
            player = findPlayer(game, table);
        }
    }

    // ---- read the character ----
    int raw = 0, diff = -1;
    long[] stats = { 0, 0 };
    if (player != 0)
    {
        Func<Process, long, int> readArea = vars.ReadArea;
        raw = readArea(game, player);
        if (raw != 0)
        {
            Func<Process, long, int> readDiff = vars.ReadDiff;
            Func<Process, long, long[]> readStats = vars.ReadStats;
            diff = readDiff(game, player);
            stats = readStats(game, player);
        }
        else if (!vars.WarnedArea)
        {
            vars.WarnedArea = true;
            vars.Log("Character found but its area can't be read: the Path/Room/Level offsets may have changed.");
        }
    }

    // Area must read the same twice in a row; this ignores torn reads while the map changes.
    int area = vars.Area;
    if (raw == vars.RawArea) area = raw;
    vars.RawArea = raw;

    vars.OldInGame = vars.InGame;
    vars.OldArea = vars.Area;
    vars.InGame = area != 0;
    vars.Area = area;
    vars.Player = player;
    if (vars.InGame) { vars.Diff = diff; vars.Level = stats[0]; vars.Exp = stats[1]; }

    // ---- game entry: fresh character? ----
    if (vars.InGame && !vars.OldInGame)
    {
        vars.EnteredAt = now; vars.EntryPending = true; vars.JoinAt = now;
        if (dbg) vars.Log("Entered game: area " + area + ", difficulty " + diff + ", level " + stats[0] + ", exp " + stats[1]);
    }
    if (!vars.InGame && vars.OldInGame && dbg) vars.Log("Left game");

    if (vars.EntryPending && vars.InGame)
    {
        if (stats[0] > 0)
        {
            vars.EntryPending = false;
            if (stats[0] == 1 && stats[1] == 0 && area == 1 && diff <= 0)
            {
                vars.FreshAt = now;
                if (dbg) vars.Log("Fresh level 1 character detected");
            }
        }
        else if (now - vars.EnteredAt > 3000)
        {
            vars.EntryPending = false;
            if (!vars.WarnedStats) { vars.WarnedStats = true; vars.Log("Character stats can't be read: the stat list offsets may have changed. Start falls back to 'entered Rogue Encampment on Normal'."); }
            if (area == 1 && diff <= 0) vars.GuessAt = now;
        }
    }

    if (dbg && vars.InGame && area != vars.OldArea && vars.OldInGame)
        vars.Log("Area " + vars.OldArea + " -> " + area);

    // ---- split events (only while the timer runs) ----
    if (timer.CurrentPhase != TimerPhase.Running || !vars.InGame) return true;

    string dk = "d" + (diff < 0 ? 0 : diff);
    List<object[]> events = vars.Events;

    if (area != vars.OldArea)
    {
        foreach (object[] e in events)
        {
            if ((int)e[3] != 0 || (int)e[4] != area) continue;
            string k = dk + "_" + (string)e[1];
            if (vars.Done.Add(k)) vars.Pending.Enqueue(k);
        }
    }

    // Boss checks run at ~10 Hz and only in the boss's area for enabled, unfinished splits.
    vars.Tick++;
    if (vars.Tick % 3 != 0) return true;

    var bosses = new Dictionary<int, string>();   // txtFileNo -> state key prefix
    var bossEvents = new List<object[]>();
    foreach (object[] e in events)
    {
        int kind = (int)e[3];
        if (kind == 0 || (int)e[5] != area) continue;
        string k = dk + "_" + (string)e[1];
        if (!settings[k] || vars.Done.Contains(k)) continue;
        bossEvents.Add(e);
        if (kind == 1) bosses[(int)e[4]] = k;
        else foreach (int a in vars.Ancients) bosses[a] = k + "_" + a;
    }
    if (bosses.Count == 0) return true;

    Func<Process, long, int, List<long>> units = vars.Units;
    Dictionary<string, int> boss = vars.Boss;
    foreach (long u in units(game, table, 1))
    {
        byte[] h = rb(game, u, 0x10);
        if (h == null) continue;
        int txt = (int)BitConverter.ToUInt32(h, 4);
        string sk;
        if (!bosses.TryGetValue(txt, out sk)) continue;
        int mode = (int)BitConverter.ToUInt32(h, 12);
        bool dead = mode == vars.MModeDeath || mode == vars.MModeDead;
        int st; boss.TryGetValue(sk, out st);
        if (!dead && st == 0) { boss[sk] = 1; if (dbg) vars.Log("Boss " + txt + " seen alive"); }
        else if (dead && st == 1) { boss[sk] = 2; if (dbg) vars.Log("Boss " + txt + " died"); }
    }

    foreach (object[] e in bossEvents)
    {
        string k = dk + "_" + (string)e[1];
        bool killed;
        if ((int)e[3] == 1) { int st; boss.TryGetValue(k, out st); killed = st == 2; }
        else
        {
            killed = true;
            foreach (int a in vars.Ancients) { int st; boss.TryGetValue(k + "_" + a, out st); if (st != 2) killed = false; }
        }
        if (killed && vars.Done.Add(k)) vars.Pending.Enqueue(k);
    }
    return true;
}

start
{
    long now = vars.Clock.ElapsedMilliseconds;
    bool go = false;
    if (settings["start"] && (now - vars.FreshAt < 2000 || now - vars.GuessAt < 2000)) go = true;
    if (settings["start_any"] && now - vars.JoinAt < 2000) go = true;
    if (go) { vars.FreshAt = -100000L; vars.GuessAt = -100000L; vars.JoinAt = -100000L; }
    return go;
}

reset
{
    // Only a confirmed fresh character (stats readable) resets, never the fallback guess.
    long now = vars.Clock.ElapsedMilliseconds;
    return settings["reset"] && now - vars.FreshAt < 2000;
}

split
{
    while (vars.Pending.Count > 0)
    {
        string k = vars.Pending.Dequeue();
        if (settings[k])
        {
            if (settings["debug"]) vars.Log("Split: " + k);
            return true;
        }
    }
    return false;
}

isLoading
{
    return (settings["loads"] && vars.Loading) || (settings["menus"] && !vars.InGame);
}

exit
{
    vars.InGame = false;
    vars.Loading = false;
    if (settings["menus"]) timer.IsGameTimePaused = true;
}
