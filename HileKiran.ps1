# Calistirma: irm https://raw.githubusercontent.com/mero123bw123/Hile-Bulan/refs/heads/main/HileKiran.ps1 | iex
# (param() blogu iex ile calismadigi icin kullanilmaz; -Av bayragi $args ile, iex modunda ise soru ile secilir)
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$script:SelfUrl = 'https://raw.githubusercontent.com/mero123bw123/Hile-Bulan/refs/heads/main/HileKiran.ps1'
$Av = (@($args) -contains '-Av')
$hkModeSet = $Av
if (-not $hkModeSet -and $env:HK_AV -eq '1') { $Av = $true; $hkModeSet = $true }
if (-not $hkModeSet -and $env:HK_AV -eq '0') { $hkModeSet = $true }
if (-not $hkModeSet -and -not $PSCommandPath) {
    Write-Host ''
    Write-Host 'HileKiran - mod sec:' -ForegroundColor Cyan
    Write-Host '  [1] Normal tarama (iz/prefetch/kayit defteri/bellek + sonunda tum disk avi sorusu)' -ForegroundColor Gray
    Write-Host '  [2] Sadece HILE AVI (tum disk, sure siniri yok)' -ForegroundColor Gray
    $mAns = Read-Host 'Secim (1/2, bos birakirsan 1)'
    if ($mAns -match '^\s*2') { $Av = $true }
}
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $elevated = $false
    if ($PSCommandPath) {
        try {
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -NoExit -File "' + $PSCommandPath + '"' + $(if ($Av) { ' -Av' } else { '' }))
            $elevated = $true
        } catch {}
    } else {
        try {
            $flag = '0'
            if ($Av) { $flag = '1' }
            $ecmd = '$env:HK_AV=''' + $flag + '''; try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}; irm ''' + $script:SelfUrl + ''' | iex'
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -NoExit -Command "' + $ecmd + '"')
            $elevated = $true
        } catch {}
    }
    if ($elevated) { return }
    Write-Host 'HATA: Bu script YONETICI olarak calistirilmali. PowerShell i sag tik > Yonetici olarak calistir ile acip komutu tekrar yapistir.' -ForegroundColor Red
    if ($PSCommandPath) { Read-Host 'Kapatmak icin Enter a bas' | Out-Null }
    return
}
# Konsolda yanlislikla tiklayinca/secince scriptin DONMASINI onle (QuickEdit kapatilir) + islem onceligi
try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HkCon {
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    public static void NoQuickEdit() {
        IntPtr h = GetStdHandle(-10);
        uint m;
        if (GetConsoleMode(h, out m)) { m = (m & ~0x40u) | 0x80u; SetConsoleMode(h, m); }
    }
}
'@ -Language CSharp -ErrorAction Stop
    [HkCon]::NoQuickEdit()
} catch {}
try { [Diagnostics.Process]::GetCurrentProcess().PriorityClass = [Diagnostics.ProcessPriorityClass]::BelowNormal } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $Host.UI.RawUI.WindowTitle = 'HileKiran' } catch {}
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue

# =====================================================================
# HileKiran - bu bilgisayardaki hile izlerini arar. Hicbir dosya icerigi disari gonderilmez (mod hash sorgusu haric, bkz. asagi),
# hicbir dosya silinmez/degistirilmez. Sadece okur ve rapor yazar (process bellegi de sadece OKUNUR).
# Tek istisna: 10. adimda mod dosyalarinin SHA1 hash i Modrinth/Megabase te sorgulanir (icerik gonderilmez; kapatmak icin HK_NONET=1).
# =====================================================================

$script:Rep = New-Object System.Collections.Generic.List[string]
$script:F = New-Object System.Collections.Generic.List[object]
$script:Sys = New-Object System.Collections.Generic.List[object]
$script:UsnDel = @{}
$script:UsnRecent = New-Object System.Collections.Generic.List[object]
$script:DeletedPf = New-Object System.Collections.Generic.List[object]
$script:BinItems = New-Object System.Collections.Generic.List[object]
$script:BinEmptied = @{}
$script:BinState = New-Object System.Collections.Generic.List[string]
$script:UsbList = New-Object System.Collections.Generic.List[object]
$script:GameDirs = New-Object System.Collections.Generic.List[string]
$script:ScanRoots = New-Object System.Collections.Generic.List[string]
$script:LogCand = New-Object System.Collections.Generic.List[object]
$script:ProfileJsonCand = New-Object System.Collections.Generic.List[object]
$script:JsonCand2 = New-Object System.Collections.Generic.List[object]
$script:JavaInfo = New-Object System.Collections.Generic.List[string]
$script:fileCount = 0
$script:PfExecs = New-Object System.Collections.Generic.List[object]
$script:BamLeaves = @{}
$script:Bt = New-Object System.Collections.Generic.List[object]
$script:JarCand = New-Object System.Collections.Generic.List[object]
$script:Runs = New-Object System.Collections.Generic.List[object]
$script:ArcOther = New-Object System.Collections.Generic.List[string]
$script:BinCand = New-Object System.Collections.Generic.List[object]
$script:CfgCand = New-Object System.Collections.Generic.List[object]
$script:HkOk = $false
$Started = Get-Date
$UP = $env:USERPROFILE

function Log([string]$t, [string]$c = 'Gray', [bool]$fileOnly = $false) {
    Write-Host $t -ForegroundColor $c
    [void]$script:Rep.Add($t)
}
$script:StepTimes = New-Object System.Collections.Generic.List[object]
$script:StepName = ''
$script:StepT0 = Get-Date
# ---- Canli ilerleme: pencere basligi (gorev cubugunda da gorunur) her saniye guncellenir ----
$script:TitleOk = $false
$titleCs = @'
using System;
using System.Threading;
public static class HkTitle {
    public static int Idx = 0;
    public static int Total = 38;
    public static double Frac = 0;
    public static string Name = "";
    public static string Sub = "";
    public static bool Done = false;
    public static DateTime T0 = DateTime.Now;
    static Timer tm;
    public static void Start() {
        T0 = DateTime.Now;
        tm = new Timer(delegate(object o) { Tick(); }, null, 0, 1000);
    }
    public static void Tick() {
        try {
            if (Done) { Console.Title = "HileKiran - BITTI (%100)"; return; }
            double f = Frac; if (f < 0) f = 0; if (f > 1) f = 1;
            double p = ((Idx > 0 ? Idx - 1 : 0) + f) / Total * 100.0;
            if (p > 99) p = 99;
            TimeSpan e = DateTime.Now - T0;
            string nm = Name == null ? "" : Name;
            int b = nm.IndexOf(']');
            if (b > 0 && b < nm.Length - 1) nm = nm.Substring(b + 1).Trim();
            if (nm.Length > 45) nm = nm.Substring(0, 45);
            string sub = string.IsNullOrEmpty(Sub) ? "" : " | " + Sub;
            Console.Title = "HileKiran %" + ((int)p) + " | adim " + Idx + "/" + Total + " | " + ((int)e.TotalMinutes) + ":" + e.Seconds.ToString("00") + " gecti | " + nm + sub;
        } catch { }
    }
}
'@
try {
    Add-Type -TypeDefinition $titleCs -Language CSharp -ErrorAction Stop
    if ($Av) { [HkTitle]::Total = 5 }
    [HkTitle]::Start()
    $script:TitleOk = $true
} catch {}
# ---- Konsol ilerleme cubugu (Write-Progress): ust satirda adim ici %, altinda genel % ----
$script:BarLast = [DateTime]::MinValue
function Update-Bar([double]$frac, [string]$sub = '', [bool]$force = $false) {
    $ProgressPreference = 'Continue'
    if (-not $script:TitleOk) { return }
    $now = Get-Date
    if (-not $force -and ($now - $script:BarLast).TotalMilliseconds -lt 300) { return }
    $script:BarLast = $now
    if ($frac -lt 0) { $frac = 0 }
    if ($frac -gt 1) { $frac = 1 }
    $idx = [HkTitle]::Idx
    $tot = [HkTitle]::Total
    $all = [int]((([Math]::Max(0, $idx - 1)) + $frac) / $tot * 100)
    if ($all -gt 99) { $all = 99 }
    $stp = [int]($frac * 100)
    $nm = [string][HkTitle]::Name
    $b = $nm.IndexOf(']')
    if ($b -gt 0 -and $b -lt $nm.Length - 1) { $nm = $nm.Substring($b + 1).Trim() }
    if ($nm.Length -gt 60) { $nm = $nm.Substring(0, 60) }
    $st = '%' + $stp
    if ($sub) { $st = '[' + $sub + ']  %' + $stp }
    Write-Progress -Id 0 -Activity ('HileKiran genel ilerleme: %' + $all) -Status ('adim ' + $idx + '/' + $tot) -PercentComplete $all
    Write-Progress -Id 1 -ParentId 0 -Activity $nm -Status $st -PercentComplete $stp
}
function Close-Bar {
    $ProgressPreference = 'Continue'
    Write-Progress -Id 1 -Activity ' ' -Completed
    Write-Progress -Id 0 -Activity ' ' -Completed
}
function Set-Frac([double]$f, [string]$sub = '') {
    if ($script:TitleOk) { [HkTitle]::Frac = $f; if ($sub) { [HkTitle]::Sub = $sub }; Update-Bar $f $sub }
}
function Step([string]$t) {
    $now = Get-Date
    if ($script:StepName) {
        $secPrev = [int]($now - $script:StepT0).TotalSeconds
        [void]$script:StepTimes.Add([pscustomobject]@{ Ad = $script:StepName; Sn = $secPrev })
        Log ('   [onceki adim: ' + $secPrev + ' sn]') 'DarkGray'
    }
    $script:StepName = $t
    $script:StepT0 = $now
    $pct = 0
    if ($script:TitleOk) {
        [HkTitle]::Idx = [HkTitle]::Idx + 1
        [HkTitle]::Frac = 0
        [HkTitle]::Sub = ''
        [HkTitle]::Name = $t
        $pct = [int](([HkTitle]::Idx - 1) / [HkTitle]::Total * 100)
        if ($pct -gt 99) { $pct = 99 }
        Update-Bar 0 '' $true
    }
    Log '' 'Gray'
    Log ($t + '   [genel %' + $pct + ']') 'Cyan'
}
function Fmt($d) {
    if ($d) { try { return ([datetime]$d).ToString('dd.MM.yyyy HH:mm:ss') } catch { return [string]$d } }
    return '-'
}
function Ft([long]$v) {
    if ($v -le 0) { return $null }
    try {
        $d = [datetime]::FromFileTime($v)
        if ($d.Year -lt 2000) { return $null }
        return $d
    } catch { return $null }
}

# ---------------- C# yardimcilari (registry zamani, sikistirma, pencere, surucu haritasi) ----------------
$cs = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
public static class HkNative {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    public static extern uint QueryDosDevice(string lpDeviceName, StringBuilder lpTargetPath, int ucchMax);
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    public static extern int RegQueryInfoKey(Microsoft.Win32.SafeHandles.SafeRegistryHandle hKey, StringBuilder lpClass, IntPtr lpcbClass, IntPtr lpReserved, IntPtr lpcSubKeys, IntPtr lpcbMaxSubKeyLen, IntPtr lpcbMaxClassLen, IntPtr lpcValues, IntPtr lpcbMaxValueNameLen, IntPtr lpcbMaxValueLen, IntPtr lpcbSecurityDescriptor, out long lpftLastWriteTime);
    [DllImport("ntdll.dll")] public static extern uint RtlGetCompressionWorkSpaceSize(ushort fmt, out uint ws, out uint fw);
    [DllImport("ntdll.dll")] public static extern uint RtlDecompressBufferEx(ushort fmt, byte[] ub, uint ubs, byte[] cb, uint cbs, out uint fin, byte[] ws);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct FIND_STREAM_DATA { public long StreamSize; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 296)] public string StreamName; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr FindFirstStreamW(string f, int lvl, out FIND_STREAM_DATA d, uint flags);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool FindNextStreamW(IntPtr h, out FIND_STREAM_DATA d);
    [DllImport("kernel32.dll")] static extern bool FindClose(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint acc, bool inh, int pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
    [StructLayout(LayoutKind.Sequential)] public struct MBI { public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; }
    [DllImport("kernel32.dll")] static extern IntPtr VirtualQueryEx(IntPtr h, IntPtr a, out MBI m, IntPtr len);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr p, uint acc, out IntPtr tok);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool LookupPrivilegeValue(string sys, string name, out long luid);
    [StructLayout(LayoutKind.Sequential, Pack = 1)] struct TokPriv { public int Count; public long Luid; public int Attr; }
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool AdjustTokenPrivileges(IntPtr tok, bool dis, ref TokPriv np, int len, IntPtr prev, IntPtr ret);

    // NTFS ADS (alternate data stream) listesi: "ad|boyut"
    public static List<string> Streams(string path) {
        List<string> res = new List<string>();
        FIND_STREAM_DATA d;
        IntPtr h = FindFirstStreamW(path, 0, out d, 0);
        if (h == new IntPtr(-1)) return res;
        do { res.Add(d.StreamName + "|" + d.StreamSize.ToString()); } while (FindNextStreamW(h, out d));
        FindClose(h);
        return res;
    }
    // Process bellegini okumak icin SeDebugPrivilege (sadece okuma)
    public static bool EnableDebug() {
        IntPtr tok;
        if (!OpenProcessToken(GetCurrentProcess(), 0x28, out tok)) return false;
        long luid;
        if (!LookupPrivilegeValue(null, "SeDebugPrivilege", out luid)) { CloseHandle(tok); return false; }
        TokPriv tp = new TokPriv();
        tp.Count = 1; tp.Luid = luid; tp.Attr = 2;
        bool ok = AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        CloseHandle(tok);
        return ok;
    }
    static bool PrintA(char c) { return c >= (char)0x20 && c < (char)0x7F; }
    static bool PrintU(char c) { return (c >= (char)0x20 && c < (char)0x7F) || (c >= (char)0xC0 && c <= (char)0x17F); }
    static void Harvest(string text, bool uni, Regex r, int minLen, Dictionary<string, bool> seen, List<string> res) {
        foreach (Match m in r.Matches(text)) {
            int a = m.Index;
            int lim = m.Index - 300; if (lim < 0) lim = 0;
            while (a > lim && (uni ? PrintU(text[a - 1]) : PrintA(text[a - 1]))) a--;
            int e = m.Index + m.Length;
            int lim2 = e + 200; if (lim2 > text.Length) lim2 = text.Length;
            while (e < lim2 && (uni ? PrintU(text[e]) : PrintA(text[e]))) e++;
            if (e - a < minLen) continue;
            string s = text.Substring(a, e - a);
            if (!seen.ContainsKey(s)) { seen[s] = true; res.Add(s); if (res.Count >= 150000) return; }
        }
    }
    // Bir process'in (Private/Mapped/Image) bellegindeki ASCII + UTF-16 stringleri tarar, rx ile eslesenleri dondurur. Sadece okur.
    static Dictionary<string, Regex> RxCache = new Dictionary<string, Regex>();
    public static List<string> MemStrings(int pid, string rx, int minLen, bool mapped, bool priv, bool image, long maxBytes) {
        IntPtr h = OpenProcess(0x0410, false, pid);
        if (h == IntPtr.Zero) h = OpenProcess(0x1010, false, pid);
        if (h == IntPtr.Zero) return null;
        List<string> res = new List<string>();
        Dictionary<string, bool> seen = new Dictionary<string, bool>();
        Regex r;
        lock (RxCache) { if (!RxCache.TryGetValue(rx, out r)) { r = new Regex(rx, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled); RxCache[rx] = r; } }
        Encoding lat = Encoding.GetEncoding(28591);
        byte[] buf = new byte[4 * 1024 * 1024];
        int mbiSize = Marshal.SizeOf(typeof(MBI));
        long addr = 0; long total = 0;
        while (total < maxBytes && res.Count < 150000) {
            MBI m;
            if (VirtualQueryEx(h, new IntPtr(addr), out m, new IntPtr(mbiSize)) == IntPtr.Zero) break;
            long size = m.RegionSize.ToInt64();
            long baseA = m.BaseAddress.ToInt64();
            if (size <= 0) break;
            bool ok = (m.State == 0x1000) && ((m.Protect & 0x101) == 0) && (m.Protect != 0);
            if (ok) {
                bool take = (m.Type == 0x20000 && priv) || (m.Type == 0x40000 && mapped) || (m.Type == 0x1000000 && image);
                if (take) {
                    long off = 0;
                    while (off < size && total < maxBytes) {
                        int cnt = (int)Math.Min((long)buf.Length, size - off);
                        IntPtr rd;
                        if (!ReadProcessMemory(h, new IntPtr(baseA + off), buf, new IntPtr(cnt), out rd)) break;
                        int n = rd.ToInt32();
                        if (n <= 0) break;
                        total += n;
                        Harvest(lat.GetString(buf, 0, n), false, r, minLen, seen, res);
                        if (n > 2) {
                            Harvest(Encoding.Unicode.GetString(buf, 0, n & ~1), true, r, minLen, seen, res);
                            Harvest(Encoding.Unicode.GetString(buf, 1, (n - 1) & ~1), true, r, minLen, seen, res);
                        }
                        if (off + n < size && n > 1024) off += n - 512; else off += n;
                    }
                }
            }
            addr = baseA + size;
            if (addr < 0) break;
        }
        CloseHandle(h);
        return res;
    }

    public static List<string> Overlays() {
        List<string> res = new List<string>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            if (!IsWindowVisible(h)) return true;
            int ex = GetWindowLong(h, -20);
            bool layered = (ex & 0x80000) != 0;
            bool transp = (ex & 0x20) != 0;
            bool top = (ex & 0x8) != 0;
            if (layered && transp && top) {
                uint pid = 0;
                GetWindowThreadProcessId(h, out pid);
                StringBuilder sb = new StringBuilder(256);
                GetWindowText(h, sb, 256);
                RECT r;
                GetWindowRect(h, out r);
                res.Add(pid.ToString() + "|" + sb.ToString() + "|" + (r.Right - r.Left).ToString() + "x" + (r.Bottom - r.Top).ToString());
            }
            return true;
        }, IntPtr.Zero);
        return res;
    }
    public static byte[] Xpress(byte[] comp, uint usize) {
        uint ws = 0; uint fw = 0;
        if (RtlGetCompressionWorkSpaceSize(4, out ws, out fw) != 0) return null;
        byte[] work = new byte[ws];
        byte[] outb = new byte[usize];
        uint fin = 0;
        uint st = RtlDecompressBufferEx(4, outb, usize, comp, (uint)comp.Length, out fin, work);
        if (st != 0) return null;
        return outb;
    }
    public static long KeyTime(Microsoft.Win32.SafeHandles.SafeRegistryHandle h) {
        long ft = 0;
        int r = RegQueryInfoKey(h, null, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, out ft);
        if (r != 0) return 0;
        return ft;
    }
}
'@
try {
    Add-Type -TypeDefinition $cs -Language CSharp -ErrorAction Stop
    $script:HkOk = $true
} catch { $script:HkOk = $false }

# ---------------- isim listeleri ----------------
$StrongNames = @(
    'wurst','aristois','meteor','mathax','doomsday','haruka','nursultan','dimosik','liquidbounce','minced','arbuz',
    'newcode','vanadium','catlean','nightware','wexside','mythra','oyvey','interia','iternia','inertia','catlavan',
    'zenora','vape','rusher','shoreline','slinky','augustus','boze','cutthrough','invmove','danqclient','baritone',
    'monoton','fdpclient','deadcode','radon','churka','koshka','litka','genclient','fluger','dettex','evaware',
    'moonproject','miraclous','nexgen','nightdlc','nextdlc','rogalik','ratka','spectra','shitpaste','wissend','amoral',
    'excellentomni','relake','deko','desteny','vredux','kimadlc','nixware','hachclient','neverlose','wiksi',
    'seasonreloadd','vegaline','voil','multiware','verist','foxclient','nurik','zovchik','hynix','zaharov','nuckerdlc',
    'nucker','komarudlc','komaru','waileent','astralisbeta','astralis','liorclient','mantance','lunoclient',
    'awesomeproject','zexis','wirent','hitdelay','hitsune','wingclient','aka_tweaks','potionrefill','visible-barriers',
    'jumpoverfences','attack_through_grass','pingbypass','astolfo','novoware','entrophy','zeroday','tenacity','hellion',
    'jigsaw','huzuni','7clicker','bape','cheatbreaker','goki','koid','cheatengine','extremeinjector','processhacker',
    'systeminformer','opautoclicker','gsautoclicker','tinytask','jitbit','phantomclient',
    'astralux','astraulex','nyrex','noxx','alycone','luminex','zoomies','rebron','vapev4','vapelite','glazedclient','kryptonclient',
    'thunderhack','astraware','exosware','dimasx','noxium','voidstrike','zyron','dqrkis','gooba','salarixi','horion','borion','krismilex','vxrgin','trashh','waterclient','releon'
)
$WeakNames = @(
    'collapse','expensive','excellent','delta','grim','venus','arcade','zenith','essence','adjust','centric','future',
    'phantom','nix','moon','ares','wild','grace','damage','opal','dream','grape','reach','velocity','aimbot','esp','fly',
    'explicit','exclusive','flux','rise','sigma','thunder','impact','rocket','virgin','prestige','exhibition','ethereal',
    'preacher','deluxe','sparta','winner','kami','raven','ventura','argon','vapor','krypton','celestial',
    'helsing','marlow','xenon','calcium','astral','radium','achilles','gypsy','osmium','zorin','vril','mist','silk','combo','fusion','aero','mace','helion','glazed'
)
function New-Rx([string[]]$names) {
    $sorted = $names | Sort-Object -Property { $_.Length } -Descending
    $alt = ($sorted | ForEach-Object { [regex]::Escape($_) }) -join '|'
    return New-Object System.Text.RegularExpressions.Regex ('(?i)(?<![a-z0-9])(' + $alt + ')(?![a-z0-9])')
}
$script:StrongRx = New-Rx $StrongNames
# '<isim> client' kalibi: sik kelimeler (water, star, system...) tek basina degil, sadece 'client/hack/ghost/dlc' ekiyle hile sayilir
$script:ClientRx = New-Object System.Text.RegularExpressions.Regex ('(?i)(?<![a-z0-9])(helsing|marlow|nyrex|noxx|xenon|calcium|astral|astralux|radium|helion|hellion|achilles|alycone|luminex|gypsy|osmium|zorin|zoomies|zenith|prestige|phantom|krypton|glazed|vril|rebron|catlean|3qi|4e|vape|doomsday|shoreline|vanadium)[ _\-\.]?(client|hack|hacked[ _\-]?client|ghost|dlc)(?![a-z0-9])|(?<![a-z0-9])(system|shell|water|star|rich|air|combo|mist|silk|mace|mio|bt|fusion|aero)[ _\-](client|hack|ghost|dlc)(?![a-z0-9])')
$script:CamelRx = New-Object System.Text.RegularExpressions.Regex ('(?<![A-Za-z])(System|Shell|Water|Star|Rich|Air|Combo|Mist|Silk|Mace|Fusion|Aero|Echo|Pulse|Fake|Nature|Clarity|Matcha|Venom|Saber|Expensive|Rockstar|Celestial|Sakura|Leet|Mochi|Phobia|Orchard|Rubidium|Lumine|Selene|Epitaph|Arsenic|Cataclysm|Boze|Krispy|Corz|Zeph|Myau|Voil|Xiu|Primordial|Francium)Client(?![A-Za-z0-9])')
$script:WeakRx = New-Rx $WeakNames
$script:SubRx = New-Object System.Text.RegularExpressions.Regex ('(?i)(kill[ _\-]?aura|trigger[ _\-]?bot|aim[ _\-]?assist|aim[ _\-]?bot|auto[ _\-]?clicker|cheat[ _\-]?engine|elytra[ _\-]?target|jump[ _\-]?reset|scaffoldwalk|nofall|freecam|xray|antikb|autototem|autoarmor|chestesp|hitboxexpand)')
$script:StrongRx = New-Object System.Text.RegularExpressions.Regex ($script:StrongRx.ToString(), [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:WeakRx = New-Object System.Text.RegularExpressions.Regex ($script:WeakRx.ToString(), [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:SubRx = New-Object System.Text.RegularExpressions.Regex ($script:SubRx.ToString(), [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:ClientRx = New-Object System.Text.RegularExpressions.Regex ($script:ClientRx.ToString(), [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:CamelRx = New-Object System.Text.RegularExpressions.Regex ($script:CamelRx.ToString(), [System.Text.RegularExpressions.RegexOptions]::Compiled)
# Cok kelimeli/ayracli isimler ve ekli isimler (arsenic-client, click-crystal-ghost, hwid-spoofer, echo-client, corz-clienttt ...)
$script:ExtraRx = New-Object System.Text.RegularExpressions.Regex ('(?<![a-z0-9])(?:liquid[ _\-\.]?bounce|click[ _\-\.]?crystal[ _\-\.]?(?:ghost|script)|hwid[ _\-\.]?spoofer|fate[ _\-\.]?injector|mei[ _\-\.]?laa|discord[ _\-\.]?orbs[ _\-\.]?farm|198[ _\-\.]?macros|cw[ _\-\.]?client[ _\-\.]?plus|zenith[ _\-\.]?macro|francium[ _\-\.]?reborn|argon[ _\-\.]?library|67[ _\-\.]?client|orchard[ _\-\.]?nitro|system[ _\-]1[ _\-]21(?:[ _\-]\d+)?|(?:arsenic|cataclysm|boze|krispy|corz|zeph|myau|voil|xiu|primordial|francium)[ _\-\.]?(?:clientt{0,3}|clients|hack|ghost|dlc|srcc?|macros?|injector|spoofer|proxy|reborn|remake|recode|nitro|plus)|(?:echo|pulse|fake|nature|clarity|matcha|venom|saber|expensive|rockstar|celestial|sakura|leet|mochi|phobia|rubidium|lumine|selene|epitaph)[ _\-](?:clientt{0,3}|clients|hack|ghost|dlc|srcc?|macros?|injector|proxy))(?![a-z0-9])', ([System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Compiled'))
$script:BenignRx = '(?i)^(setup|install|installer|update|updater|unins\d*|uninstall|vc_?redist|vcredist|dxwebsetup|dotnet|windowsupdate|msedge|chrome|googleupdate|onedrive|teams|zoom|discord|spotify|steam|epicgames|riot|valorant|battle|nvidia|amd|radeon|intel|driver|java|jre|jdk|python|node|git|code|vscode|7z|winrar|vlc|obs|notepad|firefox|opera|brave|whatsapp|telegram|skype|anydesk|teamviewer|malwarebytes|avast|kaspersky|tlauncher|lunar|badlion|modrinth|prism|curseforge|overwolf|minecraft)'
$script:LauncherRx = '(?i)minecraft|launcher|lunar|badlion|modrinth|prism|multimc|feather|curseforge|tlauncher|labymod|salwyrr|atlauncher|technic|ftb|overwolf|ichor|sklauncher'
$IntExt = @('.exe','.dll','.jar','.zip','.rar','.7z','.bat','.cmd','.ps1','.vbs','.scr','.msi','.com')
$DisguiseExt = @('.png','.jpg','.jpeg','.gif','.bmp','.txt','.dat','.bin','.log','.pdf','.mp3','.mp4','.wav','.ico','.db','.ttf','.cfg','.ini','.json','.xml','.lang','.mcmeta','.nbt')
$HeavyRx = '(?i)\\(node_modules|Cache|Code Cache|GPUCache|CacheStorage|Service Worker|IndexedDB|Local Storage|Session Storage|Crashpad|blob_storage|libraries|assets|runtime|\.git)(\\|$)'
$SigRx = '(?i)\\(Downloads|Desktop|Documents|Temp|Public)\\'

function Get-NameHit([string]$text, [bool]$weak = $true) {
    if ([string]::IsNullOrEmpty($text)) { return $null }
    $m = $script:SubRx.Match($text)
    if ($m.Success) { return [pscustomobject]@{ Name = $m.Groups[1].Value.ToLower(); Weak = $false } }
    $m = $script:StrongRx.Match($text)
    if ($m.Success) { return [pscustomobject]@{ Name = $m.Groups[1].Value.ToLower(); Weak = $false } }
    $m = $script:ClientRx.Match($text)
    if ($m.Success) { return [pscustomobject]@{ Name = ($m.Value.ToLower().Trim()); Weak = $false } }
    $m = $script:ExtraRx.Match($text)
    if ($m.Success) { return [pscustomobject]@{ Name = ($m.Value.ToLower().Trim()); Weak = $false } }
    $m = $script:CamelRx.Match($text)
    if ($m.Success) { return [pscustomobject]@{ Name = ($m.Value.ToLower().Trim()); Weak = $false } }
    if ($weak) {
        $m = $script:WeakRx.Match($text)
        if ($m.Success) { return [pscustomobject]@{ Name = $m.Groups[1].Value.ToLower(); Weak = $true } }
    }
    return $null
}
function Name-Score($hit, [bool]$leaf) {
    if (-not $hit) { return 0 }
    if (-not $hit.Weak) { if ($leaf) { return 60 } else { return 40 } }
    if ($leaf) { return 25 }
    return 0
}

# Klavyeye rastgele basilarak uretilmis gibi gorunen dosya adi mi? (ornek: asdhjsa, hasdih, xzvkqpw)
function Test-Gibberish([string]$base) {
    if ([string]::IsNullOrWhiteSpace($base)) { return $false }
    $b = $base.ToLower()
    if ($b -match '^[0-9a-f\-_\{\}\.]{8,}$') { return $false }
    $letters = ($b -replace '[^a-z\u00e7\u011f\u0131\u00f6\u015f\u00fc]', '')
    if ($letters.Length -lt 5) { return $false }
    if ($letters -match '(asd|sdf|dfg|fgh|ghj|hjk|jkl|qwe|zxc|xcv|cvb)') { return $true }
    $vow = ([regex]::Matches($letters, '[aeiou\u0131\u00f6\u00fc]')).Count
    $ratio = $vow / [double]$letters.Length
    if ($letters.Length -ge 6 -and $ratio -lt 0.15) { return $true }
    if ($letters.Length -ge 6 -and $ratio -lt 0.25 -and $letters -match '[^aeiou\u0131\u00f6\u00fc]{5,}') { return $true }
    return $false
}

# id83lls.exe gibi harf-rakam karisik rastgele isimler (hile dosyalari sik boyle adlandirilir)
function Test-MixedRandom([string]$base) {
    if ([string]::IsNullOrWhiteSpace($base)) { return $false }
    $b = $base.ToLower()
    if ($b -notmatch '^[a-z0-9]{6,14}$') { return $false }
    if ($b -match '^[0-9a-f]{8,}$') { return $false }
    if ($b -match '(x64|x86|win32|win64|mp3|mp4|utf8|sha\d|md5|h264|h265|k2|3d|v\d)') { return $false }
    if ($b -notmatch '[a-z]\d+[a-z]') { return $false }
    $letters = ($b -replace '[^a-z]', '')
    if ($letters.Length -lt 3) { return $false }
    $vow = ([regex]::Matches($letters, '[aeiou]')).Count
    return (($vow / [double]$letters.Length) -lt 0.34)
}

# ---------------- yardimci fonksiyonlar ----------------
$script:Drives = @()
foreach ($d in [IO.DriveInfo]::GetDrives()) { if ($d.IsReady) { $script:Drives += $d.Name.Substring(0, 2).ToUpper() } }
$script:VolMap = @{}
if ($script:HkOk) {
    foreach ($dl in $script:Drives) {
        $sb = New-Object System.Text.StringBuilder 512
        if ([HkNative]::QueryDosDevice($dl, $sb, 512) -gt 0) { $script:VolMap[$sb.ToString()] = $dl }
    }
}
$script:SerialMap = @{}
foreach ($ld in @(Get-CimInstance Win32_LogicalDisk)) {
    if ($ld.VolumeSerialNumber) { $script:SerialMap[$ld.VolumeSerialNumber.ToUpper()] = $ld.DeviceID.ToUpper() }
}
$script:FixedNtfs = @()
foreach ($d in [IO.DriveInfo]::GetDrives()) {
    if ($d.IsReady -and $d.DriveType -eq 'Fixed' -and $d.DriveFormat -eq 'NTFS') { $script:FixedNtfs += $d.Name.Substring(0, 2).ToUpper() }
}

function Get-Zone([string]$p) {
    if ($p -match '(?i)\\Users\\[^\\]+\\(Downloads|Desktop|Documents|Music|Videos|Pictures|OneDrive[^\\]*)\\') { return 'user' }
    if ($p -match '(?i)\\AppData\\Local\\Temp\\|\\Windows\\Temp\\|\\Temp\\') { return 'temp' }
    if ($p -match '(?i)\\AppData\\') { return 'appdata' }
    if ($p -match '(?i)\\Users\\Public\\|\\ProgramData\\') { return 'shared' }
    if ($p -match '(?i)^[A-Za-z]:\\Windows\\|\\Program Files( \(x86\))?\\|\\WindowsApps\\') { return 'system' }
    return 'other'
}
$script:SigCache = @{}
function Test-Signed([string]$p) {
    $k = $p.ToLower()
    if ($script:SigCache.ContainsKey($k)) { return $script:SigCache[$k] }
    $r = $false
    try {
        $sg = Get-AuthenticodeSignature -LiteralPath $p -ErrorAction Stop
        $r = ($sg.Status -eq 'Valid')
    } catch { $r = $false }
    $script:SigCache[$k] = $r
    return $r
}
$script:NameDeep = New-Object System.Collections.Generic.List[string]
$script:NameDeepSeen = @{}
function Add-NameDeep([string]$p) {
    if (-not $p -or $p -notmatch '^[A-Za-z]:\\') { return }
    $k = $p.ToLower()
    if ($script:NameDeepSeen.ContainsKey($k)) { return }
    if ($script:NameDeep.Count -ge 300) { return }
    $script:NameDeepSeen[$k] = 1
    [void]$script:NameDeep.Add($p)
}
function Get-ZoneInfo([string]$p) {
    try {
        $z = Get-Content -LiteralPath $p -Stream Zone.Identifier -ErrorAction Stop
        $h = $z | Where-Object { $_ -match '^HostUrl=' } | Select-Object -First 1
        $r = $z | Where-Object { $_ -match '^ReferrerUrl=' } | Select-Object -First 1
        $o = @()
        if ($h) { $o += ($h -replace '^HostUrl=', '') }
        if ($r) { $o += ('ref: ' + ($r -replace '^ReferrerUrl=', '')) }
        return ($o -join ' | ')
    } catch { return '' }
}
function Get-Magic([string]$p) {
    try {
        $fs = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite')
        $n = 0
        $buf = New-Object byte[] 4
        try { $n = $fs.Read($buf, 0, 4) } finally { $fs.Dispose() }
        if ($n -ge 2 -and $buf[0] -eq 0x4D -and $buf[1] -eq 0x5A) { return 'MZ' }
        if ($n -ge 4 -and $buf[0] -eq 0x50 -and $buf[1] -eq 0x4B -and $buf[2] -eq 3 -and $buf[3] -eq 4) { return 'PK' }
        if ($n -ge 2) { return 'OTHER' }
    } catch {}
    return ''
}
function Get-KeyTime($k) {
    if ($script:HkOk) { try { return (Ft ([HkNative]::KeyTime($k.Handle))) } catch {} }
    return $null
}
function Test-PathInfo([string]$p) {
    $r = @{ Exists = $false; Removed = $false }
    if ($p -match '^([A-Za-z]:)\\') {
        $dl = $Matches[1].ToUpper()
        if ($script:Drives -contains $dl) { $r.Exists = [bool](Test-Path -LiteralPath $p) } else { $r.Removed = $true }
    } elseif ($p -match '^\(') {
        $r.Removed = $true
    } else {
        $r.Exists = [bool](Test-Path -LiteralPath $p)
    }
    return $r
}
function Resolve-NtPath([string]$p) {
    $r = @{ Path = $p; Exists = $false; Removed = $false }
    if ($p -match '^(\\Device\\HarddiskVolume\d+)(\\.*)$') {
        $dev = $Matches[1]
        $rest = $Matches[2]
        if ($script:VolMap.ContainsKey($dev)) {
            $r.Path = $script:VolMap[$dev] + $rest
            $r.Exists = [bool](Test-Path -LiteralPath $r.Path)
        } else {
            $found = $false
            if (-not $script:HkOk) {
                foreach ($dl in $script:Drives) {
                    if (Test-Path -LiteralPath ($dl + $rest)) { $r.Path = $dl + $rest; $r.Exists = $true; $found = $true; break }
                }
            }
            if (-not $found -and -not $r.Exists) { $r.Path = '(cikarilmis/eski surucu)' + $rest; $r.Removed = $true }
        }
    } else {
        $pi = Test-PathInfo $p
        $r.Exists = $pi.Exists
        $r.Removed = $pi.Removed
    }
    return $r
}
function Resolve-PfPath([string]$p) {
    $r = @{ Path = $p; Exists = $false; Removed = $false }
    if ($p -match '^\\VOLUME\{[0-9a-fA-F]+-([0-9a-fA-F]{8})\}(\\.*)$') {
        $ser = $Matches[1].ToUpper()
        $rest = $Matches[2]
        if ($script:SerialMap.ContainsKey($ser)) {
            $r.Path = $script:SerialMap[$ser] + $rest
            $r.Exists = [bool](Test-Path -LiteralPath $r.Path)
        } else {
            $r.Path = '(cikarilmis/eski surucu)' + $rest
            $r.Removed = $true
        }
    }
    return $r
}
function Rot13([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $c = [int]$ch
        if ($c -ge 65 -and $c -le 90) { $c = ((($c - 65 + 13) % 26) + 65) } elseif ($c -ge 97 -and $c -le 122) { $c = ((($c - 97 + 13) % 26) + 97) }
        [void]$sb.Append([char]$c)
    }
    return $sb.ToString()
}
function Get-DownloadsPath {
    try {
        $v = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}'
        if ($v) { return [Environment]::ExpandEnvironmentVariables($v) }
    } catch {}
    return (Join-Path $env:USERPROFILE 'Downloads')
}

function Add-Sys([string]$Baslik, [int]$Skor, [string]$Aciklama, $Zaman = $null, [string]$Durum = '', $Degisim = $null) {
    [void]$script:Sys.Add([pscustomobject]@{ Baslik = $Baslik; Skor = $Skor; Aciklama = $Aciklama; Zaman = $Zaman; Durum = $Durum; Degisim = $Degisim })
}
# Bir servisin durumunu (baslatma modu + calisip calismadigi) ve kayit defteri anahtarinin
# en son ne zaman elle degistirildigini (Degisim) birlikte raporlar.
function Check-Service([string]$sv, [string]$aciklama, [int]$devreDisiSkor = 40, [int]$durdurulmusSkor = 30) {
    $s = Get-CimInstance Win32_Service -Filter ("Name='" + $sv + "'")
    if (-not $s) { return }
    $kt = $null
    try {
        $k = (Get-Item -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $sv))
        $kt = Get-KeyTime $k
    } catch {}
    $durum = $sv + ': baslatma=' + $s.StartMode + ', durum=' + $s.State
    if ($s.StartMode -eq 'Disabled') {
        Add-Sys ('Servis DEVRE DISI: ' + $sv) $devreDisiSkor $aciklama $null $durum $kt
    } elseif ($s.State -ne 'Running' -and $s.StartMode -eq 'Auto') {
        Add-Sys ('Servis durdurulmus: ' + $sv) $durdurulmusSkor $aciklama $null $durum $kt
    } elseif ($kt -and $kt -gt (Get-Date).AddDays(-14)) {
        Add-Sys ('Servis ayari yakin zamanda degistirilmis: ' + $sv) 15 ($aciklama + ' (ayar 14 gun icinde degismis, normal olabilir)') $null $durum $kt
    }
}
# Bir kayit defteri DWORD degerini okur; beklenen (guvenli) degerden farkliysa uyari ekler,
# anahtarin en son ne zaman elle degistirildigini de raporlar.
function Check-RegFlag([string]$path, [string]$name, $beklenen, [string]$baslik, [string]$aciklama, [int]$skor) {
    try {
        $item = Get-Item -LiteralPath $path -ErrorAction Stop
        $val = $item.GetValue($name)
        $kt = Get-KeyTime $item
        if ($null -eq $val) { return }
        if ($val -ne $beklenen) {
            Add-Sys $baslik $skor $aciklama $null ($name + '=' + $val + ' (beklenen: ' + $beklenen + ')') $kt
        } elseif ($kt -and $kt -gt (Get-Date).AddDays(-14)) {
            Add-Sys ($baslik + ' - ayar yakin zamanda degistirilmis') 12 ($aciklama + ' (deger guvenli ama anahtar 14 gun icinde degismis)') $null ($name + '=' + $val) $kt
        }
    } catch {}
}
function Add-F {
    param([string]$Kaynak, [string]$Ad, [string]$Yol, [int]$Skor, $Son = $null, $Ilk = $null, [string]$Var = 'Bilinmiyor', $Silinme = $null, [string]$Not = '', [bool]$Benign = $false)
    # Guvence: Windows'un kendi klasorlerindeki (System32/SysWOW64/WinSxS) gecerli imzali dosyalar hicbir modulde bulgu sayilmaz
    if ($Yol -match '^[A-Za-z]:\\' -and $Kaynak -notmatch 'Kernel surucusu|Servis/surucu|Defender|ADS') {
        $swd = [string]$env:SystemRoot
        if ($swd -and $Yol.StartsWith(($swd.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase) -and $Yol -match '(?i)\\(System32|SysWOW64|WinSxS|SystemApps|servicing)\\') {
            if (Test-Signed $Yol) { return }
        }
    }
    [void]$script:F.Add([pscustomobject]@{ Kaynak = $Kaynak; Ad = $Ad; Yol = $Yol; Skor = $Skor; Son = $Son; Ilk = $Ilk; Var = $Var; Silinme = $Silinme; Not = $Not; Benign = $Benign })
}

# Calistirilmis bir program kaydini (Prefetch/BAM/UserAssist/Amcache/Shimcache/Recent) degerlendirir
$script:ExecExtSet = @('.exe','.dll','.scr','.com','.msi')
$script:CodeExtSet = @('.exe','.dll','.scr','.com','.msi','.jar','.bat','.cmd','.ps1','.vbs')
function Eval-Exec {
    param([string]$Kaynak, [string]$Path, [bool]$Exists = $false, [bool]$Removed = $false, $Last = $null, $First = $null, [string]$Note = '', [switch]$NoLoc)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $leaf = $Path
    try { $leaf = Split-Path -Leaf $Path } catch {}
    if ([string]::IsNullOrWhiteSpace($leaf)) { return }
    if ($Last -and $Path -match '^[A-Za-z]:\\' -and $script:Runs.Count -lt 30000) { [void]$script:Runs.Add([pscustomobject]@{ Yol = $Path; Zaman = $Last; Kaynak = $Kaynak }) }
    $zone = 'other'
    if (-not $NoLoc) { $zone = Get-Zone $Path }
    $hit = Get-NameHit $leaf $true
    $extL = ''
    try { $extL = [IO.Path]::GetExtension($leaf).ToLower() } catch {}
    $isCode = ($script:CodeExtSet -contains $extL)
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    if ($hit) {
        $ns = Name-Score $hit $true
        if ($ns -gt 0) { $sc += $ns; [void]$why.Add('isim eslesmesi: ' + $hit.Name) }
    }
    # ONEMLI: isim eslesmesi YOKSA ve dosya calistirilabilir bir kod dosyasi (exe/dll/jar/bat/ps1 vs.) DEGILSE
    # (yani sadece bir arsiv/veri dosyasi ise: .zip/.rar/.7z/resource pack vb.) hicbir konum/imza puani verme.
    # Sirf "indirilenler klasorunde" veya "imzasiz" olmak (zip'lerin zaten imzasi olmaz) tek basina supheli degildir.
    if ($hit -and -not $hit.Weak -and $Exists) { Add-NameDeep $Path }
    if (-not $hit -and -not $isCode) { return }
    if ($isCode -and -not $NoLoc -and $zone -ne 'system') {
        $rbn = ''
        try { $rbn = [IO.Path]::GetFileNameWithoutExtension($leaf) } catch {}
        if ((Test-MixedRandom $rbn) -or (Test-Gibberish $rbn)) { $sc += 25; [void]$why.Add('rastgele/anlamsiz karakterli dosya adi') }
    }
    if (-not $NoLoc) {
        if ($zone -eq 'system' -and $sc -eq 0) { return }
        if ($Removed) {
            $sc += 30
            [void]$why.Add('cikarilmis/eski surucuden calistirilmis')
        } elseif ($zone -eq 'user' -or $zone -eq 'temp') {
            if (-not $Exists) {
                $sc += 30
                [void]$why.Add('kullanici/temp klasorunden calistirilmis, su an SILINMIS')
            } else {
                $sc += 12
                [void]$why.Add('kullanici/temp klasorunden calistirilmis')
                if (($script:ExecExtSet -contains $extL) -and -not (Test-Signed $Path)) { $sc += 20; [void]$why.Add('imzasiz calistirilabilir dosya') }
            }
        } elseif ($zone -eq 'shared') {
            if (-not $Exists) { $sc += 20; [void]$why.Add('ortak klasorden calistirilmis, SILINMIS') } elseif (($script:ExecExtSet -contains $extL) -and -not (Test-Signed $Path)) { $sc += 15; [void]$why.Add('ortak klasorde imzasiz program') }
        } elseif ($zone -eq 'appdata') {
            if (-not $Exists) { $sc += 12; [void]$why.Add('AppData programi, su an yok') }
        } elseif ($zone -eq 'other') {
            if (-not $Exists) { $sc += 12; [void]$why.Add('calistirilmis, su an bulunamiyor') }
        }
    }
    $benign = $false
    if (($leaf -match $script:BenignRx) -and $sc -lt 40) { $benign = $true; $sc -= 15 }
    if ($sc -lt 10) { return }
    $var = 'Bilinmiyor'
    if (-not $NoLoc) { if ($Exists) { $var = 'Evet' } else { $var = 'Hayir' } }
    $nt = ($why -join '; ')
    if ($Note) { $nt = $nt + ' | ' + $Note }
    if ($Exists -and $sc -ge 20) {
        $zi = Get-ZoneInfo $Path
        if ($zi) { $nt = $nt + ' | indirildigi adres: ' + $zi }
    }
    Add-F -Kaynak $Kaynak -Ad $leaf.ToLower() -Yol $Path -Skor ([Math]::Min(100, $sc)) -Son $Last -Ilk $First -Var $var -Not $nt -Benign $benign
}

function Inspect-Jar([string]$p) {
    $r = @{ Hit = $null; Agent = $false; AgentClass = '' }
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($p)
        try {
            foreach ($e in $zip.Entries) {
                $n = $e.FullName
                if (-not $r.Hit -and $n.EndsWith('.class')) {
                    $h = Get-NameHit $n $false
                    if ($h) { $r.Hit = $h.Name }
                }
                if ($n -eq 'META-INF/MANIFEST.MF') {
                    $sr = New-Object IO.StreamReader($e.Open())
                    $txt = $sr.ReadToEnd()
                    $sr.Dispose()
                    if ($txt -match '(?im)^(Premain-Class|Agent-Class|Launcher-Agent-Class):\s*(\S+)') { $r.Agent = $true; $r.AgentClass = $Matches[2] }
                }
            }
        } finally { $zip.Dispose() }
    } catch {}
    return $r
}

function Inspect-File($f) {
    $script:fileCount++
    if (($script:fileCount % 3000) -eq 0) { Write-Host -NoNewline '.' -ForegroundColor DarkGray }
    if (($script:fileCount % 500) -eq 0 -and $script:TitleOk) { [HkTitle]::Sub = ($script:fileCount.ToString() + ' dosya'); if ([HkTitle]::Frac -lt 0.9) { [HkTitle]::Frac = [Math]::Min(0.9, $script:fileCount / 200000.0) }; Update-Bar ([HkTitle]::Frac) ($script:fileCount.ToString() + ' dosya') }
    $name = $f.Name
    $ext = $f.Extension.ToLower()
    $path = $f.FullName
    if (($ext -eq '.jar' -or ($ext -eq '.zip' -and $path -match $SigRx)) -and $f.Length -lt 104857600 -and $path -notmatch $HeavyRx -and $script:JarCand.Count -lt 1500) { [void]$script:JarCand.Add($f) }
    if (($ext -eq '.rar' -or $ext -eq '.7z') -and $f.Length -lt 4294967296 -and $script:ArcOther.Count -lt 800) { [void]$script:ArcOther.Add($path) }
    if (($ext -eq '.exe' -or $ext -eq '.dll') -and $f.Length -gt 4096 -and $f.Length -lt 41943040 -and $path -notmatch $HeavyRx -and $script:BinCand.Count -lt 800) { [void]$script:BinCand.Add($f) }
    if (@('.json', '.cfg', '.toml', '.txt', '.properties', '.yml', '.yaml', '.ini', '.conf') -contains $ext -and $f.Length -gt 100 -and $f.Length -lt 3145728 -and $path -match '(?i)\\(\.minecraft|AppData\\Roaming|AppData\\Local|Documents|Downloads|Desktop)\\' -and $path -notmatch $HeavyRx -and $path -notmatch '(?i)\\(logs|crash-reports)\\' -and $name -notlike 'launcher_profiles*' -and $script:CfgCand.Count -lt 4000) { [void]$script:CfgCand.Add($f) }
    $isInt = ($IntExt -contains $ext)
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]

    if (($ext -eq '.log' -or $ext -eq '.gz' -or $ext -eq '.txt') -and ($path -match '(?i)\\(logs|crash-reports)\\') -and ($path -match $script:LauncherRx)) {
        [void]$script:LogCand.Add($f)
    }
    if ($name -like 'launcher_profiles*.json') { [void]$script:ProfileJsonCand.Add($f) }
    if ($ext -eq '.json' -and $f.Length -lt 3145728 -and ($path -match '(?i)\\\.minecraft\\versions\\|feather')) { [void]$script:JsonCand2.Add($f) }
    if ($isInt -or $ext -eq '') {
        $hit = Get-NameHit $name $true
        if ($hit) {
            if (-not $hit.Weak) { Add-NameDeep $path }
            $ns = Name-Score $hit $true
            if ($ns -gt 0) { $sc += $ns; [void]$why.Add('dosya adi: ' + $hit.Name) }
        }
    }
    if ($name -match '(?i)\.(png|jpe?g|gif|txt|pdf|docx?|xlsx?|mp3|mp4|zip|rar|lnk)\.(exe|scr|bat|cmd|jar|com|vbs|ps1|dll)$') {
        $sc += 55; [void]$why.Add('cift uzanti (gizlenmis calistirilabilir dosya)')
    }
    if ($name.IndexOf([char]0x202E) -ge 0) { $sc += 60; [void]$why.Add('RTLO (ters yazdirma) uzanti hilesi') }
    if ((@('.exe', '.jar', '.dll', '.bat', '.ps1', '.scr') -contains $ext) -and ($path -match '(?i)\\Users\\[^\\]+\\(Downloads|Desktop|Documents)\\') -and (Test-Gibberish ([IO.Path]::GetFileNameWithoutExtension($name)))) {
        $sc += 30; [void]$why.Add('rastgele/anlamsiz karakterli dosya adi')
    }

    $heavy = ($path -notmatch $HeavyRx)
    $magic = ''
    $disg = ($DisguiseExt -contains $ext)
    # .tmp: Temp/installer/updater artiklari normalde MZ/PK icerir, bu yuzden sadece mod/surum klasorlerinde supheli say
    if ($ext -eq '.tmp' -and ($path -match '(?i)\\\.minecraft\\(mods|versions)\\')) { $disg = $true }
    if ($f.Length -ge 4 -and $heavy) {
        if (($disg -and $f.Length -ge 20480) -or ($ext -eq '' -and $f.Length -ge 20480) -or $ext -eq '.jar' -or $ext -eq '.exe' -or $ext -eq '.dll') { $magic = Get-Magic $path }
    }
    if ($magic -eq 'MZ' -and ($disg -or $ext -eq '')) {
        $extTxt = $ext
        if (-not $extTxt) { $extTxt = '(uzantisiz)' }
        $sc += 60; [void]$why.Add('uzanti ' + $extTxt + ' ama icerik EXE/DLL (MZ) - uzanti degistirilmis/silinmis')
    } elseif ($magic -eq 'PK' -and $disg) {
        $sc += 45; [void]$why.Add('uzanti ' + $ext + ' ama icerik ZIP/JAR (PK) - uzanti degistirilmis')
    } elseif ($magic -eq 'OTHER' -and $ext -eq '.jar') {
        $sc += 35; [void]$why.Add('.jar uzantili ama gercek jar/zip degil (sifreli/bozuk olabilir)')
    } elseif ($magic -eq 'OTHER' -and ($ext -eq '.exe' -or $ext -eq '.dll')) {
        $sc += 40; [void]$why.Add($ext + ' uzantili ama gercek program degil')
    }
    if ($magic -eq 'PK' -and $disg -and $f.Length -lt 104857600 -and $script:JarCand.Count -lt 1500) { [void]$script:JarCand.Add($f) }
    if ($magic -eq 'MZ' -and ($disg -or $ext -eq '') -and $f.Length -lt 41943040 -and $script:BinCand.Count -lt 800) { [void]$script:BinCand.Add($f) }
    if ($heavy -and ($ext -eq '.jar' -or ($magic -eq 'PK' -and $disg)) -and $f.Length -lt 157286400) {
        $jr = Inspect-Jar $path
        if ($jr.Hit) { $sc += 40; [void]$why.Add('jar ICINDE hile modulu/istemci ismi: ' + $jr.Hit) }
        if ($jr.Agent) { $sc += 30; [void]$why.Add('jar bir Java agent (' + $jr.AgentClass + ') - oyuna kod enjekte edebilir') }
    }
    if ($script:HkOk -and $heavy) {
        $adsList = $null
        try { $adsList = [HkNative]::Streams($path) } catch {}
        foreach ($stx in @($adsList)) {
            if (-not $stx) { continue }
            $sp = ([string]$stx).Split('|')
            $sn = $sp[0]
            if ($sn -eq '::$DATA') { continue }
            $nm = ($sn -replace '^:', '') -replace ':\$DATA$', ''
            if ($nm -match '^(Zone\.Identifier|Win32App_\d+|SmartScreen|encryptable|com\.dropbox\.attrs|com\.dropbox\.attributes|AFP_AfpInfo|OECustomProperty)$') { continue }
            $ssz = [long]0
            [void][long]::TryParse($sp[1], [ref]$ssz)
            $adsSc = 30
            $adsWhy = 'gizli veri akisi (ADS): ' + $nm + ' (' + $ssz + ' bayt)'
            if ($ssz -ge 1024) { $adsSc = 45 }
            if ($nm -match '(?i)\.(exe|dll|jar|bat|ps1|cmd|vbs)$') { $adsSc = [Math]::Max($adsSc, 60); $adsWhy += ' - kod uzantili' }
            if ($ssz -ge 2) {
                try {
                    $hb = @(Get-Content -LiteralPath $path -Stream $nm -Encoding Byte -TotalCount 2 -ErrorAction Stop)
                    if ($hb.Count -ge 2 -and $hb[0] -eq 0x4D -and $hb[1] -eq 0x5A) { $adsSc = 80; $adsWhy += ' - icerik EXE/DLL (MZ)' }
                } catch {}
            }
            Add-F -Kaynak 'ADS (gizli veri akisi)' -Ad ($name.ToLower() + ':' + $nm.ToLower()) -Yol ($path + ':' + $nm) -Skor $adsSc -Son $f.LastWriteTime -Ilk $f.CreationTime -Var 'Evet' -Not $adsWhy
        }
    }
    if ($ext -eq '.exe' -and ($path -match $SigRx)) {
        if (-not (Test-Signed $path)) { $sc += 20; [void]$why.Add('imzasiz exe') }
    }
    if ($sc -ge 10) {
        $nt = ($why -join '; ')
        if ($isInt) {
            $zi = Get-ZoneInfo $path
            if ($zi) { $nt = $nt + ' | indirildigi adres: ' + $zi }
        }
        Add-F -Kaynak 'Dosya taramasi' -Ad $name.ToLower() -Yol $path -Skor ([Math]::Min(100, $sc)) -Son $f.LastWriteTime -Ilk $f.CreationTime -Var 'Evet' -Not $nt
    }
}

function Read-Prefetch([string]$file) {
    $res = @{ Runs = @(); Paths = @(); Exe = '' }
    try {
        $raw = [IO.File]::ReadAllBytes($file)
        $data = $raw
        if ($raw.Length -gt 8 -and $raw[0] -eq 0x4D -and $raw[1] -eq 0x41 -and $raw[2] -eq 0x4D) {
            if (-not $script:HkOk) { return $res }
            $usize = [BitConverter]::ToUInt32($raw, 4)
            $comp = New-Object byte[] ($raw.Length - 8)
            [Array]::Copy($raw, 8, $comp, 0, $comp.Length)
            $data = [HkNative]::Xpress($comp, $usize)
        }
        if ($null -eq $data -or $data.Length -lt 200) { return $res }
        if ([Text.Encoding]::ASCII.GetString($data, 4, 4) -ne 'SCCA') { return $res }
        $ver = [BitConverter]::ToUInt32($data, 0)
        $res.Exe = [Text.Encoding]::Unicode.GetString($data, 16, 60).Split([char]0)[0]
        $runs = @()
        if ($ver -ge 26) {
            for ($i = 0; $i -lt 8; $i++) {
                $t = Ft ([BitConverter]::ToInt64($data, 128 + 8 * $i))
                if ($t) { $runs += $t }
            }
        } elseif ($ver -eq 23) {
            $t = Ft ([BitConverter]::ToInt64($data, 128))
            if ($t) { $runs += $t }
        } elseif ($ver -eq 17) {
            $t = Ft ([BitConverter]::ToInt64($data, 120))
            if ($t) { $runs += $t }
        }
        $res.Runs = $runs
        $so = [BitConverter]::ToUInt32($data, 100)
        $sl = [BitConverter]::ToUInt32($data, 104)
        if ($so -gt 0 -and $sl -gt 0 -and ($so + $sl) -le $data.Length) {
            $s = [Text.Encoding]::Unicode.GetString($data, $so, $sl)
            $res.Paths = @($s.Split([char]0) | Where-Object { $_ })
        }
    } catch {}
    return $res
}

function Read-LogText([string]$p) {
    try {
        if ($p -like '*.gz') {
            $fs = [IO.File]::OpenRead($p)
            $gz = New-Object IO.Compression.GZipStream($fs, [IO.Compression.CompressionMode]::Decompress)
            $sr = New-Object IO.StreamReader($gz)
            $t = $sr.ReadToEnd()
            $sr.Dispose(); $gz.Dispose(); $fs.Dispose()
            return $t
        }
        $fs2 = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite')
        $sr2 = New-Object IO.StreamReader($fs2)
        $t2 = $sr2.ReadToEnd()
        $sr2.Dispose(); $fs2.Dispose()
        return $t2
    } catch { return '' }
}

function Get-UsnTime([string]$ln) {
    $m = [regex]::Match($ln, '(\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4})[ T,]+(\d{1,2}:\d{2}:\d{2}(?:\s?[AaPp][Mm])?)')
    if (-not $m.Success) { return $null }
    $s = $m.Groups[1].Value + ' ' + $m.Groups[2].Value
    $d = [datetime]::MinValue
    if ([datetime]::TryParse($s, [Globalization.CultureInfo]::CurrentCulture, [Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
    if ([datetime]::TryParse($s, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
    return $null
}
function Get-UsnName([string]$ln) {
    foreach ($tok in $ln.Split(',')) {
        $t = $tok.Trim().Trim('"').Trim()
        if (-not $t) { continue }
        if ($t -match '^0x[0-9A-Fa-f]+$') { continue }
        if ($t -match '^\d+$') { continue }
        if ($t -match '[\\/:*?<>|]') { continue }
        if ($t -match '^\$I[A-Za-z0-9]{6}(\.|$)' -or $t -match '\.[A-Za-z0-9]{1,5}$') { return $t }
    }
    return $null
}
function Test-UsnDelete([string]$ln) {
    if ($ln -match '(?i)file delete') { return $true }
    foreach ($mm in [regex]::Matches($ln, '0x[0-9A-Fa-f]{8}(?![0-9A-Fa-f])')) {
        $val = [Convert]::ToUInt32($mm.Value.Substring(2), 16)
        if (($val -band 0x200) -ne 0) { return $true }
    }
    return $false
}
# USN gunlugu her surucu icin sadece BIR kez okunur (eskiden 3 ayri tam gecis vardi); sonuc bellekte tutulur
$script:UsnRawCache = @{}
$script:UsnBg = @{}
function Stop-UsnBg([string]$dl) {
    $k = $dl.ToUpper()
    if (-not $script:UsnBg.ContainsKey($k)) { return }
    $bg = $script:UsnBg[$k]
    $script:UsnBg.Remove($k)
    try { if (-not $bg.Proc.HasExited) { $bg.Proc.Kill() } } catch {}
    Start-Sleep -Milliseconds 200
    Remove-Item -LiteralPath $bg.Cmd -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $bg.Out -Force -ErrorAction SilentlyContinue
}
# USN gunlugu okumasi (fsutil, dakikalar surebilir) diger adimlarla ayni anda arka planda baslatilir; sonuc Get-UsnRaw ile beklenip okunur
function Start-UsnBg([string]$dl) {
    $k = $dl.ToUpper()
    if ($script:UsnBg.ContainsKey($k) -or $script:UsnRawCache.ContainsKey($k)) { return }
    $id = [guid]::NewGuid().ToString('N')
    $tmpCmd = Join-Path $env:TEMP ('hk_usn_' + $id + '.cmd')
    $tmpOut = Join-Path $env:TEMP ('hk_usn_' + $id + '.txt')
    $cmdText = "@echo off`r`nfsutil usn readjournal " + $dl + " csv | findstr /i /c:`".exe`" /c:`".jar`" /c:`".rar`" /c:`".zip`" /c:`".7z`" /c:`".dll`" /c:`".bat`" /c:`".ps1`" /c:`".pf`" /c:`"`$I`" /c:`"ConsoleHost_history`" /c:`"JavaLauncher`" > `"" + $tmpOut + "`"`r`n"
    try {
        Set-Content -LiteralPath $tmpCmd -Value $cmdText -Encoding ASCII
        $pr = Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c "' + $tmpCmd + '"') -WindowStyle Hidden -PassThru -ErrorAction Stop
        if ($pr) { $script:UsnBg[$k] = @{ Proc = $pr; Cmd = $tmpCmd; Out = $tmpOut } }
    } catch { Remove-Item -LiteralPath $tmpCmd -Force -ErrorAction SilentlyContinue }
}
function Get-UsnRaw([string]$dl) {
    $k = $dl.ToUpper()
    if ($script:UsnRawCache.ContainsKey($k)) { return ,$script:UsnRawCache[$k] }
    $tmpCmd = $null
    $tmpOut = $null
    if ($script:UsnBg.ContainsKey($k)) {
        $bg = $script:UsnBg[$k]
        $script:UsnBg.Remove($k)
        try { $bg.Proc.WaitForExit() } catch {}
        $tmpCmd = $bg.Cmd
        $tmpOut = $bg.Out
    } else {
        $id = [guid]::NewGuid().ToString('N')
        $tmpCmd = Join-Path $env:TEMP ('hk_usn_' + $id + '.cmd')
        $tmpOut = Join-Path $env:TEMP ('hk_usn_' + $id + '.txt')
        $cmdText = "@echo off`r`nfsutil usn readjournal " + $dl + " csv | findstr /i /c:`".exe`" /c:`".jar`" /c:`".rar`" /c:`".zip`" /c:`".7z`" /c:`".dll`" /c:`".bat`" /c:`".ps1`" /c:`".pf`" /c:`"`$I`" /c:`"ConsoleHost_history`" /c:`"JavaLauncher`" > `"" + $tmpOut + "`"`r`n"
        try {
            Set-Content -LiteralPath $tmpCmd -Value $cmdText -Encoding ASCII
            & $tmpCmd | Out-Null
        } catch {}
    }
    $lines = @()
    if (Test-Path -LiteralPath $tmpOut) { try { $lines = [IO.File]::ReadAllLines($tmpOut, [Text.Encoding]::Default) } catch { $lines = @(Get-Content -LiteralPath $tmpOut -ErrorAction SilentlyContinue) } }
    Remove-Item -LiteralPath $tmpCmd -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue
    $script:UsnRawCache[$k] = $lines
    return ,$lines
}
function Select-UsnLines([string]$dl, [string[]]$needles) {
    $raw = Get-UsnRaw $dl
    $parts = @()
    foreach ($nd in $needles) { $parts += [regex]::Escape($nd) }
    $urx = New-Object System.Text.RegularExpressions.Regex (($parts -join '|'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $res = New-Object System.Collections.Generic.List[string]
    foreach ($ln in $raw) { if ($urx.IsMatch($ln)) { [void]$res.Add($ln) } }
    return $res.ToArray()
}
function Read-Usn([string]$dl) {
    $lines = @(Select-UsnLines $dl @('.exe', '.jar', '.rar', '.zip', '.7z', '.dll', '.bat', '.ps1', '.pf', '$I'))
    $cnt = 0
    $cut = (Get-Date).AddDays(-30)
    foreach ($ln in $lines) {
        if (-not (Test-UsnDelete $ln)) { continue }
        $nm = Get-UsnName $ln
        if (-not $nm) { continue }
        $tm = Get-UsnTime $ln
        $key = $nm.ToLower()
        if ($nm -match '^\$I[A-Za-z0-9]{6}(\.|$)') {
            if ($tm) {
                if (-not $script:BinEmptied.ContainsKey($dl) -or $tm -gt $script:BinEmptied[$dl]) { $script:BinEmptied[$dl] = $tm }
            }
            continue
        }
        if ($nm -match '^\$R') { continue }
        $cnt++
        if ($tm) {
            if (-not $script:UsnDel.ContainsKey($key) -or $tm -gt $script:UsnDel[$key]) { $script:UsnDel[$key] = $tm }
        }
        $ext = ''
        try { $ext = [IO.Path]::GetExtension($nm).ToLower() } catch {}
        if ($ext -eq '.pf') { [void]$script:DeletedPf.Add([pscustomobject]@{ Ad = $nm; Zaman = $tm; Surucu = $dl }) }
        $hit = Get-NameHit $nm $true
        $ns = 0
        if ($hit) { $ns = Name-Score $hit $true }
        if ($ns -gt 0) {
            Add-F -Kaynak 'USN silinme kaydi' -Ad $key -Yol $nm -Skor ($ns + 5) -Var 'Hayir' -Silinme $tm -Not ('dosya silinmis (USN gunlugu): ' + $hit.Name)
        }
        if ($tm -and $tm -ge $cut -and @('.exe', '.jar', '.rar', '.zip', '.7z', '.bat', '.ps1') -contains $ext) {
            [void]$script:UsnRecent.Add([pscustomobject]@{ Ad = $nm; Zaman = $tm; Surucu = $dl })
        }
    }
    return $cnt
}

function Add-Root([string]$r) {
    if ([string]::IsNullOrWhiteSpace($r)) { return }
    if (-not (Test-Path -LiteralPath $r)) { return }
    $r = $r.TrimEnd('\')
    foreach ($e in $script:ScanRoots) {
        if ($r -ieq $e -or $r.StartsWith($e + '\', [StringComparison]::OrdinalIgnoreCase)) { return }
    }
    [void]$script:ScanRoots.Add($r)
}

$script:mF = 0
$script:mS = 0

function Find-Paths([string]$text, [string]$exts) {
    $res = New-Object System.Collections.Generic.List[string]
    $pat = '[A-Za-z]:\\[^\x00-\x1f"<>|*?:]{3,260}?\.(?:' + $exts + ')(?![A-Za-z0-9])'
    try {
        $rx = New-Object System.Text.RegularExpressions.Regex ($pat, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase, [TimeSpan]::FromSeconds(25))
        foreach ($m in $rx.Matches($text)) { [void]$res.Add($m.Value) }
    } catch {}
    return $res
}
# Fileless / script kalibi: Invoke-*, Reflection.Assembly, base64, gizli pencere vb. (tek basina BAN sebebi degil, supheli)
$script:FlRx2 = '(?i)Invoke-Expression|Invoke-RestMethod|Invoke-WebRequest|Invoke-Command|Invoke-Shellcode|\bIEX\b|System\.Reflection\.Assembly|\[Reflection\.Assembly\]|DownloadString|DownloadFile|FromBase64String|-enc(odedcommand)?\s|-w(indowstyle)?\s+hidden|-ExecutionPolicy\s+Bypass|\bmshta\b|certutil.*-urlcache|bitsadmin.*transfer|wmic\s+.*process\s+call\s+create'

# Byte dizisinden (registry binary / XML / PIDL) dosya yolu ve dosya adi cikarir (hem UTF-16 hem ASCII okunur)
function Get-PathsFromBytes([byte[]]$b, [bool]$namesToo = $false) {
    $res = New-Object System.Collections.Generic.List[string]
    if ($null -eq $b -or $b.Length -lt 8) { return $res }
    $seen = @{}
    $texts = New-Object System.Collections.Generic.List[string]
    foreach ($off in @(0, 1)) {
        $len = $b.Length - $off
        if ($len -lt 4) { continue }
        $sub = New-Object byte[] $len
        [Array]::Copy($b, $off, $sub, 0, $len)
        [void]$texts.Add([Text.Encoding]::Unicode.GetString($sub))
    }
    [void]$texts.Add([Text.Encoding]::GetEncoding(28591).GetString($b))
    foreach ($t in $texts) {
        foreach ($p in (Find-Paths $t 'exe|dll|jar|bat|ps1|scr|cmd|vbs|com')) {
            $k = $p.ToLower()
            if (-not $seen.ContainsKey($k)) { $seen[$k] = 1; [void]$res.Add($p) }
        }
        if ($namesToo) {
            foreach ($m in [regex]::Matches($t, '(?i)(?<![\w.\-\\/])[\w\-.]{2,80}\.(?:exe|dll|jar|bat|ps1|scr|cmd|vbs)(?![\w])')) {
                $k = $m.Value.ToLower()
                if (-not $seen.ContainsKey($k)) { $seen[$k] = 1; [void]$res.Add($m.Value) }
            }
        }
    }
    return $res
}

$script:PiCache = @{}
function Get-PiCached([string]$p) {
    $k = $p.ToLower()
    if (-not $script:PiCache.ContainsKey($k)) { $script:PiCache[$k] = Test-PathInfo $p }
    return $script:PiCache[$k]
}

# ---------------- process bellegi (RAM) string analizi ----------------
# .exe/.dll/.jar... yolu ve dosya adi iceren stringler: bilinen hile isimleri, silinmis/olagan disi yerden calisanlar
function Analyze-MemExe([string]$label, $strings, [int]$procId) {
    if ($null -eq $strings -or $strings.Count -eq 0) { return }
    $text = [string]::Join("`n", $strings)
    $seenP = @{}
    $cnt = 0
    foreach ($pm in (Find-Paths $text 'exe|dll|jar|bat|ps1|scr|cmd|vbs|com')) {
        $lk = $pm.ToLower()
        if ($seenP.ContainsKey($lk)) { continue }
        $seenP[$lk] = 1
        $leaf = ''
        try { $leaf = Split-Path -Leaf $pm } catch {}
        if (-not $leaf) { continue }
        $zone = Get-Zone $pm
        $hit = Get-NameHit $leaf $false
        if ($zone -eq 'system' -and -not $hit) { continue }
        $cnt++
        if ($cnt -gt 3000) { break }
        $pi = Get-PiCached $pm
        Eval-Exec -Kaynak ('Bellek stringi: ' + $label) -Path $pm -Exists $pi.Exists -Removed $pi.Removed -Note ('process bellegindeki yol (PID ' + $procId + ')')
    }
    $seenN = @{}
    foreach ($m in [regex]::Matches($text, '(?i)(?<![\w.\-\\/])([\w\-]{2,60})\.(?:exe|dll|jar)(?![\w])')) {
        $leaf = $m.Value
        $lk = $leaf.ToLower()
        if ($seenN.ContainsKey($lk)) { continue }
        $seenN[$lk] = 1
        $hit = Get-NameHit $leaf $false
        if (-not $hit) { continue }
        Add-F -Kaynak ('Bellek stringi: ' + $label) -Ad $lk -Yol $leaf -Skor 45 -Var 'Bilinmiyor' -Not ('process bellegindeki dosya adi, hile ismi: ' + $hit.Name + ' (PID ' + $procId + ')')
    }
}
# DPS servisinin bellegindeki !!program.exe!yyyy/MM/dd:HH:mm:ss! kayitlari (calistirma zamani)
function Analyze-MemDps([string]$label, $strings, [int]$procId) {
    if ($null -eq $strings -or $strings.Count -eq 0) { return }
    $text = [string]::Join("`n", $strings)
    $seen = @{}
    foreach ($m in [regex]::Matches($text, '!!([^!\\/\r\n]{2,80}\.(?:exe|dll))!(\d{4}/\d{2}/\d{2}:\d{2}:\d{2}:\d{2})!')) {
        $n = $m.Groups[1].Value
        $hit = Get-NameHit $n $false
        if (-not $hit) { continue }
        $key = $n.ToLower() + '|' + $m.Groups[2].Value
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = 1
        $tm = $null
        try { $tm = [datetime]::ParseExact($m.Groups[2].Value, 'yyyy/MM/dd:HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) } catch {}
        Add-F -Kaynak ('Bellek stringi: ' + $label + ' (DPS kaydi)') -Ad $n.ToLower() -Yol $n -Skor 50 -Son $tm -Var 'Bilinmiyor' -Not ('DPS bellek kaydi: calistirilmis program, hile ismi: ' + $hit.Name)
    }
}
# Dnscache bellegindeki alan adlari: hile site/istemci isimleri
function Analyze-MemDns([string]$label, $strings, [int]$procId) {
    if ($null -eq $strings -or $strings.Count -eq 0) { return }
    $text = [string]::Join("`n", $strings)
    $seen = @{}
    foreach ($m in [regex]::Matches($text, '(?i)(?<![a-z0-9\-])[a-z0-9][a-z0-9\-]{1,40}(?:\.[a-z0-9\-]{1,30})*\.(?:com|net|org|gg|io|xyz|ru|to|cc|club|pw|dev|me|app|su|cloud|shop|store|lol|fun|top|info|site|online|space|tech|cx|ws)(?![a-z0-9])')) {
        $d = $m.Value.ToLower()
        if ($seen.ContainsKey($d)) { continue }
        $seen[$d] = 1
        if ($seen.Count -gt 20000) { break }
        $hit = Get-NameHit $d $false
        if (-not $hit) { continue }
        Add-F -Kaynak ('Bellek stringi: ' + $label + ' (DNS)') -Ad ('alan adi: ' + $d) -Yol $d -Skor 45 -Var 'Bilinmiyor' -Not ('DNS onbellegi/bellek: bu alan adina baglanilmis olabilir, hile ismi: ' + $hit.Name)
    }
}
# wmic ile program baslatma komutlari (wmic ... process call create)
function Analyze-MemWmic([string]$label, $strings, [int]$procId) {
    if ($null -eq $strings -or $strings.Count -eq 0) { return }
    $seen = @{}
    foreach ($s in $strings) {
        if ($s.IndexOf('wmic', [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        $sc = 0
        if ($s -match '(?i)wmic(\.exe)?\s+.*process\s+call\s+create') { $sc = 60 }
        elseif ($s -match '(?i)wmic(\.exe)?\s+\S.*\.(exe|dll|bat|ps1|jar)') { $sc = 40 }
        if ($sc -eq 0) { continue }
        $k = $s.ToLower()
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = 1
        if ($seen.Count -gt 10) { break }
        $snip = $s
        if ($snip.Length -gt 220) { $snip = $snip.Substring(0, 220) + '...' }
        Add-F -Kaynak ('Bellek stringi: ' + $label + ' (wmic)') -Ad 'wmic ile program baslatma' -Yol $snip -Skor $sc -Var 'Bilinmiyor' -Not ('komut: ' + $snip + ' (PID ' + $procId + ') - exe/uzantisiz dosya/ADS baslatmak icin kullanilir')
    }
}
function Scan-MemProcess([string]$label, [int]$procId, [string]$rx, [string]$mode) {
    Log ('   bellek taraniyor: ' + $label + ' (PID ' + $procId + ')') 'DarkGray'
    $list = $null
    try { $list = [HkNative]::MemStrings($procId, $rx, 5, $true, $true, $false, [long]734003200) } catch { $list = $null }
    if ($null -eq $list) { $script:MemFail++; [void]$script:MemFailNames.Add($label); return }
    $script:MemOk++
    if ($mode -eq 'dns') { Analyze-MemDns $label $list $procId; return }
    Analyze-MemExe $label $list $procId
    if ($mode -eq 'dps') { Analyze-MemDps $label $list $procId }
    if ($mode -eq 'wmic') { Analyze-MemWmic $label $list $procId }
}

function Get-DelTime($x) {
    if ($x.Silinme) { return $x.Silinme }
    if ($x.Var -eq 'Hayir') {
        $k = ([string]$x.Ad).ToLower()
        if ($script:UsnDel.ContainsKey($k)) { return $script:UsnDel[$k] }
        foreach ($b in $script:BinItems) { if ($b.Orijinal -ieq $x.Yol) { return $b.Silinme } }
    }
    return $null
}
function Show-Finding($x) {
    $col = 'Yellow'
    if ($x.Skor -ge 60) { $col = 'Red' }
    Log '' 'Gray'
    $vtxt = ''
    if ($x.Skor -lt 60) { $vtxt = ' - tek basina kanit degil, DOGRULA' }
    Log ('   [%' + $x.Skor + ' hile ihtimali' + $vtxt + '] ' + $x.Ad) $col
    Log ('      Konum            : ' + $x.Yol) 'Gray'
    $durum = 'DURUYOR'
    if ($x.Var -eq 'Hayir') {
        $dt = Get-DelTime $x
        if ($dt) { $durum = 'SILINMIS - silinme zamani: ' + (Fmt $dt) } else { $durum = 'SILINMIS - silinme zamani kayitlarda bulunamadi' }
    } elseif ($x.Var -eq 'Bilinmiyor') {
        $durum = 'bilinmiyor (yol kaydi yok)'
    }
    Log ('      Durum            : ' + $durum) 'Gray'
    Log ('      En son calistirma: ' + (Fmt $x.Son)) 'Gray'
    Log ('      Ilk gorulme/indirme: ' + (Fmt $x.Ilk)) 'Gray'
    Log ('      Bulundugu yer    : ' + $x.Kaynak) 'DarkGray'
    if ($x.Not) { Log ('      Detay            : ' + $x.Not) 'DarkGray' }
}
function Start-Sec {
    $script:mF = $script:F.Count
    $script:mS = $script:Sys.Count
}
function Show-Section {
    for ($i = $script:mS; $i -lt $script:Sys.Count; $i++) {
        $s = $script:Sys[$i]
        $zt = ''
        if ($s.Zaman) { $zt = ' [' + (Fmt $s.Zaman) + ']' }
        Log ('   ! [%' + $s.Skor + '] ' + $s.Baslik + $zt) 'Yellow'
        Log ('        ' + $s.Aciklama) 'DarkGray'
    }
    $items = @()
    for ($i = $script:mF; $i -lt $script:F.Count; $i++) { $items += $script:F[$i] }
    $sel = @($items | Where-Object { $_.Skor -ge 30 -and -not $_.Benign } | Sort-Object -Property @{ Expression = 'Skor'; Descending = $true }, @{ Expression = 'Son'; Descending = $true })
    $rest = $items.Count - $sel.Count
    if ($sel.Count -eq 0) { Log '   -> supheli bulgu yok' 'Green' }
    $shownKeys = @{}
    $dupN = 0
    foreach ($x in $sel) {
        $dk = (([string]$x.Ad) + '|' + ([string]$x.Yol)).ToLower()
        if ($shownKeys.ContainsKey($dk)) { $dupN++; continue }
        $shownKeys[$dk] = 1
        Show-Finding $x
    }
    if ($dupN -gt 0) { Log ('   (' + $dupN + ' ayni bulgu tekrar kaydi gizlendi)') 'DarkGray' }
    if ($rest -gt 0) { Log ('   (' + $rest + ' dusuk guvenli kayit daha - sonda TAM LISTE bolumunde)') 'DarkGray' }
}

function Show-Item($m, [string]$color, [bool]$fileOnly = $false) {
    Log '' 'Gray' $fileOnly
    Log ('[%' + $m.Skor + '] ' + $m.Ad) $color $fileOnly
    Log ('   Yer            : ' + $m.Yol) 'Gray' $fileOnly
    $durum = 'DURUYOR'
    if ($m.Var -eq 'Hayir') {
        if ($m.Silinme) { $durum = 'SILINMIS - silinme zamani: ' + (Fmt $m.Silinme) } else { $durum = 'SILINMIS (silinme zamani kayitlarda bulunamadi)' }
    } elseif ($m.Var -eq 'Bilinmiyor') {
        $durum = 'bilinmiyor (yol kaydi yok)'
    }
    Log ('   Durum          : ' + $durum) 'Gray' $fileOnly
    Log ('   Son kullanim   : ' + (Fmt $m.Son) + '     Ilk gorulme/indirme: ' + (Fmt $m.Ilk)) 'Gray' $fileOnly
    Log ('   Kaynaklar      : ' + $m.Kaynaklar) 'Gray' $fileOnly
    if ($m.Not) { Log ('   Detay          : ' + $m.Not) 'DarkGray' $fileOnly }
}

# =====================================================================
Log '===================================================================' 'Green'
Log '  HileKiran - Minecraft hile / iz analizi' 'Green'
Log ('  Baslangic: ' + (Get-Date)) 'Green'
Log '  Not: Sadece bu bilgisayarda calisir, veri gondermez, hicbir seyi silmez.' 'DarkGray'
Log '===================================================================' 'Green'
if ($PSVersionTable.PSVersion.Major -lt 5) { Log 'UYARI: PowerShell 5+ gerekli, bazi kontroller calismayabilir.' 'Yellow' }
if (-not $script:HkOk) { Log 'UYARI: yardimci modul derlenemedi; Prefetch saatleri/USB/BAM yol cozumu kisitli olabilir.' 'Yellow' } else { Log 'Yardimci modul (Prefetch/USN/ADS cozumleyici): hazir.' 'DarkGray' }

# =====================================================================
# HILE AVI MODU ve paylasilan yardimcilar (adimlardan once tanimlanir)
# =====================================================================
$jarCs = @'
using System;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Threading.Tasks;
public class HkJarRes {
    public HashSet<string> Terms = new HashSet<string>();
    public HashSet<string> Brands = new HashSet<string>();
    public StringBuilder MetaSb = new StringBuilder();
    public bool Plugin;
    public string Pkg = "";
    public int Classes;
    public int Short;
    public int Scanned;
    public int Nested;
    public int TextScanned;
    public bool TimedOut;
    public bool Error;
    public string EncReason = "";
    public int BadMagic;
    public HashSet<string> ObfMarks = new HashSet<string>();
    public List<string> NativeLibs = new List<string>();
    public List<string> HiEnt = new List<string>();
    public string Meta { get { return MetaSb.ToString(); } }
}
public static class HkJar {
    static Encoding Lat = Encoding.GetEncoding(28591);
    static Dictionary<string, Regex> Cache = new Dictionary<string, Regex>();
    static Regex RxPlugin = new Regex(@"^(plugin\.yml|bungee\.yml|paper-plugin\.yml|velocity-plugin\.json)$", RegexOptions.IgnoreCase);
    static Regex RxMeta = new Regex(@"^(fabric\.mod\.json|quilt\.mod\.json|mcmod\.info|META-INF/mods\.toml|META-INF/neoforge\.mods\.toml)$", RegexOptions.IgnoreCase);
    static Regex RxText = new Regex(@"\.(json|txt|cfg|toml|properties|yml|yaml)$", RegexOptions.IgnoreCase);
    static Regex Get(string pat) {
        lock (Cache) {
            Regex r;
            if (!Cache.TryGetValue(pat, out r)) {
                r = new Regex(pat, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);
                Cache[pat] = r;
            }
            return r;
        }
    }
    static Regex RxObf = new Regex(@"ALLATORIxDEMO|Allatori|Zelix KlassMaster|Stringer Java|DashO|Paramorphism|Skidfuscator|qProtect|Branchlock|Binscure|JNIC|Superblaze|obfuscated by", RegexOptions.None);
    static Regex RxNative = new Regex(@"\.(dll|so|dylib|jnilib)$", RegexOptions.IgnoreCase);
    static Regex RxBlob = new Regex(@"\.(bin|dat|enc|data|pak|res|cache|key)$", RegexOptions.IgnoreCase);
    public static double Entropy(byte[] b, int max) {
        if (b == null || b.Length == 0) { return 0.0; }
        int n = Math.Min(b.Length, max);
        long[] cnt = new long[256];
        for (int i = 0; i < n; i++) { cnt[b[i]]++; }
        double h = 0.0;
        for (int i = 0; i < 256; i++) {
            if (cnt[i] == 0) { continue; }
            double p = (double)cnt[i] / n;
            h -= p * Math.Log(p, 2.0);
        }
        return h;
    }
    public static string[] PeSections(byte[] b) {
        List<string> r = new List<string>();
        try {
            if (b == null || b.Length < 256 || b[0] != 0x4D || b[1] != 0x5A) { return r.ToArray(); }
            int pe = BitConverter.ToInt32(b, 0x3C);
            if (pe < 0 || pe + 24 > b.Length) { return r.ToArray(); }
            if (b[pe] != 0x50 || b[pe + 1] != 0x45) { return r.ToArray(); }
            int nsec = BitConverter.ToUInt16(b, pe + 6);
            int optSize = BitConverter.ToUInt16(b, pe + 20);
            int sec = pe + 24 + optSize;
            for (int i = 0; i < nsec && i < 40; i++) {
                int o = sec + i * 40;
                if (o + 8 > b.Length) { break; }
                r.Add(System.Text.Encoding.ASCII.GetString(b, o, 8).TrimEnd('\0'));
            }
        } catch { }
        return r.ToArray();
    }
    static string ZipEnc(FileStream fs, long len) {
        int tail = (int)Math.Min(len, 65557L);
        byte[] t = new byte[tail];
        fs.Seek(len - tail, SeekOrigin.Begin);
        int got = 0;
        while (got < tail) { int c = fs.Read(t, got, tail - got); if (c <= 0) { break; } got += c; }
        int eocd = -1;
        for (int i = got - 22; i >= 0; i--) {
            if (t[i] == 0x50 && t[i + 1] == 0x4B && t[i + 2] == 0x05 && t[i + 3] == 0x06) { eocd = i; break; }
        }
        if (eocd < 0) { return ""; }
        int total = BitConverter.ToUInt16(t, eocd + 10);
        uint cdSize = BitConverter.ToUInt32(t, eocd + 12);
        uint cdOff = BitConverter.ToUInt32(t, eocd + 16);
        if (cdSize == 0xFFFFFFFFu || cdOff == 0xFFFFFFFFu || total == 0xFFFF) { return ""; }
        if (cdSize > 33554432u || (long)cdOff + (long)cdSize > len) { return ""; }
        byte[] cd = new byte[cdSize];
        fs.Seek((long)cdOff, SeekOrigin.Begin);
        got = 0;
        while (got < cd.Length) { int c2 = fs.Read(cd, got, cd.Length - got); if (c2 <= 0) { break; } got += c2; }
        int pos = 0;
        int n = 0;
        int enc = 0;
        int aes = 0;
        while (pos + 46 <= got && cd[pos] == 0x50 && cd[pos + 1] == 0x4B && cd[pos + 2] == 0x01 && cd[pos + 3] == 0x02) {
            int flags = BitConverter.ToUInt16(cd, pos + 8);
            int method = BitConverter.ToUInt16(cd, pos + 10);
            int nl = BitConverter.ToUInt16(cd, pos + 28);
            int el = BitConverter.ToUInt16(cd, pos + 30);
            int cl = BitConverter.ToUInt16(cd, pos + 32);
            n++;
            if ((flags & 1) != 0) { enc++; }
            if (method == 99) { aes++; }
            pos += 46 + nl + el + cl;
            if (n > 200000) { break; }
        }
        if (enc > 0 || aes > 0) {
            string a = "";
            if (aes > 0) { a = " (AES)"; }
            return "sifreli zip: " + Math.Max(enc, aes) + "/" + n + " dosya sifreli" + a;
        }
        return "";
    }
    static string RarEnc(FileStream fs, long len) {
        byte[] b = new byte[64];
        fs.Seek(0, SeekOrigin.Begin);
        int got = fs.Read(b, 0, 64);
        if (got < 20) { return ""; }
        if (b[4] == 0x1A && b[5] == 0x07 && b[6] == 0x01 && b[7] == 0x00) {
            int p = 12;
            int shift = 0;
            while (p < got) { byte x = b[p]; p++; shift += 7; if ((x & 0x80) == 0) { break; } if (shift > 28) { break; } }
            if (p < got) {
                int type = 0;
                shift = 0;
                while (p < got) { byte y = b[p]; p++; type |= (y & 0x7F) << shift; shift += 7; if ((y & 0x80) == 0) { break; } if (shift > 28) { break; } }
                if (type == 4) { return "sifreli rar: basliklar sifreli (icerik listesi bile gorunmuyor)"; }
            }
        } else if (b[4] == 0x1A && b[5] == 0x07 && b[6] == 0x00) {
            int flags = b[10] | (b[11] << 8);
            if (b[9] == 0x73 && (flags & 0x0080) != 0) { return "sifreli rar: basliklar sifreli"; }
        }
        return "";
    }
    static string SevenEnc(FileStream fs, long len) {
        int tail = (int)Math.Min(len, 65536L);
        byte[] t = new byte[tail];
        fs.Seek(len - tail, SeekOrigin.Begin);
        int got = 0;
        while (got < tail) { int c = fs.Read(t, got, tail - got); if (c <= 0) { break; } got += c; }
        for (int i = 0; i + 3 < got; i++) {
            if (t[i] == 0x06 && t[i + 1] == 0xF1 && t[i + 2] == 0x07 && t[i + 3] == 0x01) { return "sifreli 7z (AES kodlayici bulundu)"; }
        }
        return "";
    }
    public static string EncInfo(string path) {
        try {
            using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
                long len = fs.Length;
                if (len < 32) { return ""; }
                byte[] head = new byte[8];
                int hn = fs.Read(head, 0, 8);
                if (hn < 8) { return ""; }
                if (head[0] == 0x50 && head[1] == 0x4B) { return ZipEnc(fs, len); }
                if (head[0] == 0x52 && head[1] == 0x61 && head[2] == 0x72 && head[3] == 0x21) { return RarEnc(fs, len); }
                if (head[0] == 0x37 && head[1] == 0x7A && head[2] == 0xBC && head[3] == 0xAF) { return SevenEnc(fs, len); }
            }
        } catch { }
        return "";
    }
    static byte[] ReadAll(ZipArchiveEntry e, int len) {
        try {
            using (Stream s = e.Open()) {
                byte[] b = new byte[len];
                int off = 0;
                while (off < len) {
                    int c = s.Read(b, off, len - off);
                    if (c <= 0) break;
                    off += c;
                }
                if (off != len) Array.Resize(ref b, off);
                return b;
            }
        } catch { return null; }
    }
    static string ReadText(ZipArchiveEntry e) {
        try {
            using (StreamReader sr = new StreamReader(e.Open(), Encoding.UTF8)) { return sr.ReadToEnd(); }
        } catch { return null; }
    }
    static void AddMatches(Regex rx, string t, HashSet<string> set) {
        foreach (Match m in rx.Matches(t)) { set.Add(m.Value.ToLowerInvariant().Replace(" ", "")); }
    }
    static void Walk(ZipArchive z, HkJarRes r, Regex term, Regex brand, Regex pkg, System.Diagnostics.Stopwatch sw, int maxSec, int depth) {
        foreach (ZipArchiveEntry e in z.Entries) {
            if (sw.Elapsed.TotalSeconds > maxSec) { r.TimedOut = true; return; }
            string n = e.FullName;
            if (RxPlugin.IsMatch(n)) r.Plugin = true;
            if (r.NativeLibs.Count < 5 && RxNative.IsMatch(n)) { r.NativeLibs.Add(n); }
            if (r.Pkg.Length == 0) {
                Match pm = pkg.Match(n);
                if (pm.Success) r.Pkg = pm.Groups[1].Value;
            }
            if (n.EndsWith(".class", StringComparison.Ordinal)) {
                r.Classes++;
                string bn = Path.GetFileNameWithoutExtension(n);
                if (bn.Length <= 2) r.Short++;
                long len = e.Length;
                if (r.Scanned < 2500 && len > 0 && len < 1048576) {
                    r.Scanned++;
                    byte[] buf = ReadAll(e, (int)len);
                    if (buf != null) {
                        if (buf.Length >= 4 && !(buf[0] == 0xCA && buf[1] == 0xFE && buf[2] == 0xBA && buf[3] == 0xBE)) { r.BadMagic++; }
                        string t = Lat.GetString(buf);
                        AddMatches(term, t, r.Terms);
                        AddMatches(brand, t, r.Brands);
                        foreach (Match om in RxObf.Matches(t)) { r.ObfMarks.Add(om.Value); }
                    }
                }
            } else if (RxBlob.IsMatch(n) && e.Length > 20000 && e.Length < 4194304 && r.HiEnt.Count < 3) {
                byte[] bb = ReadAll(e, (int)e.Length);
                if (bb != null && Entropy(bb, bb.Length) > 7.9) { r.HiEnt.Add(n + " (" + e.Length + " bayt)"); }
            } else if (RxMeta.IsMatch(n) && e.Length < 65536) {
                string tx = ReadText(e);
                if (tx != null) r.MetaSb.Append(' ').Append(tx);
            } else if (depth < 2 && n.EndsWith(".jar", StringComparison.OrdinalIgnoreCase) && e.Length > 0 && e.Length < 31457280 && r.Nested < 25) {
                r.Nested++;
                try {
                    byte[] ib = ReadAll(e, (int)e.Length);
                    if (ib != null) {
                        using (MemoryStream ms = new MemoryStream(ib)) {
                            using (ZipArchive inner = new ZipArchive(ms, ZipArchiveMode.Read)) {
                                Walk(inner, r, term, brand, pkg, sw, maxSec, depth + 1);
                            }
                        }
                    }
                } catch { }
            } else if (RxText.IsMatch(n) && e.Length > 20 && e.Length < 262144 && r.TextScanned < 150) {
                r.TextScanned++;
                string tx2 = ReadText(e);
                if (tx2 != null) {
                    AddMatches(term, tx2, r.Terms);
                    AddMatches(brand, tx2, r.Brands);
                }
            }
        }
    }
    public static HkJarRes Scan(string path, string termPat, string brandPat, string pkgPat, int maxSeconds) {
        HkJarRes r = new HkJarRes();
        r.EncReason = EncInfo(path);
        try {
            Regex term = Get(termPat);
            Regex brand = Get(brandPat);
            Regex pkg = Get(pkgPat);
            System.Diagnostics.Stopwatch sw = System.Diagnostics.Stopwatch.StartNew();
            using (ZipArchive z = ZipFile.OpenRead(path)) {
                Walk(z, r, term, brand, pkg, sw, maxSeconds, 0);
            }
        } catch { r.Error = true; }
        return r;
    }
    public static HkJarRes[] ScanMany(string[] paths, string termPat, string brandPat, string pkgPat, int maxSeconds, int threads) {
        HkJarRes[] res = new HkJarRes[paths.Length];
        ParallelOptions po = new ParallelOptions();
        po.MaxDegreeOfParallelism = threads;
        Parallel.For(0, paths.Length, po, delegate(int i) {
            res[i] = Scan(paths[i], termPat, brandPat, pkgPat, maxSeconds);
        });
        return res;
    }
}
'@
$script:ModTermPat = 'kill ?aura|aim ?assist|trigger ?bot|auto ?clicker|click ?gui|self ?destruct|scaffold(?!ing)|auto ?totem|auto ?inv ?totem|chest ?esp|chest ?stealer|anti ?knockback|anti ?kb|jump ?reset|wtap|block ?hit(?!result)|auto ?pot(?!ion)|no ?slow ?down|auto ?crystal|crystal ?aura|anchor ?(?:macro|aura)|auto ?anchor|shield ?breaker|auto ?d ?tap|stun ?slam|mace ?swap|silent ?aim|target ?strafe|elytra ?target|hitbox ?expand|pearl ?catch'
$script:BrandRx = New-Object System.Text.RegularExpressions.Regex ('astralux|astraulex|helsing ?client|shoreline ?client|vanadium ?client|nyrex|noxx ?client|alycone|luminex ?(?:beta|client)|marlow ?client|zoomies ?client|catlean|wurst ?client|doomsday ?client|liquidbounce|meteor ?client|rusherhack|vape ?v4|achilles ?client|calcium ?client|xenon ?client|krypton ?client|glazed ?client|hellion ?client|prestige ?client|phantom ?client|aristois|huzuni|impact ?client|future ?client|sigma ?client|rise ?client|tenacity|astolfo|novoline|remix ?client|exhibition ?client', ([System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Compiled'))
$script:PkgRx = '(?i)^(meteordevelopment/meteorclient|net/wurstclient|net/ccbluex/liquidbounce|me/zeroeightsix/kami)'
function Get-Brands([string]$text, $dict) {
    foreach ($m in $script:BrandRx.Matches($text)) { $dict[($m.Value.ToLower() -replace ' ', '')] = 1 }
}
$script:ModTermRx = New-Object System.Text.RegularExpressions.Regex ($script:ModTermPat, ([System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Compiled'))
function Get-Terms([string]$text, $dict) {
    foreach ($m in $script:ModTermRx.Matches($text)) { $dict[($m.Value.ToLower() -replace ' ', '')] = 1 }
}

$knownNat = '(?i)^(lwjgl|glfw|openal|jemalloc|stb|tinyfd|nanovg|nfd|jna|sqlite|libusb|vcruntime|msvcp|concrt|ucrtbase|api-ms)'
function Has-Any([string]$t, [string[]]$needles, [bool]$ic = $false) {
    $cmp = [StringComparison]::Ordinal
    if ($ic) { $cmp = [StringComparison]::OrdinalIgnoreCase }
    foreach ($nd in $needles) { if ($t.IndexOf($nd, $cmp) -ge 0) { return $true } }
    return $false
}
$script:ObfList = New-Object System.Collections.Generic.List[object]
$script:ObfSeen = @{}
function Add-ObfNote([string]$path, [string]$reason) {
    if (-not $reason) { return }
    $k = ($path + '|' + $reason).ToLower()
    if ($script:ObfSeen.ContainsKey($k)) { return }
    $script:ObfSeen[$k] = 1
    [void]$script:ObfList.Add([pscustomobject]@{ Yol = $path; Neden = $reason })
}
function Get-PackInfo($b) {
    $res = @{ Reason = ''; Bonus = 0 }
    if ($null -eq $b -or $b.Length -lt 4096) { return $res }
    $secs = @()
    try { $secs = @([HkJar]::PeSections($b)) } catch {}
    $pk = @()
    foreach ($sn in $secs) { if ($sn -match '(?i)^\.?(upx\d|vmp\d|themida|winlice|enigma\d?|aspack|adata|petite|mpress\d|nsp\d|boom|perplex|pec\d?|yoda|rlpack|kkrunchy|neolite|molebox|obsidium|armadillo|svkp|ezip)') { $pk += $sn } }
    $ent = 0.0
    try { $ent = [HkJar]::Entropy($b, 8388608) } catch {}
    $parts = @()
    if ($pk.Count -gt 0) { $parts += ('paketleyici/koruyucu bolum adlari: ' + ($pk -join ', ')); $res.Bonus = 25 }
    if ($ent -gt 7.4 -and $b.Length -gt 200000) { $parts += ('yuksek entropi ' + [Math]::Round($ent, 2) + ' (paketlenmis/sifreli icerik olabilir)'); $res.Bonus = $res.Bonus + 15 }
    if ($parts.Count -gt 0) { $res.Reason = ($parts -join '; ') }
    return $res
}
function Show-ObfSummary {
    $items = @($script:ObfList)
    Log '' 'Gray'
    Log '=================== SIFRELI / OBFUSCATE / PAKETLI DOSYALAR ===================' 'Magenta'
    if ($items.Count -eq 0) {
        Log '   Bu taramada sifreli arsiv, sifreli class, obfuscator imzasi veya paketli exe bulunmadi.' 'Green'
        return
    }
    Log ('   ' + $items.Count + ' kayit. Icerigi gizlendigi/okunamadigi icin elle bakman gerekebilir:') 'Yellow'
    foreach ($it in @($items | Select-Object -First 60)) {
        Log ('   ' + $it.Yol) 'Yellow'
        Log ('        -> ' + $it.Neden) 'DarkYellow'
    }
    if ($items.Count -gt 60) { Log ('   ... ve ' + ($items.Count - 60) + ' kayit daha.') 'DarkGray' }
}
function Add-HistVals($val, $list) {
    foreach ($v in @($val)) {
        if ($v -is [byte[]]) {
            foreach ($z in ([Text.Encoding]::Unicode.GetString($v) -split "`0")) { if ($z) { [void]$list.Add($z) } }
        } elseif ($v) {
            [void]$list.Add([string]$v)
        }
    }
}
function Invoke-NameDeep {
Step '[17+/17] V) OZEL TARAMA: adi bilinen bir hile istemcisiyle eslesen dosyalarin icerigi (sure siniri yok)...'
Start-Sec
$vList = @($script:NameDeep)
Log ('   isim eslesen ' + $vList.Count + ' dosya ozel taramaya alindi.') 'DarkGray'
foreach ($vp in $vList) {
    if (-not (Test-Path -LiteralPath $vp)) { continue }
    $vf = $null
    try { $vf = Get-Item -LiteralPath $vp -Force -ErrorAction Stop } catch { continue }
    if (-not $vf -or $vf.PSIsContainer) { continue }
    $vext = $vf.Extension.ToLower()
    $vh = Get-NameHit $vf.Name $false
    $vhn = ''
    if ($vh) { $vhn = $vh.Name }
    Write-Host ('   [ozel tarama] ' + $vp) -ForegroundColor DarkGray
    $tk = @()
    $bk = @()
    $why = New-Object System.Collections.Generic.List[string]
    $sc = 40
    $info = ''
    [void]$why.Add('dosya adi bilinen hile istemcisiyle eslesti: ' + $vhn)
    if ($vext -eq '.jar' -or $vext -eq '.zip') {
        $classes = 0
        $short = 0
        $pkg = ''
        $plug = $false
        $nested = 0
        $meta = ''
        $got = $false
        if ($jarCsOk) {
            $vx = $null
            try { $vx = [HkJar]::Scan($vp, $script:ModTermPat, $script:BrandRx.ToString(), $script:PkgRx, 120) } catch {}
            if ($vx -and -not $vx.Error) {
                $got = $true
                $tk = @($vx.Terms)
                $bk = @($vx.Brands)
                $classes = $vx.Classes
                $short = $vx.Short
                $pkg = $vx.Pkg
                $plug = $vx.Plugin
                $nested = $vx.Nested
                $meta = $vx.Meta
            }
        } else {
            $vd = Deep-Jar $vp
            $got = $true
            $tk = @($vd.Terms.Keys)
            $bk = @($vd.Brands.Keys)
            $classes = $vd.Classes
            $short = $vd.Short
            $pkg = $vd.Pkg
            $plug = $vd.Plugin
            $nested = $vd.Nested
            $meta = $vd.Meta
        }
        if (-not $got) {
            [void]$why.Add('icerik OKUNAMADI (bozuk/sifreli arsiv olabilir)')
        } else {
            if ($pkg) { $sc += 30; [void]$why.Add('bilinen hile istemcisi paket yolu: ' + $pkg) }
            $mh = Get-NameHit $meta $false
            if ($mh) { $sc += 15; [void]$why.Add('mod bilgisinde hile ismi: ' + $mh.Name) }
            if ($classes -ge 20 -and ($short / [double]$classes) -ge 0.6) { $sc += 20; [void]$why.Add('obfuscate edilmis gorunuyor (' + $short + '/' + $classes + ' sinif adi 1-2 harf)') }
            if ($plug) { [void]$why.Add('plugin.yml var: sunucu eklentisi olabilir') }
            if ($vx) {
                if ($vx.EncReason) { $sc += 25; [void]$why.Add($vx.EncReason); Add-ObfNote $vp $vx.EncReason }
                if ($vx.BadMagic -gt 0) { $sc += 40; [void]$why.Add('class dosyalarinin ' + $vx.BadMagic + ' tanesi gecersiz (sifreli olabilir)'); Add-ObfNote $vp ('sifreli/bozuk class dosyasi: ' + $vx.BadMagic) }
                if ($vx.ObfMarks.Count -gt 0) { $sc += 15; $omv = (@($vx.ObfMarks) -join ', '); [void]$why.Add('obfuscator imzasi: ' + $omv); Add-ObfNote $vp ('obfuscator imzasi: ' + $omv) }
                if ($vx.NativeLibs.Count -gt 0) { $sc += 10; $nlv = (@($vx.NativeLibs) -join ', '); [void]$why.Add('jar icinde yerel kutuphane: ' + $nlv); Add-ObfNote $vp ('jar icinde yerel kutuphane (dll/so): ' + $nlv) }
                if ($vx.HiEnt.Count -gt 0) { $sc += 15; $hev = (@($vx.HiEnt) -join ', '); [void]$why.Add('yuksek entropili veri dosyasi: ' + $hev); Add-ObfNote $vp ('yuksek entropili veri dosyasi: ' + $hev) }
            }
            if ($classes -ge 20 -and ($short / [double]$classes) -ge 0.6) { Add-ObfNote $vp ('obfuscate edilmis (' + $short + '/' + $classes + ' sinif adi 1-2 harf)') }
            $info = ' | ' + $classes + ' class, ic ice jar: ' + $nested
        }
    } elseif (@('.exe', '.dll', '.scr', '.com') -contains $vext) {
        if ($vf.Length -gt 125829120) {
            [void]$why.Add('dosya 120 MB ustu, icerik taramasi atlandi')
        } else {
            $vb = $null
            try { $vb = [IO.File]::ReadAllBytes($vp) } catch {}
            if ($null -eq $vb) {
                [void]$why.Add('icerik OKUNAMADI')
            } else {
                $vt = [Text.Encoding]::GetEncoding(28591).GetString($vb)
                $tkh = @{}
                $bkh = @{}
                Get-Terms $vt $tkh
                Get-Brands $vt $bkh
                if ($vb.Length -lt 20971520) {
                    $vu = [Text.Encoding]::Unicode.GetString($vb)
                    Get-Terms $vu $tkh
                    Get-Brands $vu $bkh
                }
                $tk = @($tkh.Keys)
                $bk = @($bkh.Keys)
                $vJni = Has-Any $vt @('JNI_GetCreatedJavaVMs', 'GetCreatedJavaVMs', 'jvmtiEnv', 'AttachCurrentThread')
                $vMc = Has-Any $vt @('net/minecraft/client', 'net.minecraft.client', 'class_310', 'class_746', 'Lnet/minecraft/', 'net/minecraft/class_', 'com/mojang/blaze3d')
                $vInj = ((Has-Any $vt @('WriteProcessMemory')) -and (Has-Any $vt @('CreateRemoteThread', 'NtCreateThreadEx', 'RtlCreateUserThread', 'QueueUserAPC', 'SetWindowsHookEx')) -and (Has-Any $vt @('javaw', 'java.exe', 'Minecraft') $true))
                if ($vJni -and $vMc) { $sc += 40; [void]$why.Add('Minecraft sinif adlari + JNI/JVMTI: Java disindan oyuna baglanan program/DLL') }
                if ($vInj) { $sc += 45; [void]$why.Add('enjektor belirtileri (WriteProcessMemory + uzak thread + javaw/Minecraft)') }
                $pkV = Get-PackInfo $vb
                if ($pkV.Reason) { $sc += $pkV.Bonus; [void]$why.Add($pkV.Reason); Add-ObfNote $vp $pkV.Reason }
                $vsg = 'imzasiz'
                if (Test-Signed $vp) { $vsg = 'imzali' }
                $info = ' | ' + $vsg
            }
        }
    } elseif (@('.bat', '.cmd', '.ps1', '.vbs', '.txt', '.json', '.cfg', '.toml', '.yml', '.yaml', '.ini', '.conf', '.properties') -contains $vext) {
        $vtx = $null
        if ($vf.Length -le 5242880) { try { $vtx = [IO.File]::ReadAllText($vp) } catch {} }
        if ($vtx) {
            $tkh = @{}
            $bkh = @{}
            Get-Terms $vtx $tkh
            Get-Brands $vtx $bkh
            $tk = @($tkh.Keys)
            $bk = @($bkh.Keys)
        } else {
            [void]$why.Add('icerik okunamadi veya 5 MB ustu')
        }
    } else {
        [void]$why.Add('dosya turu (' + $vext + ') icerigi okunamiyor; elle ac ve bak')
    }
    if ($tk.Count -ge 3) { $sc += 40 } elseif ($tk.Count -eq 2) { $sc += 30 } elseif ($tk.Count -eq 1) { $sc += 15 }
    if ($tk.Count -gt 0) { [void]$why.Add('icerikte hile modulu stringleri (' + $tk.Count + ' adet): ' + ($tk -join ', ')) }
    if ($bk.Count -gt 0) { $sc += 20; [void]$why.Add('icerikte bilinen hile istemcisi ismi: ' + ($bk -join ', ')) }
    if ($tk.Count -gt 0 -or $bk.Count -gt 0) {
        Write-Host ('      -> ICERIK KANITI VAR: ' + $tk.Count + ' modul ismi, ' + $bk.Count + ' istemci ismi') -ForegroundColor Red
    } else {
        Write-Host '      -> isim eslesti ama icerikte modul/istemci ismi bulunamadi (obfuscate/sifreli olabilir, ya da yanlis eslesme)' -ForegroundColor Yellow
    }
    Add-F -Kaynak 'Ozel tarama (isim eslesen dosya)' -Ad ('ozel: ' + $vf.Name.ToLower()) -Yol $vp -Skor ([Math]::Min(100, $sc)) -Son $vf.LastWriteTime -Ilk $vf.CreationTime -Var 'Evet' -Not (($why -join '; ') + $info)
}
Show-Section
}
function Scan-BinHunt($bf) {
    $pth = $bf.FullName
    if ((Get-Zone $pth) -eq 'system') { return }
    if ($bf.Name.ToLower() -match $knownNat) { return }
    if ($bf.Length -gt 12582912 -and (Test-Signed $pth)) { return }
    $b = $null
    try { $b = [IO.File]::ReadAllBytes($pth) } catch { return }
    if ($null -eq $b) { return }
    $t = [Text.Encoding]::GetEncoding(28591).GetString($b)
    $isJni = Has-Any $t @('JNI_GetCreatedJavaVMs', 'GetCreatedJavaVMs', 'jvmtiEnv', 'AttachCurrentThread')
    $isMc = Has-Any $t @('net/minecraft/client', 'net.minecraft.client', 'class_310', 'class_746', 'Lnet/minecraft/', 'net/minecraft/class_', 'com/mojang/blaze3d')
    $isInj = ((Has-Any $t @('WriteProcessMemory')) -and (Has-Any $t @('CreateRemoteThread', 'NtCreateThreadEx', 'RtlCreateUserThread', 'QueueUserAPC', 'SetWindowsHookEx')) -and (Has-Any $t @('javaw', 'java.exe', 'Minecraft') $true))
    $terms = @{}
    $brands = @{}
    $mcRel = ($isJni -or $isMc -or (Has-Any $t @('minecraft', 'javaw', 'lwjgl', 'glfw', 'jvmti') $true))
    if ($b.Length -lt 4194304 -or $mcRel) {
        Get-Terms $t $terms
        Get-Brands $t $brands
        if ($b.Length -lt 8388608) {
            $tu = [Text.Encoding]::Unicode.GetString($b)
            Get-Terms $tu $terms
            Get-Brands $tu $brands
        }
    }
    $tk = @($terms.Keys)
    $bk = @($brands.Keys)
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    if ($tk.Count -ge 3) { $sc += 70 } elseif ($tk.Count -eq 2) { $sc += 50 } elseif ($tk.Count -eq 1) { $sc += 25 }
    if ($tk.Count -gt 0) { [void]$why.Add('icerikte hile modulu stringleri: ' + ($tk -join ', ')) }
    if ($bk.Count -gt 0) { $sc += 35; [void]$why.Add('icerikte bilinen hile istemcisi ismi: ' + ($bk -join ', ')) }
    if ($isJni -and $isMc) { $sc += 40; [void]$why.Add('Minecraft sinif adlari + JNI/JVMTI: Java disindan oyuna baglanan program/DLL') }
    if ($isInj) { $sc += 45; [void]$why.Add('enjektor belirtileri (WriteProcessMemory + uzak thread + javaw/Minecraft)') }
    $pk = Get-PackInfo $b
    if ($pk.Reason) { $sc += $pk.Bonus; [void]$why.Add($pk.Reason) }
    if ($sc -lt 25) { return }
    $sig = Test-Signed $pth
    if ($pk.Reason -and -not $sig) { Add-ObfNote $pth $pk.Reason }
    if ($sig -and $tk.Count -lt 3) { return }
    $sg = 'imzasiz'
    if ($sig) { $sg = 'imzali' }
    Add-F -Kaynak 'Hile avi: exe/dll icerigi' -Ad $bf.Name.ToLower() -Yol $pth -Skor ([Math]::Min(100, $sc)) -Son $bf.LastWriteTime -Ilk $bf.CreationTime -Var 'Evet' -Not (($why -join '; ') + ' | ' + $sg)
}
function Invoke-Hunt {
    Step '[AV] HILE AVI: tum sabit disklerde isim, icerik, indirme izi ve yakin zamanda gelen dosyalar (calistirilmamis dosyalar dahil)...'
    Start-Sec
    $hSw = [Diagnostics.Stopwatch]::StartNew()
    $huntCs = @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Text.RegularExpressions;
public static class HkHunt {
    public static List<string> Sweep(string root, string[] ciPats, string[] csPats, string skipDirRx, string candSkipRx, string[] exts, int maxOut) {
        List<string> res = new List<string>();
        List<Regex> ci = new List<Regex>();
        foreach (string p in ciPats) { ci.Add(new Regex(p, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)); }
        List<Regex> cs = new List<Regex>();
        foreach (string q in csPats) { cs.Add(new Regex(q, RegexOptions.CultureInvariant)); }
        Regex skip = new Regex(skipDirRx, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        Regex candSkip = new Regex(candSkipRx, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        HashSet<string> ext = new HashSet<string>(exts, StringComparer.OrdinalIgnoreCase);
        Stack<string> st = new Stack<string>();
        st.Push(root);
        while (st.Count > 0 && res.Count < maxOut) {
            string d = st.Pop();
            string[] files = null;
            string[] dirs = null;
            try { files = Directory.GetFiles(d); } catch { }
            try { dirs = Directory.GetDirectories(d); } catch { }
            if (files != null) {
                foreach (string f in files) {
                    string n = Path.GetFileName(f);
                    bool hit = false;
                    foreach (Regex r1 in ci) { if (r1.IsMatch(n)) { hit = true; break; } }
                    if (!hit) { foreach (Regex r2 in cs) { if (r2.IsMatch(n)) { hit = true; break; } } }
                    if (hit) { res.Add("N|" + f); continue; }
                    string e = Path.GetExtension(f);
                    if (e.Length > 0 && ext.Contains(e)) {
                        if (!candSkip.IsMatch(f) || f.IndexOf("\\Windows\\Temp\\", StringComparison.OrdinalIgnoreCase) >= 0) { res.Add("C|" + f); }
                    }
                }
            }
            if (dirs != null) {
                foreach (string sd in dirs) {
                    try { if ((File.GetAttributes(sd) & FileAttributes.ReparsePoint) != 0) { continue; } } catch { continue; }
                    if (skip.IsMatch(sd)) { continue; }
                    string dn = Path.GetFileName(sd);
                    bool dh = false;
                    foreach (Regex r3 in ci) { if (r3.IsMatch(dn)) { dh = true; break; } }
                    if (!dh) { foreach (Regex r4 in cs) { if (r4.IsMatch(dn)) { dh = true; break; } } }
                    if (dh) { res.Add("D|" + sd); }
                    st.Push(sd);
                }
            }
        }
        return res;
    }
}
'@
    $hOk = $false
    if ('HkHunt' -as [type]) { $hOk = $true } else {
        try { Add-Type -TypeDefinition $huntCs -Language CSharp -ErrorAction Stop; $hOk = $true } catch {}
    }
    if (-not $hOk) { Log '   HATA: hile avi tarayicisi derlenemedi.' 'Red'; return }
    if (-not ('HkJar' -as [type])) {
        try { Add-Type -TypeDefinition $jarCs -Language CSharp -ReferencedAssemblies @('System.IO.Compression', 'System.IO.Compression.FileSystem') -ErrorAction Stop } catch {}
    }
    $script:jarCsOk = [bool]('HkJar' -as [type])

    $drv = @()
    try { $drv = @(Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Where-Object { $_.DriveType -eq 3 } | ForEach-Object { [string]$_.DeviceID }) } catch {}
    if ($drv.Count -eq 0) { $drv = @([string]$env:SystemDrive) }
    $ciP = [string[]]@($script:StrongRx.ToString(), $script:ClientRx.ToString(), $script:ExtraRx.ToString(), $script:SubRx.ToString())
    $csP = [string[]]@($script:CamelRx.ToString())
    $skipDir = '(?i)\\(Windows\\(WinSxS|System32|SysWOW64|assembly|servicing|Installer|Microsoft\.NET|Fonts|Logs|Boot|Panther|diagnostics|SoftwareDistribution|Speech|InputMethod|Cursors)|\$Recycle\.Bin|System Volume Information|\$WinREAgent|Recovery|MSOCache|Config\.Msi)$'
    $candSkip = '(?i)\\(Windows|Program Files|Program Files \(x86\)|ProgramData\\Microsoft|\$Recycle\.Bin)(\\|$)'
    $exts = [string[]]@('.jar', '.zip', '.rar', '.7z', '.exe', '.dll', '.scr', '.msi', '.bat', '.cmd', '.ps1', '.vbs')
    $allLines = New-Object System.Collections.Generic.List[string]
    foreach ($dv in $drv) {
        Write-Host ('   disk taraniyor: ' + $dv + '\ (tum klasorler gezilir, birkac dakika surebilir)...') -ForegroundColor DarkGray
        $dl = $null
        try { $dl = [HkHunt]::Sweep(($dv + '\'), $ciP, $csP, $skipDir, $candSkip, $exts, 400000) } catch {}
        if ($dl) { foreach ($x in $dl) { [void]$allLines.Add($x) } }
        Write-Host ('   ' + $dv + ' bitti (' + [int]$hSw.Elapsed.TotalSeconds + ' sn, toplam ' + $allLines.Count + ' kayit)') -ForegroundColor DarkGray
    }
    $nFiles = New-Object System.Collections.Generic.List[string]
    $dDirs = New-Object System.Collections.Generic.List[string]
    $cand = New-Object System.Collections.Generic.List[string]
    foreach ($ln in $allLines) {
        if ($ln.Length -lt 3) { continue }
        $tag = $ln.Substring(0, 1)
        $pp = $ln.Substring(2)
        if ($tag -eq 'N') { [void]$nFiles.Add($pp) } elseif ($tag -eq 'D') { [void]$dDirs.Add($pp) } elseif ($tag -eq 'C') { [void]$cand.Add($pp) }
    }
    Log ('   adi hile istemcisiyle eslesen dosya: ' + $nFiles.Count + ', klasor: ' + $dDirs.Count + ', icerik/iz adayi dosya: ' + $cand.Count) 'DarkGray'

    # --- Klasor adi eslesmeleri ---
    $dN = 0
    foreach ($dp in $dDirs) {
        $dN++
        if ($dN -gt 60) { break }
        $cntTxt = ''
        try {
            $fl = [IO.Directory]::GetFiles($dp, '*', [IO.SearchOption]::AllDirectories)
            $cntTxt = ' | icinde ' + $fl.Length + ' dosya: ' + ((@($fl | Select-Object -First 4 | ForEach-Object { Split-Path -Leaf $_ })) -join ', ')
        } catch {}
        $dLeaf = Split-Path -Leaf $dp
        $dh = Get-NameHit $dLeaf $false
        $dhn = ''
        if ($dh) { $dhn = $dh.Name }
        Add-F -Kaynak 'Hile avi: klasor adi' -Ad ('klasor: ' + $dLeaf.ToLower()) -Yol $dp -Skor 55 -Var 'Evet' -Not ('klasor adi bilinen hile istemcisiyle eslesti: ' + $dhn + $cntTxt)
    }
    # --- Dosya adi eslesmeleri ---
    foreach ($np in $nFiles) {
        $nf = $null
        try { $nf = New-Object IO.FileInfo $np } catch { continue }
        $nh = Get-NameHit $nf.Name $false
        $nhn = ''
        if ($nh) { $nhn = $nh.Name }
        Add-NameDeep $np
        Add-F -Kaynak 'Hile avi: dosya adi' -Ad $nf.Name.ToLower() -Yol $np -Skor 55 -Son $nf.LastWriteTime -Ilk $nf.CreationTime -Var 'Evet' -Not ('dosya adi bilinen hile istemcisiyle eslesti: ' + $nhn)
    }
    Show-Section
    Invoke-NameDeep

    # --- Jar/zip icerik taramasi (tum diskte) ---
    Step '[AV] jar/zip icerik taramasi (tum disk, kullanici klasorleri once)...'
    Start-Sec
    $arcAll = New-Object System.Collections.Generic.List[object]
    foreach ($cp in $cand) {
        if ($cp -notmatch '(?i)\.(jar|zip)$') { continue }
        try {
            $fi = New-Object IO.FileInfo $cp
            if ($fi.Length -gt 0 -and $fi.Length -lt 157286400 -and (([int]$fi.Attributes -band 4460544) -eq 0)) { [void]$arcAll.Add($fi) }
        } catch {}
    }
    $arcSorted = @($arcAll | Sort-Object @{ Expression = { if ($_.FullName -match '(?i)\\Users\\') { 0 } else { 1 } } }, Length | Select-Object -First 1000000)
    Log ('   ' + $arcAll.Count + ' jar/zip bulundu, ' + $arcSorted.Count + ' tanesi taranacak.') 'DarkGray'
    if ($script:jarCsOk) {
        $thr = [Math]::Max(2, [Math]::Min(4, [Math]::Max(2, [int]([Environment]::ProcessorCount / 2))))
        $chN = 0
        for ($ci = 0; $ci -lt $arcSorted.Count; $ci += 24) {
            Set-Frac ($ci / [Math]::Max(1, $arcSorted.Count)) ('jar/zip ' + $ci + '/' + $arcSorted.Count)
            $hi = [Math]::Min($ci + 23, $arcSorted.Count - 1)
            $chunk = @($arcSorted[$ci..$hi])
            $paths = [string[]]@($chunk | ForEach-Object { $_.FullName })
            $res = $null
            try { $res = [HkJar]::ScanMany($paths, $script:ModTermPat, $script:BrandRx.ToString(), $script:PkgRx, 3600, $thr) } catch {}
            if ($res) {
                for ($k = 0; $k -lt $paths.Count; $k++) {
                    $x = $res[$k]
                    if (-not $x -or $x.Error -or $x.Plugin) { continue }
                    $tl = @($x.Terms)
                    $bl = @($x.Brands)
                    $sc = 0
                    $why = New-Object System.Collections.Generic.List[string]
                    if ($tl.Count -ge 3) { $sc += 70 } elseif ($tl.Count -eq 2) { $sc += 55 } elseif ($tl.Count -eq 1) { $sc += 30 }
                    if ($tl.Count -gt 0) { [void]$why.Add('icerikte hile modulu stringleri (' + $tl.Count + ' adet): ' + ($tl -join ', ')) }
                    if ($bl.Count -gt 0) { $sc += 35; [void]$why.Add('icerikte bilinen hile istemcisi ismi: ' + ($bl -join ', ')) }
                    if ($x.Pkg) { $sc += 40; [void]$why.Add('bilinen hile istemcisi paket yolu: ' + $x.Pkg) }
                    if ($x.Classes -ge 20 -and ($x.Short / [double]$x.Classes) -ge 0.6) { $sc += 25; [void]$why.Add('obfuscate edilmis gorunuyor (' + $x.Short + '/' + $x.Classes + ' sinif adi 1-2 harf)') }
                    $mh = Get-NameHit $x.Meta $false
                    if ($mh) { $sc += 40; [void]$why.Add('mod bilgisinde hile ismi: ' + $mh.Name) }
                    $cfp = $chunk[$k].FullName
                    if ($x.EncReason) { $sc += 25; [void]$why.Add($x.EncReason); Add-ObfNote $cfp $x.EncReason }
                    if ($x.BadMagic -gt 0) { $sc += 40; [void]$why.Add('class dosyalarinin ' + $x.BadMagic + ' tanesi gecersiz (sifreli olabilir)'); Add-ObfNote $cfp ('sifreli/bozuk class dosyasi: ' + $x.BadMagic) }
                    if ($x.ObfMarks.Count -gt 0) { $sc += 15; $omh = (@($x.ObfMarks) -join ', '); [void]$why.Add('obfuscator imzasi: ' + $omh); Add-ObfNote $cfp ('obfuscator imzasi: ' + $omh) }
                    if ($x.NativeLibs.Count -gt 0) { $sc += 10; $nlh = (@($x.NativeLibs) -join ', '); [void]$why.Add('jar icinde yerel kutuphane: ' + $nlh); Add-ObfNote $cfp ('jar icinde yerel kutuphane (dll/so): ' + $nlh) }
                    if ($x.HiEnt.Count -gt 0) { $sc += 15; $heh = (@($x.HiEnt) -join ', '); [void]$why.Add('yuksek entropili veri dosyasi: ' + $heh); Add-ObfNote $cfp ('yuksek entropili veri dosyasi: ' + $heh) }
                    if ($x.Classes -ge 20 -and ($x.Short / [double]$x.Classes) -ge 0.6) { Add-ObfNote $cfp ('obfuscate edilmis (' + $x.Short + '/' + $x.Classes + ' sinif adi 1-2 harf)') }
                    if ($sc -ge 25) {
                        $cf = $chunk[$k]
                        Add-F -Kaynak 'Hile avi: jar/zip icerigi' -Ad ('jar: ' + $cf.Name.ToLower()) -Yol $cf.FullName -Skor ([Math]::Min(100, $sc)) -Son $cf.LastWriteTime -Ilk $cf.CreationTime -Var 'Evet' -Not (($why -join '; ') + ' | NOT: sifreli/agir obfuscation kullanan hilelerde class stringleri gorunmez')
                    }
                }
            }
            $chN++
            if (($chN % 10) -eq 0) { Write-Host ('   jar/zip ilerleme: ' + [Math]::Min($ci + 24, $arcSorted.Count) + '/' + $arcSorted.Count + ' (' + [int]$hSw.Elapsed.TotalSeconds + ' sn)') -ForegroundColor DarkGray }
        }
    } else {
        Log '   jar tarayici derlenemedi, jar/zip icerik taramasi atlandi.' 'DarkYellow'
    }
    foreach ($cp in $cand) {
        if ($cp -notmatch '(?i)\.(rar|7z)$') { continue }
        $er = ''
        try { $er = [HkJar]::EncInfo($cp) } catch {}
        if ($er) {
            Add-ObfNote $cp $er
            Add-F -Kaynak 'Hile avi: sifreli arsiv' -Ad ('arsiv: ' + (Split-Path -Leaf $cp).ToLower()) -Yol $cp -Skor 35 -Var 'Evet' -Not ($er + ' | icerigi okunamadi, elle ac ve bak')
        }
    }
    Show-Section

    # --- exe/dll icerik taramasi (kullanici klasorleri once, kucuk dosyalar once) ---
    Step '[AV] exe/dll icerik taramasi (tum disk, sistem klasorleri haric)...'
    Start-Sec
    $binAll = New-Object System.Collections.Generic.List[object]
    foreach ($cp in $cand) {
        if ($cp -notmatch '(?i)\.(exe|dll|scr)$') { continue }
        try {
            $fi = New-Object IO.FileInfo $cp
            if ($fi.Length -gt 4096 -and $fi.Length -lt 31457280) { [void]$binAll.Add($fi) }
        } catch {}
    }
    $binSorted = @($binAll | Sort-Object @{ Expression = { if ($_.FullName -match '(?i)\\Users\\') { 0 } else { 1 } } }, Length)
    Log ('   ' + $binSorted.Count + ' exe/dll adayi (sure siniri yok, hepsi taranir).') 'DarkGray'
    $bSw = [Diagnostics.Stopwatch]::StartNew()
    $bI = 0
    foreach ($bf in $binSorted) {
        $bI++
        if (($bI % 50) -eq 0) { Set-Frac ($bI / [Math]::Max(1, $binSorted.Count)) ('exe/dll ' + $bI + '/' + $binSorted.Count) }
        if (($bI % 200) -eq 0) { Write-Host ('   exe/dll ilerleme: ' + $bI + '/' + $binSorted.Count + ' (' + [int]$bSw.Elapsed.TotalSeconds + ' sn)') -ForegroundColor DarkGray }
        try { Scan-BinHunt $bf } catch {}
    }
    Show-Section

    # --- Indirme izi (Zone.Identifier), yakin zamanda gelen dosyalar, arsiv programi gecmisi ---
    Step '[AV] indirme izi (Zone.Identifier), son 60 gunde gelen dosyalar ve WinRAR/7-Zip gecmisi...'
    Start-Sec
    $dlHostRx = '(?i)cdn\.discordapp\.com/attachments|media\.discordapp\.net/attachments|mega\.nz|mediafire\.com|gofile\.io|pixeldrain\.com|anonfiles|transfer\.sh|workupload\.com|file\.io|catbox\.moe|dropbox\.com|drive\.google\.com|sendspace\.com|1fichier\.com|t\.me|telegram'
    $recentRows = New-Object System.Collections.Generic.List[object]
    $zChecked = 0
    $cutoff = (Get-Date).AddDays(-60)
    foreach ($cp in $cand) {
        if ($cp -notmatch '(?i)\\Users\\') { continue }
        if ($cp -notmatch '(?i)\.(jar|zip|rar|7z|exe|dll|msi|bat|cmd|ps1|vbs|scr)$') { continue }
        $fi = $null
        try { $fi = New-Object IO.FileInfo $cp } catch { continue }
        $newest = $fi.CreationTime
        if ($fi.LastWriteTime -gt $newest) { $newest = $fi.LastWriteTime }
        $srcUrl = ''
        if ($zChecked -lt 5000) {
            $zChecked++
            $zi = $null
            try { $zi = @(Get-Content -LiteralPath $cp -Stream Zone.Identifier -ErrorAction Stop) } catch {}
            foreach ($zl in @($zi)) { if ($zl -and ($zl -match '^(HostUrl|ReferrerUrl)=(.+)$')) { $srcUrl = $srcUrl + ' ' + $Matches[2] } }
        }
        $srcUrl = $srcUrl.Trim()
        if ($srcUrl) {
            $zh = Get-NameHit ($srcUrl + ' ' + $fi.Name) $false
            if ($zh) {
                Add-F -Kaynak 'Hile avi: indirme kaynagi (Zone.Identifier)' -Ad $fi.Name.ToLower() -Yol $cp -Skor 50 -Son $fi.LastWriteTime -Ilk $fi.CreationTime -Var 'Evet' -Not ('indirildigi adres: ' + $srcUrl + ' | hile ismi: ' + $zh.Name)
            } elseif ($srcUrl -match $dlHostRx -and ($IntExt -contains $fi.Extension.ToLower())) {
                Add-F -Kaynak 'Hile avi: indirme kaynagi (Zone.Identifier)' -Ad $fi.Name.ToLower() -Yol $cp -Skor 30 -Son $fi.LastWriteTime -Ilk $fi.CreationTime -Var 'Evet' -Not ('dosya paylasim/sohbet sitesinden indirilmis kod/arsiv dosyasi: ' + $srcUrl + ' (hile dagitiminda sik kullanilir ama mesru dosyalar da olabilir)')
            }
        }
        if ($newest -gt $cutoff) { [void]$recentRows.Add([pscustomobject]@{ T = $newest; Yol = $cp; Boyut = $fi.Length; Kaynak = $srcUrl }) }
    }
    $hist = New-Object System.Collections.Generic.List[string]
    foreach ($rk in @('HKCU:\Software\WinRAR\ArcHistory', 'HKCU:\Software\WinRAR\DialogEditHistory\ExtrPath')) {
        try {
            $k = Get-Item -LiteralPath $rk -ErrorAction Stop
            foreach ($vn in $k.GetValueNames()) { Add-HistVals ($k.GetValue($vn)) $hist }
        } catch {}
    }
    foreach ($rv in @(@('HKCU:\Software\7-Zip\FM', 'FolderHistory'), @('HKCU:\Software\7-Zip\FM', 'PanelPath0'), @('HKCU:\Software\7-Zip\FM', 'PanelPath1'), @('HKCU:\Software\7-Zip\Extraction', 'PathHistory'), @('HKCU:\Software\7-Zip\Compression', 'ArcHistory'))) {
        try {
            $pr = Get-ItemProperty -LiteralPath $rv[0] -Name $rv[1] -ErrorAction Stop
            Add-HistVals ($pr.($rv[1])) $hist
        } catch {}
    }
    $hSeen = @{}
    $hShown = 0
    Log '' 'Gray'
    Log 'WinRAR/7-Zip gecmisinde gecen yollar (arsiv acilmis/cikarilmis olabilir):' 'Cyan'
    foreach ($hp in $hist) {
        $hk = $hp.ToLower()
        if ($hSeen.ContainsKey($hk)) { continue }
        $hSeen[$hk] = 1
        $hEx = $true
        if ($hp -match '^[A-Za-z]:\\') { $hEx = [bool](Test-Path -LiteralPath $hp) }
        $hh = Get-NameHit $hp $false
        $hTxt = ''
        if (-not $hEx) { $hTxt = '   (ARTIK YOK)' }
        if ($hShown -lt 40) { Log ('   ' + $hp + $hTxt) 'Gray'; $hShown++ }
        if ($hh) {
            Add-F -Kaynak 'Hile avi: arsiv programi gecmisi' -Ad ('gecmis: ' + $hp.ToLower()) -Yol $hp -Skor 50 -Var 'Evet' -Not ('WinRAR/7-Zip gecmisinde hile ismi: ' + $hh.Name)
        }
    }
    if ($hShown -eq 0) { Log '   (kayit yok)' 'DarkGray' }
    $recSorted = @($recentRows | Sort-Object T -Descending | Select-Object -First 80)
    Log '' 'Gray'
    Log ('SON 60 GUNDE kullanici klasorlerine gelen/degisen kod ve arsiv dosyalari (' + $recentRows.Count + ' adet, en yenisinden ilk ' + $recSorted.Count + ') - tanidik bir dosya var mi bak:') 'Cyan'
    foreach ($rr in $recSorted) {
        $szMb = [Math]::Round($rr.Boyut / 1048576, 1)
        $ln2 = '   ' + (Fmt $rr.T) + '  ' + $szMb + ' MB  ' + $rr.Yol
        if ($rr.Kaynak) { $ln2 = $ln2 + '   <- ' + $rr.Kaynak }
        Log $ln2 'Gray'
    }
    Show-Section
    Log '' 'Gray'
    Show-ObfSummary
    Log ('HILE AVI bitti: ' + [int]$hSw.Elapsed.TotalSeconds + ' sn.') 'Cyan'
    Close-Bar
    if ($script:TitleOk -and $Av) { [HkTitle]::Done = $true; [HkTitle]::Tick() }
}
if ($Av) {
    Invoke-Hunt
    Log '' 'Gray'
    if ($PSCommandPath) { Read-Host 'Kapatmak icin Enter a bas' | Out-Null }
    return
}

# USN gunlugu okumalari simdi arka planda baslar (adim 2 sonucu bekler)
foreach ($ubDl in $script:FixedNtfs) { Start-UsnBg $ubDl }

# ---------------------------------------------------------------------
Step '[1/17] BYPASS TESPITI - iz saklama/temizleme, servis ve ayar durumlari...'
Start-Sec
$pfDir = $env:WINDIR + '\Prefetch'
$pfFiles = @()
try { $pfFiles = @(Get-ChildItem -LiteralPath $pfDir -Filter '*.pf' -Force -ErrorAction Stop) } catch {}
$pfReg = $null
try { $pfReg = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' -ErrorAction Stop).EnablePrefetcher } catch {}
if ($pfReg -eq 0) { Add-Sys 'Prefetch KAPATILMIS' 45 'EnablePrefetcher=0: Windows program calistirma kaydi tutmuyor (iz saklama girisimi olabilir).' }
if ($pfFiles.Count -eq 0) {
    Add-Sys 'Prefetch klasoru bos veya okunamadi' 40 'Normalde yuzlerce .pf dosyasi olur. Bos ise temizlenmis olabilir.'
} elseif ($pfFiles.Count -lt 20) {
    Add-Sys ('Prefetch klasorunde sadece ' + $pfFiles.Count + ' kayit var') 35 'Normalde cok daha fazla olur; yakin zamanda temizlenmis olabilir.'
} else {
    $oldest = ($pfFiles | Sort-Object CreationTime | Select-Object -First 1).CreationTime
    Log ('   Prefetch: ' + $pfFiles.Count + ' kayit, en eskisi: ' + (Fmt $oldest)) 'DarkGray'
}
Check-Service 'SysMain' 'Bu servis (eski adiyla Superfetch) Prefetch verisiyle iliskilidir; kapatilmasi iz saklama girisimi olabilir.' 40 30
Check-Service 'PcaSvc' 'Program Compatibility Assistant, calistirilan programlarla ilgili ek kayit tutar.' 35 15
Check-Service 'DPS' 'Diagnostic Policy Service - tanilama ve bazi kayit mekanizmalari buna baglidir.' 35 20
Check-Service 'EventLog' 'Windows Olay Gunlugu servisinin kendisi; kapaliysa hicbir olay kaydedilmez.' 60 50
Check-Service 'bam' 'BAM (Background Activity Moderator) - programlarin son calistirma zamanini tutar.' 45 30
Check-Service 'WinDefend' 'Windows Defender antivirus motoru.' 45 35
Check-Service 'WdNisSvc' 'Windows Defender ag denetimi.' 25 15
Check-Service 'Sense' 'Windows Defender gelismis tehdit koruma servisi.' 20 10
Check-Service 'wscsvc' 'Windows Guvenlik Merkezi servisi; antivirus/guvenlik duvarinin durumunu bildirir.' 30 20
Check-Service 'Appinfo' 'Uygulama Bilgisi servisi; yonetici izni isteyen programlarla ilgili kayit tutar.' 25 15
Check-Service 'mpssvc' 'Windows Guvenlik Duvari servisi.' 35 25
Check-Service 'Dnscache' 'DNS Istemci (Dnscache) servisi; hangi sitelere baglanildigina dair DNS onbellegini tutar.' 25 15
Check-Service 'BFE' 'Taban Filtre Motoru (BFE); guvenlik duvari kurallarini uygular, kapatilmasi tehlikeli.' 40 30
Check-Service 'DiagTrack' 'Baglanti Kullanici Deneyimleri ve Telemetri servisi.' 15 10
Check-Service 'WSearch' 'Windows Arama (SearchIndexer) servisi; dosya indeksleme ve arama gecmisini tutar.' 20 12

# --- Prefetch/Superfetch parametreleri (acik/kapali + en son elle degistirilme zamani) ---
Check-RegFlag 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' 3 'Prefetch (EnablePrefetcher) beklenenden farkli' 'Program calistirma onbellegi ayari degistirilmis (normal: 2 veya 3).' 40
Check-RegFlag 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnableSuperfetch' 3 'Superfetch ayari beklenenden farkli' 'Superfetch/SysMain onbellek ayari degistirilmis.' 25

# --- USN gunlugu / degisiklik gunlugu izleme ayari ---
try {
    $nlu = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name NtfsDisableLastAccessUpdate -ErrorAction Stop).NtfsDisableLastAccessUpdate
    if ($nlu -eq 1) { Add-Sys 'Dosya erisim zamani guncellemesi elle KAPATILMIS' 20 'NtfsDisableLastAccessUpdate=1 (kullanici yonetimli). Windows varsayilani (sistem yonetimli) bu degildir ama performans icin kapatan cok kisi vardir; tek basina suphe degil.' }
} catch {}

# --- PowerShell komut/script kaydi (loglama) ---
Check-RegFlag 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' 'EnableScriptBlockLogging' 1 'PowerShell ScriptBlock loglama KAPALI' 'PowerShell komutlarinin kaydi tutulmuyor; script tabanli islemler iz birakmaz.' 20

# --- Windows Defender kapatma bayraklari (grup ilkesi seviyesinde) ---
Check-RegFlag 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableAntiSpyware' 0 'Windows Defender grup ilkesiyle KAPATILMIS' 'Antivirus grup ilkesi (registry) uzerinden devre disi birakilmis.' 55
Check-RegFlag 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection' 'DisableRealtimeMonitoring' 0 'Windows Defender aninda koruma KAPALI (registry)' 'Gercek zamanli tarama registry uzerinden kapatilmis.' 45

# --- Denetim (audit) ilkesi: nesne erisimi/sistem olaylari izleniyor mu ---
try {
    $apOut = & auditpol.exe /get /subcategory:"File System" 2>&1 | Out-String
    if ($apOut -match '(?i)No Auditing') { Add-Sys 'Dosya sistemi denetimi (audit) KAPALI' 15 'Dosya erisim/degisiklik olaylari Olay Gunlugune yazilmiyor (varsayilan zaten kapali olabilir).' }
} catch {}

# --- Zamanlanmis gorevler: log/prefetch/iz temizleyen komutlar iceren gorev var mi ---
$taskRoot = $env:WINDIR + '\System32\Tasks'
$cleanRx = '(?i)wevtutil\s+(cl|clear-log)|fsutil\s+usn\s+deletejournal|cipher\s*/w|del\s+/f.*prefetch|Clear-EventLog|Remove-Item.*Prefetch'
if (Test-Path -LiteralPath $taskRoot) {
    foreach ($tf in @(Get-ChildItem -LiteralPath $taskRoot -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        $ttxt = ''
        try { $ttxt = Get-Content -LiteralPath $tf.FullName -Raw -ErrorAction Stop } catch {}
        if ($ttxt -and ($ttxt -match $cleanRx)) {
            Add-Sys ('Zamanlanmis gorev iz temizliyor: ' + $tf.Name) 45 'Bu gorev calistiginda log/prefetch/USN temizleme komutu iceriyor.' $tf.LastWriteTime ('gorev dosyasi: ' + $tf.FullName) $tf.LastWriteTime
        }
    }
}

# --- hosts dosyasi: yakin zamanda elle degistirilmis mi (anticheat/telemetri engelleme icin kullanilabilir) ---
$hostsPath = $env:WINDIR + '\System32\drivers\etc\hosts'
if (Test-Path -LiteralPath $hostsPath) {
    $hf = Get-Item -LiteralPath $hostsPath
    $hlines = @(Get-Content -LiteralPath $hostsPath -ErrorAction SilentlyContinue | Where-Object { $_ -and ($_.TrimStart() -notmatch '^#') })
    if ($hlines.Count -gt 5 -or ($hf.LastWriteTime -gt (Get-Date).AddDays(-30) -and $hlines.Count -gt 0)) {
        Add-Sys 'hosts dosyasi degistirilmis' 20 'Sistemin hosts dosyasinda ozel yonlendirme/engelleme kayitlari var (bazi hileler/anticheat atlatma araclari bunu kullanir).' $null ($hlines.Count.ToString() + ' ozel satir') $hf.LastWriteTime
    }
}
foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 1102 } -MaxEvents 5 -ErrorAction SilentlyContinue)) {
    Add-Sys 'Guvenlik olay gunlugu TEMIZLENMIS' 50 'Windows olay kaydi (Event 1102) silinmis.' $e.TimeCreated 'temizlenme zamani asagida' $e.TimeCreated
}
foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 104 } -MaxEvents 5 -ErrorAction SilentlyContinue)) {
    Add-Sys 'Sistem olay gunlugu TEMIZLENMIS' 50 'Windows olay kaydi (Event 104) silinmis.' $e.TimeCreated 'temizlenme zamani asagida' $e.TimeCreated
}
foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1102 } -MaxEvents 5 -ErrorAction SilentlyContinue)) {
    Add-Sys 'Uygulama olay gunlugu TEMIZLENMIS' 45 'Windows olay kaydi (Event 1102) Uygulama gunlugunde silinmis.' $e.TimeCreated 'temizlenme zamani asagida' $e.TimeCreated
}
foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 3079 } -MaxEvents 5 -ErrorAction SilentlyContinue)) {
    Add-Sys 'Olay Gunlugu TEMIZLENMIS (3079)' 40 'Olay Goruntuleyicisi uzerinden bir log elle temizlenmis (Event 3079).' $e.TimeCreated 'temizlenme zamani asagida' $e.TimeCreated
}
# --- NTFS Operational log: USN Journal silinip yeniden olusturulmus mu (Event 501 tekrarlari = journal bypass) ---
try {
    $ntfsOp = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Ntfs/Operational'; Id = 501 } -MaxEvents 20 -ErrorAction Stop)
    if ($ntfsOp.Count -ge 2) {
        Add-Sys ('USN Journal olayi (501) birden fazla kayitli (' + $ntfsOp.Count + ' kayit)') 15 'NTFS Operational logunda 501 olayi tekrar ediyor. Journal silinip yeniden olusturulmus olabilir ama Windows guncellemeleri, disk araclari ve harici/sanal diskler de bunu uretebilir; TEK BASINA KANIT DEGIL, olay zamanini Olay Goruntuleyicisinde kontrol et.' $ntfsOp[0].TimeCreated ('en son: ' + (Fmt $ntfsOp[0].TimeCreated)) $ntfsOp[0].TimeCreated
    }
} catch {}

# --- Prefetch dosya nitelikleri: Salt Okunur/Gizli yapilmis mi (Prefetch'in kaydetmesini engelleme yontemi) ---
$pfAttrBad = 0
$pfAttrExample = ''
foreach ($pf in $pfFiles) {
    if (($pf.Attributes -band [IO.FileAttributes]::ReadOnly) -or ($pf.Attributes -band [IO.FileAttributes]::Hidden)) {
        $pfAttrBad++
        if (-not $pfAttrExample) { $pfAttrExample = $pf.Name + ' (' + $pf.Attributes + ')' }
    }
}
if ($pfAttrBad -gt 0) {
    Add-Sys ('Prefetch dosyalarinda Salt Okunur/Gizli nitelik bulundu (' + $pfAttrBad + ' dosya)') 45 'Prefetch dosyasi Salt Okunur/Gizli yapilarak Windows''in yeni kayit yazmasi engellenebilir.' $null $pfAttrExample
}

# --- CMD AutoRun: her CMD acilista otomatik calisan komut (ozellikle kendini kapatan) ---
foreach ($arPath in @('HKLM:\SOFTWARE\Microsoft\Command Processor', 'HKCU:\SOFTWARE\Microsoft\Command Processor')) {
    try {
        $ar = (Get-ItemProperty -LiteralPath $arPath -Name AutoRun -ErrorAction Stop).AutoRun
        if ($ar) {
            $sc2 = 25
            if ($ar -match '(?i)taskkill|cmd\.exe.*\/f|cmd\.exe.*kill') { $sc2 = 50 }
            Add-Sys ('CMD AutoRun tanimli (' + $arPath + ')') $sc2 'CMD her acildiginda otomatik calisan bir komut var; CMD''yi kapatmak icin kullanilmis olabilir.' $null $ar
        }
    } catch {}
}

# --- CMD renk gizleme: yazi rengi = arka plan rengi (yazilanlari gizleme yontemi) ---
try {
    $cons = Get-ItemProperty -LiteralPath 'HKCU:\Console' -ErrorAction Stop
    if ($null -ne $cons.ScreenColors -and $null -ne $cons.PopupColors) {
        $fg = $cons.ScreenColors -band 0x0F
        $bg = ($cons.ScreenColors -band 0xF0) -shr 4
        if ($fg -eq $bg) {
            Add-Sys 'CMD yazi rengi arka plan rengiyle AYNI' 40 'Komut isterinde yazilanlar gorunmuyor olabilir (renk gizleme yontemi).' $null ('ScreenColors=0x' + [Convert]::ToString($cons.ScreenColors, 16))
        }
    }
    if ($null -ne $cons.ForceV2 -and $cons.ForceV2 -eq 0) {
        Add-Sys 'CMD eski konsol modunda (Legacy Console)' 20 'Kopyala/yapistir ve bazi ozellikler kapatilmis olabilir (eski konsol moduna alinarak).' $null 'ForceV2=0'
    }
} catch {}

# --- Internet Secenekleri Yasakli Siteler: anticheat/ss-tool sitelerini engelleme (indirme bypass) ---
try {
    $zoneRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains'
    if (Test-Path -LiteralPath $zoneRoot) {
        $domains = New-Object System.Collections.Generic.List[string]
        foreach ($d in @(Get-ChildItem -LiteralPath $zoneRoot -ErrorAction SilentlyContinue)) {
            $sub = Get-ItemProperty -LiteralPath $d.PSPath -ErrorAction SilentlyContinue
            $hasRestricted = $false
            foreach ($p in $sub.PSObject.Properties) { if ($p.Name -notmatch '^PS' -and $p.Value -eq 4) { $hasRestricted = $true } }
            if ($hasRestricted) { [void]$domains.Add($d.PSChildName) }
            foreach ($d2 in @(Get-ChildItem -LiteralPath $d.PSPath -ErrorAction SilentlyContinue)) {
                $sub2 = Get-ItemProperty -LiteralPath $d2.PSPath -ErrorAction SilentlyContinue
                foreach ($p in $sub2.PSObject.Properties) { if ($p.Name -notmatch '^PS' -and $p.Value -eq 4) { [void]$domains.Add($d2.PSChildName + '.' + $d.PSChildName) } }
            }
        }
        if ($domains.Count -gt 0) {
            Add-Sys ('Internet Secenekleri Yasakli Siteler listesinde ' + $domains.Count + ' adres var') 25 'Bazi web siteleri "Yasakli Siteler" bolgesine eklenerek erisimi/indirmeyi engellemek icin kullanilabilir (anticheat/takip sitelerini engellemek gibi); listeyi elle kontrol et.' $null (($domains | Select-Object -First 5) -join ', ')
        }
    }
} catch {}
try {
    $mp = Get-MpPreference -ErrorAction Stop
    foreach ($x in @($mp.ExclusionPath)) {
        if ($x) {
            $z = Get-Zone $x
            if ($z -eq 'user' -or $z -eq 'temp' -or $x -match $script:LauncherRx -or $x -match '(?i)mods') { Add-Sys ('Defender dislama (klasor): ' + $x) 45 'Antivirus bu klasoru taramiyor; hile dosyalarini saklamak icin kullanilabilir.' } else { Add-Sys ('Defender dislama (klasor): ' + $x) 20 'Antivirus bu klasoru taramiyor.' }
        }
    }
    foreach ($x in @($mp.ExclusionProcess)) { if ($x) { Add-Sys ('Defender dislama (process): ' + $x) 35 'Antivirus bu programi taramiyor.' } }
    foreach ($x in @($mp.ExclusionExtension)) { if ($x) { Add-Sys ('Defender dislama (uzanti): ' + $x) 40 'Bu uzantili dosyalar taranmiyor.' } }
} catch {}
foreach ($pair in @(@('LGHUB', ($env:LOCALAPPDATA + '\LGHUB')), @('Razer Synapse', ($env:LOCALAPPDATA + '\Razer')), @('Bloody7', ($env:APPDATA + '\Bloody7')), @('SteelSeries', ($env:PROGRAMDATA + '\SteelSeries')))) {
    if (Test-Path -LiteralPath $pair[1]) { Add-Sys ('Fare/klavye yazilimi var: ' + $pair[0]) 15 'Makro/autoclick profili tanimlanmis olabilir (bu script profil icerigini okuyamaz).' (Get-Item -LiteralPath $pair[1]).LastWriteTime }
}
Show-Section

# ---------------------------------------------------------------------
Step '[2/17] Geri donusum kutusu ve USN gunlugu (silinen dosyalar, silinme zamanlari)...'
Start-Sec
foreach ($dl in $script:Drives) {
    $bin = $dl + '\$Recycle.Bin'
    if (-not (Test-Path -LiteralPath $bin)) { continue }
    $total = 0
    $latestDirChange = $null
    foreach ($sd in @(Get-ChildItem -LiteralPath $bin -Force -Directory -ErrorAction SilentlyContinue)) {
        if (-not $latestDirChange -or $sd.LastWriteTime -gt $latestDirChange) { $latestDirChange = $sd.LastWriteTime }
        foreach ($fi in @(Get-ChildItem -LiteralPath $sd.FullName -Force -Filter '$I*' -File -ErrorAction SilentlyContinue)) {
            try {
                $b = [IO.File]::ReadAllBytes($fi.FullName)
                if ($b.Length -lt 28) { continue }
                $ver = [BitConverter]::ToInt64($b, 0)
                $del = Ft ([BitConverter]::ToInt64($b, 16))
                $orig = ''
                if ($ver -eq 2) {
                    $plen = [BitConverter]::ToInt32($b, 24)
                    $take = [Math]::Min($plen * 2, $b.Length - 28)
                    $orig = [Text.Encoding]::Unicode.GetString($b, 28, $take).TrimEnd([char]0)
                } else {
                    $orig = [Text.Encoding]::Unicode.GetString($b, 24, $b.Length - 24).TrimEnd([char]0)
                }
                $rname = '$R' + $fi.Name.Substring(2)
                $still = Test-Path -LiteralPath (Join-Path $sd.FullName $rname)
                $total++
                [void]$script:BinItems.Add([pscustomobject]@{ Surucu = $dl; Orijinal = $orig; Silinme = $del; Kutuda = $still })
                $leaf = ''
                try { $leaf = Split-Path -Leaf $orig } catch {}
                if ($leaf) {
                    $bext = ''
                    try { $bext = [IO.Path]::GetExtension($leaf).ToLower() } catch {}
                    $bh = Get-NameHit $leaf $true
                    $bsc = 0
                    if ($bh) { $bsc += (Name-Score $bh $true) }
                    if (@('.exe', '.jar', '.rar', '.zip', '.7z', '.bat', '.ps1', '.scr') -contains $bext) { $bsc += 30 }
                    if ($bsc -ge 20) {
                        $bpi = Test-PathInfo $orig
                        $bvar = 'Hayir'
                        if ($bpi.Exists) { $bvar = 'Evet' }
                        $bnote = 'geri donusum kutusunda'
                        if (-not $still) { $bnote = 'geri donusum kutusu kaydi var ama dosya artik yok (kutu bosaltilmis)' }
                        Add-F -Kaynak 'Geri donusum kutusu' -Ad $leaf.ToLower() -Yol $orig -Skor ([Math]::Min(100, $bsc)) -Var $bvar -Silinme $del -Not $bnote -Benign ($bh -eq $null -and $leaf -match $script:BenignRx)
                    }
                }
            } catch {}
        }
    }
    if ($total -gt 0) { [void]$script:BinState.Add($dl + ' geri donusum kutusunda su an ' + $total + ' kayit var.') } else { [void]$script:BinState.Add($dl + ' geri donusum kutusu su an BOS.') }
    if ($latestDirChange) { [void]$script:BinState.Add('   ' + $dl + ' kutu klasoru son degisiklik: ' + (Fmt $latestDirChange) + ' (kutu bossa: yaklasik en son bosaltma/silme zamani)') }
}
foreach ($dl in $script:FixedNtfs) {
    & fsutil usn queryjournal $dl 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Stop-UsnBg $dl
        Add-Sys ('USN gunlugu YOK/silinmis: ' + $dl) 45 'USN gunlugu dosya silme/degistirme kayitlarini tutar; silinmis olmasi iz temizleme girisimi olabilir (fsutil usn deletejournal).'
        continue
    }
    Log ('   USN gunlugu okunuyor: ' + $dl + ' (biraz surebilir)...') 'DarkGray'
    $n = Read-Usn $dl
    Log ('   ' + $dl + ' : ' + $n + ' ilgili silme kaydi bulundu.') 'DarkGray'
}

# --- Silinen Prefetch (.pf) dosyalari: Prefetch'in kendisi veya java/javaw calisma kaydi silinmis mi ---
if ($script:DeletedPf.Count -gt 0) {
    $javaPf = @($script:DeletedPf | Where-Object { $_.Ad -match '(?i)^JAVA(W)?\.EXE' })
    $otherPf = @($script:DeletedPf | Where-Object { $_.Ad -notmatch '(?i)^JAVA(W)?\.EXE' })
    if ($javaPf.Count -gt 0) {
        $jp = $javaPf | Sort-Object Zaman -Descending | Select-Object -First 1
        $jpList = (($javaPf | Sort-Object Zaman -Descending | Select-Object -First 5 | ForEach-Object { $_.Ad + ' (' + (Fmt $_.Zaman) + ')' }) -join '; ')
        Add-Sys ('JAVA/JAVAW Prefetch kaydi SILINMIS (' + $javaPf.Count + ' adet)') 55 'java.exe veya javaw.exe icin Windows''in tuttugu calisma kaydi (Prefetch) elle silinmis; Minecraft/java calistirma gecmisini gizlemek icin kullanilan bir yontemdir.' $jp.Zaman $jpList
    }
    if ($otherPf.Count -gt 0) {
        $op = $otherPf | Sort-Object Zaman -Descending | Select-Object -First 1
        $opList = (($otherPf | Sort-Object Zaman -Descending | Select-Object -First 5 | ForEach-Object { $_.Ad + ' (' + (Fmt $_.Zaman) + ')' }) -join '; ')
        Add-Sys ('Prefetch (.pf) dosyasi SILINMIS (' + $otherPf.Count + ' adet)') 35 'Bir programin calisma kaydi (Prefetch dosyasi) elle silinmis; o programin calistirildigi izi gizlemek icin kullanilabilir.' $op.Zaman $opList
    }
}
Show-Section

# ---------------------------------------------------------------------
Step '[3/17] Calisan process, Java komut satiri, overlay pencereleri...'
Start-Sec
$procs = @(Get-CimInstance Win32_Process)
$SysNames = @('svchost', 'csrss', 'lsass', 'winlogon', 'services', 'smss', 'wininit', 'explorer', 'dllhost', 'conhost', 'taskhostw', 'sihost', 'RuntimeBroker', 'fontdrvhost', 'spoolsv', 'ctfmon', 'audiodg', 'dwm')
$ToolRx = '(?i)^(cheatengine|processhacker|systeminformer|x64dbg|x32dbg|ollydbg|extremeinjector|xenos|injector|dnspy|reclass|autohotkey|autoclick|tinytask|jitbit)'
foreach ($pr in $procs) {
    $pn = $pr.Name
    if (-not $pn) { continue }
    $base = [IO.Path]::GetFileNameWithoutExtension($pn)
    $pp = [string]$pr.ExecutablePath
    $isJava = ($pn -ieq 'javaw.exe' -or $pn -ieq 'java.exe')
    if (-not $isJava -and $pp -match '(?i)^[A-Za-z]:\\Windows\\' -and -not ($SysNames -contains $base)) { continue }
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    if ($pp -and ($SysNames -contains $base)) {
        # Yol karsilastirmasi: \??\ oneki, / ayiraci, kisa 8.3 adlar ve buyuk/kucuk harf farklari duzeltilir
        $ppn = $pp.Trim().Trim('"') -replace '^\\\?\?\\', ''
        $ppn = $ppn -replace '/', '\'
        try { $ppn = [IO.Path]::GetFullPath($ppn) } catch {}
        $winDir = [string]$env:SystemRoot
        if (-not $winDir) { $winDir = 'C:\Windows' }
        $inWin = $ppn.StartsWith($winDir.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
        if (-not $inWin) {
            # Windows klasorunde degil: Microsoft imzali degilse taklit say
            if (-not (Test-Signed $pp)) {
                $sc += 65; [void]$why.Add('sistem process ismi taklidi (Windows klasorunde degil ve imzasiz)')
            }
        }
    }
    $hit = Get-NameHit $pn $true
    if ($hit) { $ns = Name-Score $hit $true; if ($ns -gt 0) { $sc += $ns; [void]$why.Add('isim eslesmesi: ' + $hit.Name) } }
    if ($base -match $ToolRx) { $sc += 40; [void]$why.Add('hile/enjeksiyon/makro araci ismi') }
    if ($pp -and ($pp -match '(?i)\\Users\\[^\\]+\\(Downloads|Desktop|Documents)\\|\\Temp\\|\\Users\\Public\\')) {
        $sc += 25; [void]$why.Add('kullanici/temp klasorunden calisiyor')
        if (-not (Test-Signed $pp)) { $sc += 15; [void]$why.Add('imzasiz') }
    }
    if ($sc -ge 20) {
        Add-F -Kaynak 'Calisan process' -Ad $pn.ToLower() -Yol $pp -Skor ([Math]::Min(100, $sc)) -Son $pr.CreationDate -Var 'Evet' -Not (($why -join '; ') + ' | PID ' + $pr.ProcessId)
    }
    if ($isJava) {
        $cl = [string]$pr.CommandLine
        $gd = ''
        if ($cl -match '--gameDir\s+(?:"([^"]+)"|(\S+))') { $gd = $Matches[1]; if (-not $gd) { $gd = $Matches[2] } }
        if ($gd) { [void]$script:GameDirs.Add($gd) }
        [void]$script:JavaInfo.Add(('Java PID ' + $pr.ProcessId + ' (basladi: ' + (Fmt $pr.CreationDate) + ') oyun klasoru: ' + $(if ($gd) { $gd } else { 'bilinmiyor' })))
        foreach ($am in [regex]::Matches($cl, '-javaagent:(?:"([^"]+)"|([^\s"]+))')) {
            $ap = $am.Groups[1].Value
            if (-not $ap) { $ap = $am.Groups[2].Value }
            $eq = $ap.IndexOf('=')
            if ($eq -gt 0) { $ap = $ap.Substring(0, $eq) }
            $asc = 30
            $anote = '-javaagent ile yuklenmis (oyuna dis kod yukler; Lunar/Badlion gibi launcher''lar da kullanir)'
            $ah = Get-NameHit $ap $false
            if ($ah) { $asc += 35; $anote = $anote + ' | isim: ' + $ah.Name }
            $api = Test-PathInfo $ap
            $avar = 'Hayir'
            if ($api.Exists) { $avar = 'Evet' }
            Add-F -Kaynak 'Java komut satiri' -Ad ('javaagent: ' + (Split-Path -Leaf $ap).ToLower()) -Yol $ap -Skor $asc -Son $pr.CreationDate -Var $avar -Not $anote
        }
        foreach ($fl in @('-Xbootclasspath', '-agentpath', '-agentlib', '-noverify', '-Xverify:none', '-Djdk.attach.allowAttachSelf')) {
            if ($cl.IndexOf($fl, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                Add-F -Kaynak 'Java komut satiri' -Ad ('javaparam: ' + $fl) -Yol ('PID ' + $pr.ProcessId) -Skor 35 -Son $pr.CreationDate -Var 'Evet' -Not ('Java baslatma parametresi: ' + $fl + ' (dogrulamayi atlar / dis kod yukler)')
            }
        }
        try {
            $gp = Get-Process -Id $pr.ProcessId -ErrorAction Stop
            foreach ($mod in $gp.Modules) {
                $mp2 = $mod.FileName
                if ($mp2 -match '(?i)^[A-Za-z]:\\Windows\\|\\Program Files') { continue }
                $mh = Get-NameHit $mod.ModuleName $false
                $mz = Get-Zone $mp2
                $bad = $false
                $why2 = ''
                if ($mh) {
                    $bad = $true; $why2 = 'isim: ' + $mh.Name
                } elseif (($mz -eq 'user' -or $mz -eq 'shared' -or $mz -eq 'other') -and ($mp2 -notmatch '(?i)\\\.minecraft\\|ModrinthApp|PrismLauncher|\.lunarclient|\\runtime\\|\\jre|\\jdk|\\java') -and -not (Test-Signed $mp2)) {
                    $bad = $true; $why2 = 'imzasiz modul, olagan disi yerde'
                }
                if ($bad) {
                    Add-F -Kaynak 'Java modulu (injection)' -Ad $mod.ModuleName.ToLower() -Yol $mp2 -Skor 65 -Son $pr.CreationDate -Var 'Evet' -Not ('calisan Java icine yuklenmis DLL: ' + $why2)
                }
            }
        } catch {}
    }
}
if ($script:HkOk) {
    $OverlayOk = @('explorer', 'dwm', 'TextInputHost', 'ShellExperienceHost', 'SearchHost', 'SearchApp', 'StartMenuExperienceHost', 'ApplicationFrameHost', 'NVIDIA Overlay', 'nvcontainer', 'NVIDIA Share', 'RTSS', 'MSIAfterburner', 'Discord', 'steamwebhelper', 'steam', 'GameBar', 'XboxGameBar', 'GameBarPresenceWriter', 'obs64', 'Medal', 'Overwolf', 'OverwolfBrowser', 'RadeonSoftware', 'AMDRSSrcExt', 'LockApp', 'ScreenClippingHost', 'SnippingTool', 'PowerToys', 'Lightshot', 'Rainmeter', 'ShareX')
    try {
        foreach ($o in [HkNative]::Overlays()) {
            $parts = $o.Split('|')
            $opid = [int]$parts[0]
            $pname = ''
            try { $pname = (Get-Process -Id $opid -ErrorAction Stop).ProcessName } catch {}
            if ($pname -and ($OverlayOk -notcontains $pname)) {
                $opath = ''
                try { $opath = (Get-Process -Id $opid -ErrorAction Stop).Path } catch {}
                Add-F -Kaynak 'Overlay penceresi' -Ad ('overlay: ' + $pname.ToLower()) -Yol $opath -Skor 40 -Var 'Evet' -Not ('saydam + hep ustte + tiklamayi gecirgen pencere (harici ESP/overlay olabilir). Baslik: ' + $parts[1] + ' boyut: ' + $parts[2])
            }
        }
    } catch {}
}
Show-Section

# ---------------------------------------------------------------------
Step '[4/17] Prefetch: calistirilan programlar ve calisma saatleri...'
Start-Sec
$pfCount = 0
foreach ($pf in $pfFiles) {
    try {
        $info = Read-Prefetch $pf.FullName
        $exe = $info.Exe
        if (-not $exe) { $exe = ($pf.BaseName -split '-')[0] }
        $pathFull = $null
        foreach ($sp in $info.Paths) { if ($sp -like ('*\' + $exe)) { $pathFull = $sp; break } }
        $last = $pf.LastWriteTime
        $runsTxt = ''
        if ($info.Runs.Count -gt 0) {
            $sorted = @($info.Runs | Sort-Object -Descending)
            $last = $sorted[0]
            $runsTxt = 'Prefetch calisma saatleri: ' + ((@($sorted | Select-Object -First 8) | ForEach-Object { Fmt $_ }) -join ', ')
        }
        $pfCount++
        if ($exe -ieq 'WMIC.EXE') {
            Add-Sys 'WMIC.EXE calistirilmis (Prefetch)' 10 'wmic ile exe/dosya baslatmak hilelerde kullanilabilir, ama bircok oyun/launcher/anticheat/donanim araci da donanim bilgisi okumak icin wmic calistirir; tek basina supheli degil.' $last $runsTxt $null
        }
        if ($pathFull) {
            $rr = Resolve-PfPath $pathFull
            [void]$script:PfExecs.Add([pscustomobject]@{ Exe = $exe; Path = $rr.Path; Exists = $rr.Exists; Last = $last })
            Eval-Exec -Kaynak 'Prefetch' -Path $rr.Path -Exists $rr.Exists -Removed $rr.Removed -Last $last -First $pf.CreationTime -Note $runsTxt
        } else {
            Eval-Exec -Kaynak 'Prefetch' -Path $exe -Last $last -First $pf.CreationTime -Note $runsTxt -NoLoc
        }
    } catch {}
}
Log ('   ' + $pfCount + ' Prefetch kaydi incelendi.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[5/17] BAM: programlarin son calistirma zamani (kayit defteri)...'
Start-Sec
$bamCount = 0
foreach ($root in @('HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings', 'HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings')) {
    if (-not (Test-Path $root)) { continue }
    foreach ($sk in @(Get-ChildItem $root)) {
        foreach ($vn in $sk.GetValueNames()) {
            if ($vn -notmatch '^\\Device\\|^[A-Za-z]:\\') { continue }
            $bytes = $sk.GetValue($vn)
            $t = $null
            if ($bytes -is [byte[]] -and $bytes.Length -ge 8) { $t = Ft ([BitConverter]::ToInt64($bytes, 0)) }
            $rp = Resolve-NtPath $vn
            try { $script:BamLeaves[(Split-Path -Leaf $rp.Path).ToLower()] = 1 } catch {}
            Eval-Exec -Kaynak 'BAM' -Path $rp.Path -Exists $rp.Exists -Removed $rp.Removed -Last $t -Note 'BAM son calistirma kaydi'
            $bamCount++
        }
    }
}
Log ('   ' + $bamCount + ' BAM kaydi incelendi.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[6/17] UserAssist: calistirma sayisi ve zamani...'
Start-Sec
$KnownFolders = @{
    '{374DE290-123F-4565-9164-39C4925E467B}' = ($UP + '\Downloads')
    '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}' = ($UP + '\Desktop')
    '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}' = ($UP + '\Documents')
    '{3EB685DB-65F9-4CF6-A03A-E3EF65729F3D}' = $env:APPDATA
    '{F1B32785-6FBA-4FCF-9D55-7B8E7F157091}' = $env:LOCALAPPDATA
    '{5E6C858F-0E22-4760-9AFE-EA3317B67173}' = $UP
    '{905E63B6-C1BF-494E-B29C-65B732D3D21A}' = 'C:\Program Files'
    '{6D809377-6AF0-444B-8957-A3773F02200E}' = 'C:\Program Files'
    '{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E}' = 'C:\Program Files (x86)'
    '{F38BF404-1D43-42F2-9305-67DE0B28FC23}' = 'C:\Windows'
    '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}' = 'C:\Windows\System32'
}
$uaCount = 0
$uaRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist'
foreach ($g in @(Get-ChildItem $uaRoot)) {
    $ck = $g.OpenSubKey('Count')
    if (-not $ck) { continue }
    foreach ($vn in $ck.GetValueNames()) {
        $dec = Rot13 $vn
        if ($dec -notmatch '(?i)\.exe$') { continue }
        foreach ($kf in $KnownFolders.Keys) { if ($dec.StartsWith($kf, [StringComparison]::OrdinalIgnoreCase)) { $dec = $KnownFolders[$kf] + $dec.Substring($kf.Length); break } }
        if ($dec -notmatch '^[A-Za-z]:\\') { continue }
        $bytes = $ck.GetValue($vn)
        $t = $null
        $cnt = ''
        if ($bytes -is [byte[]] -and $bytes.Length -ge 68) {
            $t = Ft ([BitConverter]::ToInt64($bytes, 60))
            $cnt = 'UserAssist calistirma sayisi: ' + [BitConverter]::ToUInt32($bytes, 4)
        }
        $pi = Test-PathInfo $dec
        Eval-Exec -Kaynak 'UserAssist' -Path $dec -Exists $pi.Exists -Removed $pi.Removed -Last $t -Note $cnt
        $uaCount++
    }
}
Log ('   ' + $uaCount + ' UserAssist kaydi incelendi.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[7/17] Amcache: program envanteri (silinmis programlarin izi)...'
$amCount = 0
$amReason = ''
$amDir = Join-Path $env:TEMP ('hk_amc_' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $amDir -Force -ErrorAction SilentlyContinue)
$amSrc = $env:WINDIR + '\appcompat\Programs\Amcache.hve'
$amTmp = Join-Path $amDir 'Amcache.hve'
$copied = $false
try {
    $eo = & esentutl.exe /y /vss $amSrc /d $amTmp 2>&1
    if (Test-Path -LiteralPath $amTmp) { $copied = $true } else { $amReason = 'esentutl: ' + ((($eo | Out-String).Trim()) -replace '\s+', ' ') }
} catch { $amReason = 'esentutl calistirilamadi: ' + $_.Exception.Message }
if (-not $copied) {
    try { Copy-Item -LiteralPath $amSrc -Destination $amTmp -Force -ErrorAction Stop; $copied = $true } catch { $amReason = $amReason + ' | dogrudan kopya: ' + $_.Exception.Message }
}
if ($copied) {
    $loaded = $false
    $hkn = 'HK_AMC_' + (Get-Random -Maximum 99999)
    $lo = & reg.exe load ('HKLM\' + $hkn) $amTmp 2>&1
    if ($LASTEXITCODE -eq 0) {
        $loaded = $true
    } else {
        foreach ($lgx in @('.LOG1', '.LOG2')) { & esentutl.exe /y /vss ($amSrc + $lgx) /d ($amTmp + $lgx) 2>&1 | Out-Null }
        $lo = & reg.exe load ('HKLM\' + $hkn) $amTmp 2>&1
        if ($LASTEXITCODE -eq 0) { $loaded = $true } else { $amReason = 'hive yuklenemedi: ' + ((($lo | Out-String).Trim()) -replace '\s+', ' ') }
    }
    if ($loaded) {
        Start-Sec
        try {
            $rk = 'Registry::HKEY_LOCAL_MACHINE\' + $hkn + '\Root\InventoryApplicationFile'
            foreach ($k in @(Get-ChildItem -LiteralPath $rk -ErrorAction SilentlyContinue)) {
                $ap = [string]$k.GetValue('LowerCaseLongPath')
                if (-not $ap) { $k.Close(); continue }
                if ($ap -match '(?i)^[a-z]:\\(windows|program files)') { $k.Close(); continue }
                $kt = Get-KeyTime $k
                $pub = [string]$k.GetValue('Publisher')
                $sha = [string]$k.GetValue('FileId')
                $k.Close()
                $pi = Test-PathInfo $ap
                $nt = 'Amcache kaydi'
                if ($pub) { $nt = $nt + ' | yayinci: ' + $pub } else { $nt = $nt + ' | yayinci yok' }
                if ($sha.Length -gt 4) { $nt = $nt + ' | SHA1: ' + $sha.Substring(4) }
                Eval-Exec -Kaynak 'Amcache' -Path $ap -Exists $pi.Exists -Removed $pi.Removed -First $kt -Note $nt
                $amCount++
            }
        } catch {}
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        Start-Sleep -Milliseconds 300
        & reg.exe unload ('HKLM\' + $hkn) 2>&1 | Out-Null
    }
}
Remove-Item -LiteralPath $amDir -Recurse -Force -ErrorAction SilentlyContinue
if ($amCount -eq 0) {
    if ($amReason.Length -gt 300) { $amReason = $amReason.Substring(0, 300) + '...' }
    if (-not $amReason) { $amReason = 'kayit bulunamadi' }
    Log ('   Amcache okunamadi. Neden: ' + $amReason) 'DarkYellow'
} else {
    Log ('   ' + $amCount + ' Amcache kaydi incelendi.') 'DarkGray'
    Show-Section
}

# ---------------------------------------------------------------------
Step '[8/17] Shimcache (AppCompatCache) yol taramasi...'
Start-Sec
$shCount = 0
try {
    $blob = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache' -ErrorAction Stop).AppCompatCache
    if ($blob -is [byte[]]) {
        $seenSh = @{}
        foreach ($off in @(0, 1)) {
            $len = $blob.Length - $off
            $sub = New-Object byte[] $len
            [Array]::Copy($blob, $off, $sub, 0, $len)
            $txt = [Text.Encoding]::Unicode.GetString($sub)
            foreach ($pm in (Find-Paths $txt 'exe|jar|bat|ps1|scr|cmd|vbs')) {
                $lk = $pm.ToLower()
                if ($seenSh.ContainsKey($lk)) { continue }
                $seenSh[$lk] = 1
                $pi = Test-PathInfo $pm
                Eval-Exec -Kaynak 'Shimcache' -Path $pm -Exists $pi.Exists -Removed $pi.Removed -Note 'Shimcache kaydi (zaman bilgisi yok)'
                $shCount++
            }
        }
    }
} catch {}
Log ('   ' + $shCount + ' Shimcache yolu incelendi.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[9/17] Recent (son kullanilanlar) ve Jump List kayitlari...'
Start-Sec
$recentDir = Join-Path $env:APPDATA 'Microsoft\Windows\Recent'
$lnks = @(Get-ChildItem -LiteralPath $recentDir -Filter '*.lnk' -Force -ErrorAction SilentlyContinue)
Log ('   Recent klasorunde ' + $lnks.Count + ' kisayol var.') 'DarkGray'
if ($lnks.Count -lt 5) { Add-Sys 'Recent (Son kullanilanlar) neredeyse bos' 30 'Temizlenmis olabilir (normalde onlarca kayit olur).' }
$wsh = $null
try { $wsh = New-Object -ComObject WScript.Shell } catch {}
foreach ($l in $lnks) {
    $target = ''
    try { if ($wsh) { $target = [string]$wsh.CreateShortcut($l.FullName).TargetPath } } catch {}
    $tExt = ''
    try { $tExt = [IO.Path]::GetExtension($target).ToLower() } catch {}
    $lh = Get-NameHit $l.BaseName $true
    # Recent'ta rastgele/anlamsiz isimli kod dosyasi (ornek: asdhjsa.jar, hasdih.exe)
    $bnL = $l.BaseName
    $bnExt = ''
    $bnStem = $bnL
    try { $bnExt = [IO.Path]::GetExtension($bnL).ToLower(); $bnStem = [IO.Path]::GetFileNameWithoutExtension($bnL) } catch {}
    if (($script:CodeExtSet -contains $bnExt) -and (Test-Gibberish $bnStem)) {
        $gv = 'Bilinmiyor'
        $gy = $bnL
        if ($target -match '^[A-Za-z]:\\') {
            $gp0 = Test-PathInfo $target
            $gy = $target
            if ($gp0.Exists) { $gv = 'Evet' } else { $gv = 'Hayir' }
        }
        Add-F -Kaynak 'Recent (anlamsiz dosya adi)' -Ad ($bnL.ToLower()) -Yol $gy -Skor 45 -Son $l.LastWriteTime -Ilk $l.CreationTime -Var $gv -Not 'Recent klasorunde rastgele/anlamsiz karakterli kod dosyasi (ornek: asdhjsa.jar, hasdih.exe); hile dosyalari sik boyle adlandirilir'
    }
    if ([string]::IsNullOrWhiteSpace($target)) {
        if ($lh) { Eval-Exec -Kaynak 'Recent (kisayol)' -Path $l.BaseName -Last $l.LastWriteTime -First $l.CreationTime -Note ('kisayol: ' + $l.Name) -NoLoc }
    } elseif (($IntExt -contains $tExt) -or $lh) {
        $pi = Test-PathInfo $target
        Eval-Exec -Kaynak 'Recent (kisayol)' -Path $target -Exists $pi.Exists -Removed $pi.Removed -Last $l.LastWriteTime -First $l.CreationTime -Note ('kisayol: ' + $l.Name)
    }
}
$jlCount = 0
foreach ($jd in @((Join-Path $recentDir 'AutomaticDestinations'), (Join-Path $recentDir 'CustomDestinations'))) {
    foreach ($jf in @(Get-ChildItem -LiteralPath $jd -File -Force -ErrorAction SilentlyContinue)) {
        try {
            $jb = [IO.File]::ReadAllBytes($jf.FullName)
            $jp = @{}
            foreach ($enc in @([Text.Encoding]::Unicode, [Text.Encoding]::ASCII)) {
                $jt = $enc.GetString($jb)
                foreach ($pm in (Find-Paths $jt 'exe|jar|bat|ps1|scr|zip|rar|7z')) { $jp[$pm] = 1 }
            }
            foreach ($pth in $jp.Keys) {
                $pi = Test-PathInfo $pth
                Eval-Exec -Kaynak 'Jump List' -Path $pth -Exists $pi.Exists -Removed $pi.Removed -Last $jf.LastWriteTime -Note 'Jump List kaydi (zaman = uygulamanin liste dosyasi)'
                $jlCount++
            }
        } catch {}
    }
}
Log ('   ' + $jlCount + ' Jump List yolu incelendi.') 'DarkGray'
Show-Section

# =====================================================================
# MOD KLASORU ANALIZI (Meow Mod Analyzer mantigi, HileKiran yapisina uyarlandi)
# Sadece OKUR. Tek ag kullanimi: mod dosyasinin SHA1 hash i Modrinth/Megabase te aranir (HK_NONET=1 ile kapatilir).
# =====================================================================
Step '[10/17] MOD KLASORU ANALIZI: .jar modlarin hash dogrulamasi, hile stringleri, bypass/enjeksiyon, obfuscation, JVM agent...'
Start-Sec

function ConvertTo-Fw([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $c = [int]$ch
        if (($c -ge 48 -and $c -le 57) -or ($c -ge 65 -and $c -le 90) -or ($c -ge 97 -and $c -le 122)) { [void]$sb.Append([char]($c + 0xFEE0)) }
        elseif ($c -eq 45) { [void]$sb.Append([char]0xFF0D) }
        elseif ($c -eq 44) { [void]$sb.Append([char]0xFF0C) }
        else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

$script:MmNet = ($env:HK_NONET -ne '1')
$script:MmFails = 0
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

# ---- desen listesi (entry adlari + class icerigi; regex, buyuk/kucuk harf duyarli) ----
$mmPatList = @(
    'AimAssist','AnchorTweaks','AutoAnchor','AutoCrystal','AutoDoubleHand','JDWP.VirtualMachine.AllModules',
    'AutoHitCrystal','AutoPot','AutoTotem','AutoArmor','InventoryTotem','LegitTotem','PingSpoof','SelfDestruct',
    'ShieldBreaker','TriggerBot','AxeSpam','WebMacro','FastPlace','WalskyOptimizer','WalksyOptimizer','walsky.optimizer',
    'WalksyCrystalOptimizerMod','Donut','Replace Mod','ShieldDisabler','SilentAim','Totem Hit','Wtap','FakeLag','dev.virel','orchard',
    'BlockESP','dev.krypton','dev/krypton','skid.krypton','skid/krypton','AntiMissClick','LagReach','PopSwitch','SprintReset',
    'ChestSteal','AntiBot','ElytraSwap','FastXP','FastExp','Refill','AirAnchor','jnativehook','FakeInv','HoverTotem',
    'AutoClicker','AutoFirework','PackSpoof','Antiknockback','catlean','AuthBypass','Asteria','Prestige','AutoEat','AutoMine',
    'MaceSwap','Macro198','StunSlam','SafeAnchor','DoubleAnchor','AutoTPA','BaseFinder','Xenon','gypsy','AutoPotRefill',
    'KeyPearl','AutoNethPot','AutoDtap','AutoWeb','AnchorAction',
    'org.chainlibs.module.impl.modules.Crystal.Y','org.chainlibs.module.impl.modules.Crystal.bF','org.chainlibs.module.impl.modules.Crystal.bM',
    'org.chainlibs.module.impl.modules.Crystal.bY','org.chainlibs.module.impl.modules.Crystal.bq','org.chainlibs.module.impl.modules.Crystal.cv',
    'org.chainlibs.module.impl.modules.Crystal.o','org.chainlibs.module.impl.modules.Blatant.I','org.chainlibs.module.impl.modules.Blatant.bR',
    'org.chainlibs.module.impl.modules.Blatant.bx','org.chainlibs.module.impl.modules.Blatant.cj','org.chainlibs.module.impl.modules.Blatant.dk',
    'imgui.gl3','imgui.glfw','BowAim','Criticals','Fakenick','FakeItem','invsee','ItemExploit','Hellion','hellion',
    'LicenseCheckMixin','ClientPlayerInteractionManagerAccessor','ClientPlayerEntityMixim','dev.gambleclient','obfuscatedAuth',
    'phantom-refmap.json','xyz.greaj',
    'HighStep','WaterWalk','LiquidWalk','LavaWalk','NoSlow','NoSlowdown','NoWeb','NoSoulSand','WallHack','ElytraSpeed','InstantElytra',
    'ScaffoldWalk','FastBridge','BuildHelper','AutoBridge','Nuker','NukerLegit','InstantBreak',
    'GhostHand','NoSwing','PlaceAssist','AirPlace','AutoPlace','InstantPlace',
    'PlayerESP','MobESP','ItemESP','StorageESP','ChestESP','Tracers','NameTagsHack','XRayHack','OreFinder','CaveFinder','OreESP',
    'NewChunks','ChunkBorders','TunnelFinder','TargetHUD','ReachDisplay','DoubleClicker','JitterClick','ButterflyClick','CPSBoost',
    'ChestStealer','InvManager','InvMovebypass','AutoSprint','AntiAFK','AutoRespawn',
    'FakeLatency','FakePing','SpoofRotation','PositionSpoof','GameSpeed','SpeedTimer','GrimBypass','VulcanBypass','MatrixBypass',
    'AACBypass','VerusDisabler','IntaveBypass','WatchdogBypass',
    'PacketMine','PacketWalk','PacketSneak','PacketCancel','PacketDupe','PacketSpam',
    'HideClient','SessionStealer','TokenLogger','TokenGrabber','DiscordToken','RemoteAccess','ReverseShell','C2Server','Backdoor','KeyLogger',
    'StashFinder','TrailFinder','imgui.binding','JNativeHook','GlobalScreen','NativeKeyListener','client-refmap.json','cheat-refmap.json',
    'aHR0cDovL2FwaS5ub3ZhY2xpZW50LmxvbC93ZWJob29rLnR4dA==',
    'meteordevelopment','cc/novoline','com/alan/clients','club/maxstats','wtf/moonlight','me/zeroeightsix/kami','net/ccbluex','today/opai',
    'net/minecraft/injection','org/chainlibs/module/impl/modules','xyz/greaj','com/cheatbreaker','com/moonsworth',
    'doomsdayclient','DoomsdayClient','doomsday.jar','novaclient','api.novaclient.lol','LWFH Crystal',
    'vape.gg','vapeclient','VapeClient','VapeLite','intent.store','IntentClient','rise.today','riseclient.com',
    'meteor-client','meteorclient','meteordevelopment.meteorclient','liquidbounce','fdp-client','net.ccbluex','novoware','novoclient',
    'aristois','impactclient','azura','pandaware','skilled','moonClient','astolfo','futureClient','konas','rusherhack','inertia','exhibition',
    'VirginClient','virgin client','CatleanClient','catlean client','ArgonClient','argon client','AsteriaClient','asteria client',
    'PrestigeClient','prestige client','prestigeclient.vip','GypsyClient','gypsy client','XenonClient','xenon client',
    'GrimClient','grim client','dqrkis.xyz','Dqrkis Client'
)
# Japonca sinif adi obfuscation izleri (script ASCII kalsin diye kod noktasindan uretilir)
foreach ($cp in @(0x3058,0x3075,0x3076,0x3077,0x305F,0x306D,0x305D,0x306A,0x3069,0x3050,0x305A,0x3067,0x3064,0x3079,0x305B,0x3068,0x307F,0x3073,0x3059,0x306E)) {
    $mmPatList += (([string][char]$cp) + '.class')
}
$mmPatSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($p in $mmPatList) { if ($p) { [void]$mmPatSet.Add($p) } }
$mmPatSorted = @($mmPatSet | Sort-Object -Property { $_.Length } -Descending)
$mmPatAlt = ($mmPatSorted | ForEach-Object { [regex]::Escape($_) }) -join '|'
$script:MmPatRx = New-Object System.Text.RegularExpressions.Regex -ArgumentList ('(?<![A-Za-z])(' + $mmPatAlt + ')(?![A-Za-z])'), ([System.Text.RegularExpressions.RegexOptions]::None)

# ---- class icerigi stringleri: hem duz hem tam genislikli (fullwidth) halleri aranir ----
$mmBoth = @(
    'AutoCrystal','Auto Crystal','AutoHitCrystal','AutoAnchor','Auto Anchor','DoubleAnchor','Double Anchor','SafeAnchor','Safe Anchor','Anchor Macro',
    'AutoTotem','Auto Totem','HoverTotem','Hover Totem','InventoryTotem','Auto Inventory Totem','Auto Totem Hit','AutoPot','Auto Pot','Auto Pot Refill',
    'AutoArmor','Auto Armor','ShieldDisabler','Shield Disabler','AutoDoubleHand','Auto Double Hand','AutoClicker','AutoMace','Auto Mace',
    'MaceSwap','Mace Swap','Spear Swap','Stun Slam','AimAssist','Aim Assist','TriggerBot','Trigger Bot','Silent Rotations','FakeLag','Fake Lag',
    'Fake Punch','Anti Web','AutoWeb','Walksy Optimizer','ElytraSwap','Elytra Swap','KeyPearl','Key Pearl','Loot Yeeter','Fast Place','Auto Breach',
    'Freecam','No Clip','Freeze Player','LWFH Crystal'
)
# Cok genel ayar adlari: sadece tam genislikli (obfuscate/gizlenmis) halleri aranir, duz halleri mesru modlarda cok gectigi icin atlanir
$mmFwOnly = @(
    'Click Simulation','On RMB','No Count Glitch','No Bounce','NoBounce','Place Delay','Break Delay','Fast Mode','Place Chance','Break Chance',
    'Stop On Kill','Damage Tick','Anti Weakness','Particle Chance','Trigger Key','Switch Delay','Totem Slot','Smooth Rotations','Rotation Speed',
    'Use Easing','Easing Strength','While Use','Glowstone Delay','Glowstone Chance','Explode Delay','Explode Chance','Explode Slot','Only Charge',
    'Reach Distance','Min Height','Min Fall Speed','Attack Delay','Breach Delay','Require Elytra','Auto Switch Back','Check Line of Sight',
    'Only When Falling','Require Crit','Show Status Display','Stop On Crystal','Check Shield','On Pop','Predict Damage','On Ground','Check Players',
    'Predict Crystals','Check Aim','Check Items','Activates Above','Blatant','Force Totem','Stay Open For','Only On Pop','Vertical Speed','Swap Speed',
    'Strict One-Tick','Mace Priority','Min Totems','Min Pearls','Totem First','Drop Interval','Random Pattern','Horizontal Aim Speed',
    'Vertical Aim Speed','Include Head','Web Delay','Holding Web','Not When Affects Player','Hit Delay','Switch Back','Require Hold Axe',
    'Activate Key','Macro Key','Places Webs On Enemies','Move freely through walls','Refills your hotbar with potions','Keeps you sprinting at all times',
    'placeInterval','breakInterval','stopOnKill','activateOnRightClick','damagetick','holdCrystal','fakePunch'
)
$mmPlainExtra = @(
    'JDWP.VirtualMachine.AllModules','dontPlaceCrystal','dontBreakCrystal','dev.virel','orchard','autocrystal','cw crystal','autohitcrystal',
    'canPlaceCrystalServer','healPotSlot','autoanchor','HasAnchor','anchortweaks','anchor macro','safe anchor','AirAnchor','anchorMacro','autototem',
    'inventorytotem','legittotem','hover totem','speedPotSlot','strengthPotSlot','autopot','auto pot','autoarmor','auto armor',
    'preventSwordBlockBreaking','preventSwordBlockAttack','ShieldBreaker','Breaking shield with axe...','autodoublehand','Failed to switch to mace after axe!',
    'SpearSwap','Donut','JumpReset','axespam','axe spam','findKnockbackSword','attackRegisteredThisClick','aimassist','triggerbot','trigger bot',
    'FakeInv','swapBackToOriginalSlot','pingspoof','ping spoof','mace_swap','quick_strike','macro_198','stun_slam','safe_anchor','double_anchor',
    'auto_pot_refill','walksy_optimizer','key_pearl','aim_assist','auto_neth_pot','auto_dtap','trigger_bot','auto_web','DOUBLE_ESCAPE',
    'DOUBLE_RIGHTCLICK_FIRST','DOUBLE_RIGHTCLICK_SECOND','POST_CYCLE_DELAY','PLACE_OBI','WAIT_OBI','PLACE_CRYSTAL','BREAK_CRYSTAL','ROTATING_DOWN',
    'ROTATING_BACK','REFILLING','PLANTING','BONEMEALING','AnchorAction','Places two anchors for massive damage','REOFFHAND_TOTEM','webmacro','web macro',
    'AntiWeb','lvstrng','dqrkis','selfdestruct','self destruct','WalksyCrystalOptimizerMod','WalksyOptimizer','WalskyOptimizer','autoCrystalPlaceClock',
    'AutoFirework','FastXP','FastExp','NoJumpDelay','PackSpoof','Antiknockback','catlean','AuthBypass','obfuscatedAuth','LicenseCheckMixin','BaseFinder',
    'invsee','ItemExploit','FreezePlayer','LootYeeter','setBlockBreakingCooldown','getBlockBreakingCooldown','blockBreakingCooldown','onBlockBreaking',
    'setItemUseCooldown','invokeDoAttack','invokeDoItemUse','invokeOnMouseButton','onPushOutOfBlocks','onIsGlowing',
    'Automatically switches to sword when hitting with totem','arrayOfString','POT_CHEATS','Dqrkis Client','Entity.isGlowing',
    'KillAura','ClickAura','MultiAura','ForceField','LegitAura','AimBot','AutoAim','SilentAim','AimLock','HeadSnap','CrystalAura','AnchorAura','AnchorFill',
    'AnchorPlace','BedAura','AutoBed','BedBomb','BedPlace','BowAimbot','BowSpam','AutoBow','AutoCrit','CritBypass','AlwaysCrit','CriticalHit','ReachHack',
    'ExtendReach','LongReach','HitboxExpand','AntiKB','NoKnockback','GrimVelocity','GrimDisabler','VelocitySpoof','KBReduce','OffhandTotem','TotemSwitch',
    'AutoWeapon','AutoSword','AutoCity','Burrow','SelfTrap','HoleFiller','AntiSurround','AntiBurrow','WTap','TargetStrafe','AutoGap','AutoPearl',
    'FlyHack','CreativeFlight','BoatFly','PacketFly','AirJump','SpeedHack','BHop','BunnyHop','AntiFall','NoFallDamage','SafeFall','StepHack','FastClimb','AutoStep'
)
$mmStrSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($s in $mmBoth) { [void]$mmStrSet.Add($s); [void]$mmStrSet.Add((ConvertTo-Fw $s)) }
foreach ($s in $mmFwOnly) { [void]$mmStrSet.Add((ConvertTo-Fw $s)) }
foreach ($s in $mmPlainExtra) { [void]$mmStrSet.Add($s) }
$mmStrSorted = @($mmStrSet | Sort-Object -Property { $_.Length } -Descending)
$mmStrAlt = ($mmStrSorted | ForEach-Object { [regex]::Escape($_) }) -join '|'
$script:MmStrRx = New-Object System.Text.RegularExpressions.Regex -ArgumentList $mmStrAlt, ([System.Text.RegularExpressions.RegexOptions]::None)
$script:MmFwRx = New-Object System.Text.RegularExpressions.Regex -ArgumentList '[\uFF21-\uFF3A\uFF41-\uFF5A\uFF10-\uFF19]{2,}', ([System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:MmFwPool = @($mmStrSet | Where-Object { $_ -cmatch '[\uFF21-\uFF3A\uFF41-\uFF5A\uFF10-\uFF19]' })

# ---- arsiv yardimcilari ----
function Open-MmArchive([string]$path) {
    $zip = $null
    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($path) } catch { return $null }
    if (-not $zip) { return $null }
    $entries = New-Object System.Collections.Generic.List[object]
    $inner = New-Object System.Collections.Generic.List[object]
    $nested = New-Object System.Collections.Generic.List[object]
    foreach ($e in @($zip.Entries)) { [void]$entries.Add($e) }
    foreach ($e in @($zip.Entries)) {
        if ($e.FullName -match '^META-INF/jars/.+\.jar$') {
            [void]$nested.Add($e)
            if ($e.Length -gt 0 -and $e.Length -lt 31457280) {
                try {
                    $ns = $e.Open()
                    $ms = New-Object System.IO.MemoryStream
                    $ns.CopyTo($ms); $ns.Dispose()
                    $ms.Position = 0
                    $iz = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Read)
                    [void]$inner.Add($iz)
                    foreach ($ie in @($iz.Entries)) { [void]$entries.Add($ie) }
                } catch {}
            }
        }
    }
    return @{ Zip = $zip; Entries = $entries; Inner = $inner; Nested = $nested }
}
function Close-MmArchive($a) {
    if (-not $a) { return }
    foreach ($i in $a.Inner) { try { $i.Dispose() } catch {} }
    try { $a.Zip.Dispose() } catch {}
}
function Read-MmEntry($entry, [int]$max) {
    try {
        if ($entry.Length -gt $max) { return $null }
        $st = $entry.Open()
        $ms = New-Object System.IO.MemoryStream
        $st.CopyTo($ms); $st.Dispose()
        $b = $ms.ToArray(); $ms.Dispose()
        return ,$b
    } catch { return $null }
}

# ---- 1) hile string taramasi ----
function Invoke-ModScan([string]$FilePath) {
    $foundPatterns = New-Object 'System.Collections.Generic.HashSet[string]'
    $foundStrings = New-Object 'System.Collections.Generic.HashSet[string]'
    $foundFw = New-Object 'System.Collections.Generic.HashSet[string]'
    $arc = Open-MmArchive $FilePath
    if ($arc) {
        foreach ($e in $arc.Entries) {
            foreach ($m in $script:MmPatRx.Matches($e.FullName)) { [void]$foundPatterns.Add($m.Value) }
        }
        foreach ($e in $arc.Entries) {
            $n = $e.FullName
            if ($n -match '\.(class|json)$' -or $n -match 'MANIFEST\.MF') {
                $bytes = Read-MmEntry $e 3145728
                if ($null -eq $bytes) { continue }
                $txt = [System.Text.Encoding]::UTF8.GetString($bytes)
                foreach ($m in $script:MmPatRx.Matches($txt)) { [void]$foundPatterns.Add($m.Value) }
                foreach ($m in $script:MmStrRx.Matches($txt)) { [void]$foundStrings.Add($m.Value) }
                foreach ($m in $script:MmFwRx.Matches($txt)) { [void]$foundFw.Add($m.Value) }
            }
        }
        Close-MmArchive $arc
    }
    $resolved = New-Object System.Collections.Generic.List[string]
    $resSet = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($fw in @($foundFw)) {
        if ($fw.Length -lt 3) { continue }
        $best = $null
        foreach ($cs in $script:MmFwPool) {
            if ($cs.Contains($fw)) { if ($null -eq $best -or $cs.Length -lt $best.Length) { $best = $cs } }
        }
        if ($null -ne $best) { if ($resSet.Add($best)) { [void]$resolved.Add($best) } }
        elseif ($fw.Length -ge 6) { if ($resSet.Add($fw)) { [void]$resolved.Add($fw) } }
    }
    $finalFw = New-Object System.Collections.Generic.List[string]
    foreach ($fw in $resolved) {
        $red = $false
        foreach ($o in $resolved) { if ($fw.Length -lt $o.Length -and $o.Contains($fw)) { $red = $true; break } }
        if (-not $red) { [void]$finalFw.Add($fw) }
    }
    return @{ Patterns = @($foundPatterns); Strings = @($foundStrings); Fullwidth = @($finalFw) }
}

# ---- 2) bypass / enjeksiyon taramasi ----
function Test-MmJarName([string]$JarName) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($JarName)
    if ($base -match '\d') { return $false }
    foreach ($pfx in @('com_','org_','net_','io_','dev_','gs_','xyz_','app_','me_','tv_','uk_','be_','fr_','de_')) {
        if ($base.ToLower().StartsWith($pfx)) { return $false }
    }
    if ($base.Length -gt 20) { return $false }
    return $true
}
function Invoke-MmBypassScan([string]$FilePath) {
    $flags = New-Object System.Collections.Generic.List[string]
    $arc = Open-MmArchive $FilePath
    if (-not $arc) { return ,$flags }
    $outerClasses = @($arc.Zip.Entries | Where-Object { $_.FullName -match '\.class$' })
    foreach ($nj in $arc.Nested) {
        $njBase = [System.IO.Path]::GetFileName($nj.FullName)
        if (Test-MmJarName $njBase) { [void]$flags.Add('Suspicious nested JAR - no version, unknown dependency: ' + $njBase) }
    }
    if ($arc.Nested.Count -eq 1 -and $outerClasses.Count -lt 3) {
        $njName = [System.IO.Path]::GetFileName($arc.Nested[0].FullName)
        [void]$flags.Add('Hollow shell - only ' + $outerClasses.Count + ' own class(es), wraps: ' + $njName)
    }
    $outerModId = ''
    $fmje = @($arc.Zip.Entries | Where-Object { $_.FullName -eq 'fabric.mod.json' } | Select-Object -First 1)
    if ($fmje.Count -gt 0) {
        $fb = Read-MmEntry $fmje[0] 262144
        if ($null -ne $fb) {
            $ft = [System.Text.Encoding]::UTF8.GetString($fb)
            if ($ft -match '"id"\s*:\s*"([^"]+)"') { $outerModId = $Matches[1] }
        }
    }
    $rtExec = $false; $httpDl = $false; $httpExfil = $false
    $obfN = 0; $numN = 0; $uniN = 0; $totN = 0
    foreach ($entry in $arc.Entries) {
        $name = $entry.FullName
        if ($name -notmatch '\.class$') { continue }
        $totN++
        $className = [System.IO.Path]::GetFileNameWithoutExtension(($name -split '/')[-1])
        if ($className -match '^\d+$') { $numN++ }
        if ($className -match '[^\x00-\x7F]') { $uniN++ }
        $segs = ($name -replace '\.class$', '') -split '/'
        $cons = 0; $maxC = 0
        foreach ($seg in $segs) {
            if ($seg.Length -eq 1) { $cons++; if ($cons -gt $maxC) { $maxC = $cons } } else { $cons = 0 }
        }
        if ($maxC -ge 3) { $obfN++ }
        $rb = Read-MmEntry $entry 2097152
        if ($null -eq $rb) { continue }
        $ct = [System.Text.Encoding]::ASCII.GetString($rb)
        if (-not $rtExec -and $ct.Contains('java/lang/Runtime') -and $ct.Contains('getRuntime') -and $ct.Contains('exec')) { $rtExec = $true }
        if (-not $httpDl -and $ct.Contains('openConnection') -and $ct.Contains('HttpURLConnection') -and $ct.Contains('FileOutputStream')) { $httpDl = $true }
        if (-not $httpExfil -and $ct.Contains('openConnection') -and $ct.Contains('setDoOutput') -and $ct.Contains('getOutputStream') -and $ct.Contains('getProperty')) { $httpExfil = $true }
    }
    Close-MmArchive $arc
    $obfPct = 0; $numPct = 0; $uniPct = 0
    if ($totN -ge 10) { $obfPct = [math]::Round(($obfN / $totN) * 100) }
    if ($totN -ge 5) { $numPct = [math]::Round(($numN / $totN) * 100); $uniPct = [math]::Round(($uniN / $totN) * 100) }
    if ($rtExec -and $obfPct -ge 25) { [void]$flags.Add('Runtime.exec() in obfuscated code - can run arbitrary OS commands') }
    if ($httpDl) { [void]$flags.Add('HTTP file download - fetches and writes files from a remote server at runtime') }
    if ($httpExfil) { [void]$flags.Add('HTTP POST exfiltration - sends system data to an external server') }
    if ($totN -ge 10 -and $obfPct -ge 25) { [void]$flags.Add('Heavy obfuscation - ' + $obfPct + '% of classes use single-letter path segments (a/b/c style)') }
    if ($numPct -ge 20) { [void]$flags.Add('Numeric class names - ' + $numPct + '% of classes have numeric-only names') }
    if ($uniPct -ge 10) { [void]$flags.Add('Unicode class names - ' + $uniPct + '% of classes use non-ASCII characters') }
    $legitIds = @('vmp-fabric','vmp','lithium','sodium','iris','fabric-api','modmenu','ferrite-core','lazydfu','starlight','entityculling','memoryleakfix','krypton','c2me-fabric','smoothboot-fabric','immediatelyfast','noisium','threadtweak')
    $danger = @($flags | Where-Object { $_ -match 'Runtime\.exec|HTTP file download|HTTP POST|Heavy obfuscation|Suspicious nested JAR' }).Count
    if ($outerModId -and ($legitIds -contains $outerModId) -and $danger -gt 0) {
        [void]$flags.Add("Fake mod identity - claims to be '" + $outerModId + "' but contains dangerous code")
    }
    return ,$flags
}

# ---- 3) obfuscation analizi ----
function Invoke-MmObfScan([string]$FilePath) {
    $flags = New-Object System.Collections.Generic.List[string]
    $arc = $null
    try { $arc = [System.IO.Compression.ZipFile]::OpenRead($FilePath) } catch { return ,$flags }
    $totalClass = 0; $numeric = 0; $unicode = 0; $fullw = 0; $jp = 0; $s1 = 0; $s2 = 0; $gib = 0; $nov = 0; $conf = 0; $singlePkg = 0
    $sample = New-Object System.Text.StringBuilder
    $sampleSize = 0
    $cheatObf = [ordered]@{
        'Skidfuscator' = @('dev/skidfuscator', 'Skidfuscator', 'skidfuscator.dev')
        'Paramorphism' = @('Paramorphism', 'paramorphism-', 'dev/paramorphism')
        'Radon' = @('ItzSomebody/Radon', 'me/itzsomebody/radon', 'Radon Obfuscator')
        'Caesium' = @('sim0n/Caesium', 'Caesium Obfuscator', 'dev/sim0n/caesium')
        'Bozar' = @('vimasig/Bozar', 'Bozar Obfuscator', 'com/bozar')
        'Branchlock' = @('Branchlock', 'branchlock.dev')
        'Binscure' = @('Binscure', 'com/binscure')
        'SuperBlaubeere' = @('superblaubeere', 'superblaubeere27')
        'Qprotect' = @('Qprotect', 'QProtect', 'mdma.dev/qprotect')
        'Zelix' = @('ZKMFLOW', 'ZelixKlassMaster', 'com/zelix')
        'Stringer' = @('StringerJavaObfuscator', 'com/licel/stringer')
        'JNIC' = @('jnic.obf', 'jnic-obfuscator')
        'Scuti' = @('ScutiObf', 'scuti.obf')
        'Smoke' = @('SmokeObf', 'smoke.obf')
    }
    try {
        foreach ($entry in $arc.Entries) {
            $name = $entry.FullName
            if ($name -notmatch '\.class$') { continue }
            $totalClass++
            $className = [System.IO.Path]::GetFileNameWithoutExtension(($name -split '/')[-1])
            if ($className -match '^\d+$') { $numeric++ }
            if ($className -match '[^\x00-\x7F]') { $unicode++ }
            if ($className -match '[\uFF21-\uFF3A\uFF41-\uFF5A\uFF10-\uFF19]') { $fullw++ }
            if ($className -match '[\u3040-\u309F\u30A0-\u30FF]') { $jp++ }
            if ($className -match '^[a-zA-Z]$') { $s1++ }
            if ($className -match '^[a-zA-Z]{2}$') { $s2++ }
            if ($className -match '^[Il1O0]+$' -or $className -match '^_+$') { $conf++ }
            if ($className.Length -ge 3 -and $className.Length -le 8 -and $className -match '^[a-zA-Z]+$') {
                $vow = ([regex]::Matches($className, '[aeiouAEIOU]')).Count
                if ($vow -eq 0) { $nov++ }
                if (($className -match '[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]{3,}') -and (($vow / $className.Length) -lt 0.3)) { $gib++ }
            }
            $segs = ($name -replace '\.class$', '') -split '/'
            if ($segs.Count -gt 1) { foreach ($seg in $segs[0..($segs.Count - 2)]) { if ($seg.Length -eq 1) { $singlePkg++ } } }
            if ($sampleSize -lt 150000 -and $entry.Length -lt 100000 -and $entry.Length -gt 100) {
                $sb2 = Read-MmEntry $entry 100000
                if ($null -ne $sb2) {
                    $as = [System.Text.Encoding]::ASCII.GetString($sb2)
                    [void]$sample.Append($as)
                    $sampleSize += $as.Length
                }
            }
        }
    } catch {}
    try { $arc.Dispose() } catch {}
    if ($totalClass -lt 5) { return ,$flags }
    $pct = { param($n) [math]::Round(($n / $totalClass) * 100) }
    $numPct = & $pct $numeric; $uniPct = & $pct $unicode; $fwPct = & $pct $fullw; $jpPct = & $pct $jp
    $s1Pct = & $pct $s1; $s2Pct = & $pct $s2; $gibPct = & $pct $gib; $novPct = & $pct $nov; $confPct = & $pct $conf
    if ($numPct -ge 20) { [void]$flags.Add('Numeric class names - ' + $numPct + '% of classes have numeric-only names') }
    if ($uniPct -ge 10) { [void]$flags.Add('Unicode class names - ' + $uniPct + '% of classes use non-ASCII characters') }
    if ($fwPct -gt 0) { [void]$flags.Add('Fullwidth Unicode class names - ' + $fwPct + '% use fullwidth chars (' + $fullw + ' classes)') }
    if ($jpPct -gt 0) { [void]$flags.Add('Japanese obfuscation - ' + $jpPct + '% use hiragana/katakana class names (' + $jp + ' classes)') }
    if ($s1Pct -ge 15) { [void]$flags.Add('Single-letter class names - ' + $s1Pct + '% (' + $s1 + ' classes)') }
    if ($s2Pct -ge 20) { [void]$flags.Add('Two-letter class names - ' + $s2Pct + '% (' + $s2 + ' classes)') }
    if ($gibPct -ge 5) { [void]$flags.Add('Gibberish class names - ' + $gibPct + '% have no vowels / consonant clusters (' + $gib + ' classes)') }
    if ($novPct -ge 8) { [void]$flags.Add('No-vowel class names - ' + $novPct + '% (' + $nov + ' classes)') }
    if ($confPct -ge 3) { [void]$flags.Add('Confusion-char names (Il1O0/_) - ' + $confPct + '% (' + $conf + ' classes)') }
    if ($singlePkg -ge 6) { [void]$flags.Add('Single-char package paths - ' + $singlePkg + ' path segments like a/b/c') }
    $sampleStr = $sample.ToString()
    $fwM = $script:MmFwRx.Matches($sampleStr)
    if ($fwM.Count -gt 0) {
        $ex = (@($fwM | Select-Object -First 3 | ForEach-Object { $_.Value }) -join ', ')
        [void]$flags.Add('Fullwidth strings in class content - ' + $fwM.Count + ' occurrences (e.g. ' + $ex + ')')
    }
    foreach ($on in $cheatObf.Keys) {
        foreach ($pt in $cheatObf[$on]) {
            if ($sampleStr.Contains($pt)) { [void]$flags.Add('Known cheat obfuscator detected - ' + $on + ' (matched: ' + $pt + ')'); break }
        }
    }
    return ,$flags
}

# ---- hash dogrulama (Modrinth / Megabase) ----
function Invoke-MmWeb([string]$uri) {
    if (-not $script:MmNet) { return $null }
    try {
        $r = Invoke-RestMethod -Uri $uri -Method Get -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        $script:MmFails = 0
        return $r
    } catch {
        $code = 0
        try { $code = [int]$_.Exception.Response.StatusCode } catch {}
        if ($code -ne 404 -and $code -ne 400) {
            $script:MmFails++
            if ($script:MmFails -ge 4) { $script:MmNet = $false }
        }
        return $null
    }
}
function Get-MmVerify([string]$hash) {
    $res = @{ Name = ''; Slug = ''; By = '' }
    if (-not $hash) { return $res }
    $vi = Invoke-MmWeb ('https://api.modrinth.com/v2/version_file/' + $hash)
    if ($vi -and $vi.project_id) {
        $pj = Invoke-MmWeb ('https://api.modrinth.com/v2/project/' + $vi.project_id)
        if ($pj -and $pj.slug) { $res.Name = [string]$pj.title; $res.Slug = [string]$pj.slug; $res.By = 'Modrinth'; return $res }
    }
    $mb = Invoke-MmWeb ('https://megabase.vercel.app/api/query?hash=' + $hash)
    if ($mb -and -not $mb.error -and $mb.data -and $mb.data.name) { $res.Name = [string]$mb.data.name; $res.By = 'Megabase' }
    return $res
}
function Get-MmSource([string]$path) {
    $zd = $null
    try { $zd = Get-Content -Raw -Stream Zone.Identifier -LiteralPath $path -ErrorAction Stop } catch {}
    if ($zd -and $zd -match 'HostUrl=(.+)') {
        $url = $Matches[1].Trim()
        if ($url -match 'mediafire\.com') { return 'MediaFire' }
        if ($url -match 'discord(app)?\.(com|net)') { return 'Discord' }
        if ($url -match 'dropbox\.com') { return 'Dropbox' }
        if ($url -match 'drive\.google\.com') { return 'Google Drive' }
        if ($url -match 'mega\.nz|mega\.co\.nz') { return 'MEGA' }
        if ($url -match 'github\.com') { return 'GitHub' }
        if ($url -match 'modrinth\.com') { return 'Modrinth' }
        if ($url -match 'curseforge\.com') { return 'CurseForge' }
        if ($url -match 'anydesk\.com') { return 'AnyDesk' }
        if ($url -match 'https?://(?:www\.)?([^/]+)') { return $Matches[1] }
        return $url
    }
    return ''
}
function Get-MmFlagScore([string]$f) {
    if ($f -match '^Fake mod identity') { return 70 }
    if ($f -match '^Runtime\.exec') { return 50 }
    if ($f -match '^HTTP POST') { return 50 }
    if ($f -match '^HTTP file download') { return 40 }
    if ($f -match '^Hollow shell') { return 45 }
    if ($f -match '^Suspicious nested JAR') { return 35 }
    if ($f -match '^Known cheat obfuscator') { return 45 }
    if ($f -match '^(Fullwidth|Japanese)') { return 45 }
    if ($f -match '^Heavy obfuscation') { return 35 }
    return 30
}

# ---- mod klasorlerini bul ----
$mmDirs = New-Object System.Collections.Generic.List[string]
$mmDirSeen = @{}
function Add-MmDir([string]$d) {
    if ([string]::IsNullOrWhiteSpace($d)) { return }
    if (-not (Test-Path -LiteralPath $d -PathType Container)) { return }
    $k = $d.TrimEnd('\').ToLower()
    if ($mmDirSeen.ContainsKey($k)) { return }
    $mmDirSeen[$k] = 1
    [void]$mmDirs.Add($d)
}
Add-MmDir ($env:APPDATA + '\.minecraft\mods')
foreach ($g in $script:GameDirs) { Add-MmDir ($g + '\mods') }
foreach ($pat in @(
    ($env:APPDATA + '\ModrinthApp\profiles\*\mods'),
    ($env:APPDATA + '\com.modrinth.theseus\profiles\*\mods'),
    ($env:APPDATA + '\PrismLauncher\instances\*\.minecraft\mods'),
    ($env:APPDATA + '\PrismLauncher\instances\*\minecraft\mods'),
    ($env:APPDATA + '\MultiMC\instances\*\.minecraft\mods'),
    ($env:USERPROFILE + '\curseforge\minecraft\Instances\*\mods'),
    ($env:APPDATA + '\ATLauncher\instances\*\mods'),
    ($env:APPDATA + '\.minecraft\versions\*\mods')
)) {
    foreach ($x in @(Get-ChildItem -Path $pat -Directory -ErrorAction SilentlyContinue)) { Add-MmDir $x.FullName }
}
$mmJars = New-Object System.Collections.Generic.List[object]
$mmJarSeen = @{}
foreach ($d in $mmDirs) {
    Log ('   mod klasoru: ' + $d) 'DarkGray'
    foreach ($j in @(Get-ChildItem -LiteralPath $d -File -Recurse -Depth 1 -Filter '*.jar' -Force -ErrorAction SilentlyContinue)) {
        $jk = $j.FullName.ToLower()
        if ($mmJarSeen.ContainsKey($jk)) { continue }
        $mmJarSeen[$jk] = 1
        [void]$mmJars.Add($j)
    }
}
if ($mmDirs.Count -eq 0) { Log '   mod klasoru bulunamadi (.minecraft\mods, calisan oyunun gameDir i, Modrinth/Prism/CurseForge/ATLauncher profilleri).' 'DarkGray' }
if ($mmDirs.Count -gt 0 -and $mmJars.Count -eq 0) { Log '   mod klasorleri var ama icinde .jar yok.' 'DarkGray' }
if ($mmJars.Count -gt 0 -and $script:MmNet) { Log '   NOT: mod dosyalarinin SHA1 hash i Modrinth/Megabase te sorgulanacak (dosya icerigi gonderilmez). Kapatmak icin: $env:HK_NONET=1' 'DarkGray' }

# ---- HIZLI MOTOR: 3 ayri PowerShell gecisi (string/bypass/obfuscation) tek gecisli, paralel C# tarayiciya birlestirildi; SHA1 hesabi paralel ----
$mmCs = @'
using System;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Net;
using System.Security.Cryptography;
using System.Threading.Tasks;
public sealed class HkTrie {
    sealed class Node { public Dictionary<char, Node> Kids; public bool End; }
    readonly Node root = new Node();
    readonly bool[] first = new bool[65536];
    readonly bool bounded;
    static bool IsAlpha(char c) { return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'); }
    public HkTrie(string[] words, bool bounded) {
        this.bounded = bounded;
        foreach (string w in words) {
            if (string.IsNullOrEmpty(w)) continue;
            Node nd = root;
            foreach (char c in w) {
                if (nd.Kids == null) nd.Kids = new Dictionary<char, Node>();
                Node nx;
                if (!nd.Kids.TryGetValue(c, out nx)) { nx = new Node(); nd.Kids[c] = nx; }
                nd = nx;
            }
            nd.End = true;
            first[w[0]] = true;
        }
    }
    // Regex alternation ile ayni semantik: en soldan, en uzun eslesme, sinir kontrolu (lookbehind/lookahead) ile.
    public void Collect(string text, HashSet<string> into) {
        int n = text.Length, i = 0;
        while (i < n) {
            if (!first[text[i]]) { i++; continue; }
            if (bounded && i > 0 && IsAlpha(text[i - 1])) { i++; continue; }
            Node nd = root; int j = i, best = -1;
            while (j < n) {
                Node nx;
                if (nd.Kids == null || !nd.Kids.TryGetValue(text[j], out nx)) break;
                nd = nx; j++;
                if (nd.End && (!bounded || j >= n || !IsAlpha(text[j]))) best = j;
            }
            if (best > 0) { into.Add(text.Substring(i, best - i)); i = best; } else i++;
        }
    }
}
public class HkMmRes {
    public string[] Patterns = new string[0];
    public string[] Strings = new string[0];
    public string[] Fullwidth = new string[0];
    public string[] Bypass = new string[0];
    public string[] Obf = new string[0];
}
public static class HkMm {
    const StringComparison SC = StringComparison.OrdinalIgnoreCase;
    static Regex RxNested = new Regex(@"^META-INF/jars/.+\.jar$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static Regex RxModId = new Regex(@"""id""\s*:\s*""([^""]+)""", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static Regex RxDanger = new Regex(@"Runtime\.exec|HTTP file download|HTTP POST|Heavy obfuscation|Suspicious nested JAR", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static Regex RxNum = new Regex(@"^\d+$", RegexOptions.Compiled);
    static Regex RxNonAscii = new Regex(@"[^\x00-\x7F]", RegexOptions.Compiled);
    static Regex RxFwChar = new Regex(@"[Ａ-Ｚａ-ｚ０-９]", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static Regex RxJp = new Regex(@"[぀-ゟ゠-ヿ]", RegexOptions.Compiled);
    static Regex RxS1 = new Regex(@"^[a-zA-Z]$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static Regex RxS2 = new Regex(@"^[a-zA-Z]{2}$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static Regex RxConf = new Regex(@"^[Il1O0]+$|^_+$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static Regex RxAlpha = new Regex(@"^[a-zA-Z]+$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static Regex RxCluster = new Regex(@"[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]{3,}", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static Dictionary<string, Regex> Cache = new Dictionary<string, Regex>();
    static readonly Encoding Lat1 = Encoding.GetEncoding(28591);
    static string[] LegitIds = new string[] { "vmp-fabric","vmp","lithium","sodium","iris","fabric-api","modmenu","ferrite-core","lazydfu","starlight","entityculling","memoryleakfix","krypton","c2me-fabric","smoothboot-fabric","immediatelyfast","noisium","threadtweak" };
    static string[] Pfx = new string[] { "com_","org_","net_","io_","dev_","gs_","xyz_","app_","me_","tv_","uk_","be_","fr_","de_" };
    static string[] ObfNames = new string[] { "Skidfuscator","Paramorphism","Radon","Caesium","Bozar","Branchlock","Binscure","SuperBlaubeere","Qprotect","Zelix","Stringer","JNIC","Scuti","Smoke" };
    static string[][] ObfPats = new string[][] {
        new string[] { "dev/skidfuscator", "Skidfuscator", "skidfuscator.dev" },
        new string[] { "Paramorphism", "paramorphism-", "dev/paramorphism" },
        new string[] { "ItzSomebody/Radon", "me/itzsomebody/radon", "Radon Obfuscator" },
        new string[] { "sim0n/Caesium", "Caesium Obfuscator", "dev/sim0n/caesium" },
        new string[] { "vimasig/Bozar", "Bozar Obfuscator", "com/bozar" },
        new string[] { "Branchlock", "branchlock.dev" },
        new string[] { "Binscure", "com/binscure" },
        new string[] { "superblaubeere", "superblaubeere27" },
        new string[] { "Qprotect", "QProtect", "mdma.dev/qprotect" },
        new string[] { "ZKMFLOW", "ZelixKlassMaster", "com/zelix" },
        new string[] { "StringerJavaObfuscator", "com/licel/stringer" },
        new string[] { "jnic.obf", "jnic-obfuscator" },
        new string[] { "ScutiObf", "scuti.obf" },
        new string[] { "SmokeObf", "smoke.obf" }
    };
    static Regex Get(string p) {
        lock (Cache) {
            Regex r;
            if (!Cache.TryGetValue(p, out r)) { r = new Regex(p, RegexOptions.Compiled); Cache[p] = r; }
            return r;
        }
    }
    static byte[] ReadAll(ZipArchiveEntry e, long max) {
        try {
            long len = e.Length;
            if (len > max) return null;
            using (Stream s = e.Open()) {
                byte[] b = new byte[len];
                int off = 0;
                while (off < len) {
                    int c = s.Read(b, off, (int)(len - off));
                    if (c <= 0) break;
                    off += c;
                }
                if (off != len) Array.Resize(ref b, off);
                return b;
            }
        } catch { return null; }
    }
    static string LastSeg(string n) { int i = n.LastIndexOf('/'); return i >= 0 ? n.Substring(i + 1) : n; }
    static string NoExt(string n) { int d = n.LastIndexOf('.'); return d >= 0 ? n.Substring(0, d) : n; }
    static bool JarNameSus(string jarName) {
        string b = NoExt(jarName);
        foreach (char c in b) { if (char.IsDigit(c)) return false; }
        string lo = b.ToLowerInvariant();
        foreach (string p in Pfx) { if (lo.StartsWith(p, StringComparison.Ordinal)) return false; }
        if (b.Length > 20) return false;
        return true;
    }
    static int Pct(int n, int total) { return (int)Math.Round(((double)n / total) * 100.0); }
    static string[] ToArr(HashSet<string> h) { string[] a = new string[h.Count]; h.CopyTo(a); return a; }

    public static HkMmRes Scan(string path, HkTrie pat, HkTrie str, Regex fw, string[] fwPool) {
        HkMmRes r = new HkMmRes();
        ZipArchive zip = null;
        List<ZipArchive> inners = new List<ZipArchive>();
        try { zip = ZipFile.OpenRead(path); } catch { return r; }
        try {
            List<ZipArchiveEntry> entries = new List<ZipArchiveEntry>();
            List<ZipArchiveEntry> nested = new List<ZipArchiveEntry>();
            foreach (ZipArchiveEntry e in zip.Entries) entries.Add(e);
            int outerCount = entries.Count;
            for (int i = 0; i < outerCount; i++) {
                ZipArchiveEntry e = entries[i];
                if (RxNested.IsMatch(e.FullName)) {
                    nested.Add(e);
                    if (e.Length > 0 && e.Length < 31457280) {
                        try {
                            byte[] nb = ReadAll(e, 31457280);
                            if (nb != null) {
                                ZipArchive iz = new ZipArchive(new MemoryStream(nb), ZipArchiveMode.Read);
                                inners.Add(iz);
                                foreach (ZipArchiveEntry ie in iz.Entries) entries.Add(ie);
                            }
                        } catch { }
                    }
                }
            }
            HashSet<string> pats = new HashSet<string>();
            HashSet<string> strs = new HashSet<string>();
            HashSet<string> fws = new HashSet<string>();
            List<string> bypass = new List<string>();
            List<string> obf = new List<string>();

            // --- bypass: ic ice jar ve kabuk jar kontrolleri ---
            int outerClasses = 0;
            for (int i = 0; i < outerCount; i++) { if (entries[i].FullName.EndsWith(".class", SC)) outerClasses++; }
            string modId = "";
            for (int i = 0; i < outerCount; i++) {
                if (string.Equals(entries[i].FullName, "fabric.mod.json", SC)) {
                    byte[] fb = ReadAll(entries[i], 262144);
                    if (fb != null) { Match mm = RxModId.Match(Encoding.UTF8.GetString(fb)); if (mm.Success) modId = mm.Groups[1].Value; }
                    break;
                }
            }
            foreach (ZipArchiveEntry nj in nested) {
                string njBase = LastSeg(nj.FullName);
                if (JarNameSus(njBase)) bypass.Add("Suspicious nested JAR - no version, unknown dependency: " + njBase);
            }
            if (nested.Count == 1 && outerClasses < 3) bypass.Add("Hollow shell - only " + outerClasses + " own class(es), wraps: " + LastSeg(nested[0].FullName));

            // --- ad desenleri (tum girdiler) ---
            foreach (ZipArchiveEntry e in entries) { pat.Collect(e.FullName, pats); }

            bool rtExec = false, httpDl = false, httpExfil = false;
            int obfN = 0, numN = 0, uniN = 0, totN = 0;
            int tc = 0, numeric = 0, unicode = 0, fullw = 0, jp = 0, s1 = 0, s2 = 0, gib = 0, nov = 0, conf = 0, singlePkg = 0;
            StringBuilder sample = new StringBuilder();
            int sampleSize = 0;

            for (int i = 0; i < entries.Count; i++) {
                ZipArchiveEntry e = entries[i];
                string n = e.FullName;
                bool isClass = n.EndsWith(".class", SC);
                bool isTxt = isClass || n.EndsWith(".json", SC) || n.IndexOf("MANIFEST.MF", SC) >= 0;
                byte[] bytes = null;
                if (isTxt) bytes = ReadAll(e, 3145728);
                if (bytes != null) {
                    try {
                        string t = Encoding.UTF8.GetString(bytes);
                        pat.Collect(t, pats);
                        str.Collect(t, strs);
                        foreach (Match m in fw.Matches(t)) fws.Add(m.Value);
                    } catch { }
                }
                if (!isClass) continue;
                string last = LastSeg(n);
                string cn = NoExt(last);
                string nm = n.Substring(0, n.Length - 6);
                string[] segs = nm.Split('/');
                // bypass sayaclari (tum class lar)
                totN++;
                if (RxNum.IsMatch(cn)) numN++;
                if (RxNonAscii.IsMatch(cn)) uniN++;
                int cons = 0, maxC = 0;
                foreach (string sg in segs) { if (sg.Length == 1) { cons++; if (cons > maxC) maxC = cons; } else cons = 0; }
                if (maxC >= 3) obfN++;
                if (bytes != null && bytes.Length <= 2097152 && !(rtExec && httpDl && httpExfil)) {
                    string ct = Lat1.GetString(bytes);
                    if (!rtExec && ct.Contains("java/lang/Runtime") && ct.Contains("getRuntime") && ct.Contains("exec")) rtExec = true;
                    if (!httpDl && ct.Contains("openConnection") && ct.Contains("HttpURLConnection") && ct.Contains("FileOutputStream")) httpDl = true;
                    if (!httpExfil && ct.Contains("openConnection") && ct.Contains("setDoOutput") && ct.Contains("getOutputStream") && ct.Contains("getProperty")) httpExfil = true;
                }
                // obfuscation sayaclari (sadece dis jar class lari)
                if (i < outerCount) {
                    tc++;
                    if (RxNum.IsMatch(cn)) numeric++;
                    if (RxNonAscii.IsMatch(cn)) unicode++;
                    if (RxFwChar.IsMatch(cn)) fullw++;
                    if (RxJp.IsMatch(cn)) jp++;
                    if (RxS1.IsMatch(cn)) s1++;
                    if (RxS2.IsMatch(cn)) s2++;
                    if (RxConf.IsMatch(cn)) conf++;
                    if (cn.Length >= 3 && cn.Length <= 8 && RxAlpha.IsMatch(cn)) {
                        int vow = 0;
                        foreach (char ch in cn) { if ("aeiouAEIOU".IndexOf(ch) >= 0) vow++; }
                        if (vow == 0) nov++;
                        if (RxCluster.IsMatch(cn) && ((double)vow / cn.Length) < 0.3) gib++;
                    }
                    if (segs.Length > 1) { for (int q = 0; q < segs.Length - 1; q++) { if (segs[q].Length == 1) singlePkg++; } }
                    if (sampleSize < 150000 && e.Length < 100000 && e.Length > 100 && bytes != null) {
                        string asx = Encoding.ASCII.GetString(bytes);
                        sample.Append(asx);
                        sampleSize += asx.Length;
                    }
                }
            }

            // --- bypass sonuc bayraklari ---
            int obfPct = 0, numPct = 0, uniPct = 0;
            if (totN >= 10) obfPct = Pct(obfN, totN);
            if (totN >= 5) { numPct = Pct(numN, totN); uniPct = Pct(uniN, totN); }
            if (rtExec && obfPct >= 25) bypass.Add("Runtime.exec() in obfuscated code - can run arbitrary OS commands");
            if (httpDl) bypass.Add("HTTP file download - fetches and writes files from a remote server at runtime");
            if (httpExfil) bypass.Add("HTTP POST exfiltration - sends system data to an external server");
            if (totN >= 10 && obfPct >= 25) bypass.Add("Heavy obfuscation - " + obfPct + "% of classes use single-letter path segments (a/b/c style)");
            if (numPct >= 20) bypass.Add("Numeric class names - " + numPct + "% of classes have numeric-only names");
            if (uniPct >= 10) bypass.Add("Unicode class names - " + uniPct + "% of classes use non-ASCII characters");
            int danger = 0;
            foreach (string f in bypass) { if (RxDanger.IsMatch(f)) danger++; }
            if (modId.Length > 0 && danger > 0) {
                foreach (string lg in LegitIds) {
                    if (string.Equals(lg, modId, SC)) { bypass.Add("Fake mod identity - claims to be '" + modId + "' but contains dangerous code"); break; }
                }
            }

            // --- obfuscation sonuc bayraklari ---
            if (tc >= 5) {
                int numPct2 = Pct(numeric, tc), uniPct2 = Pct(unicode, tc), fwPct = Pct(fullw, tc), jpPct = Pct(jp, tc);
                int s1Pct = Pct(s1, tc), s2Pct = Pct(s2, tc), gibPct = Pct(gib, tc), novPct = Pct(nov, tc), confPct = Pct(conf, tc);
                if (numPct2 >= 20) obf.Add("Numeric class names - " + numPct2 + "% of classes have numeric-only names");
                if (uniPct2 >= 10) obf.Add("Unicode class names - " + uniPct2 + "% of classes use non-ASCII characters");
                if (fwPct > 0) obf.Add("Fullwidth Unicode class names - " + fwPct + "% use fullwidth chars (" + fullw + " classes)");
                if (jpPct > 0) obf.Add("Japanese obfuscation - " + jpPct + "% use hiragana/katakana class names (" + jp + " classes)");
                if (s1Pct >= 15) obf.Add("Single-letter class names - " + s1Pct + "% (" + s1 + " classes)");
                if (s2Pct >= 20) obf.Add("Two-letter class names - " + s2Pct + "% (" + s2 + " classes)");
                if (gibPct >= 5) obf.Add("Gibberish class names - " + gibPct + "% have no vowels / consonant clusters (" + gib + " classes)");
                if (novPct >= 8) obf.Add("No-vowel class names - " + novPct + "% (" + nov + " classes)");
                if (confPct >= 3) obf.Add("Confusion-char names (Il1O0/_) - " + confPct + "% (" + conf + " classes)");
                if (singlePkg >= 6) obf.Add("Single-char package paths - " + singlePkg + " path segments like a/b/c");
                string sampleStr = sample.ToString();
                MatchCollection fwM = fw.Matches(sampleStr);
                if (fwM.Count > 0) {
                    List<string> ex = new List<string>();
                    for (int q = 0; q < fwM.Count && q < 3; q++) ex.Add(fwM[q].Value);
                    obf.Add("Fullwidth strings in class content - " + fwM.Count + " occurrences (e.g. " + string.Join(", ", ex.ToArray()) + ")");
                }
                for (int q = 0; q < ObfNames.Length; q++) {
                    foreach (string pt in ObfPats[q]) {
                        if (sampleStr.Contains(pt)) { obf.Add("Known cheat obfuscator detected - " + ObfNames[q] + " (matched: " + pt + ")"); break; }
                    }
                }
            }

            // --- fullwidth cozumleme ---
            List<string> resolved = new List<string>();
            HashSet<string> resSet = new HashSet<string>();
            foreach (string f in fws) {
                if (f.Length < 3) continue;
                string best = null;
                foreach (string cs in fwPool) { if (cs.Contains(f)) { if (best == null || cs.Length < best.Length) best = cs; } }
                if (best != null) { if (resSet.Add(best)) resolved.Add(best); }
                else if (f.Length >= 6) { if (resSet.Add(f)) resolved.Add(f); }
            }
            List<string> finalFw = new List<string>();
            foreach (string f in resolved) {
                bool red = false;
                foreach (string o in resolved) { if (f.Length < o.Length && o.Contains(f)) { red = true; break; } }
                if (!red) finalFw.Add(f);
            }
            r.Patterns = ToArr(pats);
            r.Strings = ToArr(strs);
            r.Fullwidth = finalFw.ToArray();
            r.Bypass = bypass.ToArray();
            r.Obf = obf.ToArray();
        } catch { }
        finally {
            foreach (ZipArchive iz in inners) { try { iz.Dispose(); } catch { } }
            try { zip.Dispose(); } catch { }
        }
        return r;
    }
    public static HkMmRes[] ScanMany(string[] paths, string[] patList, string[] strList, string fwRx, string[] fwPool, int threads) {
        HkTrie pat = new HkTrie(patList, true);
        HkTrie str = new HkTrie(strList, false);
        Regex fw = Get(fwRx);
        HkMmRes[] res = new HkMmRes[paths.Length];
        ParallelOptions po = new ParallelOptions();
        po.MaxDegreeOfParallelism = threads;
        Parallel.For(0, paths.Length, po, delegate(int i) {
            System.Threading.Thread th = System.Threading.Thread.CurrentThread;
            System.Threading.ThreadPriority oldP = th.Priority;
            try { th.Priority = System.Threading.ThreadPriority.BelowNormal; } catch { }
            try { res[i] = Scan(paths[i], pat, str, fw, fwPool); } catch { res[i] = new HkMmRes(); }
            finally { try { th.Priority = oldP; } catch { } }
        });
        return res;
    }
    public static string[] Sha1Many(string[] paths, int threads) {
        string[] res = new string[paths.Length];
        ParallelOptions po = new ParallelOptions();
        po.MaxDegreeOfParallelism = threads;
        Parallel.For(0, paths.Length, po, delegate(int i) {
            try {
                using (FileStream fs = new FileStream(paths[i], FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                using (SHA1 sha = SHA1.Create()) {
                    byte[] h = sha.ComputeHash(fs);
                    StringBuilder sb = new StringBuilder();
                    foreach (byte b in h) sb.Append(b.ToString("X2"));
                    res[i] = sb.ToString();
                }
            } catch { res[i] = ""; }
        });
        return res;
    }
    // null = ag hatasi, "" = sunucu yanit verdi ama kayit yok (404/400), diger = govde
    public static string[] FetchMany(string[] urls, int timeoutMs, int threads) {
        string[] res = new string[urls.Length];
        ServicePointManager.DefaultConnectionLimit = Math.Max(16, threads * 2);
        ParallelOptions po = new ParallelOptions();
        po.MaxDegreeOfParallelism = threads;
        Parallel.For(0, urls.Length, po, delegate(int i) {
            try {
                HttpWebRequest rq = (HttpWebRequest)WebRequest.Create(urls[i]);
                rq.Timeout = timeoutMs;
                rq.ReadWriteTimeout = timeoutMs;
                rq.UserAgent = "HileKiran/1.0";
                using (HttpWebResponse rs = (HttpWebResponse)rq.GetResponse())
                using (StreamReader sr = new StreamReader(rs.GetResponseStream(), Encoding.UTF8)) { res[i] = sr.ReadToEnd(); }
            } catch (WebException ex) {
                HttpWebResponse er = ex.Response as HttpWebResponse;
                if (er != null) { int code = (int)er.StatusCode; er.Close(); res[i] = (code == 404 || code == 400) ? "" : null; }
                else res[i] = null;
            } catch { res[i] = null; }
        });
        return res;
    }
}
'@
$mmCsOk = $false
try {
    if (-not ('HkMm' -as [type])) { Add-Type -TypeDefinition $mmCs -Language CSharp -ReferencedAssemblies @('System.IO.Compression', 'System.IO.Compression.FileSystem') -ErrorAction Stop }
    $mmCsOk = $true
} catch { Log ('   UYARI: hizli mod motoru derlenemedi, yavas yola donuluyor: ' + $_.Exception.Message) 'DarkYellow' }

# Toplu hash dogrulama: Modrinth tek istekte (version_files + projects), bulunamayanlar Megabase te paralel
function Get-MmVerifyMany([string[]]$hashes) {
    $out = @{}
    if (-not $script:MmNet -or -not $hashes -or $hashes.Count -eq 0) { return $out }
    $lower = @($hashes | Where-Object { $_ } | ForEach-Object { $_.ToLower() } | Select-Object -Unique)
    $vers = @{}
    $bulkOk = $true
    for ($i = 0; $i -lt $lower.Count; $i += 200) {
        $hi = [Math]::Min($i + 199, $lower.Count - 1)
        $chunk = @($lower[$i..$hi])
        $body = '{"hashes":[' + (($chunk | ForEach-Object { '"' + $_ + '"' }) -join ',') + '],"algorithm":"sha1"}'
        try {
            $resp = Invoke-RestMethod -Uri 'https://api.modrinth.com/v2/version_files' -Method Post -Body $body -ContentType 'application/json' -UserAgent 'HileKiran/1.0' -TimeoutSec 30 -ErrorAction Stop
            if ($resp) { foreach ($p in $resp.PSObject.Properties) { if ($p.Value -and $p.Value.project_id) { $vers[$p.Name.ToLower()] = [string]$p.Value.project_id } } }
        } catch { $bulkOk = $false }
    }
    if (-not $bulkOk) {
        # toplu sorgu basarisiz: eski (tek tek) yontem, 4 ardisik hatada ag kapanir
        foreach ($h in $lower) {
            if (-not $script:MmNet) { break }
            $v = Get-MmVerify $h
            if ($v.By) { $out[$h.ToUpper()] = $v }
        }
        return $out
    }
    $projInfo = @{}
    $projIds = @($vers.Values | Select-Object -Unique)
    for ($i = 0; $i -lt $projIds.Count; $i += 100) {
        $hi = [Math]::Min($i + 99, $projIds.Count - 1)
        $c = @($projIds[$i..$hi])
        $idsJson = '[' + (($c | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'
        try {
            $pr = Invoke-RestMethod -Uri ('https://api.modrinth.com/v2/projects?ids=' + [uri]::EscapeDataString($idsJson)) -UserAgent 'HileKiran/1.0' -TimeoutSec 30 -ErrorAction Stop
            foreach ($pj in @($pr)) { if ($pj -and $pj.id) { $projInfo[[string]$pj.id] = $pj } }
        } catch {}
    }
    $rest = New-Object System.Collections.Generic.List[string]
    foreach ($h in $lower) {
        if ($vers.ContainsKey($h) -and $projInfo.ContainsKey($vers[$h])) {
            $pj = $projInfo[$vers[$h]]
            $out[$h.ToUpper()] = @{ Name = [string]$pj.title; Slug = [string]$pj.slug; By = 'Modrinth' }
        } else { [void]$rest.Add($h) }
    }
    if ($rest.Count -gt 0 -and $script:MmNet) {
        $mbRes = $null
        if ($mmCsOk) {
            $urls = [string[]]@($rest | ForEach-Object { 'https://megabase.vercel.app/api/query?hash=' + $_.ToUpper() })
            try { $mbRes = [HkMm]::FetchMany($urls, 8000, 8) } catch {}
        }
        if ($mbRes) {
            $okN = 0
            for ($k = 0; $k -lt $rest.Count; $k++) {
                $s = $mbRes[$k]
                if ($null -eq $s) { continue }
                $okN++
                if (-not $s) { continue }
                try {
                    $j = $s | ConvertFrom-Json -ErrorAction Stop
                    if ($j -and -not $j.error -and $j.data -and $j.data.name) { $out[$rest[$k].ToUpper()] = @{ Name = [string]$j.data.name; Slug = ''; By = 'Megabase' } }
                } catch {}
            }
            if ($okN -eq 0) { $script:MmNet = $false }
        } else {
            foreach ($h in $rest) {
                if (-not $script:MmNet) { break }
                $mb = Invoke-MmWeb ('https://megabase.vercel.app/api/query?hash=' + $h.ToUpper())
                if ($mb -and -not $mb.error -and $mb.data -and $mb.data.name) { $out[$h.ToUpper()] = @{ Name = [string]$mb.data.name; Slug = ''; By = 'Megabase' } }
            }
        }
    }
    return $out
}

$mmVerified = New-Object System.Collections.Generic.List[string]
$mmUnknown = New-Object System.Collections.Generic.List[string]
$mmCntSus = 0; $mmCntByp = 0; $mmCntObf = 0
$mmWhite = @('viafabricplus', 'viafabricversion')
$mmThr = [Math]::Max(2, [Math]::Min(4, [Math]::Max(2, [int]([Environment]::ProcessorCount / 2))))
$mmPaths = [string[]]@($mmJars | ForEach-Object { $_.FullName })

# 1) SHA1 (paralel)
$mmHashMap = @{}
if ($mmJars.Count -gt 0) {
    Set-Frac 0.02 'sha1 hesaplaniyor'
    $hs = $null
    if ($mmCsOk) { try { $hs = [HkMm]::Sha1Many($mmPaths, $mmThr) } catch {} }
    for ($i = 0; $i -lt $mmPaths.Count; $i++) {
        $h = ''
        if ($hs -and $hs[$i]) { $h = [string]$hs[$i] } else { try { $h = (Get-FileHash -LiteralPath $mmPaths[$i] -Algorithm SHA1 -ErrorAction Stop).Hash } catch {} }
        $mmHashMap[$mmPaths[$i]] = $h
    }
}
# 2) Hash dogrulama (toplu)
Set-Frac 0.05 'hash dogrulamasi (toplu)'
$mmVerMap = @{}
if ($mmJars.Count -gt 0) { $mmVerMap = Get-MmVerifyMany ([string[]]@($mmHashMap.Values | Where-Object { $_ })) }
# 3) Icerik taramasi (tek gecis, paralel); buyuk dosyalar once
$mmScanRes = @{}
if ($mmCsOk) {
    $mmToScan = New-Object System.Collections.Generic.List[object]
    foreach ($jar in $mmJars) {
        $h0 = $mmHashMap[$jar.FullName]
        if ($h0 -and $mmVerMap.ContainsKey($h0) -and ($mmWhite -contains ([string]$mmVerMap[$h0].Slug).ToLower())) { continue }
        if ($jar.Length -gt 157286400) { continue }
        [void]$mmToScan.Add($jar)
    }
    $mmSorted = @($mmToScan | Sort-Object Length -Descending)
    Log ('   ' + $mmSorted.Count + ' mod tek gecisli paralel motorla taraniyor (' + $mmThr + ' is parcacigi)...') 'DarkGray'
    $mmSw = [Diagnostics.Stopwatch]::StartNew()
    for ($ci = 0; $ci -lt $mmSorted.Count; $ci += 24) {
        $hi = [Math]::Min($ci + 23, $mmSorted.Count - 1)
        $paths = [string[]]@($mmSorted[$ci..$hi] | ForEach-Object { $_.FullName })
        $res = $null
        try { $res = [HkMm]::ScanMany($paths, [string[]]@($mmPatSorted), [string[]]@($mmStrSorted), $script:MmFwRx.ToString(), [string[]]@($script:MmFwPool), $mmThr) } catch {}
        if ($res) { for ($k = 0; $k -lt $paths.Count; $k++) { $mmScanRes[$paths[$k]] = $res[$k] } }
        $dn = [Math]::Min($ci + 24, $mmSorted.Count)
        Set-Frac (0.1 + 0.9 * $dn / [Math]::Max(1, $mmSorted.Count)) ('mod ' + $dn + '/' + $mmSorted.Count)
        Start-Sleep -Milliseconds 120
        Write-Host ('   mod ilerleme: ' + $dn + '/' + $mmSorted.Count + ' (' + [int]$mmSw.Elapsed.TotalSeconds + ' sn)') -ForegroundColor DarkGray
    }
}
foreach ($jar in $mmJars) {
    $jp = $jar.FullName
    $hash = $mmHashMap[$jp]
    $ver = @{ Name = ''; Slug = ''; By = '' }
    if ($hash -and $mmVerMap.ContainsKey($hash)) { $ver = $mmVerMap[$hash] }
    $isVer = [bool]$ver.By
    if ($isVer -and ($mmWhite -contains ([string]$ver.Slug).ToLower())) { [void]$mmVerified.Add($ver.Name + ' -> ' + $jar.Name); continue }
    if ($jar.Length -gt 157286400) {
        Add-F -Kaynak 'Mod klasoru analizi' -Ad ('mod: ' + $jar.Name.ToLower()) -Yol $jp -Skor 12 -Son $jar.LastWriteTime -Ilk $jar.CreationTime -Var 'Evet' -Not 'mod 150 MB ustu, derin tarama atlandi'
        continue
    }
    $ms = $null; $bf = @(); $of = @()
    if ($mmCsOk) {
        $rr = $null
        if ($mmScanRes.ContainsKey($jp)) { $rr = $mmScanRes[$jp] }
        if ($rr) {
            $ms = @{ Patterns = @($rr.Patterns); Strings = @($rr.Strings); Fullwidth = @($rr.Fullwidth) }
            $bf = @($rr.Bypass)
            $of = @($rr.Obf)
        }
    } else {
        try { $ms = Invoke-ModScan $jp } catch {}
        try { $bf = @(Invoke-MmBypassScan $jp) } catch {}
        try { $of = @(Invoke-MmObfScan $jp) } catch {}
    }
    $hitSet = New-Object 'System.Collections.Generic.HashSet[string]'
    $fwList = @()
    if ($ms) {
        foreach ($x in $ms.Patterns) { [void]$hitSet.Add($x) }
        foreach ($x in $ms.Strings) { [void]$hitSet.Add($x) }
        $fwList = @($ms.Fullwidth)
    }
    $hitN = $hitSet.Count
    $fwN = $fwList.Count
    $sc1 = 0
    if ($hitN -ge 6) { $sc1 = 80 } elseif ($hitN -ge 4) { $sc1 = 65 } elseif ($hitN -eq 3) { $sc1 = 55 } elseif ($hitN -eq 2) { $sc1 = 45 } elseif ($hitN -eq 1) { $sc1 = 30 }
    if ($fwN -gt 0) { $sc1 = [Math]::Max($sc1, 50); if ($fwN -ge 2) { $sc1 += 10 } }
    $sc2 = 0
    foreach ($f in $bf) { $fs2 = Get-MmFlagScore $f; if ($fs2 -gt $sc2) { $sc2 = $fs2 } }
    if ($bf.Count -gt 1) { $sc2 += 5 * ($bf.Count - 1) }
    $sc3 = 0
    foreach ($f in $of) { $fs3 = Get-MmFlagScore $f; if ($fs3 -gt $sc3) { $sc3 = $fs3 } }
    if ($of.Count -gt 1) { $sc3 += 3 * ($of.Count - 1) }
    $cats = 0
    if ($sc1 -gt 0) { $cats++; $mmCntSus++ }
    if ($sc2 -gt 0) { $cats++; $mmCntByp++ }
    if ($sc3 -gt 0) { $cats++; $mmCntObf++ }
    $why = New-Object System.Collections.Generic.List[string]
    if ($isVer) { [void]$why.Add($ver.By + ' hash eslesmesi: ' + $ver.Name) }
    if ($hitN -gt 0) { [void]$why.Add('hile stringleri/desenleri (' + $hitN + '): ' + ((@($hitSet | Select-Object -First 15)) -join ', ')) }
    if ($fwN -gt 0) { [void]$why.Add('tam genislikli (fullwidth) unicode stringler: ' + ((@($fwList | Select-Object -First 10)) -join ', ')) }
    if ($bf.Count -gt 0) { [void]$why.Add('BYPASS/ENJEKSIYON: ' + ($bf -join ' | ')) }
    if ($of.Count -gt 0) {
        [void]$why.Add('OBFUSCATION: ' + ($of -join ' | '))
        Add-ObfNote $jp ('mod obfuscation izleri: ' + ((@($of | Select-Object -First 3)) -join ' | '))
    }
    $src = Get-MmSource $jp
    if ($cats -eq 0) {
        if ($isVer) { [void]$mmVerified.Add($ver.Name + ' -> ' + $jar.Name) }
        else {
            [void]$mmUnknown.Add($jar.Name + $(if ($src) { ' (kaynak: ' + $src + ')' } else { '' }))
            $usc = 12
            if ($src -match '^(Discord|MediaFire|MEGA|Dropbox|Google Drive|AnyDesk)$') { $usc = 27 }
            $unote = 'Modrinth/Megabase te hash eslesmesi yok (ozel/eski/degistirilmis mod olabilir)'
            if (-not $script:MmNet) { $unote = 'hash dogrulamasi yapilamadi (ag kapali/erisilemedi)' }
            if ($src) { $unote = $unote + ' | indirme kaynagi: ' + $src }
            Add-F -Kaynak 'Mod klasoru analizi' -Ad ('mod: ' + $jar.Name.ToLower()) -Yol $jp -Skor $usc -Son $jar.LastWriteTime -Ilk $jar.CreationTime -Var 'Evet' -Not $unote
        }
        continue
    }
    $total = [Math]::Max($sc1, [Math]::Max($sc2, $sc3)) + 8 * ($cats - 1)
    if ($isVer) { $total -= 25; [void]$why.Add('(dogrulanmis modda skor 25 dusuruldu; yine de kontrol et)') }
    if ($total -lt 10) { $total = 10 }
    if ($total -gt 100) { $total = 100 }
    if (-not $isVer) { [void]$mmUnknown.Add($jar.Name + $(if ($src) { ' (kaynak: ' + $src + ')' } else { '' })) }
    if ($src) { [void]$why.Add('indirme kaynagi: ' + $src) }
    Add-F -Kaynak 'Mod klasoru analizi' -Ad ('mod: ' + $jar.Name.ToLower()) -Yol $jp -Skor $total -Son $jar.LastWriteTime -Ilk $jar.CreationTime -Var 'Evet' -Not (($why -join ' ; ') + ' | SHA1: ' + $hash)
}
Log ('   ' + $mmJars.Count + ' mod incelendi: ' + $mmVerified.Count + ' dogrulanmis, ' + $mmUnknown.Count + ' bilinmeyen, ' + $mmCntSus + ' supheli string, ' + $mmCntByp + ' bypass/enjeksiyon, ' + $mmCntObf + ' obfuscated.') 'DarkGray'
if ($mmJars.Count -gt 0 -and -not $script:MmNet -and $env:HK_NONET -ne '1') { Log '   UYARI: ag erisimi basarisiz oldu, hash dogrulamasi yarida birakildi (bilinmeyen sayisi sisik olabilir).' 'DarkYellow' }
foreach ($vm in @($mmVerified | Select-Object -First 40)) { Log ('   dogrulanmis: ' + $vm) 'DarkGray' }
foreach ($um in @($mmUnknown | Select-Object -First 40)) { Log ('   bilinmeyen : ' + $um) 'DarkGray' }

# ---- calisan Java: JVM agent / enjeksiyon bayraklari ----
$legitAgents = 'jmxremote|yjp|jrebel|newrelic|jacoco|theseus'
foreach ($jpr in @(Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" -ErrorAction SilentlyContinue)) {
    $cl = [string]$jpr.CommandLine
    if (-not $cl) { continue }
    foreach ($am in [regex]::Matches($cl, '-javaagent:(?:"([^"]+)"|([^\s"]+))')) {
        $ap = $am.Groups[1].Value
        if (-not $ap) { $ap = $am.Groups[2].Value }
        $eq = $ap.IndexOf('=')
        if ($eq -gt 0) { $ap = $ap.Substring(0, $eq) }
        $an = ''
        try { $an = [IO.Path]::GetFileName($ap) } catch {}
        if ($an -match $legitAgents) { continue }
        Add-Sys ('JVM agent: -javaagent:' + $an) 40 'Calisan Java a -javaagent ile dis kod yuklenmis (Lunar/Badlion gibi launcher lar da kullanabilir; dosyanin ne oldugunu kontrol et).' $jpr.CreationDate ('PID ' + $jpr.ProcessId + ' | yol: ' + $ap)
    }
    foreach ($sf in @(
        @('-Xbootclasspath/p:', 'bootstrap classpath in basina ekler, cekirdek Java siniflarini degistirebilir', 45),
        @('-Xbootclasspath/a:', 'bootstrap classpath e ekler, class loader in altina kod enjekte eder', 45),
        @('-agentlib:jdwp', 'JDWP hata ayiklama ajani, uzaktan debug acik', 35),
        @('-agentpath:', 'yerel (native) ajan yuklenmis, Java sandbox ini atlar', 45)
    )) {
        if ($cl.IndexOf($sf[0], [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            Add-Sys ('Supheli JVM parametresi: ' + $sf[0]) $sf[2] ('Calisan Java: ' + $sf[1]) $jpr.CreationDate ('PID ' + $jpr.ProcessId)
        }
    }
}
Show-Section

# ---------------------------------------------------------------------
Step '[11/17] Dosya taramasi (Downloads, Masaustu, Belgeler, Temp, AppData/Roaming, launcher klasorleri)...'
Start-Sec
Add-Root (Get-DownloadsPath)
Add-Root ([Environment]::GetFolderPath('Desktop'))
Add-Root ([Environment]::GetFolderPath('MyDocuments'))
Add-Root $env:APPDATA
Add-Root $env:TEMP
Add-Root ($env:WINDIR + '\Temp')
foreach ($gd in $script:GameDirs) { Add-Root $gd }
Add-Root ($env:ProgramData + '\Microsoft\Windows\Start Menu\Programs\StartUp')
Add-Root ($env:APPDATA + '\Microsoft\Windows\Start Menu\Programs\Startup')
foreach ($base in @($env:LOCALAPPDATA, $UP, $env:ProgramData, $env:ProgramFiles, ${env:ProgramFiles(x86)}, ($env:SystemDrive + '\'))) {
    if (-not $base) { continue }
    foreach ($d in @(Get-ChildItem -LiteralPath $base -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($d.Name -match $script:LauncherRx -or ($base -eq $UP -and $d.Name -match '(?i)^\.(minecraft|lunarclient|tlauncher|badlion|feather|ichor)')) { Add-Root $d.FullName }
    }
}
$walkCs = @'
using System;
using System.Collections.Generic;
using System.IO;
public static class HkWalk {
    static readonly HashSet<string> Codes = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".exe", ".dll", ".jar", ".bat", ".cmd", ".ps1", ".vbs", ".scr", ".msi", ".com", ".zip", ".rar", ".7z" };
    public static List<string> CodeFiles(string root, int maxFiles) {
        List<string> res = new List<string>();
        Stack<string> st = new Stack<string>();
        st.Push(root);
        while (st.Count > 0 && res.Count < maxFiles) {
            string d = st.Pop();
            try {
                foreach (string f in Directory.GetFiles(d)) { if (Codes.Contains(Path.GetExtension(f))) res.Add(f); }
                foreach (string sd in Directory.GetDirectories(d)) {
                    try { if ((File.GetAttributes(sd) & FileAttributes.ReparsePoint) != 0) continue; } catch { continue; }
                    st.Push(sd);
                }
            } catch { }
        }
        return res;
    }
}
'@
$script:WalkOk = $false
try { Add-Type -TypeDefinition $walkCs -Language CSharp -ErrorAction Stop; $script:WalkOk = $true } catch {}
# Tarayici/uygulama onbellek klasorleri (yuz binlerce anlamsiz dosya): icerigi gezilmez, sadece icindeki kod/arsiv dosyalari yine incelenir
$pruneRx = '(?i)^(node_modules|Cache|Code Cache|GPUCache|CacheStorage|Service Worker|IndexedDB|Local Storage|Session Storage|Crashpad|blob_storage|\.git)$'
function Walk-Root([string]$root) {
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        $items = $null
        try { $items = (New-Object IO.DirectoryInfo $d).GetFileSystemInfos() } catch { continue }
        foreach ($it in $items) {
            if ($it -is [IO.DirectoryInfo]) {
                if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                if ($it.Name -match $pruneRx) {
                    if ($script:WalkOk) {
                        $cl = $null
                        try { $cl = [HkWalk]::CodeFiles($it.FullName, 1000000) } catch {}
                        foreach ($cp in @($cl)) { if ($cp) { try { Inspect-File (New-Object IO.FileInfo $cp) } catch {} } }
                    }
                    continue
                }
                $stack.Push($it.FullName)
            } else {
                Inspect-File $it
            }
        }
    }
}
foreach ($root in $script:ScanRoots) {
    Log ('   taraniyor: ' + $root) 'DarkGray'
    if ($script:WalkOk) {
        Walk-Root $root
    } else {
        Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object { Inspect-File $_ }
    }
}
Write-Host ''
Log ('   ' + $script:fileCount + ' dosya incelendi.') 'DarkGray'

# --- Phantom Client: JVM args ile calisan, dosya icermeyen hile. launcher_profiles.json (JavaArgs) + surum/feather json dosyalari taranir ---
$script:PhantomRx = New-Object System.Text.RegularExpressions.Regex ('(?i)phantom[\s._\-]*(client|launcher)')
foreach ($pj in $script:ProfileJsonCand) {
    try {
        $j = Get-Content -LiteralPath $pj.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($j.profiles) {
            foreach ($prop in $j.profiles.PSObject.Properties) {
                $prof = $prop.Value
                $ja = [string]$prof.javaArgs
                if (-not $ja) { continue }
                $lu = $pj.LastWriteTime
                try { if ($prof.lastUsed) { $lu = [datetime]([string]$prof.lastUsed) } } catch {}
                $ver = [string]$prof.lastVersionId
                $pmx = $script:PhantomRx.Match($ja)
                $h = Get-NameHit $ja $true
                if ($pmx.Success) {
                    Add-F -Kaynak 'launcher_profiles.json (JavaArgs)' -Ad ('javaargs: ' + $pmx.Value.ToLower()) -Yol $pj.FullName -Skor 75 -Son $lu -Var 'Evet' -Not ('profil: ' + $prop.Name + ' | surum/loader: ' + $ver + ' | JavaArgs icinde Phantom Client yaziyor (dosyasiz hile, JVM parametresiyle yuklenir) | JavaArgs: ' + $ja)
                } elseif ($h) {
                    Add-F -Kaynak 'launcher_profiles.json (JavaArgs)' -Ad ('javaargs: ' + $h.Name) -Yol $pj.FullName -Skor 55 -Son $lu -Var 'Evet' -Not ('profil: ' + $prop.Name + ' | surum/loader: ' + $ver + ' | JavaArgs icinde hile ismi geciyor (dosyasiz/fileless hile olabilir) | JavaArgs: ' + $ja)
                } elseif ($ja -match '(?i)-javaagent|-Xbootclasspath|-agentpath|-noverify|-Xverify:none') {
                    Add-F -Kaynak 'launcher_profiles.json (JavaArgs)' -Ad ('javaargs: ozel parametre (' + $prop.Name + ')') -Yol $pj.FullName -Skor 35 -Son $lu -Var 'Evet' -Not ('profil: ' + $prop.Name + ' | surum/loader: ' + $ver + ' | dis kod yukleyen JVM parametresi | JavaArgs: ' + $ja)
                }
            }
        }
    } catch {}
}
# Oyuncunun kullandigi surumun (loader) json dosyasi ve Feather klasoru: Phantom Client yazisi aranir
foreach ($jf in $script:JsonCand2) {
    try {
        $jt = [IO.File]::ReadAllText($jf.FullName)
        $jm = $script:PhantomRx.Match($jt)
        if ($jm.Success) {
            $a0 = [Math]::Max(0, $jm.Index - 60)
            $l0 = [Math]::Min(180, $jt.Length - $a0)
            $ctx = ($jt.Substring($a0, $l0) -replace '\s+', ' ')
            Add-F -Kaynak 'Surum/Feather json (JVM args)' -Ad ('json: ' + $jm.Value.ToLower()) -Yol $jf.FullName -Skor 65 -Son $jf.LastWriteTime -Ilk $jf.CreationTime -Var 'Evet' -Not ('Phantom Client yazisi bulundu | baglam: ' + $ctx)
        }
    } catch {}
}

# --- Run / RunOnce kayit defteri: bilgisayar acilista otomatik calisan programlar ve komutlar ---
foreach ($runKey in @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'
)) {
    try {
        $rkItem = Get-Item -LiteralPath $runKey -ErrorAction Stop
        $rkTime = Get-KeyTime $rkItem
        $rkNote = ''
        if ($rkTime) { $rkNote = ' | Run anahtari son degisim: ' + (Fmt $rkTime) }
        foreach ($rn in $rkItem.GetValueNames()) {
            if (-not $rn) { continue }
            $cmdline = [string]$rkItem.GetValue($rn)
            if (-not $cmdline) { continue }
            $cmdX = [Environment]::ExpandEnvironmentVariables($cmdline)
            if ($cmdX -match $script:FlRx2) {
                Add-F -Kaynak 'Run (otomatik baslatma)' -Ad ('run: ' + $rn.ToLower()) -Yol $cmdX -Skor 55 -Var 'Evet' -Not ('acilista calisan komutta fileless/script kalibi var | anahtar: ' + $runKey + ' | tam komut: ' + $cmdline + $rkNote)
            }
            $runPaths = New-Object System.Collections.Generic.List[string]
            if ($cmdX -match '(?i)^\s*"([^"]+)"') { [void]$runPaths.Add($Matches[1]) } elseif ($cmdX -match '(?i)^\s*([A-Za-z]:\\.*?\.(?:exe|bat|cmd|ps1|vbs|jar|scr|com))') { [void]$runPaths.Add($Matches[1]) }
            foreach ($rp2 in (Find-Paths $cmdX 'exe|bat|cmd|ps1|vbs|jar|dll|scr')) { [void]$runPaths.Add($rp2) }
            $seenRun = @{}
            foreach ($ep in $runPaths) {
                if ($ep -notmatch '^[A-Za-z]:\\') { continue }
                $ek = $ep.ToLower()
                if ($seenRun.ContainsKey($ek)) { continue }
                $seenRun[$ek] = 1
                $pi = Test-PathInfo $ep
                Eval-Exec -Kaynak 'Run (otomatik baslatma)' -Path $ep -Exists $pi.Exists -Removed $pi.Removed -Note ('kayit adi: ' + $rn + ' | tam komut: ' + $cmdline + $rkNote)
            }
        }
    } catch {}
}

# --- XML Startup kayitlari (C:\Windows\System32\WDI\LogFiles\StartupInfo) ---
$xmlDir = $env:WINDIR + '\System32\WDI\LogFiles\StartupInfo'
if (Test-Path -LiteralPath $xmlDir) {
    $xmlList = @(Get-ChildItem -LiteralPath $xmlDir -Filter '*.xml' -File -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 40)
    $xmlSeen = @{}
    foreach ($xf in $xmlList) {
        try {
            $xb = [IO.File]::ReadAllBytes($xf.FullName)
            foreach ($pth in (Get-PathsFromBytes $xb $true)) {
                $lk = $pth.ToLower()
                if ($xmlSeen.ContainsKey($lk)) { continue }
                $xmlSeen[$lk] = 1
                if ($pth -match '^[A-Za-z]:\\') {
                    $pi = Test-PathInfo $pth
                    Eval-Exec -Kaynak 'XML Startup (boot izleme)' -Path $pth -Exists $pi.Exists -Removed $pi.Removed -Last $xf.LastWriteTime -Note ('acilis kaydi: ' + $xf.Name)
                } else {
                    $h = Get-NameHit $pth $false
                    if ($h) {
                        Add-F -Kaynak 'XML Startup (boot izleme)' -Ad $lk -Yol $pth -Skor 45 -Son $xf.LastWriteTime -Var 'Bilinmiyor' -Not ('acilista calisan program olarak kaydedilmis, hile ismi: ' + $h.Name + ' | dosya: ' + $xf.Name)
                    }
                }
            }
        } catch {}
    }
    Log ('   ' + $xmlList.Count + ' XML Startup dosyasi incelendi.') 'DarkGray'
}

# --- PowerShell gecmisi ve olay loglari: fileless (dosyasiz) calistirma izleri ---
# Anahtar kelimeler: "Invoke-" ve "System.Reflection.Assembly". Tek basina BAN sebebi degildir, sadece suphe uyandirir;
# bulunan komutun tamamina bakip icinde bir dosya veya web sitesi var mi kontrol etmek gerekir.
$flRx = '(?i)Invoke-|System\.Reflection\.Assembly'
$flStrong = '(?i)((Invoke-Expression|\bIEX\b)[^\r\n]*(https?://|DownloadString|Invoke-RestMethod|Invoke-WebRequest))|((Invoke-RestMethod|Invoke-WebRequest|DownloadString)[^\r\n]*(Invoke-Expression|\bIEX\b))|(Reflection\.Assembly\]?::Load)'
$psHist = $env:APPDATA + '\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'
if (Test-Path -LiteralPath $psHist) {
    $hcontent = @(Get-Content -LiteralPath $psHist -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch 'HileKiran\.ps1' })
    $hTime = (Get-Item -LiteralPath $psHist).LastWriteTime
    $flHits = @($hcontent | Where-Object { $_ -match $flRx })
    if ($flHits.Count -gt 0) {
        $strongH = @($flHits | Where-Object { $_ -match $flStrong })
        $showH = $flHits
        $skorH = 35
        if ($strongH.Count -gt 0) { $showH = $strongH; $skorH = 55 }
        $samples = @($showH | Select-Object -First 3 | ForEach-Object { $t2 = ([string]$_).Trim(); if ($t2.Length -gt 220) { $t2 = $t2.Substring(0, 220) + '...' }; $t2 })
        Add-Sys ('PowerShell gecmisinde fileless calistirma izi (' + $flHits.Count + ' satir)') $skorH 'Invoke-* / System.Reflection.Assembly komutlari dosyasiz (bellekten) kod calistirmak icin kullanilabilir; her zaman kotu amacli degildir. Komutun tamamina bak: icinde bir dosya veya web sitesi var mi?' $null ($samples -join ' || ') $hTime
    }
    $wmH = @($hcontent | Where-Object { $_ -match '(?i)wmic(\.exe)?\s+.*process\s+call\s+create' })
    if ($wmH.Count -gt 0) {
        Add-Sys ('PowerShell gecmisinde wmic ile program baslatma (' + $wmH.Count + ' satir)') 45 'wmic ... process call create komutu bir exe/uzantisiz dosya/ADS baslatmak icin hilelerde kullanilir.' $null (([string]$wmH[0]).Trim()) $hTime
    }
}
foreach ($evId in @(4104, 4103)) {
    try {
        $evs = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-PowerShell/Operational'; Id = $evId } -MaxEvents 300 -ErrorAction Stop | Where-Object { $_.ProcessId -ne $PID -and $_.Message -notmatch 'HileKiran\.ps1' })
        $flEvt = @($evs | Where-Object { $_.Message -match $flRx })
        if ($flEvt.Count -gt 0) {
            $strongE = @($flEvt | Where-Object { $_.Message -match $flStrong })
            $skorE = 35
            $firstE = $flEvt[0]
            if ($strongE.Count -gt 0) { $skorE = 55; $firstE = $strongE[0] }
            $mline = [string]($firstE.Message -split "`n" | Where-Object { $_ -match $flRx } | Select-Object -First 1)
            $mline = $mline.Trim()
            if ($mline.Length -gt 220) { $mline = $mline.Substring(0, 220) + '...' }
            Add-Sys ('PowerShell olay logunda (olay ' + $evId + ') fileless calistirma izi (' + $flEvt.Count + ' kayit)') $skorE 'Calistirilan PowerShell komut/script bloklarinda Invoke-* / System.Reflection.Assembly kaliplari bulundu. Tam komuta bak.' $firstE.TimeCreated $mline $firstE.TimeCreated
        }
    } catch {}
}
Show-Section

# ---------------------------------------------------------------------
Step '[12/17] Gorev Zamanlayici (Task Scheduler), WMI abonelikleri, StartUp klasoru...'
Start-Sec
$taskRoot2 = $env:WINDIR + '\System32\Tasks'
$taskFiles = @{}
$taskCount = 0
if (Test-Path -LiteralPath $taskRoot2) {
    foreach ($tf in @(Get-ChildItem -LiteralPath $taskRoot2 -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        $rel = $tf.FullName.Substring($taskRoot2.Length)
        $taskFiles[$rel.ToLower()] = $tf
        $xml = $null
        try { $xml = [xml](Get-Content -LiteralPath $tf.FullName -Raw -ErrorAction Stop) } catch {}
        if (-not $xml -or -not $xml.Task) { continue }
        $taskCount++
        $isMs = ($rel -match '(?i)^\\Microsoft\\')
        $trig = ''
        try { if ($xml.Task.Triggers) { $trig = (@($xml.Task.Triggers.ChildNodes | ForEach-Object { $_.LocalName }) -join ',') } } catch {}
        $regDate = $null
        try { $regDate = [datetime]([string]$xml.Task.RegistrationInfo.Date) } catch {}
        foreach ($ex in @($xml.Task.Actions.Exec)) {
            if (-not $ex) { continue }
            $cmd = [string]$ex.Command
            if (-not $cmd) { continue }
            $targ = [string]$ex.Arguments
            $targX = [Environment]::ExpandEnvironmentVariables($targ)
            $cmdX = [Environment]::ExpandEnvironmentVariables($cmd).Trim().Trim('"')
            $full = $cmdX + ' ' + $targX
            $hit = Get-NameHit $full $false
            if ($isMs -and -not $hit) { continue }
            $sc = 0
            $why = New-Object System.Collections.Generic.List[string]
            if ($hit) { $sc += 45; [void]$why.Add('isim eslesmesi: ' + $hit.Name) }
            if ($full -match $script:FlRx2) { $sc += 40; [void]$why.Add('fileless/script kalibi (Invoke-/Reflection/base64/gizli pencere vb.)') }
            if ($full -match '(?i)https?://') { $sc += 15; [void]$why.Add('komutta web adresi var') }
            if ($cmdX -match '^[A-Za-z]:\\') {
                $cmdExists = [bool](Test-Path -LiteralPath $cmdX)
                $zc = Get-Zone $cmdX
                if (-not $cmdExists) {
                    $sc += 30; [void]$why.Add('gorevin komut dosyasi SILINMIS/yok')
                } elseif ($zc -eq 'user' -or $zc -eq 'temp' -or $zc -eq 'appdata' -or $zc -eq 'shared') {
                    $sc += 20; [void]$why.Add('gorev kullanici/temp/AppData klasorundeki bir programi calistiriyor')
                }
            }
            if (($trig -match '(?i)Boot|Logon') -and $sc -gt 0) { $sc += 10; [void]$why.Add('tetikleyici: ' + $trig) }
            if ($sc -ge 15) {
                $nt = ($why -join '; ') + ' | komut: ' + $cmd + ' | arguman: ' + $targ
                Add-F -Kaynak 'Gorev Zamanlayici' -Ad ('gorev: ' + $tf.Name.ToLower()) -Yol ($rel + '  ->  ' + $cmd) -Skor ([Math]::Min(100, $sc)) -Son $tf.LastWriteTime -Ilk $regDate -Var 'Evet' -Not $nt
            }
            foreach ($ap in (Find-Paths $targX 'exe|dll|jar|bat|ps1|cmd|vbs|scr')) {
                $api = Test-PathInfo $ap
                Eval-Exec -Kaynak 'Gorev Zamanlayici (arguman)' -Path $ap -Exists $api.Exists -Removed $api.Removed -Last $tf.LastWriteTime -Note ('gorev: ' + $rel)
            }
        }
    }
}
Log ('   ' + $taskCount + ' zamanlanmis gorev incelendi.') 'DarkGray'

# Gorev kayit defteri (TaskCache) ile Tasks klasoru birbirini tutuyor mu? (gizlenmis/silinmis gorev izi)
$taskTreeSet = @{}
try {
    $trBase = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree'
    $trLen = ('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree').Length
    foreach ($k in @(Get-ChildItem -LiteralPath $trBase -Recurse -ErrorAction SilentlyContinue)) {
        $tid = $k.GetValue('Id')
        if (-not $tid) { $k.Close(); continue }
        $krel = $k.Name.Substring($trLen)
        $taskTreeSet[$krel.ToLower()] = 1
        $ktime = Get-KeyTime $k
        $k.Close()
        if ($taskFiles.Count -gt 0 -and -not $taskFiles.ContainsKey($krel.ToLower())) {
            Add-Sys ('Gorev kayit defterinde var ama dosyasi YOK: ' + $krel) 40 'Gorev Zamanlayici kaydi duruyor ama System32\Tasks icindeki dosyasi silinmis; gorev gizlenmis veya iz silinmis olabilir.' $null ('Id=' + $tid) $ktime
        }
    }
} catch {}
if ($taskTreeSet.Count -gt 0) {
    foreach ($fk in @($taskFiles.Keys)) {
        if (-not $taskTreeSet.ContainsKey($fk)) {
            $tfo = $taskFiles[$fk]
            Add-Sys ('Gorev dosyasi var ama kayit defterinde YOK: ' + $fk) 30 'System32\Tasks icinde dosya var ama TaskCache kaydi yok; Gorev Zamanlayici arayuzunde gorunmeyen gorev olabilir.' $null ('dosya: ' + $tfo.FullName) $tfo.LastWriteTime
        }
    }
}
# Silinen gorevler: olay gunlugu aciksa (Windows varsayilani kapali) silinme zamanlari buradan gelir
try {
    foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-TaskScheduler/Operational'; Id = 141 } -MaxEvents 15 -ErrorAction Stop)) {
        $qm = [regex]::Matches([string]$e.Message, '"([^"]+)"')
        $tn = [string]$e.Message
        if ($qm.Count -gt 0) { $tn = $qm[$qm.Count - 1].Groups[1].Value }
        Add-Sys ('Gorev SILINMIS (olay 141): ' + $tn) 30 'Gorev Zamanlayici olay gunlugu: bu gorev silinmis.' $e.TimeCreated $null $e.TimeCreated
    }
} catch {}
try {
    foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4699 } -MaxEvents 15 -ErrorAction Stop)) {
        $tn = ''
        try { $tn = [string]$e.Properties[4].Value } catch {}
        Add-Sys ('Gorev SILINMIS (guvenlik olayi 4699): ' + $tn) 30 'Guvenlik olay gunlugu: bir zamanlanmis gorev silinmis.' $e.TimeCreated $null $e.TimeCreated
    }
} catch {}
# WMI kalici olay aboneligi (kalici baslatma yontemi)
try {
    foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-WMI-Activity/Operational'; Id = 5861 } -MaxEvents 10 -ErrorAction Stop)) {
        $wmsg = ([string]$e.Message -replace '\s+', ' ')
        if ($wmsg.Length -gt 220) { $wmsg = $wmsg.Substring(0, 220) + '...' }
        Add-Sys 'WMI kalici olay aboneligi olusturulmus (olay 5861)' 35 'WMI uzerinden kalici tetikleyici/komut tanimlanmis; hile veya zararli yazilim kalici calismak icin kullanabilir.' $e.TimeCreated $wmsg $e.TimeCreated
    }
} catch {}

# --- Start Menu\Programs\StartUp klasorleri: bilgisayar acilinca calisan kisayol/script/exe ---
$wsh2 = $null
try { $wsh2 = New-Object -ComObject WScript.Shell } catch {}
$suCount = 0
$scriptExt = @('.py', '.pyw', '.ps1', '.bat', '.cmd', '.vbs', '.vbe', '.js', '.jse', '.wsf', '.html', '.htm', '.hta', '.jar', '.exe', '.dll', '.scr', '.com', '.url')
foreach ($sd in @(($env:ProgramData + '\Microsoft\Windows\Start Menu\Programs\StartUp'), ($env:APPDATA + '\Microsoft\Windows\Start Menu\Programs\Startup'))) {
    if (-not (Test-Path -LiteralPath $sd)) { continue }
    foreach ($sf in @(Get-ChildItem -LiteralPath $sd -File -Force -ErrorAction SilentlyContinue)) {
        if ($sf.Name -ieq 'desktop.ini') { continue }
        $suCount++
        $sext = $sf.Extension.ToLower()
        $sc = 0
        $why = New-Object System.Collections.Generic.List[string]
        $hit = Get-NameHit $sf.Name $false
        if ($hit) { $sc += 45; [void]$why.Add('dosya adi: ' + $hit.Name) }
        if ($sext -eq '.lnk') {
            $tg = ''
            $ta = ''
            try { if ($wsh2) { $lk = $wsh2.CreateShortcut($sf.FullName); $tg = [string]$lk.TargetPath; $ta = [string]$lk.Arguments } } catch {}
            $lh = Get-NameHit ($tg + ' ' + $ta) $false
            if ($lh) { $sc += 40; [void]$why.Add('kisayol hedefinde isim: ' + $lh.Name) }
            if (($tg + ' ' + $ta) -match $script:FlRx2) { $sc += 40; [void]$why.Add('kisayol komutunda fileless/script kalibi') }
            if ($tg -match '^[A-Za-z]:\\') {
                $tpi = Test-PathInfo $tg
                Eval-Exec -Kaynak 'StartUp klasoru (kisayol)' -Path $tg -Exists $tpi.Exists -Removed $tpi.Removed -Last $sf.LastWriteTime -First $sf.CreationTime -Note ('kisayol: ' + $sf.Name + ' | arguman: ' + $ta)
            }
            if ($sc -gt 0) { [void]$why.Add('hedef: ' + $tg + ' ' + $ta) }
        } elseif ($scriptExt -contains $sext) {
            $sc += 30
            [void]$why.Add('StartUp klasorunde ' + $sext + ' dosyasi var (normalde sadece kisayol bulunur)')
            if (@('.html', '.htm', '.hta') -contains $sext) { $sc += 15 }
            if ($sf.Length -lt 2097152 -and (@('.exe', '.dll', '.scr', '.com', '.jar') -notcontains $sext)) {
                $ctext = ''
                try { $ctext = [IO.File]::ReadAllText($sf.FullName) } catch {}
                if ($ctext) {
                    $ch = Get-NameHit $ctext $false
                    if ($ch) { $sc += 30; [void]$why.Add('icerikte hile ismi: ' + $ch.Name) }
                    if ($ctext -match $script:FlRx2) { $sc += 25; [void]$why.Add('icerikte fileless/script kalibi') }
                    if ($ctext -match '(?i)https?://') { $sc += 10; [void]$why.Add('icerikte web adresi var') }
                }
            }
            if ($sext -eq '.exe' -and -not (Test-Signed $sf.FullName)) { $sc += 20; [void]$why.Add('imzasiz exe') }
        }
        if ($sc -ge 10) {
            Add-F -Kaynak 'StartUp klasoru' -Ad $sf.Name.ToLower() -Yol $sf.FullName -Skor ([Math]::Min(100, $sc)) -Son $sf.LastWriteTime -Ilk $sf.CreationTime -Var 'Evet' -Not ($why -join '; ')
        }
    }
}
Log ('   StartUp klasorlerinde ' + $suCount + ' oge incelendi.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[13/17] Kayit defteri izleri (OpenSavePidlMRU, MountedDevices, VolumeInfoCache, DirectInput, WordWheelQuery, Uyumluluk, WinRAR, MuiCache)...'
Start-Sec
# --- Dosya Ac/Kaydet diyalogu gecmisi: OpenSavePidlMRU (uzantilar + dosya adlari), LastVisitedPidlMRU (diyalogu acan programlar) ---
$mruBase = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32'
$extFound = New-Object System.Collections.Generic.List[string]
$extTime = $null
foreach ($mk in @('OpenSavePidlMRU', 'LastVisitedPidlMRU')) {
    $rb = $mruBase + '\' + $mk
    if (-not (Test-Path -LiteralPath $rb)) { continue }
    $nodes = New-Object System.Collections.Generic.List[object]
    try { [void]$nodes.Add((Get-Item -LiteralPath $rb -ErrorAction Stop)) } catch {}
    foreach ($chd in @(Get-ChildItem -LiteralPath $rb -ErrorAction SilentlyContinue)) {
        [void]$nodes.Add($chd)
        if ($mk -eq 'OpenSavePidlMRU') {
            $en = $chd.PSChildName.ToLower()
            if (@('jar', 'exe', 'dll', 'bat', 'cmd', 'ps1', 'vbs', 'scr', 'zip', 'rar', '7z', 'py', 'msi') -contains $en) {
                [void]$extFound.Add($en)
                $ktE = Get-KeyTime $chd
                if ($ktE -and (-not $extTime -or $ktE -gt $extTime)) { $extTime = $ktE }
            }
        }
    }
    foreach ($nd in $nodes) {
        $kt = Get-KeyTime $nd
        foreach ($vn in $nd.GetValueNames()) {
            if ($vn -eq 'MRUListEx' -or -not $vn) { continue }
            $vb = $nd.GetValue($vn)
            if ($vb -isnot [byte[]]) { continue }
            foreach ($pth in (Get-PathsFromBytes $vb $true)) {
                if ($pth -match '^[A-Za-z]:\\') {
                    $pi = Test-PathInfo $pth
                    Eval-Exec -Kaynak ('ComDlg32\' + $mk) -Path $pth -Exists $pi.Exists -Removed $pi.Removed -Last $kt -Note 'Dosya Ac/Kaydet diyalogu gecmisi'
                } else {
                    Eval-Exec -Kaynak ('ComDlg32\' + $mk) -Path $pth -Last $kt -Note 'Dosya Ac/Kaydet diyalogu gecmisi (sadece dosya adi)' -NoLoc
                }
            }
        }
    }
}
if ($extFound.Count -gt 0) {
    $extList = (@($extFound | Select-Object -Unique) -join ', ')
    $extSkor = 8
    if (@($extFound) -contains 'jar' -or @($extFound) -contains 'exe' -or @($extFound) -contains 'dll') { $extSkor = 15 }
    Add-Sys 'Dosya Ac/Kaydet diyalogunda kod/arsiv uzantilari kullanilmis (OpenSavePidlMRU)' $extSkor 'Bu uzantilarla bir dosya acilmis/kaydedilmis. Ayrintili dosya adlari asagidaki bulgularda (varsa) listelenir.' $null ('uzantilar: ' + $extList) $extTime
}

# --- MountedDevices: harfi olup su an takili olmayan surucular, harf atanmamis (\??\Volume) hacimler ---
try {
    $md = Get-Item -LiteralPath 'HKLM:\SYSTEM\MountedDevices' -ErrorAction Stop
    $mdKt = Get-KeyTime $md
    $volOnly = 0
    $mdShown = 0
    foreach ($vn in $md.GetValueNames()) {
        if ($vn -match '^\\DosDevices\\([A-Za-z]:)$') {
            $dl = $Matches[1].ToUpper()
            if ($script:Drives -contains $dl) { continue }
            $desc = 'disk imzasi (sabit disk/bolum kaydi)'
            $bytes = $md.GetValue($vn)
            if ($bytes -is [byte[]] -and $bytes.Length -ge 8) {
                $tx = ([Text.Encoding]::Unicode.GetString($bytes)).TrimEnd([char]0)
                if ($tx -match '^_\?\?_') { $desc = $tx }
            }
            $mdShown++
            if ($mdShown -le 10) { Add-Sys ('Kayitli ama su an takili olmayan surucu harfi: ' + $dl) 15 'MountedDevices kaydinda var, simdi takili degil (cikarilmis USB/disk olabilir).' $null $desc $mdKt }
        } elseif ($vn -match '^\\\?\?\\Volume\{') {
            $volOnly++
        }
    }
    if ($volOnly -gt 0) {
        Add-Sys ('Harf atanmamis hacim kaydi: ' + $volOnly + ' adet (\??\Volume{...})') 10 'Bu kayitlar gizli veya silinmis suruculere ait olabilir (cogu zaman normaldir: kurtarma bolumu, eski USB).' $null $null $mdKt
    }
} catch {}

# --- Windows Search VolumeInfoCache: eskiden kullanilmis surucu harfleri (silinse de kayit kalir) ---
try {
    foreach ($c in @(Get-ChildItem -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows Search\VolumeInfoCache' -ErrorAction Stop)) {
        $dl = $c.PSChildName.TrimEnd('\').ToUpper()
        $lbl = [string]$c.GetValue('VolumeLabel')
        $dty = $c.GetValue('DriveType')
        $kt = Get-KeyTime $c
        $c.Close()
        if ($dl -match '^[A-Z]:$' -and ($script:Drives -notcontains $dl)) {
            $vs = 15
            if ($dty -eq 2) { $vs = 20 }
            Add-Sys ('Eskiden kullanilmis surucu (su an takili degil): ' + $dl) $vs 'Windows Search VolumeInfoCache: bu harfle bir surucu takilmis (surucu silinse de kayit kalir). Tur 2 = cikarilabilir (USB).' $null ('etiket=' + $lbl + ', surucu turu=' + $dty) $kt
        }
    }
} catch {}

# --- DirectInput: DirectInput kullanan programlar (bazi hileler kullanir) ---
try {
    foreach ($c in @(Get-ChildItem -LiteralPath 'HKCU:\Software\Microsoft\DirectInput' -ErrorAction Stop)) {
        $kn = $c.PSChildName
        $kt = Get-KeyTime $c
        $nameV = [string]$c.GetValue('Name')
        $pathV = [string]$c.GetValue('Path')
        $c.Close()
        $cand = ($kn -replace '[0-9A-Fa-f]{16}$', '')
        if ($nameV) { $cand = $nameV }
        if ($pathV -match '^[A-Za-z]:\\') {
            $pi = Test-PathInfo $pathV
            Eval-Exec -Kaynak 'DirectInput' -Path $pathV -Exists $pi.Exists -Removed $pi.Removed -Last $kt -Note ('DirectInput kaydi: ' + $kn)
        } elseif ($cand) {
            Eval-Exec -Kaynak 'DirectInput' -Path $cand -Last $kt -Note ('DirectInput kaydi: ' + $kn) -NoLoc
        }
    }
} catch {}

# --- WordWheelQuery: Dosya Gezgini sag ustteki arama kutusunun gecmisi ---
try {
    $ww = Get-Item -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery' -ErrorAction Stop
    $wwKt = Get-KeyTime $ww
    foreach ($vn in $ww.GetValueNames()) {
        if ($vn -eq 'MRUListEx' -or -not $vn) { continue }
        $vb = $ww.GetValue($vn)
        if ($vb -isnot [byte[]]) { continue }
        $q = ([Text.Encoding]::Unicode.GetString($vb)).TrimEnd([char]0)
        if (-not $q) { continue }
        $h = Get-NameHit $q $false
        if ($h) {
            Add-F -Kaynak 'Dosya Gezgini arama gecmisi (WordWheelQuery)' -Ad ('arama: ' + $q.ToLower()) -Yol $q -Skor 40 -Son $wwKt -Var 'Bilinmiyor' -Not ('Dosya Gezgini aramasinda hile ismi aranmis: ' + $h.Name + ' | anahtar son degisim: ' + (Fmt $wwKt))
        }
    }
} catch {}

# --- Compatibility Assistant (Store / Persisted): calistirilmis programlarin yollari ---
foreach ($cak in @('Store', 'Persisted')) {
    try {
        $cas = Get-Item -LiteralPath ('HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\' + $cak) -ErrorAction Stop
        foreach ($vn in $cas.GetValueNames()) {
            if ($vn -notmatch '^[A-Za-z]:\\') { continue }
            $pi = Test-PathInfo $vn
            Eval-Exec -Kaynak ('Compatibility Assistant ' + $cak) -Path $vn -Exists $pi.Exists -Removed $pi.Removed -Note 'Uyumluluk yardimcisi kaydi (program calistirilmis)'
        }
    } catch {}
}
# --- WinRAR gecmisi: acilan arsivler ---
try {
    $wr = Get-ItemProperty -LiteralPath 'HKCU:\Software\WinRAR\ArcHistory' -ErrorAction Stop
    foreach ($prop in $wr.PSObject.Properties) {
        if ($prop.Name -match '^PS') { continue }
        $vp = [string]$prop.Value
        if ($vp -notmatch '^[A-Za-z]:\\') { continue }
        $h = Get-NameHit $vp $true
        if ($h) {
            $pi = Test-PathInfo $vp
            $wvar = 'Hayir'
            if ($pi.Exists) { $wvar = 'Evet' }
            Add-F -Kaynak 'WinRAR gecmisi' -Ad (Split-Path -Leaf $vp).ToLower() -Yol $vp -Skor 40 -Var $wvar -Not ('WinRAR ile acilmis arsiv | isim eslesmesi: ' + $h.Name)
        }
    }
} catch {}
# --- MuiCache: calistirilmis programlarin gorunen adlari (deger adi: yol.FriendlyAppName) ---
try {
    $mc = Get-Item -LiteralPath 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache' -ErrorAction Stop
    $mcSeen = @{}
    foreach ($vn in $mc.GetValueNames()) {
        $mp = $vn -replace '\.(FriendlyAppName|ApplicationCompany)$', ''
        if ($mp -notmatch '(?i)^[A-Za-z]:\\.*\.(exe|dll)$') { continue }
        $mk2 = $mp.ToLower()
        if ($mcSeen.ContainsKey($mk2)) { continue }
        $mcSeen[$mk2] = 1
        $pi = Test-PathInfo $mp
        Eval-Exec -Kaynak 'MuiCache' -Path $mp -Exists $pi.Exists -Removed $pi.Removed -Note 'MuiCache kaydi (program en az bir kez calistirilmis)'
    }
} catch {}
Show-Section

# ---------------------------------------------------------------------
Step '[14/17] Bellek (RAM) string taramasi: ctfmon, sihost, explorer, DPS, Dnscache... (birkac dakika surebilir)'
Start-Sec
$script:MemOk = 0
$script:MemFail = 0
$script:MemFailNames = New-Object System.Collections.Generic.List[string]
if (-not $script:HkOk) {
    Log '   yardimci modul derlenemedi, bellek taramasi atlandi.' 'DarkYellow'
} else {
    try { [void][HkNative]::EnableDebug() } catch {}
    $rxExe = '\.(?:exe|dll|jar|bat|ps1|cmd|vbs|scr)'
    $rxDom = '\.(?:com|net|org|gg|io|xyz|ru|to|cc|club|pw|dev|me|app|su|cloud|shop|store|lol|fun|top|info|site|online|space|tech|cx|ws)(?![a-z0-9])'
    $memDone = @{}
    # Normal process'ler: etiket, process adi, regex, mod
    $procTargets = @(
        @('ctfmon', 'ctfmon', $rxExe, 'exe'),
        @('sihost', 'sihost', $rxExe, 'exe'),
        @('taskhostw', 'taskhostw', $rxExe, 'exe'),
        @('explorer', 'explorer', ($rxExe + '|wmic'), 'wmic'),
        @('SearchIndexer', 'SearchIndexer', $rxExe, 'exe'),
        @('SmartScreen', 'smartscreen', $rxExe, 'exe'),
        @('csrss', 'csrss', $rxExe, 'exe'),
        @('SgrmBroker', 'SgrmBroker', 'wmic', 'wmic'),
        @('MsMpEng', 'MsMpEng', 'wmic', 'wmic')
    )
    foreach ($pt in $procTargets) {
        foreach ($gp in @(Get-Process -Name $pt[1] -ErrorAction SilentlyContinue)) {
            $mkey = ([string]$gp.Id) + '|' + $pt[3]
            if ($memDone.ContainsKey($mkey)) { continue }
            $memDone[$mkey] = 1
            Scan-MemProcess $pt[0] $gp.Id $pt[2] $pt[3]
        }
    }
    # Servisler (svchost icinde calisir): servis adi, regex, mod
    $svcTargets = @(
        @('Appinfo', $rxExe, 'exe'),
        @('DPS', $rxExe, 'dps'),
        @('mpssvc', $rxExe, 'exe'),
        @('BFE', $rxExe, 'exe'),
        @('DiagTrack', $rxExe, 'exe'),
        @('SysMain', $rxExe, 'exe'),
        @('Dnscache', $rxDom, 'dns')
    )
    foreach ($st in $svcTargets) {
        $svo = Get-CimInstance Win32_Service -Filter ("Name='" + $st[0] + "'")
        if (-not $svo -or -not $svo.ProcessId -or $svo.ProcessId -le 0) { continue }
        $mkey = ([string]$svo.ProcessId) + '|' + $st[2]
        if ($memDone.ContainsKey($mkey)) { continue }
        $memDone[$mkey] = 1
        Scan-MemProcess $st[0] ([int]$svo.ProcessId) $st[1] $st[2]
    }
    $failTxt = ''
    if ($script:MemFail -gt 0) { $failTxt = ' | okunamayanlar: ' + (($script:MemFailNames | Select-Object -Unique) -join ', ') + ' (korumali/PPL process olabilir)' }
    Log ('   ' + $script:MemOk + ' process bellegi tarandi, ' + $script:MemFail + ' tanesi okunamadi' + $failTxt) 'DarkGray'
}
Show-Section

# =====================================================================
# EK MODULLER (Discord rehberlerinden): JAVAW Prefetch, JavaLauncher.log, bellek (-jar/.jar),
# PowerShell gecmisi/olay gunlukleri, USN silinme, ENB/ReShade proxy dll, dizinlenmis konumlar, process modulleri
# =====================================================================
# ---------------- ek yardimcilar ----------------
$script:PsTamperRx = '(?i)wevtutil(\.exe)?\s+(cl|clear-log)|Clear-EventLog|Remove-EventLog|fsutil(\.exe)?\s+usn\s+deletejournal|(Remove-Item|\bdel\b|\brm\b|\berase\b)[^\r\n]*(Prefetch|ConsoleHost_history|JavaLauncher)|Set-MpPreference[^\r\n]*Disable|Add-MpPreference[^\r\n]*Exclusion(Path|Process|Extension)|Stop-Service[^\r\n]*(EventLog|DPS|SysMain|PcaSvc|bam|WinDefend)|Set-Service[^\r\n]*(EventLog|DPS|SysMain|PcaSvc|bam)|\bsc(\.exe)?\s+(config|stop)\s+(EventLog|DPS|SysMain|PcaSvc|bam)|\bClear-History\b|Set-PSReadLineOption[^\r\n]*SaveNothing|(Set-Content|Clear-Content|Out-File)[^\r\n]*(ConsoleHost_history|JavaLauncher)|reg(\.exe)?\s+(add|delete)[^\r\n]*(PrefetchParameters|EnablePrefetcher|DisableAntiSpyware)'
$script:ProxyDllRx = '(?i)^(d3d8|d3d9|d3d10|d3d10_1|d3d11|dxgi|opengl32|dinput8|dinput|winmm|version|xinput1_3|xinput1_4|xinput9_1_0|dsound|ddraw|msimg32|dbghelp|vorbisfile)\.dll$'
$script:OwnMarkers = 'HileKiran|\$StrongNames|Eval-Exec|Eval-JarArg|Analyze-PsText|Show-Section|HkNative|Add-F '

$script:HkUserDirs = @()
try {
    $script:HkUserDirs = @(Get-ChildItem -LiteralPath ($env:SystemDrive + '\Users') -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^(All Users|Default|Default User|Public)$' })
} catch {}

function Get-SigInfo([string]$p) {
    $r = @{ Valid = $false; Subject = '' }
    try {
        $s = Get-AuthenticodeSignature -LiteralPath $p -ErrorAction Stop
        if ($s.Status -eq 'Valid') { $r.Valid = $true }
        if ($s.SignerCertificate) { $r.Subject = [string]$s.SignerCertificate.Subject }
    } catch {}
    return $r
}

# "java -jar <arg>" argumanini degerlendirir (uzanti degistirilmis mi, dosya silinmis mi, jar icinde hile var mi)
function Eval-JarArg([string]$arg, [string]$kaynak, $tm, [string]$note) {
    $arg = $arg.Trim().Trim('"').Trim([char]39).Trim()
    if ($arg.Length -lt 3) { return }
    if ($arg -match '^[-/%$]') { return }
    $leaf = $arg
    try { $leaf = Split-Path -Leaf $arg } catch {}
    if (-not $leaf) { return }
    $ext = ''
    try { $ext = [IO.Path]::GetExtension($leaf).ToLower() } catch {}
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    $hit = Get-NameHit $leaf $true
    if ($hit) {
        $ns = Name-Score $hit $true
        if ($ns -gt 0) { $sc += $ns; [void]$why.Add('isim eslesmesi: ' + $hit.Name) }
    }
    if ($ext -ne '.jar') {
        $extTxt = $ext
        if (-not $extTxt) { $extTxt = 'uzantisiz' }
        $sc += 55
        [void]$why.Add('java -jar ile calistirilmis ama uzanti .jar degil (' + $extTxt + ') - uzanti degistirilmis olabilir')
    }
    $var = 'Bilinmiyor'
    if ($arg -match '^[A-Za-z]:\\') {
        $pi = Get-PiCached $arg
        $zone = Get-Zone $arg
        if ($pi.Exists) {
            $var = 'Evet'
            if ($ext -ne '.jar') {
                $mg = Get-Magic $arg
                if ($mg -eq 'PK') { $sc += 25; [void]$why.Add('dosya icerigi gercekten ZIP/JAR (PK) - jar baska uzantiyla saklaniyor') }
                elseif ($mg -eq 'MZ') { $sc += 30; [void]$why.Add('dosya icerigi EXE/DLL (MZ)') }
            } else {
                $jr = Inspect-Jar $arg
                if ($jr.Hit) { $sc += 40; [void]$why.Add('jar ICINDE hile modulu/istemci ismi: ' + $jr.Hit) }
                if ($jr.Agent) { $sc += 15; [void]$why.Add('jar bir Java agent (' + $jr.AgentClass + ')') }
            }
            if ($zone -eq 'user' -or $zone -eq 'temp') { $sc += 10; [void]$why.Add('kullanici/temp klasorunde') }
        } else {
            $var = 'Hayir'
            if ($pi.Removed) {
                $sc += 30; [void]$why.Add('cikarilmis/eski surucuden calistirilmis')
            } elseif ($zone -eq 'user' -or $zone -eq 'temp' -or $zone -eq 'appdata' -or $zone -eq 'shared') {
                $sc += 30; [void]$why.Add('dosya SILINMIS (kullanici/temp/AppData klasoru)')
            } else {
                $sc += 15; [void]$why.Add('dosya su an bulunamiyor')
            }
        }
    }
    if ($arg -match '(?i)\\(\.minecraft|\.lunarclient|ModrinthApp|PrismLauncher)\\(libraries|versions|runtime)\\|^[A-Za-z]:\\Program Files') { $sc -= 20 }
    if ($leaf -match $script:BenignRx) { $sc -= 15 }
    if ($sc -lt 25) { return }
    $nt = ($why -join '; ')
    if ($note) { $nt = $nt + ' | ' + $note }
    Add-F -Kaynak $kaynak -Ad ('jar: ' + $leaf.ToLower()) -Yol $arg -Skor ([Math]::Min(100, $sc)) -Son $tm -Var $var -Not $nt
}

# Bellek string listesinden "-jar <arguman>" cikarir
function Analyze-MemJar([string]$label, $strings, [int]$procId) {
    if ($null -eq $strings -or $strings.Count -eq 0) { return }
    $seen = @{}
    foreach ($s in $strings) {
        if ($s.IndexOf('-jar', [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        foreach ($m in [regex]::Matches($s, '(?i)-jar\s+(?:"([^"]+)"|([^\s")]+))')) {
            $a = $m.Groups[1].Value
            if (-not $a) { $a = $m.Groups[2].Value }
            if (-not $a) { continue }
            $k = $a.ToLower()
            if ($seen.ContainsKey($k)) { continue }
            $seen[$k] = 1
            if ($seen.Count -gt 400) { return }
            $snip = $s
            if ($snip.Length -gt 200) { $snip = $snip.Substring(0, 200) + '...' }
            Eval-JarArg $a ('Bellek stringi: ' + $label + ' (-jar)') $null ('PID ' + $procId + ' | string: ' + $snip)
        }
    }
}
function Scan-MemJar([string]$label, [int]$procId, [string]$rx, [bool]$img) {
    Log ('   bellek taraniyor: ' + $label + ' (PID ' + $procId + ')') 'DarkGray'
    $list = $null
    try { $list = [HkNative]::MemStrings($procId, $rx, 4, $true, $true, $img, [long]734003200) } catch { $list = $null }
    if ($null -eq $list) { Log ('   okunamadi (korumali process olabilir): ' + $label) 'DarkYellow'; return }
    Analyze-MemJar $label $list $procId
    Analyze-MemExe $label $list $procId
}

# PowerShell komut/script metnini analiz eder (gecmis dosyasi, olay gunlugu, profil)
function Analyze-PsText([string]$text, [string]$kaynak, $tm, [bool]$useFl) {
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    $snip = ($text -replace '\s+', ' ').Trim()
    if ($snip.Length -gt 260) { $snip = $snip.Substring(0, 260) + '...' }
    foreach ($m in [regex]::Matches($text, '(?i)-jar\s+(?:"([^"]+)"|([^\s")]+))')) {
        $a = $m.Groups[1].Value
        if (-not $a) { $a = $m.Groups[2].Value }
        if ($a) { Eval-JarArg $a $kaynak $tm ('PowerShell: ' + $snip) }
    }
    if ($text -match $script:PsTamperRx) {
        Add-F -Kaynak $kaynak -Ad 'powershell: iz temizleme / koruma kapatma komutu' -Yol $snip -Skor 55 -Son $tm -Var 'Bilinmiyor' -Not ('log/prefetch/gecmis silme veya Defender/servis kapatma komutu | komut: ' + $snip)
    }
    foreach ($pm in (Find-Paths $text 'exe|dll|jar|bat|ps1|scr|cmd|vbs')) {
        $pi = Get-PiCached $pm
        Eval-Exec -Kaynak $kaynak -Path $pm -Exists $pi.Exists -Removed $pi.Removed -Last $tm -Note ('PowerShell komutu: ' + $snip)
    }
    $h = Get-NameHit $text $false
    if ($h) {
        Add-F -Kaynak $kaynak -Ad ('powershell: ' + $h.Name) -Yol $snip -Skor 45 -Son $tm -Var 'Bilinmiyor' -Not ('PowerShell komutunda hile ismi geciyor: ' + $h.Name + ' | komut: ' + $snip)
    }
    if ($useFl -and ($text -match $script:FlRx2)) {
        Add-F -Kaynak $kaynak -Ad 'powershell: fileless/script kalibi' -Yol $snip -Skor 35 -Son $tm -Var 'Bilinmiyor' -Not ('gizli pencere/encoded/indirme kalibi (tek basina BAN sebebi degil, komutun tamamina bak) | komut: ' + $snip)
    }
}

# fsutil USN gunlugunde isim deseni arar (tek gecis, birden cok desen)
function Read-UsnPattern([string]$dl, [string[]]$patterns) {
    $out = New-Object System.Collections.Generic.List[object]
    $lines = @(Select-UsnLines $dl $patterns)
    foreach ($ln in $lines) {
        [void]$out.Add([pscustomobject]@{ Silme = (Test-UsnDelete $ln); Ad = (Get-UsnName $ln); Zaman = (Get-UsnTime $ln) })
    }
    return $out
}

# ENB / ReShade / taninmayan proxy dll degerlendirmesi
function Eval-ProxyDll([string]$p, [string]$kaynak, $tm, [string]$ctx) {
    $fi = $null
    try { $fi = Get-Item -LiteralPath $p -Force -ErrorAction Stop } catch { return }
    $dir = ''
    try { $dir = Split-Path -Parent $p } catch {}
    $sig = Get-SigInfo $p
    if ($sig.Valid -and $sig.Subject -match '(?i)Microsoft|NVIDIA|Intel|Advanced Micro Devices|Oracle|Azul|Eclipse|Amazon|Google') { return }
    $vi = $fi.VersionInfo
    $idText = (([string]$vi.ProductName) + ' ' + ([string]$vi.FileDescription) + ' ' + ([string]$vi.CompanyName) + ' ' + ([string]$vi.OriginalFilename))
    $ident = ''
    if ($idText -match '(?i)reshade') { $ident = 'ReShade' } elseif ($idText -match '(?i)\benb\b|enbseries|vorontsov') { $ident = 'ENB' }
    if (-not $ident -and $fi.Length -lt 41943040) {
        try {
            $b = [IO.File]::ReadAllBytes($p)
            $t = [Text.Encoding]::GetEncoding(28591).GetString($b)
            if ($t -match '(?i)reshade') { $ident = 'ReShade' } elseif ($t -match '(?i)enbseries|enblocal\.ini|boris vorontsov') { $ident = 'ENB' }
        } catch {}
    }
    $sib = @()
    if ($dir) {
        foreach ($sn in @('ReShade.ini', 'reshade-shaders', 'ReShade64.dll', 'ReShade32.dll', 'enbseries.ini', 'enbseries', 'enblocal.ini')) {
            if (Test-Path -LiteralPath (Join-Path $dir $sn)) { $sib += $sn }
        }
    }
    $sha = ''
    try { $sha = (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash } catch {}
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    if ($ident -or $sib.Count -gt 0) {
        $nm2 = $ident
        if (-not $nm2) { $nm2 = 'ENB/ReShade' }
        $sc = 35
        [void]$why.Add($nm2 + ' (grafik modu) - mesru olabilir ama enjeksiyon/gizleme icin de kullanilir; SHA256 degerini bilinen surumle karsilastir')
        if ($sib.Count -gt 0) { [void]$why.Add('yaninda: ' + ($sib -join ', ')) }
        if (-not $sig.Valid) { $sc += 5 }
    } elseif ($sig.Valid) {
        $sc = 15
        [void]$why.Add('imzali proxy dll, yayinci: ' + $sig.Subject)
    } else {
        $sc = 65
        [void]$why.Add('IMZASIZ ve taninmayan proxy/sistem dll ismi (' + $fi.Name + ') oyun/java klasorunde - hile enjeksiyonunda sik kullanilir')
    }
    $h = Get-NameHit $fi.Name $false
    if ($h) { $sc += 40; [void]$why.Add('isim eslesmesi: ' + $h.Name) }
    $nt = ($why -join '; ')
    if ($sha) { $nt = $nt + ' | SHA256: ' + $sha }
    if ($ctx) { $nt = $nt + ' | ' + $ctx }
    Add-F -Kaynak $kaynak -Ad ($fi.Name.ToLower()) -Yol $p -Skor ([Math]::Min(100, $sc)) -Son $fi.LastWriteTime -Ilk $fi.CreationTime -Var 'Evet' -Not $nt
}

# =====================================================================
Step '[14+/17] A) JAVAW/JAVA Prefetch: calisma sirasinda acilan dosyalar (.jar ve uzantisi degistirilmis jar)...'
Start-Sec
$jvPf = @($pfFiles | Where-Object { $_.Name -match '(?i)^JAVAW?\.EXE-[0-9A-F]{8}\.pf$' })
if ($jvPf.Count -eq 0 -and ((Test-Path -LiteralPath ($env:APPDATA + '\.minecraft')) -or $script:GameDirs.Count -gt 0)) {
    Add-Sys 'JAVAW/JAVA Prefetch kaydi YOK' 30 '.minecraft klasoru var ama java.exe/javaw.exe icin Prefetch kaydi bulunamadi; kayit silinmis olabilir (WinPrefetchView ile bakilan ilk yer burasi).'
}
$jvSeen = @{}
$jvCount = 0
foreach ($jpf in $jvPf) {
    $info = Read-Prefetch $jpf.FullName
    $last = $jpf.LastWriteTime
    $runsTxt = ''
    Log ('   ' + $jpf.Name + ': ' + @($info.Runs).Count + ' calisma saati, ' + @($info.Paths).Count + ' dosya yolu okundu') 'DarkGray'
    if (@($info.Paths).Count -eq 0) { Log '     (bu Prefetch dosyasindan yol okunamadi: bozuk/bos olabilir veya yardimci modul derlenmemis)' 'DarkYellow' }
    if ($info.Runs.Count -gt 0) {
        $sorted = @($info.Runs | Sort-Object -Descending)
        $last = $sorted[0]
        $runsTxt = 'Prefetch calisma saatleri: ' + ((@($sorted | Select-Object -First 8) | ForEach-Object { Fmt $_ }) -join ', ')
    }
    foreach ($raw in $info.Paths) {
        $rr = $null
        if ($raw -match '^\\VOLUME\{') { $rr = Resolve-PfPath $raw }
        elseif ($raw -match '^\\DEVICE\\HARDDISKVOLUME\d+\\') { $rr = Resolve-NtPath $raw }
        else { continue }
        $p = $rr.Path
        $lk = $p.ToLower()
        if ($jvSeen.ContainsKey($lk)) { continue }
        $jvSeen[$lk] = 1
        $ext = ''
        $leaf = ''
        try { $ext = [IO.Path]::GetExtension($p).ToLower(); $leaf = Split-Path -Leaf $p } catch {}
        if (-not $leaf) { continue }
        $jvCount++
        $zone = Get-Zone $p
        $isLib = ($p -match '(?i)\\(\.minecraft|\.lunarclient|ModrinthApp|PrismLauncher|\.tlauncher|\.feather|\.ichor)\\(libraries|assets|versions|runtime|bin)\\') -or ($p -match '(?i)^[A-Za-z]:\\(Windows|Program Files|Program Files \(x86\))\\')
        $sc = 0
        $why = New-Object System.Collections.Generic.List[string]
        $hit = Get-NameHit $leaf $false
        if ($hit) { $sc += 50; [void]$why.Add('isim eslesmesi: ' + $hit.Name) }
        $var = 'Bilinmiyor'
        if ($ext -eq '.jar') {
            if ($isLib -and -not $hit) { continue }
            if ($rr.Removed) {
                $var = 'Hayir'; $sc += 40; [void]$why.Add('javaw tarafindan acilan jar, surucu cikarilmis')
            } elseif (-not $rr.Exists) {
                $var = 'Hayir'
                if ($zone -eq 'user' -or $zone -eq 'temp' -or $zone -eq 'appdata' -or $zone -eq 'shared') { $sc += 40 } else { $sc += 25 }
                [void]$why.Add('javaw tarafindan acilan jar su an YOK (silinmis olabilir; silinen mod da olabilir)')
            } else {
                $var = 'Evet'
                $jr = Inspect-Jar $p
                if ($jr.Hit) { $sc += 40; [void]$why.Add('jar ICINDE hile modulu/istemci ismi: ' + $jr.Hit) }
                if ($jr.Agent) { $sc += 30; [void]$why.Add('jar bir Java agent (' + $jr.AgentClass + ')') }
                if ($zone -eq 'user' -or $zone -eq 'temp') { $sc += 10; [void]$why.Add('kullanici/temp klasorunde jar') }
            }
        } elseif ($rr.Exists -and -not $isLib -and (($DisguiseExt -contains $ext) -or $ext -eq '')) {
            $var = 'Evet'
            $fl = $null
            try { $fl = Get-Item -LiteralPath $p -Force -ErrorAction Stop } catch {}
            if ($fl -and -not $fl.PSIsContainer -and $fl.Length -ge 20480) {
                $mg = Get-Magic $p
                if ($mg -eq 'PK') { $sc += 65; [void]$why.Add('javaw acmis; uzanti ' + $ext + ' ama icerik ZIP/JAR (PK) - jar baska uzantiyla gizlenmis') }
                elseif ($mg -eq 'MZ') { $sc += 65; [void]$why.Add('javaw acmis; uzanti ' + $ext + ' ama icerik EXE/DLL (MZ)') }
            }
        }
        if ($sc -ge 25) {
            $nt = ($why -join '; ')
            if ($runsTxt) { $nt = $nt + ' | ' + $runsTxt }
            Add-F -Kaynak ('Prefetch: ' + $jpf.Name) -Ad $leaf.ToLower() -Yol $p -Skor ([Math]::Min(100, $sc)) -Son $last -Ilk $jpf.CreationTime -Var $var -Not $nt
        }
    }
}
Log ('   ' + $jvPf.Count + ' java/javaw Prefetch dosyasi, ' + $jvCount + ' dosya yolu incelendi.') 'DarkGray'
Show-Section

# =====================================================================
Step '[14+/17] B) JavaLauncher.log: java -jar ile baslatilan dosyalar (uzantisi degistirilmis jar)...'
Start-Sec
$tempDirs = New-Object System.Collections.Generic.List[string]
foreach ($t0 in @($env:TEMP, ($env:WINDIR + '\Temp'))) { if ($t0) { [void]$tempDirs.Add($t0) } }
foreach ($ud in $script:HkUserDirs) { [void]$tempDirs.Add((Join-Path $ud.FullName 'AppData\Local\Temp')) }
$jlSeenF = @{}
$jlSeenK = @{}
$jlTotal = 0
foreach ($tdir in $tempDirs) {
    if (-not (Test-Path -LiteralPath $tdir)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $tdir -Filter 'JavaLauncher*' -File -Force -ErrorAction SilentlyContinue)) {
        $fk = $f.FullName.ToLower()
        if ($jlSeenF.ContainsKey($fk)) { continue }
        $jlSeenF[$fk] = 1
        $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
        $n = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $ln = [string]$lines[$i]
            if ($ln -notmatch '(?i)-jar\s') { continue }
            $tm = $null
            for ($j = $i; $j -lt [Math]::Min($lines.Count, $i + 5); $j++) {
                $tmm = [regex]::Match([string]$lines[$j], '\[(\d{4}/\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2})')
                if ($tmm.Success) {
                    try { $tm = [datetime]::ParseExact(($tmm.Groups[1].Value -replace '\s+', ' '), 'yyyy/MM/dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) } catch {}
                    break
                }
            }
            foreach ($m in [regex]::Matches($ln, '(?i)-jar\s+(?:"([^"]+)"|([^\s")]+))')) {
                $a = $m.Groups[1].Value
                if (-not $a) { $a = $m.Groups[2].Value }
                if (-not $a) { continue }
                $dk = $a.ToLower() + '|' + [string]$tm
                if ($jlSeenK.ContainsKey($dk)) { continue }
                $jlSeenK[$dk] = 1
                $n++
                $jlTotal++
                Eval-JarArg $a 'JavaLauncher.log (-jar)' $tm ('log dosyasi: ' + $f.FullName)
            }
        }
        Log ('   ' + $f.FullName + ' : ' + $n + ' adet -jar kaydi (son degisim: ' + (Fmt $f.LastWriteTime) + ')') 'DarkGray'
    }
}
if ($jlSeenF.Count -eq 0) { Log '   JavaLauncher.log bulunamadi (bu dosya her bilgisayarda olmayabilir).' 'DarkGray' }
Show-Section

# =====================================================================
Step '[14+/17] C) Bellek: DcomLaunch (-jar), explorer (.jar), conhost (-jar) taramasi (System Informer mantigi)...'
Start-Sec
if (-not $script:HkOk) {
    Log '   yardimci modul derlenemedi, bellek taramasi atlandi.' 'DarkYellow'
} else {
    try { [void][HkNative]::EnableDebug() } catch {}
    $dcom = Get-CimInstance Win32_Service -Filter "Name='DcomLaunch'"
    if ($dcom -and $dcom.ProcessId -gt 0) { Scan-MemJar 'DcomLaunch' ([int]$dcom.ProcessId) '-jar' $false }
    foreach ($gp in @(Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Scan-MemJar 'explorer' $gp.Id '\.jar' $true }
    foreach ($gp in @(Get-Process -Name conhost -ErrorAction SilentlyContinue | Select-Object -First 12)) { Scan-MemJar 'conhost' $gp.Id '-jar' $false }
}
Show-Section

# =====================================================================
Step '[14+/17] D) PowerShell: komut gecmisi, olay gunlukleri (400/403/600/800/4104), profil scriptleri...'
Start-Sec
$psSeen = @{}
foreach ($ud in $script:HkUserDirs) {
    $hd = Join-Path $ud.FullName 'AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine'
    $hp = Join-Path $hd 'ConsoleHost_history.txt'
    $isMe = ($ud.FullName -ieq $env:USERPROFILE)
    if (-not (Test-Path -LiteralPath $hp)) {
        if ($isMe) { Add-Sys 'PowerShell komut gecmisi dosyasi (ConsoleHost_history.txt) YOK' 20 'Hic PowerShell kullanilmamis olabilir; ama silinmis de olabilir (asagidaki USN kontrolune bak).' }
        continue
    }
    $hf = Get-Item -LiteralPath $hp -Force
    if ($hf.Length -eq 0) { Add-Sys ('PowerShell komut gecmisi BOS (' + $ud.Name + ')') 30 'ConsoleHost_history.txt var ama icerigi bos; icerigi silinmis olabilir.' $null ('boyut=0') $hf.LastWriteTime }
    if ($hf.Attributes -band [IO.FileAttributes]::ReadOnly) { Add-Sys ('PowerShell gecmis dosyasi SALT OKUNUR (' + $ud.Name + ')') 40 'Dosya salt okunur yapilarak PSReadLine yeni komut yazamaz hale getirilmis olabilir.' $null $hp $hf.LastWriteTime }
    foreach ($hx in @(Get-ChildItem -LiteralPath $hd -Filter '*_history.txt' -File -Force -ErrorAction SilentlyContinue)) {
        foreach ($ln in @(Get-Content -LiteralPath $hx.FullName -ErrorAction SilentlyContinue)) {
            $l = [string]$ln
            if ([string]::IsNullOrWhiteSpace($l)) { continue }
            if ($l -match $script:OwnMarkers) { continue }
            $k = $l.Trim().ToLower()
            if ($psSeen.ContainsKey($k)) { continue }
            $psSeen[$k] = 1
            Analyze-PsText $l ('PowerShell gecmisi (' + $ud.Name + ')') $hx.LastWriteTime $false
        }
    }
}
try {
    $o = Get-PSReadLineOption -ErrorAction Stop
    if ([string]$o.HistorySaveStyle -eq 'SaveNothing') { Add-Sys 'PSReadLine gecmis kaydi KAPALI (SaveNothing)' 45 'Komut gecmisi hic kaydedilmiyor; iz birakmamak icin ayarlanmis olabilir.' }
} catch {}

# Olay gunlugu acik mi / cok mu kucuk
foreach ($lname in @('Windows PowerShell', 'Microsoft-Windows-PowerShell/Operational')) {
    try {
        $lg = Get-WinEvent -ListLog $lname -ErrorAction Stop
        if (-not $lg.IsEnabled) { Add-Sys ('PowerShell olay gunlugu KAPALI: ' + $lname) 50 'Olay Goruntuleyicisinde bu gunluk kapatilmis; PowerShell calistirma izi tutulmuyor (bypass girisimi sayilir).' }
        elseif ($lg.MaximumSizeInBytes -lt 1048576) { Add-Sys ('PowerShell olay gunlugu cok kucuk: ' + $lname) 20 'Gunluk boyutu 1 MB altinda; eski kayitlar hemen uzerine yazilir.' $null ('MaxSize=' + $lg.MaximumSizeInBytes) }
    } catch {}
}
# Windows PowerShell (klasik) gunlugu: 400 / 600 = oturum acildi (HostApplication = tam komut satiri)
$ev400 = @()
try { $ev400 = @(Get-WinEvent -FilterHashtable @{ LogName = 'Windows PowerShell'; Id = 400, 403, 600 } -MaxEvents 600 -ErrorAction Stop) } catch {}
$evSeen = @{}
foreach ($e in $ev400) {
    $msg = [string]$e.Message
    if ($msg -match $script:OwnMarkers) { continue }
    $hm = [regex]::Match($msg, '(?im)HostApplication=(.+)$')
    if (-not $hm.Success) { continue }
    $ha = $hm.Groups[1].Value.Trim()
    $k = $ha.ToLower()
    if ($evSeen.ContainsKey($k)) { continue }
    $evSeen[$k] = 1
    Analyze-PsText $ha 'PowerShell olay gunlugu (400/600 HostApplication)' $e.TimeCreated $true
}
# 800 = pipeline calistirma ayrintilari (CommandLine)
try {
    foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Windows PowerShell'; Id = 800 } -MaxEvents 300 -ErrorAction Stop)) {
        $msg = [string]$e.Message
        if ($msg -match $script:OwnMarkers) { continue }
        if ($msg.Length -gt 3000) { $msg = $msg.Substring(0, 3000) }
        $k = $msg.Substring(0, [Math]::Min(200, $msg.Length)).ToLower()
        if ($evSeen.ContainsKey($k)) { continue }
        $evSeen[$k] = 1
        Analyze-PsText $msg 'PowerShell olay gunlugu (800)' $e.TimeCreated $false
    }
} catch {}
# 4104 = script blogu (Operational)
try {
    foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-PowerShell/Operational'; Id = 4104 } -MaxEvents 400 -ErrorAction Stop | Where-Object { $_.ProcessId -ne $PID })) {
        $msg = [string]$e.Message
        if ($msg -match $script:OwnMarkers) { continue }
        if ($msg.Length -gt 6000) { $msg = $msg.Substring(0, 6000) }
        $k = $msg.Substring(0, [Math]::Min(200, $msg.Length)).ToLower()
        if ($evSeen.ContainsKey($k)) { continue }
        $evSeen[$k] = 1
        Analyze-PsText $msg 'PowerShell olay gunlugu (4104 script blogu)' $e.TimeCreated $false
    }
} catch {}
# powershell.exe Prefetch'te calismis ama olay gunlugunde karsiligi yok mu
$psPf = @($pfFiles | Where-Object { $_.Name -match '(?i)^POWERSHELL\.EXE-' } | Select-Object -First 1)
if ($psPf.Count -gt 0 -and $ev400.Count -gt 0) {
    $pinfo = Read-Prefetch $psPf[0].FullName
    $oldestEv = $ev400[$ev400.Count - 1].TimeCreated
    $un = 0
    $tot = 0
    foreach ($rt in @($pinfo.Runs | Sort-Object -Descending | Select-Object -First 8)) {
        if ($rt -lt $oldestEv) { continue }
        $tot++
        $mt = @($ev400 | Where-Object { [Math]::Abs(($_.TimeCreated - $rt).TotalSeconds) -le 120 })
        if ($mt.Count -eq 0) { $un++ }
    }
    if ($un -ge 2 -and $un -ge ($tot / 2)) {
        Add-Sys ('powershell.exe ' + $un + '/' + $tot + ' kez calistirilmis ama olay gunlugunde karsiligi yok') 40 'Prefetch calisma saatleriyle Windows PowerShell gunlugu (400/600) eslesmiyor; gunluk kapatilmis, temizlenmis veya kayit engellenmis olabilir.'
    }
}
# Profil scriptleri (her PowerShell acilisinda calisir)
$profFiles = New-Object System.Collections.Generic.List[string]
try { foreach ($pp in @($PROFILE.AllUsersAllHosts, $PROFILE.AllUsersCurrentHost, $PROFILE.CurrentUserAllHosts, $PROFILE.CurrentUserCurrentHost)) { if ($pp) { [void]$profFiles.Add([string]$pp) } } } catch {}
foreach ($ud in $script:HkUserDirs) {
    foreach ($rel in @('Documents\WindowsPowerShell\profile.ps1', 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1', 'Documents\PowerShell\profile.ps1', 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')) { [void]$profFiles.Add((Join-Path $ud.FullName $rel)) }
}
$profSeen = @{}
foreach ($pf2 in $profFiles) {
    $pk = $pf2.ToLower()
    if ($profSeen.ContainsKey($pk)) { continue }
    $profSeen[$pk] = 1
    if (-not (Test-Path -LiteralPath $pf2)) { continue }
    $pitem = Get-Item -LiteralPath $pf2 -Force
    $ptxt = ''
    try { $ptxt = [IO.File]::ReadAllText($pf2) } catch {}
    if ($ptxt.Length -gt 100000) { $ptxt = $ptxt.Substring(0, 100000) }
    if ($ptxt) {
        Analyze-PsText $ptxt 'PowerShell profil scripti' $pitem.LastWriteTime $true
        Add-Sys ('PowerShell profil scripti var: ' + $pf2) 12 'Bu script her PowerShell acilisinda otomatik calisir; icerigi elle kontrol et.' $null $null $pitem.LastWriteTime
    }
}
Show-Section

# =====================================================================
Step '[14+/17] E) USN: ConsoleHost_history.txt ve JavaLauncher.log silinme kayitlari...'
Start-Sec
$usnHit = 0
foreach ($dl in $script:FixedNtfs) {
    & fsutil usn queryjournal $dl 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { continue }
    Log ('   USN gunlugu taraniyor: ' + $dl) 'DarkGray'
    $rows = @(Read-UsnPattern $dl @('ConsoleHost_history', 'JavaLauncher'))
    foreach ($grp in @('ConsoleHost_history', 'JavaLauncher')) {
        $dels = @($rows | Where-Object { $_.Silme -and $_.Ad -and ($_.Ad -match $grp) } | Sort-Object Zaman -Descending)
        if ($dels.Count -gt 0) {
            $usnHit++
            $skor = 35
            $baslik = 'JavaLauncher.log'
            $acik = 'Bu log (java -jar kayitlari) silinmis; Java bazen kendisi de yeniler, ama zamanina bak.'
            if ($grp -eq 'ConsoleHost_history') {
                $skor = 40
                $baslik = 'PowerShell komut gecmisi (ConsoleHost_history.txt)'
                $acik = 'PowerShell komut gecmisi dosyasi silinmis (USN gunlugu); iz temizleme girisimi olabilir.'
            }
            Add-Sys ($baslik + ' SILINMIS (' + $dl + ', ' + $dels.Count + ' silme kaydi)') $skor $acik $dels[0].Zaman ('en son silinme: ' + (Fmt $dels[0].Zaman))
        }
    }
}
if ($usnHit -eq 0) { Log '   USN gunlugunde ilgili silme kaydi bulunamadi.' 'DarkGray' }
Show-Section

# =====================================================================
Step '[14+/17] F) ENB / ReShade ve proxy dll (d3d9/d3d10/d3d11/dxgi/opengl32...) + grafik modu loglari...'
Start-Sec
$pdRoots = New-Object System.Collections.Generic.List[string]
function Add-PdRoot([string]$r) {
    if ([string]::IsNullOrWhiteSpace($r)) { return }
    if (-not (Test-Path -LiteralPath $r)) { return }
    foreach ($e in $pdRoots) { if ($e -ieq $r) { return } }
    [void]$pdRoots.Add($r)
}
foreach ($g in $script:GameDirs) { Add-PdRoot $g }
foreach ($r in $script:ScanRoots) { Add-PdRoot $r }
Add-PdRoot ($env:APPDATA + '\.minecraft')
Add-PdRoot ($env:USERPROFILE + '\.minecraft')
foreach ($pr in $procs) {
    if ($pr.Name -match '(?i)^javaw?\.exe$' -and $pr.ExecutablePath) {
        try { Add-PdRoot (Split-Path -Parent $pr.ExecutablePath) } catch {}
    }
}
foreach ($jb in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if (-not $jb) { continue }
    foreach ($jn in @('Java', 'Eclipse Adoptium', 'Zulu', 'Microsoft', 'AdoptOpenJDK', 'BellSoft', 'Amazon Corretto', 'Minecraft Launcher')) { Add-PdRoot (Join-Path $jb $jn) }
}
$pdHeavy = '(?i)\\(node_modules|Cache|Code Cache|GPUCache|CacheStorage|Service Worker|IndexedDB|\.git|assets)(\\|$)'
$pdSeen = @{}
$pdCount = 0
$pdRI = 0
foreach ($root in $pdRoots) {
    $pdRI++
    Set-Frac (0.6 * $pdRI / [Math]::Max(1, $pdRoots.Count)) ('proxy dll klasor ' + $pdRI + '/' + $pdRoots.Count)
    Log ('   proxy dll taraniyor (' + $pdRI + '/' + $pdRoots.Count + '): ' + $root) 'DarkGray'
    foreach ($d in @(Get-ChildItem -LiteralPath $root -Recurse -Depth 8 -File -Force -Filter '*.dll' -ErrorAction SilentlyContinue)) {
        if ($d.Name -notmatch $script:ProxyDllRx) { continue }
        if ($d.FullName -match $pdHeavy) { continue }
        $dk = $d.FullName.ToLower()
        if ($pdSeen.ContainsKey($dk)) { continue }
        $pdSeen[$dk] = 1
        $pdCount++
        Eval-ProxyDll $d.FullName 'Proxy dll taramasi (ENB/ReShade/hile)' $d.LastWriteTime ''
    }
}
foreach ($pr in $procs) {
    if ($pr.Name -notmatch '(?i)^javaw?\.exe$') { continue }
    try {
        $gp = Get-Process -Id $pr.ProcessId -ErrorAction Stop
        foreach ($mod in $gp.Modules) {
            if ($mod.ModuleName -notmatch $script:ProxyDllRx) { continue }
            if ($mod.FileName -match '(?i)^[A-Za-z]:\\Windows\\') { continue }
            $dk = $mod.FileName.ToLower()
            if ($pdSeen.ContainsKey($dk)) { continue }
            $pdSeen[$dk] = 1
            $pdCount++
            Eval-ProxyDll $mod.FileName 'Calisan Java: yuklu proxy dll' $pr.CreationDate ('PID ' + $pr.ProcessId + ' icine yuklenmis')
        }
    } catch {}
}
Log ('   ' + $pdCount + ' proxy dll adayi incelendi.') 'DarkGray'

# "Loaded graphics mod" / ReShade / ENB izleri: Minecraft loglari
$gfxRx = '(?i)Loaded graphics mod|reshade|enbseries|enblocal'
$gfxFiles = New-Object System.Collections.Generic.List[object]
$gfxSeen = @{}
foreach ($lf in $script:LogCand) {
    $lk = $lf.FullName.ToLower()
    if (-not $gfxSeen.ContainsKey($lk)) { $gfxSeen[$lk] = 1; [void]$gfxFiles.Add($lf) }
}
$latestCands = New-Object System.Collections.Generic.List[string]
[void]$latestCands.Add($env:APPDATA + '\.minecraft\logs\latest.log')
foreach ($g in $script:GameDirs) { [void]$latestCands.Add($g + '\logs\latest.log') }
foreach ($lc in $latestCands) {
    if (Test-Path -LiteralPath $lc) {
        $lk = $lc.ToLower()
        if (-not $gfxSeen.ContainsKey($lk)) { $gfxSeen[$lk] = 1; [void]$gfxFiles.Add((Get-Item -LiteralPath $lc -Force)) }
    }
}
foreach ($base in @($env:LOCALAPPDATA, $env:APPDATA)) {
    foreach ($mr in @(Get-ChildItem -LiteralPath $base -Directory -Filter 'Minecraft*' -Force -ErrorAction SilentlyContinue)) {
        foreach ($f in @(Get-ChildItem -LiteralPath $mr.FullName -Recurse -Depth 4 -File -Force -Filter '*.log' -ErrorAction SilentlyContinue)) {
            $lk = $f.FullName.ToLower()
            if (-not $gfxSeen.ContainsKey($lk)) { $gfxSeen[$lk] = 1; [void]$gfxFiles.Add($f) }
        }
    }
}
$gfxHit = 0
$gfI = 0
foreach ($lf in @($gfxFiles | Sort-Object LastWriteTime -Descending)) {
    $gfI++
    Set-Frac (0.6 + 0.4 * $gfI / [Math]::Max(1, $gfxFiles.Count)) ('grafik logu ' + $gfI + '/' + $gfxFiles.Count)
    if ($lf.Length -gt 31457280) { continue }
    $txt = Read-LogText $lf.FullName
    if (-not $txt) { continue }
    $mm = [regex]::Match($txt, ($gfxRx + '[^\r\n]{0,160}'))
    if ($mm.Success) {
        $gfxHit++
        Add-F -Kaynak 'Minecraft logu: grafik modu izi' -Ad ('log: ' + $lf.Name.ToLower()) -Yol $lf.FullName -Skor 40 -Son $lf.LastWriteTime -Ilk $lf.CreationTime -Var 'Evet' -Not ('logda grafik modu/ENB/ReShade ifadesi: ' + ($mm.Value -replace '\s+', ' ') + ' | ENB/ReShade mesru olabilir; dll konumunu, imzasini ve SHA256 degerini kontrol et')
    }
}
Log ('   ' + $gfxFiles.Count + ' log dosyasindan ' + $gfxFiles.Count + ' tanesi tarandi, ' + $gfxHit + ' tanesinde grafik modu izi var.') 'DarkGray'
Show-Section
# ===================== EK MODUL SONU =====================

# =====================================================================
Step '[14+/17] G) Dizinlenmis konumlar (Searches\*.search-ms, "Indexed Locations")...'
Start-Sec
$isCount = 0
$isSeen = @{}
foreach ($ud in $script:HkUserDirs) {
    $sdir = Join-Path $ud.FullName 'Searches'
    if (-not (Test-Path -LiteralPath $sdir)) { continue }
    foreach ($sf in @(Get-ChildItem -LiteralPath $sdir -Filter '*.search-ms' -File -Force -ErrorAction SilentlyContinue)) {
        $stxt = ''
        try { $stxt = [IO.File]::ReadAllText($sf.FullName) } catch {}
        if (-not $stxt) { continue }
        try { $stxt = [System.Net.WebUtility]::HtmlDecode($stxt) } catch {}
        foreach ($m in [regex]::Matches($stxt, '[A-Za-z]:\\[^<>"|*?\r\n]{2,240}')) {
            $pth = $m.Value.Trim().TrimEnd('\')
            $lk = $pth.ToLower()
            if ($isSeen.ContainsKey($lk)) { continue }
            $isSeen[$lk] = 1
            $isCount++
            $pi = Get-PiCached $pth
            $zone = Get-Zone $pth
            $sc = 0
            $why = New-Object System.Collections.Generic.List[string]
            $h = Get-NameHit $pth $false
            if ($h) { $sc += 45; [void]$why.Add('dizinlenmis konum yolunda hile ismi: ' + $h.Name) }
            if ($pi.Removed) {
                $sc += 20; [void]$why.Add('cikarilmis/eski surucudeki klasor')
            } elseif (-not $pi.Exists -and ($zone -eq 'user' -or $zone -eq 'temp' -or $zone -eq 'appdata' -or $zone -eq 'shared')) {
                $sc += 25; [void]$why.Add('dizinlenmis klasor artik YOK (silinmis klasor olabilir)')
            }
            if ($sc -ge 20) {
                $var = 'Evet'
                if (-not $pi.Exists) { $var = 'Hayir' }
                $leaf = $pth
                try { $leaf = Split-Path -Leaf $pth } catch {}
                Add-F -Kaynak 'Dizinlenmis konumlar (.search-ms)' -Ad ('dizin: ' + $leaf.ToLower()) -Yol $pth -Skor ([Math]::Min(100, $sc)) -Son $sf.LastWriteTime -Var $var -Not (($why -join '; ') + ' | dosya: ' + $sf.FullName)
            }
        }
    }
}
# Windows Search "Indexed Locations" (Dizin Olusturma Secenekleri): kayit defterindeki tarama kapsami kurallari
function Eval-IdxPath([string]$pth, [string]$src, $when) {
    $pth = $pth.Trim().TrimEnd('\')
    if ($pth.Length -lt 3) { return }
    $lk = $pth.ToLower()
    if ($isSeen.ContainsKey($lk)) { return }
    $isSeen[$lk] = 1
    $script:isCount = $script:isCount + 1
    $pi = Get-PiCached $pth
    $zone = Get-Zone $pth
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    $h = Get-NameHit $pth $false
    if ($h) { $sc += 45; [void]$why.Add('dizinlenmis konum yolunda hile ismi: ' + $h.Name) }
    if ($pi.Removed) {
        $sc += 20; [void]$why.Add('cikarilmis/eski surucudeki klasor')
    } elseif (-not $pi.Exists -and ($zone -eq 'user' -or $zone -eq 'temp' -or $zone -eq 'appdata' -or $zone -eq 'shared')) {
        $sc += 25; [void]$why.Add('dizinlenmis klasor artik YOK (silinmis klasor olabilir)')
    }
    if ($sc -ge 20) {
        $var = 'Evet'
        if (-not $pi.Exists) { $var = 'Hayir' }
        $leaf = $pth
        try { $leaf = Split-Path -Leaf $pth } catch {}
        Add-F -Kaynak 'Dizinlenmis konumlar (Windows Search)' -Ad ('dizin: ' + $leaf.ToLower()) -Yol $pth -Skor ([Math]::Min(100, $sc)) -Son $when -Var $var -Not (($why -join '; ') + ' | kaynak: ' + $src)
    }
}
$idxKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\WorkingSetRules',
    'HKLM:\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\DefaultRules',
    'HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex\Sites\LocalHost\Paths',
    'HKCU:\Software\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\WorkingSetRules'
)
$idxRegN = 0
foreach ($ik in $idxKeys) {
    foreach ($sk in @(Get-ChildItem -LiteralPath $ik -ErrorAction SilentlyContinue)) {
        $url = ''
        try { $url = [string]$sk.GetValue('URL') } catch {}
        if (-not $url) { continue }
        if ($url -notmatch '(?i)^file:///') { continue }
        $p2 = ($url -replace '(?i)^file:///', '') -replace '/', '\'
        $p2 = $p2 -replace '\\\*$', ''
        if ($p2 -notmatch '^[A-Za-z]:') { continue }
        $idxRegN++
        $kt = $null
        try { $kt = Get-KeyTime $sk } catch {}
        Eval-IdxPath $p2 ('kayit defteri: ' + $ik) $kt
    }
}
Log ('   kayit defterinden ' + $idxRegN + ' dizin kapsami kurali okundu.') 'DarkGray'
Log ('   ' + $isCount + ' dizinlenmis konum incelendi.') 'DarkGray'
Show-Section

# =====================================================================
Step '[14+/17] H) Process modulleri (System Informer > Modules mantigi): sistem DLL taklidi, AppData/Temp DLL...'
Start-Sec
$sysDll = @{}
foreach ($sdp in @(($env:WINDIR + '\System32'), ($env:WINDIR + '\SysWOW64'))) {
    foreach ($nm in @(Get-ChildItem -LiteralPath $sdp -Filter '*.dll' -File -Force -Name -ErrorAction SilentlyContinue)) { $sysDll[([string]$nm).ToLower()] = 1 }
}
$knownNat = '(?i)^(lwjgl|glfw|openal|jemalloc|stb|tinyfd|nanovg|nfd|jna|sqlite|libusb|vcruntime|msvcp|concrt|ucrtbase|api-ms)'
$modSeen = @{}
$modProcCnt = 0
foreach ($pr in $procs) {
    $pn = [string]$pr.Name
    if (-not $pn -or $pr.ProcessId -le 4 -or $pr.ProcessId -eq $PID) { continue }
    $isJavaP = ($pn -match '(?i)^javaw?\.exe$')
    $isExpl = ($pn -ieq 'explorer.exe')
    $gp = $null
    try { $gp = Get-Process -Id $pr.ProcessId -ErrorAction Stop } catch { continue }
    $mods = $null
    try { $mods = @($gp.Modules) } catch { continue }
    $modProcCnt++
    foreach ($mod in $mods) {
        $mp = [string]$mod.FileName
        if (-not $mp -or $mp -notmatch '^[A-Za-z]:\\') { continue }
        if ($mp -match '(?i)^[A-Za-z]:\\(Windows|Program Files|Program Files \(x86\))\\') { continue }
        $mk = $mp.ToLower()
        if ($modSeen.ContainsKey($mk)) { continue }
        $modSeen[$mk] = 1
        $mn = ([string]$mod.ModuleName).ToLower()
        if ($mn -notmatch '\.(dll|ocx|drv)$') { continue }
        $sc = 0
        $why = New-Object System.Collections.Generic.List[string]
        if ($sysDll.ContainsKey($mn)) {
            $sc += 70; [void]$why.Add('sistem DLL ismi (System32 icinde de var) ama baska klasorden yuklenmis')
        } else {
            $norm = (($mn -replace '1', 'l') -replace '0', 'o') -replace 'rn', 'm'
            if ($norm -ne $mn -and $sysDll.ContainsKey($norm)) { $sc += 60; [void]$why.Add('sistem DLL ismine benziyor (' + $norm + ')') }
        }
        $hit = Get-NameHit $mn $false
        if ($hit) { $sc += 50; [void]$why.Add('isim eslesmesi: ' + $hit.Name) }
        if ($isJavaP -or $isExpl) {
            $zone = Get-Zone $mp
            $isNat = ($mn -match $knownNat) -and ($mp -match '(?i)\\(lwjgl|\.minecraft|natives|ModrinthApp|PrismLauncher|\.lunarclient|Temp)\\')
            $launcherDir = ($mp -match '(?i)\\(\.minecraft|\.lunarclient|ModrinthApp|PrismLauncher|\.tlauncher|\.feather|\.ichor)\\|\\(runtime|jre|jdk|java)[^\\]*\\')
            if (($zone -eq 'appdata' -or $zone -eq 'temp' -or $zone -eq 'shared' -or $zone -eq 'user') -and -not $isNat -and -not $launcherDir) {
                if (-not (Test-Signed $mp)) { $sc += 40; [void]$why.Add('IMZASIZ DLL, ' + $zone + ' klasorunden yuklenmis') }
            } elseif ($zone -eq 'other' -and $isJavaP -and -not $launcherDir -and -not (Test-Signed $mp)) {
                $sc += 25; [void]$why.Add('Java icine olagan disi klasorden imzasiz DLL yuklenmis')
            }
        }
        if ($sc -ge 30) {
            $mdir = ''
            try { $mdir = Split-Path -Parent $mp } catch {}
            Add-F -Kaynak ('Process modulleri: ' + $pn) -Ad $mn -Yol $mp -Skor ([Math]::Min(100, $sc)) -Son $pr.CreationDate -Var 'Evet' -Not (($why -join '; ') + ' | process: ' + $pn + ' (PID ' + $pr.ProcessId + ') | DLL klasoru: ' + $mdir)
        }
    }
}
Log ('   ' + $modProcCnt + ' process modul listesi incelendi (korumali process ler atlanir).') 'DarkGray'
Show-Section
# ===================== EK MODUL 2 SONU =====================

# ---------------------------------------------------------------------
# =====================================================================
# BYPASS GECMISI MODULU: gecmiste yapilmis iz silme/bypass islemlerinin kalintilarini arar
# (Sadece OKUR; hicbir seyi silmez/degistirmez.)
# =====================================================================
Step '[14+/17] I) BYPASS GECMISI: olay zaman cizelgesi, USN/olay gunlugu temizleme, saat degisikligi, kutu bosaltma, toplu Prefetch silme, BAM karsilastirma...'
Start-Sec
function Add-Bt([string]$tur, $zaman) {
    if ($zaman) { [void]$script:Bt.Add([pscustomobject]@{ Tur = $tur; Zaman = [datetime]$zaman }) }
}
function Test-UsnBasicInfo([string]$ln) {
    if ($ln -match '(?i)basic info change') { return $true }
    foreach ($mm in [regex]::Matches($ln, '0x[0-9A-Fa-f]{8}(?![0-9A-Fa-f])')) {
        $val = [Convert]::ToUInt32($mm.Value.Substring(2), 16)
        if (($val -band 0x8000) -ne 0) { return $true }
    }
    return $false
}
# Prefetch (.pf) ile ilgili USN satirlarini okur: silme / nitelik-zaman degisikligi
function Read-UsnPfLines([string]$dl) {
    $res = New-Object System.Collections.Generic.List[object]
    $lines = @(Select-UsnLines $dl @('.pf'))
    foreach ($ln in $lines) {
        $nm = Get-UsnName $ln
        if (-not $nm) { continue }
        if ($nm -notmatch '(?i)\.pf$') { continue }
        [void]$res.Add([pscustomobject]@{ Ad = $nm; Zaman = (Get-UsnTime $ln); Info = (Test-UsnBasicInfo $ln); Silme = (Test-UsnDelete $ln) })
    }
    return $res
}

$tl = New-Object System.Collections.Generic.List[string]
$osInstall = $null
try { $osInstall = [datetime](Get-CimInstance Win32_OperatingSystem).InstallDate } catch {}

# --- 1) USN gunlugu: olusturulma zamani (Journal ID = olusturulma zamani). Windows kurulumundan sonra yeniden olusturulduysa silinip acilmis olabilir ---
foreach ($dl in $script:FixedNtfs) {
    $qo = ''
    try { $qo = (& fsutil usn queryjournal $dl 2>&1 | Out-String) } catch {}
    $jm = [regex]::Match($qo, '0x([0-9A-Fa-f]{16})')
    if (-not $jm.Success) { continue }
    $jt = $null
    try { $jt = Ft ([Convert]::ToInt64($jm.Groups[1].Value, 16)) } catch {}
    if (-not $jt) { continue }
    [void]$tl.Add('USN Journal olusturulma zamani (' + $dl + '): ' + (Fmt $jt))
    if ($osInstall -and $jt -gt $osInstall.AddDays(3)) {
        $sk = 35
        if ($jt -gt (Get-Date).AddDays(-30)) { $sk = 50 }
        Add-Sys ('USN gunlugu Windows kurulumundan SONRA yeniden olusturulmus (' + $dl + ')') $sk 'USN gunlugu silinip (fsutil usn deletejournal) yeniden acilmis olabilir. Sonradan bicimlendirilen ikincil suruculerde bu normaldir; C: icin supheli.' $jt ('journal olusturulma: ' + (Fmt $jt) + ' | Windows kurulum: ' + (Fmt $osInstall)) $null
        Add-Bt 'USN gunlugu sifirlandi' $jt
    }
}

# --- 2) Olay gunlugu temizleme zamanlari (Security 1102 / System 104) ---
foreach ($spec in @(@('Security', 1102), @('System', 104))) {
    try {
        $ce = @(Get-WinEvent -FilterHashtable @{ LogName = $spec[0]; Id = $spec[1] } -MaxEvents 1 -ErrorAction Stop)
        if ($ce.Count -gt 0) {
            [void]$tl.Add('Olay gunlugu TEMIZLENMIS (' + $spec[0] + ' / olay ' + $spec[1] + '): ' + (Fmt $ce[0].TimeCreated))
            Add-Bt 'Olay gunlugu temizlendi' $ce[0].TimeCreated
        }
    } catch {}
}

# --- 3) Son kapanis (6006) ve Event Log servisi son baslama (6005) ---
try {
    $e6 = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'EventLog'; Id = 6006 } -MaxEvents 1 -ErrorAction Stop)
    if ($e6.Count -gt 0) { [void]$tl.Add('Son temiz kapanis (6006): ' + (Fmt $e6[0].TimeCreated)) }
} catch {}
try {
    $e5 = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'EventLog'; Id = 6005 } -MaxEvents 1 -ErrorAction Stop)
    if ($e5.Count -gt 0) { [void]$tl.Add('Event Log servisi son baslama (6005): ' + (Fmt $e5[0].TimeCreated)) }
} catch {}

# --- 4) Event Log servisi bilgisayar yeniden baslamadan durdurulup baslatilmis mi (6006 -> 6005 cifti, yaninda OS kapanis/acilis olayi yok) ---
try {
    $el = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'EventLog'; Id = 6005, 6006 } -MaxEvents 80 -ErrorAction Stop)
    $kg = @()
    try { $kg = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-General'; Id = 12, 13 } -MaxEvents 200 -ErrorAction Stop) } catch {}
    if ($kg.Count -gt 0) {
        $kgOldest = ($kg | Sort-Object TimeCreated | Select-Object -First 1).TimeCreated
        $restarts = New-Object System.Collections.Generic.List[object]
        foreach ($st in @($el | Where-Object { $_.Id -eq 6006 })) {
            if ($st.TimeCreated -lt $kgOldest) { continue }
            $nx = @($el | Where-Object { $_.Id -eq 6005 -and $_.TimeCreated -gt $st.TimeCreated -and $_.TimeCreated -lt $st.TimeCreated.AddMinutes(10) } | Sort-Object TimeCreated | Select-Object -First 1)
            if ($nx.Count -eq 0) { continue }
            $stT = $st.TimeCreated
            $nxT = $nx[0].TimeCreated
            $near = @($kg | Where-Object { ([Math]::Abs(($_.TimeCreated - $stT).TotalMinutes) -le 3) -or ([Math]::Abs(($_.TimeCreated - $nxT).TotalMinutes) -le 3) })
            if ($near.Count -eq 0) { [void]$restarts.Add($st) }
        }
        if ($restarts.Count -gt 0) {
            $rt = $restarts[0].TimeCreated
            Add-Sys ('Event Log servisi bilgisayar yeniden baslamadan durdurulup baslatilmis (' + $restarts.Count + ' kez)') 55 'EventLog servisi durdu (6006) ve hemen tekrar basladi (6005) ama Windows kapanis/acilis olayi yok; servis elle durdurularak olay kaydi atlatilmis olabilir (bypass yontemi).' $rt ('en son: ' + (Fmt $rt)) $null
            Add-Bt 'Event Log servisi elle yeniden baslatildi' $rt
            [void]$tl.Add('Event Log servisi ELLE yeniden baslatilmis: ' + (Fmt $rt))
        }
    }
} catch {}

# --- 5) Sistem saati degistirilmis mi (Kernel-General olay 1) ---
try {
    $tc = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-General'; Id = 1 } -MaxEvents 80 -ErrorAction Stop)
    if ($tc.Count -gt 0) { [void]$tl.Add('Sistem saati en son degisme olayi: ' + (Fmt $tc[0].TimeCreated)) }
    $bigN = 0
    foreach ($e in $tc) {
        $nt = $null
        $ot = $null
        try { $nt = [datetime]$e.Properties[0].Value; $ot = [datetime]$e.Properties[1].Value } catch {}
        if (-not $nt -or -not $ot) { continue }
        $df = [Math]::Abs(($nt - $ot).TotalSeconds)
        if ($df -le 120) { continue }
        $bigN++
        Add-Bt 'Sistem saati degistirildi' $e.TimeCreated
        if ($bigN -le 3) {
            $sk = 40
            if ($df -gt 3600) { $sk = 50 }
            Add-Sys ('Sistem saati ' + [Math]::Round($df / 60, 1) + ' dakika oynatilmis') $sk 'Saat degisikligi kayitlardaki zamanlari karistirmak/iz saklamak icin kullanilabilir (kucuk NTP duzeltmeleri filtrelendi, sadece 2 dakikadan buyukler gosterilir).' $e.TimeCreated ('eski: ' + (Fmt $ot) + ' -> yeni: ' + (Fmt $nt)) $null
        }
    }
} catch {}

# --- 6) Geri donusum kutusu yakin zamanda bosaltilmis gorunuyor mu ---
foreach ($dl in $script:Drives) {
    $bin = $dl + '\$Recycle.Bin'
    if (-not (Test-Path -LiteralPath $bin)) { continue }
    foreach ($sd in @(Get-ChildItem -LiteralPath $bin -Force -Directory -ErrorAction SilentlyContinue)) {
        $bitems = @(Get-ChildItem -LiteralPath $sd.FullName -Force -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })
        if ($bitems.Count -eq 0 -and $sd.LastWriteTime -gt (Get-Date).AddDays(-30)) {
            [void]$tl.Add('Geri donusum kutusu BOS, son degisiklik (' + $dl + '): ' + (Fmt $sd.LastWriteTime))
            Add-Sys ('Geri donusum kutusu yakin zamanda bosaltilmis gorunuyor (' + $dl + ')') 20 'Kutu su an bos ve klasorunun son degisim zamani son 30 gun icinde. Tek basina supheli degildir; bu zamani diger bypass olaylariyla karsilastir.' $sd.LastWriteTime ($sd.Name) $null
            Add-Bt 'Geri donusum kutusu bosaltildi' $sd.LastWriteTime
        }
    }
}
foreach ($kv in $script:BinEmptied.GetEnumerator()) {
    if ($kv.Value -gt (Get-Date).AddDays(-30)) { Add-Bt 'Geri donusum kutusu bosaltildi' $kv.Value }
}

# --- 7) Toplu Prefetch silme (kisa surede cok sayida .pf silinmesi) ---
$pfDelT = @($script:DeletedPf | Where-Object { $_.Zaman } | Sort-Object Zaman)
$bestN = 0
$bestT = $null
for ($i = 0; $i -lt $pfDelT.Count; $i++) {
    $n = 1
    for ($j = $i + 1; $j -lt $pfDelT.Count; $j++) {
        if ((([datetime]$pfDelT[$j].Zaman) - ([datetime]$pfDelT[$i].Zaman)).TotalMinutes -le 5) { $n++ } else { break }
    }
    if ($n -gt $bestN) { $bestN = $n; $bestT = [datetime]$pfDelT[$i].Zaman }
}
if ($bestN -ge 15) {
    Add-Sys ('Toplu Prefetch silme: 5 dakika icinde ' + $bestN + ' adet .pf silinmis') 55 'Prefetch klasoru toplu temizlenmis olabilir (Windows 1024 dosya sinirini asinca eskileri kendisi de silebilir, ama bu kadar yogun silme supheli).' $bestT ('baslangic: ' + (Fmt $bestT)) $null
    Add-Bt 'Prefetch toplu silindi' $bestT
    $nearRuns = @($script:Runs | Where-Object { (Get-Zone $_.Yol) -ne 'system' -and ([Math]::Abs((([datetime]$_.Zaman) - $bestT).TotalMinutes) -le 10) } | Sort-Object { [Math]::Abs((([datetime]$_.Zaman) - $bestT).TotalSeconds) } | Select-Object -First 20)
    [void]$tl.Add('Toplu Prefetch silme zamani (' + (Fmt $bestT) + ') +-10 dk cevresinde calisan sistem disi programlar (BAM/UserAssist/Prefetch kayitlari):')
    foreach ($nr in $nearRuns) { [void]$tl.Add('      ' + (Fmt $nr.Zaman) + '  ' + $nr.Yol + '  (' + $nr.Kaynak + ')') }
    if ($nearRuns.Count -eq 0) { [void]$tl.Add('      kayit yok (ilgili Prefetch/BAM/UserAssist kayitlari silinmis olabilir)') }
    [void]$tl.Add('Prefetch toplu silme (' + $bestN + ' dosya): ' + (Fmt $bestT))
}

# --- 8) Prefetch dosyalarinda nitelik/zaman degisikligi izi (USN BASIC_INFO_CHANGE = Salt Okunur/Gizli yapma izi) ---
$sysDrv = [string]$env:SystemDrive
if ($sysDrv -and ($script:FixedNtfs -contains $sysDrv.ToUpper())) {
    Log ('   Prefetch USN izleri okunuyor: ' + $sysDrv.ToUpper() + ' (biraz surebilir)...') 'DarkGray'
    $pfRows = @(Read-UsnPfLines $sysDrv.ToUpper())
    $infoRows = @($pfRows | Where-Object { $_.Info -and -not $_.Silme } | Sort-Object Zaman -Descending)
    if ($infoRows.Count -gt 0) {
        $iNames = (($infoRows | Select-Object -First 5 | ForEach-Object { $_.Ad + ' (' + (Fmt $_.Zaman) + ')' }) -join '; ')
        Add-Sys ('Prefetch dosyalarinda nitelik/zaman degisikligi izi (USN) - ' + $infoRows.Count + ' kayit') 30 'USN gunlugunde .pf dosyalari icin "basic info change" kaydi var: Salt Okunur/Gizli yapilmis veya zamani oynanmis olabilir. Tek basina kesin degil; asagidaki nitelik kontroluyle birlikte degerlendir.' $infoRows[0].Zaman $iNames $null
        Add-Bt 'Prefetch niteligi degistirildi' $infoRows[0].Zaman
    }
}

# --- 9) BAM karsilastirma: Prefetch'te son gunlerde calismis ama BAM'de HIC kaydi olmayan programlar (BAM anahtari silinmis olabilir) ---
if ($script:PfExecs.Count -gt 20 -and $bamCount -eq 0) {
    Add-Sys 'BAM kayitlari tamamen BOS' 45 'Prefetch kayitlari var ama BAM (UserSettings) hic kayit icermiyor; BAM anahtarlari silinmis veya bam servisi kapatilmis olabilir.'
} elseif ($bamCount -gt 0) {
    $cut5 = (Get-Date).AddDays(-5)
    $missList = New-Object System.Collections.Generic.List[string]
    foreach ($pe in $script:PfExecs) {
        if (-not $pe.Last -or $pe.Last -lt $cut5) { continue }
        if ($pe.Path -notmatch '^[A-Za-z]:\\') { continue }
        if ((Get-Zone $pe.Path) -eq 'system') { continue }
        $lf = ''
        try { $lf = (Split-Path -Leaf $pe.Path).ToLower() } catch {}
        if (-not $lf -or $lf -notmatch '\.exe$') { continue }
        if ($script:BamLeaves.ContainsKey($lf)) { continue }
        [void]$missList.Add($lf + ' (' + (Fmt $pe.Last) + ')')
        $bh = Get-NameHit $lf $false
        if ($bh) {
            Add-F -Kaynak 'BAM/Prefetch karsilastirma' -Ad $lf -Yol $pe.Path -Skor 60 -Son $pe.Last -Var $(if ($pe.Exists) { 'Evet' } else { 'Hayir' }) -Not ('Prefetch''te son 5 gunde calismis ama BAM''de kaydi YOK, hile ismi: ' + $bh.Name + ' | BAM anahtari silinmis olabilir (BamDeletedKeys araciyla da dogrula)')
        }
    }
    if ($missList.Count -ge 3) {
        Add-Sys ('Prefetch''te var ama BAM''de olmayan ' + $missList.Count + ' program (son 5 gun)') 25 'BAM''den degerler silinmis olabilir. BAM yalnizca kullanici oturumunda calisan programlari tutar; servis olarak calisanlar yanlis alarm uretebilir, listeyi elle incele.' $null (($missList | Select-Object -First 6) -join '; ') $null
    }
}

# --- 10) KOMBINASYON: 24 saat icinde birden fazla farkli bypass turu = klasik bypass paketi ---
$btS = @($script:Bt | Sort-Object Zaman)
$bestCnt = 0
$bestTxt = ''
$bestStart = $null
for ($i = 0; $i -lt $btS.Count; $i++) {
    $set = @{}
    for ($j = $i; $j -lt $btS.Count; $j++) {
        if (($btS[$j].Zaman - $btS[$i].Zaman).TotalHours -le 24) { $set[$btS[$j].Tur] = $btS[$j].Zaman } else { break }
    }
    if ($set.Count -gt $bestCnt) {
        $bestCnt = $set.Count
        $bestStart = $btS[$i].Zaman
        $bestTxt = (($set.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key + ' [' + (Fmt $_.Value) + ']' }) -join '; ')
    }
}
if ($bestCnt -ge 3) {
    Add-Sys ('BYPASS KOMBINASYONU: 24 saat icinde ' + $bestCnt + ' farkli iz silme/bypass olayi') 70 'USN sifirlama, olay gunlugu temizleme, saat degisikligi, Prefetch/geri donusum kutusu temizleme gibi olaylarin ayni gun icinde birlikte gorulmesi klasik bir bypass paketine isaret eder.' $bestStart $bestTxt $null
}

Log '' 'Gray'
Log '   --- OLAY ZAMAN CIZELGESI (bu zamanlar birbirine yakinsa bypass suphesi artar) ---' 'Cyan'
foreach ($t in $tl) { Log ('   ' + $t) 'Gray' }
if ($tl.Count -eq 0) { Log '   okunabilen olay yok' 'DarkGray' }
Show-Section

# ---------------------------------------------------------------------
Step '[15/17] Minecraft loglari (hile modulu isimleri, eski loglar dahil)...'
Start-Sec
$mcMain = $env:APPDATA + '\.minecraft'
if (Test-Path -LiteralPath $mcMain) {
    $lg = $mcMain + '\logs'
    $lgFiles = @()
    if (Test-Path -LiteralPath $lg) { $lgFiles = @(Get-ChildItem -LiteralPath $lg -File -Force -ErrorAction SilentlyContinue) }
    if ($lgFiles.Count -eq 0) { Add-Sys '.minecraft\logs klasoru bos/yok' 25 'Oyun loglari silinmis olabilir (normalde her oturumda log olusur).' }
}
$logs = @($script:LogCand | Sort-Object LastWriteTime -Descending)
$logHits = 0
$liN = 0
Log ('   ' + $logs.Count + ' log dosyasi okunacak...') 'DarkGray'
foreach ($lf in $logs) {
    $liN++
    Set-Frac ($liN / [Math]::Max(1, $logs.Count)) ('log ' + $liN + '/' + $logs.Count)
    if (($liN % 10) -eq 0) { Log ('   ' + $liN + '/' + $logs.Count + ' log okundu (%' + [int]($liN * 100 / [Math]::Max(1, $logs.Count)) + ')') 'DarkGray' }
    $txt = Read-LogText $lf.FullName
    if (-not $txt) { continue }
    if (-not (Get-NameHit $txt $false)) { continue }
    $shown = 0
    foreach ($line in $txt.Split("`n")) {
        if ($shown -ge 3) { break }
        $h = Get-NameHit $line $false
        if ($h) {
            $shown++
            $logHits++
            $ln2 = $line.Trim()
            if ($ln2.Length -gt 170) { $ln2 = $ln2.Substring(0, 170) + '...' }
            Add-F -Kaynak 'Minecraft logu' -Ad ('log: ' + $h.Name + ' | ' + $lf.Name.ToLower()) -Yol $lf.FullName -Skor 40 -Son $lf.LastWriteTime -Ilk $lf.CreationTime -Var 'Evet' -Not ('satir: ' + $ln2)
        }
    }
}
Log ('   ' + $logs.Count + ' log dosyasi incelendi.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[16/17] USB depolama gecmisi (harici surucuden calistirma ihtimali)...'
Start-Sec
$setup = @{}
foreach ($sf in @(Get-ChildItem -LiteralPath ($env:WINDIR + '\INF') -Filter 'setupapi.dev*.log' -File -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)) {
    $slines = @(Get-Content -LiteralPath $sf.FullName -ErrorAction SilentlyContinue)
    for ($i = 0; $i -lt ($slines.Count - 1); $i++) {
        if ($slines[$i] -match 'Device Install.*USBSTOR\\(.+?)\]\s*$') {
            $devId = $Matches[1].ToLower()
            if ($slines[$i + 1] -match 'Section start (\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})') {
                if (-not $setup.ContainsKey($devId)) { $setup[$devId] = $Matches[1] }
            }
        }
    }
}
foreach ($dev in @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR' -ErrorAction SilentlyContinue)) {
    foreach ($inst in @(Get-ChildItem $dev.PSPath -ErrorAction SilentlyContinue)) {
        $fn = [string]$inst.GetValue('FriendlyName')
        if (-not $fn) { $fn = $dev.PSChildName }
        $key = ($dev.PSChildName + '\' + $inst.PSChildName).ToLower()
        $first = $null
        if ($setup.ContainsKey($key)) { try { $first = [datetime]::ParseExact($setup[$key], 'yyyy/MM/dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) } catch {} }
        [void]$script:UsbList.Add([pscustomobject]@{ Ad = $fn; Ilk = $first; Son = (Get-KeyTime $inst) })
    }
}
Log ('   ' + $script:UsbList.Count + ' USB depolama cihazi kaydi bulundu.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[17/17] Windows Defender tespit gecmisi (silinmis/karantinaya alinmis dosyalar)...'
Start-Sec
$defCount = 0
try {
    Set-Frac 0 'defender kayitlari aliniyor'
    Log '   Defender kayitlari aliniyor (bu kisim sessiz bekletebilir, normal)...' 'DarkGray'
    $tdAll = @(Get-MpThreatDetection -ErrorAction Stop)
    Log ('   ' + $tdAll.Count + ' Defender kaydi var, inceleniyor...') 'DarkGray'
    $tdI = 0
    $tnCache = @{}
    foreach ($td in $tdAll) {
        $tdI++
        Set-Frac ($tdI / [Math]::Max(1, $tdAll.Count)) ('defender ' + $tdI + '/' + $tdAll.Count)
        if (($tdI % 25) -eq 0) { Log ('   ' + $tdI + '/' + $tdAll.Count + ' kayit (%' + [int]($tdI * 100 / [Math]::Max(1, $tdAll.Count)) + ')') 'DarkGray' }
        $tn = ''
        $tidk = [string]$td.ThreatID
        if ($tnCache.ContainsKey($tidk)) { $tn = $tnCache[$tidk] } else {
            try { $tn = (Get-MpThreat -ThreatID $td.ThreatID -ErrorAction Stop).ThreatName } catch {}
            $tnCache[$tidk] = $tn
        }
        foreach ($res in @($td.Resources)) {
            if ($res -notmatch '^file:_') { continue }
            $rp = $res -replace '^file:_', ''
            $leaf = ''
            try { $leaf = Split-Path -Leaf $rp } catch {}
            if (-not $leaf) { continue }
            $pi = Test-PathInfo $rp
            $dsc = 40
            if ($tn -match '(?i)hacktool|cheat|inject|gamehack|exploit|trojan|backdoor|pua|riskware') { $dsc = 55 }
            $dvar = 'Hayir'
            if ($pi.Exists) { $dvar = 'Evet' }
            Add-F -Kaynak 'Defender tespiti' -Ad $leaf.ToLower() -Yol $rp -Skor $dsc -Son $td.InitialDetectionTime -Ilk $td.InitialDetectionTime -Var $dvar -Not ('Defender tespit etti: ' + $tn)
            $defCount++
        }
    }
} catch {}
Log ('   ' + $defCount + ' Defender kaydi bulundu.') 'DarkGray'
Show-Section

# =====================================================================
# EK MODUL 3: Tarayici indirme gecmisi + kernel suruculeri
# =====================================================================
function Read-DbBytes([string]$p) {
    $r = $null
    try {
        $fs = [IO.File]::Open($p, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        try {
            if ($fs.Length -gt 134217728) { return $null }
            $r = New-Object byte[] ([int]$fs.Length)
            $off = 0
            while ($off -lt $r.Length) {
                $n = $fs.Read($r, $off, $r.Length - $off)
                if ($n -le 0) { break }
                $off += $n
            }
        } finally { $fs.Dispose() }
        return ,$r
    } catch {}
    # Tarayici aciksa dosya kilitli olabilir: golge kopya ile okumayi dene
    $r = $null
    $tmp = Join-Path $env:TEMP ('hk_db_' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        & esentutl.exe /y /vss $p /d $tmp 2>&1 | Out-Null
        if (Test-Path -LiteralPath $tmp) {
            if ((Get-Item -LiteralPath $tmp).Length -le 134217728) { $r = [IO.File]::ReadAllBytes($tmp) }
        }
    } catch {}
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    if ($null -eq $r) { return $null }
    return ,$r
}

Step '[17+/17] J) Tarayici gecmisi: indirilen dosyalar ve ziyaret edilen hile siteleri (Chrome, Edge, Brave, Opera, Firefox)...'
Start-Sec
$brDbs = New-Object System.Collections.Generic.List[object]
$brRoots = @(
    @('Chrome', ($env:LOCALAPPDATA + '\Google\Chrome\User Data')),
    @('Edge', ($env:LOCALAPPDATA + '\Microsoft\Edge\User Data')),
    @('Brave', ($env:LOCALAPPDATA + '\BraveSoftware\Brave-Browser\User Data')),
    @('Opera', ($env:APPDATA + '\Opera Software\Opera Stable')),
    @('Opera GX', ($env:APPDATA + '\Opera Software\Opera GX Stable'))
)
foreach ($br in $brRoots) {
    if (-not (Test-Path -LiteralPath $br[1])) { continue }
    foreach ($h in @(Get-ChildItem -LiteralPath $br[1] -Recurse -Depth 2 -File -Force -Filter 'History' -ErrorAction SilentlyContinue)) {
        [void]$brDbs.Add([pscustomobject]@{ Tarayici = $br[0]; File = $h })
    }
}
$ffRoot = $env:APPDATA + '\Mozilla\Firefox\Profiles'
if (Test-Path -LiteralPath $ffRoot) {
    foreach ($h in @(Get-ChildItem -LiteralPath $ffRoot -Recurse -Depth 1 -File -Force -Filter 'places.sqlite' -ErrorAction SilentlyContinue)) {
        [void]$brDbs.Add([pscustomobject]@{ Tarayici = 'Firefox'; File = $h })
    }
}
$brSeen = @{}
$brScanned = 0
foreach ($db in $brDbs) {
    $b = Read-DbBytes $db.File.FullName
    if ($null -eq $b -or $b.Length -lt 100) { continue }
    $brScanned++
    $txt = [Text.Encoding]::GetEncoding(28591).GetString($b)
    $kaynak = 'Tarayici gecmisi: ' + $db.Tarayici
    # 1) indirilen/acilan dosya yollari (hile ismi, silinmis dosya, olagan disi konum)
    foreach ($pm in (Find-Paths $txt 'exe|dll|jar|bat|ps1|scr|cmd|vbs|msi|zip|rar|7z')) {
        $lk = $pm.ToLower()
        if ($brSeen.ContainsKey($lk)) { continue }
        $brSeen[$lk] = 1
        $pi = Get-PiCached $pm
        Eval-Exec -Kaynak $kaynak -Path $pm -Exists $pi.Exists -Removed $pi.Removed -Note ('indirme/gecmis kaydi (' + $db.Tarayici + ' veritabani, kayit bazinda zaman bilgisi okunmuyor)')
    }
    # 2) ziyaret edilen/indirilen adreslerde hile ismi (tek basina kanit degil, yanlis alarm olabilir)
    $urlN = 0
    foreach ($um in [regex]::Matches($txt, '(?i)https?://[^\s\x00-\x1f"<>\x7f-\xff]{6,300}')) {
        $u = $um.Value
        $uh = Get-NameHit $u $false
        if (-not $uh) { continue }
        $uk = $u.ToLower()
        if ($brSeen.ContainsKey($uk)) { continue }
        $brSeen[$uk] = 1
        $urlN++
        if ($urlN -gt 60) { break }
        $hm = [regex]::Match($u, '(?i)^https?://([^/?#:]+)')
        $hostName = $u
        if ($hm.Success) { $hostName = $hm.Groups[1].Value.ToLower() }
        Add-F -Kaynak $kaynak -Ad ('adres: ' + $hostName) -Yol $u -Skor 35 -Son $db.File.LastWriteTime -Var 'Bilinmiyor' -Not ('tarayici gecmisinde hile ismi iceren adres: ' + $uh.Name + ' | ismin gecmesi tek basina kanit degil (ornek: meteor, inertia gibi yazilim siteleri); adrese ve tarihe bak')
    }
}
Log ('   ' + $brScanned + ' tarayici gecmis veritabani incelendi.') 'DarkGray'
Show-Section

# =====================================================================
Step '[17+/17] K) Kernel suruculeri, test signing, savunmasiz surucu engeli...'
Start-Sec
$vulnDrv = @('capcom.sys', 'iqvw64e.sys', 'iqvw32.sys', 'gdrv.sys', 'dbutil_2_3.sys', 'rtcore64.sys', 'rtcore32.sys', 'winio64.sys', 'winio32.sys', 'winring0x64.sys', 'winring0.sys', 'physmem.sys', 'atillk64.sys', 'amifldrv64.sys', 'asmmap64.sys', 'mhyprot2.sys', 'mhyprot3.sys', 'kprocesshacker.sys', 'speedfan.sys', 'ene.sys', 'glckio2.sys')
$drvCount = 0
foreach ($dv in @(Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue)) {
    $raw = [string]$dv.PathName
    if (-not $raw) { continue }
    $dp = $raw.Trim().Trim('"')
    $dp = $dp -replace '^\\\?\?\\', ''
    $dp = $dp -replace '(?i)^\\SystemRoot', $env:WINDIR
    if ($dp -match '(?i)^System32\\') { $dp = $env:WINDIR + '\' + $dp }
    if ($dp -notmatch '^[A-Za-z]:\\') { continue }
    $drvCount++
    $dleaf = ''
    try { $dleaf = Split-Path -Leaf $dp } catch {}
    if (-not $dleaf) { continue }
    $dzone = Get-Zone $dp
    $dexists = [bool](Test-Path -LiteralPath $dp)
    $sysPath = ($dp -match '(?i)^[A-Za-z]:\\Windows\\') -or ($dp -match '(?i)^[A-Za-z]:\\Program Files') -or ($dp -match '(?i)\\ProgramData\\Microsoft\\Windows Defender\\')
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    if ($vulnDrv -contains $dleaf.ToLower()) { $sc += 40; [void]$why.Add('bilinen savunmasiz/kotuye kullanilan surucu ismi (BYOVD). Mesru yazilimla da gelmis olabilir, hangi programa ait oldugunu kontrol et') }
    $dh = Get-NameHit $dleaf $false
    if ($dh) { $sc += 50; [void]$why.Add('isim eslesmesi: ' + $dh.Name) }
    if (-not $sysPath) {
        if ($dzone -eq 'user' -or $dzone -eq 'temp' -or $dzone -eq 'appdata' -or $dzone -eq 'shared') {
            $sc += 35; [void]$why.Add('surucu kullanici/temp/AppData/ortak klasorden yukleniyor')
            if ($dexists -and -not (Test-Signed $dp)) { $sc += 20; [void]$why.Add('imzasiz') }
        } elseif (-not $dexists) {
            $sc += 20; [void]$why.Add('surucu dosyasi diskte bulunamiyor')
        } elseif (-not (Test-Signed $dp)) {
            $sc += 20; [void]$why.Add('olagan disi klasorde imzasiz surucu')
        }
    }
    if ($sc -ge 30) {
        $dvar = 'Hayir'
        if ($dexists) { $dvar = 'Evet' }
        Add-F -Kaynak 'Kernel surucusu' -Ad $dleaf.ToLower() -Yol $dp -Skor ([Math]::Min(100, $sc)) -Var $dvar -Not (($why -join '; ') + ' | servis: ' + $dv.Name + ' | durum: ' + $dv.State + ' | baslatma: ' + $dv.StartMode)
    }
}
Log ('   ' + $drvCount + ' kernel surucusu incelendi.') 'DarkGray'

try {
    $bcd = (& bcdedit.exe /enum '{current}' 2>&1 | Out-String)
    if ($bcd -match '(?im)^\s*testsigning\s+(Yes|Evet)') {
        Add-Sys 'Windows TEST SIGNING modu ACIK' 60 'Imzasiz kernel suruculerinin yuklenmesine izin verir; kernel seviyesinde hile suruculeri icin kullanilir.'
    }
    if ($bcd -match '(?im)^\s*nointegritychecks\s+(Yes|Evet)') {
        Add-Sys 'Surucu imza dogrulamasi KAPALI (nointegritychecks)' 60 'Boot ayarlarinda kod butunlugu kontrolleri kapatilmis.'
    }
} catch {}
Check-RegFlag 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config' 'VulnerableDriverBlocklistEnable' 1 'Savunmasiz surucu engelleme listesi KAPALI' 'Microsoft''un bilinen savunmasiz suruculer listesi devre disi; BYOVD yontemiyle hile suruculeri yuklemeyi kolaylastirir (bazi oyuncular performans icin de kapatir).' 25
Check-RegFlag 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 1 'Bellek butunlugu (HVCI) KAPALI' 'Cekirdek yalitimi/bellek butunlugu kapali; tek basina supheli degil, diger bulgularla birlikte degerlendir.' 8
Show-Section

# =====================================================================
# EK MODUL 4: NirSoft mantigi, programsiz (SQLite, ShellBags, Uninstall, Defender, DLL, olaylar, jar icerigi, bellek)
# =====================================================================
function Ft-Webkit([string]$v) {
    $n = [long]0
    if ([long]::TryParse($v, [ref]$n) -and $n -gt 0) { try { return [datetime]::FromFileTimeUtc($n * 10).ToLocalTime() } catch {} }
    return $null
}
function Ft-Unix([string]$v) {
    $n = [long]0
    if ([long]::TryParse($v, [ref]$n) -and $n -gt 0) { try { return ([DateTimeOffset]::FromUnixTimeMilliseconds([long]($n / 1000))).LocalDateTime } catch {} }
    return $null
}
function Copy-DbTemp([string]$src) {
    $b = Read-DbBytes $src
    if ($null -eq $b -or $b.Length -lt 100) { return $null }
    $tmp = Join-Path $env:TEMP ('hk_q_' + [guid]::NewGuid().ToString('N') + '.db')
    [IO.File]::WriteAllBytes($tmp, $b)
    if (Test-Path -LiteralPath ($src + '-wal')) {
        $w = Read-DbBytes ($src + '-wal')
        if ($null -ne $w -and $w.Length -gt 0) { [IO.File]::WriteAllBytes(($tmp + '-wal'), $w) }
    }
    return $tmp
}
function Remove-DbTemp([string]$t) {
    foreach ($x in @($t, ($t + '-wal'), ($t + '-shm'), ($t + '-journal'))) { Remove-Item -LiteralPath $x -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------
Step '[17+/17] M) BrowserDownloadsView + BrowsingHistoryView mantigi (winsqlite3 ile): ne, nereden, ne zaman indirildi...'
Start-Sec
$sqlCs = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class HkSql {
    const string D = "winsqlite3.dll";
    [DllImport(D, CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_open_v2(byte[] f, out IntPtr db, int flags, IntPtr vfs);
    [DllImport(D, CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_close(IntPtr db);
    [DllImport(D, CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int n, out IntPtr st, IntPtr tail);
    [DllImport(D, CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_step(IntPtr st);
    [DllImport(D, CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_finalize(IntPtr st);
    [DllImport(D, CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_column_count(IntPtr st);
    [DllImport(D, CallingConvention = CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_text(IntPtr st, int i);
    [DllImport(D, CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_column_bytes(IntPtr st, int i);
    public static List<string[]> Query(string path, string sql, int max) {
        List<string[]> rows = new List<string[]>();
        IntPtr db;
        byte[] fb = Encoding.UTF8.GetBytes(path + "\0");
        if (sqlite3_open_v2(fb, out db, 2, IntPtr.Zero) != 0) { if (db != IntPtr.Zero) sqlite3_close(db); return null; }
        IntPtr st;
        byte[] sb = Encoding.UTF8.GetBytes(sql + "\0");
        if (sqlite3_prepare_v2(db, sb, -1, out st, IntPtr.Zero) != 0) { sqlite3_close(db); return null; }
        int cc = sqlite3_column_count(st);
        while (rows.Count < max && sqlite3_step(st) == 100) {
            string[] r = new string[cc];
            for (int i = 0; i < cc; i++) {
                IntPtr p = sqlite3_column_text(st, i);
                if (p == IntPtr.Zero) { r[i] = ""; continue; }
                int n = sqlite3_column_bytes(st, i);
                byte[] b = new byte[n];
                Marshal.Copy(p, b, 0, n);
                r[i] = Encoding.UTF8.GetString(b);
            }
            rows.Add(r);
        }
        sqlite3_finalize(st);
        sqlite3_close(db);
        return rows;
    }
}
'@
$script:SqlOk = $false
try { Add-Type -TypeDefinition $sqlCs -Language CSharp -ErrorAction Stop; $script:SqlOk = $true } catch {}
$dlHostRx = '(?i)cdn\.discordapp\.com/attachments|media\.discordapp\.net/attachments|mega\.nz|mediafire\.com|gofile\.io|pixeldrain\.com|anonfiles|transfer\.sh|workupload\.com|file\.io|catbox\.moe|dropbox\.com|drive\.google\.com|sendspace\.com|1fichier\.com'
$qSeenDl = @{}
$dlTotal = 0
$histTotal = 0
if (-not $script:SqlOk) {
    Log '   winsqlite3.dll kullanilamadi; yukaridaki J modulundeki metin taramasi gecerli.' 'DarkYellow'
} else {
    foreach ($db in $brDbs) {
        $tmp = $null
        try { $tmp = Copy-DbTemp $db.File.FullName } catch {}
        if (-not $tmp) { continue }
        $isFf = ($db.Tarayici -eq 'Firefox')
        $kaynak = 'Tarayici indirmesi: ' + $db.Tarayici
        try {
            if (-not $isFf) {
                $q1 = 'SELECT d.target_path, (SELECT c.url FROM downloads_url_chains c WHERE c.id = d.id ORDER BY c.chain_index DESC LIMIT 1), d.tab_url, d.start_time, d.total_bytes FROM downloads d ORDER BY d.start_time DESC'
                $rows = $null
                try { $rows = [HkSql]::Query($tmp, $q1, 20000) } catch {}
                if ($null -ne $rows) {
                    foreach ($r in $rows) {
                        $tp = [string]$r[0]
                        if (-not $tp) { continue }
                        $durl = [string]$r[1]
                        $tab = [string]$r[2]
                        $tm = Ft-Webkit ([string]$r[3])
                        $dk = $tp.ToLower() + '|' + [string]$r[3]
                        if ($qSeenDl.ContainsKey($dk)) { continue }
                        $qSeenDl[$dk] = 1
                        $dlTotal++
                        $leafD = ''
                        $extD = ''
                        try { $leafD = Split-Path -Leaf $tp; $extD = [IO.Path]::GetExtension($leafD).ToLower() } catch {}
                        $srcN = 'indirildigi adres: ' + $durl
                        if ($tab) { $srcN = $srcN + ' | sayfa: ' + $tab }
                        if ($tp -match '^[A-Za-z]:\\') {
                            $pi = Get-PiCached $tp
                            Eval-Exec -Kaynak $kaynak -Path $tp -Exists $pi.Exists -Removed $pi.Removed -Last $tm -First $tm -Note $srcN
                            if (($IntExt -contains $extD) -and (($durl + ' ' + $tab) -match $dlHostRx)) {
                                $sc2 = 30
                                $pvar = 'Evet'
                                if (-not $pi.Exists) { $sc2 = 45; $pvar = 'Hayir' }
                                Add-F -Kaynak ($kaynak + ' (paylasim sitesi)') -Ad $leafD.ToLower() -Yol $tp -Skor $sc2 -Son $tm -Ilk $tm -Var $pvar -Not ('dosya paylasim/sohbet sitesinden indirilmis kod/arsiv dosyasi (hile dagitiminda sik kullanilir ama mesru dosyalar da olabilir) | ' + $srcN)
                            }
                        }
                        $hu = Get-NameHit ($durl + ' ' + $tab + ' ' + $leafD) $false
                        if ($hu) {
                            Add-F -Kaynak ($kaynak + ' (hile ismi)') -Ad $leafD.ToLower() -Yol $tp -Skor 55 -Son $tm -Ilk $tm -Var 'Bilinmiyor' -Not ('indirme adresinde/dosya adinda hile ismi: ' + $hu.Name + ' | ' + $srcN)
                        }
                    }
                }
                $q2 = 'SELECT url, title, visit_count, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 30000'
                $rows2 = $null
                try { $rows2 = [HkSql]::Query($tmp, $q2, 30000) } catch {}
                $tmFn = 'W'
            } else {
                $q2 = 'SELECT url, title, visit_count, last_visit_date FROM moz_places WHERE last_visit_date IS NOT NULL ORDER BY last_visit_date DESC LIMIT 30000'
                $rows2 = $null
                try { $rows2 = [HkSql]::Query($tmp, $q2, 30000) } catch {}
                $tmFn = 'U'
            }
            if ($null -ne $rows2) {
                $hN = 0
                foreach ($r in $rows2) {
                    $u = [string]$r[0]
                    $ti = [string]$r[1]
                    $hh = Get-NameHit ($u + ' ' + $ti) $false
                    if (-not $hh) { continue }
                    $hN++
                    if ($hN -gt 80) { break }
                    $histTotal++
                    if ($tmFn -eq 'W') { $tm = Ft-Webkit ([string]$r[3]) } else { $tm = Ft-Unix ([string]$r[3]) }
                    $hm2 = [regex]::Match($u, '(?i)^https?://([^/?#:]+)')
                    $hostN = $u
                    if ($hm2.Success) { $hostN = $hm2.Groups[1].Value.ToLower() }
                    Add-F -Kaynak ('Tarayici gecmisi (SQL): ' + $db.Tarayici) -Ad ('adres: ' + $hostN) -Yol $u -Skor 35 -Son $tm -Var 'Bilinmiyor' -Not ('ziyaret sayisi: ' + $r[2] + ' | baslik: ' + $ti + ' | hile ismi: ' + $hh.Name + ' (ismin gecmesi tek basina kanit degil)')
                }
            }
        } catch {}
        Remove-DbTemp $tmp
    }
    Log ('   ' + $dlTotal + ' tarayici indirme kaydi, ' + $histTotal + ' supheli gecmis kaydi incelendi.') 'DarkGray'
}
Show-Section

# ---------------------------------------------------------------------
Step '[17+/17] N) ShellBags: gezilen klasorler (silinmis olsa bile) - ShellBagsView mantigi...'
Start-Sec
function Get-ShellName([byte[]]$b) {
    if ($null -eq $b -or $b.Length -lt 8) { return $null }
    if (($b[2] -band 0x70) -eq 0x20) {
        $dv = [Text.Encoding]::ASCII.GetString($b, 3, 3)
        if ($dv -match '^[A-Za-z]:\\') { return $dv.Substring(0, 2).ToUpper() }
        return $null
    }
    if (($b[2] -band 0x70) -ne 0x30) { return $null }
    $best = ''
    foreach ($off in @(0, 1)) {
        $len = $b.Length - $off
        $len = $len - ($len % 2)
        if ($len -lt 6) { continue }
        $txt = [Text.Encoding]::Unicode.GetString($b, $off, $len)
        foreach ($m in [regex]::Matches($txt, '[A-Za-z0-9 \.\-_\(\)\+&,!@#\u00C0-\u017F]{3,120}')) {
            $v = $m.Value.Trim()
            if ($v.Length -gt $best.Length -and $v -match '[A-Za-z]' -and $v -notmatch '^[0-9A-Fa-f\-]{20,}$') { $best = $v }
        }
    }
    if ($best) { return $best }
    $a = [Text.Encoding]::GetEncoding(28591).GetString($b, 4, $b.Length - 4)
    $am = [regex]::Match($a, '[A-Za-z0-9_\.\-~]{3,}')
    if ($am.Success) { return $am.Value }
    return $null
}
$script:SbSeen = @{}
$script:SbCount = 0
function Eval-Bag([string]$full, $kt) {
    if ($full -notmatch '^[A-Za-z]:\\.+') { return }
    $lk = $full.ToLower()
    if ($script:SbSeen.ContainsKey($lk)) { return }
    $script:SbSeen[$lk] = 1
    $script:SbCount++
    $leaf = ''
    try { $leaf = Split-Path -Leaf $full } catch {}
    if (-not $leaf) { return }
    $pi = Get-PiCached $full
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    $h = Get-NameHit $leaf $false
    if ($h) { $sc += 45; [void]$why.Add('klasor adinda hile ismi: ' + $h.Name) }
    if (-not $pi.Exists -and ((Test-MixedRandom $leaf) -or (Test-Gibberish $leaf))) { $sc += 30; [void]$why.Add('rastgele isimli klasor, su an SILINMIS') }
    if ($h -and -not $pi.Exists) { $sc += 15; [void]$why.Add('klasor su an yok (silinmis/tasinmis/cikarilmis surucu)') }
    if ($sc -ge 30) {
        $var = 'Evet'
        if (-not $pi.Exists) { $var = 'Hayir' }
        Add-F -Kaynak 'ShellBags (gezilen klasor)' -Ad ('klasor: ' + $leaf.ToLower()) -Yol $full -Skor ([Math]::Min(100, $sc)) -Son $kt -Var $var -Not (($why -join '; ') + ' | Zaman = klasorun en son acildigi/gezildigi zamana yakin kayit defteri degisimi')
    }
}
function Walk-BagMRU($key, [string]$parent, [int]$depth) {
    if ($depth -gt 14) { return }
    foreach ($vn in $key.GetValueNames()) {
        if ($vn -notmatch '^\d+$') { continue }
        $vb = $key.GetValue($vn)
        if ($vb -isnot [byte[]]) { continue }
        $nm = Get-ShellName $vb
        $full = $parent
        if ($nm) {
            if ($parent) { $full = $parent.TrimEnd('\') + '\' + $nm } else { $full = $nm }
        }
        $sub = $null
        try { $sub = $key.OpenSubKey($vn) } catch {}
        if ($sub) {
            if ($nm) { Eval-Bag $full (Get-KeyTime $sub) }
            Walk-BagMRU $sub $full ($depth + 1)
            $sub.Close()
        }
    }
}
foreach ($bk in @('HKCU:\Software\Microsoft\Windows\Shell\BagMRU', 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU')) {
    try {
        $root = Get-Item -LiteralPath $bk -ErrorAction Stop
        Walk-BagMRU $root '' 0
    } catch {}
}
Log ('   ' + $script:SbCount + ' ShellBag klasor kaydi cozuldu (isim cikarma sezgiseldir).') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[17+/17] O) Yuklu programlar listesi (UninstallView mantigi)...'
Start-Sec
$unToolRx = '(?i)cheat ?engine|process ?hacker|system ?informer|x64dbg|x32dbg|ollydbg|dnspy|extreme ?injector|autohotkey|auto ?clicker|tinytask|jitbit|op ?auto ?clicker'
$unCount = 0
foreach ($ur in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')) {
    foreach ($k in @(Get-ChildItem -LiteralPath $ur -ErrorAction SilentlyContinue)) {
        $dn = [string]$k.GetValue('DisplayName')
        if (-not $dn) { $k.Close(); continue }
        $pub = [string]$k.GetValue('Publisher')
        $loc = [string]$k.GetValue('InstallLocation')
        $uns = [string]$k.GetValue('UninstallString')
        $ids = [string]$k.GetValue('InstallDate')
        $kt = Get-KeyTime $k
        $k.Close()
        $unCount++
        $txt = $dn + ' ' + $pub + ' ' + $loc + ' ' + $uns
        $h = Get-NameHit $txt $false
        $tool = [regex]::Match($dn, $unToolRx)
        if (-not $h -and -not $tool.Success) { continue }
        $idt = $null
        if ($ids -match '^\d{8}$') { try { $idt = [datetime]::ParseExact($ids, 'yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture) } catch {} }
        $sc = 0
        $nt = ''
        if ($h) { $sc += 45; $nt = 'program adinda/yolunda hile ismi: ' + $h.Name }
        if ($tool.Success) { $sc += 30; $nt = $nt + ' | hile/enjeksiyon/makro araci: ' + $tool.Value }
        $var = 'Evet'
        if ($loc -match '^[A-Za-z]:\\' -and -not (Test-Path -LiteralPath $loc)) { $sc += 10; $var = 'Hayir'; $nt = $nt + ' | kurulum klasoru artik yok' }
        Add-F -Kaynak 'Yuklu programlar (Uninstall)' -Ad ('program: ' + $dn.ToLower()) -Yol ($loc + ' ' + $uns) -Skor ([Math]::Min(100, $sc)) -Son $kt -Ilk $idt -Var $var -Not ($nt + ' | yayinci: ' + $pub + ' | Son: kayit defteri degisimi, Ilk: kurulum tarihi')
    }
}
Log ('   ' + $unCount + ' yuklu program kaydi incelendi.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[17+/17] P) Windows Defender olay gunlugu ve MPLog (WinDefLogView mantigi)...'
Start-Sec
$defEv = @()
try { $defEv = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Windows Defender/Operational'; Id = 1116, 1117, 1118, 1119, 5001, 5007, 5010, 5012, 5013 } -MaxEvents 800 -ErrorAction Stop) } catch {}
$defSeen = @{}
$defSysN = @{}
foreach ($e in $defEv) {
    $msg = [string]$e.Message
    if ($e.Id -ge 1116 -and $e.Id -le 1119) {
        $tn = ''
        $nmM = [regex]::Match($msg, '(?im)^\s*(?:Name|Ad|Adi|Ad\u0131)\s*:\s*(.+?)\s*$')
        if ($nmM.Success) { $tn = $nmM.Groups[1].Value }
        foreach ($pm in [regex]::Matches($msg, 'file:_([A-Za-z]:\\[^\r\n;]+)')) {
            $dp = $pm.Groups[1].Value.Trim()
            $dk = $dp.ToLower() + '|' + $e.Id
            if ($defSeen.ContainsKey($dk)) { continue }
            $defSeen[$dk] = 1
            $leaf = ''
            $bn = ''
            try { $leaf = Split-Path -Leaf $dp; $bn = [IO.Path]::GetFileNameWithoutExtension($leaf) } catch {}
            if (-not $leaf) { continue }
            $pi = Get-PiCached $dp
            $sc = 45
            $why = 'Defender olayi ' + $e.Id + ' (' + $tn + ')'
            if ((Test-MixedRandom $bn) -or (Test-Gibberish $bn)) { $sc += 15; $why = $why + ' | rastgele dosya adi' }
            $hh = Get-NameHit $leaf $true
            if ($hh) { $sc += 10; $why = $why + ' | isim eslesmesi: ' + $hh.Name }
            if ($tn -match '(?i)hacktool|cheat|inject|gamehack|trojan|exploit|pua|riskware|behavior') { $sc += 10 }
            $dvar = 'Hayir'
            if ($pi.Exists) { $dvar = 'Evet' }
            Add-F -Kaynak 'Defender olay gunlugu' -Ad $leaf.ToLower() -Yol $dp -Skor ([Math]::Min(100, $sc)) -Son $e.TimeCreated -Ilk $e.TimeCreated -Var $dvar -Not $why
        }
    } elseif ($e.Id -eq 5007) {
        foreach ($xm in [regex]::Matches($msg, '(?i)Exclusions\\(Paths|Processes|Extensions|IpAddresses)\\([^\r\n=]+?)\s*=')) {
            $xk = 'x|' + $xm.Groups[2].Value.ToLower()
            if ($defSeen.ContainsKey($xk)) { continue }
            $defSeen[$xk] = 1
            Add-Sys ('Defender dislama degisikligi (olay 5007): ' + $xm.Groups[2].Value) 40 'Defender ayar degisikligi olay gunlugunde; bu yol/uzanti/process icin dislama eklenmis ya da degistirilmis olabilir.' $e.TimeCreated $xm.Groups[1].Value $e.TimeCreated
        }
        if ($msg -match '(?i)DisableRealtimeMonitoring|DisableAntiSpyware|DisableBehaviorMonitoring|DisableIOAVProtection|DisableScriptScanning') {
            if (-not $defSysN.ContainsKey('5007k')) { $defSysN['5007k'] = 1; Add-Sys 'Defender koruma ayari degistirilmis (olay 5007)' 35 'Gercek zamanli/davranis/script tarama ayarlarindan biri degistirilmis.' $e.TimeCreated }
        }
    } else {
        $ik = [string]$e.Id
        if (-not $defSysN.ContainsKey($ik)) {
            $defSysN[$ik] = 1
            $sk = 40
            $bs = 'Defender olay ' + $e.Id
            if ($e.Id -eq 5001) { $sk = 50; $bs = 'Defender aninda koruma KAPATILMIS (olay 5001)' }
            if ($e.Id -eq 5013) { $sk = 35; $bs = 'Defender kurcalamaya karsi koruma bir degisikligi engellemis (olay 5013)' }
            Add-Sys $bs $sk 'Defender koruma durumu degistirilmis; zamanina ve diger bypass olaylarina bak.' $e.TimeCreated
        }
    }
}
Log ('   ' + $defEv.Count + ' Defender olayi incelendi.') 'DarkGray'

$mpDir = $env:ProgramData + '\Microsoft\Windows Defender\Support'
$mpFiles = @()
if (-not (Test-Path -LiteralPath $mpDir)) { Log ('   Defender Support klasoru yok/erisilemiyor: ' + $mpDir + ' (Defender kapali veya baska antivirus olabilir; yonetici degilse de okunamaz)') 'DarkYellow' }
if (Test-Path -LiteralPath $mpDir) { $mpFiles = @(Get-ChildItem -LiteralPath $mpDir -Filter 'MPLog-*.log' -File -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 4) }
$mpPat = '(?i)(?:\\Device\\HarddiskVolume\d+|[A-Za-z]:)\\[^\r\n"<>|*?]{3,260}?\.(?:exe|dll|jar|bat|ps1|scr|cmd|vbs|msi)(?![A-Za-z0-9])'
$mpRx = New-Object System.Text.RegularExpressions.Regex($mpPat, [System.Text.RegularExpressions.RegexOptions]::Compiled, [TimeSpan]::FromSeconds(2))
$mpSeen = @{}
$mpN = 0
foreach ($mf in $mpFiles) {
    if ($mf.Length -gt 157286400) { continue }
    $mt = Read-LogText $mf.FullName
    if (-not $mt) { continue }
    foreach ($ln in $mt.Split("`n")) {
        if ($ln.Length -lt 10) { continue }
        $mm = $null
        try { $mm = $mpRx.Match($ln) } catch { continue }
        if (-not $mm.Success) { continue }
        $pth = $mm.Value
        $pk = $pth.ToLower()
        if ($mpSeen.ContainsKey($pk)) { continue }
        $mpSeen[$pk] = 1
        $mpN++
        if ($mpN -gt 6000) { break }
        $rr = Resolve-NtPath $pth
        $tt = $null
        $tmM = [regex]::Match($ln, '^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})')
        if ($tmM.Success) { try { $tt = [datetime]::ParseExact(($tmM.Groups[1].Value + ' ' + $tmM.Groups[2].Value), 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture).ToLocalTime() } catch {} }
        Eval-Exec -Kaynak 'Defender MPLog (taranan dosya)' -Path $rr.Path -Exists $rr.Exists -Removed $rr.Removed -Last $tt -Note ('MPLog: Defender bu dosyayi taramis/gormus (dosya silinse de iz kalir) | ' + $mf.Name)
    }
}
Log ('   ' + $mpFiles.Count + ' MPLog dosyasindan ' + $mpN + ' farkli dosya yolu incelendi.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[17+/17] Q) Yuklu DLL analizi: tum process ler (LoadedDllsView mantigi)...'
Start-Sec
$ldAll = @{}
foreach ($gp in @(Get-Process -ErrorAction SilentlyContinue)) {
    if ($gp.Id -le 4 -or $gp.Id -eq $PID) { continue }
    $mods = $null
    try { $mods = @($gp.Modules) } catch { continue }
    foreach ($m in $mods) {
        $mp = [string]$m.FileName
        if ($mp -notmatch '^[A-Za-z]:\\') { continue }
        if ($mp -match '(?i)^[A-Za-z]:\\(Windows|Program Files|Program Files \(x86\))\\') { continue }
        $mk = $mp.ToLower()
        if (-not $ldAll.ContainsKey($mk)) { $ldAll[$mk] = @{ Path = $mp; Procs = (New-Object System.Collections.Generic.List[string]) } }
        if ($ldAll[$mk].Procs.Count -lt 8 -and -not $ldAll[$mk].Procs.Contains($gp.ProcessName)) { [void]$ldAll[$mk].Procs.Add($gp.ProcessName) }
    }
}
$ldN = 0
foreach ($kv in $ldAll.GetEnumerator()) {
    $ldN++
    if ($ldN -gt 1500) { break }
    $mp = $kv.Value.Path
    $mn = ''
    try { $mn = (Split-Path -Leaf $mp).ToLower() } catch {}
    if (-not $mn) { continue }
    if ($mn -match $knownNat) { continue }
    if ($mp -match '(?i)\\(\.minecraft|\.lunarclient|ModrinthApp|PrismLauncher|\.tlauncher|\.feather|\.ichor)\\|\\(runtime|jre|jdk)[^\\]*\\') { continue }
    $procs = ($kv.Value.Procs -join ', ')
    $isJ = ($procs -match '(?i)javaw?')
    $fi = $null
    try { $fi = Get-Item -LiteralPath $mp -Force -ErrorAction Stop } catch {}
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    $bn = [IO.Path]::GetFileNameWithoutExtension($mn)
    if (-not $fi) {
        $sc += 50; [void]$why.Add('DLL diskte YOK ama bellekte yuklu (dosya silinmis)')
    } else {
        $comp = [string]$fi.VersionInfo.CompanyName
        $prod = [string]$fi.VersionInfo.ProductName
        $sig = Test-Signed $mp
        if (-not $sig) {
            if (-not $comp -and -not $prod) { $sc += 35; [void]$why.Add('imzasiz + sirket/urun adi YOK') } else { $sc += 10; [void]$why.Add('imzasiz (sirket: ' + $comp + ')') }
        }
        $zn = Get-Zone $mp
        if ($sc -gt 0 -and ($zn -eq 'user' -or $zn -eq 'temp' -or $zn -eq 'appdata' -or $zn -eq 'shared')) { $sc += 10; [void]$why.Add($zn + ' klasorunde') }
    }
    $hit = Get-NameHit $mn $false
    if ($hit) { $sc += 50; [void]$why.Add('isim eslesmesi: ' + $hit.Name) }
    if ($sc -gt 0 -and ((Test-MixedRandom $bn) -or (Test-Gibberish $bn))) { $sc += 20; [void]$why.Add('rastgele dll adi') }
    if ($sc -gt 0 -and $isJ) { $sc += 15; [void]$why.Add('Java process ine yuklenmis') }
    if ($sc -ge 40) {
        $son = $null
        $ilk = $null
        $var = 'Hayir'
        if ($fi) { $son = $fi.LastWriteTime; $ilk = $fi.CreationTime; $var = 'Evet' }
        Add-F -Kaynak 'Yuklu DLL (tum process ler)' -Ad $mn -Yol $mp -Skor ([Math]::Min(100, $sc)) -Son $son -Ilk $ilk -Var $var -Not (($why -join '; ') + ' | yukleyen process ler: ' + $procs)
    }
}
Log ('   ' + $ldAll.Count + ' farkli sistem disi DLL incelendi.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[17+/17] R) Olay gunlukleri: servis/surucu kurulumu (7045), process baslatma (4688), uygulama cokmeleri (1000) - LastActivityView mantigi...'
Start-Sec
$r7 = 0
$r88 = 0
$r10 = 0
try {
    foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 7045 } -MaxEvents 300 -ErrorAction Stop)) {
        $sn = ''
        $ip = ''
        try { $sn = [string]$e.Properties[0].Value; $ip = [string]$e.Properties[1].Value } catch {}
        if (-not $ip) { continue }
        if ($sn -match '(?i)^mbam') { continue }
        $ipx = [Environment]::ExpandEnvironmentVariables($ip).Trim()
        $ipx = $ipx -replace '^\\\?\?\\', ''
        $ipx = $ipx -replace '(?i)^\\SystemRoot', $env:WINDIR
        $cand = $null
        if ($ipx -match '(?i)^\s*"([^"]+)"') { $cand = $Matches[1] } elseif ($ipx -match '(?i)^\s*([A-Za-z]:\\.*?\.(?:exe|sys|dll|bat|cmd|ps1|vbs|jar))') { $cand = $Matches[1] }
        if (-not $cand -or $cand -notmatch '^[A-Za-z]:\\') { continue }
        $r7++
        $pi = Get-PiCached $cand
        if ($cand -match '(?i)\.sys$') {
            $sc = 0
            $why = New-Object System.Collections.Generic.List[string]
            $z = Get-Zone $cand
            if ($z -ne 'system') { $sc += 25; [void]$why.Add('surucu sistem klasoru disindan kurulmus') }
            if (-not $pi.Exists) { $sc += 20; [void]$why.Add('surucu dosyasi artik yok') }
            $hs = Get-NameHit (Split-Path -Leaf $cand) $false
            if ($hs) { $sc += 50; [void]$why.Add('isim eslesmesi: ' + $hs.Name) }
            if ($sc -ge 30) {
                $v = 'Hayir'
                if ($pi.Exists) { $v = 'Evet' }
                Add-F -Kaynak 'Servis/surucu kurulumu (olay 7045)' -Ad ((Split-Path -Leaf $cand).ToLower()) -Yol $cand -Skor $sc -Son $e.TimeCreated -Ilk $e.TimeCreated -Var $v -Not (($why -join '; ') + ' | servis adi: ' + $sn)
            }
        } else {
            Eval-Exec -Kaynak 'Servis kurulumu (olay 7045)' -Path $cand -Exists $pi.Exists -Removed $pi.Removed -Last $e.TimeCreated -First $e.TimeCreated -Note ('yeni servis kuruldu: ' + $sn)
        }
    }
} catch {}
try {
    $seen88 = @{}
    foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4688 } -MaxEvents 3000 -ErrorAction Stop)) {
        $np = ''
        try { $np = [string]$e.Properties[5].Value } catch {}
        if ($np -notmatch '^[A-Za-z]:\\') { continue }
        $nk = $np.ToLower()
        if ($seen88.ContainsKey($nk)) { continue }
        $seen88[$nk] = 1
        $r88++
        $pi = Get-PiCached $np
        Eval-Exec -Kaynak 'Process baslatma kaydi (olay 4688)' -Path $np -Exists $pi.Exists -Removed $pi.Removed -Last $e.TimeCreated -Note 'Guvenlik gunlugu process olusturma kaydi'
    }
} catch {}
try {
    $seen10 = @{}
    foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000 } -MaxEvents 300 -ErrorAction Stop)) {
        $ap = ''
        $mp2 = ''
        try { $ap = [string]$e.Properties[10].Value; $mp2 = [string]$e.Properties[11].Value } catch {}
        foreach ($c in @($ap, $mp2)) {
            if ($c -notmatch '^[A-Za-z]:\\') { continue }
            $ck = $c.ToLower()
            if ($seen10.ContainsKey($ck)) { continue }
            $seen10[$ck] = 1
            $r10++
            $pi = Get-PiCached $c
            Eval-Exec -Kaynak 'Uygulama hata kaydi (olay 1000)' -Path $c -Exists $pi.Exists -Removed $pi.Removed -Last $e.TimeCreated -Note 'bu program/modul bir uygulamayi cokertmis olabilir (yuklenmis kayit)'
        }
    }
} catch {}
Log ('   7045: ' + $r7 + ', 4688: ' + $r88 + ', 1000: ' + $r10 + ' kayit incelendi (4688 icin Windows denetimi acik olmali).') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[17+/17] S) Jar/zip ICERIK taramasi: class stringleri, ic ice jar, istemci markalari, paket yollari, obfuscation (isimsiz hileler icin)...'
Start-Sec
function Scan-Zip($zip, $r, [int]$depth) {
    foreach ($e in $zip.Entries) {
        if ($script:ZipSw -and $script:ZipSw.Elapsed.TotalSeconds -gt 45) { $r.TimedOut = $true; break }
        $n = $e.FullName
        if ($n -match '(?i)^(plugin\.yml|bungee\.yml|paper-plugin\.yml|velocity-plugin\.json)$') { $r.Plugin = $true }
        if (-not $r.Pkg -and $n -match $script:PkgRx) { $r.Pkg = $Matches[1] }
        if ($n.EndsWith('.class')) {
            $r.Classes++
            $cb = ''
            try { $cb = [IO.Path]::GetFileNameWithoutExtension($n) } catch {}
            if ($cb.Length -le 2) { $r.Short++ }
            if ($r.Scanned -lt 2500 -and $e.Length -gt 0 -and $e.Length -lt 1048576) {
                $r.Scanned++
                $st = $e.Open()
                $ms = New-Object IO.MemoryStream
                $st.CopyTo($ms)
                $st.Dispose()
                $t = [Text.Encoding]::GetEncoding(28591).GetString($ms.ToArray())
                $ms.Dispose()
                Get-Terms $t $r.Terms
                Get-Brands $t $r.Brands
            }
        } elseif ($n -match '(?i)^(fabric\.mod\.json|quilt\.mod\.json|mcmod\.info|META-INF/mods\.toml|META-INF/neoforge\.mods\.toml)$' -and $e.Length -lt 65536) {
            $sr = New-Object IO.StreamReader($e.Open())
            $r.Meta = $r.Meta + ' ' + $sr.ReadToEnd()
            $sr.Dispose()
        } elseif ($depth -lt 2 -and $n -match '(?i)\.jar$' -and $e.Length -gt 0 -and $e.Length -lt 31457280 -and $r.Nested -lt 25) {
            $r.Nested++
            try {
                $st = $e.Open()
                $ms = New-Object IO.MemoryStream
                $st.CopyTo($ms)
                $st.Dispose()
                $ms.Position = 0
                $inner = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Read)
                try { Scan-Zip $inner $r ($depth + 1) } finally { $inner.Dispose(); $ms.Dispose() }
            } catch {}
        } elseif ($n -match '(?i)\.(json|txt|cfg|toml|properties|yml|yaml)$' -and $e.Length -gt 20 -and $e.Length -lt 262144 -and $r.TextScanned -lt 150) {
            $r.TextScanned++
            try {
                $sr2 = New-Object IO.StreamReader($e.Open())
                $tx = $sr2.ReadToEnd()
                $sr2.Dispose()
                Get-Terms $tx $r.Terms
                Get-Brands $tx $r.Brands
            } catch {}
        }
    }
}
function Deep-Jar([string]$p) {
    $script:ZipSw = [Diagnostics.Stopwatch]::StartNew()
    $r = @{ Terms = @{}; Brands = @{}; Meta = ''; Plugin = $false; Pkg = ''; Classes = 0; Short = 0; Scanned = 0; Nested = 0; TextScanned = 0; Obf = $false; TimedOut = $false }
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($p)
        try { Scan-Zip $zip $r 0 } finally { $zip.Dispose() }
    } catch {}
    if ($r.Classes -ge 20 -and ($r.Short / [double]$r.Classes) -ge 0.6) { $r.Obf = $true }
    return $r
}
$jarCsOk = $false
try { Add-Type -TypeDefinition $jarCs -Language CSharp -ReferencedAssemblies @('System.IO.Compression', 'System.IO.Compression.FileSystem') -ErrorAction Stop; $jarCsOk = $true } catch {}
$jarResults = @{}
if ($jarCsOk) {
    try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch {}
    $stPath = Join-Path $env:TEMP ('hk_selftest_' + [guid]::NewGuid().ToString('N') + '.jar')
    $stN = -1
    try {
        $zf = [IO.Compression.ZipFile]::Open($stPath, [IO.Compression.ZipArchiveMode]::Create)
        $ze = $zf.CreateEntry('net/testclient/module/TestModule.class')
        $zs = $ze.Open()
        $zb = [Text.Encoding]::GetEncoding(28591).GetBytes('xxxx KillAura ClickGUI AutoCrystal ShieldBreaker xxxx')
        $zs.Write($zb, 0, $zb.Length)
        $zs.Dispose()
        $zf.Dispose()
        $stRes = [HkJar]::Scan($stPath, $script:ModTermPat, $script:BrandRx.ToString(), $script:PkgRx, 10)
        $stN = $stRes.Terms.Count
    } catch {}
    Remove-Item -LiteralPath $stPath -Force -ErrorAction SilentlyContinue
    if ($stN -ge 3) { Write-Host ('   [oz-test] jar tarayici calisiyor (' + $stN + ' modul ismi bulundu).') -ForegroundColor Green }
    else { Write-Host ('   [oz-test] BASARISIZ: jar tarayici kendi test jar indeki modul isimlerini bulamadi (bulunan: ' + $stN + '). Bu bir tarayici hatasidir, bana bildir.') -ForegroundColor Red }
    # Masaustu/Indirilenler/Belgeler/script klasoru: dosya gezme adimina bagli kalmadan dogrudan listele
    $jarExtra = New-Object System.Collections.Generic.List[object]
    if ($script:WalkOk) {
        $xr = New-Object System.Collections.Generic.List[string]
        try { [void]$xr.Add((Get-DownloadsPath)) } catch {}
        [void]$xr.Add([Environment]::GetFolderPath('Desktop'))
        [void]$xr.Add([Environment]::GetFolderPath('MyDocuments'))
        if ($PSScriptRoot) { [void]$xr.Add($PSScriptRoot) }
        $xrSeen = @{}
        foreach ($xroot in $xr) {
            if (-not $xroot -or $xrSeen.ContainsKey($xroot.ToLower())) { continue }
            $xrSeen[$xroot.ToLower()] = 1
            $xl = $null
            try { $xl = [HkWalk]::CodeFiles($xroot, 8000) } catch {}
            foreach ($xp in @($xl)) {
                if (-not $xp) { continue }
                if ($xp -notmatch '(?i)\.(jar|zip)$') { continue }
                if ($xp -match $HeavyRx) { continue }
                try { $xf = New-Object IO.FileInfo $xp; if ($xf.Length -lt 104857600) { [void]$jarExtra.Add($xf) } } catch {}
            }
        }
    }
    $jarSrc = New-Object System.Collections.Generic.List[object]
    foreach ($ja in $script:JarCand) { [void]$jarSrc.Add($ja) }
    foreach ($ja in $jarExtra) { [void]$jarSrc.Add($ja) }
    $jarCandList = New-Object System.Collections.Generic.List[object]
    $jarCloud = 0
    $jarTotal = 0
    $jarSeenP = @{}
    foreach ($jx in $jarSrc) {
        $jarTotal++
        $jk = ([string]$jx.FullName).ToLower()
        if ($jarSeenP.ContainsKey($jk)) { continue }
        $jarSeenP[$jk] = 1
        $at = 0
        try { $at = [int]$jx.Attributes } catch {}
        if (($at -band 4460544) -ne 0) { $jarCloud++ } else { [void]$jarCandList.Add($jx) }
    }
    $jarCands = @($jarCandList.ToArray())
    Write-Host ('   aday jar/zip: ' + $jarTotal + ' kayit, ' + $jarSeenP.Count + ' benzersiz dosya, ' + $jarCloud + ' bulut/cevrimdisi dosya') -ForegroundColor DarkGray
    Write-Host ('   ' + $jarCands.Count + ' jar/zip dosyasi derlenmis hizli tarayici ile taraniyor (dosya basina en fazla 45 sn)...') -ForegroundColor DarkGray
    if ($jarCloud -gt 0) { Write-Host ('   ' + $jarCloud + ' bulut (OneDrive vb. indirilmemis) dosya atlandi: acilmasi dosyayi indirtir.') -ForegroundColor DarkYellow }
    $jarSw = [Diagnostics.Stopwatch]::StartNew()
    $jarThreads = [Math]::Max(2, [Math]::Min(4, [Math]::Max(2, [int]([Environment]::ProcessorCount / 2))))
    for ($ci = 0; $ci -lt $jarCands.Count; $ci += 24) {
        $hi = [Math]::Min($ci + 23, $jarCands.Count - 1)
        $chunk = @($jarCands[$ci..$hi])
        $paths = [string[]]@($chunk | ForEach-Object { $_.FullName })
        $res = $null
        try { $res = [HkJar]::ScanMany($paths, $script:ModTermPat, $script:BrandRx.ToString(), $script:PkgRx, 45, $jarThreads) } catch {}
        if ($res) {
            for ($k = 0; $k -lt $paths.Count; $k++) {
                $x = $res[$k]
                if (-not $x -or $x.Error) { continue }
                $ht = @{ Terms = @{}; Brands = @{}; Meta = $x.Meta; Plugin = $x.Plugin; Pkg = $x.Pkg; Classes = $x.Classes; Short = $x.Short; Nested = $x.Nested; TimedOut = $x.TimedOut; Obf = $false; Enc = $x.EncReason; BadMagic = $x.BadMagic; ObfMarks = @($x.ObfMarks); Native = @($x.NativeLibs); HiEnt = @($x.HiEnt) }
                foreach ($tt in $x.Terms) { $ht.Terms[$tt] = 1 }
                foreach ($bb in $x.Brands) { $ht.Brands[$bb] = 1 }
                if ($ht.Classes -ge 20 -and ($ht.Short / [double]$ht.Classes) -ge 0.6) { $ht.Obf = $true }
                $jarResults[$paths[$k]] = $ht
            }
        }
        $doneN = [Math]::Min($ci + 24, $jarCands.Count)
        Set-Frac ($doneN / [Math]::Max(1, $jarCands.Count)) ('jar/zip ' + $doneN + '/' + $jarCands.Count)
        Write-Host ('   jar/zip ilerleme: ' + $doneN + '/' + $jarCands.Count + ' (' + [int]$jarSw.Elapsed.TotalSeconds + ' sn)') -ForegroundColor DarkGray
    }
}
if (-not $jarCsOk) {
$deepJarScript = @'
param($path, $termPat, $brandPat, $pkgPat)
try { Add-Type -AssemblyName System.IO.Compression } catch {}
try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch {}
$termRx = New-Object System.Text.RegularExpressions.Regex ($termPat, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$brandRx = New-Object System.Text.RegularExpressions.Regex ($brandPat, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$lat = [Text.Encoding]::GetEncoding(28591)
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = @{ Terms = @{}; Brands = @{}; Meta = ''; Plugin = $false; Pkg = ''; Classes = 0; Short = 0; Scanned = 0; Nested = 0; TextScanned = 0; Obf = $false; TimedOut = $false }
function Scan-ZipP($zip, [int]$depth) {
    foreach ($e in $zip.Entries) {
        if ($sw.Elapsed.TotalSeconds -gt 45) { $r.TimedOut = $true; break }
        $n = $e.FullName
        if ($n -match '(?i)^(plugin\.yml|bungee\.yml|paper-plugin\.yml|velocity-plugin\.json)$') { $r.Plugin = $true }
        if (-not $r.Pkg -and $n -match $pkgPat) { $r.Pkg = $Matches[1] }
        if ($n.EndsWith('.class')) {
            $r.Classes++
            $cb = ''
            try { $cb = [IO.Path]::GetFileNameWithoutExtension($n) } catch {}
            if ($cb.Length -le 2) { $r.Short++ }
            if ($r.Scanned -lt 2500 -and $e.Length -gt 0 -and $e.Length -lt 1048576) {
                $r.Scanned++
                $st = $e.Open()
                $ms = New-Object IO.MemoryStream
                $st.CopyTo($ms)
                $st.Dispose()
                $t = $lat.GetString($ms.ToArray())
                $ms.Dispose()
                foreach ($m in $termRx.Matches($t)) { $r.Terms[($m.Value.ToLower() -replace ' ', '')] = 1 }
                foreach ($m in $brandRx.Matches($t)) { $r.Brands[($m.Value.ToLower() -replace ' ', '')] = 1 }
            }
        } elseif ($n -match '(?i)^(fabric\.mod\.json|quilt\.mod\.json|mcmod\.info|META-INF/mods\.toml|META-INF/neoforge\.mods\.toml)$' -and $e.Length -lt 65536) {
            $sr = New-Object IO.StreamReader($e.Open())
            $r.Meta = $r.Meta + ' ' + $sr.ReadToEnd()
            $sr.Dispose()
        } elseif ($depth -lt 2 -and $n -match '(?i)\.jar$' -and $e.Length -gt 0 -and $e.Length -lt 31457280 -and $r.Nested -lt 25) {
            $r.Nested++
            try {
                $st = $e.Open()
                $ms = New-Object IO.MemoryStream
                $st.CopyTo($ms)
                $st.Dispose()
                $ms.Position = 0
                $inner = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Read)
                try { Scan-ZipP $inner ($depth + 1) } finally { $inner.Dispose(); $ms.Dispose() }
            } catch {}
        } elseif ($n -match '(?i)\.(json|txt|cfg|toml|properties|yml|yaml)$' -and $e.Length -gt 20 -and $e.Length -lt 262144 -and $r.TextScanned -lt 150) {
            $r.TextScanned++
            try {
                $sr2 = New-Object IO.StreamReader($e.Open())
                $tx = $sr2.ReadToEnd()
                $sr2.Dispose()
                foreach ($m in $termRx.Matches($tx)) { $r.Terms[($m.Value.ToLower() -replace ' ', '')] = 1 }
                foreach ($m in $brandRx.Matches($tx)) { $r.Brands[($m.Value.ToLower() -replace ' ', '')] = 1 }
            } catch {}
        }
    }
}
try {
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try { Scan-ZipP $zip 0 } finally { $zip.Dispose() }
} catch {}
if ($r.Classes -ge 20 -and ($r.Short / [double]$r.Classes) -ge 0.6) { $r.Obf = $true }
$r
'@
$jarResults = @{}
$jarJobs = New-Object System.Collections.Generic.List[object]
Write-Host ('   ' + $script:JarCand.Count + ' jar/zip dosyasi paralel taraniyor (her dosya icin en fazla 45 sn)...') -ForegroundColor DarkGray
$jarPool = $null
try {
    $nTh = [Math]::Max(2, [Math]::Min(6, [Environment]::ProcessorCount))
    $jarPool = [runspacefactory]::CreateRunspacePool(1, $nTh)
    $jarPool.Open()
    foreach ($jq in $script:JarCand) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $jarPool
        [void]$ps.AddScript($deepJarScript).AddArgument($jq.FullName).AddArgument($script:ModTermPat).AddArgument($script:BrandRx.ToString()).AddArgument($script:PkgRx)
        [void]$jarJobs.Add([pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke(); Path = $jq.FullName })
    }
} catch {}
$jobTotal = $jarJobs.Count
$jobDone = 0
$jobSw = [Diagnostics.Stopwatch]::StartNew()
$timedOutJars = New-Object System.Collections.Generic.List[string]
foreach ($jj in $jarJobs) {
    $jobDone++
    Set-Frac ($jobDone / [Math]::Max(1, $jobTotal)) ('jar/zip ' + $jobDone + '/' + $jobTotal)
    if (($jobDone % 10) -eq 0 -or $jobDone -eq $jobTotal) { Write-Host ('   jar/zip ilerleme: ' + $jobDone + '/' + $jobTotal + ' (' + [int]$jobSw.Elapsed.TotalSeconds + ' sn)') -ForegroundColor DarkGray }
    if (-not $jj.H.AsyncWaitHandle.WaitOne(120000)) {
        [void]$timedOutJars.Add($jj.Path)
        try { [void]$jj.PS.BeginStop($null, $null) } catch {}
        $jarResults[$jj.Path] = @{ Terms = @{}; Brands = @{}; Meta = ''; Plugin = $true; Pkg = ''; Classes = 0; Short = 0; Obf = $false; Nested = 0; TimedOut = $true }
        continue
    }
    try {
        $out = $jj.PS.EndInvoke($jj.H)
        if ($out -and $out.Count -gt 0) {
            $o1 = $out[$out.Count - 1]
            if ($o1 -is [System.Management.Automation.PSObject]) { $o1 = $o1.BaseObject }
            if ($o1 -is [hashtable] -and $o1.ContainsKey('Terms')) { $jarResults[$jj.Path] = $o1 }
        }
    } catch {}
    try { $jj.PS.Dispose() } catch {}
}
if ($jarPool) { try { [void]$jarPool.BeginClose($null, $null) } catch {} }
foreach ($toj in @($timedOutJars | Select-Object -First 10)) { Log ('   ZAMAN ASIMI (atlandi, elle bak): ' + $toj) 'DarkYellow' }
}
$jdN = 0
$jarIter = $script:JarCand
if ($jarCsOk) { $jarIter = $jarCands }
$testSeen = $false
foreach ($jf in $jarIter) {
    $jdN++
    $jr = $null
    if ($jarResults.ContainsKey($jf.FullName)) { $jr = $jarResults[$jf.FullName] }
    if (-not $jr) {
        if ($jf.Name -like 'TestHile*') { $testSeen = $true; Write-Host ('   [test dosyasi] ' + $jf.FullName + ' -> TARAMA SONUCU YOK (dosya acilamadi veya tarayici hata verdi)') -ForegroundColor Red }
        if ($jarCsOk) { continue }
        $jr = Deep-Jar $jf.FullName
    }
    if ($jr.Plugin) { continue }
    $tl = @($jr.Terms.Keys)
    $bl = @($jr.Brands.Keys)
    if ($jf.Name -like 'TestHile*') { $testSeen = $true; Write-Host ('   [test dosyasi] ' + $jf.FullName + ' -> ' + $tl.Count + ' modul ismi bulundu') -ForegroundColor Cyan }
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    if ($tl.Count -ge 3) { $sc += 70 } elseif ($tl.Count -eq 2) { $sc += 55 } elseif ($tl.Count -eq 1) { $sc += 30 }
    if ($tl.Count -gt 0) { [void]$why.Add('icerikte hile modulu stringleri (' + $tl.Count + ' adet): ' + ($tl -join ', ')) }
    if ($bl.Count -gt 0) { $sc += 35; [void]$why.Add('icerikte bilinen hile istemcisi ismi: ' + ($bl -join ', ')) }
    if ($jr.Pkg) { $sc += 40; [void]$why.Add('bilinen hile istemcisi paket yolu: ' + $jr.Pkg) }
    if ($jr.Obf) { $sc += 25; [void]$why.Add('obfuscate edilmis gorunuyor (' + $jr.Short + '/' + $jr.Classes + ' sinif adi 1-2 harf)') }
    if ($jr.Nested -gt 0) { [void]$why.Add('ic ice jar: ' + $jr.Nested) }
    if ($jr.TimedOut) { [void]$why.Add('tarama 45 sn sinirina takildi, sonuc kismi') }
    $jfp = $jf.FullName
    if ($jr.Enc) { $sc += 25; [void]$why.Add([string]$jr.Enc); Add-ObfNote $jfp ([string]$jr.Enc) }
    if ($jr.BadMagic -gt 0) { $sc += 40; [void]$why.Add('class dosyalarinin ' + $jr.BadMagic + ' tanesi gecersiz (sifreli olabilir)'); Add-ObfNote $jfp ('sifreli/bozuk class dosyasi: ' + $jr.BadMagic) }
    $omk = @($jr.ObfMarks | Where-Object { $_ })
    if ($omk.Count -gt 0) { $sc += 15; [void]$why.Add('obfuscator imzasi: ' + ($omk -join ', ')); Add-ObfNote $jfp ('obfuscator imzasi: ' + ($omk -join ', ')) }
    $nlb = @($jr.Native | Where-Object { $_ })
    if ($nlb.Count -gt 0) { $sc += 10; [void]$why.Add('jar icinde yerel kutuphane: ' + ($nlb -join ', ')); Add-ObfNote $jfp ('jar icinde yerel kutuphane (dll/so): ' + ($nlb -join ', ')) }
    $heb = @($jr.HiEnt | Where-Object { $_ })
    if ($heb.Count -gt 0) { $sc += 15; [void]$why.Add('yuksek entropili veri dosyasi: ' + ($heb -join ', ')); Add-ObfNote $jfp ('yuksek entropili veri dosyasi: ' + ($heb -join ', ')) }
    if ($jr.Obf) { Add-ObfNote $jfp ('obfuscate edilmis (' + $jr.Short + '/' + $jr.Classes + ' sinif adi 1-2 harf)') }
    $mh = Get-NameHit $jr.Meta $false
    if ($mh) { $sc += 40; [void]$why.Add('mod bilgisinde (fabric.mod.json/mcmod.info vb.) hile ismi: ' + $mh.Name) }
    if ($sc -ge 25) {
        Add-F -Kaynak 'Jar/zip icerik taramasi' -Ad ('jar: ' + $jf.Name.ToLower()) -Yol $jf.FullName -Skor ([Math]::Min(100, $sc)) -Son $jf.LastWriteTime -Ilk $jf.CreationTime -Var 'Evet' -Not (($why -join '; ') + ' | NOT: string sifreleme/agir obfuscation kullanan hilelerde class stringleri gorunmez')
    }
}
foreach ($ap in @($script:ArcOther)) {
    $er = ''
    try { $er = [HkJar]::EncInfo($ap) } catch {}
    if ($er) {
        Add-ObfNote $ap $er
        Add-F -Kaynak 'Jar/zip icerik taramasi (sifreli arsiv)' -Ad ('arsiv: ' + (Split-Path -Leaf $ap).ToLower()) -Yol $ap -Skor 35 -Var 'Evet' -Not ($er + ' | icerigi okunamadi, elle ac ve bak')
    }
}
if (-not $testSeen) { Write-Host '   [test dosyasi] TestHile.jar tarama listesinde yok (Masaustu/Indirilenler/Belgeler/script klasorunde degil, ya da koymadin).' -ForegroundColor DarkGray }
Log ('   ' + $jdN + ' jar/zip dosyasinin icerigi (ic ice jar dahil) okundu.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Step '[17+/17] T) Bellek taramasi: Java ve kullanici klasorlerinden calisan process lerde hile modul isimleri (hile ACIKKEN calistir)...'
Start-Sec
if (-not $script:HkOk) {
    Log '   yardimci modul derlenemedi, bellek taramasi atlandi.' 'DarkYellow'
} else {
    try { [void][HkNative]::EnableDebug() } catch {}
    $skipProc = '(?i)^(powershell|pwsh|conhost|WindowsTerminal|chrome|msedge|firefox|opera|brave|discord|code|notepad|explorer|steam|steamwebhelper|OneDrive|Teams|slack|Spotify|devenv|cmd)$'
    $tgts = New-Object System.Collections.Generic.List[object]
    foreach ($gp in @(Get-Process -ErrorAction SilentlyContinue)) {
        if ($gp.Id -le 4 -or $gp.Id -eq $PID) { continue }
        if ($gp.ProcessName -match $skipProc) { continue }
        $pth = ''
        try { $pth = [string]$gp.Path } catch {}
        $isJ = ($gp.ProcessName -match '(?i)^javaw?$')
        if (-not $isJ) {
            if (-not $pth) { continue }
            if ((Get-Zone $pth) -eq 'system') { continue }
            if (Test-Signed $pth) { continue }
        }
        [void]$tgts.Add([pscustomobject]@{ Id = $gp.Id; Name = $gp.ProcessName; Path = $pth; Java = $isJ })
    }
    $tN = 0
    foreach ($t in @($tgts)) {
        $tN++
        $cap = [long]157286400
        if ($t.Java) { $cap = [long]734003200 }
        Log ('   bellek taraniyor: ' + $t.Name + ' (PID ' + $t.Id + ')') 'DarkGray'
        $list = $null
        try { $list = [HkNative]::MemStrings([int]$t.Id, $script:ModTermPat, 5, $true, $true, $false, $cap) } catch { $list = $null }
        if ($null -eq $list -or $list.Count -eq 0) { continue }
        $terms = @{}
        foreach ($sx in $list) { Get-Terms $sx $terms }
        $tk = @($terms.Keys)
        if ($tk.Count -eq 0) { continue }
        $sc = 25
        if ($tk.Count -ge 3) { $sc = 70 } elseif ($tk.Count -eq 2) { $sc = 50 }
        if ($t.Java -and $sc -ge 50) { $sc += 10 }
        Add-F -Kaynak 'Bellek stringi: hile modul isimleri' -Ad ('bellek: ' + $t.Name.ToLower() + ' (PID ' + $t.Id + ')') -Yol $t.Path -Skor ([Math]::Min(100, $sc)) -Var 'Evet' -Not ('process belleginde hile modul isimleri: ' + ($tk -join ', ') + ' | Hile bu process icine enjekte edilmis ya da kendisi olabilir; ayni isimler yazili bir sohbet/dokuman da olabilir, process in ne oldugunu kontrol et. Process kapaliysa gorunmez.')
    }
    Log ('   ' + $tN + ' process bellegi tarandi.') 'DarkGray'
}
Show-Section

# ---------------------------------------------------------------------
Step '[17+/17] U) Dosya ICERIK taramasi: exe/dll (JNI, enjektor, modul stringleri) ve ayar dosyalari (cfg/json/toml/txt)...'
Start-Sec
$jniRx = New-Object System.Text.RegularExpressions.Regex ('JNI_GetCreatedJavaVMs|GetCreatedJavaVMs|jvmtiEnv|AttachCurrentThread', [System.Text.RegularExpressions.RegexOptions]::None)
$mcRx = New-Object System.Text.RegularExpressions.Regex ('net/minecraft/client|net\.minecraft\.client|class_310|class_746|Lnet/minecraft/|net/minecraft/class_|com/mojang/blaze3d', [System.Text.RegularExpressions.RegexOptions]::None)
$injRx1 = New-Object System.Text.RegularExpressions.Regex ('WriteProcessMemory', [System.Text.RegularExpressions.RegexOptions]::None)
$injRx2 = New-Object System.Text.RegularExpressions.Regex ('CreateRemoteThread|NtCreateThreadEx|RtlCreateUserThread|QueueUserAPC|SetWindowsHookEx', [System.Text.RegularExpressions.RegexOptions]::None)
$injRx3 = New-Object System.Text.RegularExpressions.Regex ('javaw|java\.exe|Minecraft', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$binCs = @'
using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Globalization;
using System.Threading.Tasks;
public class HkBinRes {
    public bool Ok;
    public string[] Terms = new string[0];
    public string[] Brands = new string[0];
    public bool Jni;
    public bool Mc;
    public bool Inj;
    public string PackReason = "";
    public int PackBonus;
}
public static class HkBin {
    static Dictionary<string, Regex> Cache = new Dictionary<string, Regex>();
    static Regex RxPack = new Regex(@"^\.?(upx\d|vmp\d|themida|winlice|enigma\d?|aspack|adata|petite|mpress\d|nsp\d|boom|perplex|pec\d?|yoda|rlpack|kkrunchy|neolite|molebox|obsidium|armadillo|svkp|ezip)", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    static string[] JniN = new string[] { "JNI_GetCreatedJavaVMs", "GetCreatedJavaVMs", "jvmtiEnv", "AttachCurrentThread" };
    static string[] McN = new string[] { "net/minecraft/client", "net.minecraft.client", "class_310", "class_746", "Lnet/minecraft/", "net/minecraft/class_", "com/mojang/blaze3d" };
    static string[] Inj2 = new string[] { "CreateRemoteThread", "NtCreateThreadEx", "RtlCreateUserThread", "QueueUserAPC", "SetWindowsHookEx" };
    static string[] Inj3 = new string[] { "javaw", "java.exe", "Minecraft" };
    static Regex Get(string p) {
        lock (Cache) {
            Regex r;
            if (!Cache.TryGetValue(p, out r)) { r = new Regex(p, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled); Cache[p] = r; }
            return r;
        }
    }
    static bool Any(string t, string[] nd, StringComparison c) {
        foreach (string s in nd) { if (t.IndexOf(s, c) >= 0) return true; }
        return false;
    }
    static void Harvest(Regex rx, string text, HashSet<string> set) {
        foreach (Match m in rx.Matches(text)) { set.Add(m.Value.ToLowerInvariant().Replace(" ", "")); }
    }
    static double Entropy(byte[] b, int max) {
        if (b == null || b.Length == 0) return 0.0;
        int n = Math.Min(b.Length, max);
        long[] cnt = new long[256];
        for (int i = 0; i < n; i++) cnt[b[i]]++;
        double h = 0.0;
        for (int i = 0; i < 256; i++) {
            if (cnt[i] == 0) continue;
            double p = (double)cnt[i] / n;
            h -= p * Math.Log(p, 2.0);
        }
        return h;
    }
    static List<string> PeSections(byte[] b) {
        List<string> r = new List<string>();
        try {
            if (b == null || b.Length < 256 || b[0] != 0x4D || b[1] != 0x5A) return r;
            int pe = BitConverter.ToInt32(b, 0x3C);
            if (pe < 0 || pe + 24 > b.Length) return r;
            if (b[pe] != 0x50 || b[pe + 1] != 0x45) return r;
            int nsec = BitConverter.ToUInt16(b, pe + 6);
            int optSize = BitConverter.ToUInt16(b, pe + 20);
            int sec = pe + 24 + optSize;
            for (int i = 0; i < nsec && i < 40; i++) {
                int o = sec + i * 40;
                if (o + 8 > b.Length) break;
                r.Add(Encoding.ASCII.GetString(b, o, 8).TrimEnd('\0'));
            }
        } catch { }
        return r;
    }
    static string[] ToArr(HashSet<string> h) { string[] a = new string[h.Count]; h.CopyTo(a); return a; }
    public static HkBinRes ScanBin(string path, Regex term, Regex brand) {
        HkBinRes r = new HkBinRes();
        byte[] b = null;
        try { b = File.ReadAllBytes(path); } catch { return r; }
        if (b == null) return r;
        r.Ok = true;
        string t = Encoding.GetEncoding(28591).GetString(b);
        r.Jni = Any(t, JniN, StringComparison.Ordinal);
        r.Mc = Any(t, McN, StringComparison.Ordinal);
        HashSet<string> tk = new HashSet<string>();
        HashSet<string> bk = new HashSet<string>();
        Harvest(term, t, tk);
        Harvest(brand, t, bk);
        if (b.Length < 8388608) {
            string tu = Encoding.Unicode.GetString(b);
            Harvest(term, tu, tk);
            Harvest(brand, tu, bk);
        }
        r.Inj = (t.IndexOf("WriteProcessMemory", StringComparison.Ordinal) >= 0) && Any(t, Inj2, StringComparison.Ordinal) && Any(t, Inj3, StringComparison.OrdinalIgnoreCase);
        r.Terms = ToArr(tk);
        r.Brands = ToArr(bk);
        if (b.Length >= 4096) {
            List<string> pk = new List<string>();
            foreach (string sn in PeSections(b)) { if (RxPack.IsMatch(sn)) pk.Add(sn); }
            double ent = Entropy(b, 8388608);
            List<string> parts = new List<string>();
            int bonus = 0;
            if (pk.Count > 0) { parts.Add("paketleyici/koruyucu bolum adlari: " + string.Join(", ", pk.ToArray())); bonus = 25; }
            if (ent > 7.4 && b.Length > 200000) { parts.Add("yuksek entropi " + Math.Round(ent, 2).ToString(CultureInfo.InvariantCulture) + " (paketlenmis/sifreli icerik olabilir)"); bonus += 15; }
            if (parts.Count > 0) { r.PackReason = string.Join("; ", parts.ToArray()); r.PackBonus = bonus; }
        }
        return r;
    }
    public static HkBinRes[] ScanBinMany(string[] paths, string termPat, string brandPat, int threads) {
        Regex term = Get(termPat);
        Regex brand = Get(brandPat);
        HkBinRes[] res = new HkBinRes[paths.Length];
        ParallelOptions po = new ParallelOptions();
        po.MaxDegreeOfParallelism = threads;
        Parallel.For(0, paths.Length, po, delegate(int i) {
            try { res[i] = ScanBin(paths[i], term, brand); } catch { res[i] = new HkBinRes(); }
        });
        return res;
    }
    public static HkBinRes[] CfgMany(string[] paths, string termPat, string brandPat, int threads) {
        Regex term = Get(termPat);
        Regex brand = Get(brandPat);
        HkBinRes[] res = new HkBinRes[paths.Length];
        ParallelOptions po = new ParallelOptions();
        po.MaxDegreeOfParallelism = threads;
        Parallel.For(0, paths.Length, po, delegate(int i) {
            HkBinRes r = new HkBinRes();
            try {
                string ct = File.ReadAllText(paths[i]);
                if (!string.IsNullOrEmpty(ct)) {
                    r.Ok = true;
                    HashSet<string> tk = new HashSet<string>();
                    HashSet<string> bk = new HashSet<string>();
                    Harvest(term, ct, tk);
                    Harvest(brand, ct, bk);
                    r.Terms = ToArr(tk);
                    r.Brands = ToArr(bk);
                }
            } catch { }
            res[i] = r;
        });
        return res;
    }
}
'@
$binCsOk = $false
try {
    if (-not ('HkBin' -as [type])) { Add-Type -TypeDefinition $binCs -Language CSharp -ErrorAction Stop }
    $binCsOk = $true
} catch { Log ('   UYARI: paralel icerik tarayici derlenemedi, eski sirali yola donuluyor: ' + $_.Exception.Message) 'DarkYellow' }
$budget = [long]1610612736
$uSw = [Diagnostics.Stopwatch]::StartNew()
$uIdx = 0
$binOrder = @($script:BinCand | Sort-Object @{ Expression = { if ($_.FullName -match $SigRx) { 0 } else { 1 } } }, Length)
$uTotal = $binOrder.Count
$uFastNote = $false
$script:BinSkipped = @()
$script:BinFastList = New-Object System.Collections.Generic.List[object]
function Has-Any([string]$t, [string[]]$needles, [bool]$ic = $false) {
    $cmp = [StringComparison]::Ordinal
    if ($ic) { $cmp = [StringComparison]::OrdinalIgnoreCase }
    foreach ($nd in $needles) { if ($t.IndexOf($nd, $cmp) -ge 0) { return $true } }
    return $false
}
$uN = 0
if ($binCsOk) {
    $uList = New-Object System.Collections.Generic.List[object]
    foreach ($bf in $binOrder) {
        $pth = $bf.FullName
        if ((Get-Zone $pth) -eq 'system') { continue }
        if ($bf.Name.ToLower() -match $knownNat) { continue }
        if ($bf.Length -gt 12582912 -and (Test-Signed $pth)) { continue }
        [void]$uList.Add($bf)
    }
    $uArr = $uList.ToArray()
    $uThr = [Math]::Max(2, [Math]::Min(4, [Environment]::ProcessorCount))
    Log ('   ' + $uArr.Count + ' exe/dll paralel taraniyor (' + $uThr + ' is parcacigi, sure siniri yok)...') 'DarkGray'
    for ($ci = 0; $ci -lt $uArr.Count; $ci += 16) {
        $hi = [Math]::Min($ci + 15, $uArr.Count - 1)
        $chunkP = [string[]]@($uArr[$ci..$hi] | ForEach-Object { $_.FullName })
        $res = $null
        try { $res = [HkBin]::ScanBinMany($chunkP, $script:ModTermPat, $script:BrandRx.ToString(), $uThr) } catch {}
        $dn = $ci + $chunkP.Count
        Set-Frac ($dn / [Math]::Max(1, $uArr.Count)) ('exe/dll ' + $dn + '/' + $uArr.Count)
        if (($dn % 64) -lt 16 -or $dn -ge $uArr.Count) { Write-Host ('   exe/dll ilerleme: ' + $dn + '/' + $uArr.Count + ' (' + [int]$uSw.Elapsed.TotalSeconds + ' sn)') -ForegroundColor DarkGray }
        if (-not $res) { continue }
        for ($k = 0; $k -lt $chunkP.Count; $k++) {
            $x = $res[$k]
            if (-not $x -or -not $x.Ok) { continue }
            $bf = $uArr[$ci + $k]
            $pth = $bf.FullName
            $uN++
            $tk = @($x.Terms)
            $bk = @($x.Brands)
            $sc = 0
            $why = New-Object System.Collections.Generic.List[string]
            if ($tk.Count -ge 3) { $sc += 70 } elseif ($tk.Count -eq 2) { $sc += 50 } elseif ($tk.Count -eq 1) { $sc += 25 }
            if ($tk.Count -gt 0) { [void]$why.Add('icerikte hile modulu stringleri: ' + ($tk -join ', ')) }
            if ($bk.Count -gt 0) { $sc += 35; [void]$why.Add('icerikte bilinen hile istemcisi ismi: ' + ($bk -join ', ')) }
            if ($x.Jni -and $x.Mc) { $sc += 40; [void]$why.Add('Minecraft sinif adlari + JNI/JVMTI: Java disindan oyuna baglanan program/DLL') }
            if ($x.Inj) { $sc += 45; [void]$why.Add('enjektor belirtileri (WriteProcessMemory + uzak thread + javaw/Minecraft)') }
            if ($x.PackReason) { $sc += $x.PackBonus; [void]$why.Add($x.PackReason) }
            if ($sc -lt 25) { continue }
            $sig = Test-Signed $pth
            if ($x.PackReason -and -not $sig) { Add-ObfNote $pth $x.PackReason }
            if ($sig -and $tk.Count -lt 3) { continue }
            $sg = 'imzasiz'
            if ($sig) { $sg = 'imzali' }
            Add-F -Kaynak 'Dosya icerik taramasi (exe/dll)' -Ad $bf.Name.ToLower() -Yol $pth -Skor ([Math]::Min(100, $sc)) -Son $bf.LastWriteTime -Ilk $bf.CreationTime -Var 'Evet' -Not (($why -join '; ') + ' | ' + $sg + ' | icerik: dosyanin ham baytlari (Latin1 + UTF-16) tarandi')
        }
    }
} else {
foreach ($bf in $binOrder) {
    if (((Get-Date) - $Started).TotalSeconds -gt 540) { Log '   toplam sure 9 dakikayi asti, exe/dll icerik taramasinin kalani atlandi.' 'DarkYellow'; $script:BinSkipped = @($binOrder[$uIdx..($binOrder.Count - 1)]); break }
    if ($budget -le 0) { Log '   exe/dll okuma butcesi (1.5 GB) doldu, kalan dosyalar atlandi.' 'DarkYellow'; $script:BinSkipped = @($binOrder[$uIdx..($binOrder.Count - 1)]); break }
    if ($uSw.Elapsed.TotalSeconds -gt 300) { Log '   exe/dll icerik taramasi 300 sn sinirina ulasti, kalan dosyalar atlandi.' 'DarkYellow'; $script:BinSkipped = @($binOrder[$uIdx..($binOrder.Count - 1)]); break }
    $uIdx++
    Set-Frac ($uIdx / [Math]::Max(1, $uTotal)) ('exe/dll ' + $uIdx + '/' + $uTotal)
    if (($uIdx % 25) -eq 0) { Write-Host ('   exe/dll ilerleme: ' + $uIdx + '/' + $uTotal + ' (' + [int]$uSw.Elapsed.TotalSeconds + ' sn)') -ForegroundColor DarkGray }
    $pth = $bf.FullName
    if ((Get-Zone $pth) -eq 'system') { continue }
    if ($bf.Name.ToLower() -match $knownNat) { continue }
    if ($bf.Length -gt 12582912 -and (Test-Signed $pth)) { continue }
    $b = $null
    try { $b = [IO.File]::ReadAllBytes($pth) } catch { continue }
    if ($null -eq $b) { continue }
    $budget -= $b.Length
    $uN++
    $t = [Text.Encoding]::GetEncoding(28591).GetString($b)
    $isJni = Has-Any $t @('JNI_GetCreatedJavaVMs', 'GetCreatedJavaVMs', 'jvmtiEnv', 'AttachCurrentThread')
    $isMc = Has-Any $t @('net/minecraft/client', 'net.minecraft.client', 'class_310', 'class_746', 'Lnet/minecraft/', 'net/minecraft/class_', 'com/mojang/blaze3d')
    $terms = @{}
    $brands = @{}
    # Buyuk (4 MB ustu) dosyalarda agir modul/marka regex i sadece Minecraft/Java ile iliskili izler varsa calisir
    $mcRel = ($isJni -or $isMc -or (Has-Any $t @('minecraft', 'javaw', 'lwjgl', 'glfw', 'jvmti') $true))
    $fullMode = ($uSw.Elapsed.TotalSeconds -lt 150 -and ((Get-Date) - $Started).TotalSeconds -lt 420)
    if (-not $fullMode -and -not $uFastNote) {
        $uFastNote = $true
        Log '   sure butcesi nedeniyle buyuk dosyalarda hizli moda gecildi (Minecraft/Java izi olmayan 4 MB ustu dosyalarda modul stringi artik aranmiyor).' 'DarkYellow'
    }
    if ($b.Length -lt 4194304 -or $mcRel -or $fullMode) {
        Get-Terms $t $terms
        Get-Brands $t $brands
        if ($b.Length -lt 8388608) {
            $tu = [Text.Encoding]::Unicode.GetString($b)
            Get-Terms $tu $terms
            Get-Brands $tu $brands
        }
    } else {
        [void]$script:BinFastList.Add($bf)
    }
    $isInj = ((Has-Any $t @('WriteProcessMemory')) -and (Has-Any $t @('CreateRemoteThread', 'NtCreateThreadEx', 'RtlCreateUserThread', 'QueueUserAPC', 'SetWindowsHookEx')) -and (Has-Any $t @('javaw', 'java.exe', 'Minecraft') $true))
    $tk = @($terms.Keys)
    $bk = @($brands.Keys)
    $sc = 0
    $why = New-Object System.Collections.Generic.List[string]
    if ($tk.Count -ge 3) { $sc += 70 } elseif ($tk.Count -eq 2) { $sc += 50 } elseif ($tk.Count -eq 1) { $sc += 25 }
    if ($tk.Count -gt 0) { [void]$why.Add('icerikte hile modulu stringleri: ' + ($tk -join ', ')) }
    if ($bk.Count -gt 0) { $sc += 35; [void]$why.Add('icerikte bilinen hile istemcisi ismi: ' + ($bk -join ', ')) }
    if ($isJni -and $isMc) { $sc += 40; [void]$why.Add('Minecraft sinif adlari + JNI/JVMTI: Java disindan oyuna baglanan program/DLL') }
    if ($isInj) { $sc += 45; [void]$why.Add('enjektor belirtileri (WriteProcessMemory + uzak thread + javaw/Minecraft)') }
    $pk = Get-PackInfo $b
    if ($pk.Reason) { $sc += $pk.Bonus; [void]$why.Add($pk.Reason) }
    if ($sc -lt 25) { continue }
    $sig = Test-Signed $pth
    if ($pk.Reason -and -not $sig) { Add-ObfNote $pth $pk.Reason }
    if ($sig -and $tk.Count -lt 3) { continue }
    $sg = 'imzasiz'
    if ($sig) { $sg = 'imzali' }
    Add-F -Kaynak 'Dosya icerik taramasi (exe/dll)' -Ad $bf.Name.ToLower() -Yol $pth -Skor ([Math]::Min(100, $sc)) -Son $bf.LastWriteTime -Ilk $bf.CreationTime -Var 'Evet' -Not (($why -join '; ') + ' | ' + $sg + ' | icerik: dosyanin ham baytlari (Latin1 + UTF-16) tarandi')
}
}
Log ('   ' + $uN + ' exe/dll icerigi okundu.') 'DarkGray'

$cfN = 0
$cfgTestSeen = $false
$cfSw = [Diagnostics.Stopwatch]::StartNew()
$cfAll = $script:CfgCand.ToArray()
$cfIdx = 0
$script:CfgSkipped = @()
if ($binCsOk) {
    $cfPaths = [string[]]@($cfAll | ForEach-Object { $_.FullName })
    $cfThr = [Math]::Max(2, [Math]::Min(4, [Math]::Max(2, [int]([Environment]::ProcessorCount / 2))))
    for ($ci = 0; $ci -lt $cfPaths.Count; $ci += 64) {
        $hi = [Math]::Min($ci + 63, $cfPaths.Count - 1)
        $chunkP = [string[]]@($cfPaths[$ci..$hi])
        $res = $null
        try { $res = [HkBin]::CfgMany($chunkP, $script:ModTermPat, $script:BrandRx.ToString(), $cfThr) } catch {}
        Set-Frac (($ci + $chunkP.Count) / [Math]::Max(1, $cfPaths.Count)) ('ayar dosyasi ' + ($ci + $chunkP.Count) + '/' + $cfPaths.Count)
        if (-not $res) { continue }
        for ($k = 0; $k -lt $chunkP.Count; $k++) {
            $x = $res[$k]
            if (-not $x -or -not $x.Ok) { continue }
            $cf = $cfAll[$ci + $k]
            $cfN++
            $tk = @($x.Terms)
            $bk = @($x.Brands)
            if ($cf.Name -like 'TestHile*') { $cfgTestSeen = $true; Write-Host ('   [test dosyasi] ' + $cf.FullName + ' -> ' + $tk.Count + ' modul ismi bulundu') -ForegroundColor Cyan }
            $sc = 0
            if ($tk.Count -ge 3) { $sc = 60 } elseif ($tk.Count -eq 2) { $sc = 45 }
            if ($bk.Count -gt 0) { $sc += 35 }
            if ($sc -lt 35) { continue }
            $nt = 'ayar dosyasi icinde'
            if ($tk.Count -gt 0) { $nt = $nt + ' hile modulu isimleri: ' + ($tk -join ', ') }
            if ($bk.Count -gt 0) { $nt = $nt + ' | istemci ismi: ' + ($bk -join ', ') }
            Add-F -Kaynak 'Ayar dosyasi icerik taramasi' -Ad $cf.Name.ToLower() -Yol $cf.FullName -Skor ([Math]::Min(100, $sc)) -Son $cf.LastWriteTime -Ilk $cf.CreationTime -Var 'Evet' -Not ($nt + ' | hile istemcileri modul ayarlarini (acik/kapali, tus) boyle dosyalara yazar; ayri bir mesru program da olabilir')
        }
    }
} else {
foreach ($cf in $cfAll) {
    if ($cfSw.Elapsed.TotalSeconds -gt 150) { Log '   ayar dosyasi taramasi 150 sn sinirina ulasti, kalanlar atlandi.' 'DarkYellow'; $script:CfgSkipped = @($cfAll[$cfIdx..($cfAll.Count - 1)]); break }
    $cfIdx++
    $ct = $null
    try { $ct = [IO.File]::ReadAllText($cf.FullName) } catch { continue }
    if (-not $ct) { continue }
    $cfN++
    $terms = @{}
    $brands = @{}
    Get-Terms $ct $terms
    Get-Brands $ct $brands
    $tk = @($terms.Keys)
    $bk = @($brands.Keys)
    if ($cf.Name -like 'TestHile*') { $cfgTestSeen = $true; Write-Host ('   [test dosyasi] ' + $cf.FullName + ' -> ' + $tk.Count + ' modul ismi bulundu') -ForegroundColor Cyan }
    $sc = 0
    if ($tk.Count -ge 3) { $sc = 60 } elseif ($tk.Count -eq 2) { $sc = 45 }
    if ($bk.Count -gt 0) { $sc += 35 }
    if ($sc -lt 35) { continue }
    $nt = 'ayar dosyasi icinde'
    if ($tk.Count -gt 0) { $nt = $nt + ' hile modulu isimleri: ' + ($tk -join ', ') }
    if ($bk.Count -gt 0) { $nt = $nt + ' | istemci ismi: ' + ($bk -join ', ') }
    Add-F -Kaynak 'Ayar dosyasi icerik taramasi' -Ad $cf.Name.ToLower() -Yol $cf.FullName -Skor ([Math]::Min(100, $sc)) -Son $cf.LastWriteTime -Ilk $cf.CreationTime -Var 'Evet' -Not ($nt + ' | hile istemcileri modul ayarlarini (acik/kapali, tus) boyle dosyalara yazar; ayri bir mesru program da olabilir')
}
}
if (-not $cfgTestSeen) { Write-Host '   [test dosyasi] TestHile_ayar.json ayar listesinde yok (Masaustu/Indirilenler/Belgeler altinda degil, ya da koymadin).' -ForegroundColor DarkGray }
Log ('   ' + $cfN + ' ayar/metin dosyasinin icerigi okundu.') 'DarkGray'
Show-Section

# ---------------------------------------------------------------------
Invoke-NameDeep

# =====================================================================
# BIRLESTIRME (ayni dosya adi birden fazla kaynakta gorunuyorsa guven artar)
# =====================================================================
$merged = New-Object System.Collections.Generic.List[object]
$all = @($script:F.ToArray())
foreach ($g in ($all | Group-Object -Property Ad)) {
    $items = @($g.Group)
    $mx = 0
    foreach ($i in $items) { if ($i.Skor -gt $mx) { $mx = $i.Skor } }
    $srcs = @($items | ForEach-Object { $_.Kaynak } | Select-Object -Unique)
    $bonus = [Math]::Min(30, 10 * ($srcs.Count - 1))
    $skor = [Math]::Min(100, $mx + $bonus)
    $var = 'Bilinmiyor'
    $yol = $items[0].Yol
    $ev = @($items | Where-Object { $_.Var -eq 'Evet' })
    $hy = @($items | Where-Object { $_.Var -eq 'Hayir' })
    if ($ev.Count -gt 0) { $var = 'Evet'; $yol = $ev[0].Yol } elseif ($hy.Count -gt 0) { $var = 'Hayir'; $yol = $hy[0].Yol }
    $sonList = @($items | Where-Object { $_.Son } | ForEach-Object { [datetime]$_.Son })
    $ilkList = @($items | Where-Object { $_.Ilk } | ForEach-Object { [datetime]$_.Ilk })
    $silList = @($items | Where-Object { $_.Silinme } | ForEach-Object { [datetime]$_.Silinme })
    $son = $null
    $ilk = $null
    $sil = $null
    if ($sonList.Count -gt 0) { $son = ($sonList | Sort-Object -Descending | Select-Object -First 1) }
    if ($ilkList.Count -gt 0) { $ilk = ($ilkList | Sort-Object | Select-Object -First 1) }
    if ($silList.Count -gt 0) { $sil = ($silList | Sort-Object -Descending | Select-Object -First 1) }
    $notes = @($items | ForEach-Object { $_.Not } | Where-Object { $_ } | Select-Object -Unique)
    if ($var -eq 'Hayir' -and -not $sil) {
        $k = ([string]$g.Name).ToLower()
        if ($script:UsnDel.ContainsKey($k)) { $sil = $script:UsnDel[$k]; $notes += 'silinme zamani USN gunlugunden' }
        if (-not $sil) {
            foreach ($bi in $script:BinItems) {
                $bl = ''
                try { $bl = (Split-Path -Leaf $bi.Orijinal).ToLower() } catch {}
                if ($bl -eq $k -and $bi.Silinme) { $sil = $bi.Silinme; $notes += 'silinme zamani geri donusum kutusu kaydindan'; break }
            }
        }
    }
    $allBenign = (@($items | Where-Object { -not $_.Benign }).Count -eq 0)
    [void]$merged.Add([pscustomobject]@{ Ad = $g.Name; Yol = $yol; Skor = $skor; Var = $var; Son = $son; Ilk = $ilk; Silinme = $sil; Kaynaklar = ($srcs -join ', '); Not = ($notes -join ' ; '); Benign = $allBenign })
}
$ranked = @($merged | Sort-Object -Property @{ Expression = 'Skor'; Descending = $true }, @{ Expression = 'Son'; Descending = $true })
$high = @($ranked | Where-Object { $_.Skor -ge 60 })
$mid = @($ranked | Where-Object { $_.Skor -ge 40 -and $_.Skor -lt 60 })
$low = @($ranked | Where-Object { $_.Skor -lt 40 })
$total = $ranked.Count

# =====================================================================
# SONUC EKRANI
# =====================================================================
Log '' 'Gray'
Log '===================================================================' 'Green'
Log '  SONUC - HileKiran' 'Green'
Log '===================================================================' 'Green'
if ($total -gt 0) {
    $ph = [Math]::Round(100 * $high.Count / $total)
    $pm = [Math]::Round(100 * $mid.Count / $total)
    $pl = 100 - $ph - $pm
    Log ('  Toplam bulgu: ' + $total) 'White'
    Log ('   %' + $ph + ' YUKSEK guven (' + $high.Count + ')  - buyuk ihtimalle gercek, incele') 'Red'
    Log ('   %' + $pm + ' ORTA guven   (' + $mid.Count + ')  - suphe var, tarih/yola bak') 'Yellow'
    Log ('   %' + $pl + ' DUSUK guven  (' + $low.Count + ')  - buyuk ihtimalle yanlis alarm (sonda TAM LISTE bolumunde)') 'DarkGray'
    Log '  (Yuzdeler tahmini dagilimdir, kesin dogruluk orani DEGILDIR.)' 'DarkGray'
} else {
    Log '  Hicbir bulgu yok.' 'Green'
}

Log '' 'Gray'
Log '--- BYPASS TESPITI (iz saklama/temizleme, servis ve ayar durumlari) ---' 'Yellow'
if ($script:Sys.Count -eq 0) { Log '   Uyari yok: Prefetch, servisler, olay gunlukleri, USN gunlugu, Defender ayarlari, zamanlanmis gorevler normal gorunuyor.' 'Green' }
foreach ($s in ($script:Sys | Sort-Object -Property Skor -Descending)) {
    $zt = ''
    if ($s.Zaman) { $zt = '  [olay zamani: ' + (Fmt $s.Zaman) + ']' }
    Log ('   [%' + $s.Skor + '] ' + $s.Baslik + $zt) 'Yellow'
    Log ('        ' + $s.Aciklama) 'DarkGray'
    if ($s.Durum) { Log ('        Durum          : ' + $s.Durum) 'DarkGray' }
    if ($s.Degisim) { Log ('        Son elle degisim: ' + (Fmt $s.Degisim)) 'DarkGray' }
}

Log '' 'Gray'
Log '--- YUKSEK GUVENLI BULGULAR ---' 'Red'
if ($high.Count -eq 0) { Log '   Yok.' 'Green' }
foreach ($m in $high) { Show-Item $m 'Red' }

Log '' 'Gray'
Log '--- ORTA GUVENLI BULGULAR ---' 'Yellow'
if ($mid.Count -eq 0) { Log '   Yok.' 'Green' }
foreach ($m in $mid) {
    $d2 = 'DURUYOR'
    if ($m.Var -eq 'Hayir') { $d2 = 'SILINMIS' }
    if ($m.Var -eq 'Bilinmiyor') { $d2 = '?' }
    Log ('   [%' + $m.Skor + '] ' + $m.Ad + ' | ' + $d2 + ' | son: ' + (Fmt $m.Son) + ' | ' + $m.Yol) 'Yellow'
}

Log '' 'Gray'
Log '--- CALISTIRILIP SONRA SILINEN PROGRAMLAR (en yeniden eskiye) ---' 'Magenta'
$delProg = @($ranked | Where-Object { $_.Var -eq 'Hayir' -and $_.Kaynaklar -match 'BAM|Prefetch|UserAssist|Amcache|Shimcache|Jump|Recent|Geri' -and -not $_.Benign } | Sort-Object -Property @{ Expression = 'Son'; Descending = $true })
if ($delProg.Count -eq 0) { Log '   Yok.' 'Green' }
foreach ($m in ($delProg | Select-Object -First 25)) {
    $sz = 'silinme zamani bilinmiyor'
    if ($m.Silinme) { $sz = 'silindi: ' + (Fmt $m.Silinme) }
    Log ('   ' + $m.Ad + '  | son calisma: ' + (Fmt $m.Son) + ' | ' + $sz) 'Magenta'
    Log ('        yer: ' + $m.Yol) 'DarkGray'
}
if ($delProg.Count -gt 25) { Log ('   ... ve ' + ($delProg.Count - 25) + ' tane daha (sonda TAM LISTE bolumunde).') 'DarkGray' }

Log '' 'Gray'
Log '--- GERI DONUSUM KUTUSU ---' 'Cyan'
foreach ($bs2 in $script:BinState) { Log ('   ' + $bs2) 'Gray' }
foreach ($kv in $script:BinEmptied.GetEnumerator()) { Log ('   ' + $kv.Key + ' en son bosaltma/kalici silme (USN kaydi): ' + (Fmt $kv.Value)) 'Cyan' }
if ($script:BinEmptied.Count -eq 0) { Log '   USN gunlugunde kutu bosaltma kaydi bulunamadi (kayit eski/yok olabilir).' 'DarkGray' }
$binX = @($script:BinItems | Where-Object { $_.Orijinal -match '(?i)\.(exe|jar|rar|zip|7z|bat|ps1|scr)$' } | Sort-Object -Property @{ Expression = 'Silinme'; Descending = $true } | Select-Object -First 10)
foreach ($bi in $binX) { Log ('   kutuda: ' + $bi.Orijinal + '  (silindi: ' + (Fmt $bi.Silinme) + ')') 'Gray' }

Log '' 'Gray'
Log '--- SON 30 GUNDE SILINEN exe/jar/zip/rar/7z (USN gunlugu, en yeni 15) ---' 'Cyan'
$ur = @($script:UsnRecent | Where-Object { $_.Ad -notmatch '^(~\$|\$)' } | Sort-Object -Property @{ Expression = 'Zaman'; Descending = $true } | Select-Object -First 15)
if ($ur.Count -eq 0) { Log '   Kayit yok.' 'DarkGray' }
foreach ($u in $ur) { Log ('   ' + (Fmt $u.Zaman) + '  ' + $u.Ad + '  (' + $u.Surucu + ')') 'Gray' }

Log '' 'Gray'
Log '--- USB DEPOLAMA GECMISI ---' 'Cyan'
if ($script:UsbList.Count -eq 0) { Log '   Kayit yok.' 'DarkGray' }
foreach ($u in $script:UsbList) { Log ('   ' + $u.Ad + '  | ilk baglanti: ' + (Fmt $u.Ilk) + ' | son kayit: ' + (Fmt $u.Son)) 'Gray' }

Log '' 'Gray'
Log '--- CALISAN JAVA (Minecraft) ---' 'Cyan'
if ($script:JavaInfo.Count -eq 0) { Log '   Su an calisan Java yok. Hile acikken/Minecraft acikken tekrar calistirirsan enjeksiyon kontrolu de yapilir.' 'DarkGray' }
foreach ($j in $script:JavaInfo) { Log ('   ' + $j) 'Gray' }

Log '' 'Gray'
Log '--- BU ARACIN GOREMEDIGI SEYLER (durust sinirlar) ---' 'DarkGray'
Log '   * Bellekte (RAM) calisan hilelerin tamami: sadece secili process stringleri taranir; korumali (PPL) process ler (csrss, MsMpEng, SgrmBroker) okunamaz. DMA/ikinci PC gibi donanim hileleri gorulmez' 'DarkGray'
Log '   * Adi ve icerigi listede olmayan, obfuscate edilmis ozel (private) hileler' 'DarkGray'
Log '   * Kesin silinme zamani: sadece USN gunlugunde kaydi varsa bulunur (gunluk eskirse kaybolur)' 'DarkGray'
Log '   * Bu bir kanit degil, incelenecek ipuclari listesidir; dosyayi acip elle dogrula.' 'DarkGray'

# tam liste sadece rapor dosyasina
Log '' 'Gray' $true
Log '=================== TAM LISTE (tum bulgular) ===================' 'Gray' $true
foreach ($m in $ranked) { Show-Item $m 'Gray' $true }
Log '' 'Gray' $true
Log '=================== SON 30 GUN SILINENLER (USN, tumu) ===================' 'Gray' $true
foreach ($u in ($script:UsnRecent | Sort-Object -Property @{ Expression = 'Zaman'; Descending = $true } | Select-Object -First 300)) { Log ('   ' + (Fmt $u.Zaman) + '  ' + $u.Ad + '  (' + $u.Surucu + ')') 'Gray' $true }

if ($script:StepName) { [void]$script:StepTimes.Add([pscustomobject]@{ Ad = $script:StepName; Sn = [int]((Get-Date) - $script:StepT0).TotalSeconds }) }
Log '' 'Gray'
Log 'Adim sureleri (en uzundan):' 'Cyan'
foreach ($stt in @($script:StepTimes | Sort-Object Sn -Descending | Select-Object -First 12)) {
    $stn = [string]$stt.Ad
    if ($stn.Length -gt 95) { $stn = $stn.Substring(0, 95) }
    Log ('   ' + $stt.Sn + ' sn   ' + $stn) 'Gray'
}
$el = [int]((Get-Date) - $Started).TotalSeconds
Log '' 'Gray'
Log ('Tarama suresi: ' + $el + ' sn.') 'Cyan'

Show-ObfSummary
$dBin = New-Object System.Collections.Generic.List[object]
foreach ($dx in @($script:BinSkipped)) { if ($dx) { [void]$dBin.Add($dx) } }
foreach ($dx in $script:BinFastList) { [void]$dBin.Add($dx) }
$dCfg = @($script:CfgSkipped)
if (($dBin.Count + $dCfg.Count) -gt 0) {
    function Scan-BinDeferred($bf) {
        $pth = $bf.FullName
        if ((Get-Zone $pth) -eq 'system') { return }
        if ($bf.Name.ToLower() -match $knownNat) { return }
        if ($bf.Length -gt 12582912 -and (Test-Signed $pth)) { return }
        $b = $null
        try { $b = [IO.File]::ReadAllBytes($pth) } catch { return }
        if ($null -eq $b) { return }
        $t = [Text.Encoding]::GetEncoding(28591).GetString($b)
        $isJni = Has-Any $t @('JNI_GetCreatedJavaVMs', 'GetCreatedJavaVMs', 'jvmtiEnv', 'AttachCurrentThread')
        $isMc = Has-Any $t @('net/minecraft/client', 'net.minecraft.client', 'class_310', 'class_746', 'Lnet/minecraft/', 'net/minecraft/class_', 'com/mojang/blaze3d')
        $isInj = ((Has-Any $t @('WriteProcessMemory')) -and (Has-Any $t @('CreateRemoteThread', 'NtCreateThreadEx', 'RtlCreateUserThread', 'QueueUserAPC', 'SetWindowsHookEx')) -and (Has-Any $t @('javaw', 'java.exe', 'Minecraft') $true))
        $terms = @{}
        $brands = @{}
        Get-Terms $t $terms
        Get-Brands $t $brands
        if ($b.Length -lt 8388608) {
            $tu = [Text.Encoding]::Unicode.GetString($b)
            Get-Terms $tu $terms
            Get-Brands $tu $brands
        }
        $tk = @($terms.Keys)
        $bk = @($brands.Keys)
        $sc = 0
        $why = New-Object System.Collections.Generic.List[string]
        if ($tk.Count -ge 3) { $sc += 70 } elseif ($tk.Count -eq 2) { $sc += 50 } elseif ($tk.Count -eq 1) { $sc += 25 }
        if ($tk.Count -gt 0) { [void]$why.Add('icerikte hile modulu stringleri: ' + ($tk -join ', ')) }
        if ($bk.Count -gt 0) { $sc += 35; [void]$why.Add('icerikte bilinen hile istemcisi ismi: ' + ($bk -join ', ')) }
        if ($isJni -and $isMc) { $sc += 40; [void]$why.Add('Minecraft sinif adlari + JNI/JVMTI: Java disindan oyuna baglanan program/DLL') }
        if ($isInj) { $sc += 45; [void]$why.Add('enjektor belirtileri (WriteProcessMemory + uzak thread + javaw/Minecraft)') }
        $pk = Get-PackInfo $b
        if ($pk.Reason) { $sc += $pk.Bonus; [void]$why.Add($pk.Reason) }
        if ($sc -lt 25) { return }
        $sig = Test-Signed $pth
        if ($pk.Reason -and -not $sig) { Add-ObfNote $pth $pk.Reason }
        if ($sig -and $tk.Count -lt 3) { return }
        $sg = 'imzasiz'
        if ($sig) { $sg = 'imzali' }
        Add-F -Kaynak 'Dosya icerik taramasi (exe/dll, sonradan)' -Ad $bf.Name.ToLower() -Yol $pth -Skor ([Math]::Min(100, $sc)) -Son $bf.LastWriteTime -Ilk $bf.CreationTime -Var 'Evet' -Not (($why -join '; ') + ' | ' + $sg + ' | icerik: dosyanin ham baytlari tam modda tarandi')
    }
    function Scan-CfgDeferred($cf) {
        $ct = $null
        try { $ct = [IO.File]::ReadAllText($cf.FullName) } catch { return }
        if (-not $ct) { return }
        $terms = @{}
        $brands = @{}
        Get-Terms $ct $terms
        Get-Brands $ct $brands
        $tk = @($terms.Keys)
        $bk = @($brands.Keys)
        if ($cf.Name -like 'TestHile*') { Write-Host ('   [test dosyasi] ' + $cf.FullName + ' -> ' + $tk.Count + ' modul ismi bulundu') -ForegroundColor Cyan }
        $sc = 0
        if ($tk.Count -ge 3) { $sc = 60 } elseif ($tk.Count -eq 2) { $sc = 45 }
        if ($bk.Count -gt 0) { $sc += 35 }
        if ($sc -lt 35) { return }
        $nt = 'ayar dosyasi icinde'
        if ($tk.Count -gt 0) { $nt = $nt + ' hile modulu isimleri: ' + ($tk -join ', ') }
        if ($bk.Count -gt 0) { $nt = $nt + ' | istemci ismi: ' + ($bk -join ', ') }
        Add-F -Kaynak 'Ayar dosyasi icerik taramasi (sonradan)' -Ad $cf.Name.ToLower() -Yol $cf.FullName -Skor ([Math]::Min(100, $sc)) -Son $cf.LastWriteTime -Ilk $cf.CreationTime -Var 'Evet' -Not ($nt + ' | hile istemcileri modul ayarlarini boyle dosyalara yazar; ayri bir mesru program da olabilir')
    }
    Log '' 'Gray'
    Log ('Sure siniri nedeniyle ATLANAN / HIZLI MODDA gecilen dosyalar: ' + $dBin.Count + ' exe/dll, ' + $dCfg.Count + ' ayar/metin dosyasi.') 'Yellow'
    $dAns = Read-Host 'Simdi bunlar da (sure siniri olmadan) taransin mi? Birkac dakika surebilir (E/H)'
    if ($dAns -match '^[eE]') {
        Start-Sec
        $dSw = [Diagnostics.Stopwatch]::StartNew()
        $dI = 0
        foreach ($dx in $dBin) {
            $dI++
            Set-Frac ($dI / [Math]::Max(1, $dBin.Count)) ('exe/dll (sonradan) ' + $dI + '/' + $dBin.Count)
            if (($dI % 25) -eq 0 -or $dI -eq $dBin.Count) { Write-Host ('   exe/dll (sonradan) ilerleme: ' + $dI + '/' + $dBin.Count + ' (' + [int]$dSw.Elapsed.TotalSeconds + ' sn)') -ForegroundColor DarkGray }
            try { Scan-BinDeferred $dx } catch {}
        }
        $dI = 0
        foreach ($dx in $dCfg) {
            $dI++
            Set-Frac ($dI / [Math]::Max(1, $dCfg.Count)) ('ayar dosyasi (sonradan) ' + $dI + '/' + $dCfg.Count)
            if (($dI % 200) -eq 0 -or $dI -eq $dCfg.Count) { Write-Host ('   ayar dosyasi (sonradan) ilerleme: ' + $dI + '/' + $dCfg.Count + ' (' + [int]$dSw.Elapsed.TotalSeconds + ' sn)') -ForegroundColor DarkGray }
            try { Scan-CfgDeferred $dx } catch {}
        }
        Log '' 'Gray'
        Log 'SONRADAN TARANAN DOSYALARIN SONUCU:' 'Cyan'
        Show-Section
    } else {
        Log 'Atlanan dosyalar taranmadi.' 'DarkGray'
    }
}
if (($dBin.Count + $dCfg.Count) -eq 0) { Log 'Sure siniri nedeniyle atlanan dosya yok, bu yuzden atlananlari tarama sorusu cikmadi.' 'DarkGray' }
Log '' 'Gray'
Close-Bar
$avAns = Read-Host 'TUM DISKTE hile avi (calistirilmamis / yeri bilinmeyen dosyalar dahil) da yapilsin mi? Birkac dakika surer (E/H)'
if ($avAns -match '^[eE]') { Invoke-Hunt }
if ($PSCommandPath) { Write-Host ''; Read-Host 'Bitti. Kapatmak icin Enter a bas' | Out-Null }
