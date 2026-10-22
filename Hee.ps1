# Hee v3.1 FINAL - Windows / FiveM performance settings (single file, dashboard-style GUI + key screen)
# Run: powershell -ep bypass -file "Hee.ps1"   (auto-elevates to Administrator)
# Every registry / power / TCP change is recorded the first time it is touched -> "RESTORE ALL" puts the originals back.
# v3.0: hardware-aware recommendations (RAM / SSD / laptop), live [ACTIVE] status on every card, auto-detected FiveM builds,
#       restore point before apply, selectable timer resolution, FiveM cache cleaner, exact TCP / power restore, reboot prompt.

param([switch]$MKElevated)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -MKElevated' -f $PSCommandPath) -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$MKVersion = '3.1 FINAL'

# UI font: 'Auto' = best installed Thai-friendly clean font (Noto Sans Thai / IBM Plex Sans Thai / Sarabun -> Leelawadee UI -> Tahoma).
# Or type any installed font name, e.g. 'Sarabun', 'Noto Sans Thai', 'Segoe UI'.
$UIFontName = 'Auto'

# ---------------------------------------------------------------- UI text / branding (edit freely)
$UI = @{
    Brand = 'Hee'; BrandSub = 'SETTING HEE V1.0'; Version = '1.0.0'
    Tag1 = 'เครื่องมือที่จะทำให้คอมของคุณ'; Tag2 = '“แรงขึ้น ลื่นขึ้น เล่นได้มากขึ้น”'; Credit = 'By. Hee'
    StatusTitle = 'สถานะระบบ'; Home = 'หน้าแรก'; LogNav = 'บันทึกการทำงาน'; ResetNav = 'คืนค่าทั้งหมด'
    Welcome = 'ยินดีต้อนรับ'; UserName = $env:USERNAME; UserQuote = '“เล่นลื่นกว่าเดิม”'
    VerText = 'เวอร์ชันล่าสุด'; F1 = 'เล่นลื่น'; F2 = 'เครื่องเสถียร'; F3 = 'ปลอดภัย'; F4 = 'ประสิทธิภาพสูง'
    Restore = 'คืนค่าเดิม'; Active = 'ใช้งานอยู่'; Choose = 'เลือกโหมดที่ต้องการใช้งาน'; Search = 'ค้นหาโหมด...'
    PromoA = 'เลือกโหมดที่ใช่'; PromoB = 'สำหรับสไตล์ที่เป็นคุณ'; PromoC = 'ทุกการตั้งค่า... เพื่อประสิทธิภาพที่ดีกว่า'
    SelRec = 'เลือกที่แนะนำ'; Apply = 'เปิดใช้งานโหมดที่เลือก'; ApplyBtn = 'นำไปใช้'; LogTitle = 'บันทึกการทำงาน'
    StReady = 'พร้อมใช้งาน'; StOpt = 'ปรับแต่งแล้ว'; StBusy = 'กำลังทำงาน...'
    Ok = 'ตกลง'; Cancel = 'ยกเลิก'; Restart = 'รีสตาร์ท'; Later = 'ไว้ทีหลัง'
    NoneTtl = 'ยังไม่ได้เลือกโหมด'; NoneMsg = 'กรุณาเลือกอย่างน้อย 1 โหมดก่อน โดยคลิกที่การ์ดโหมด'
    ApplyTtl = 'เปิดใช้งานโหมด'; ConfirmApply = "จะเปิดใช้งาน {0} โหมด ({1} รายการปรับแต่ง)?`r`n`r`nค่าเดิมจะถูกบันทึกไว้ก่อน กดคืนค่าเดิมได้ทุกเมื่อ"
    DoneTtl = 'เสร็จแล้ว'; DoneMsg = "ปรับแต่งสำเร็จ {0} รายการ, ล้มเหลว {1} รายการ`r`n`r`nต้องรีสตาร์ท Windows เพื่อให้มีผลทั้งหมด รีสตาร์ทตอนนี้เลยไหม?"
    RestoreTtl = 'คืนค่าเดิม'; RestoreDoneTtl = 'คืนค่าเสร็จแล้ว'
    ConfirmRestoreMode = 'จะคืนค่าเดิมของ "{0}" ใช่ไหม?'
    NothingToRestore = 'โหมดนี้ยังไม่มีค่าที่ต้องคืน (ยังไม่เคยปรับแต่ง หรือเป็นรายการแบบครั้งเดียว)'
    RestoredMode = "คืนค่าเดิมของโหมดนี้แล้ว`r`n`r`nรีสตาร์ท Windows ตอนนี้เลยไหม?"
    ConfirmRestoreAll = 'จะคืนค่าทุกอย่างที่โปรแกรมเปลี่ยนไปกลับเป็นค่าเดิมทั้งหมดใช่ไหม?'
    RestoredAll = "คืนค่าทั้งหมดเรียบร้อย`r`n`r`nรีสตาร์ท Windows ตอนนี้เลยไหม?"
    MenuHead = 'ตั้งค่าในโหมด:'; MenuEnable = 'เปิดใช้รายการนี้'; MenuReset = 'ใช้ค่าเริ่มต้นของเครื่องนี้'
}
$DataDir   = Join-Path $env:ProgramData 'MostKill'
$StateFile = Join-Path $DataDir 'state.json'
$LogFile   = Join-Path $DataDir 'log.txt'
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
$CCS = 'HKLM:\SYSTEM\CurrentControlSet'
$IFEO = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
$script:Reg = @{}
$script:X   = @{}
$script:logBox = $null
$script:Checkpointed = $false
$script:CurMode = $null

# ---------------------------------------------------------------- helpers
function Log($m) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
    try { Add-Content -Path $LogFile -Value $line } catch {}
    if ($script:logBox) { $script:logBox.AppendText($line + "`r`n"); [System.Windows.Forms.Application]::DoEvents() }
}
try { if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 524288) { Remove-Item $LogFile -Force } } catch {}

function ConvertTo-Hash($o) {
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hash $p.Value }
        return $h
    }
    if ($o -is [System.Array]) { return ,@($o | ForEach-Object { ConvertTo-Hash $_ }) }
    return $o
}

function Save-State {
    @{ reg = $script:Reg; x = $script:X } | ConvertTo-Json -Depth 8 | Set-Content -Path $StateFile -Encoding UTF8
}

function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
    $key = "$Path|$Name"
    if (-not $script:Reg.ContainsKey($key)) {
        $o = @{ existed = $false; value = $null; kind = $null; own = $script:CurMode }
        try {
            $it = Get-Item -LiteralPath $Path -ErrorAction Stop
            if ($it.GetValueNames() -contains $Name) {
                $o.existed = $true
                $o.value   = $it.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
                $o.kind    = [string]$it.GetValueKind($Name)
            }
        } catch {}
        $script:Reg[$key] = $o
    }
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type $Type -Force
}

# read-only helpers used by the [ACTIVE] status checks
function Get-RegVal($Path, $Name) {
    try { return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}
function Test-Reg($Path, $Name, $Value) {
    $x = Get-RegVal $Path $Name
    return ($null -ne $x -and ([string]$x) -eq ([string]$Value))
}

function Get-ActivePlan {
    $o = (powercfg /getactivescheme) -join ' '
    if ($o -match '([0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})') { return $Matches[1] }
}

# AC power setting with the original value remembered (restored exactly)
function Set-PowerAc($Guid, $Sub, $Setting, $Value) {
    if (-not $script:X.ContainsKey('pwr')) { $script:X['pwr'] = @() }
    $key = "$Guid|$Sub|$Setting"
    $have = @($script:X['pwr'] | Where-Object { $_.k -eq $key }).Count -gt 0
    if (-not $have) {
        $q = (powercfg -q $Guid $Sub $Setting) -join "`n"
        if ($q -match 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)') {
            $script:X['pwr'] = @($script:X['pwr']) + @(, @{ k = $key; guid = $Guid; sub = $Sub; set = $Setting; ac = [Convert]::ToInt32($Matches[1], 16) })
        }
    }
    powercfg -setacvalueindex $Guid $Sub $Setting $Value | Out-Null
}

# one System Restore point per session, before the first apply
function New-Checkpoint {
    if ($script:Checkpointed) { return }
    $script:Checkpointed = $true
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Hee before apply' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Log 'System restore point created.'
    } catch { Log ('Restore point skipped: ' + $_.Exception.Message) }
}

if (Test-Path $StateFile) {
    try {
        $h = ConvertTo-Hash (Get-Content $StateFile -Raw | ConvertFrom-Json)
        if ($h.reg) { $script:Reg = $h.reg }
        if ($h.x)   { $script:X   = $h.x }
    } catch {}
}

# ---------------------------------------------------------------- hardware detection (drives the Recommended selection)
$RamGB = 8; $IsLaptop = $false; $IsSSD = $true
$CpuName = 'CPU ?'; $GpuName = 'GPU ?'; $OsName = 'Windows'
try { $RamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch {}
try { $CpuName = ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace '\s+', ' ').Trim() } catch {}
try { $GpuName = (@(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Remote|Virtual' } | ForEach-Object { $_.Name }) -join ' + ') } catch {}
try { $OsName = (Get-CimInstance Win32_OperatingSystem).Caption } catch {}
try { $IsLaptop = @((Get-CimInstance Win32_SystemEnclosure).ChassisTypes | Where-Object { $_ -in 8,9,10,11,12,14,18,21,30,31,32 }).Count -gt 0 } catch {}
try {
    $pd = Get-Partition -DriveLetter ($env:SystemDrive.Substring(0, 1)) -ErrorAction Stop | Get-Disk | Get-PhysicalDisk -ErrorAction Stop | Select-Object -First 1
    if ($pd -and $pd.MediaType -eq 'HDD') { $IsSSD = $false }
} catch {}

# every FiveM / GTA executable we can find (installed builds are detected automatically)
function Get-FiveMExes {
    $l = New-Object System.Collections.ArrayList
    foreach ($e in 'FiveM.exe', 'FiveM_GTAProcess.exe', 'FiveM_b3258_GTAProcess.exe', 'GTA5.exe') { [void]$l.Add($e) }
    try {
        $app = Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.app'
        if (Test-Path $app) {
            Get-ChildItem -LiteralPath $app -Filter 'FiveM*_GTAProcess.exe' -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($l -notcontains $_.Name) { [void]$l.Add($_.Name) }
            }
        }
    } catch {}
    return @($l)
}

# FiveM / GTA executables with their full path (for the Windows "high performance GPU" preference)
$GpuPrefKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
function Get-GpuPrefExes {
    $l = New-Object System.Collections.ArrayList
    try {
        $root = Join-Path $env:LOCALAPPDATA 'FiveM'
        $f = Join-Path $root 'FiveM.exe'
        if (Test-Path -LiteralPath $f) { [void]$l.Add($f) }
        $app = Join-Path $root 'FiveM.app'
        if (Test-Path -LiteralPath $app) {
            Get-ChildItem -LiteralPath $app -Filter 'FiveM*_GTAProcess.exe' -File -ErrorAction SilentlyContinue | ForEach-Object { [void]$l.Add($_.FullName) }
        }
    } catch {}
    foreach ($rk in 'HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto V', 'HKLM:\SOFTWARE\Rockstar Games\Grand Theft Auto V') {
        try {
            $d = (Get-ItemProperty -LiteralPath $rk -ErrorAction Stop).InstallFolder
            if ($d) { $g = Join-Path $d 'GTA5.exe'; if ((Test-Path -LiteralPath $g) -and ($l -notcontains $g)) { [void]$l.Add($g) } }
        } catch {}
    }
    return @($l)
}

# ---------------------------------------------------------------- timer resolution service source
$TimerCs = @'
using System;
using System.Runtime.InteropServices;
using System.ServiceProcess;
public class MostKillTimer : ServiceBase {
    [DllImport("ntdll.dll")] static extern int NtSetTimerResolution(uint Desired, bool Set, out uint Current);
    public MostKillTimer() { ServiceName = "MostKillTimer"; }
    protected override void OnStart(string[] a) { uint c; NtSetTimerResolution(__RES__, true, out c); }
    protected override void OnStop() { uint c; NtSetTimerResolution(__RES__, false, out c); }
    public static void Main() { ServiceBase.Run(new MostKillTimer()); }
}
'@

# ---------------------------------------------------------------- NetFade helpers (personal network profile)
function Get-NfState { if (-not $script:X.ContainsKey('nfx')) { $script:X['nfx'] = @{} }; return $script:X['nfx'] }
function Get-NfAdapters { return @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }) }
function Get-NfNicKeys {
    $ck = "$CCS\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    $up = @(Get-NfAdapters | ForEach-Object { ([string]$_.InterfaceGuid).ToLower() })
    $all = @(Get-ChildItem -LiteralPath $ck -ErrorAction SilentlyContinue | ForEach-Object {
        $pp = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
        if ($pp -and $pp.PSObject.Properties['*SpeedDuplex']) { [pscustomobject]@{ Path = $_.PSPath; Props = $pp; Guid = ([string]$pp.NetCfgInstanceId).ToLower() } }
    })
    $mine = @($all | Where-Object { $up -contains $_.Guid })
    if ($mine.Count -gt 0) { return $mine }
    return $all
}
function Restore-NfState {
    if (-not $script:X.ContainsKey('nfx')) { return }
    $nf = $script:X['nfx']
    if ($nf.ContainsKey('glob')) {
        foreach ($p in @($nf['glob'].Keys)) {
            try { $a = @{}; $a[$p] = [string]$nf['glob'][$p]; Set-NetOffloadGlobalSetting @a -ErrorAction Stop } catch { Log ('NetFade restore (global ' + $p + ') failed: ' + $_.Exception.Message) }
        }
    }
    if ($nf.ContainsKey('rss')) {
        foreach ($n in @($nf['rss'].Keys)) {
            $r = $nf['rss'][$n]
            try {
                Set-NetAdapterRss -Name $n -Enabled ([bool]$r['en']) -NoRestart -ErrorAction Stop
                if ([bool]$r['en']) { Set-NetAdapterRss -Name $n -NumberOfReceiveQueues ([int]$r['q']) -Profile ([string]$r['prof']) -BaseProcessorNumber ([int]$r['base']) -MaxProcessorNumber ([int]$r['max']) -MaxProcessors ([int]$r['mp']) -NoRestart -ErrorAction Stop }
            } catch { Log ('NetFade restore (RSS ' + $n + ') failed: ' + $_.Exception.Message) }
        }
    }
    if ($nf.ContainsKey('ip')) {
        foreach ($idx in @($nf['ip'].Keys)) {
            foreach ($p in @($nf['ip'][$idx].Keys)) {
                try { $a = @{ InterfaceIndex = [int]$idx; AddressFamily = 'IPv4' }; $a[$p] = $nf['ip'][$idx][$p]; Set-NetIPInterface @a -ErrorAction Stop } catch { Log ('NetFade restore (IP ' + $p + ') failed: ' + $_.Exception.Message) }
            }
        }
    }
    $script:X.Remove('nfx')
}

# ---------------------------------------------------------------- NVIDIA helpers
function Get-NvKeys {
    $ck = "$CCS\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    @(Get-ChildItem -LiteralPath $ck -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
        $pp = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
        if ($pp -and $pp.DriverDesc -match 'NVIDIA') { [pscustomobject]@{ Path = $_.PSPath; Props = $pp } }
    })
}
function Get-NvPnpIds {
    @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'NVIDIA' -and $_.PNPDeviceID } | ForEach-Object { [string]$_.PNPDeviceID })
}

# ---------------------------------------------------------------- tweak definitions
# G = category, Rec = recommended, Opts = selectable value, Check = returns $true when already active
$Tweaks = @(

# ===== CPU / Scheduler
@{ G='CPU / Scheduler'; Name='Win32PrioritySeparation'; Rec=$true
   Desc='Foreground quantum/boost. 0x26 = Kai Prime, 0x2A = aironplus, 0x16 = ASPAS, 0x28 = short fixed, 0x02 = Windows default.'
   Opts=[ordered]@{ '0x26 (Kai Prime)'=0x26; '0x2A (aironplus)'=0x2A; '0x16 (ASPAS)'=0x16; '0x28 (short fixed)'=0x28; '0x02 (default)'=0x02 }
   Check={ $x = Get-RegVal "$CCS\Control\PriorityControl" 'Win32PrioritySeparation'; ($null -ne $x) -and ([int]$x -ne 2) }
   Apply={ param($v) Set-Reg "$CCS\Control\PriorityControl" 'Win32PrioritySeparation' ([int]$v) } },

@{ G='CPU / Scheduler'; Name='MMCSS + Games profile'; Rec=$true
   Desc='SystemResponsiveness 0, NetworkThrottlingIndex off, Games task: GPU prio 8, prio 6, High scheduling/SFIO.'
   Check={ $sp = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; (Test-Reg $sp 'SystemResponsiveness' 0) -and (Test-Reg "$sp\Tasks\Games" 'GPU Priority' 8) }
   Apply={
       $sp = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
       Set-Reg $sp 'SystemResponsiveness' 0
       Set-Reg $sp 'NetworkThrottlingIndex' -1
       $g = "$sp\Tasks\Games"
       Set-Reg $g 'Affinity' 0
       Set-Reg $g 'Background Only' 'False' 'String'
       Set-Reg $g 'Clock Rate' 10000
       Set-Reg $g 'GPU Priority' 8
       Set-Reg $g 'Latency Sensitive' 'True' 'String'
       Set-Reg $g 'Priority' 6
       Set-Reg $g 'Scheduling Category' 'High' 'String'
       Set-Reg $g 'SFIO Priority' 'High' 'String'
   } },

@{ G='CPU / Scheduler'; Name='FiveM / GTA process priority = High'; Rec=$true
   Desc='Permanent CpuPriorityClass=3 (IFEO PerfOptions) for FiveM.exe, GTA5.exe and every installed GTAProcess build (auto-detected).'
   Check={ Test-Reg "$IFEO\FiveM.exe\PerfOptions" 'CpuPriorityClass' 3 }
   Apply={
       foreach ($e in (Get-FiveMExes)) {
           Set-Reg "$IFEO\$e\PerfOptions" 'CpuPriorityClass' 3
       }
   } },

@{ G='CPU / Scheduler'; Name='Global timer resolution requests'; Rec=$true
   Desc='GlobalTimerResolutionRequests=1 so a process timer request affects the whole system.'
   Check={ Test-Reg "$CCS\Control\Session Manager\kernel" 'GlobalTimerResolutionRequests' 1 }
   Apply={ Set-Reg "$CCS\Control\Session Manager\kernel" 'GlobalTimerResolutionRequests' 1 } },

@{ G='CPU / Scheduler'; Name='Timer Resolution service'; Rec=$true
   Desc='Compiles a tiny service (csc.exe) that holds the system timer at the chosen resolution. 0.5 ms is the lowest most CPUs allow. Removed by Restore.'
   Opts=[ordered]@{ '0.5 ms'=5000; '0.75 ms'=7500; '1.0 ms'=10000 }
   Check={ $s = Get-Service -Name 'MostKillTimer' -ErrorAction SilentlyContinue; [bool]($s -and $s.Status -eq 'Running') }
   Apply={ param($v)
       $res = 5000; if ($v) { $res = [int]$v }
       $csc = "$env:windir\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
       if (-not (Test-Path $csc)) { throw 'csc.exe not found (.NET Framework 4 required)' }
       $cs  = Join-Path $DataDir 'MostKillTimer.cs'
       $exe = Join-Path $DataDir 'MostKillTimer.exe'
       if (Get-Service -Name 'MostKillTimer' -ErrorAction SilentlyContinue) {
           Stop-Service 'MostKillTimer' -Force -ErrorAction SilentlyContinue
           sc.exe delete MostKillTimer | Out-Null
           Start-Sleep -Milliseconds 1200
       }
       Remove-Item $exe -Force -ErrorAction SilentlyContinue
       Set-Content -Path $cs -Value $TimerCs.Replace('__RES__', [string]$res) -Encoding ASCII
       & $csc /nologo /target:exe "/out:$exe" /r:System.ServiceProcess.dll $cs | Out-Null
       if (-not (Test-Path $exe)) { throw 'compile failed' }
       New-Service -Name 'MostKillTimer' -BinaryPathName ('"{0}"' -f $exe) -DisplayName 'Hee Timer Resolution' -StartupType Automatic | Out-Null
       Start-Service 'MostKillTimer'
       Set-Reg "$CCS\Control\Session Manager\kernel" 'GlobalTimerResolutionRequests' 1
       $script:X['timer'] = $true
   } },

@{ G='CPU / Scheduler'; Name='csrss.exe (input) priority High'; Rec=$false
   Desc='CpuPriorityClass 3 + IoPriority 3 for csrss.exe so input threads run ahead of background work.'
   Check={ Test-Reg "$IFEO\csrss.exe\PerfOptions" 'CpuPriorityClass' 3 }
   Apply={
       $k = "$IFEO\csrss.exe\PerfOptions"
       Set-Reg $k 'CpuPriorityClass' 3
       Set-Reg $k 'IoPriority' 3
   } },

@{ G='CPU / Scheduler'; Name='Boot timer tweaks (bcdedit)'; Rec=$false
   Desc='disabledynamictick yes + useplatformclock no. Needs reboot; reverted with /deletevalue.'
   Apply={
       bcdedit /set disabledynamictick yes | Out-Null
       bcdedit /set useplatformclock no | Out-Null
       $script:X['bcd'] = @('disabledynamictick','useplatformclock')
   } },

# ===== Power
@{ G='Power'; Name='Ultimate Performance power plan'; Rec=$false
   Desc='Activates (or creates) Ultimate Performance. Previous plan is remembered. Laptop: uses more battery.'
   Check={ ((powercfg /getactivescheme) -join ' ') -match 'Ultimate' }
   Apply={
       if (-not $script:X.ContainsKey('prevPlan')) { $script:X['prevPlan'] = Get-ActivePlan }
       $g = $null
       $list = (powercfg /l) -join "`n"
       if ($list -match '([0-9a-fA-F-]{36})\s+\(Ultimate Performance\)') { $g = $Matches[1] }
       else {
           $o = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61) -join ' '
           if ($o -match '([0-9a-fA-F-]{36})') { $g = $Matches[1] }
       }
       if ($g) { powercfg /setactive $g | Out-Null } else { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null }
   } },

@{ G='Power'; Name='No core parking + min CPU 100% (AC)'; Rec=$false
   Desc='Minimum cores 100% and minimum processor state 100% on the active plan while plugged in. Higher idle power / heat.'
   Apply={
       $g = Get-ActivePlan
       Set-PowerAc $g 'SUB_PROCESSOR' 'CPMINCORES' 100
       Set-PowerAc $g 'SUB_PROCESSOR' 'PROCTHROTTLEMIN' 100
       powercfg /setactive $g | Out-Null
   } },

@{ G='Power'; Name='Power throttling off + timer coalescing off'; Rec=$true
   Desc='PowerThrottlingOff=1, CoalescingTimerInterval=0, PerfEnablePackageIdle=0.'
   Check={ Test-Reg "$CCS\Control\Power\PowerThrottling" 'PowerThrottlingOff' 1 }
   Apply={
       Set-Reg "$CCS\Control\Power\PowerThrottling" 'PowerThrottlingOff' 1
       Set-Reg "$CCS\Control\Session Manager\Power" 'CoalescingTimerInterval' 0
       Set-Reg "$CCS\Control\Session Manager\Throttle" 'PerfEnablePackageIdle' 0
   } },

@{ G='Power'; Name='USB selective suspend off'; Rec=$true
   Desc='DisableSelectiveSuspend=1 so mouse/keyboard never power down.'
   Check={ Test-Reg "$CCS\Services\USB" 'DisableSelectiveSuspend' 1 }
   Apply={ Set-Reg "$CCS\Services\USB" 'DisableSelectiveSuspend' 1 } },

@{ G='Power'; Name='Fast Startup off (real cold boot)'; Rec=$false
   Desc='HiberbootEnabled=0 so Restart/Shutdown fully reload the kernel and timer/boot tweaks always take effect. Slightly slower boot on HDD.'
   Check={ Test-Reg "$CCS\Control\Session Manager\Power" 'HiberbootEnabled' 0 }
   Apply={ Set-Reg "$CCS\Control\Session Manager\Power" 'HiberbootEnabled' 0 } },

# ===== Memory / Disk
@{ G='Memory / Disk'; Name='Keep kernel in RAM'; Rec=($RamGB -ge 16)
   Desc="DisablePagingExecutive=1, LargeSystemCache=0. Recommended from 16 GB RAM (this PC: $RamGB GB)."
   Check={ Test-Reg "$CCS\Control\Session Manager\Memory Management" 'DisablePagingExecutive' 1 }
   Apply={
       $k = "$CCS\Control\Session Manager\Memory Management"
       Set-Reg $k 'DisablePagingExecutive' 1
       Set-Reg $k 'LargeSystemCache' 0
   } },

@{ G='Memory / Disk'; Name='NTFS tweaks'; Rec=$true
   Desc='No 8.3 names, no last-access updates, NtfsMemoryUsage=2.'
   Check={ Test-Reg "$CCS\Control\FileSystem" 'NtfsMemoryUsage' 2 }
   Apply={
       $k = "$CCS\Control\FileSystem"
       Set-Reg $k 'NtfsDisable8dot3NameCreation' 1
       Set-Reg $k 'NtfsDisableLastAccessUpdate' 1
       Set-Reg $k 'NtfsMemoryUsage' 2
   } },

@{ G='Memory / Disk'; Name='Prefetch / SysMain off (SSD)'; Rec=$IsSSD
   Desc=('EnablePrefetcher/Superfetch 0 and SysMain service disabled. Only worth it on SSD (detected system drive: ' + $(if ($IsSSD) { 'SSD/NVMe' } else { 'HDD - not recommended' }) + ').')
   Check={ Test-Reg "$CCS\Control\Session Manager\Memory Management\PrefetchParameters" 'EnablePrefetcher' 0 }
   Apply={
       $k = "$CCS\Control\Session Manager\Memory Management\PrefetchParameters"
       Set-Reg $k 'EnablePrefetcher' 0
       Set-Reg $k 'EnableSuperfetch' 0
       $svc = Get-CimInstance Win32_Service -Filter "Name='SysMain'"
       if ($svc) {
           if (-not $script:X.ContainsKey('svc')) { $script:X['svc'] = @{} }
           if (-not $script:X['svc'].ContainsKey('SysMain')) { $script:X['svc']['SysMain'] = $svc.StartMode }
           Stop-Service SysMain -Force -ErrorAction SilentlyContinue
           Set-Service SysMain -StartupType Disabled
       }
   } },

# ===== Input
@{ G='Input'; Name='Keyboard + mouse data queue size'; Rec=$true
   Desc='KeyboardDataQueueSize / MouseDataQueueSize. 20 is the common value (Kai/ASPAS/aironplus).'
   Opts=[ordered]@{ '20'=20; '16'=16; '30'=30; '50'=50 }
   Check={ Test-Reg "$CCS\Services\mouclass\Parameters" 'MouseDataQueueSize' 20 }
   Apply={ param($v)
       Set-Reg "$CCS\Services\kbdclass\Parameters" 'KeyboardDataQueueSize' ([int]$v)
       Set-Reg "$CCS\Services\mouclass\Parameters" 'MouseDataQueueSize' ([int]$v)
   } },

@{ G='Input'; Name='Mouse acceleration off (1:1)'; Rec=$true
   Desc='Enhance pointer precision off: MouseSpeed/Threshold1/Threshold2 = 0 (current user, log off to apply).'
   Check={ (Test-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0') -and (Test-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0') }
   Apply={
       $m = 'HKCU:\Control Panel\Mouse'
       Set-Reg $m 'MouseSpeed' '0' 'String'
       Set-Reg $m 'MouseThreshold1' '0' 'String'
       Set-Reg $m 'MouseThreshold2' '0' 'String'
   } },

# ===== Graphics / Games
@{ G='Graphics / Games'; Name='Game DVR / Game Bar off + FSE behavior'; Rec=$true
   Desc='GameDVR_Enabled 0, FSEBehaviorMode 2, AppCaptureEnabled 0, AllowGameDVR policy 0.'
   Check={ (Test-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0) -and (Test-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0) }
   Apply={
       $g = 'HKCU:\System\GameConfigStore'
       Set-Reg $g 'GameDVR_Enabled' 0
       Set-Reg $g 'GameDVR_FSEBehaviorMode' 2
       Set-Reg $g 'GameDVR_FSEBehavior' 2
       Set-Reg $g 'GameDVR_HonorUserFSEBehaviorMode' 1
       Set-Reg $g 'GameDVR_DXGIHonorFSEWindowsCompatible' 1
       Set-Reg $g 'GameDVR_EFSEFeatureFlags' 0
       Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
       Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
   } },

@{ G='Graphics / Games'; Name='Hardware-accelerated GPU scheduling (HAGS)'; Rec=$false
   Desc='HwSchMode=2. Needs Windows 10 2004+ and a supporting driver (not on LTSC 1809). Test it: helps some GPUs, hurts others.'
   Check={ Test-Reg "$CCS\Control\GraphicsDrivers" 'HwSchMode' 2 }
   Apply={ Set-Reg "$CCS\Control\GraphicsDrivers" 'HwSchMode' 2 } },

@{ G='Graphics / Games'; Name='NVIDIA driver low-latency keys'; Rec=$false
   Desc='LOWLATENCY, Node3DLowLatency, D3PCLatency, vrrCursorMarginUs, VRDirectFlipDPCDelayUs (from aironplus) on NVIDIA adapters only.'
   Apply={
       $ck = "$CCS\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
       $n = 0
       Get-ChildItem -LiteralPath $ck -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
           $pp = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
           if ($pp -and $pp.DriverDesc -match 'NVIDIA') {
               foreach ($name in 'LOWLATENCY','Node3DLowLatency','D3PCLatency','vrrCursorMarginUs','VRDirectFlipDPCDelayUs') {
                   Set-Reg $_.PSPath $name 1
               }
               $n++
           }
       }
       if ($n -eq 0) { Log 'No NVIDIA adapter key found - nothing changed' }
   } },

# ===== Network
@{ G='Network'; Name='Nagle off (per interface)'; Rec=$true
   Desc='TcpAckFrequency=1, TCPNoDelay=1, TcpDelAckTicks=0 on every interface that has an IP.'
   Apply={
       $b = "$CCS\Services\Tcpip\Parameters\Interfaces"
       Get-ChildItem -LiteralPath $b | ForEach-Object {
           $pp = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
           if ($pp -and ($pp.DhcpIPAddress -or $pp.IPAddress)) {
               Set-Reg $_.PSPath 'TcpAckFrequency' 1
               Set-Reg $_.PSPath 'TCPNoDelay' 1
               Set-Reg $_.PSPath 'TcpDelAckTicks' 0
           }
       }
   } },

@{ G='Network'; Name='TCP global (netsh)'; Rec=$true
   Desc='timestamps off, RSS on, nonsackrttresiliency off, ECN off, RSC off, fastopen on, autotuning normal. Original values are saved and restored.'
   Apply={
       if (-not $script:X.ContainsKey('tcp')) {
           try {
               $t = Get-NetTCPSetting -SettingName Internet -ErrorAction Stop
               $script:X['tcp'] = @{ ts = [string]$t.Timestamps; ecn = [string]$t.EcnCapability; au = [string]$t.AutoTuningLevelLocal; nsr = [string]$t.NonSackRttResiliency }
           } catch { Log 'Could not read the current TCP settings (restore will only re-enable RSC)' }
       }
       foreach ($c in 'int tcp set global timestamps=disabled','int tcp set global rss=enabled','int tcp set global nonsackrttresiliency=disabled','int tcp set global ecncapability=disabled','int tcp set global rsc=disabled','int tcp set global fastopen=enabled','int tcp set global autotuninglevel=normal') {
           & netsh ($c -split ' ') | Out-Null
       }
       $script:X['netsh'] = $true
   } },

@{ G='Network'; Name='TCP / DNS registry (conservative)'; Rec=$true
   Desc='TimedWaitDelay 30, MaxUserPort 65534, TTL 64, PMTU on, ICMP redirect off, retransmissions 3, DNS neg-cache 0, QoS NonBestEffortLimit 0.'
   Check={ (Test-Reg "$CCS\Services\Tcpip\Parameters" 'TcpTimedWaitDelay' 30) -and (Test-Reg "$CCS\Services\Tcpip\Parameters" 'MaxUserPort' 65534) }
   Apply={
       $t = "$CCS\Services\Tcpip\Parameters"
       Set-Reg $t 'TcpTimedWaitDelay' 30
       Set-Reg $t 'MaxUserPort' 65534
       Set-Reg $t 'DefaultTTL' 64
       Set-Reg $t 'EnablePMTUDiscovery' 1
       Set-Reg $t 'EnablePMTUBHDetect' 0
       Set-Reg $t 'SackOpts' 1
       Set-Reg $t 'EnableICMPRedirect' 0
       Set-Reg $t 'TcpMaxDataRetransmissions' 3
       Set-Reg "$CCS\Services\Dnscache\Parameters" 'MaxCacheTtl' 3600
       Set-Reg "$CCS\Services\Dnscache\Parameters" 'MaxNegativeCacheTtl' 0
       Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched' 'NonBestEffortLimit' 0
   } },

@{ G='Network'; Name='FiveM QoS (DSCP 46)'; Rec=$true
   Desc='QoS policies for FiveM.exe and every installed GTAProcess build (remote ports 30120-30125), then gpupdate /force.'
   Check={ Test-Path -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\MostKill_FiveM' }
   Apply={
       $apps = New-Object System.Collections.ArrayList
       [void]$apps.Add(@('MostKill_FiveM', 'FiveM.exe', '*'))
       foreach ($e in (Get-FiveMExes)) {
           if ($e -match '^FiveM.*_GTAProcess\.exe$') {
               $pn = switch ($e) {
                   'FiveM_GTAProcess.exe'       { 'MostKill_GTAProcess' }
                   'FiveM_b3258_GTAProcess.exe' { 'MostKill_GTAProcess3258' }
                   default                      { 'MostKill_' + ($e -replace '\.exe$', '' -replace '[^A-Za-z0-9_]', '') }
               }
               [void]$apps.Add(@($pn, $e, '30120:30125'))
           }
       }
       $del = @(); if ($script:X.ContainsKey('delKeys')) { $del = @($script:X['delKeys']) }
       foreach ($a in $apps) {
           $k = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\$($a[0])"
           Set-Reg $k 'Version' '1.0' 'String'
           Set-Reg $k 'Application Name' $a[1] 'String'
           foreach ($n in 'Protocol','Local Port','Local IP','Local IP Prefix Length','Remote IP','Remote IP Prefix Length') { Set-Reg $k $n '*' 'String' }
           Set-Reg $k 'Remote Port' $a[2] 'String'
           Set-Reg $k 'DSCP Value' '46' 'String'
           if ($del -notcontains $k) { $del += $k }
       }
       $script:X['delKeys'] = $del
       Set-Reg "$CCS\Services\Tcpip\QoS" 'Do not use NLA' '1' 'String'
       if ($script:X.ContainsKey('hib')) { if ($script:X['hib']) { powercfg /hibernate on | Out-Null } }
    gpupdate /force | Out-Null
   } },

@{ G='Network'; Name='NIC power-saving off (physical adapters)'; Rec=$true
   Desc='EEE, flow control, interrupt moderation, green ethernet, WoL, selective suspend = 0 (only keys the driver has). Adapters restart.'
   Apply={
       $ck = "$CCS\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
       $want = [ordered]@{ '*EEE'='0'; '*FlowControl'='0'; '*InterruptModeration'='0'; 'EnableGreenEthernet'='0'; 'GigaLite'='0'; 'AdvancedEEE'='0'; 'EEELinkAdvertisement'='0'; 'PowerSavingMode'='0'; 'ULPMode'='0'; '*WakeOnMagicPacket'='0'; '*WakeOnPattern'='0'; '*SelectiveSuspend'='0' }
       $n = 0
       Get-ChildItem -LiteralPath $ck -ErrorAction SilentlyContinue | ForEach-Object {
           $pp = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
           if ($pp -and $pp.PSObject.Properties['*SpeedDuplex']) {
               foreach ($k in $want.Keys) {
                   if ($pp.PSObject.Properties[$k]) { Set-Reg $_.PSPath $k $want[$k] 'String'; $n++ }
               }
           }
       }
       Log "NIC values written: $n - restarting adapters (brief disconnect)"
       Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Restart-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
   } },

# ===== NetFade (personal network profile - values taken from the Network Adapter Tweaker)
@{ G='Network'; Name='NetFade: RSS + global offload'; Rec=$false
   Desc='RSS on (2 queues, NUMAStatic, base CPU 0, max CPU 14, 8 processors), RSC off, TaskOffload off, Chimney off, NetworkDirect on, NetworkDirectAcrossIPSubnets blocked, PacketCoalescingFilter on. Originals are saved and restored.'
   Check={ $g = Get-NetOffloadGlobalSetting -ErrorAction Stop; ([string]$g.ReceiveSegmentCoalescing -eq 'Disabled') -and ([string]$g.TaskOffload -eq 'Disabled') }
   Apply={
       $nf = Get-NfState
       $want = [ordered]@{ ReceiveSideScaling='Enabled'; ReceiveSegmentCoalescing='Disabled'; Chimney='Disabled'; TaskOffload='Disabled'; NetworkDirect='Enabled'; NetworkDirectAcrossIPSubnets='Blocked'; PacketCoalescingFilter='Enabled' }
       if (-not $nf.ContainsKey('glob')) {
           $cur = Get-NetOffloadGlobalSetting -ErrorAction Stop
           $o = @{}
           foreach ($k in $want.Keys) { if ($cur.PSObject.Properties[$k]) { $o[$k] = [string]$cur.$k } }
           $nf['glob'] = $o
       }
       foreach ($k in $want.Keys) {
           try { $a = @{}; $a[$k] = $want[$k]; Set-NetOffloadGlobalSetting @a -ErrorAction Stop }
           catch { Log ('NetFade: skipped global ' + $k + ' (' + $_.Exception.Message + ')') }
       }
       $cpus = [Environment]::ProcessorCount
       $mx = [Math]::Min(14, $cpus - 1); $mp = [Math]::Min(8, $cpus)
       if (-not $nf.ContainsKey('rss')) { $nf['rss'] = @{} }
       foreach ($ad in (Get-NfAdapters)) {
           $n = [string]$ad.Name
           if (-not $nf['rss'].ContainsKey($n)) {
               try {
                   $r = Get-NetAdapterRss -Name $n -ErrorAction Stop
                   $nf['rss'][$n] = @{ en = [bool]$r.Enabled; q = [int]$r.NumberOfReceiveQueues; prof = [string]$r.Profile; base = [int]$r.BaseProcessorNumber; max = [int]$r.MaxProcessorNumber; mp = [int]$r.MaxProcessors }
               } catch { Log ('NetFade: ' + $n + ' has no RSS support - skipped'); continue }
           }
           try {
               Set-NetAdapterRss -Name $n -Enabled $true -NoRestart -ErrorAction Stop
               Set-NetAdapterRss -Name $n -NumberOfReceiveQueues 2 -Profile NUMAStatic -BaseProcessorNumber 0 -MaxProcessorNumber $mx -MaxProcessors $mp -NoRestart -ErrorAction Stop
           } catch { Log ('NetFade: RSS on ' + $n + ' partly failed: ' + $_.Exception.Message) }
       }
   } },

@{ G='Network'; Name='NetFade: IPv4 interface settings'; Rec=$false
   Desc='Per active adapter: forwarding/advertising off, weak host off, ClampMss off, ECN AppDecide, RouterDiscovery ControlledByDHCP, ND timers (30000/1000/1000), DadTransmits 3, MTU 1500. Originals are saved and restored.'
   Check={ $ok = $false; foreach ($ad in (Get-NfAdapters)) { $i = Get-NetIPInterface -InterfaceIndex $ad.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue; if ($i -and [string]$i.WeakHostReceive -eq 'Disabled' -and [string]$i.WeakHostSend -eq 'Disabled' -and [string]$i.ClampMss -eq 'Disabled' -and [string]$i.EcnMarking -eq 'AppDecide' -and [int]$i.NlMtu -eq 1500) { $ok = $true } }; $ok }
   Apply={
       $nf = Get-NfState
       if (-not $nf.ContainsKey('ip')) { $nf['ip'] = @{} }
       # param, property, value
       $map = @(
           @('Advertising','Advertising','Disabled'), @('AdvertiseDefaultRoute','AdvertiseDefaultRoute','Disabled'), @('AutomaticMetric','AutomaticMetric','Enabled'),
           @('ClampMss','ClampMss','Disabled'), @('DirectedMacWolPattern','DirectedMacWolPattern','Disabled'), @('EcnMarking','EcnMarking','AppDecide'),
           @('ForceArpNdWolPattern','ForceArpNdWolPattern','Disabled'), @('Forwarding','Forwarding','Disabled'), @('IgnoreDefaultRoutes','IgnoreDefaultRoutes','Disabled'),
           @('ManagedAddressConfiguration','ManagedAddressConfiguration','Enabled'), @('NeighborDiscoverySupported','NeighborDiscoverySupported','Yes'),
           @('NeighborUnreachabilityDetection','NeighborUnreachabilityDetection','Enabled'), @('OtherStatefulConfiguration','OtherStatefulConfiguration','Enabled'),
           @('RouterDiscovery','RouterDiscovery','ControlledByDHCP'), @('WeakHostReceive','WeakHostReceive','Disabled'), @('WeakHostSend','WeakHostSend','Disabled'),
           @('BaseReachableTimeMs','BaseReachableTime',30000), @('RetransmitTimeMs','RetransmitTime',1000), @('DadRetransmitTimeMs','DadRetransmitTime',1000),
           @('DadTransmits','DadTransmits',3), @('NlMtuBytes','NlMtu',1500)
       )
       foreach ($ad in (Get-NfAdapters)) {
           $idx = [int]$ad.ifIndex
           $cur = Get-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue
           if (-not $cur) { continue }
           $sk = [string]$idx
           if (-not $nf['ip'].ContainsKey($sk)) { $nf['ip'][$sk] = @{} }
           foreach ($m in $map) {
               if (-not $cur.PSObject.Properties[$m[1]]) { continue }
               if (-not $nf['ip'][$sk].ContainsKey($m[0])) { $nf['ip'][$sk][$m[0]] = [string]$cur.($m[1]) }
               try { $a = @{ InterfaceIndex = $idx; AddressFamily = 'IPv4' }; $a[$m[0]] = $m[2]; Set-NetIPInterface @a -ErrorAction Stop }
               catch { Log ('NetFade: skipped ' + $m[0] + ' on ' + $ad.Name + ' (' + $_.Exception.Message + ')') }
           }
       }
   } },

@{ G='Network'; Name='NetFade: NIC advanced + power-saving off'; Rec=$false
   Desc='Driver keys (only those your driver has): all checksum/LSO/ARP/NS offload off, flow control off, interrupt moderation off, buffers RX 512 / TX 128, priority tag on, coalesce on (2048), UDP Tx scaling on, every power-saving option off. Adapters restart.'
   Check={ $k = @(Get-NfNicKeys); ($k.Count -gt 0) -and (@($k | Where-Object { [string]$_.Props.'*LsoV2IPv4' -eq '0' -and [string]$_.Props.'*FlowControl' -eq '0' }).Count -gt 0) }
   Apply={
       $want = [ordered]@{
           '*FlowControl'='0'; '*IPChecksumOffloadIPv4'='0'; '*TCPChecksumOffloadIPv4'='0'; '*TCPChecksumOffloadIPv6'='0'; '*UDPChecksumOffloadIPv4'='0'; '*UDPChecksumOffloadIPv6'='0'
           '*LsoV1IPv4'='0'; '*LsoV2IPv4'='0'; '*LsoV2IPv6'='0'; '*PMARPOffload'='0'; '*PMNSOffload'='0'; '*PriorityVLANTag'='1'
           '*ReceiveBuffers'='512'; '*TransmitBuffers'='128'; '*InterruptModeration'='0'; 'Coalesce'='1'; 'CoalesceBufferSize'='2048'; '*UdpTxScaling'='1'
           'APMSleepStates'='0'; 'DynamicPowerGating'='0'; 'ConnectedPowerGating'='0'; 'AutoPowerSaveModeEnabled'='0'; 'NicAutoPowerSaver'='0'; 'DelayedPowerUpEnabled'='0'; 'ReduceSpeedOnPowerDown'='0'
       }
       $n = 0
       foreach ($nk in (Get-NfNicKeys)) {
           foreach ($k in $want.Keys) {
               $bare = $k.TrimStart('*')
               foreach ($v in @(@($k, $bare, ('*' + $bare)) | Select-Object -Unique)) {
                   if ($nk.Props.PSObject.Properties[$v]) { Set-Reg $nk.Path $v $want[$k] 'String'; $n++; break }
               }
           }
       }
       Log "NetFade: NIC driver values written: $n - restarting adapters (brief disconnect)"
       Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Restart-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
   } },

@{ G='Network'; Name='NetFade: NIC MSI mode + interrupt priority'; Rec=$false
   Desc='MSI mode on, interrupt priority High, device policy AllCloseProcessors for the active network adapter. Needs a reboot.'
   Check={ $ok = $false; foreach ($ad in (Get-NfAdapters)) { if ($ad.PnPDeviceID -and (Test-Reg "$CCS\Enum\$($ad.PnPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" 'MSISupported' 1) -and (Test-Reg "$CCS\Enum\$($ad.PnPDeviceID)\Device Parameters\Interrupt Management\Affinity Policy" 'DevicePriority' 3)) { $ok = $true } }; $ok }
   Apply={
       $n = 0
       foreach ($ad in (Get-NfAdapters)) {
           if (-not $ad.PnPDeviceID) { continue }
           $b = "$CCS\Enum\$($ad.PnPDeviceID)\Device Parameters\Interrupt Management"
           Set-Reg "$b\MessageSignaledInterruptProperties" 'MSISupported' 1
           Set-Reg "$b\Affinity Policy" 'DevicePolicy' 1
           Set-Reg "$b\Affinity Policy" 'DevicePriority' 3
           $n++
       }
       if ($n -eq 0) { Log 'NetFade: no active physical adapter found for MSI - nothing changed' }
   } },

# ===== NVIDIA GPU
@{ G='Graphics / Games'; Name='NVIDIA: max performance power state (PowerMizer)'; Rec=$false
   Desc='PerfLevelSrc=0x2222, PowerMizerEnable/Level/LevelAC = 1 on NVIDIA adapters: the driver prefers maximum performance. Laptop: more heat and battery use.'
   Check={ $k = @(Get-NvKeys); ($k.Count -gt 0) -and (Test-Reg $k[0].Path 'PerfLevelSrc' 8738) }
   Apply={
       $n = 0
       foreach ($k in (Get-NvKeys)) {
           Set-Reg $k.Path 'PerfLevelSrc' 8738
           Set-Reg $k.Path 'PowerMizerEnable' 1
           Set-Reg $k.Path 'PowerMizerLevel' 1
           Set-Reg $k.Path 'PowerMizerLevelAC' 1
           $n++
       }
       if ($n -eq 0) { Log 'No NVIDIA adapter key found - nothing changed' }
   } },

@{ G='Graphics / Games'; Name='NVIDIA: lock GPU at P0 (no idle downclock)'; Rec=$false
   Desc='DisableDynamicPstate=1: the GPU never drops to a low power state. Steadier frame times, but the card runs hotter and uses more power even on the desktop.'
   Check={ $k = @(Get-NvKeys); ($k.Count -gt 0) -and (Test-Reg $k[0].Path 'DisableDynamicPstate' 1) }
   Apply={
       $n = 0
       foreach ($k in (Get-NvKeys)) { Set-Reg $k.Path 'DisableDynamicPstate' 1; $n++ }
       if ($n -eq 0) { Log 'No NVIDIA adapter key found - nothing changed' }
   } },

@{ G='Graphics / Games'; Name='NVIDIA: GPU MSI mode'; Rec=$false
   Desc='MSISupported=1 for the NVIDIA display adapter (message-signaled interrupts, lower interrupt latency). Needs a reboot.'
   Check={ $ids = @(Get-NvPnpIds); ($ids.Count -gt 0) -and (Test-Reg "$CCS\Enum\$($ids[0])\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" 'MSISupported' 1) }
   Apply={
       $n = 0
       foreach ($id in (Get-NvPnpIds)) {
           Set-Reg "$CCS\Enum\$id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" 'MSISupported' 1
           $n++
       }
       if ($n -eq 0) { Log 'No NVIDIA display adapter found - nothing changed' }
   } },

@{ G='Graphics / Games'; Name='NVIDIA: telemetry off'; Rec=$false
   Desc='NVIDIA FTS telemetry flags (EnableRID44231/64640/66610) = 0 and NvTelemetryContainer service set to Disabled (if installed).'
   Check={ Test-Reg 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS' 'EnableRID44231' 0 }
   Apply={
       $f = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS'
       foreach ($n in 'EnableRID44231','EnableRID64640','EnableRID66610') { Set-Reg $f $n 0 }
       $sv = "$CCS\Services\NvTelemetryContainer"
       if (Test-Path -LiteralPath $sv) {
           Set-Reg $sv 'Start' 4
           Stop-Service 'NvTelemetryContainer' -Force -ErrorAction SilentlyContinue
       }
   } },

@{ G='Graphics / Games'; Name='GPU: longer TDR timeout (TdrDelay 10)'; Rec=$false
   Desc='TdrDelay=10, TdrDdiDelay=25 (defaults 2 / 5): fewer false "display driver stopped responding" resets under heavy load.'
   Check={ (Test-Reg "$CCS\Control\GraphicsDrivers" 'TdrDelay' 10) -and (Test-Reg "$CCS\Control\GraphicsDrivers" 'TdrDdiDelay' 25) }
   Apply={
       Set-Reg "$CCS\Control\GraphicsDrivers" 'TdrDelay' 10
       Set-Reg "$CCS\Control\GraphicsDrivers" 'TdrDdiDelay' 25
   } },

@{ G='Graphics / Games'; Name='Windowed game optimizations (flip model upgrade)'; Rec=$false
   Desc='DirectXUserGlobalSettings: SwapEffectUpgradeEnable=1. Windowed / borderless DX10-11 games use the lower-latency flip model. Existing flags are kept.'
   Check={ ([string](Get-RegVal $GpuPrefKey 'DirectXUserGlobalSettings')) -match 'SwapEffectUpgradeEnable=1' }
   Apply={
       $cur = [string](Get-RegVal $GpuPrefKey 'DirectXUserGlobalSettings')
       if ($cur -match 'SwapEffectUpgradeEnable=\d;') { $new = $cur -replace 'SwapEffectUpgradeEnable=\d;', 'SwapEffectUpgradeEnable=1;' }
       else { $new = $cur.Trim() + 'SwapEffectUpgradeEnable=1;' }
       Set-Reg $GpuPrefKey 'DirectXUserGlobalSettings' $new 'String'
   } },

@{ G='Graphics / Games'; Name='NVIDIA shader cache cleaner (one-time)'; Rec=$false
   Desc='Deletes NVIDIA DXCache / GLCache, D3DSCache and NV_Cache contents. Games rebuild shaders on the next launch (first run may stutter). Not reverted.'
   Apply={
       foreach ($d in "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\NVIDIA\GLCache", "$env:LOCALAPPDATA\D3DSCache", "$env:ProgramData\NVIDIA Corporation\NV_Cache") {
           if (Test-Path -LiteralPath $d) { Remove-Item -Path (Join-Path $d '*') -Recurse -Force -ErrorAction SilentlyContinue; Log "Cleared $d" }
       }
   } },

# ===== Misc
@{ G='Misc'; Name='Telemetry level 0 (policy)'; Rec=$false
   Desc='AllowTelemetry=0 (honored fully on LTSC/Enterprise).'
   Check={ Test-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 }
   Apply={ Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 } },

@{ G='Misc'; Name='Clean temp files + flush DNS (one-time)'; Rec=$false
   Desc='Deletes %TEMP% and C:\Windows\Temp contents and flushes DNS. Not reverted.'
   Apply={
       Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
       Remove-Item "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
       ipconfig /flushdns | Out-Null
   } },

@{ G='Misc'; Name='FiveM cache cleaner (one-time)'; Rec=$false
   Desc='Deletes FiveM cache, server-cache and server-cache-priv (fixes stutter / corrupt assets; next launch downloads again). Close FiveM first. Not reverted.'
   Apply={
       if (Get-Process -Name 'FiveM*', 'GTA5*' -ErrorAction SilentlyContinue) { throw 'FiveM / GTA is running - close it first' }
       $d = Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.app\data'
       if (-not (Test-Path $d)) { throw "FiveM data folder not found: $d" }
       foreach ($n in 'cache', 'server-cache', 'server-cache-priv') {
           $p = Join-Path $d $n
           if (Test-Path $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue; Log "removed $n" }
       }
   } },


@{ G='Input'; Name='Fast keyboard repeat + Sticky/Filter/Toggle keys off'; Rec=$true
   Desc='KeyboardDelay 0, KeyboardSpeed 31 and the Sticky / Filter / Toggle Keys shortcut popups disabled (current user).'
   Check={ (Test-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardSpeed' '31') -and (Test-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506') }
   Apply={
       $k = 'HKCU:\Control Panel\Keyboard'
       Set-Reg $k 'KeyboardDelay' '0' 'String'
       Set-Reg $k 'KeyboardSpeed' '31' 'String'
       Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506' 'String'
       Set-Reg 'HKCU:\Control Panel\Accessibility\Keyboard Response' 'Flags' '122' 'String'
       Set-Reg 'HKCU:\Control Panel\Accessibility\ToggleKeys' 'Flags' '58' 'String'
   } },

@{ G='Misc'; Name='Desktop responsiveness (menus + animations)'; Rec=$true
   Desc='MenuShowDelay 0, window minimize/maximize animation off, taskbar animations off (current user; sign out to fully apply).'
   Check={ (Test-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0') -and (Test-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0') }
   Apply={
       Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
       Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
       Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
   } },

@{ G='Memory / Disk'; Name='Keep kernel in RAM (DisablePagingExecutive)'; Rec=($RamGB -ge 16)
   Desc='DisablePagingExecutive=1 keeps the kernel and drivers out of the page file. Only worth it with 16 GB+ RAM.'
   Check={ Test-Reg "$CCS\Control\Session Manager\Memory Management" 'DisablePagingExecutive' 1 }
   Apply={ Set-Reg "$CCS\Control\Session Manager\Memory Management" 'DisablePagingExecutive' 1 } },

@{ G='Power'; Name='Hibernate off'; Rec=$false
   Desc='powercfg /hibernate off (removes hiberfil.sys). Restore turns it back on if it was on. Not recommended on laptops.'
   Check={ Test-Reg "$CCS\Control\Power" 'HibernateEnabled' 0 }
   Apply={
       if (-not $script:X.ContainsKey('hib')) { $script:X['hib'] = [bool](Test-Reg "$CCS\Control\Power" 'HibernateEnabled' 1) }
       powercfg /hibernate off | Out-Null
   } },

@{ G='Graphics / Games'; Name='Force dedicated GPU for FiveM / GTA'; Rec=$true
   Desc='Windows Graphics settings: High performance GPU for the FiveM / GTA V executables found on this PC (useful on laptops / hybrid graphics).'
   Check={ $ex = @(Get-GpuPrefExes); ($ex.Count -gt 0) -and (Test-Reg $GpuPrefKey $ex[0] 'GpuPreference=2;') }
   Apply={
       $ex = @(Get-GpuPrefExes)
       if ($ex.Count -eq 0) { throw 'FiveM / GTA executable not found' }
       foreach ($p in $ex) { Set-Reg $GpuPrefKey $p 'GpuPreference=2;' 'String' }
   } }
)

# ---------------------------------------------------------------- restore
function Restore-All {
    Log '===== RESTORE ====='
    foreach ($k in @($script:Reg.Keys)) {
        $i = $k.LastIndexOf('|'); $path = $k.Substring(0, $i); $name = $k.Substring($i + 1); $o = $script:Reg[$k]
        try {
            if ($o.existed) {
                $v = $o.value
                switch ($o.kind) {
                    'DWord'       { $v = [int]$v }
                    'QWord'       { $v = [long]$v }
                    'Binary'      { $v = [byte[]]@($v) }
                    'MultiString' { $v = [string[]]@($v) }
                }
                if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
                Set-ItemProperty -LiteralPath $path -Name $name -Value $v -Type $o.kind -Force
            } else {
                Remove-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue
            }
        } catch { Log "restore failed: $k ($($_.Exception.Message))" }
    }
    if ($script:X.ContainsKey('delKeys')) { foreach ($k in @($script:X['delKeys'])) { Remove-Item -LiteralPath $k -Recurse -Force -ErrorAction SilentlyContinue } }
    if ($script:X.ContainsKey('bcd'))     { foreach ($n in @($script:X['bcd'])) { bcdedit /deletevalue $n 2>$null | Out-Null } }
    if ($script:X.ContainsKey('netsh')) {
        & netsh int tcp set global rsc=enabled | Out-Null
        if ($script:X.ContainsKey('tcp')) {
            $t = $script:X['tcp']
            try { Set-NetTCPSetting -SettingName Internet -Timestamps $t.ts -EcnCapability $t.ecn -AutoTuningLevelLocal $t.au -NonSackRttResiliency $t.nsr -ErrorAction Stop }
            catch { Log ('TCP restore failed: ' + $_.Exception.Message) }
        }
    }
    Restore-NfState
    if ($script:X.ContainsKey('cpmin'))   { $c = $script:X['cpmin']; powercfg -setacvalueindex $c.guid SUB_PROCESSOR CPMINCORES ([int]$c.ac) | Out-Null; powercfg /setactive $c.guid | Out-Null }
    if ($script:X.ContainsKey('pwr')) {
        $plans = @()
        foreach ($c in @($script:X['pwr'])) {
            try { powercfg -setacvalueindex $c.guid $c.sub $c.set ([int]$c.ac) | Out-Null; if ($plans -notcontains $c.guid) { $plans += $c.guid } } catch { Log "power restore failed: $($c.k)" }
        }
        foreach ($p in $plans) { powercfg /setactive $p | Out-Null }
    }
    if ($script:X.ContainsKey('prevPlan') -and $script:X['prevPlan']) { powercfg /setactive $script:X['prevPlan'] | Out-Null }
    if ($script:X.ContainsKey('svc')) {
        foreach ($n in @($script:X['svc'].Keys)) {
            $mode = switch ($script:X['svc'][$n]) { 'Auto' { 'Automatic' } 'Manual' { 'Manual' } default { 'Disabled' } }
            Set-Service -Name $n -StartupType $mode -ErrorAction SilentlyContinue
        }
    }
    if ($script:X.ContainsKey('timer')) {
        Stop-Service 'MostKillTimer' -Force -ErrorAction SilentlyContinue
        sc.exe delete MostKillTimer | Out-Null
        Remove-Item (Join-Path $DataDir 'MostKillTimer.exe') -Force -ErrorAction SilentlyContinue
    }
    gpupdate /force | Out-Null
    $script:Reg = @{}; $script:X = @{}
    Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
    Log '===== RESTORE complete - restart Windows ====='
}

# ---------------------------------------------------------------- GUI (blue card-style mode selector)
if (-not ('HY.ModeGrid' -as [type])) {
Add-Type -ReferencedAssemblies 'System.Windows.Forms','System.Drawing' -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace HX {
  // ---------------------------------------------------------------- palette / fonts
  public static class Pal {
    public static Color Bg    = Color.FromArgb(6, 9, 28);
    public static Color Side  = Color.FromArgb(7, 11, 30);
    public static Color Card  = Color.FromArgb(12, 17, 40);
    public static Color Card2 = Color.FromArgb(17, 25, 51);
    public static Color Line  = Color.FromArgb(24, 34, 62);
    public static Color Line2 = Color.FromArgb(44, 57, 90);
    public static Color Txt   = Color.FromArgb(240, 240, 240);
    public static Color Soft  = Color.FromArgb(200, 200, 200);
    public static Color Mut   = Color.FromArgb(109, 122, 149);
    public static Color Dim   = Color.FromArgb(72, 87, 120);
    public static Color Ok    = Color.FromArgb(74, 222, 128);
    public static Color Warn  = Color.FromArgb(250, 190, 60);
    public static Color Bad   = Color.FromArgb(239, 68, 68);
  }

  public static class Fnt {
    static Dictionary<string, Font> cache = new Dictionary<string, Font>();
    static string head;
    static string Pick(string[] names) {
      foreach (string n in names) { try { using (FontFamily f = new FontFamily(n)) { return n; } } catch (Exception) { } }
      return "Segoe UI";
    }
    public static string HeadFamily {
      get { if (head == null) head = Pick(new string[] { "Segoe UI Semibold", "Segoe UI" }); return head; }
    }
    static Font Get(string k, string fam, float pt, FontStyle st) {
      if (pt < 7.8f) pt = 7.8f;
      string key = k + pt.ToString(CultureInfo.InvariantCulture);
      lock (cache) {
        Font f;
        if (!cache.TryGetValue(key, out f)) {
          try { f = new Font(fam, pt, st, GraphicsUnit.Point); }
          catch (Exception) { f = new Font(FontFamily.GenericSansSerif, pt, st, GraphicsUnit.Point); }
          cache[key] = f;
        }
        return f;
      }
    }
    public static Font H(float pt) { return Get("H", HeadFamily, pt, FontStyle.Regular); }
    public static Font S(float pt) { return Get("S", "Segoe UI", pt, FontStyle.Regular); }
    public static Font SB(float pt) { return Get("SB", "Segoe UI", pt, FontStyle.Bold); }
    public static Font M(float pt) { return Get("M", "Consolas", pt, FontStyle.Bold); }
  }

  // ---------------------------------------------------------------- drawing helpers
  public static class G {
    public static StringFormat TF;
    static G() {
      TF = new StringFormat(StringFormat.GenericTypographic);
      TF.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces | StringFormatFlags.NoWrap;
    }
    public static GraphicsPath Round(RectangleF r, float rad) {
      float d = Math.Min(rad * 2f, Math.Min(r.Width, r.Height));
      GraphicsPath p = new GraphicsPath();
      if (d <= 0.5f) { p.AddRectangle(r); return p; }
      p.AddArc(r.X, r.Y, d, d, 180, 90);
      p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
      p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
      p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
      p.CloseFigure();
      return p;
    }
    public static void Smooth(Graphics g) {
      g.SmoothingMode = SmoothingMode.AntiAlias;
      g.InterpolationMode = InterpolationMode.HighQualityBicubic;
      g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;
    }
    public static Color Back(Control c) { return (c.Parent != null) ? c.Parent.BackColor : Pal.Bg; }
    public static Color Mix(Color a, Color b, float t) {
      if (t < 0f) t = 0f; if (t > 1f) t = 1f;
      return Color.FromArgb((int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t));
    }
    public static void Box(Graphics g, RectangleF r, float rad, Color fill, Color line) {
      using (GraphicsPath p = Round(r, rad)) {
        if (fill.A > 0) { using (SolidBrush b = new SolidBrush(fill)) g.FillPath(b, p); }
        if (line.A > 0) { using (Pen pn = new Pen(line, 1f)) g.DrawPath(pn, p); }
      }
    }
    public static void Text(Graphics g, string s, Font f, Color c, RectangleF r, StringAlignment h, StringAlignment v, bool wrap) {
      if (string.IsNullOrEmpty(s)) return;
      using (StringFormat sf = new StringFormat()) {
        sf.Alignment = h; sf.LineAlignment = v;
        if (wrap) { sf.Trimming = StringTrimming.EllipsisWord; sf.FormatFlags = StringFormatFlags.LineLimit; }
        else { sf.Trimming = StringTrimming.EllipsisCharacter; sf.FormatFlags = StringFormatFlags.NoWrap; }
        using (SolidBrush b = new SolidBrush(c)) g.DrawString(s, f, b, r, sf);
      }
    }
    public static float TrackW(Graphics g, string s, Font f, float sp) {
      sp *= 0.3f;
      if (sp < 0.4f) return g.MeasureString(s, f, 10000, TF).Width;
      float w = 0f;
      foreach (char ch in s) w += g.MeasureString(ch.ToString(), f, 10000, TF).Width + sp;
      return (w > 0f) ? w - sp : 0f;
    }
    public static void Track(Graphics g, string s, Font f, Color c, float x, float y, float sp) {
      sp *= 0.3f;
      using (SolidBrush b = new SolidBrush(c)) {
        if (sp < 0.4f) { g.DrawString(s, f, b, x, y, TF); return; }
        foreach (char ch in s) {
          string t = ch.ToString();
          g.DrawString(t, f, b, x, y, TF);
          x += g.MeasureString(t, f, 10000, TF).Width + sp;
        }
      }
    }
    public static void TrackR(Graphics g, string s, Font f, Color c, float right, float y, float sp) {
      Track(g, s, f, c, right - TrackW(g, s, f, sp), y, sp);
    }
    public static void DrawHead(Graphics g, int w, string title, string sub) {
      Track(g, title, Fnt.H(17f), Pal.Txt, 27f, 20f, 1.6f);
      G.Text(g, sub, Fnt.S(8.5f), Color.FromArgb(89, 103, 134), new RectangleF(27f, 54f, Math.Max(10, w - 54), 18f), StringAlignment.Near, StringAlignment.Near, false);
      using (Pen p = new Pen(Color.FromArgb(26, 255, 255, 255), 1f)) g.DrawLine(p, 27f, 83f, w - 23f, 83f);
    }
  }

  // ---------------------------------------------------------------- vector icons (no icon font needed)
  public static class Ico {
    public static Color Tint(int id) {
      switch (id) {
        case 2: return Color.FromArgb(96, 165, 250);
        case 3: return Color.FromArgb(251, 191, 36);
        case 5: return Color.FromArgb(74, 222, 128);
        default: return Color.FromArgb(228, 228, 228);
      }
    }
    // 0 laptop  1 gear  2 globe  3 bolt  4 keyboard  5 battery  6 refresh  7 doc  8 info
    // 9 memory  10 gamepad  11 disk  12 wrench  13 wifi  14 cpu  15 mouse  16 user
    public static void Draw(Graphics g, int id, float cx, float cy, float s, Color c) {
      SmoothingMode old = g.SmoothingMode;
      g.SmoothingMode = SmoothingMode.AntiAlias;
      using (Pen p = new Pen(c, Math.Max(1.2f, s / 11f))) using (SolidBrush b = new SolidBrush(c)) {
        p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; p.LineJoin = LineJoin.Round;
        float h = s / 2f;
        switch (id) {
          case 0: {
            RectangleF r = new RectangleF(cx - h * 0.78f, cy - h * 0.72f, s * 0.78f, s * 0.56f);
            using (GraphicsPath gp = G.Round(r, 2f)) g.DrawPath(p, gp);
            g.DrawLine(p, cx - h * 1.0f, cy + h * 0.62f, cx + h * 1.0f, cy + h * 0.62f);
            break; }
          case 1: {
            float r1 = s * 0.2f, r2 = s * 0.33f;
            g.DrawEllipse(p, cx - r1, cy - r1, r1 * 2, r1 * 2);
            g.DrawEllipse(p, cx - r2, cy - r2, r2 * 2, r2 * 2);
            for (int i = 0; i < 8; i++) {
              double a = i * Math.PI / 4.0;
              g.DrawLine(p, cx + (float)Math.Cos(a) * r2, cy + (float)Math.Sin(a) * r2, cx + (float)Math.Cos(a) * (h * 0.95f), cy + (float)Math.Sin(a) * (h * 0.95f));
            }
            break; }
          case 2: {
            float r = h * 0.92f;
            g.DrawEllipse(p, cx - r, cy - r, r * 2, r * 2);
            g.DrawEllipse(p, cx - r * 0.42f, cy - r, r * 0.84f, r * 2);
            g.DrawLine(p, cx - r, cy, cx + r, cy);
            g.DrawArc(p, cx - r * 0.86f, cy - r * 0.62f, r * 1.72f, r * 1.24f, 200, 140);
            g.DrawArc(p, cx - r * 0.86f, cy - r * 0.62f, r * 1.72f, r * 1.24f, 20, 140);
            break; }
          case 3: {
            PointF[] pts = new PointF[] {
              new PointF(cx + s * 0.10f, cy - h * 1.0f), new PointF(cx - s * 0.30f, cy + s * 0.06f), new PointF(cx - s * 0.02f, cy + s * 0.06f),
              new PointF(cx - s * 0.10f, cy + h * 1.0f), new PointF(cx + s * 0.30f, cy - s * 0.08f), new PointF(cx + s * 0.02f, cy - s * 0.08f) };
            g.FillPolygon(b, pts);
            break; }
          case 4: {
            RectangleF r = new RectangleF(cx - h * 1.0f, cy - h * 0.58f, s, s * 0.58f);
            using (GraphicsPath gp = G.Round(r, 2.5f)) g.DrawPath(p, gp);
            float dx = s * 0.2f;
            for (int row = 0; row < 2; row++) for (int col = 0; col < 4; col++)
              g.FillEllipse(b, cx - h * 0.62f + col * dx - 0.8f, cy - h * 0.28f + row * s * 0.2f - 0.8f, 1.8f, 1.8f);
            g.DrawLine(p, cx - h * 0.4f, cy + h * 0.2f, cx + h * 0.4f, cy + h * 0.2f);
            break; }
          case 5: {
            RectangleF r = new RectangleF(cx - h * 0.62f, cy - h * 0.78f, s * 0.62f, s * 0.9f);
            using (GraphicsPath gp = G.Round(r, 2f)) g.DrawPath(p, gp);
            g.FillRectangle(b, cx - h * 0.28f, cy - h * 1.02f, s * 0.28f, s * 0.1f);
            g.FillRectangle(b, r.X + 2.2f, r.Y + r.Height * 0.38f, r.Width - 4.4f, r.Height * 0.62f - 2.2f);
            break; }
          case 6: {
            float r = h * 0.78f;
            g.DrawArc(p, cx - r, cy - r, r * 2, r * 2, -30, 300);
            float ex = cx + (float)Math.Cos(-Math.PI / 6.0) * r, ey = cy + (float)Math.Sin(-Math.PI / 6.0) * r;
            PointF[] ar = new PointF[] { new PointF(ex + s * 0.02f, ey - s * 0.26f), new PointF(ex + s * 0.02f, ey + s * 0.02f), new PointF(ex - s * 0.26f, ey - s * 0.02f) };
            g.FillPolygon(b, ar);
            break; }
          case 7: {
            RectangleF r = new RectangleF(cx - h * 0.68f, cy - h * 0.92f, s * 0.68f, s * 0.92f);
            using (GraphicsPath gp = G.Round(r, 2f)) g.DrawPath(p, gp);
            for (int i = 0; i < 3; i++) g.DrawLine(p, r.X + 3.2f, r.Y + r.Height * (0.3f + i * 0.22f), r.Right - 3.2f, r.Y + r.Height * (0.3f + i * 0.22f));
            break; }
          case 8: {
            float r = h * 0.92f;
            g.DrawEllipse(p, cx - r, cy - r, r * 2, r * 2);
            g.DrawLine(p, cx, cy - r * 0.05f, cx, cy + r * 0.5f);
            g.FillEllipse(b, cx - 1.2f, cy - r * 0.55f - 1.2f, 2.4f, 2.4f);
            break; }
          case 9: {
            RectangleF r = new RectangleF(cx - h * 0.62f, cy - h * 0.62f, s * 0.62f, s * 0.62f);
            using (GraphicsPath gp = G.Round(r, 2f)) g.DrawPath(p, gp);
            for (int i = 0; i < 3; i++) {
              float t = r.X + r.Width * (0.2f + i * 0.3f);
              g.DrawLine(p, t, r.Y, t, r.Y - s * 0.16f);
              g.DrawLine(p, t, r.Bottom, t, r.Bottom + s * 0.16f);
            }
            g.DrawRectangle(p, cx - s * 0.12f, cy - s * 0.12f, s * 0.24f, s * 0.24f);
            break; }
          case 10: {
            RectangleF r = new RectangleF(cx - h * 1.0f, cy - h * 0.55f, s, s * 0.6f);
            using (GraphicsPath gp = G.Round(r, 5f)) g.DrawPath(p, gp);
            g.DrawLine(p, cx - h * 0.58f, cy - h * 0.12f, cx - h * 0.22f, cy - h * 0.12f);
            g.DrawLine(p, cx - h * 0.4f, cy - h * 0.3f, cx - h * 0.4f, cy + h * 0.06f);
            g.FillEllipse(b, cx + h * 0.3f - 1.4f, cy - h * 0.2f - 1.4f, 2.8f, 2.8f);
            g.FillEllipse(b, cx + h * 0.58f - 1.4f, cy - h * 0.02f - 1.4f, 2.8f, 2.8f);
            break; }
          case 11: {
            float r = h * 0.92f;
            g.DrawEllipse(p, cx - r, cy - r, r * 2, r * 2);
            g.FillEllipse(b, cx - r * 0.22f, cy - r * 0.22f, r * 0.44f, r * 0.44f);
            break; }
          case 12: {
            g.DrawLine(p, cx - h * 0.78f, cy + h * 0.78f, cx + h * 0.28f, cy - h * 0.28f);
            g.DrawEllipse(p, cx + h * 0.05f, cy - h * 0.95f, h * 0.9f, h * 0.9f);
            break; }
          case 13: {
            float by = cy + h * 0.55f;
            for (int i = 1; i <= 3; i++) {
              float r = h * 0.42f * i;
              g.DrawArc(p, cx - r, by - r, r * 2, r * 2, 225, 90);
            }
            g.FillEllipse(b, cx - 1.6f, by - 1.6f, 3.2f, 3.2f);
            break; }
          case 14: {
            RectangleF r = new RectangleF(cx - h * 0.56f, cy - h * 0.56f, s * 0.56f, s * 0.56f);
            using (GraphicsPath gp = G.Round(r, 2f)) g.DrawPath(p, gp);
            g.DrawRectangle(p, cx - s * 0.12f, cy - s * 0.12f, s * 0.24f, s * 0.24f);
            for (int i = 0; i < 3; i++) {
              float t = r.X + r.Width * (0.2f + i * 0.3f);
              g.DrawLine(p, t, r.Y, t, r.Y - s * 0.14f); g.DrawLine(p, t, r.Bottom, t, r.Bottom + s * 0.14f);
              float u = r.Y + r.Height * (0.2f + i * 0.3f);
              g.DrawLine(p, r.X, u, r.X - s * 0.14f, u); g.DrawLine(p, r.Right, u, r.Right + s * 0.14f, u);
            }
            break; }
          case 15: {
            RectangleF r = new RectangleF(cx - h * 0.5f, cy - h * 0.95f, s * 0.5f, s * 0.95f);
            using (GraphicsPath gp = G.Round(r, h * 0.5f)) g.DrawPath(p, gp);
            g.DrawLine(p, cx, r.Y, cx, r.Y + r.Height * 0.4f);
            break; }
          case 17: {
            RectangleF r = new RectangleF(cx - h * 0.95f, cy - h * 0.72f, s * 0.95f, s * 0.7f);
            using (GraphicsPath gp = G.Round(r, h * 0.45f)) g.DrawPath(p, gp);
            g.FillEllipse(b, cx - h * 0.38f - 1.5f, cy - h * 0.2f - 1.5f, 3f, 3f);
            g.FillEllipse(b, cx + h * 0.38f - 1.5f, cy - h * 0.2f - 1.5f, 3f, 3f);
            g.DrawLine(p, cx - h * 0.45f, cy + h * 0.5f, cx - h * 0.62f, cy + h * 0.85f);
            g.DrawLine(p, cx + h * 0.45f, cy + h * 0.5f, cx + h * 0.62f, cy + h * 0.85f);
            break; }
          case 18: {
            RectangleF r = new RectangleF(cx - h * 0.85f, cy - h * 0.85f, s * 0.85f, s * 0.85f);
            using (GraphicsPath gp = G.Round(r, h * 0.5f)) g.DrawPath(p, gp);
            g.DrawEllipse(p, cx - h * 0.38f, cy - h * 0.38f, h * 0.76f, h * 0.76f);
            g.FillEllipse(b, cx + h * 0.42f - 1.2f, cy - h * 0.48f - 1.2f, 2.4f, 2.4f);
            break; }
          case 19: {
            g.DrawEllipse(p, cx + h * 0.05f, cy - h * 0.85f, h * 0.8f, h * 0.8f);
            g.DrawLine(p, cx + h * 0.1f, cy - h * 0.05f, cx - h * 0.8f, cy + h * 0.8f);
            g.DrawLine(p, cx - h * 0.45f, cy + h * 0.45f, cx - h * 0.15f, cy + h * 0.75f);
            g.DrawLine(p, cx - h * 0.2f, cy + h * 0.2f, cx + h * 0.05f, cy + h * 0.45f);
            break; }
          case 20: case 21: {
            g.DrawBezier(p, cx - h, cy, cx - h * 0.4f, cy - h * 0.95f, cx + h * 0.4f, cy - h * 0.95f, cx + h, cy);
            g.DrawBezier(p, cx - h, cy, cx - h * 0.4f, cy + h * 0.95f, cx + h * 0.4f, cy + h * 0.95f, cx + h, cy);
            g.DrawEllipse(p, cx - h * 0.3f, cy - h * 0.3f, h * 0.6f, h * 0.6f);
            if (id == 21) g.DrawLine(p, cx - h * 0.8f, cy + h * 0.8f, cx + h * 0.8f, cy - h * 0.8f);
            break; }
          case 22: {
            g.DrawLines(p, new PointF[] { new PointF(cx - h * 0.62f, cy + h * 0.02f), new PointF(cx - h * 0.15f, cy + h * 0.5f), new PointF(cx + h * 0.7f, cy - h * 0.5f) });
            break; }
          case 23: {
            RectangleF r = new RectangleF(cx - h * 0.62f, cy - h * 0.7f, s * 0.62f, s * 0.86f);
            using (GraphicsPath gp = G.Round(r, 2f)) g.DrawPath(p, gp);
            g.FillRectangle(b, cx - h * 0.28f, cy - h * 0.9f, s * 0.28f, s * 0.16f);
            g.DrawLine(p, r.X + 3f, r.Y + r.Height * 0.45f, r.Right - 3f, r.Y + r.Height * 0.45f);
            g.DrawLine(p, r.X + 3f, r.Y + r.Height * 0.7f, r.Right - 5f, r.Y + r.Height * 0.7f);
            break; }
          case 24: {
            RectangleF r = new RectangleF(cx - h * 0.7f, cy - h * 0.1f, s * 0.7f, h * 0.95f);
            using (GraphicsPath gp = G.Round(r, 2f)) g.DrawPath(p, gp);
            g.DrawArc(p, cx - h * 0.42f, cy - h * 0.92f, h * 0.84f, h * 1.6f, 180, 180);
            g.FillEllipse(b, cx - 1.3f, cy + h * 0.25f, 2.6f, 2.6f);
            break; }
          default: {
            g.DrawEllipse(p, cx - h * 0.3f, cy - h * 0.82f, h * 0.6f, h * 0.6f);
            g.DrawArc(p, cx - h * 0.65f, cy - h * 0.05f, h * 1.3f, h * 1.2f, 180, 180);
            break; }
        }
      }
      g.SmoothingMode = old;
    }
  }

  // ---------------------------------------------------------------- native helpers
  public static class Native {
    [DllImport("user32.dll")] static extern bool ReleaseCapture();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] static extern int SetWindowTheme(IntPtr h, string a, string b);
    [DllImport("kernel32.dll")] static extern bool GetSystemTimes(out long idle, out long kernel, out long user);
    [StructLayout(LayoutKind.Sequential)]
    struct MEMSTAT {
      public uint dwLength; public uint dwMemoryLoad;
      public ulong ullTotalPhys; public ulong ullAvailPhys; public ulong ullTotalPageFile; public ulong ullAvailPageFile;
      public ulong ullTotalVirtual; public ulong ullAvailVirtual; public ulong ullAvailExtendedVirtual;
    }
    [DllImport("kernel32.dll")] static extern bool GlobalMemoryStatusEx(ref MEMSTAT m);

    public static void Drag(IntPtr h) { try { ReleaseCapture(); SendMessage(h, 0xA1, (IntPtr)2, IntPtr.Zero); } catch (Exception) { } }
    public static void HideConsole() { try { IntPtr c = GetConsoleWindow(); if (c != IntPtr.Zero) ShowWindow(c, 0); } catch (Exception) { } }
    public static void Foreground(IntPtr h) { try { SetForegroundWindow(h); } catch (Exception) { } }
    public static void Dark(IntPtr h) { try { SetWindowTheme(h, "DarkMode_Explorer", null); } catch (Exception) { } }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, string l);
    public static void Cue(IntPtr h, string s) { try { SendMessage(h, 0x1501, (IntPtr)1, s); } catch (Exception) { } }

    static long pi, pk, pu; static bool have;
    public static double CpuLoad() {
      try {
        long i, k, u;
        if (!GetSystemTimes(out i, out k, out u)) return -1;
        double r = -1;
        if (have) {
          long tot = (k - pk) + (u - pu);
          long idle = i - pi;
          if (tot > 0) r = (tot - idle) * 100.0 / tot;
          if (r < 0) r = 0; if (r > 100 && r < 1000) r = 100;
        }
        pi = i; pk = k; pu = u; have = true;
        return r;
      } catch (Exception) { return -1; }
    }
    // returns { totalGB, usedGB, percent }
    public static double[] MemInfo() {
      try {
        MEMSTAT m = new MEMSTAT();
        m.dwLength = (uint)Marshal.SizeOf(typeof(MEMSTAT));
        if (!GlobalMemoryStatusEx(ref m)) return null;
        double tot = m.ullTotalPhys / 1073741824.0;
        double used = (m.ullTotalPhys - m.ullAvailPhys) / 1073741824.0;
        return new double[] { tot, used, m.dwMemoryLoad };
      } catch (Exception) { return null; }
    }
  }

  public class HForm : Form {
    public HForm() { SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint, true); }
    protected override CreateParams CreateParams {
      get { CreateParams cp = base.CreateParams; cp.Style |= 0x20000 | 0x80000; return cp; }
    }
  }

  // ---------------------------------------------------------------- base for custom-painted controls
  public class Ctl : Control {
    public Ctl() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      SetStyle(ControlStyles.Selectable, false);
      BackColor = Pal.Bg;
    }
  }

  // ---------------------------------------------------------------- sidebar item
  public class Nav : Ctl {
    public int Icon; public string Badge = ""; public bool Selected; public int Style; // 0 list item, 1 outlined small
    bool hover, down;
    public Nav() { Cursor = Cursors.Hand; }
    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { down = true; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(G.Back(this));
      RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1, Height - 1);
      if (Style == 0) {
        if (Selected) G.Box(g, r, 12, Color.FromArgb(17, 24, 49), Color.FromArgb(43, 56, 88));
        else if (hover) G.Box(g, r, 12, Color.FromArgb(11, 16, 39), Color.Empty);
        float ts = 32f;
        RectangleF t = new RectangleF(8f, (Height - ts) / 2f, ts, ts);
        G.Box(g, t, 9, Selected ? Color.FromArgb(24, 34, 62) : Color.FromArgb(14, 20, 44), Color.FromArgb(Selected ? 78 : 50, Selected ? 78 : 50, Selected ? 78 : 50));
        Ico.Draw(g, Icon, t.X + ts / 2f, t.Y + ts / 2f, 16f, Ico.Tint(Icon));
        float tx = 52f;
        float bw = 0f;
        if (!string.IsNullOrEmpty(Badge)) {
          Font bf = Fnt.H(7.5f);
          bw = g.MeasureString(Badge, bf, 1000, G.TF).Width + 14f;
          RectangleF br = new RectangleF(Width - 12f - bw, (Height - 18f) / 2f, bw, 18f);
          G.Box(g, br, 9, Color.FromArgb(18, 26, 52), Color.FromArgb(36, 48, 80));
          G.Text(g, Badge, bf, Pal.Mut, br, StringAlignment.Center, StringAlignment.Center, false);
        }
        G.Text(g, Text, Fnt.H(10f), Selected ? Pal.Txt : Color.FromArgb(214, 214, 214), new RectangleF(tx, 0, Width - tx - bw - 16f, Height), StringAlignment.Near, StringAlignment.Center, false);
      } else {
        Color f = hover ? Color.FromArgb(15, 22, 46) : Color.FromArgb(10, 15, 36);
        if (down) f = Color.FromArgb(19, 27, 53);
        G.Box(g, r, 11, f, Selected ? Color.FromArgb(72, 87, 120) : Color.FromArgb(30, 41, 71));
        Ico.Draw(g, Icon, 24f, Height / 2f, 13f, Pal.Mut);
        G.Track(g, Text, Fnt.H(7.8f), Color.FromArgb(190, 190, 190), 44f, Height / 2f - 7f, 1.5f);
      }
    }
  }

  // ---------------------------------------------------------------- button
  public class Btn : Ctl {
    public int Kind; public int Icon = -1; // 0 outline, 1 primary (white), 2 danger
    bool hover, down;
    public Btn() { Cursor = Cursors.Hand; }
    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { down = true; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(G.Back(this));
      RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1, Height - 1);
      Color fill, line, txt;
      if (Kind == 1) {
        fill = down ? Color.FromArgb(29, 78, 216) : (hover ? Color.FromArgb(96, 165, 250) : Color.FromArgb(37, 99, 235));
        line = Color.Empty; txt = Color.FromArgb(255, 255, 255);
      } else if (Kind == 2) {
        fill = down ? Color.FromArgb(70, 24, 24) : (hover ? Color.FromArgb(52, 22, 22) : Color.FromArgb(26, 18, 18));
        line = Color.FromArgb(96, 44, 44); txt = Color.FromArgb(244, 128, 128);
      } else {
        fill = down ? Color.FromArgb(24, 34, 62) : (hover ? Color.FromArgb(19, 27, 53) : Color.FromArgb(14, 20, 44));
        line = hover ? Color.FromArgb(55, 69, 102) : Color.FromArgb(35, 46, 78); txt = Pal.Txt;
      }
      if (!Enabled) { fill = Color.FromArgb(11, 16, 39); txt = Pal.Dim; }
      G.Box(g, r, 10, fill, line);
      Font f = Fnt.H(Kind == 1 ? 9.5f : 8.5f);
      float tw = g.MeasureString(Text, f, 2000, G.TF).Width;
      float lead = (Icon >= 0) ? 20f : 0f;
      float x = (Width - (tw + lead)) / 2f;
      if (Icon >= 0) Ico.Draw(g, Icon, x + 7f, Height / 2f, 14f, txt);
      using (SolidBrush b = new SolidBrush(txt)) g.DrawString(Text, f, b, x + lead, (Height - g.MeasureString("Ag", f, 2000, G.TF).Height) / 2f, G.TF);
    }
  }

  // ---------------------------------------------------------------- toggle switch
  public class Toggle : Ctl {
    bool chk; float pos; Timer tm = new Timer(); public Color Under = Pal.Card;
    public event EventHandler CheckedChanged;
    public Toggle() {
      Size = new Size(46, 26); Cursor = Cursors.Hand;
      tm.Interval = 15;
      tm.Tick += delegate {
        float t = chk ? 1f : 0f;
        pos += (t - pos) * 0.38f;
        if (Math.Abs(t - pos) < 0.02f) { pos = t; tm.Stop(); }
        Invalidate();
      };
    }
    protected override void Dispose(bool d) { if (d) tm.Dispose(); base.Dispose(d); }
    public bool Checked {
      get { return chk; }
      set {
        if (chk == value) return;
        chk = value; tm.Start();
        EventHandler h = CheckedChanged; if (h != null) h(this, EventArgs.Empty);
      }
    }
    public void SetInstant(bool v) { chk = v; pos = v ? 1f : 0f; tm.Stop(); Invalidate(); }
    protected override void OnClick(EventArgs e) { Checked = !chk; base.OnClick(e); }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(Under);
      RectangleF tr = new RectangleF(0.5f, 2.5f, Width - 1, Height - 5);
      Color on = Color.FromArgb(37, 99, 235), off = Color.FromArgb(27, 37, 67);
      G.Box(g, tr, tr.Height / 2f, G.Mix(off, on, pos), G.Mix(Color.FromArgb(48, 61, 94), on, pos));
      float d = tr.Height - 8f;
      float x = tr.X + 4f + pos * (tr.Width - 8f - d);
      using (SolidBrush b = new SolidBrush(G.Mix(Color.FromArgb(134, 144, 164), Color.FromArgb(255, 255, 255), pos)))
        g.FillEllipse(b, x, tr.Y + 4f, d, d);
    }
  }

  // ---------------------------------------------------------------- dark drop-down
  public class DarkTable : ProfessionalColorTable {
    public override Color ToolStripDropDownBackground { get { return Color.FromArgb(12, 18, 41); } }
    public override Color ImageMarginGradientBegin { get { return Color.FromArgb(12, 18, 41); } }
    public override Color ImageMarginGradientMiddle { get { return Color.FromArgb(12, 18, 41); } }
    public override Color ImageMarginGradientEnd { get { return Color.FromArgb(12, 18, 41); } }
    public override Color MenuBorder { get { return Color.FromArgb(43, 56, 88); } }
    public override Color MenuItemBorder { get { return Color.FromArgb(48, 61, 94); } }
    public override Color MenuItemSelected { get { return Color.FromArgb(27, 37, 67); } }
    public override Color MenuItemSelectedGradientBegin { get { return Color.FromArgb(27, 37, 67); } }
    public override Color MenuItemSelectedGradientEnd { get { return Color.FromArgb(27, 37, 67); } }
    public override Color CheckBackground { get { return Color.FromArgb(27, 37, 67); } }
    public override Color CheckSelectedBackground { get { return Color.FromArgb(33, 44, 75); } }
    public override Color CheckPressedBackground { get { return Color.FromArgb(33, 44, 75); } }
  }
  public class DarkRenderer : ToolStripProfessionalRenderer {
    public DarkRenderer() : base(new DarkTable()) { RoundedEdges = false; }
    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) { e.TextColor = Color.FromArgb(236, 236, 236); base.OnRenderItemText(e); }
  }

  public class Drop : Ctl {
    public List<string> Items = new List<string>(); int idx; public Color Under = Pal.Card; bool hover;
    public event EventHandler SelectedIndexChanged;
    public Drop() { Cursor = Cursors.Hand; Size = new Size(190, 32); }
    public int SelectedIndex {
      get { return idx; }
      set { if (value < 0 || value >= Items.Count || value == idx) return; idx = value; Invalidate(); EventHandler h = SelectedIndexChanged; if (h != null) h(this, EventArgs.Empty); }
    }
    public string SelectedItem { get { return (idx >= 0 && idx < Items.Count) ? Items[idx] : ""; } }
    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnClick(EventArgs e) {
      base.OnClick(e);
      ContextMenuStrip m = new ContextMenuStrip();
      m.Renderer = new DarkRenderer(); m.ShowImageMargin = false; m.ShowCheckMargin = false;
      m.BackColor = Color.FromArgb(12, 18, 41); m.ForeColor = Color.FromArgb(236, 236, 236); m.Font = Fnt.S(9f);
      m.MinimumSize = new Size(Width, 0);
      for (int i = 0; i < Items.Count; i++) {
        int k = i;
        ToolStripMenuItem mi = new ToolStripMenuItem((k == idx ? "\u2022  " : "    ") + Items[i]);
        mi.ForeColor = Color.FromArgb(236, 236, 236);
        mi.Padding = new Padding(2, 5, 2, 5);
        mi.Click += delegate { SelectedIndex = k; };
        m.Items.Add(mi);
      }
      m.Closed += delegate { try { BeginInvoke((MethodInvoker)delegate { m.Dispose(); }); } catch (Exception) { } };
      m.Show(this, new Point(0, Height + 3));
    }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(Under);
      RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1, Height - 1);
      G.Box(g, r, 9, hover ? Color.FromArgb(23, 32, 60) : Color.FromArgb(18, 26, 52), hover ? Color.FromArgb(61, 75, 108) : Color.FromArgb(38, 50, 82));
      G.Text(g, SelectedItem, Fnt.H(8.8f), Pal.Txt, new RectangleF(12f, 0, Width - 36f, Height), StringAlignment.Near, StringAlignment.Center, false);
      float cx = Width - 16f, cy = Height / 2f;
      using (Pen p = new Pen(Pal.Mut, 1.6f)) { p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; g.DrawLine(p, cx - 4f, cy - 1.5f, cx, cy + 2.5f); g.DrawLine(p, cx, cy + 2.5f, cx + 4f, cy - 1.5f); }
    }
  }

  // ---------------------------------------------------------------- tweak card
  public class Row : Ctl {
    public string Title = "", Desc = ""; public bool Rec, Applied, Selected; public int IconId;
    public Toggle Tog; public Drop Dd; bool hover;
    public Row() {
      Height = 86; Cursor = Cursors.Hand;
      Tog = new Toggle(); Controls.Add(Tog);
      Tog.CheckedChanged += delegate { Selected = Tog.Checked; Sync(); };
    }
    public void SetSelected(bool v) { Tog.SetInstant(v); Selected = v; Sync(); }
    public Drop AddDrop() { Dd = new Drop(); Controls.Add(Dd); PosKids(); Sync(); return Dd; }
    Color Fill() {
      Color c = Selected ? Color.FromArgb(15, 22, 46) : Pal.Card;
      return hover ? G.Mix(c, Color.FromArgb(255, 255, 255), 0.03f) : c;
    }
    void Sync() {
      Color f = Fill(); Tog.Under = f; Tog.Invalidate();
      if (Dd != null) { Dd.Under = f; Dd.Invalidate(); }
      Invalidate();
    }
    void PosKids() {
      if (Tog == null) return;
      Tog.Location = new Point(Width - 20 - Tog.Width, (Height - Tog.Height) / 2);
      if (Dd != null) Dd.Location = new Point(Tog.Left - 14 - Dd.Width, (Height - Dd.Height) / 2);
    }
    protected override void OnResize(EventArgs e) { base.OnResize(e); PosKids(); }
    protected override void OnControlAdded(ControlEventArgs e) {
      base.OnControlAdded(e);
      e.Control.MouseEnter += Kid; e.Control.MouseLeave += Kid;
    }
    void Kid(object s, EventArgs e) {
      bool h = ClientRectangle.Contains(PointToClient(Cursor.Position));
      if (h != hover) { hover = h; Sync(); }
    }
    protected override void OnMouseEnter(EventArgs e) { Kid(this, e); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { Kid(this, e); base.OnMouseLeave(e); }
    protected override void OnClick(EventArgs e) { Tog.Checked = !Tog.Checked; base.OnClick(e); }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(BackColor);
      RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1, Height - 1);
      G.Box(g, r, 14, Fill(), Selected ? Color.FromArgb(61, 75, 108) : Pal.Line);
      RectangleF t = new RectangleF(18f, (Height - 42f) / 2f, 42f, 42f);
      G.Box(g, t, 11, Color.FromArgb(18, 26, 52), Color.FromArgb(32, 43, 73));
      Ico.Draw(g, IconId, t.X + 21f, t.Y + 21f, 18f, Ico.Tint(IconId));
      float x = 76f;
      float right = ((Dd != null) ? Dd.Left : Tog.Left) - 18f;
      float avail = Math.Max(40f, right - x);
      Font tf = Fnt.H(10.5f), gf = Fnt.S(6.8f);
      float wA = 0f, wR = 0f;
      if (Applied) wA = G.TrackW(g, "ACTIVE", gf, 1.2f) + 16f;
      if (Rec) wR = G.TrackW(g, "REC", gf, 1.2f) + 16f;
      float tagW = (wA > 0 ? wA + 6f : 0f) + (wR > 0 ? wR + 6f : 0f);
      float tAvail = Math.Max(30f, avail - tagW);
      float tw = Math.Min(tAvail, g.MeasureString(Title, tf, 4000, G.TF).Width + 2f);
      G.Text(g, Title, tf, Pal.Txt, new RectangleF(x, 14f, tAvail, 22f), StringAlignment.Near, StringAlignment.Near, false);
      float tx = x + tw + 8f;
      if (wA > 0) {
        RectangleF b = new RectangleF(tx, 17f, wA, 16f);
        G.Box(g, b, 8, Color.FromArgb(30, 74, 222, 128), Color.FromArgb(100, 74, 222, 128));
        G.Track(g, "ACTIVE", gf, Pal.Ok, b.X + 8f, b.Y + 2.5f, 1.2f);
        tx += wA + 6f;
      }
      if (wR > 0) {
        RectangleF b = new RectangleF(tx, 17f, wR, 16f);
        G.Box(g, b, 8, Color.FromArgb(12, 255, 255, 255), Color.FromArgb(52, 255, 255, 255));
        G.Track(g, "REC", gf, Pal.Mut, b.X + 8f, b.Y + 2.5f, 1.2f);
      }
      G.Text(g, Desc, Fnt.S(8.5f), Color.FromArgb(102, 115, 144), new RectangleF(x, 39f, avail, 34f), StringAlignment.Near, StringAlignment.Near, true);
    }
  }

  // ---------------------------------------------------------------- smooth scroll host
  public class Surf : Panel {
    public Surf() { SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint, true); BackColor = Pal.Bg; }
  }
  public class Scroll : Ctl {
    public Surf Content = new Surf(); public int Pad = 27;
    float cur, tgt; int ch = 0; Timer tm = new Timer(); bool drag, hov; int dragY; float dragCur;
    public Scroll() {
      Controls.Add(Content); tm.Interval = 15;
      tm.Tick += delegate {
        cur += (tgt - cur) * 0.24f;
        if (Math.Abs(tgt - cur) < 0.6f) { cur = tgt; tm.Stop(); }
        Apply();
      };
    }
    protected override void Dispose(bool d) { if (d) tm.Dispose(); base.Dispose(d); }
    float Max() { return Math.Max(0, ch - Height); }
    void Clamp() { float m = Max(); if (tgt > m) tgt = m; if (tgt < 0) tgt = 0; if (cur > m) cur = m; if (cur < 0) cur = 0; }
    void Apply() { Content.Top = -(int)Math.Round(cur); Invalidate(new Rectangle(Width - 14, 0, 14, Height)); }
    public void SetContentHeight(int h) { ch = h; Content.Height = h; Clamp(); Relayout(); Apply(); }
    public void ScrollToTop() { cur = 0; tgt = 0; Apply(); }
    public void Relayout() {
      Content.SetBounds(0, -(int)Math.Round(cur), Math.Max(0, Width - 14), ch);
      foreach (Control c in Content.Controls) { c.Left = Pad; c.Width = Math.Max(10, Content.Width - Pad * 2); }
    }
    public void Wheel(int delta) {
      if (Max() <= 0) return;
      tgt -= delta * 0.9f; Clamp(); tm.Start();
    }
    protected override void OnResize(EventArgs e) { base.OnResize(e); Clamp(); Relayout(); Invalidate(); }
    static Rectangle Wide(Rectangle r) { Rectangle x = r; x.Inflate(6, 0); return x; }
    Rectangle Thumb() {
      float m = Max(); if (m <= 0 || ch <= 0) return Rectangle.Empty;
      int h = Math.Max(36, (int)((long)Height * Height / ch));
      int y = (int)((Height - h) * (cur / m));
      return new Rectangle(Width - 9, y, 5, h);
    }
    protected override void OnMouseDown(MouseEventArgs e) {
      Rectangle t = Thumb();
      if (t.IsEmpty) return;
      if (Wide(t).Contains(e.Location)) { drag = true; dragY = e.Y; dragCur = cur; }
      else { tgt = Max() * Math.Min(1f, Math.Max(0f, (float)e.Y / Height)); tm.Start(); }
      base.OnMouseDown(e);
    }
    protected override void OnMouseMove(MouseEventArgs e) {
      bool h = !Thumb().IsEmpty && Wide(Thumb()).Contains(e.Location);
      if (h != hov) { hov = h; Invalidate(); }
      if (drag) {
        Rectangle t = Thumb(); float room = Math.Max(1, Height - t.Height);
        cur = tgt = dragCur + (e.Y - dragY) * (Max() / room); Clamp(); Apply();
      }
      base.OnMouseMove(e);
    }
    protected override void OnMouseUp(MouseEventArgs e) { drag = false; base.OnMouseUp(e); }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(BackColor);
      Rectangle t = Thumb();
      if (!t.IsEmpty) G.Box(g, t, 2.5f, (drag || hov) ? Color.FromArgb(98, 111, 141) : Color.FromArgb(41, 54, 86), Color.Empty);
    }
  }

  // wheel routing: scroll whichever Scroll / TextBox is under the cursor, no focus needed
  public class WheelFilter : IMessageFilter {
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point p);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
    public bool PreFilterMessage(ref Message m) {
      if (m.Msg != 0x020A) return false;
      try {
        Control c = Control.FromHandle(WindowFromPoint(Cursor.Position));
        int delta = unchecked((short)(((long)m.WParam >> 16) & 0xFFFF));
        while (c != null) {
          Scroll s = c as Scroll;
          if (s != null) { s.Wheel(delta); return true; }
          TextBox tb = c as TextBox;
          if (tb != null) { SendMessage(tb.Handle, 0x020A, m.WParam, m.LParam); return true; }
          c = c.Parent;
        }
      } catch (Exception) { }
      return false;
    }
  }

  // ---------------------------------------------------------------- section caption, page header, action bar
  public class Sec : Ctl {
    public bool Line = true;
    public Sec() { Height = 34; }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(BackColor);
      Font f = Fnt.H(7.5f);
      float w = G.TrackW(g, Text, f, 1.6f);
      G.Track(g, Text, f, Pal.Dim, 2f, Height - 20f, 1.6f);
      if (Line) using (Pen p = new Pen(Color.FromArgb(24, 255, 255, 255), 1f)) g.DrawLine(p, w + 16f, Height - 14f, Width - 2f, Height - 14f);
    }
  }

  public class Head : Ctl {
    public string Title = "", Sub = ""; public List<Control> RightItems = new List<Control>();
    public Head() { Height = 84; }
    protected override void OnResize(EventArgs e) { base.OnResize(e); Lay(); }
    public void Lay() {
      int x = Width - 27;
      foreach (Control c in RightItems) { x -= c.Width; c.Location = new Point(x, 28); x -= 8; }
    }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(BackColor);
      G.DrawHead(g, Width, Title, Sub);
    }
  }

  public class ActBar : Ctl {
    public List<Control> LeftItems = new List<Control>(), RightItems = new List<Control>();
    public ActBar() { Height = 74; }
    protected override void OnResize(EventArgs e) { base.OnResize(e); Lay(); }
    public void Lay() {
      int x = 27;
      foreach (Control c in LeftItems) { c.Location = new Point(x, (Height - c.Height) / 2); x += c.Width + 10; }
      x = Width - 27;
      foreach (Control c in RightItems) { x -= c.Width; c.Location = new Point(x, (Height - c.Height) / 2); x -= 10; }
    }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; g.Clear(BackColor);
      using (Pen p = new Pen(Color.FromArgb(20, 28, 55), 1f)) g.DrawLine(p, 0, 0, Width, 0);
    }
  }

  // ---------------------------------------------------------------- title bar (brand / status pill / user chip / window buttons)
  public class TopBar : Ctl {
    public string Brand = "HEE", Ver = "", Status = "SYSTEM READY", User = "USER", Role = "Administrator";
    public Color StatusColor = Color.FromArgb(98, 111, 141);
    public Image Logo; public bool Maxed; public int SideW = 216;
    public event EventHandler MinClick, MaxClick, CloseClick;
    Rectangle[] bt = new Rectangle[3]; int hot = -1;
    public TopBar() { Height = 41; BackColor = Color.FromArgb(6, 10, 29); }
    public void SetStatus(string s, Color c) { Status = s; StatusColor = c; Invalidate(); }
    void Lay() { int w = 46; bt[2] = new Rectangle(Width - w, 0, w, Height - 1); bt[1] = new Rectangle(Width - 2 * w, 0, w, Height - 1); bt[0] = new Rectangle(Width - 3 * w, 0, w, Height - 1); }
    protected override void OnResize(EventArgs e) { Lay(); base.OnResize(e); }
    int Hit(Point p) { Lay(); for (int i = 0; i < 3; i++) if (bt[i].Contains(p)) return i; return -1; }
    protected override void OnMouseMove(MouseEventArgs e) { int h = Hit(e.Location); if (h != hot) { hot = h; Cursor = (h >= 0) ? Cursors.Hand : Cursors.Default; Invalidate(); } base.OnMouseMove(e); }
    protected override void OnMouseLeave(EventArgs e) { if (hot != -1) { hot = -1; Invalidate(); } base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) {
      base.OnMouseDown(e);
      if (e.Button != MouseButtons.Left) return;
      int h = Hit(e.Location);
      EventHandler ev = null;
      if (h == 0) ev = MinClick; else if (h == 1) ev = MaxClick; else if (h == 2) ev = CloseClick;
      if (h >= 0) { if (ev != null) ev(this, EventArgs.Empty); return; }
      Form f = FindForm(); if (f != null && f.WindowState == FormWindowState.Normal) Native.Drag(f.Handle);
    }
    protected override void OnMouseDoubleClick(MouseEventArgs e) {
      base.OnMouseDoubleClick(e);
      if (Hit(e.Location) < 0 && MaxClick != null) MaxClick(this, EventArgs.Empty);
    }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(BackColor);
      Lay();
      using (Pen p = new Pen(Color.FromArgb(21, 30, 58), 1f)) {
        g.DrawLine(p, 0, Height - 1, Width, Height - 1);
        g.DrawLine(p, SideW, 0, SideW, Height - 1);
      }
      // brand
      if (Logo != null) {
        try { g.DrawImage(Logo, new Rectangle(14, 5, 30, 30)); } catch (Exception) { }
      } else {
        G.Box(g, new RectangleF(14, 5, 30, 30), 8, Color.FromArgb(17, 25, 51), Color.FromArgb(36, 48, 80));
      }
      G.Track(g, Brand, Fnt.H(11f), Pal.Txt, 54f, 6f, 1.8f);
      G.Text(g, Ver, Fnt.S(7f), Pal.Dim, new RectangleF(54f, 23f, SideW - 60f, 12f), StringAlignment.Near, StringAlignment.Near, false);
      // status pill
      Font pf = Fnt.H(7.2f);
      float pw = G.TrackW(g, Status, pf, 1.4f) + 38f;
      RectangleF pr = new RectangleF(SideW + 19f, 8f, pw, 25f);
      G.Box(g, pr, 9, Color.FromArgb(11, 16, 39), Color.FromArgb(29, 39, 69));
      using (SolidBrush b = new SolidBrush(StatusColor)) g.FillEllipse(b, pr.X + 12f, pr.Y + 10f, 5f, 5f);
      G.Track(g, Status, pf, Color.FromArgb(134, 144, 164), pr.X + 24f, pr.Y + 7.5f, 1.4f);
      // user chip
      float right = bt[0].X - 18f;
      Font nf = Fnt.H(8.2f), rf = Fnt.S(7f);
      float nw = Math.Max(g.MeasureString(User, nf, 1000, G.TF).Width, g.MeasureString(Role, rf, 1000, G.TF).Width);
      float tx = right - nw;
      G.Text(g, User, nf, Pal.Txt, new RectangleF(tx, 7f, nw + 6f, 15f), StringAlignment.Near, StringAlignment.Near, false);
      G.Text(g, Role, rf, Pal.Dim, new RectangleF(tx, 22f, nw + 6f, 12f), StringAlignment.Near, StringAlignment.Near, false);
      RectangleF av = new RectangleF(tx - 40f, 6f, 28f, 28f);
      G.Box(g, av, 14, Color.FromArgb(16, 23, 48), Color.FromArgb(33, 44, 75));
      Ico.Draw(g, 16, av.X + 14f, av.Y + 14f, 15f, Pal.Soft);
      using (SolidBrush b = new SolidBrush(Pal.Side)) g.FillEllipse(b, av.Right - 8f, av.Bottom - 8f, 9f, 9f);
      using (SolidBrush b = new SolidBrush(Pal.Ok)) g.FillEllipse(b, av.Right - 6.5f, av.Bottom - 6.5f, 6f, 6f);
      // window buttons
      for (int i = 0; i < 3; i++) {
        if (hot == i) using (SolidBrush b = new SolidBrush(i == 2 ? Color.FromArgb(196, 43, 58) : Color.FromArgb(20, 28, 55))) g.FillRectangle(b, bt[i]);
        float cx = bt[i].X + bt[i].Width / 2f, cy = bt[i].Y + bt[i].Height / 2f;
        using (Pen p = new Pen(hot == i ? Color.White : Color.FromArgb(161, 166, 178), 1.2f)) {
          g.SmoothingMode = SmoothingMode.None;
          if (i == 0) g.DrawLine(p, cx - 5, cy + 0.5f, cx + 5, cy + 0.5f);
          else if (i == 1) {
            if (Maxed) { g.DrawRectangle(p, cx - 5, cy - 2, 7, 7); g.DrawLine(p, cx - 2, cy - 5, cx + 5, cy - 5); g.DrawLine(p, cx + 5, cy - 5, cx + 5, cy + 2); }
            else g.DrawRectangle(p, cx - 5, cy - 5, 10, 10);
          }
          g.SmoothingMode = SmoothingMode.AntiAlias;
          if (i == 2) { g.DrawLine(p, cx - 5, cy - 5, cx + 5, cy + 5); g.DrawLine(p, cx + 5, cy - 5, cx - 5, cy + 5); }
        }
      }
    }
  }

  // ---------------------------------------------------------------- generic rounded container + info card
  public class Card : Panel {
    public Color Fill = Pal.Card;
    public Card() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      BackColor = Pal.Bg; Padding = new Padding(18);
    }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(BackColor);
      G.Box(g, new RectangleF(0.5f, 0.5f, Width - 1, Height - 1), 14, Fill, Pal.Line);
    }
  }

  public class InfoCard : Ctl {
    public string Heading = "", Tagline = ""; public List<string[]> Lines = new List<string[]>();
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(BackColor);
      G.Box(g, new RectangleF(0.5f, 0.5f, Width - 1, Height - 1), 14, Pal.Card, Pal.Line);
      G.Track(g, Heading, Fnt.H(15f), Pal.Txt, 26f, 22f, 1.6f);
      G.Text(g, Tagline, Fnt.S(9f), Pal.Mut, new RectangleF(26f, 52f, Width - 52f, 18f), StringAlignment.Near, StringAlignment.Near, false);
      float y = 88f;
      using (Pen p = new Pen(Color.FromArgb(30, 255, 255, 255), 1f)) g.DrawLine(p, 26f, y - 8f, Width - 26f, y - 8f);
      foreach (string[] l in Lines) {
        G.Track(g, l[0].ToUpper(), Fnt.H(7f), Pal.Dim, 26f, y + 3f, 1.4f);
        G.Text(g, l[1], Fnt.S(9.5f), Color.FromArgb(222, 222, 222), new RectangleF(172f, y - 1f, Math.Max(20f, Width - 172f - 26f), 20f), StringAlignment.Near, StringAlignment.Near, false);
        y += 32f;
      }
    }
  }

  // ---------------------------------------------------------------- license / key screen
  public class IconBtn : Ctl {
    public int Icon; bool hover, down;
    public IconBtn() { Cursor = Cursors.Hand; Size = new Size(34, 34); }
    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { down = true; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(G.Back(this));
      RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1, Height - 1);
      G.Box(g, r, 10, down ? Color.FromArgb(20, 28, 55) : (hover ? Color.FromArgb(16, 23, 48) : Color.FromArgb(10, 15, 36)), hover ? Color.FromArgb(57, 71, 104) : Color.FromArgb(27, 37, 67));
      Ico.Draw(g, Icon, Width / 2f, Height / 2f, 15f, hover ? Pal.Txt : Pal.Mut);
    }
  }

  public class Login : Ctl {
    public Image Logo; public string Brand = "HEE", Sub = "", Footer = "", Msg = "", RememberText = "REMEMBER THIS PC";
    public Color MsgColor = Pal.Bad; public bool KeyFocus, Caps, Reveal;
    public int State;   // 0 idle, 1 invalid key, 2 access granted, 3 locked (too many attempts)
    public Rectangle BoxRect = new Rectangle(30, 196, 294, 44);
    public TextBox Edit; public int EditLeft = 70;
    public event EventHandler CloseClick, EyeClick, PasteClick, RememberClick, SuccessDone;
    Rectangle cl = new Rectangle(322, 8, 24, 24);
    bool hotClose, hotEye, hotPaste, hotRem;
    float shake, phase, grant; int shakeN = -1, grantN; bool doneFired;
    Timer tm = new Timer();
    public Login() {
      BackColor = Pal.Bg;
      tm.Interval = 30;
      tm.Tick += delegate {
        phase += 0.07f; if (phase > 6.2832f) phase -= 6.2832f;
        if (shakeN >= 0) {
          shakeN++;
          if (shakeN > 18) { shakeN = -1; shake = 0f; }
          else shake = (float)(Math.Sin(shakeN * 1.7) * 9.0 * (1.0 - shakeN / 18.0));
          if (Edit != null) Edit.Left = EditLeft + (int)shake;
        }
        if (State == 2) {
          grantN++; grant = Math.Min(1f, grantN / 14f);
          if (grantN >= 30 && !doneFired) { doneFired = true; EventHandler h = SuccessDone; if (h != null) h(this, EventArgs.Empty); }
        }
        Invalidate();
      };
      tm.Start();
    }
    protected override void Dispose(bool d) { if (d) tm.Dispose(); base.Dispose(d); }
    Rectangle EyeR { get { return new Rectangle(BoxRect.Right - 54 + (int)shake, BoxRect.Y + 11, 22, 22); } }
    Rectangle PasteR { get { return new Rectangle(BoxRect.Right - 30 + (int)shake, BoxRect.Y + 11, 22, 22); } }
    Rectangle RemR { get { return new Rectangle(76, 272, 180, 26); } }

    public void Shake() { shakeN = 0; }
    public void Succeed() { State = 2; grantN = 0; grant = 0f; doneFired = false; Invalidate(); }
    public void Reset() { if (State == 0 || State == 1) { State = 0; Msg = ""; } Invalidate(); }

    protected override void OnMouseMove(MouseEventArgs e) {
      bool c = cl.Contains(e.Location), ey = EyeR.Contains(e.Location), pa = PasteR.Contains(e.Location), rm = RemR.Contains(e.Location);
      if (c != hotClose || ey != hotEye || pa != hotPaste || rm != hotRem) {
        hotClose = c; hotEye = ey; hotPaste = pa; hotRem = rm;
        Cursor = (c || ey || pa || rm) ? Cursors.Hand : Cursors.Default; Invalidate();
      }
      base.OnMouseMove(e);
    }
    protected override void OnMouseLeave(EventArgs e) {
      hotClose = hotEye = hotPaste = hotRem = false; Cursor = Cursors.Default; Invalidate(); base.OnMouseLeave(e);
    }
    protected override void OnMouseDown(MouseEventArgs e) {
      base.OnMouseDown(e);
      if (e.Button != MouseButtons.Left) return;
      if (State != 2) {
        if (cl.Contains(e.Location)) { if (CloseClick != null) CloseClick(this, EventArgs.Empty); return; }
        if (EyeR.Contains(e.Location)) { if (EyeClick != null) EyeClick(this, EventArgs.Empty); return; }
        if (PasteR.Contains(e.Location)) { if (PasteClick != null) PasteClick(this, EventArgs.Empty); return; }
        if (RemR.Contains(e.Location)) { if (RememberClick != null) RememberClick(this, EventArgs.Empty); return; }
      }
      Form f = FindForm(); if (f != null) Native.Drag(f.Handle);
    }

    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g);
      using (LinearGradientBrush lb = new LinearGradientBrush(new Rectangle(0, 0, Width, Height), Color.FromArgb(14, 20, 44), Color.FromArgb(5, 7, 25), 90f)) g.FillRectangle(lb, 0, 0, Width, Height);
      float cx = Width / 2f, cy = 66f;
      Color accent = (State == 2) ? Pal.Ok : (State == 1 ? Pal.Bad : (State == 3 ? Pal.Warn : Color.FromArgb(96, 165, 250)));
      // soft glow behind the logo (tints with the current state)
      using (GraphicsPath gp = new GraphicsPath()) {
        gp.AddEllipse(cx - 92f, cy - 92f, 184f, 184f);
        using (PathGradientBrush pg = new PathGradientBrush(gp)) {
          pg.CenterColor = Color.FromArgb(State == 0 ? 34 : 46, accent.R, accent.G, accent.B); pg.SurroundColors = new Color[] { Color.FromArgb(0, accent.R, accent.G, accent.B) };
          g.FillPath(pg, gp);
        }
      }
      // breathing ring
      float pr = 53f + (float)Math.Sin(phase) * 2.5f; int pa = 22 + (int)(Math.Sin(phase) * 10.0);
      using (Pen p = new Pen(Color.FromArgb(pa, accent.R, accent.G, accent.B), 1f)) g.DrawEllipse(p, cx - pr, cy - pr, pr * 2f, pr * 2f);
      // success ripple
      if (State == 2 && grant < 1f) {
        float rr = 48f + grant * 30f;
        using (Pen p = new Pen(Color.FromArgb((int)(170f * (1f - grant)), Pal.Ok), 1.5f)) g.DrawEllipse(p, cx - rr, cy - rr, rr * 2f, rr * 2f);
      }
      using (Pen p = new Pen(Color.FromArgb(29, 39, 69), 1f)) g.DrawEllipse(p, cx - 48f, cy - 48f, 96f, 96f);
      using (SolidBrush b = new SolidBrush(Color.FromArgb(3, 5, 22))) g.FillEllipse(b, cx - 42f, cy - 42f, 84f, 84f);
      using (Pen p = new Pen(G.Mix(Color.FromArgb(55, 69, 102), Pal.Ok, grant), 1.5f)) g.DrawEllipse(p, cx - 42f, cy - 42f, 84f, 84f);
      if (Logo != null) { try { g.DrawImage(Logo, new RectangleF(cx - 36f, cy - 36f, 72f, 72f)); } catch (Exception) { } }
      Color dot = (State == 0) ? Color.FromArgb(230, 255, 255, 255) : accent;
      using (SolidBrush b = new SolidBrush(dot)) g.FillEllipse(b, cx + 40f, cy - 14f, 5f, 5f);

      Font tf = Fnt.H(17f); float tw = G.TrackW(g, Brand, tf, 34f);
      G.Track(g, Brand, tf, Pal.Txt, cx - tw / 2f, 122f, 34f);
      Font sf = Fnt.S(7.8f); float sw = G.TrackW(g, Sub, sf, 8f) + 14f;
      float sx = cx - sw / 2f;
      using (Pen p = new Pen(Pal.Dim, 1f)) g.DrawEllipse(p, sx, 159f, 6f, 6f);
      G.Track(g, Sub, sf, Pal.Dim, sx + 14f, 155f, 8f);

      // field label
      G.Track(g, "LICENSE KEY", Fnt.H(7.8f), Pal.Dim, 32f, 178f, 5f);

      // key box (shakes on a wrong key)
      float ox = shake;
      RectangleF br = new RectangleF(BoxRect.X + 0.5f + ox, BoxRect.Y + 0.5f, BoxRect.Width - 1, BoxRect.Height - 1);
      Color bl = Color.FromArgb(29, 39, 69);
      if (State == 1) bl = Color.FromArgb(150, 58, 58);
      else if (State == 2) bl = Color.FromArgb(60, 150, 90);
      else if (State == 3) bl = Color.FromArgb(140, 110, 40);
      else if (KeyFocus) bl = Color.FromArgb(59, 130, 246);
      if (KeyFocus && State == 0) G.Box(g, new RectangleF(br.X - 2f, br.Y - 2f, br.Width + 4f, br.Height + 4f), 14, Color.Empty, Color.FromArgb(24, 255, 255, 255));
      G.Box(g, br, 12, Color.FromArgb(4, 6, 24), bl);
      float ix = BoxRect.X + 24f + ox, iy = BoxRect.Y + BoxRect.Height / 2f;
      if (State == 2) Ico.Draw(g, 22, ix, iy, 15f, Pal.Ok);
      else if (State == 3) Ico.Draw(g, 24, ix, iy, 15f, Pal.Warn);
      else if (State == 1) Ico.Draw(g, 19, ix, iy, 15f, Pal.Bad);
      else Ico.Draw(g, 19, ix, iy, 15f, KeyFocus ? Pal.Soft : Pal.Dim);
      Rectangle er = EyeR, prc = PasteR;
      Ico.Draw(g, Reveal ? 20 : 21, er.X + 11f, er.Y + 11f, 14f, hotEye ? Pal.Txt : Pal.Dim);
      Ico.Draw(g, 23, prc.X + 11f, prc.Y + 11f, 14f, hotPaste ? Pal.Txt : Pal.Dim);

      // status line
      string m = Msg; Color mc = MsgColor;
      if (string.IsNullOrEmpty(m) && Caps) { m = "CAPS LOCK IS ON"; mc = Pal.Warn; }
      G.Text(g, m, Fnt.S(8f), mc, new RectangleF(30f, 244f, Width - 60f, 18f), StringAlignment.Center, StringAlignment.Center, false);

      // remember switch label (the switch itself is a child control at x=30)
      G.Track(g, RememberText, Fnt.H(7.8f), hotRem ? Pal.Soft : Pal.Mut, 80f, 278f, 3f);

      float dy = 382f;
      using (Pen p = new Pen(Color.FromArgb(28, 255, 255, 255), 1f)) { g.DrawLine(p, 30f, dy, cx - 40f, dy); g.DrawLine(p, cx + 40f, dy, Width - 30f, dy); }
      G.Text(g, Footer, Fnt.S(7.8f), Pal.Dim, new RectangleF(cx - 40f, dy - 8f, 80f, 16f), StringAlignment.Center, StringAlignment.Center, false);
      G.Track(g, "CONTACT", Fnt.H(7.8f), Pal.Dim, 30f, 398f, 6f);
      using (Pen p = new Pen(hotClose ? Pal.Txt : Pal.Dim, 1.3f)) {
        g.DrawLine(p, cl.X + 8, cl.Y + 8, cl.Right - 8, cl.Bottom - 8); g.DrawLine(p, cl.Right - 8, cl.Y + 8, cl.X + 8, cl.Bottom - 8);
      }
      using (Pen p = new Pen(Color.FromArgb(36, 48, 80), 1f)) g.DrawRectangle(p, 0, 0, Width - 1, Height - 1);
    }
  }

  // ---------------------------------------------------------------- dashboard (single owner-drawn surface, live CPU / RAM)
  public class HwItem {
    public int Icon; public string Label = "", Value = "", Sub = "", Right = ""; public float Pct = -1f;
    public int Live; // 1 = memory, 2 = system drive
  }

  public class Dash : Ctl {
    public string CpuName = "CPU", CpuSub = "", Cores = "-", Clock = "-", Arch = "-", Os = "-";
    public List<HwItem> Items = new List<HwItem>();
    public Image Backdrop; public float CpuPct = -1f;
    const int HistN = 60;
    List<float> hist = new List<float>(); float shown; bool dirty = true; int last; int ticks;
    Bitmap bgc; Size bgs; Timer tm = new Timer(); string driveRoot = "C:\\";

    public Dash() {
      tm.Interval = 40;
      tm.Tick += delegate {
        int now = Environment.TickCount;
        if (now - last >= 1000) { last = now; Sample(); }
        float t = CpuPct < 0f ? 0f : CpuPct;
        if (Math.Abs(shown - t) > 0.05f) { shown += (t - shown) * 0.18f; dirty = true; } else if (shown != t) { shown = t; dirty = true; }
        if (dirty && Visible) { dirty = false; Invalidate(); }
      };
      try { driveRoot = Path.GetPathRoot(Environment.SystemDirectory); } catch (Exception) { }
    }
    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); last = Environment.TickCount; Sample(); tm.Start(); }
    protected override void OnHandleDestroyed(EventArgs e) { tm.Stop(); base.OnHandleDestroyed(e); }
    protected override void Dispose(bool d) { if (d) { tm.Dispose(); if (bgc != null) bgc.Dispose(); } base.Dispose(d); }
    protected override void OnVisibleChanged(EventArgs e) { base.OnVisibleChanged(e); dirty = true; if (Visible) Invalidate(); }

    public void Sample() {
      double c = Native.CpuLoad();
      if (c >= 0) { CpuPct = (float)c; hist.Add(CpuPct); if (hist.Count > HistN) hist.RemoveAt(0); }
      ticks++;
      foreach (HwItem it in Items) {
        if (it.Live == 1) {
          double[] m = Native.MemInfo();
          if (m != null) {
            it.Value = string.Format(CultureInfo.InvariantCulture, "{0:0.0} / {1:0.0} GB", m[1], m[0]);
            it.Pct = (float)m[2]; it.Sub = ((int)Math.Round(m[2])).ToString(CultureInfo.InvariantCulture) + "% used";
          }
        } else if (it.Live == 2 && (ticks % 15 == 1 || it.Pct < 0)) {
          try {
            DriveInfo d = new DriveInfo(driveRoot);
            double tot = d.TotalSize / 1073741824.0, used = (d.TotalSize - d.TotalFreeSpace) / 1073741824.0;
            it.Value = string.Format(CultureInfo.InvariantCulture, "{0:0.0} / {1:0} GB", used, tot);
            it.Pct = (float)(used * 100.0 / tot); it.Sub = ((int)Math.Round(it.Pct)).ToString(CultureInfo.InvariantCulture) + "% used";
            it.Label = "STORAGE " + driveRoot.Substring(0, 2);
          } catch (Exception) { }
        }
      }
      dirty = true;
    }

    void EnsureBg() {
      if (Backdrop == null || Width < 2 || Height < 2) return;
      if (bgc != null && bgs.Width == Width && bgs.Height == Height) return;
      if (bgc != null) bgc.Dispose();
      bgc = new Bitmap(Width, Height); bgs = new Size(Width, Height);
      using (Graphics g = Graphics.FromImage(bgc)) {
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.Clear(Pal.Bg);
        float sc = Math.Max((float)Width / Backdrop.Width, (float)Height / Backdrop.Height);
        float w = Backdrop.Width * sc, h = Backdrop.Height * sc;
        g.DrawImage(Backdrop, (Width - w) / 2f, (Height - h) / 2f, w, h);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(214, 8, 8, 8))) g.FillRectangle(b, 0, 0, Width, Height);
        using (LinearGradientBrush lb = new LinearGradientBrush(new Rectangle(0, 0, Width, Height), Color.FromArgb(0, 0, 0, 0), Color.FromArgb(120, 0, 0, 0), 90f)) g.FillRectangle(lb, 0, 0, Width, Height);
      }
    }

    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics;
      if (Width < 50 || Height < 50) return;
      G.Smooth(g);
      if (Backdrop != null) { EnsureBg(); g.DrawImageUnscaled(bgc, 0, 0); }
      else using (LinearGradientBrush lb = new LinearGradientBrush(new Rectangle(0, 0, Width, Height), Color.FromArgb(8, 12, 33), Color.FromArgb(5, 7, 25), 90f)) g.FillRectangle(lb, 0, 0, Width, Height);
      G.DrawHead(g, Width, "DASHBOARD", "Realtime system overview");
      float top = 104f, bot = Height - 24f, gap = 15f, x0 = 27f, x1 = Width - 23f;
      float cw = (x1 - x0 - gap) / 2f;
      RectangleF L = new RectangleF(x0, top, cw, bot - top), R = new RectangleF(x0 + cw + gap, top, cw, bot - top);
      Color fill = Color.FromArgb(Backdrop != null ? 232 : 255, 20, 20, 20), ln = Color.FromArgb(30, 41, 71);
      G.Box(g, L, 16, fill, ln); G.Box(g, R, 16, fill, ln);
      DrawCpu(g, L); DrawHw(g, R);
    }

    void DrawCpu(Graphics g, RectangleF L) {
      float px = L.X + 22f, pr = L.Right - 22f;
      G.Track(g, "PROCESSOR", Fnt.H(7.2f), Pal.Dim, px, L.Y + 22f, 1.8f);
      float ring = 87f;
      RectangleF rr = new RectangleF(pr - ring, L.Y + 22f, ring, ring);
      float tw = rr.X - px - 14f;
      G.Text(g, CpuName, Fnt.H(12.5f), Pal.Txt, new RectangleF(px, L.Y + 40f, tw, 24f), StringAlignment.Near, StringAlignment.Near, false);
      G.Text(g, CpuSub, Fnt.S(8.5f), Pal.Mut, new RectangleF(px, L.Y + 68f, tw, 18f), StringAlignment.Near, StringAlignment.Near, false);
      // ring gauge
      RectangleF ri = new RectangleF(rr.X + 3f, rr.Y + 3f, rr.Width - 6f, rr.Height - 6f);
      using (Pen p = new Pen(Color.FromArgb(21, 30, 58), 5f)) g.DrawEllipse(p, ri);
      if (CpuPct >= 0f && shown > 0.3f)
        using (Pen p = new Pen(Color.FromArgb(240, 240, 240), 5f)) { p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; g.DrawArc(p, ri, -90f, 360f * Math.Min(100f, shown) / 100f); }
      string pc = (CpuPct >= 0f) ? ((int)Math.Round(shown)).ToString(CultureInfo.InvariantCulture) + "%" : "-";
      G.Text(g, pc, Fnt.H(16f), Pal.Txt, new RectangleF(rr.X, rr.Y + rr.Height / 2f - 22f, rr.Width, 28f), StringAlignment.Center, StringAlignment.Center, false);
      Font uf = Fnt.H(6.6f); float uw = G.TrackW(g, "USAGE", uf, 1.6f);
      G.Track(g, "USAGE", uf, Pal.Dim, rr.X + (rr.Width - uw) / 2f, rr.Y + rr.Height / 2f + 9f, 1.6f);
      // layout from the bottom
      float t2 = L.Bottom - 16f - 42f, t1 = t2 - 48f, sep = t1 - 14f;
      float ly = rr.Bottom + 22f;
      G.Track(g, "CPU USAGE REALTIME", Fnt.H(6.8f), Color.FromArgb(61, 75, 108), px, ly, 1.5f);
      string cur = (CpuPct >= 0f) ? ((int)Math.Round(CpuPct)).ToString(CultureInfo.InvariantCulture) + "%" : "-";
      G.Text(g, cur, Fnt.H(7.2f), Color.FromArgb(61, 75, 108), new RectangleF(px, ly - 2f, pr - px, 14f), StringAlignment.Far, StringAlignment.Near, false);
      RectangleF cr = new RectangleF(px, ly + 22f, pr - px, sep - 10f - (ly + 22f));
      if (cr.Height > 24f) DrawChart(g, cr);
      using (Pen p = new Pen(Color.FromArgb(36, 255, 255, 255), 1f)) g.DrawLine(p, px, sep, pr, sep);
      string[][] tiles = new string[][] { new string[] { "CORES", Cores }, new string[] { "CLOCK", Clock }, new string[] { "ARCH", Arch }, new string[] { "OS", Os } };
      float tww = (pr - px - 6f) / 2f;
      for (int i = 0; i < 4; i++) {
        RectangleF tr = new RectangleF(px + (i % 2) * (tww + 6f), (i < 2) ? t1 : t2, tww, 42f);
        G.Box(g, tr, 9, Color.FromArgb(13, 19, 42), Color.FromArgb(26, 35, 64));
        G.Track(g, tiles[i][0], Fnt.H(6.4f), Color.FromArgb(64, 79, 112), tr.X + 11f, tr.Y + 8f, 1.4f);
        G.Text(g, tiles[i][1], Fnt.M(9f), Pal.Txt, new RectangleF(tr.X + 11f, tr.Y + 20f, tr.Width - 20f, 18f), StringAlignment.Near, StringAlignment.Near, false);
      }
    }

    void DrawChart(Graphics g, RectangleF cr) {
      using (Pen gp = new Pen(Color.FromArgb(14, 255, 255, 255), 1f))
        for (int i = 1; i <= 3; i++) g.DrawLine(gp, cr.X, cr.Y + cr.Height * i / 4f, cr.Right, cr.Y + cr.Height * i / 4f);
      if (hist.Count < 2) return;
      PointF[] pts = new PointF[hist.Count];
      for (int i = 0; i < pts.Length; i++) {
        float x = cr.X + cr.Width * (HistN - hist.Count + i) / (float)(HistN - 1);
        float v = Math.Min(100f, Math.Max(0f, hist[i]));
        pts[i] = new PointF(x, cr.Bottom - 1f - (cr.Height - 3f) * v / 100f);
      }
      GraphicsState st = g.Save();
      g.SetClip(cr);
      using (GraphicsPath ap = new GraphicsPath()) {
        ap.AddCurve(pts, 0.3f);
        ap.AddLine(pts[pts.Length - 1], new PointF(pts[pts.Length - 1].X, cr.Bottom));
        ap.AddLine(new PointF(pts[pts.Length - 1].X, cr.Bottom), new PointF(pts[0].X, cr.Bottom));
        ap.CloseFigure();
        using (LinearGradientBrush lb = new LinearGradientBrush(cr, Color.FromArgb(64, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f)) g.FillPath(lb, ap);
      }
      using (Pen p = new Pen(Color.FromArgb(235, 235, 235), 1.8f)) { p.LineJoin = LineJoin.Round; g.DrawCurve(p, pts, 0.3f); }
      g.Restore(st);
    }

    void DrawHw(Graphics g, RectangleF R) {
      float px = R.X + 22f, pr = R.Right - 22f;
      G.Track(g, "HARDWARE OVERVIEW", Fnt.H(8.2f), Pal.Txt, px, R.Y + 22f, 1.8f);
      float ly = R.Y + 48f;
      using (Pen p = new Pen(Color.FromArgb(30, 255, 255, 255), 1f)) g.DrawLine(p, px, ly, pr, ly);
      if (Items.Count == 0) return;
      float rowH = Math.Max(50f, Math.Min(66f, (R.Bottom - ly - 10f) / Items.Count));
      for (int i = 0; i < Items.Count; i++) {
        HwItem it = Items[i]; float ry = ly + i * rowH;
        if (i > 0) using (Pen p = new Pen(Color.FromArgb(18, 255, 255, 255), 1f)) g.DrawLine(p, px, ry, pr, ry);
        RectangleF t = new RectangleF(px, ry + (rowH - 36f) / 2f, 36f, 36f);
        G.Box(g, t, 10, Color.FromArgb(16, 23, 48), Color.FromArgb(30, 41, 71));
        Ico.Draw(g, it.Icon, t.X + 18f, t.Y + 18f, 16f, Color.FromArgb(206, 206, 206));
        float tx = px + 36f + 14f;
        float rightW = (it.Pct >= 0f) ? 84f : (it.Right.Length > 0 ? 62f : 0f);
        float avail = Math.Max(20f, pr - tx - rightW - 8f);
        float by = ry + (rowH - 40f) / 2f;
        G.Track(g, it.Label, Fnt.H(6.6f), Color.FromArgb(72, 87, 120), tx, by, 1.5f);
        G.Text(g, it.Value, Fnt.H(10.5f), Pal.Txt, new RectangleF(tx, by + 11f, avail, 18f), StringAlignment.Near, StringAlignment.Near, false);
        G.Text(g, it.Sub, Fnt.S(7.3f), Color.FromArgb(61, 75, 108), new RectangleF(tx, by + 30f, avail, 12f), StringAlignment.Near, StringAlignment.Near, false);
        if (it.Pct >= 0f) {
          string pt = ((int)Math.Round(it.Pct)).ToString(CultureInfo.InvariantCulture) + "%";
          G.Text(g, pt, Fnt.H(8.4f), Color.FromArgb(224, 224, 224), new RectangleF(pr - 84f, ry + rowH / 2f - 17f, 84f, 14f), StringAlignment.Far, StringAlignment.Near, false);
          RectangleF bar = new RectangleF(pr - 72f, ry + rowH / 2f + 3f, 72f, 3f);
          G.Box(g, bar, 1.5f, Color.FromArgb(27, 37, 67), Color.Empty);
          if (it.Pct > 0.5f) G.Box(g, new RectangleF(bar.X, bar.Y, Math.Max(3f, bar.Width * Math.Min(100f, it.Pct) / 100f), bar.Height), 1.5f, Color.FromArgb(236, 236, 236), Color.Empty);
        } else if (it.Right.Length > 0) {
          G.TrackR(g, it.Right.ToUpper(), Fnt.H(6.6f), Color.FromArgb(89, 103, 134), pr, ry + rowH / 2f - 5f, 1.3f);
        }
      }
    }
  }
}

namespace HY {
  using G = HX.G;

  // ---------------------------------------------------------------- theme
  public static class Th {
    public static Color Bg    = Color.FromArgb(6, 9, 20);
    public static Color Panel = Color.FromArgb(9, 13, 26);
    public static Color Card  = Color.FromArgb(11, 16, 30);
    public static Color Card2 = Color.FromArgb(16, 23, 43);
    public static Color Line  = Color.FromArgb(27, 38, 68);
    public static Color Acc   = Color.FromArgb(37, 99, 235);
    public static Color AccHi = Color.FromArgb(96, 165, 250);
    public static Color AccLo = Color.FromArgb(29, 78, 216);
    public static Color Txt   = Color.FromArgb(236, 242, 252);
    public static Color Soft  = Color.FromArgb(178, 192, 218);
    public static Color Mut   = Color.FromArgb(118, 134, 168);
    public static Color Dim   = Color.FromArgb(78, 92, 124);
    public static Color Ok    = Color.FromArgb(52, 211, 153);
    public static Color Warn  = Color.FromArgb(250, 190, 60);
    public static Color Bad   = Color.FromArgb(248, 113, 113);
  }

  // ---------------------------------------------------------------- fonts (Thai capable)
  public static class Fx {
    static Dictionary<string, Font> cache = new Dictionary<string, Font>();
    static string fam;
    static string logo;
    static string Pick(string[] names) {
      foreach (string n in names) { try { using (FontFamily f = new FontFamily(n)) { return n; } } catch (Exception) { } }
      return "Segoe UI";
    }
    public static string Override = "";
    public static string Family {
      get {
        if (fam == null) {
          string o = (Override ?? "").Trim();
          if (o.Length > 0 && !o.Equals("Auto", StringComparison.OrdinalIgnoreCase)) { try { using (FontFamily f = new FontFamily(o)) { fam = o; } } catch (Exception) { } }
          if (fam == null) fam = Pick(new string[] { "Noto Sans Thai UI", "Noto Sans Thai", "IBM Plex Sans Thai", "Sarabun", "Leelawadee UI", "Tahoma", "Segoe UI" });
        }
        return fam;
      }
    }
    public static string LogoFamily { get { if (logo == null) logo = Pick(new string[] { "Impact", "Segoe UI Black", "Arial Black", "Segoe UI" }); return logo; } }
    public static Font F(float pt, bool bold) {
      string key = pt.ToString(CultureInfo.InvariantCulture) + (bold ? "b" : "r");
      lock (cache) {
        Font f;
        if (!cache.TryGetValue(key, out f)) {
          FontStyle st = bold ? FontStyle.Bold : FontStyle.Regular;
          try { f = new Font(Family, pt, st, GraphicsUnit.Point); }
          catch (Exception) { f = new Font(FontFamily.GenericSansSerif, pt, st, GraphicsUnit.Point); }
          cache[key] = f;
        }
        return f;
      }
    }
  }

  // ---------------------------------------------------------------- vector icons
  public static class Ic {
    public const int Home = 0, Rocket = 1, Pad = 2, Monitor = 3, Keys = 4, Gauge = 5, Block = 6, Win = 7, Shield = 8, Gpu = 9,
                     Sliders = 10, User = 11, Cpu = 12, Ram = 13, Cam = 14, Restore = 15, Chev = 16, DChev = 17, Check = 18,
                     Menu = 19, Search = 20, Crown = 21, Bolt = 22, Log = 23;
    static PointF P(float x, float y) { return new PointF(x, y); }
    static GraphicsPath RR(float x, float y, float w, float h, float r) { return G.Round(new RectangleF(x, y, w, h), r); }

    public static void Draw(Graphics g, int id, float cx, float cy, float s, Color c) {
      GraphicsState st = g.Save();
      g.SmoothingMode = SmoothingMode.AntiAlias;
      g.TranslateTransform(cx, cy);
      float k = s / 48f;
      g.ScaleTransform(k, k);
      float pw = Math.Max(2.6f, 1.7f / k);
      using (Pen p = new Pen(c, pw))
      using (SolidBrush b = new SolidBrush(c))
      using (SolidBrush bf = new SolidBrush(Color.FromArgb((int)(c.A * 0.22f), c.R, c.G, c.B))) {
        p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; p.LineJoin = LineJoin.Round;
        switch (id) {
          case Home: {
            g.FillPolygon(b, new PointF[] { P(0, -17), P(15, -4), P(15, 19), P(5, 19), P(5, 6), P(-5, 6), P(-5, 19), P(-15, 19), P(-15, -4) });
            g.DrawLines(p, new PointF[] { P(-21, -1), P(0, -20), P(21, -1) });
            break;
          }
          case Rocket: {
            g.RotateTransform(45f);
            using (GraphicsPath body = new GraphicsPath()) {
              body.AddBezier(P(0, -22), P(11, -14), P(10, 4), P(6, 12));
              body.AddLine(P(6, 12), P(-6, 12));
              body.AddBezier(P(-6, 12), P(-10, 4), P(-11, -14), P(0, -22));
              body.CloseFigure();
              g.FillPath(bf, body); g.DrawPath(p, body);
            }
            g.DrawEllipse(p, -4f, -11f, 8f, 8f);
            g.FillPolygon(b, new PointF[] { P(-7, 3), P(-16, 14), P(-7, 11) });
            g.FillPolygon(b, new PointF[] { P(7, 3), P(16, 14), P(7, 11) });
            g.FillPolygon(b, new PointF[] { P(-4, 15), P(0, 25), P(4, 15) });
            break;
          }
          case Pad: {
            using (GraphicsPath body = new GraphicsPath()) {
              body.AddClosedCurve(new PointF[] { P(-12, -12), P(12, -12), P(20, -8), P(23, 2), P(22, 14), P(17, 18), P(11, 15), P(6, 8), P(-6, 8), P(-11, 15), P(-17, 18), P(-22, 14), P(-23, 2), P(-20, -8) }, 0.35f);
              g.FillPath(bf, body); g.DrawPath(p, body);
            }
            g.DrawLine(p, -15f, -2f, -7f, -2f); g.DrawLine(p, -11f, -6f, -11f, 2f);
            g.FillEllipse(b, 6.5f, -8f, 5f, 5f); g.FillEllipse(b, 12f, -2f, 5f, 5f);
            break;
          }
          case Monitor: {
            using (GraphicsPath sc = RR(-21, -18, 42, 28, 4)) { g.FillPath(bf, sc); g.DrawPath(p, sc); }
            g.DrawLine(p, 0f, 10f, 0f, 17f); g.DrawLine(p, -9f, 18f, 9f, 18f);
            using (Pen t = new Pen(Color.FromArgb(150, c), pw * 0.8f)) {
              t.StartCap = LineCap.Round; t.EndCap = LineCap.Round;
              g.DrawLine(t, -10f, 3f, 2f, -11f); g.DrawLine(t, -3f, 4f, 11f, -10f);
            }
            break;
          }
          case Keys: {
            using (GraphicsPath kb = RR(-22, -13, 44, 27, 5)) { g.FillPath(bf, kb); g.DrawPath(p, kb); }
            for (int i = 0; i < 6; i++) g.FillRectangle(b, -17f + i * 6.6f, -8f, 4f, 4f);
            for (int i = 0; i < 5; i++) g.FillRectangle(b, -14f + i * 6.6f, -1.5f, 4f, 4f);
            g.FillRectangle(b, -10f, 6f, 20f, 3.6f);
            break;
          }
          case Gauge: {
            g.DrawArc(p, -20f, -20f, 40f, 40f, 150f, 240f);
            for (int a = 150; a <= 390; a += 40) {
              double r = a * Math.PI / 180.0;
              g.DrawLine(p, (float)(Math.Cos(r) * 13.5), (float)(Math.Sin(r) * 13.5), (float)(Math.Cos(r) * 17), (float)(Math.Sin(r) * 17));
            }
            double na = 305 * Math.PI / 180.0;
            g.DrawLine(p, 0f, 0f, (float)(Math.Cos(na) * 14), (float)(Math.Sin(na) * 14));
            g.FillEllipse(b, -3.5f, -3.5f, 7f, 7f);
            break;
          }
          case Block: {
            using (Pen t = new Pen(c, pw * 1.35f)) {
              t.StartCap = LineCap.Round; t.EndCap = LineCap.Round;
              g.FillEllipse(bf, -18f, -18f, 36f, 36f);
              g.DrawEllipse(t, -18f, -18f, 36f, 36f);
              g.DrawLine(t, -12.5f, -12.5f, 12.5f, 12.5f);
            }
            break;
          }
          case Win: {
            g.FillPolygon(b, new PointF[] { P(-20, -14), P(-2, -17), P(-2, -2.5f), P(-20, -2.5f) });
            g.FillPolygon(b, new PointF[] { P(2, -17.5f), P(20, -21), P(20, -2.5f), P(2, -2.5f) });
            g.FillPolygon(b, new PointF[] { P(-20, 2.5f), P(-2, 2.5f), P(-2, 17), P(-20, 14) });
            g.FillPolygon(b, new PointF[] { P(2, 2.5f), P(20, 2.5f), P(20, 21), P(2, 17.5f) });
            break;
          }
          case Shield: {
            using (GraphicsPath sh = new GraphicsPath()) {
              sh.AddLine(P(0, -22), P(18, -14));
              sh.AddBezier(P(18, -14), P(18, 8), P(10, 17), P(0, 22));
              sh.AddBezier(P(0, 22), P(-10, 17), P(-18, 8), P(-18, -14));
              sh.CloseFigure();
              g.FillPath(bf, sh); g.DrawPath(p, sh);
            }
            using (Pen t = new Pen(c, pw * 1.2f)) { t.StartCap = LineCap.Round; t.EndCap = LineCap.Round; t.LineJoin = LineJoin.Round; g.DrawLines(t, new PointF[] { P(-8, 0), P(-2, 7), P(9, -6) }); }
            break;
          }
          case Gpu: {
            using (GraphicsPath cd = RR(-22, -13, 44, 25, 3)) { g.FillPath(bf, cd); g.DrawPath(p, cd); }
            g.DrawEllipse(p, -17f, -7f, 14f, 14f); g.DrawEllipse(p, 3f, -7f, 14f, 14f);
            g.FillEllipse(b, -12f, -2f, 4f, 4f); g.FillEllipse(b, 8f, -2f, 4f, 4f);
            g.FillRectangle(b, -14f, 13f, 22f, 3f);
            break;
          }
          case Sliders: {
            g.DrawLine(p, -20f, -12f, 20f, -12f); g.DrawLine(p, -20f, 0f, 20f, 0f); g.DrawLine(p, -20f, 12f, 20f, 12f);
            g.FillEllipse(b, -10.5f, -16.5f, 9f, 9f); g.FillEllipse(b, 4f, -4.5f, 9f, 9f); g.FillEllipse(b, -6.5f, 7.5f, 9f, 9f);
            break;
          }
          case User: {
            g.FillEllipse(bf, -7f, -18f, 14f, 14f); g.DrawEllipse(p, -7f, -18f, 14f, 14f);
            g.DrawArc(p, -15f, 1f, 30f, 30f, 205f, 130f);
            break;
          }
          case Cpu: {
            using (GraphicsPath ch = RR(-11, -11, 22, 22, 3)) { g.FillPath(bf, ch); g.DrawPath(p, ch); }
            g.FillRectangle(b, -4.5f, -4.5f, 9f, 9f);
            for (int i = -1; i <= 1; i++) {
              float t = i * 7f;
              g.DrawLine(p, t, -11f, t, -17f); g.DrawLine(p, t, 11f, t, 17f); g.DrawLine(p, -11f, t, -17f, t); g.DrawLine(p, 11f, t, 17f, t);
            }
            break;
          }
          case Ram: {
            using (GraphicsPath rm = RR(-22, -10, 44, 19, 3)) { g.FillPath(bf, rm); g.DrawPath(p, rm); }
            g.FillRectangle(b, -17f, -5f, 8f, 9f); g.FillRectangle(b, -5f, -5f, 8f, 9f); g.FillRectangle(b, 7f, -5f, 8f, 9f);
            for (int i = 0; i < 6; i++) g.DrawLine(p, -17f + i * 6.8f, 9f, -17f + i * 6.8f, 14f);
            break;
          }
          case Cam: {
            using (GraphicsPath cm = RR(-21, -10, 26, 20, 4)) { g.FillPath(bf, cm); g.DrawPath(p, cm); }
            g.FillPolygon(b, new PointF[] { P(10, -4), P(22, -10), P(22, 10), P(10, 4) });
            break;
          }
          case Restore: {
            g.DrawArc(p, -14f, -14f, 28f, 28f, 215f, 255f);
            double a = 215 * Math.PI / 180.0;
            float px = (float)(Math.Cos(a) * 14), py = (float)(Math.Sin(a) * 14);
            g.FillPolygon(b, new PointF[] { P(px - 8f, py - 5.5f), P(px + 5.5f, py - 8f), P(px + 3f, py + 6.5f) });
            break;
          }
          case Chev: { g.DrawLines(p, new PointF[] { P(-5, -9), P(5, 0), P(-5, 9) }); break; }
          case DChev: {
            g.DrawLines(p, new PointF[] { P(-11, -8), P(-3, 0), P(-11, 8) });
            g.DrawLines(p, new PointF[] { P(1, -8), P(9, 0), P(1, 8) });
            break;
          }
          case Check: {
            using (Pen t = new Pen(c, pw * 1.3f)) { t.StartCap = LineCap.Round; t.EndCap = LineCap.Round; t.LineJoin = LineJoin.Round; g.DrawLines(t, new PointF[] { P(-11, 0), P(-3.5f, 8), P(11, -8) }); }
            break;
          }
          case Menu: {
            using (Pen t = new Pen(c, pw * 1.4f)) { t.StartCap = LineCap.Round; t.EndCap = LineCap.Round; g.DrawLine(t, -14f, -9f, 14f, -9f); g.DrawLine(t, -14f, 0f, 8f, 0f); g.DrawLine(t, -14f, 9f, 14f, 9f); }
            break;
          }
          case Search: {
            g.DrawEllipse(p, -15f, -15f, 21f, 21f);
            g.DrawLine(p, 4f, 4f, 15f, 15f);
            break;
          }
          case Crown: {
            g.FillPolygon(b, new PointF[] { P(-16, 9), P(-19, -9), P(-8, 0), P(0, -13), P(8, 0), P(19, -9), P(16, 9) });
            g.FillRectangle(b, -16f, 12f, 32f, 4.5f);
            break;
          }
          case Bolt: {
            g.FillPolygon(b, new PointF[] { P(4, -21), P(-11, 2), P(-1.5f, 2), P(-5, 21), P(11, -4), P(1.5f, -4) });
            break;
          }
          case Log: {
            using (GraphicsPath dc = RR(-14, -19, 28, 38, 3)) { g.FillPath(bf, dc); g.DrawPath(p, dc); }
            g.DrawLine(p, -7f, -9f, 7f, -9f); g.DrawLine(p, -7f, 0f, 7f, 0f); g.DrawLine(p, -7f, 9f, 2f, 9f);
            break;
          }
        }
      }
      g.Restore(st);
    }
  }

  // ---------------------------------------------------------------- brand logo (text based, drawn with GDI+)
  public static class Brand {
    public static void Draw(Graphics g, RectangleF r, string name, string sub) {
      GraphicsState st = g.Save();
      g.SmoothingMode = SmoothingMode.AntiAlias;
      float subH = string.IsNullOrEmpty(sub) ? 0f : 13f;
      float th = r.Height - subH - 2f;
      using (FontFamily ff = new FontFamily(Fx.LogoFamily))
      using (GraphicsPath p = new GraphicsPath()) {
        p.AddString(name, ff, (int)(FontStyle.Bold | FontStyle.Italic), 100f, new PointF(0f, 0f), StringFormat.GenericTypographic);
        RectangleF b = p.GetBounds();
        if (b.Width < 1f || b.Height < 1f) { g.Restore(st); return; }
        float s = Math.Min((r.Width - 6f) / b.Width, th / b.Height);
        using (Matrix mx = new Matrix()) {
          mx.Translate(r.X + (r.Width - b.Width * s) / 2f, r.Y + (th - b.Height * s) / 2f);
          mx.Scale(s, s);
          mx.Translate(-b.X, -b.Y);
          p.Transform(mx);
        }
        RectangleF nb = p.GetBounds();
        for (int i = 3; i >= 1; i--) using (Pen gp = new Pen(Color.FromArgb(18 * (4 - i), Th.AccHi), 2f * i + 1f)) { gp.LineJoin = LineJoin.Round; g.DrawPath(gp, p); }
        using (LinearGradientBrush lb = new LinearGradientBrush(new RectangleF(nb.X, nb.Y - 1f, nb.Width, nb.Height + 2f), Color.FromArgb(255, 255, 255), Th.Acc, 90f)) g.FillPath(lb, p);
        using (Pen op = new Pen(Color.FromArgb(150, Th.AccHi), 1f)) { op.LineJoin = LineJoin.Round; g.DrawPath(op, p); }
        // slashes
        using (SolidBrush sb = new SolidBrush(Color.FromArgb(220, Th.AccHi))) {
          g.FillPolygon(sb, new PointF[] { new PointF(nb.Right - nb.Width * 0.30f, nb.Y - 3f), new PointF(nb.Right - nb.Width * 0.22f, nb.Y - 3f), new PointF(nb.Right - nb.Width * 0.40f, nb.Y + 5f) });
          g.FillPolygon(sb, new PointF[] { new PointF(nb.X + nb.Width * 0.05f, nb.Bottom - 2f), new PointF(nb.X + nb.Width * 0.16f, nb.Bottom - 2f), new PointF(nb.X + nb.Width * 0.02f, nb.Bottom + 4f) });
        }
      }
      if (subH > 0f) {
        Font f = Fx.F(6.6f, true);
        float w = G.TrackW(g, sub, f, 3f);
        G.Track(g, sub, f, Th.Mut, r.X + (r.Width - w) / 2f, r.Bottom - subH + 1f, 3f);
      }
      g.Restore(st);
    }

    public static Bitmap Mark(int size, string letter) {
      Bitmap bmp = new Bitmap(size, size);
      using (Graphics g = Graphics.FromImage(bmp)) {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.Clear(Color.Transparent);
        using (FontFamily ff = new FontFamily(Fx.LogoFamily))
        using (GraphicsPath p = new GraphicsPath()) {
          p.AddString(letter, ff, (int)(FontStyle.Bold | FontStyle.Italic), 100f, new PointF(0f, 0f), StringFormat.GenericTypographic);
          RectangleF b = p.GetBounds();
          float s = Math.Min(size * 0.74f / b.Width, size * 0.74f / b.Height);
          using (Matrix mx = new Matrix()) {
            mx.Translate((size - b.Width * s) / 2f, (size - b.Height * s) / 2f);
            mx.Scale(s, s);
            mx.Translate(-b.X, -b.Y);
            p.Transform(mx);
          }
          for (int i = 3; i >= 1; i--) using (Pen gp = new Pen(Color.FromArgb(22 * (4 - i), Th.AccHi), size * 0.03f * i + 1f)) { gp.LineJoin = LineJoin.Round; g.DrawPath(gp, p); }
          using (LinearGradientBrush lb = new LinearGradientBrush(new Rectangle(0, 0, size, size), Color.FromArgb(255, 255, 255), Th.Acc, 90f)) g.FillPath(lb, p);
        }
      }
      return bmp;
    }
  }

  // ---------------------------------------------------------------- mode data
  public class Mode {
    public string Key = "", Title = "", Tag = "", D1 = "", D2 = "";
    public Color Col = Th.Acc;
    public int Icon;
    public bool Selected, Applied;
    public RectangleF Rect = RectangleF.Empty, Cur = RectangleF.Empty;
    public float Hov, SelA, RestA;
  }

  // ---------------------------------------------------------------- rounded button (eased hover)
  public class Bt : Control {
    public int Kind;          // 0 outline, 1 primary
    public int Icon = -1;
    bool hover, down; float a; Timer tm = new Timer();
    public Bt() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      SetStyle(ControlStyles.Selectable, false);
      Cursor = Cursors.Hand; BackColor = Th.Bg;
      tm.Interval = 15;
      tm.Tick += delegate {
        float t = hover ? 1f : 0f; a += (t - a) * 0.28f;
        if (Math.Abs(t - a) < 0.015f) { a = t; tm.Stop(); }
        Invalidate();
      };
    }
    protected override void Dispose(bool d) { if (d) tm.Dispose(); base.Dispose(d); }
    protected override void OnMouseEnter(EventArgs e) { hover = true; tm.Start(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; tm.Start(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { down = true; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(G.Back(this));
      RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1, Height - 1);
      Color txt = Th.Txt;
      if (Kind == 2) {
        Color k1 = down ? Color.FromArgb(150, 165, 240) : G.Mix(Color.FromArgb(160, 178, 255), Color.FromArgb(198, 216, 255), a);
        Color k2 = down ? Color.FromArgb(80, 180, 220) : G.Mix(Color.FromArgb(92, 192, 230), Color.FromArgb(124, 228, 246), a);
        if (a > 0.02f) G.Box(g, new RectangleF(r.X - 1.5f, r.Y - 1.5f, r.Width + 3f, r.Height + 3f), 15, Color.Empty, Color.FromArgb((int)(70 * a), 140, 200, 255));
        using (GraphicsPath gp = G.Round(r, 13))
        using (LinearGradientBrush lb = new LinearGradientBrush(new RectangleF(0, 0, Width, Height), k1, k2, 0f)) g.FillPath(lb, gp);
        Color tc = Enabled ? Color.FromArgb(14, 20, 44) : Color.FromArgb(70, 80, 110);
        Font tf2 = Fx.F(9.6f, true);
        string up = Text.ToUpperInvariant();
        float w2 = G.TrackW(g, up, tf2, 14f);
        float h2 = g.MeasureString("Ag", tf2, 2000, G.TF).Height;
        G.Track(g, up, tf2, tc, (Width - w2) / 2f, (Height - h2) / 2f, 14f);
        return;
      }
      if (Kind == 1) {
        Color c1 = down ? Th.AccLo : G.Mix(Th.Acc, Th.AccHi, a);
        Color c2 = down ? Th.AccLo : G.Mix(Th.AccLo, Th.Acc, a);
        if (a > 0.02f) G.Box(g, new RectangleF(r.X - 1.5f, r.Y - 1.5f, r.Width + 3f, r.Height + 3f), 12, Color.Empty, Color.FromArgb((int)(60 * a), Th.AccHi));
        using (GraphicsPath gp = G.Round(r, 10))
        using (LinearGradientBrush lb = new LinearGradientBrush(new RectangleF(0, 0, Width, Height + 1f), c1, c2, 90f)) g.FillPath(lb, gp);
        txt = Color.White;
      } else {
        Color fill = down ? G.Mix(Th.Card, Th.Acc, 0.3f) : G.Mix(Th.Card, G.Mix(Th.Card, Th.Acc, 0.18f), a);
        Color line = G.Mix(G.Mix(Th.Card, Th.Acc, 0.67f), Th.AccHi, a);
        G.Box(g, r, 10, fill, line);
      }
      if (!Enabled) txt = Th.Dim;
      Font f = Fx.F(9f, true);
      float tw = g.MeasureString(Text, f, 3000, G.TF).Width;
      float lead = (Icon >= 0) ? 24f : 0f;
      float x = (Width - (tw + lead)) / 2f;
      if (Icon >= 0) Ic.Draw(g, Icon, x + 8f, Height / 2f, 16f, txt);
      G.Text(g, Text, f, txt, new RectangleF(x + lead, 0, tw + 8f, Height), StringAlignment.Near, StringAlignment.Center, false);
    }
  }

  // ---------------------------------------------------------------- mode card grid (animated)
  public class ModeGrid : Control {
    public List<Mode> Modes = new List<Mode>();
    public string RestoreText = "Restore", ActiveText = "ACTIVE";
    public Mode Clicked; public Point MenuPoint;
    public event EventHandler ToggleClick, RestoreClick, MenuClick;
    public int Cols = 5;
    string filter = "";
    List<Mode> vis = new List<Mode>();
    Mode hot; int hotPart;     // 1 body, 2 check, 3 restore
    const float Pad = 6f, Gap = 14f;
    Timer tm = new Timer(); float clock = 99f;

    public ModeGrid() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      SetStyle(ControlStyles.Selectable, false);
      BackColor = Th.Bg;
      tm.Interval = 15; tm.Tick += delegate { Step(); };
    }
    protected override void Dispose(bool d) { if (d) tm.Dispose(); base.Dispose(d); }
    public string Filter {
      get { return filter; }
      set { filter = (value ?? "").Trim().ToLowerInvariant(); Relayout(); Invalidate(); }
    }
    public int VisibleCount { get { return vis.Count; } }
    public void PlayIntro() { clock = 0f; foreach (Mode m in Modes) m.Cur = m.Rect; tm.Start(); Invalidate(); }

    static float Ease(float t) { if (t < 0f) t = 0f; if (t > 1f) t = 1f; float u = 1f - t; return 1f - u * u * u; }
    static float Lerp(float a, float b, float k) { return a + (b - a) * k; }

    void Step() {
      bool busy = false;
      if (clock < 50f) { clock += 0.016f; if (clock < 0.6f + vis.Count * 0.05f) busy = true; else clock = 99f; }
      foreach (Mode m in Modes) {
        float t1 = (m == hot) ? 1f : 0f, t2 = m.Selected ? 1f : 0f, t3 = (m == hot && hotPart == 3) ? 1f : 0f;
        m.Hov = Lerp(m.Hov, t1, 0.26f); if (Math.Abs(m.Hov - t1) < 0.01f) m.Hov = t1; else busy = true;
        m.SelA = Lerp(m.SelA, t2, 0.24f); if (Math.Abs(m.SelA - t2) < 0.01f) m.SelA = t2; else busy = true;
        m.RestA = Lerp(m.RestA, t3, 0.30f); if (Math.Abs(m.RestA - t3) < 0.01f) m.RestA = t3; else busy = true;
        if (m.Rect.Width > 1f) {
          if (m.Cur.Width < 1f) m.Cur = m.Rect;
          else {
            RectangleF c = m.Cur, t = m.Rect;
            if (Math.Abs(c.X - t.X) + Math.Abs(c.Y - t.Y) + Math.Abs(c.Width - t.Width) + Math.Abs(c.Height - t.Height) > 0.6f) {
              m.Cur = new RectangleF(Lerp(c.X, t.X, 0.3f), Lerp(c.Y, t.Y, 0.3f), Lerp(c.Width, t.Width, 0.3f), Lerp(c.Height, t.Height, 0.3f)); busy = true;
            } else m.Cur = t;
          }
        }
      }
      Invalidate();
      if (!busy) tm.Stop();
    }

    public void Relayout() {
      vis.Clear();
      foreach (Mode m in Modes) {
        string hay = (m.Title + " " + m.Tag + " " + m.D1 + " " + m.D2).ToLowerInvariant();
        if (filter.Length == 0 || hay.Contains(filter)) vis.Add(m); else m.Rect = RectangleF.Empty;
      }
      int n = vis.Count; if (n == 0) return;
      int cols = Math.Max(1, Cols);
      int rows = Math.Max(2, (n + cols - 1) / cols);
      float cw = (Width - Pad * 2f - Gap * (cols - 1)) / cols;
      float ch = (Height - Pad * 2f - Gap * (rows - 1)) / rows;
      if (ch > 268f) ch = 268f; if (ch < 176f) ch = 176f;
      for (int i = 0; i < n; i++) {
        int col = i % cols, row = i / cols;
        vis[i].Rect = new RectangleF(Pad + col * (cw + Gap), Pad + row * (ch + Gap), cw, ch);
        if (vis[i].Cur.Width < 1f) vis[i].Cur = vis[i].Rect;
      }
      tm.Start();
    }
    protected override void OnResize(EventArgs e) { base.OnResize(e); Relayout(); }

    static float BannerH(RectangleF r) { return Math.Max(66f, Math.Min(114f, r.Height * 0.41f)); }
    static RectangleF CheckR(RectangleF r) { return new RectangleF(r.Right - 37f, r.Y + 10f, 26f, 26f); }
    static RectangleF RestoreR(RectangleF r) { return new RectangleF(r.X + 12f, r.Bottom - 46f, r.Width - 24f, 34f); }

    static GraphicsPath TopRound(RectangleF r, float rad) {
      GraphicsPath p = new GraphicsPath(); float d = rad * 2f;
      p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
      p.AddLine(r.Right, r.Y + rad, r.Right, r.Bottom); p.AddLine(r.Right, r.Bottom, r.X, r.Bottom);
      p.CloseFigure(); return p;
    }

    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(Th.Bg);
      for (int i = 0; i < vis.Count; i++) PaintCard(g, vis[i], i);
    }

    void PaintCard(Graphics g, Mode m, int idx) {
      float p = (clock > 50f) ? 1f : Ease((clock - idx * 0.05f) * 2.2f);
      if (p <= 0.001f || m.Cur.Width < 1f) return;
      RectangleF r = m.Cur; Color ac = m.Col;
      float hov = m.Hov, sa = m.SelA;
      GraphicsState g0 = g.Save();
      g.TranslateTransform(0f, (1f - p) * 20f - 3f * hov);
      if (sa > 0.01f) {
        for (int i = 3; i >= 1; i--) G.Box(g, new RectangleF(r.X - i * 2.2f, r.Y - i * 2.2f, r.Width + i * 4.4f, r.Height + i * 4.4f), 12 + i * 2, Color.Empty, Color.FromArgb((int)((i == 1 ? 40 : (i == 2 ? 22 : 10)) * sa), ac));
      }
      if (hov > 0.02f && sa < 0.99f) G.Box(g, new RectangleF(r.X - 2f, r.Y - 2f, r.Width + 4f, r.Height + 4f), 14, Color.Empty, Color.FromArgb((int)(24 * hov * (1f - sa)), ac));
      G.Box(g, r, 12, G.Mix(Th.Card, Th.Card2, hov * 0.6f), Color.Empty);
      float bh = BannerH(r);
      RectangleF b = new RectangleF(r.X + 1f, r.Y + 1f, r.Width - 2f, bh);
      GraphicsState gs = g.Save();
      using (GraphicsPath bp = TopRound(b, 11f)) {
        g.SetClip(bp, CombineMode.Intersect);
        Color deep = G.Mix(Color.FromArgb(5, 8, 17), ac, 0.30f + 0.08f * hov);
        using (LinearGradientBrush lb = new LinearGradientBrush(b, Color.FromArgb(7, 10, 20), deep, 35f)) g.FillRectangle(lb, b);
        Random rnd = new Random(m.Icon * 97 + 13);
        for (int i = 0; i < 5; i++) {
          float x = b.X + (float)rnd.NextDouble() * b.Width + hov * 6f, w = 6f + (float)rnd.NextDouble() * 22f;
          using (SolidBrush sb = new SolidBrush(Color.FromArgb(14 + rnd.Next(22), ac)))
            g.FillPolygon(sb, new PointF[] { new PointF(x, b.Bottom), new PointF(x + w, b.Bottom), new PointF(x + w + 26f, b.Y), new PointF(x + 26f, b.Y) });
        }
        float cx = b.X + b.Width / 2f, cy = b.Y + b.Height / 2f;
        using (GraphicsPath gp = new GraphicsPath()) {
          gp.AddEllipse(cx - b.Width * 0.42f, cy - bh * 0.78f, b.Width * 0.84f, bh * 1.56f);
          using (PathGradientBrush pg = new PathGradientBrush(gp)) {
            pg.CenterColor = Color.FromArgb((int)(84 + 40 * Math.Max(hov, sa)), ac); pg.SurroundColors = new Color[] { Color.FromArgb(0, ac) };
            g.FillPath(pg, gp);
          }
        }
        float isz = Math.Min(54f, bh * 0.62f) * (1f + 0.06f * hov);
        Ic.Draw(g, m.Icon, cx, cy, isz + 8f, Color.FromArgb(60, ac));
        Ic.Draw(g, m.Icon, cx, cy, isz, G.Mix(ac, Color.White, 0.42f));
      }
      g.Restore(gs);
      using (Pen lp = new Pen(Color.FromArgb(46, ac), 1f)) g.DrawLine(lp, b.X, b.Bottom, b.Right, b.Bottom);
      float na = 92f + 78f * hov;
      Color bc = Color.FromArgb((int)(na + (235f - na) * sa), ac);
      using (GraphicsPath bd = G.Round(r, 12)) using (Pen bp2 = new Pen(bc, 1f + 0.6f * sa)) g.DrawPath(bp2, bd);
      // check badge (cross-fades between off / on)
      RectangleF cr = CheckR(r);
      bool hc = (hot == m && hotPart == 2);
      if (sa < 0.99f) {
        float k = 1f - sa;
        G.Box(g, cr, 7, Color.FromArgb((int)(120 * k), 0, 0, 0), Color.FromArgb((int)((hc ? 140 : 55) * k), 255, 255, 255));
        Ic.Draw(g, Ic.Check, cr.X + cr.Width / 2f, cr.Y + cr.Height / 2f, 15f, Color.FromArgb((int)((60 + 60 * hov) * k), 255, 255, 255));
      }
      if (sa > 0.01f) {
        float sc = 0.7f + 0.3f * sa;
        RectangleF cs2 = new RectangleF(cr.X + cr.Width * (1f - sc) / 2f, cr.Y + cr.Height * (1f - sc) / 2f, cr.Width * sc, cr.Height * sc);
        using (GraphicsPath cp = G.Round(cs2, 7)) using (SolidBrush cb = new SolidBrush(Color.FromArgb((int)(255 * sa), ac))) g.FillPath(cb, cp);
        Ic.Draw(g, Ic.Check, cr.X + cr.Width / 2f, cr.Y + cr.Height / 2f, 15f * sc, Color.FromArgb((int)(255 * sa), 255, 255, 255));
      }
      if (m.Applied) {
        Font pf = Fx.F(7.4f, true);
        float tw = g.MeasureString(ActiveText, pf, 2000, G.TF).Width;
        RectangleF pr = new RectangleF(b.X + 10f, b.Bottom - 26f, tw + 24f, 18f);
        G.Box(g, pr, 9, Color.FromArgb(170, 0, 0, 0), Color.FromArgb(170, Th.Ok));
        using (SolidBrush ob = new SolidBrush(Th.Ok)) g.FillEllipse(ob, pr.X + 8f, pr.Y + 6.5f, 5f, 5f);
        G.Text(g, ActiveText, pf, Th.Ok, new RectangleF(pr.X + 15f, pr.Y, tw + 8f, pr.Height), StringAlignment.Near, StringAlignment.Center, false);
      }
      float ty = b.Bottom + 10f;
      Font tf = Fx.F(10.5f, true), gf = Fx.F(6.9f, true);
      float tagW = g.MeasureString(m.Tag, gf, 2000, G.TF).Width + 16f;
      float avail = r.Width - 24f - tagW - 8f;
      float titleW = Math.Min(g.MeasureString(m.Title, tf, 3000, G.TF).Width + 2f, avail);
      G.Text(g, m.Title, tf, Th.Txt, new RectangleF(r.X + 12f, ty, titleW + 4f, 24f), StringAlignment.Near, StringAlignment.Center, false);
      RectangleF tg = new RectangleF(r.X + 12f + titleW + 8f, ty + 3f, tagW, 18f);
      G.Box(g, tg, 5, G.Mix(ac, Color.Black, 0.32f), Color.Empty);
      G.Text(g, m.Tag, gf, Color.White, tg, StringAlignment.Center, StringAlignment.Center, false);
      Font df = Fx.F(8.3f, false);
      float dy = ty + 30f;
      G.Text(g, m.D1, df, G.Mix(Th.Mut, Th.Soft, hov), new RectangleF(r.X + 12f, dy, r.Width - 22f, 18f), StringAlignment.Near, StringAlignment.Center, false);
      G.Text(g, m.D2, df, G.Mix(Th.Mut, Th.Soft, hov), new RectangleF(r.X + 12f, dy + 17f, r.Width - 22f, 18f), StringAlignment.Near, StringAlignment.Center, false);
      RectangleF rb = RestoreR(r);
      float ra = m.RestA;
      G.Box(g, rb, 9, G.Mix(Th.Bg, G.Mix(Th.Bg, ac, 0.18f), ra), Color.FromArgb((int)(200 + 55 * ra), ac));
      Font bf = Fx.F(8.8f, true);
      float bw = g.MeasureString(RestoreText, bf, 3000, G.TF).Width;
      float sx = rb.X + (rb.Width - (bw + 24f)) / 2f - 6f;
      Ic.Draw(g, Ic.Restore, sx + 8f, rb.Y + rb.Height / 2f, 15f, Th.Txt);
      G.Text(g, RestoreText, bf, Th.Txt, new RectangleF(sx + 24f, rb.Y, bw + 10f, rb.Height), StringAlignment.Near, StringAlignment.Center, false);
      Ic.Draw(g, Ic.Chev, rb.Right - 16f + 2f * ra, rb.Y + rb.Height / 2f, 12f, G.Mix(ac, Color.White, 0.25f));
      g.Restore(g0);
      if (p < 1f) G.Box(g, new RectangleF(r.X - 10f, r.Y - 10f + (1f - p) * 20f, r.Width + 20f, r.Height + 20f), 20, Color.FromArgb((int)((1f - p) * 255), Th.Bg), Color.Empty);
    }

    void HitTest(Point pt, out Mode m, out int part) {
      m = null; part = 0;
      foreach (Mode x in vis) {
        if (x.Cur.Contains(pt.X, pt.Y)) {
          m = x;
          if (RestoreR(x.Cur).Contains(pt.X, pt.Y)) part = 3;
          else if (CheckR(x.Cur).Contains(pt.X, pt.Y)) part = 2;
          else part = 1;
          return;
        }
      }
    }
    protected override void OnMouseMove(MouseEventArgs e) {
      Mode m; int part; HitTest(e.Location, out m, out part);
      if (m != hot || part != hotPart) { hot = m; hotPart = part; Cursor = (m != null) ? Cursors.Hand : Cursors.Default; tm.Start(); }
      base.OnMouseMove(e);
    }
    protected override void OnMouseLeave(EventArgs e) { hot = null; hotPart = 0; Cursor = Cursors.Default; tm.Start(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) {
      base.OnMouseDown(e);
      Mode m; int part; HitTest(e.Location, out m, out part);
      if (m == null) return;
      Clicked = m;
      if (e.Button == MouseButtons.Right) { MenuPoint = e.Location; if (MenuClick != null) MenuClick(this, EventArgs.Empty); return; }
      if (e.Button != MouseButtons.Left) return;
      if (part == 3) { if (RestoreClick != null) RestoreClick(this, EventArgs.Empty); return; }
      m.Selected = !m.Selected; tm.Start();
      if (ToggleClick != null) ToggleClick(this, EventArgs.Empty);
    }
  }

  // ---------------------------------------------------------------- search box
  public class SearchBox : Control {
    public TextBox Tb = new TextBox();
    public string Placeholder = "";
    public event EventHandler Changed;
    bool focus;
    public SearchBox() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      BackColor = Th.Bg;
      Tb.BorderStyle = BorderStyle.None; Tb.BackColor = Th.Card; Tb.ForeColor = Th.Txt; Tb.Font = Fx.F(9.2f, false);
      Controls.Add(Tb);
      Tb.TextChanged += delegate { if (Changed != null) Changed(this, EventArgs.Empty); };
      Tb.Enter += delegate { focus = true; Invalidate(); };
      Tb.Leave += delegate { focus = false; Invalidate(); };
      Tb.HandleCreated += delegate { HX.Native.Cue(Tb.Handle, Placeholder); };
      Layout2();
    }
    public string Value { get { return Tb.Text; } }
    void Layout2() { Tb.Left = 40; Tb.Width = Math.Max(20, Width - 56); Tb.Top = (Height - Tb.Height) / 2; }
    protected override void OnResize(EventArgs e) { base.OnResize(e); Layout2(); }
    protected override void OnMouseDown(MouseEventArgs e) { Tb.Focus(); base.OnMouseDown(e); }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(G.Back(this));
      G.Box(g, new RectangleF(0.5f, 0.5f, Width - 1, Height - 1), 10, Th.Card, focus ? Th.Acc : Th.Line);
      Ic.Draw(g, Ic.Search, 22f, Height / 2f, 15f, focus ? Th.AccHi : Th.Mut);
    }
  }

  // ---------------------------------------------------------------- title row (menu icon + title + search)
  public class TopRow : Control {
    public string Title = "";
    public SearchBox Box = new SearchBox();
    public TopRow() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      BackColor = Th.Bg; Controls.Add(Box); Box.Size = new Size(300, 40);
    }
    protected override void OnResize(EventArgs e) { base.OnResize(e); Box.Left = Width - Box.Width - 5; Box.Top = (Height - Box.Height) / 2; }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(G.Back(this));
      Ic.Draw(g, Ic.Menu, 22f, Height / 2f, 22f, Th.AccHi);
      G.Text(g, Title, Fx.F(13.5f, true), Th.Txt, new RectangleF(48f, 0, Width - 380f, Height), StringAlignment.Near, StringAlignment.Center, false);
    }
  }

  // ---------------------------------------------------------------- bottom promo banner (hosts buttons on the right)
  public class Promo : Control {
    public string Line1 = "", Line1b = "", Line2 = "";
    public List<Control> RightItems = new List<Control>();
    public Promo() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      BackColor = Th.Bg;
    }
    public void Lay() {
      int x = Width - 24;
      for (int i = RightItems.Count - 1; i >= 0; i--) {
        Control c = RightItems[i]; x -= c.Width; c.Left = x; c.Top = (Height - c.Height) / 2; x -= 12;
      }
      Invalidate();
    }
    protected override void OnResize(EventArgs e) { base.OnResize(e); Lay(); }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(G.Back(this));
      RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1, Height - 1);
      GraphicsState gs = g.Save();
      using (GraphicsPath p = G.Round(r, 12)) {
        g.SetClip(p, CombineMode.Intersect);
        using (LinearGradientBrush lb = new LinearGradientBrush(r, Color.FromArgb(8, 12, 24), G.Mix(Color.FromArgb(8, 12, 24), Th.Acc, 0.22f), 0f)) g.FillRectangle(lb, r);
        using (SolidBrush sb = new SolidBrush(Color.FromArgb(14, Th.AccHi)))
          for (int i = 0; i < 6; i++) { float x = Width * 0.30f + i * 70f; g.FillPolygon(sb, new PointF[] { new PointF(x, Height), new PointF(x + 16f, Height), new PointF(x + 52f, 0f), new PointF(x + 36f, 0f) }); }
        // art on the left: glowing graphics card
        float ax = 78f, ay = Height / 2f;
        using (GraphicsPath gp = new GraphicsPath()) {
          gp.AddEllipse(ax - 80f, ay - 60f, 160f, 120f);
          using (PathGradientBrush pg = new PathGradientBrush(gp)) { pg.CenterColor = Color.FromArgb(110, Th.Acc); pg.SurroundColors = new Color[] { Color.FromArgb(0, Th.Acc) }; g.FillPath(pg, gp); }
        }
        Ic.Draw(g, Ic.Gpu, ax, ay, Math.Min(74f, Height - 22f), Th.AccHi);
      }
      g.Restore(gs);
      using (GraphicsPath bp = G.Round(r, 12)) using (Pen pn = new Pen(Color.FromArgb(150, Th.Acc), 1.3f)) g.DrawPath(pn, bp);
      float tx = 170f;
      Font f1 = Fx.F(15f, true);
      float w1 = g.MeasureString(Line1, f1, 3000, G.TF).Width;
      G.Text(g, Line1, f1, Th.Txt, new RectangleF(tx, Height / 2f - 30f, w1 + 6f, 30f), StringAlignment.Near, StringAlignment.Center, false);
      G.Text(g, Line1b, f1, Th.AccHi, new RectangleF(tx + w1 + 8f, Height / 2f - 30f, 400f, 30f), StringAlignment.Near, StringAlignment.Center, false);
      G.Text(g, Line2, Fx.F(9.5f, false), Th.Soft, new RectangleF(tx, Height / 2f + 2f, 600f, 24f), StringAlignment.Near, StringAlignment.Center, false);
    }
  }

  // ---------------------------------------------------------------- GPU load sampler (background thread, Windows 10+ perf counters)
  public static class GpuLoad {
    static Dictionary<string, PerformanceCounter> cs = new Dictionary<string, PerformanceCounter>();
    static float last = -1f; static bool busy;
    static System.Threading.Timer tm;
    public static float Value { get { return last; } }
    public static void Start() { if (tm == null) tm = new System.Threading.Timer(delegate { Tick(); }, null, 600, 2000); }
    public static void Stop() { if (tm != null) { tm.Dispose(); tm = null; } }
    static void Tick() {
      if (busy) return; busy = true;
      try {
        PerformanceCounterCategory cat = new PerformanceCounterCategory("GPU Engine");
        string[] names = cat.GetInstanceNames();
        Dictionary<string, bool> want = new Dictionary<string, bool>();
        foreach (string n in names) if (n.IndexOf("engtype_3D", StringComparison.OrdinalIgnoreCase) >= 0) want[n] = true;
        List<string> gone = new List<string>();
        foreach (string k in cs.Keys) if (!want.ContainsKey(k)) gone.Add(k);
        foreach (string k in gone) { try { cs[k].Dispose(); } catch (Exception) { } cs.Remove(k); }
        foreach (string n in want.Keys) {
          if (cs.ContainsKey(n)) continue;
          try { PerformanceCounter pc = new PerformanceCounter("GPU Engine", "Utilization Percentage", n, true); pc.NextValue(); cs[n] = pc; } catch (Exception) { }
        }
        float sum = 0f;
        foreach (PerformanceCounter pc in cs.Values) { try { sum += pc.NextValue(); } catch (Exception) { } }
        if (sum > 100f) sum = 100f;
        last = sum;
      } catch (Exception) { last = -1f; }
      busy = false;
    }
  }

  // ---------------------------------------------------------------- sidebar (home, live system status, extra nav, user card)
  public class Side : Control {
    public float Cpu = -1f, Ram = -1f, Gpu = -1f;
    public string StatusTitle = "", HomeText = "", LogText = "", ResetLabel = "", Welcome = "", UserName = "", UserQuote = "", Brand = "", BrandSub = "";
    public int Page;     // 0 home, 1 log
    public Image LogoImg;
    public event EventHandler HomeClick, LogClick, ResetClick;
    Rectangle rHome, rLog, rReset; int hot;   // 1 home, 2 log, 3 reset
    float[] ha = new float[4]; float dCpu = -1f, dRam = -1f, dGpu = -1f; Timer tm = new Timer();
    public Side() {
      tm.Interval = 16;
      tm.Tick += delegate {
        bool ch = false;
        for (int i = 1; i <= 3; i++) { float t = (hot == i) ? 1f : 0f; float n = ha[i] + (t - ha[i]) * 0.28f; if (Math.Abs(t - n) < 0.015f) n = t; if (n != ha[i]) { ha[i] = n; ch = true; } }
        float c = Ease1(dCpu, Cpu), r = Ease1(dRam, Ram), gg = Ease1(dGpu, Gpu);
        if (c != dCpu || r != dRam || gg != dGpu) { dCpu = c; dRam = r; dGpu = gg; ch = true; }
        if (ch) Invalidate();
      };
      tm.Start();
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      SetStyle(ControlStyles.Selectable, false);
      BackColor = Th.Panel;
    }
    static float Ease1(float cur, float tgt) {
      if (tgt < 0f) return -1f;
      if (cur < 0f) return tgt;
      float n = cur + (tgt - cur) * 0.2f;
      return (Math.Abs(n - tgt) < 0.05f) ? tgt : n;
    }
    protected override void Dispose(bool d) { if (d) tm.Dispose(); base.Dispose(d); }
    void Lay() {
      rHome = new Rectangle(14, 16, Width - 29, 46);
      rLog = new Rectangle(14, 270, Width - 29, 38);
      rReset = new Rectangle(14, 316, Width - 29, 38);
    }
    protected override void OnResize(EventArgs e) { base.OnResize(e); Lay(); }
    protected override void OnMouseMove(MouseEventArgs e) {
      int h = rHome.Contains(e.Location) ? 1 : (rLog.Contains(e.Location) ? 2 : (rReset.Contains(e.Location) ? 3 : 0));
      if (h != hot) { hot = h; Cursor = h > 0 ? Cursors.Hand : Cursors.Default; }
      base.OnMouseMove(e);
    }
    protected override void OnMouseLeave(EventArgs e) { hot = 0; Cursor = Cursors.Default; base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) {
      base.OnMouseDown(e);
      if (e.Button != MouseButtons.Left) return;
      if (rHome.Contains(e.Location)) { if (HomeClick != null) HomeClick(this, EventArgs.Empty); }
      else if (rLog.Contains(e.Location)) { if (LogClick != null) LogClick(this, EventArgs.Empty); }
      else if (rReset.Contains(e.Location)) { if (ResetClick != null) ResetClick(this, EventArgs.Empty); }
    }
    void Bar(Graphics g, int icon, string label, float pct, float y) {
      int w = Width;
      Ic.Draw(g, icon, 38f, y + 13f, 17f, Th.Mut);
      G.Text(g, label, Fx.F(8.4f, true), Th.Soft, new RectangleF(58f, y + 3f, 70f, 20f), StringAlignment.Near, StringAlignment.Center, false);
      string pt = (pct < 0f) ? "-" : ((int)Math.Round(pct)).ToString(CultureInfo.InvariantCulture) + "%";
      G.Text(g, pt, Fx.F(8.4f, true), Th.Txt, new RectangleF(w - 108f, y + 3f, 80f, 20f), StringAlignment.Far, StringAlignment.Center, false);
      RectangleF bar = new RectangleF(58f, y + 26f, w - 58f - 44f, 4f);
      G.Box(g, bar, 2, Th.Line, Color.Empty);
      if (pct > 0.5f) {
        RectangleF fb = new RectangleF(bar.X, bar.Y, Math.Max(4f, bar.Width * Math.Min(100f, pct) / 100f), bar.Height);
        using (GraphicsPath gp = G.Round(fb, 2)) using (LinearGradientBrush lb = new LinearGradientBrush(new RectangleF(fb.X - 1f, fb.Y, fb.Width + 2f, fb.Height), Th.Acc, Th.AccHi, 0f)) g.FillPath(lb, gp);
      }
      Ic.Draw(g, Ic.DChev, w - 36f, y + 28f, 14f, Th.Dim);
    }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(Th.Panel);
      Lay();
      using (Pen lp = new Pen(Th.Line, 1f)) g.DrawLine(lp, Width - 1, 0, Width - 1, Height);
      // home
      RectangleF hr = new RectangleF(rHome.X + 0.5f, rHome.Y + 0.5f, rHome.Width - 1, rHome.Height - 1);
      if (Page == 0) {
        G.Box(g, new RectangleF(hr.X - 1.5f, hr.Y - 1.5f, hr.Width + 3f, hr.Height + 3f), 12, Color.Empty, Color.FromArgb(50, Th.AccHi));
        using (GraphicsPath gp = G.Round(hr, 10)) using (LinearGradientBrush lb = new LinearGradientBrush(new RectangleF(hr.X, hr.Y, hr.Width, hr.Height + 1f), G.Mix(Th.Acc, Th.AccHi, ha[1]), Th.AccLo, 90f)) g.FillPath(lb, gp);
        using (GraphicsPath gp = G.Round(hr, 10)) using (Pen pn = new Pen(Color.FromArgb(150, Th.AccHi), 1f)) g.DrawPath(pn, gp);
      } else G.Box(g, hr, 10, G.Mix(Th.Card, Th.Card2, ha[1]), G.Mix(Th.Line, Th.Acc, ha[1]));
      Ic.Draw(g, Ic.Home, hr.X + 30f, hr.Y + hr.Height / 2f, 20f, Color.White);
      G.Text(g, HomeText, Fx.F(10f, true), Color.White, new RectangleF(hr.X + 54f, hr.Y, hr.Width - 60f, hr.Height), StringAlignment.Near, StringAlignment.Center, false);
      // status panel
      RectangleF pr = new RectangleF(14.5f, 80.5f, Width - 30, 172f);
      G.Box(g, pr, 12, Th.Card, Th.Line);
      G.Text(g, StatusTitle, Fx.F(9f, true), Th.Txt, new RectangleF(28f, 90f, Width - 60f, 24f), StringAlignment.Near, StringAlignment.Center, false);
      Bar(g, Ic.Cpu, "CPU", dCpu, 122f);
      Bar(g, Ic.Ram, "RAM", dRam, 164f);
      Bar(g, Ic.Cam, "GPU", dGpu, 206f);
      // extra nav
      NavBtn(g, rLog, Ic.Log, LogText, ha[2], Page == 1);
      NavBtn(g, rReset, Ic.Restore, ResetLabel, ha[3], false);
      // user card
      float ch = Math.Min(200f, Height - 376f); if (ch < 120f) ch = 120f;
      RectangleF uc = new RectangleF(14.5f, Height - ch - 14f + 0.5f, Width - 30, ch);
      G.Box(g, uc, 12, Th.Card, Th.Line);
      float ay = uc.Y + 14f;
      using (Pen ap = new Pen(Th.Acc, 1.6f)) g.DrawEllipse(ap, uc.X + 14f, ay, 38f, 38f);
      Ic.Draw(g, Ic.User, uc.X + 33f, ay + 20f, 20f, Th.Soft);
      G.Text(g, Welcome, Fx.F(7.8f, false), Th.Soft, new RectangleF(uc.X + 62f, ay - 2f, uc.Width - 70f, 16f), StringAlignment.Near, StringAlignment.Center, false);
      G.Text(g, UserName, Fx.F(10.5f, true), Th.AccHi, new RectangleF(uc.X + 62f, ay + 12f, uc.Width - 70f, 20f), StringAlignment.Near, StringAlignment.Center, false);
      G.Text(g, UserQuote, Fx.F(7.8f, false), Th.Mut, new RectangleF(uc.X + 62f, ay + 31f, uc.Width - 70f, 16f), StringAlignment.Near, StringAlignment.Center, false);
      float dy = ay + 52f;
      using (Pen dp = new Pen(Th.Line, 1f)) g.DrawLine(dp, uc.X + 14f, dy, uc.Right - 14f, dy);
      RectangleF lr = new RectangleF(uc.X + 14f, dy + 12f, uc.Width - 28f, uc.Bottom - dy - 24f);
      if (lr.Height > 30f) {
        G.Box(g, lr, 8, Color.FromArgb(5, 8, 17), Th.Line);
        if (LogoImg != null) {
          float s = Math.Min((lr.Width - 16f) / LogoImg.Width, (lr.Height - 12f) / LogoImg.Height);
          float iw = LogoImg.Width * s, ih = LogoImg.Height * s;
          g.DrawImage(LogoImg, lr.X + (lr.Width - iw) / 2f, lr.Y + (lr.Height - ih) / 2f, iw, ih);
        } else {
          HY.Brand.Draw(g, new RectangleF(lr.X + 8f, lr.Y + 6f, lr.Width - 16f, lr.Height - 12f), Brand, BrandSub);
        }
      }
    }
    void NavBtn(Graphics g, Rectangle rc, int icon, string text, float a, bool sel) {
      RectangleF r = new RectangleF(rc.X + 0.5f, rc.Y + 0.5f, rc.Width - 1, rc.Height - 1);
      float k = sel ? 1f : a;
      G.Box(g, r, 10, G.Mix(Th.Card, sel ? G.Mix(Th.Card, Th.Acc, 0.2f) : Th.Card2, k), G.Mix(Th.Line, Th.Acc, k));
      Ic.Draw(g, icon, r.X + 24f, r.Y + r.Height / 2f, 16f, G.Mix(Th.Mut, Th.AccHi, k));
      G.Text(g, text, Fx.F(9f, true), G.Mix(Th.Soft, Th.Txt, k), new RectangleF(r.X + 46f, r.Y, r.Width - 52f, r.Height), StringAlignment.Near, StringAlignment.Center, false);
    }
  }

  // ---------------------------------------------------------------- header (logo, tagline, window buttons)
  public class Head : Control {
    public string Brand = "", BrandSub = "", Line1 = "", Line2 = "", Credit = "";
    public Image LogoImg;
    public event EventHandler MinClick, CloseClick;
    Rectangle rMin, rClose; int hot;
    public Head() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      BackColor = Th.Bg;
    }
    protected override void OnResize(EventArgs e) { base.OnResize(e); rClose = new Rectangle(Width - 40, 12, 28, 28); rMin = new Rectangle(Width - 72, 12, 28, 28); Invalidate(); }
    protected override void OnMouseMove(MouseEventArgs e) {
      int h = rMin.Contains(e.Location) ? 1 : (rClose.Contains(e.Location) ? 2 : 0);
      if (h != hot) { hot = h; Cursor = h > 0 ? Cursors.Hand : Cursors.Default; Invalidate(); }
      base.OnMouseMove(e);
    }
    protected override void OnMouseLeave(EventArgs e) { hot = 0; Cursor = Cursors.Default; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) {
      base.OnMouseDown(e);
      if (e.Button != MouseButtons.Left) return;
      if (rMin.Contains(e.Location)) { if (MinClick != null) MinClick(this, EventArgs.Empty); return; }
      if (rClose.Contains(e.Location)) { if (CloseClick != null) CloseClick(this, EventArgs.Empty); return; }
      Form f = FindForm(); if (f != null) HX.Native.Drag(f.Handle);
    }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g);
      using (LinearGradientBrush lb = new LinearGradientBrush(new Rectangle(0, 0, Width, Height + 1), Color.FromArgb(10, 15, 30), Th.Bg, 90f)) g.FillRectangle(lb, 0, 0, Width, Height);
      using (Pen lp = new Pen(Th.Line, 1f)) g.DrawLine(lp, 0, Height - 1, Width, Height - 1);
      RectangleF lr = new RectangleF(26f, 10f, 196f, Height - 20f);
      if (LogoImg != null) {
        float s = Math.Min(lr.Width / LogoImg.Width, (lr.Height - 14f) / LogoImg.Height);
        float iw = LogoImg.Width * s, ih = LogoImg.Height * s;
        g.DrawImage(LogoImg, lr.X + (lr.Width - iw) / 2f, lr.Y + (lr.Height - 14f - ih) / 2f + 2f, iw, ih);
        Font sf = Fx.F(6.6f, true); float sw = G.TrackW(g, BrandSub, sf, 3f);
        G.Track(g, BrandSub, sf, Th.Mut, lr.X + (lr.Width - sw) / 2f, lr.Bottom - 12f, 3f);
      } else HY.Brand.Draw(g, lr, Brand, BrandSub);
      using (Pen vp = new Pen(Th.Line, 1f)) g.DrawLine(vp, 246f, 18f, 246f, Height - 18f);
      G.Text(g, Line1, Fx.F(9.5f, false), Th.Soft, new RectangleF(274f, Height / 2f - 26f, Width - 560f, 24f), StringAlignment.Near, StringAlignment.Center, false);
      G.Text(g, Line2, Fx.F(10.5f, true), Th.Txt, new RectangleF(274f, Height / 2f - 2f, Width - 560f, 26f), StringAlignment.Near, StringAlignment.Center, false);
      // credit + crown (right)
      Font cf = Fx.F(9f, true);
      float cw = g.MeasureString(Credit, cf, 2000, G.TF).Width;
      Ic.Draw(g, Ic.Crown, Width - 38f, Height - 28f, 20f, Th.AccHi);
      G.Text(g, Credit, cf, Th.AccHi, new RectangleF(Width - 38f - 16f - cw - 6f, Height - 40f, cw + 8f, 24f), StringAlignment.Far, StringAlignment.Center, false);
      // window buttons
      Color mc = (hot == 1) ? Th.Txt : Th.Soft, xc = (hot == 2) ? Color.White : Th.Soft;
      if (hot == 2) G.Box(g, new RectangleF(rClose.X, rClose.Y, rClose.Width, rClose.Height), 7, Color.FromArgb(220, 200, 50, 60), Color.Empty);
      if (hot == 1) G.Box(g, new RectangleF(rMin.X, rMin.Y, rMin.Width, rMin.Height), 7, Color.FromArgb(40, Th.Acc), Color.Empty);
      using (Pen p = new Pen(mc, 1.5f)) g.DrawLine(p, rMin.X + 8, rMin.Y + 14, rMin.Right - 8, rMin.Y + 14);
      using (Pen p = new Pen(xc, 1.5f)) { g.DrawLine(p, rClose.X + 9, rClose.Y + 9, rClose.Right - 9, rClose.Bottom - 9); g.DrawLine(p, rClose.Right - 9, rClose.Y + 9, rClose.X + 9, rClose.Bottom - 9); }
    }
  }

  // ---------------------------------------------------------------- footer
  public class Foot : Control {
    public string Status = "", Ver = "";
    public Color StatusColor = Th.AccHi;
    public List<string> Labels = new List<string>();
    public List<int> Icons = new List<int>();
    public Foot() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      BackColor = Th.Panel;
    }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g); g.Clear(Th.Panel);
      using (Pen lp = new Pen(Th.Line, 1f)) g.DrawLine(lp, 0, 0, Width, 0);
      float cy = Height / 2f + 0.5f;
      Ic.Draw(g, Ic.Bolt, 38f, cy, 16f, StatusColor);
      Font f = Fx.F(8.8f, true);
      float sw = g.MeasureString(Status, f, 3000, G.TF).Width;
      G.Text(g, Status, f, StatusColor, new RectangleF(54f, 0, sw + 10f, Height), StringAlignment.Near, StringAlignment.Center, false);
      float x = 54f + sw + 34f;
      using (SolidBrush ob = new SolidBrush(Th.Ok)) g.FillEllipse(ob, x, cy - 4f, 8f, 8f);
      G.Text(g, Ver, Fx.F(8.6f, false), Th.Soft, new RectangleF(x + 16f, 0, 300f, Height), StringAlignment.Near, StringAlignment.Center, false);
      // right side items
      Font rf = Fx.F(8.6f, false);
      float rx = Width - 28f;
      for (int i = Labels.Count - 1; i >= 0; i--) {
        float w = g.MeasureString(Labels[i], rf, 3000, G.TF).Width;
        rx -= w;
        G.Text(g, Labels[i], rf, Th.Soft, new RectangleF(rx, 0, w + 8f, Height), StringAlignment.Near, StringAlignment.Center, false);
        rx -= 24f;
        Ic.Draw(g, Icons[i], rx + 8f, cy, 16f, Th.Mut);
        rx -= 30f;
      }
    }
  }

  // ---------------------------------------------------------------- license key screen (glass card, animated)
  public class Lock : Control {
    public Image Logo;
    public string Brand = "", Sub = "", Footer = "", Msg = "", RememberText = "REMEMBER THIS PC", Hwid = "", Auth = "", CopyHint = "NO KEY YET? COPY YOUR HWID";
    public Color MsgColor = HX.Pal.Bad; public bool KeyFocus, Caps, Reveal;
    public int State;   // 0 idle, 1 invalid key, 2 access granted, 3 locked
    public Rectangle BoxRect = new Rectangle(30, 190, 300, 46);
    public TextBox Edit; public int EditLeft = 70;
    public event EventHandler CloseClick, EyeClick, PasteClick, RememberClick, SuccessDone, HwidClick;
    Rectangle cl = new Rectangle(322, 18, 24, 24);
    Rectangle chipH = new Rectangle(30, 252, 152, 34), chipA = new Rectangle(190, 252, 140, 34);
    Rectangle hintR = new Rectangle(30, 436, 300, 20);
    bool hotClose, hotEye, hotPaste, hotRem, hotHwid, hotHint;
    float shake, phase, grant, focusA, hwA, hintA; int shakeN = -1, grantN; bool doneFired;
    Timer tm = new Timer();
    public Lock() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
      BackColor = Color.FromArgb(12, 17, 34);
      tm.Interval = 30;
      tm.Tick += delegate {
        phase += 0.035f; if (phase > 6.2832f) phase -= 6.2832f;
        focusA += ((KeyFocus ? 1f : 0f) - focusA) * 0.25f;
        hwA += ((hotHwid ? 1f : 0f) - hwA) * 0.3f;
        hintA += ((hotHint ? 1f : 0f) - hintA) * 0.3f;
        if (shakeN >= 0) {
          shakeN++;
          if (shakeN > 18) { shakeN = -1; shake = 0f; }
          else shake = (float)(Math.Sin(shakeN * 1.7) * 9.0 * (1.0 - shakeN / 18.0));
          if (Edit != null) Edit.Left = EditLeft + (int)shake;
        }
        if (State == 2) {
          grantN++; grant = Math.Min(1f, grantN / 14f);
          if (grantN >= 30 && !doneFired) { doneFired = true; EventHandler h = SuccessDone; if (h != null) h(this, EventArgs.Empty); }
        }
        Invalidate();
      };
      tm.Start();
    }
    protected override void Dispose(bool d) { if (d) tm.Dispose(); base.Dispose(d); }
    Rectangle EyeR { get { return new Rectangle(BoxRect.Right - 56 + (int)shake, BoxRect.Y + 12, 22, 22); } }
    Rectangle PasteR { get { return new Rectangle(BoxRect.Right - 32 + (int)shake, BoxRect.Y + 12, 22, 22); } }
    Rectangle RemR { get { return new Rectangle(76, 320, 200, 24); } }
    public void Shake() { shakeN = 0; }
    public void Succeed() { State = 2; grantN = 0; grant = 0f; doneFired = false; Invalidate(); }
    public void Reset() { if (State == 0 || State == 1) { State = 0; Msg = ""; } Invalidate(); }

    protected override void OnMouseMove(MouseEventArgs e) {
      hotClose = cl.Contains(e.Location); hotEye = EyeR.Contains(e.Location); hotPaste = PasteR.Contains(e.Location); hotRem = RemR.Contains(e.Location);
      hotHwid = chipH.Contains(e.Location); hotHint = hintR.Contains(e.Location);
      Cursor = (hotClose || hotEye || hotPaste || hotRem || hotHwid || hotHint) ? Cursors.Hand : Cursors.Default;
      base.OnMouseMove(e);
    }
    protected override void OnMouseLeave(EventArgs e) {
      hotClose = hotEye = hotPaste = hotRem = hotHwid = hotHint = false; Cursor = Cursors.Default; base.OnMouseLeave(e);
    }
    protected override void OnMouseDown(MouseEventArgs e) {
      base.OnMouseDown(e);
      if (e.Button != MouseButtons.Left) return;
      if (State != 2) {
        if (cl.Contains(e.Location)) { if (CloseClick != null) CloseClick(this, EventArgs.Empty); return; }
        if (EyeR.Contains(e.Location)) { if (EyeClick != null) EyeClick(this, EventArgs.Empty); return; }
        if (PasteR.Contains(e.Location)) { if (PasteClick != null) PasteClick(this, EventArgs.Empty); return; }
        if (RemR.Contains(e.Location)) { if (RememberClick != null) RememberClick(this, EventArgs.Empty); return; }
        if (chipH.Contains(e.Location) || hintR.Contains(e.Location)) { if (HwidClick != null) HwidClick(this, EventArgs.Empty); return; }
      }
      Form f = FindForm(); if (f != null) HX.Native.Drag(f.Handle);
    }

    void Blob(Graphics g, float cx, float cy, float rx, float ry, Color c, int a) {
      using (GraphicsPath gp = new GraphicsPath()) {
        gp.AddEllipse(cx - rx, cy - ry, rx * 2f, ry * 2f);
        using (PathGradientBrush pg = new PathGradientBrush(gp)) { pg.CenterColor = Color.FromArgb(a, c); pg.SurroundColors = new Color[] { Color.FromArgb(0, c) }; g.FillPath(pg, gp); }
      }
    }

    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g);
      float W = Width, H = Height;
      g.Clear(Color.FromArgb(5, 8, 18));
      // drifting colour glows behind the glass card
      Blob(g, 70f + (float)Math.Sin(phase) * 34f, 90f + (float)Math.Cos(phase * 0.8f) * 20f, 210f, 190f, Th.Acc, 120);
      Blob(g, W - 40f + (float)Math.Cos(phase * 0.7f) * 30f, H - 90f + (float)Math.Sin(phase) * 26f, 230f, 200f, Color.FromArgb(124, 92, 246), 95);
      Blob(g, W * 0.55f, 230f + (float)Math.Sin(phase * 1.3f) * 14f, 150f, 110f, Color.FromArgb(34, 211, 238), 38);
      Color accent = (State == 2) ? Th.Ok : (State == 1 ? Th.Bad : (State == 3 ? Th.Warn : Th.AccHi));
      // glass card
      RectangleF card = new RectangleF(10.5f, 10.5f, W - 21f, H - 21f);
      using (GraphicsPath cp = G.Round(card, 26)) {
        using (LinearGradientBrush lb = new LinearGradientBrush(card, Color.FromArgb(168, 14, 19, 38), Color.FromArgb(205, 8, 11, 24), 90f)) g.FillPath(lb, cp);
        using (Pen bp = new Pen(Color.FromArgb(46, 255, 255, 255), 1f)) g.DrawPath(bp, cp);
      }
      using (Pen hp = new Pen(Color.FromArgb(34, 255, 255, 255), 1f)) g.DrawLine(hp, 40f, 11.5f, W - 40f, 11.5f);
      // close
      using (Pen p = new Pen(hotClose ? Th.Txt : Th.Dim, 1.4f)) { g.DrawLine(p, cl.X + 8, cl.Y + 8, cl.Right - 8, cl.Bottom - 8); g.DrawLine(p, cl.Right - 8, cl.Y + 8, cl.X + 8, cl.Bottom - 8); }
      // logo with breathing glow
      float cx = W / 2f, ly = 74f;
      Blob(g, cx, ly, 92f, 80f, accent, State == 0 ? 56 : 90);
      if (State == 2 && grant < 1f) {
        float rr = 52f + grant * 34f;
        using (Pen p = new Pen(Color.FromArgb((int)(170f * (1f - grant)), Th.Ok), 1.5f)) g.DrawEllipse(p, cx - rr, ly - rr, rr * 2f, rr * 2f);
      }
      float ls = 104f + (float)Math.Sin(phase) * 2f;
      if (Logo != null) { try { g.DrawImage(Logo, new RectangleF(cx - ls / 2f, ly - ls / 2f, ls, ls)); } catch (Exception) { } }
      // title + subtitle
      Font tf = Fx.F(17f, true); string ttl = Brand.ToUpperInvariant();
      float tw = G.TrackW(g, ttl, tf, 20f);
      G.Track(g, ttl, tf, Color.FromArgb(70, 0, 0, 0), cx - tw / 2f + 1f, 133f, 20f);
      G.Track(g, ttl, tf, Th.Txt, cx - tw / 2f, 132f, 20f);
      Font sf = Fx.F(6.8f, true); float sw = G.TrackW(g, Sub, sf, 7f) + 14f; float sx = cx - sw / 2f;
      using (Pen p = new Pen(accent, 1f)) g.DrawEllipse(p, sx, 168f, 6f, 6f);
      G.Track(g, Sub, sf, Th.Mut, sx + 14f, 165f, 7f);
      // key box (shakes on a wrong key, glows on focus)
      float ox = shake;
      RectangleF br = new RectangleF(BoxRect.X + 0.5f + ox, BoxRect.Y + 0.5f, BoxRect.Width - 1, BoxRect.Height - 1);
      Color bl = G.Mix(Color.FromArgb(40, 52, 84), Th.AccHi, focusA);
      if (State == 1) bl = Color.FromArgb(170, 70, 70); else if (State == 2) bl = Color.FromArgb(60, 170, 110); else if (State == 3) bl = Color.FromArgb(160, 125, 45);
      if (focusA > 0.02f && State == 0) G.Box(g, new RectangleF(br.X - 2.5f, br.Y - 2.5f, br.Width + 5f, br.Height + 5f), 17, Color.Empty, Color.FromArgb((int)(52 * focusA), Th.AccHi));
      G.Box(g, br, 14, Color.FromArgb(9, 13, 26), bl);
      float ix = BoxRect.X + 26f + ox, iy = BoxRect.Y + BoxRect.Height / 2f;
      if (State == 2) HX.Ico.Draw(g, 22, ix, iy, 15f, Th.Ok);
      else if (State == 3) HX.Ico.Draw(g, 24, ix, iy, 15f, Th.Warn);
      else if (State == 1) HX.Ico.Draw(g, 19, ix, iy, 15f, Th.Bad);
      else HX.Ico.Draw(g, 19, ix, iy, 15f, G.Mix(Th.Dim, Th.AccHi, focusA));
      Rectangle er = EyeR, prc = PasteR;
      HX.Ico.Draw(g, Reveal ? 20 : 21, er.X + 11f, er.Y + 11f, 14f, hotEye ? Th.Txt : Th.Dim);
      HX.Ico.Draw(g, 23, prc.X + 11f, prc.Y + 11f, 14f, hotPaste ? Th.Txt : Th.Dim);
      // chips: HWID + AUTH
      RectangleF ch = new RectangleF(chipH.X + 0.5f, chipH.Y + 0.5f, chipH.Width - 1, chipH.Height - 1);
      G.Box(g, ch, 12, G.Mix(Color.FromArgb(9, 13, 26), Color.FromArgb(18, 28, 52), hwA), G.Mix(Color.FromArgb(34, 44, 72), Th.AccHi, hwA));
      Ic.Draw(g, Ic.Cpu, ch.X + 16f, ch.Y + ch.Height / 2f, 13f, Th.Dim);
      G.Text(g, "HWID", Fx.F(6.6f, true), Th.Dim, new RectangleF(ch.X + 30f, ch.Y, 36f, ch.Height), StringAlignment.Near, StringAlignment.Center, false);
      G.Text(g, Hwid, Fx.F(7.6f, true), Th.Soft, new RectangleF(ch.X + 64f, ch.Y, ch.Width - 70f, ch.Height), StringAlignment.Near, StringAlignment.Center, false);
      RectangleF ca = new RectangleF(chipA.X + 0.5f, chipA.Y + 0.5f, chipA.Width - 1, chipA.Height - 1);
      G.Box(g, ca, 12, Color.FromArgb(9, 13, 26), Color.FromArgb(34, 44, 72));
      Ic.Draw(g, Ic.Log, ca.X + 16f, ca.Y + ca.Height / 2f, 13f, Th.Dim);
      G.Text(g, "AUTH", Fx.F(6.6f, true), Th.Dim, new RectangleF(ca.X + 30f, ca.Y, 36f, ca.Height), StringAlignment.Near, StringAlignment.Center, false);
      G.Text(g, Auth, Fx.F(7.6f, true), (Auth == "online") ? Th.Ok : Th.Warn, new RectangleF(ca.X + 66f, ca.Y, ca.Width - 70f, ca.Height), StringAlignment.Near, StringAlignment.Center, false);
      // status line
      string m = Msg; Color mc = MsgColor;
      if (string.IsNullOrEmpty(m) && Caps) { m = "CAPS LOCK IS ON"; mc = Th.Warn; }
      G.Text(g, m, Fx.F(7.6f, true), mc, new RectangleF(30f, 294f, W - 60f, 20f), StringAlignment.Center, StringAlignment.Center, false);
      // remember label (switch is a child control at x=30)
      G.Track(g, RememberText, Fx.F(6.9f, true), hotRem ? Th.Soft : Th.Mut, 80f, 325f, 5f);
      // footer
      float dy = 416f;
      using (Pen p = new Pen(Color.FromArgb(26, 255, 255, 255), 1f)) { g.DrawLine(p, 36f, dy, cx - 50f, dy); g.DrawLine(p, cx + 50f, dy, W - 36f, dy); }
      G.Text(g, Footer, Fx.F(7f, false), Th.Dim, new RectangleF(cx - 50f, dy - 9f, 100f, 18f), StringAlignment.Center, StringAlignment.Center, false);
      Font hf = Fx.F(6.9f, true); string hint = CopyHint; float hw = G.TrackW(g, hint, hf, 4f);
      G.Track(g, hint, hf, G.Mix(Th.Dim, Th.AccHi, hintA), cx - hw / 2f, 438f, 4f);
    }
  }
}

'@
}
try { [HY.Fx]::Override = $UIFontName } catch {}

function Rgb($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
$cBg   = Rgb 6 9 28
$cSide = Rgb 7 11 30
$cCard = Rgb 12 17 40
$cOk   = Rgb 74 222 128
$cWarn = Rgb 250 190 60
$cGray = Rgb 122 133 157

[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $ev)
    try { Log ('ERR   ' + $ev.Exception.Message) } catch {}
})


$LogoB64 = (
    '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' +
    'SuQmCC'
)
try {
    $script:LogoStream = New-Object System.IO.MemoryStream (,[Convert]::FromBase64String($LogoB64))
    $script:LogoImg = [System.Drawing.Image]::FromStream($script:LogoStream)
} catch { Log ('Logo image failed: ' + $_.Exception.Message) }
try { $script:LogoImg = [HY.Brand]::Mark(160, $UI.Brand.Substring(0, 1)) } catch { Log ('Logo mark failed: ' + $_.Exception.Message) }

# ---------------------------------------------------------------- license key screen
# $LicenseHashes = SHA-256 of each valid key. The typed key is normalised first: upper-cased, spaces / zero-width chars removed,
# fancy dashes turned into '-'  (so a key must not contain spaces). Current key: Fade (typed in any case).
# Make a hash:  [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes('YOUR-KEY'.ToUpper()))).Replace('-','').ToLower()
$RequireKey    = $true
$RememberKey   = $false   # default position of the "Remember this PC" switch on the key screen (the user can flip it)
$MaxAttempts   = 5        # wrong keys allowed before a cooldown starts
$LockSeconds   = 30       # first cooldown; doubles every time it is triggered again (max 300 s)
$LicenseHashes = @('fc6fd35d8a9c8d6b1624d8d275727fc61ff203e03b313a9c337861ecddfe1b18')
$ContactDiscord = ''      # e.g. https://discord.gg/xxxx
$ContactWeb     = ''      # e.g. https://yoursite.com
$ContactInstagram = ''    # e.g. https://instagram.com/yourname

# ---- ONLINE (realtime) LICENSE: fill the two values below to switch it on (see license-server\README.md).
# Leave $LicenseServer empty = old offline mode (SHA-256 list above).
$LicenseServer     = ''   # e.g. https://hee-license.yourname.workers.dev
$LicensePubModulus = ''   # public key printed by gen-keys.mjs (base64)
$HeartbeatMinutes  = 5    # how often a running Hee re-checks the key (revoke / expiry kicks in within this time)
$GraceHours        = 24   # how long Hee may keep running with no internet before it closes
$UseServer = [bool]($LicenseServer -and $LicensePubModulus)
$LicenseFile = Join-Path $DataDir 'license.dat'

$script:lgFails = 0; $script:lgLocks = 0; $script:lgLockUntil = [DateTime]::MinValue

function Get-KeyHash([string]$k) {
    $k = [regex]::Replace($k, '[\s\u200B-\u200D\uFEFF]', '')
    $k = [regex]::Replace($k, '[\u2010-\u2015\u2212]', '-')
    $b = [System.Text.Encoding]::UTF8.GetBytes($k.ToUpperInvariant())
    $h = [System.Security.Cryptography.SHA256]::Create().ComputeHash($b)
    return (($h | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-Hwid {
    if ($script:HwidCache) { return $script:HwidCache }
    $mg = ''; $uu = ''
    try { $mg = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -ErrorAction Stop).MachineGuid } catch {}
    try { $uu = (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction Stop).UUID } catch {}
    $h = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes("HEE|$mg|$uu"))
    $script:HwidCache = ((($h | ForEach-Object { $_.ToString('x2') }) -join '')).Substring(0, 32)
    return $script:HwidCache
}

function Test-LicSig([string]$payload, [string]$sig) {
    try {
        $pr = New-Object System.Security.Cryptography.RSAParameters
        $pr.Modulus = [Convert]::FromBase64String($LicensePubModulus); $pr.Exponent = [byte[]](1, 0, 1)
        $rsa = [System.Security.Cryptography.RSA]::Create(); $rsa.ImportParameters($pr)
        return [bool]$rsa.VerifyData([System.Text.Encoding]::UTF8.GetBytes($payload), [Convert]::FromBase64String($sig),
            [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } catch { return $false }
}

# asks the license server; returns @{ ok; err; payload; sig; exp }.  err = not_found | revoked | expired | hwid_mismatch | rate_limited | network | badsig
function Invoke-LicenseCheck([string]$key) {
    $nonce = [Guid]::NewGuid().ToString('N'); $hw = Get-Hwid
    $body = @{ key = $key; hwid = $hw; nonce = $nonce; ver = $MKVersion } | ConvertTo-Json -Compress
    $r = $null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $r = Invoke-RestMethod -Uri ($LicenseServer.TrimEnd('/') + '/v1/check') -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 8
    } catch {
        $code = 0; try { $code = [int]$_.Exception.Response.StatusCode } catch {}
        if ($code -eq 429) { return @{ ok = $false; err = 'rate_limited' } }
        return @{ ok = $false; err = 'network' }
    }
    if (-not $r -or -not $r.ok) { $e = 'network'; if ($r -and $r.error) { $e = [string]$r.error }; return @{ ok = $false; err = $e } }
    if (-not (Test-LicSig ([string]$r.payload) ([string]$r.sig))) { return @{ ok = $false; err = 'badsig' } }
    $pl = $null; try { $pl = ([string]$r.payload) | ConvertFrom-Json } catch {}
    if (-not $pl -or $pl.n -ne $nonce -or $pl.h -ne $hw) { return @{ ok = $false; err = 'badsig' } }
    return @{ ok = $true; err = ''; payload = [string]$r.payload; sig = [string]$r.sig; exp = [int64]$pl.e }
}

# offline fallback: cached, signed server answer that is still inside the grace period
function Test-LicOffline($sv) {
    try {
        if (-not (Test-LicSig ([string]$sv.payload) ([string]$sv.sig))) { return $false }
        $pl = ([string]$sv.payload) | ConvertFrom-Json
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ($pl.h -ne (Get-Hwid)) { return $false }
        if ([int64]$pl.e -gt 0 -and $now -gt [int64]$pl.e) { return $false }
        if ($now -lt ([int64]$pl.t - 600) -or ($now - [int64]$pl.t) -gt ($GraceHours * 3600)) { return $false }
        return $true
    } catch { return $false }
}

function Get-LicErrorText([string]$e) {
    switch ($e) {
        'not_found'     { return 'INVALID KEY' }
        'revoked'       { return 'KEY REVOKED' }
        'expired'       { return 'KEY EXPIRED' }
        'hwid_mismatch' { return 'KEY IS ALREADY USED ON ANOTHER PC' }
        'network'       { return 'CANNOT REACH LICENSE SERVER' }
        'rate_limited'  { return 'TOO MANY REQUESTS - WAIT A MOMENT' }
        'badsig'        { return 'INVALID SERVER RESPONSE' }
        default         { return ('LICENSE ERROR: ' + $e) }
    }
}

function Update-Caps {
    try { $script:lgPanel.Caps = [System.Windows.Forms.Control]::IsKeyLocked([System.Windows.Forms.Keys]::CapsLock) } catch {}
    $script:lgPanel.Invalidate()
}

# cooldown ticker: shows the countdown, unlocks the form when it reaches zero
function Update-LoginLock {
    $left = [int][Math]::Ceiling(($script:lgLockUntil - [DateTime]::Now).TotalSeconds)
    if ($left -gt 0) {
        $script:lgPanel.State = 3; $script:lgPanel.MsgColor = [HX.Pal]::Warn
        $script:lgPanel.Msg = ('TOO MANY ATTEMPTS - TRY AGAIN IN {0}S' -f $left)
    } else {
        $script:lgLockTimer.Stop(); $script:lgFails = 0
        $script:lgPanel.State = 0; $script:lgPanel.Msg = ''
        $script:lgBtn.Enabled = $true; $script:lgBox.ReadOnly = $false
        $script:lgBox.Focus()
    }
    $script:lgPanel.Invalidate()
}

function Invoke-Activate {
    if ($script:lgPanel.State -ge 2 -or [DateTime]::Now -lt $script:lgLockUntil) { return }
    $k = $script:lgBox.Text.Trim()
    if (-not $k) {
        $script:lgPanel.MsgColor = (Rgb 122 133 157); $script:lgPanel.Msg = 'ENTER YOUR KEY'
        $script:lgPanel.Shake(); $script:lgPanel.Invalidate(); return
    }
    $script:lgPanel.State = 0; $script:lgPanel.MsgColor = (Rgb 122 133 157); $script:lgPanel.Msg = $(if ($UseServer) { 'CONTACTING SERVER...' } else { 'CHECKING...' })
    $script:lgBtn.Enabled = $false; $script:lgPanel.Invalidate(); [System.Windows.Forms.Application]::DoEvents()
    $res = $null; $good = $false; $err = ''
    if ($UseServer) { $res = Invoke-LicenseCheck $k; $good = [bool]$res.ok; $err = [string]$res.err }
    else { $good = ($LicenseHashes -contains (Get-KeyHash $k)); if (-not $good) { $err = 'not_found' } }
    $script:lgBtn.Enabled = $true
    if ($good) {
        $script:LicKey = $k
        if ($script:lgTog.Checked) {
            try {
                if ($UseServer) { (@{ key = $k; payload = $res.payload; sig = $res.sig } | ConvertTo-Json -Compress) | Set-Content -Path $LicenseFile -Encoding ASCII }
                else { Set-Content -Path $LicenseFile -Value (Get-KeyHash $k) -Encoding ASCII }
            } catch {}
        } else { try { Remove-Item -LiteralPath $LicenseFile -Force -ErrorAction SilentlyContinue } catch {} }
        $msg = 'ACCESS GRANTED'
        if ($UseServer -and $res.exp -gt 0) {
            $days = [int][Math]::Ceiling(($res.exp - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) / 86400.0)
            $msg = ('ACCESS GRANTED - {0} DAY{1} LEFT' -f $days, $(if ($days -eq 1) { '' } else { 'S' }))
        }
        $script:lgBtn.Enabled = $false; $script:lgBox.ReadOnly = $true
        $script:lgPanel.MsgColor = [HX.Pal]::Ok; $script:lgPanel.Msg = $msg
        $script:lgPanel.Succeed()          # animation ends -> SuccessDone closes the form
        return
    }
    $script:lgPanel.State = 1; $script:lgPanel.MsgColor = [HX.Pal]::Bad
    if ($err -eq 'not_found') {            # only wrong keys count toward the cooldown
        $script:lgFails++
        if ($script:lgFails -ge $MaxAttempts) {
            $script:lgLocks++
            $secs = [Math]::Min(300, $LockSeconds * [Math]::Pow(2, $script:lgLocks - 1))
            $script:lgLockUntil = [DateTime]::Now.AddSeconds($secs)
            $script:lgBtn.Enabled = $false; $script:lgBox.ReadOnly = $true
            $script:lgLockTimer.Start(); Update-LoginLock
        } else {
            $script:lgPanel.Msg = ('INVALID KEY - {0} TRIES LEFT' -f ($MaxAttempts - $script:lgFails))
        }
    } else {
        $script:lgPanel.Msg = (Get-LicErrorText $err)
    }
    $script:lgPanel.Shake(); $script:lgPanel.Invalidate()
    $script:lgBox.SelectAll(); if (-not $script:lgBox.ReadOnly) { $script:lgBox.Focus() }
}

function Open-Link($url) {
    if ($url) { try { Start-Process $url } catch {} }
    else { $script:lgPanel.State = 0; $script:lgPanel.MsgColor = (Rgb 122 133 157); $script:lgPanel.Msg = 'LINK NOT SET'; $script:lgPanel.Invalidate() }
}

function Show-Login {
    $f = New-Object HX.HForm
    $f.FormBorderStyle = 'None'; $f.ClientSize = New-Object System.Drawing.Size(360, 470); $f.StartPosition = 'CenterScreen'
    $f.BackColor = (Rgb 5 8 18); $f.Text = $UI.Brand; $f.KeyPreview = $true; $f.Tag = ''; $f.Opacity = 0
    if ($script:LogoImg) { try { $f.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]$script:LogoImg).GetHicon()) } catch {} }
    $p = New-Object HY.Lock
    $p.Dock = 'Fill'; $p.Logo = $script:LogoImg; $p.Brand = $UI.Brand
    $p.Sub = 'PERFORMANCE OPTIMIZATION SUITE'; $p.Footer = ($UI.Brand + ' 2026')
    $p.Hwid = (Get-Hwid); $p.Auth = $(if ($UseServer) { 'online' } else { 'offline' })
    $f.Controls.Add($p)
    $script:lgForm = $f; $script:lgPanel = $p
    if ($script:LoginNote) { $p.State = 1; $p.MsgColor = [HX.Pal]::Bad; $p.Msg = $script:LoginNote }

    # key box: masked by default, auto upper-case, placeholder text; eye / paste buttons are drawn by HY.Lock
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.BorderStyle = 'None'; $tb.BackColor = (Rgb 9 13 26); $tb.ForeColor = (Rgb 236 242 252)
    $tb.Font = New-Object System.Drawing.Font('Consolas', 10.5, [System.Drawing.FontStyle]::Bold); $tb.MaxLength = 64
    $tb.CharacterCasing = 'Upper'; $tb.PasswordChar = [char]0x2022
    $tb.Location = New-Object System.Drawing.Point($p.EditLeft, ($p.BoxRect.Y + 13)); $tb.Size = New-Object System.Drawing.Size(196, 22)
    $p.Controls.Add($tb); $script:lgBox = $tb; $p.Edit = $tb
    $tb.Add_GotFocus({ $script:lgPanel.KeyFocus = $true; Update-Caps })
    $tb.Add_LostFocus({ $script:lgPanel.KeyFocus = $false })
    $tb.Add_KeyUp({ Update-Caps })
    $tb.Add_TextChanged({ $script:lgPanel.Reset() })
    $tb.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Return') { $e.SuppressKeyPress = $true; Invoke-Activate } })

    # remember-this-PC switch
    $tg = New-Object HX.Toggle
    $tg.Under = (Rgb 12 17 34); $tg.Size = New-Object System.Drawing.Size(38, 22); $tg.Location = New-Object System.Drawing.Point(30, 318)
    $tg.SetInstant([bool]$RememberKey)
    $p.Controls.Add($tg); $script:lgTog = $tg

    $b = New-Object HY.Bt
    $b.Kind = 2; $b.Text = 'Unlock & Launch'; $b.Size = New-Object System.Drawing.Size(300, 48); $b.Location = New-Object System.Drawing.Point(30, 352)
    $b.BackColor = (Rgb 12 17 34)
    $p.Controls.Add($b); $script:lgBtn = $b
    $b.Add_Click({ Invoke-Activate })

    $p.add_CloseClick({ $script:lgForm.Close() })
    $p.add_RememberClick({ $script:lgTog.Checked = -not $script:lgTog.Checked })
    $p.add_HwidClick({
        try {
            [System.Windows.Forms.Clipboard]::SetText((Get-Hwid))
            $script:lgPanel.State = 0; $script:lgPanel.MsgColor = [HX.Pal]::Ok; $script:lgPanel.Msg = 'HWID COPIED'
        } catch {}
    })
    $p.add_EyeClick({
        $script:lgPanel.Reveal = -not $script:lgPanel.Reveal
        $script:lgBox.PasswordChar = $(if ($script:lgPanel.Reveal) { [char]0 } else { [char]0x2022 })
        $script:lgBox.Focus()
    })
    $p.add_PasteClick({
        if ($script:lgBox.ReadOnly) { return }
        $t = ''
        try { $t = [System.Windows.Forms.Clipboard]::GetText() } catch {}
        $t = ((@($t -split '\r?\n')[0]) + '').Trim()
        if ($t) {
            if ($t.Length -gt 64) { $t = $t.Substring(0, 64) }
            $script:lgBox.Text = $t; $script:lgBox.SelectionStart = $script:lgBox.TextLength; $script:lgBox.Focus()
        } else {
            $script:lgPanel.State = 0; $script:lgPanel.MsgColor = (Rgb 122 133 157); $script:lgPanel.Msg = 'CLIPBOARD IS EMPTY'
        }
    })
    $p.add_SuccessDone({ $script:lgForm.Tag = 'ok'; $script:lgForm.Close() })

    $lt = New-Object System.Windows.Forms.Timer
    $lt.Interval = 500; $lt.Add_Tick({ Update-LoginLock })
    $script:lgLockTimer = $lt

    $f.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape' -and $script:lgPanel.State -ne 2) { $s.Close() } })
    $f.Add_Shown({
        param($s, $e)
        $rc = New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)
        $s.Region = New-Object System.Drawing.Region([HX.G]::Round($rc, 28))
        try { [HX.Native]::Cue($script:lgBox.Handle, 'ENTER LICENSE KEY') } catch {}
        $s.Activate(); $script:lgBox.Focus()
        $script:lgFade = New-Object System.Windows.Forms.Timer
        $script:lgFade.Interval = 15
        $script:lgFade.Add_Tick({
            $o = $script:lgForm.Opacity + 0.08
            if ($o -ge 1) { $script:lgForm.Opacity = 1; $script:lgFade.Stop() } else { $script:lgForm.Opacity = $o }
        })
        $script:lgFade.Start()
    })
    [void]$f.ShowDialog()
    try { $script:lgLockTimer.Stop(); $script:lgLockTimer.Dispose(); $script:lgFade.Stop() } catch {}
    $ok = ([string]$f.Tag -eq 'ok')
    $f.Dispose()
    return $ok
}

$LicenseOk = (-not $RequireKey)
$script:LicKey = ''; $script:LoginNote = ''
# a license.dat only exists when the user ticked "Remember this PC" on an earlier launch
if (-not $LicenseOk -and (Test-Path -LiteralPath $LicenseFile)) {
    $raw = ''; try { $raw = (Get-Content -LiteralPath $LicenseFile -Raw).Trim() } catch {}
    if ($UseServer) {
        $sv = $null; try { $sv = $raw | ConvertFrom-Json } catch {}
        if ($sv -and $sv.key) {
            $r = Invoke-LicenseCheck ([string]$sv.key)
            if ($r.ok) {
                $LicenseOk = $true; $script:LicKey = [string]$sv.key
                try { (@{ key = [string]$sv.key; payload = $r.payload; sig = $r.sig } | ConvertTo-Json -Compress) | Set-Content -Path $LicenseFile -Encoding ASCII } catch {}
            } elseif ($r.err -eq 'network' -or $r.err -eq 'rate_limited') {
                if (Test-LicOffline $sv) { $LicenseOk = $true; $script:LicKey = [string]$sv.key }
                else { $script:LoginNote = (Get-LicErrorText $r.err) }
            } else {
                try { Remove-Item -LiteralPath $LicenseFile -Force -ErrorAction SilentlyContinue } catch {}
                $script:LoginNote = (Get-LicErrorText $r.err)
            }
        }
    } else {
        try { if ($LicenseHashes -contains $raw) { $LicenseOk = $true } } catch {}
    }
}
if (-not $LicenseOk) { $LicenseOk = ((@(Show-Login) | Select-Object -Last 1) -eq $true) }
if (-not $LicenseOk) { exit }
$script:LicLastOk = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
Log 'License accepted.'

# ---- window skeleton: [header] / [sidebar | pages] / [footer]
$cBg = Rgb 6 9 20; $cCard = Rgb 11 16 30; $cOk = Rgb 52 211 153; $cWarn = Rgb 250 190 60
$osShort = ($OsName -replace '^Microsoft\s+', '')
$form = New-Object HX.HForm
$form.FormBorderStyle = 'None'
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$fw = [Math]::Min(1280, $wa.Width - 20); $fh = [Math]::Min(800, $wa.Height - 20)
$form.ClientSize = New-Object System.Drawing.Size($fw, $fh)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $cBg; $form.ForeColor = (Rgb 236 242 252)
$form.Font = [HY.Fx]::F(9.5, $false)
$form.Text = ($UI.Brand + ' ' + $MKVersion)
$form.Opacity = 0

$content = New-Object System.Windows.Forms.Panel
$content.Dock = 'Fill'; $content.BackColor = $cBg
$side = New-Object HY.Side
$side.Dock = 'Left'; $side.Width = 246
$head = New-Object HY.Head
$head.Dock = 'Top'; $head.Height = 88
$foot = New-Object HY.Foot
$foot.Dock = 'Bottom'; $foot.Height = 50
$form.Controls.Add($content); $form.Controls.Add($side); $form.Controls.Add($foot); $form.Controls.Add($head)

# optional custom logo: put logo.png next to the script (or in ProgramData\MostKill) to replace the drawn text logo
$script:UiLogo = $null
foreach ($bd in @($PSScriptRoot, $DataDir)) {
    if (-not $bd) { continue }
    $lf = Join-Path $bd 'logo.png'
    if ((-not $script:UiLogo) -and (Test-Path -LiteralPath $lf)) {
        try {
            $script:UiLogoStream = New-Object System.IO.MemoryStream (,[System.IO.File]::ReadAllBytes($lf))
            $script:UiLogo = [System.Drawing.Image]::FromStream($script:UiLogoStream)
        } catch {}
    }
}

$head.Brand = $UI.Brand; $head.BrandSub = $UI.BrandSub; $head.Line1 = $UI.Tag1; $head.Line2 = $UI.Tag2; $head.Credit = $UI.Credit
if ($script:UiLogo) { $head.LogoImg = $script:UiLogo }
if ($script:LogoImg) { try { $form.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]$script:LogoImg).GetHicon()) } catch {} }
$head.add_CloseClick({ $form.Close() })
$head.add_MinClick({ $form.WindowState = 'Minimized' })

$side.StatusTitle = $UI.StatusTitle; $side.HomeText = $UI.Home; $side.LogText = $UI.LogNav; $side.ResetLabel = $UI.ResetNav
$side.Welcome = $UI.Welcome; $side.UserName = $UI.UserName; $side.UserQuote = $UI.UserQuote
$side.Brand = $UI.Brand; $side.BrandSub = $UI.BrandSub
if ($script:UiLogo) { $side.LogoImg = $script:UiLogo }

$foot.Ver = ($UI.VerText + ' ' + $UI.Version)
foreach ($fi in @(@(2, $UI.F1), @(12, $UI.F2), @(8, $UI.F3), @(22, $UI.F4))) { $foot.Icons.Add([int]$fi[0]); $foot.Labels.Add([string]$fi[1]) }

$script:Pages = [ordered]@{}
function New-PageShell($key) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = 'Fill'; $p.BackColor = $cBg; $p.Visible = $false
    $p.Padding = New-Object System.Windows.Forms.Padding(22, 16, 22, 14)
    $content.Controls.Add($p)
    $script:Pages[$key] = $p
    return $p
}

# ---------------------------------------------------------------- mode definitions
# Each mode bundles tweaks from the list above. Default state per tweak:  on = applied  |  off = optional (right-click the card to turn on)
#   rec = follow the tweak's own hardware-aware recommendation  |  desk = on for desktops, off for laptops (battery)
$ModeDefs = @(
    @{ Key='fps';      Icon=1;  Col=@(59,130,246);  Pre=$true;  Title='โหมดเน้น FPS';     Tag='FPS';      D1='ดัน Priority ให้เกม';        D2='ลด Input Lag'
       T=@(@('Win32PrioritySeparation','on'), @('MMCSS + Games profile','on'), @('Global timer resolution requests','on'), @('Timer Resolution service','on'), @('csrss.exe (input) priority High','on'), @('Boot timer tweaks (bcdedit)','off')) },
    @{ Key='gaming';   Icon=2;  Col=@(56,189,248);  Pre=$true;  Title='โหมดเกมมิ่ง';       Tag='GAMING';   D1='ปิด Game Bar / DVR';          D2='เปิด Fullscreen แท้'
       T=@(@('Game DVR / Game Bar off + FSE behavior','on'), @('Hardware-accelerated GPU scheduling (HAGS)','off'), @('NVIDIA driver low-latency keys','off')) },
    @{ Key='desktop';  Icon=3;  Col=@(34,211,238);  Pre=$false; Title='โหมดหน้าจอลื่น';    Tag='DESKTOP';  D1='ตัดดีเลย์เมนู';              D2='ปิดแอนิเมชันหน้าต่าง'
       T=@(,@('Desktop responsiveness (menus + animations)','on')) },
    @{ Key='keyboard'; Icon=4;  Col=@(129,140,248); Pre=$true;  Title='โหมดคีย์บอร์ด';     Tag='KEYBOARD'; D1='รีพีทคีย์เร็วสุด';          D2='ปิด Sticky Keys'
       T=@(@('Keyboard + mouse data queue size','on'), @('Fast keyboard repeat + Sticky/Filter/Toggle keys off','on')) },
    @{ Key='power';    Icon=5;  Col=@(96,165,250);  Pre=$false; Title='โหมดพลังงานสูง';    Tag='POWER';    D1='ปิด Hibernate';               D2='ปลดล็อก Power Plan'
       T=@(@('Ultimate Performance power plan','desk'), @('No core parking + min CPU 100% (AC)','desk'), @('Power throttling off + timer coalescing off','on'), @('Fast Startup off (real cold boot)','on'), @('Hibernate off','desk')) },
    @{ Key='net';      Icon=6;  Col=@(14,165,233);  Pre=$false;  Title='โหมดเน็ตลื่น';       Tag='NET';      D1='ปิด Nagle Algorithm';         D2='ลดดีเลย์ TCP'
       T=@(@('Nagle off (per interface)','on'), @('TCP global (netsh)','on'), @('TCP / DNS registry (conservative)','on'), @('NIC power-saving off (physical adapters)','on')) },
    @{ Key='netfade';  Icon=12; Col=@(20,184,166);  Pre=$true; Title='โหมด NetFade';        Tag='NETFADE';  D1='RSS + Offload ค่าเน็ตส่วนตัว'; D2='MSI Mode + NIC Tuning'
       T=@(@('NetFade: RSS + global offload','on'), @('NetFade: IPv4 interface settings','on'), @('NetFade: NIC advanced + power-saving off','on'), @('NetFade: NIC MSI mode + interrupt priority','on')) },
    @{ Key='nvidia';   Icon=9;  Col=@(118,185,0);   Pre=$true; Title='โหมดการ์ดจอ NVIDIA';  Tag='NVIDIA';   D1='Power สูงสุด + MSI Mode';     D2='ปิด Telemetry / ลด TDR'
       T=@(@('NVIDIA: max performance power state (PowerMizer)','desk'), @('NVIDIA: lock GPU at P0 (no idle downclock)','off'), @('NVIDIA: GPU MSI mode','on'), @('NVIDIA: telemetry off','on'), @('GPU: longer TDR timeout (TdrDelay 10)','on'), @('Windowed game optimizations (flip model upgrade)','on'), @('NVIDIA shader cache cleaner (one-time)','off')) },
    @{ Key='system';   Icon=7;  Col=@(148,163,200); Pre=$true; Title='โหมดระบบเสถียร';    Tag='SYSTEM';   D1='Kernel อยู่ใน RAM';           D2='ปิด USB Suspend'
       T=@(@('USB selective suspend off','on'), @('NTFS tweaks','on'), @('Prefetch / SysMain off (SSD)','rec'), @('Keep kernel in RAM (DisablePagingExecutive)','rec')) },
    @{ Key='privacy';  Icon=8;  Col=@(125,170,255); Pre=$false; Title='โหมดปิดติดตาม';     Tag='PRIVACY';  D1='ปิด Telemetry';               D2='ลดงานเบื้องหลัง'
       T=@(@('Telemetry level 0 (policy)','on'), @('Clean temp files + flush DNS (one-time)','on')) },
    @{ Key='fivem';    Icon=9;  Col=@(37,99,235);   Pre=$false;  Title='โหมด FiveM';         Tag='FIVEM';    D1='Priority สูงให้ GTA V';       D2='บังคับใช้ GPU แยก'
       T=@(@('FiveM / GTA process priority = High','on'), @('FiveM QoS (DSCP 46)','on'), @('Force dedicated GPU for FiveM / GTA','on'), @('FiveM cache cleaner (one-time)','off')) },
    @{ Key='mouse';    Icon=10; Col=@(6,182,212);   Pre=$true;  Title='โหมดเมาส์';          Tag='MOUSE';    D1='ปิด Acceleration';            D2='เมาส์แม่นยำ 1:1'
       T=@(,@('Mouse acceleration off (1:1)','on')) }
)

$script:TwOn   = @{}     # tweak name -> enabled
$script:TwDef  = @{}     # tweak name -> default enabled
$script:OptSel = @{}     # tweak name -> chosen option label
$script:Modes  = New-Object System.Collections.ArrayList
$script:ModeByKey = @{}

$grid = New-Object HY.ModeGrid
$grid.Cols = 6
$grid.RestoreText = $UI.Restore; $grid.ActiveText = $UI.Active
foreach ($md in $ModeDefs) {
    $mo = New-Object HY.Mode
    $mo.Key = $md.Key; $mo.Title = $md.Title; $mo.Tag = $md.Tag; $mo.D1 = $md.D1; $mo.D2 = $md.D2; $mo.Icon = [int]$md.Icon
    $mo.Col = Rgb $md.Col[0] $md.Col[1] $md.Col[2]
    $mo.Selected = [bool]$md.Pre
    $tw = New-Object System.Collections.ArrayList
    foreach ($pair in $md.T) {
        $t = $Tweaks | Where-Object { $_.Name -eq $pair[0] } | Select-Object -First 1
        if (-not $t) { continue }
        [void]$tw.Add($t)
        $on = $false
        switch ($pair[1]) { 'on' { $on = $true } 'rec' { $on = [bool]$t.Rec } 'desk' { $on = (-not $IsLaptop) } default { $on = $false } }
        $script:TwDef[$t.Name] = $on; $script:TwOn[$t.Name] = $on
        if ($t.Opts) { $script:OptSel[$t.Name] = [string](@($t.Opts.Keys)[0]) }
    }
    $o = @{ Mode = $mo; Def = $md; Tweaks = $tw }
    [void]$script:Modes.Add($o); $script:ModeByKey[$md.Key] = $o
    [void]$grid.Modes.Add($mo)
}

# ---------------------------------------------------------------- home page
$pHome = New-PageShell 'home'
$topRow = New-Object HY.TopRow
$topRow.Dock = 'Top'; $topRow.Height = 62; $topRow.Title = $UI.Choose
$topRow.Box.Placeholder = $UI.Search
$gridHost = New-Object System.Windows.Forms.Panel
$gridHost.Dock = 'Fill'; $gridHost.BackColor = $cBg; $gridHost.Padding = New-Object System.Windows.Forms.Padding(0, 6, 0, 14)
$grid.Dock = 'Fill'
$gridHost.Controls.Add($grid)
$promo = New-Object HY.Promo
$promo.Dock = 'Bottom'; $promo.Height = 96
$promo.Line1 = $UI.PromoA; $promo.Line1b = $UI.PromoB; $promo.Line2 = $UI.PromoC
$bRec = New-Object HY.Bt; $bRec.Kind = 0; $bRec.Text = $UI.SelRec; $bRec.Size = New-Object System.Drawing.Size(150, 42); $bRec.BackColor = $cBg
$bApply = New-Object HY.Bt; $bApply.Kind = 1; $bApply.Icon = 22; $bApply.Text = $UI.Apply; $bApply.Size = New-Object System.Drawing.Size(250, 46); $bApply.BackColor = $cBg
$promo.Controls.Add($bRec); $promo.Controls.Add($bApply)
$promo.RightItems.Add($bRec); $promo.RightItems.Add($bApply)
$pHome.Controls.Add($gridHost); $pHome.Controls.Add($promo); $pHome.Controls.Add($topRow)
$promo.Lay()

# ---------------------------------------------------------------- activity log page
$pLog = New-PageShell 'log'
$logTop = New-Object HY.TopRow
$logTop.Dock = 'Top'; $logTop.Height = 62; $logTop.Title = $UI.LogTitle; $logTop.Box.Visible = $false
$logHost = New-Object System.Windows.Forms.Panel
$logHost.Dock = 'Fill'; $logHost.BackColor = $cBg; $logHost.Padding = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)
$logCard = New-Object HX.Card
$logCard.Dock = 'Fill'; $logCard.BackColor = $cBg; $logCard.Fill = $cCard
$script:logBox = New-Object System.Windows.Forms.TextBox
$script:logBox.Multiline = $true; $script:logBox.ReadOnly = $true; $script:logBox.ScrollBars = 'Vertical'
$script:logBox.BorderStyle = 'None'; $script:logBox.BackColor = $cCard; $script:logBox.ForeColor = (Rgb 200 214 238)
$script:logBox.Font = New-Object System.Drawing.Font('Consolas', 9.5); $script:logBox.Dock = 'Fill'
$logCard.Controls.Add($script:logBox); $logHost.Controls.Add($logCard)
$pLog.Controls.Add($logHost); $pLog.Controls.Add($logTop)

# ---------------------------------------------------------------- state helpers
function Get-ModeTweaks($o) { return @($o.Tweaks | Where-Object { $script:TwOn[$_.Name] }) }

function Update-Counts {
    $n = @($script:Modes | Where-Object { $_.Mode.Selected }).Count
    $bApply.Text = ('{0} ({1})' -f $UI.Apply, $n)
    $bApply.Invalidate()
}
function Refresh-Active {
    foreach ($o in $script:Modes) {
        $checked = 0; $okc = 0
        foreach ($t in (Get-ModeTweaks $o)) {
            if ($t.Check) { $checked++; $ok = $false; try { $ok = [bool](& $t.Check) } catch {}; if ($ok) { $okc++ } }
        }
        $o.Mode.Applied = ($checked -gt 0 -and $okc -eq $checked)
    }
    $grid.Invalidate()
}
function Update-Status {
    if (($script:Reg.Count + $script:X.Count) -gt 0) { $foot.Status = $UI.StOpt; $foot.StatusColor = $cOk }
    else { $foot.Status = $UI.StReady; $foot.StatusColor = [HY.Th]::AccHi }
    $foot.Invalidate()
}
function Set-Busy($b) {
    $side.Enabled = -not $b; $content.Enabled = -not $b
    if ($b) { $foot.Status = $UI.StBusy; $foot.StatusColor = $cWarn; $foot.Invalidate() } else { Update-Status }
    [System.Windows.Forms.Application]::DoEvents()
}

# ---------------------------------------------------------------- navigation
function Show-Page($key) {
    foreach ($k in @($script:Pages.Keys)) { $script:Pages[$k].Visible = ($k -eq $key) }
    $side.Page = $(if ($key -eq 'log') { 1 } else { 0 }); $side.Invalidate()
    if ($key -eq 'home' -and $form.Visible) { $grid.PlayIntro() }
    if ($key -eq 'log') { $script:logBox.SelectionStart = $script:logBox.TextLength; $script:logBox.ScrollToCaret() }
}

# ---------------------------------------------------------------- dark message dialog (buttons: first = primary)
function Show-Dlg([string]$msg, [string]$ttl, [string[]]$btns) {
    $d = New-Object System.Windows.Forms.Form
    $d.FormBorderStyle = 'None'; $d.StartPosition = 'CenterParent'; $d.ShowInTaskbar = $false
    $d.BackColor = (Rgb 10 15 30); $d.KeyPreview = $true; $d.Tag = ''
    $mf = [HY.Fx]::F(9.5, $false)
    $sz = [System.Windows.Forms.TextRenderer]::MeasureText($msg, $mf, (New-Object System.Drawing.Size(396, 0)), 'WordBreak')
    $mh = [Math]::Max(22, $sz.Height + 4)
    $d.ClientSize = New-Object System.Drawing.Size(444, (28 + 30 + $mh + 26 + 42 + 24))
    $lt = New-Object System.Windows.Forms.Label
    $lt.Text = $ttl; $lt.Font = [HY.Fx]::F(11.5, $true); $lt.ForeColor = (Rgb 236 242 252)
    $lt.AutoSize = $true; $lt.Location = New-Object System.Drawing.Point(24, 22); $lt.BackColor = $d.BackColor
    $lm = New-Object System.Windows.Forms.Label
    $lm.Text = $msg; $lm.Font = $mf; $lm.ForeColor = (Rgb 170 184 210); $lm.BackColor = $d.BackColor
    $lm.Location = New-Object System.Drawing.Point(24, 58); $lm.Size = New-Object System.Drawing.Size(396, $mh)
    $d.Controls.Add($lt); $d.Controls.Add($lm)
    $bx = 444 - 24
    for ($i = 0; $i -lt $btns.Count; $i++) {
        $b = New-Object HY.Bt
        $b.Text = $btns[$i]; $b.Kind = $(if ($i -eq 0) { 1 } else { 0 }); $b.BackColor = $d.BackColor
        $b.Size = New-Object System.Drawing.Size(([Math]::Max(104, ($btns[$i].Length * 10 + 44))), 40)
        $bx -= $b.Width
        $b.Location = New-Object System.Drawing.Point($bx, ($d.ClientSize.Height - 24 - 40))
        $bx -= 10
        $b.Add_Click({ param($s, $e) $f = $s.FindForm(); $f.Tag = $s.Text; $f.Close() })
        $d.Controls.Add($b)
    }
    $d.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape') { $s.Close() } })
    $d.Add_Paint({
        param($s, $e)
        $pp = New-Object System.Drawing.Pen((Rgb 37 99 235))
        $e.Graphics.DrawRectangle($pp, 0, 0, ($s.Width - 1), ($s.Height - 1)); $pp.Dispose()
    })
    $d.Add_Shown({
        param($s, $e)
        $rc = New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)
        $s.Region = New-Object System.Drawing.Region([HX.G]::Round($rc, 12))
    })
    [void]$d.ShowDialog($form)
    $res = [string]$d.Tag
    $d.Dispose()
    return $res
}

# ---------------------------------------------------------------- guided tour popup (shown when the main page opens; F1 opens it again)
$TourFlag = Join-Path $DataDir 'tour.off'
function Show-Tour {
    $steps = @(
        @('ยินดีต้อนรับสู่ Hee', "เครื่องมือรวมโหมดปรับแต่งเครื่องให้ลื่นขึ้น`r`nทัวร์สั้น ๆ นี้จะพาดูวิธีใช้งานใน 5 ขั้นตอน`r`n`r`nกด ถัดไป เพื่อเริ่มได้เลย"),
        @('1. เลือกโหมดที่ต้องการ', "คลิกที่การ์ดเพื่อเลือกหรือยกเลิกโหมด (เครื่องหมายถูกมุมขวาบน)`r`nการ์ดที่ติดป้าย ใช้งานอยู่ คือโหมดที่ถูกปรับไว้แล้ว`r`nใช้ช่องค้นหาด้านบนเพื่อหาโหมดได้เร็วขึ้น"),
        @('2. ปรับละเอียดรายตัว', "คลิกขวาที่การ์ดเพื่อเปิดหรือปิดแต่ละรายการในโหมดนั้น`r`nรายการที่ปิดไว้จะไม่ถูกปรับ เหมาะกับคนที่อยากเลือกเอง"),
        @('3. เปิดใช้งานโหมด', "ปุ่ม เลือกที่แนะนำ จะติ๊กโหมดที่เหมาะกับเครื่องของคุณให้`r`nจากนั้นกด เปิดใช้งานโหมดที่เลือก ที่มุมล่างขวา`r`nโปรแกรมจะบันทึกค่าเดิมและสร้างจุดคืนค่าให้ก่อนปรับทุกครั้ง"),
        @('4. คืนค่าเดิมได้ทุกเมื่อ', "กด คืนค่าเดิม บนการ์ดเพื่อย้อนเฉพาะโหมดนั้น`r`nหรือ คืนค่าทั้งหมด ที่เมนูซ้ายมือเพื่อย้อนทุกอย่าง`r`nดูรายละเอียดทั้งหมดได้ที่ บันทึกการทำงาน`r`n`r`nบางโหมดต้องรีสตาร์ท Windows จึงจะมีผลเต็มที่")
    )
    $script:tr = @{ i = 0; next = 0; dir = 1; a = 0.0; n = $steps.Count; steps = $steps }
    $d = New-Object System.Windows.Forms.Form
    $d.FormBorderStyle = 'None'; $d.StartPosition = 'CenterParent'; $d.ShowInTaskbar = $false
    $d.BackColor = (Rgb 10 15 30); $d.KeyPreview = $true; $d.Opacity = 0
    $d.ClientSize = New-Object System.Drawing.Size(520, 360)
    $script:tr.d = $d
    $script:tr.bg = $d.BackColor; $script:tr.fgC = (Rgb 125 185 255); $script:tr.fgT = (Rgb 255 255 255); $script:tr.fgB = (Rgb 218 228 244)

    $lc = New-Object System.Windows.Forms.Label
    $lc.Font = [HY.Fx]::F(9.5, $true); $lc.AutoSize = $true; $lc.Location = New-Object System.Drawing.Point(28, 24); $lc.BackColor = $d.BackColor; $lc.ForeColor = $d.BackColor
    $lt = New-Object System.Windows.Forms.Label
    $lt.Font = [HY.Fx]::F(18, $true); $lt.AutoSize = $false; $lt.Location = New-Object System.Drawing.Point(28, 50); $lt.Size = New-Object System.Drawing.Size(464, 44); $lt.BackColor = $d.BackColor; $lt.ForeColor = $d.BackColor
    $lm = New-Object System.Windows.Forms.Label
    $lm.Font = [HY.Fx]::F(11.5, $false); $lm.AutoSize = $false; $lm.Location = New-Object System.Drawing.Point(28, 106); $lm.Size = New-Object System.Drawing.Size(464, 140); $lm.BackColor = $d.BackColor; $lm.ForeColor = $d.BackColor
    $ck = New-Object System.Windows.Forms.CheckBox
    $ck.Text = 'ไม่ต้องแสดงอีก'; $ck.Font = [HY.Fx]::F(10, $false); $ck.AutoSize = $true; $ck.Location = New-Object System.Drawing.Point(28, 258)
    $ck.BackColor = $d.BackColor; $ck.ForeColor = (Rgb 178 192 216); $ck.Cursor = [System.Windows.Forms.Cursors]::Hand
    $d.Controls.Add($lc); $d.Controls.Add($lt); $d.Controls.Add($lm); $d.Controls.Add($ck)
    $script:tr.lc = $lc; $script:tr.lt = $lt; $script:tr.lm = $lm; $script:tr.ck = $ck

    $by = 360 - 24 - 40
    $bNext = New-Object HY.Bt; $bNext.Kind = 1; $bNext.BackColor = $d.BackColor; $bNext.Size = New-Object System.Drawing.Size(130, 42); $bNext.Location = New-Object System.Drawing.Point((520 - 28 - 130), $by)
    $bBack = New-Object HY.Bt; $bBack.Kind = 0; $bBack.BackColor = $d.BackColor; $bBack.Text = 'ย้อนกลับ'; $bBack.Size = New-Object System.Drawing.Size(110, 40); $bBack.Location = New-Object System.Drawing.Point((520 - 28 - 130 - 10 - 110), $by)
    $bSkip = New-Object HY.Bt; $bSkip.Kind = 0; $bSkip.BackColor = $d.BackColor; $bSkip.Text = 'ข้าม'; $bSkip.Size = New-Object System.Drawing.Size(90, 40); $bSkip.Location = New-Object System.Drawing.Point(28, $by)
    $d.Controls.Add($bNext); $d.Controls.Add($bBack); $d.Controls.Add($bSkip)
    $script:tr.bNext = $bNext; $script:tr.bBack = $bBack; $script:tr.bSkip = $bSkip

    $script:tr.Fill = {
        $t = $script:tr; $i = $t.i
        $t.lc.Text = ('ขั้นตอน {0} / {1}' -f ($i + 1), $t.n)
        $t.lt.Text = [string]$t.steps[$i][0]
        $t.lm.Text = [string]$t.steps[$i][1]
        $t.bBack.Visible = ($i -gt 0)
        $t.bNext.Text = $(if ($i -ge ($t.n - 1)) { 'เริ่มใช้งาน' } else { 'ถัดไป' })
        $t.bSkip.Visible = ($i -lt ($t.n - 1))
        $t.bNext.Invalidate(); $t.bBack.Invalidate(); $t.bSkip.Invalidate()
        $t.d.Invalidate()
    }
    $script:tr.Go = {
        param($to)
        $t = $script:tr
        if ($to -lt 0 -or $to -ge $t.n -or $to -eq $t.i) { return }
        $t.next = $to; $t.dir = -1
    }
    & $script:tr.Fill

    $bNext.Add_Click({ $t = $script:tr; if ($t.i -ge ($t.n - 1)) { $t.d.Close() } else { & $t.Go ($t.i + 1) } })
    $bBack.Add_Click({ $t = $script:tr; & $t.Go ($t.i - 1) })
    $bSkip.Add_Click({ $script:tr.d.Close() })
    $d.Add_KeyDown({
        param($s, $e)
        $t = $script:tr
        if ($e.KeyCode -eq 'Escape') { $t.d.Close() }
        elseif ($e.KeyCode -eq 'Right' -or $e.KeyCode -eq 'Return') { if ($t.i -ge ($t.n - 1)) { $t.d.Close() } else { & $t.Go ($t.i + 1) } }
        elseif ($e.KeyCode -eq 'Left') { & $t.Go ($t.i - 1) }
    })
    $d.Add_Paint({
        param($s, $e)
        $t = $script:tr
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
        $pp = New-Object System.Drawing.Pen((Rgb 37 99 235)); $g.DrawRectangle($pp, 0, 0, ($s.Width - 1), ($s.Height - 1)); $pp.Dispose()
        $x = 520 - 28
        for ($k = $t.n - 1; $k -ge 0; $k--) {
            $w = $(if ($k -eq $t.i) { 22 } else { 7 })
            $x -= $w
            $col = $(if ($k -eq $t.i) { Rgb 59 130 246 } else { Rgb 45 58 90 })
            $br = New-Object System.Drawing.SolidBrush($col)
            $path = [HX.G]::Round((New-Object System.Drawing.RectangleF($x, 28, $w, 7)), 3.5)
            $g.FillPath($br, $path); $br.Dispose(); $path.Dispose()
            $x -= 6
        }
    })
    $d.Add_Shown({
        param($s, $e)
        $rc = New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)
        $s.Region = New-Object System.Drawing.Region([HX.G]::Round($rc, 12))
        $script:tr.tm = New-Object System.Windows.Forms.Timer
        $script:tr.tm.Interval = 15
        $script:tr.tm.Add_Tick({
            $t = $script:tr
            if ($t.d.Opacity -lt 1) { $t.d.Opacity = [Math]::Min(1.0, $t.d.Opacity + 0.1) }
            if ($t.dir -lt 0) {
                $t.a -= 0.16
                if ($t.a -le 0) { $t.a = 0.0; $t.i = $t.next; & $t.Fill; $t.dir = 1 }
            } elseif ($t.a -lt 1) {
                $t.a = [Math]::Min(1.0, $t.a + 0.12)
            }
            $a = [double]$t.a
            $mix = { param($c) [System.Drawing.Color]::FromArgb([int]($t.bg.R + ($c.R - $t.bg.R) * $a), [int]($t.bg.G + ($c.G - $t.bg.G) * $a), [int]($t.bg.B + ($c.B - $t.bg.B) * $a)) }
            $t.lc.ForeColor = (& $mix $t.fgC); $t.lt.ForeColor = (& $mix $t.fgT); $t.lm.ForeColor = (& $mix $t.fgB)
        })
        $script:tr.tm.Start()
    })
    $d.Add_FormClosed({
        try { $script:tr.tm.Stop(); $script:tr.tm.Dispose() } catch {}
        if ($script:tr.ck.Checked) { try { Set-Content -Path $TourFlag -Value '1' -Encoding ASCII } catch {} }
    })
    [void]$d.ShowDialog($form)
    $d.Dispose()
}

# ---------------------------------------------------------------- apply
$XGroupOf = @{ delKeys = 'delKeys'; bcd = 'bcd'; netsh = 'net'; tcp = 'net'; cpmin = 'plan'; pwr = 'plan'; prevPlan = 'plan'; svc = 'svc'; timer = 'timer'; hib = 'hib'; nfx = 'nfx' }

function Invoke-Selected {
    $sel = @($script:Modes | Where-Object { $_.Mode.Selected })
    if ($sel.Count -eq 0) { [void](Show-Dlg $UI.NoneMsg $UI.NoneTtl @($UI.Ok)); return }
    $cnt = 0; foreach ($o in $sel) { $cnt += @(Get-ModeTweaks $o).Count }
    $a = Show-Dlg ($UI.ConfirmApply -f $sel.Count, $cnt) $UI.ApplyTtl @($UI.ApplyBtn, $UI.Cancel)
    if ($a -ne $UI.ApplyBtn) { return }
    Show-Page 'log'
    Set-Busy $true
    New-Checkpoint
    $ok = 0; $fail = 0
    foreach ($o in $sel) {
        Log ('--- ' + $o.Def.Tag + ' ---')
        foreach ($t in (Get-ModeTweaks $o)) {
            try {
                $script:CurMode = [string]$o.Def.Key
                $before = @($script:X.Keys)
                $v = $null
                if ($t.Opts) { $v = $t.Opts[[string]$script:OptSel[$t.Name]] }
                $sb = $t.Apply
                & $sb $v
                if (-not $script:X.ContainsKey('xown')) { $script:X['xown'] = @{} }
                foreach ($xk in @($script:X.Keys)) {
                    if ($xk -eq 'xown' -or $before -contains $xk) { continue }
                    $gname = $XGroupOf[$xk]
                    if ($gname -and -not $script:X['xown'].ContainsKey($gname)) { $script:X['xown'][$gname] = [string]$o.Def.Key }
                }
                Log ('OK    ' + $t.Name)
                $ok++
            } catch { Log ('FAIL  ' + $t.Name + ' : ' + $_.Exception.Message); $fail++ }
        }
    }
    $script:CurMode = $null
    Save-State
    Log ('Finished: {0} applied, {1} failed. Restart Windows to apply everything.' -f $ok, $fail)
    try { Refresh-Active } catch {}
    Set-Busy $false
    $q = Show-Dlg ($UI.DoneMsg -f $ok, $fail) $UI.DoneTtl @($UI.Restart, $UI.Later)
    if ($q -eq $UI.Restart) { shutdown.exe /r /t 5 /c "$($UI.Brand): restarting to apply tweaks" }
}

# ---------------------------------------------------------------- restore (one mode / everything)
function Restore-RegValue($k) {
    $i = $k.LastIndexOf('|'); $path = $k.Substring(0, $i); $name = $k.Substring($i + 1); $o = $script:Reg[$k]
    try {
        if ($o.existed) {
            $v = $o.value
            switch ($o.kind) {
                'DWord'       { $v = [int]$v }
                'QWord'       { $v = [long]$v }
                'Binary'      { $v = [byte[]]@($v) }
                'MultiString' { $v = [string[]]@($v) }
            }
            if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
            Set-ItemProperty -LiteralPath $path -Name $name -Value $v -Type $o.kind -Force
        } else {
            Remove-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue
        }
    } catch { Log "restore failed: $k ($($_.Exception.Message))" }
}

function Restore-XGroup($g) {
    switch ($g) {
        'delKeys' { if ($script:X.ContainsKey('delKeys')) { foreach ($k in @($script:X['delKeys'])) { Remove-Item -LiteralPath $k -Recurse -Force -ErrorAction SilentlyContinue }; $script:X.Remove('delKeys') } }
        'bcd'     { if ($script:X.ContainsKey('bcd')) { foreach ($n in @($script:X['bcd'])) { bcdedit /deletevalue $n 2>$null | Out-Null }; $script:X.Remove('bcd') } }
        'net'     {
            if ($script:X.ContainsKey('netsh')) {
                & netsh int tcp set global rsc=enabled | Out-Null
                if ($script:X.ContainsKey('tcp')) {
                    $t = $script:X['tcp']
                    try { Set-NetTCPSetting -SettingName Internet -Timestamps $t.ts -EcnCapability $t.ecn -AutoTuningLevelLocal $t.au -NonSackRttResiliency $t.nsr -ErrorAction Stop }
                    catch { Log ('TCP restore failed: ' + $_.Exception.Message) }
                }
                $script:X.Remove('netsh'); $script:X.Remove('tcp')
            }
        }
        'plan'    {
            if ($script:X.ContainsKey('cpmin')) { $c = $script:X['cpmin']; powercfg -setacvalueindex $c.guid SUB_PROCESSOR CPMINCORES ([int]$c.ac) | Out-Null; powercfg /setactive $c.guid | Out-Null; $script:X.Remove('cpmin') }
            if ($script:X.ContainsKey('pwr')) {
                $plans = @()
                foreach ($c in @($script:X['pwr'])) {
                    try { powercfg -setacvalueindex $c.guid $c.sub $c.set ([int]$c.ac) | Out-Null; if ($plans -notcontains $c.guid) { $plans += $c.guid } } catch { Log "power restore failed: $($c.k)" }
                }
                foreach ($p in $plans) { powercfg /setactive $p | Out-Null }
                $script:X.Remove('pwr')
            }
            if ($script:X.ContainsKey('prevPlan')) { if ($script:X['prevPlan']) { powercfg /setactive $script:X['prevPlan'] | Out-Null }; $script:X.Remove('prevPlan') }
        }
        'svc'     {
            if ($script:X.ContainsKey('svc')) {
                foreach ($n in @($script:X['svc'].Keys)) {
                    $mode = switch ($script:X['svc'][$n]) { 'Auto' { 'Automatic' } 'Manual' { 'Manual' } default { 'Disabled' } }
                    Set-Service -Name $n -StartupType $mode -ErrorAction SilentlyContinue
                }
                $script:X.Remove('svc')
            }
        }
        'timer'   {
            if ($script:X.ContainsKey('timer')) {
                Stop-Service 'MostKillTimer' -Force -ErrorAction SilentlyContinue
                sc.exe delete MostKillTimer | Out-Null
                Remove-Item (Join-Path $DataDir 'MostKillTimer.exe') -Force -ErrorAction SilentlyContinue
                $script:X.Remove('timer')
            }
        }
        'nfx'     { Restore-NfState }
        'hib'     { if ($script:X.ContainsKey('hib')) { if ($script:X['hib']) { powercfg /hibernate on | Out-Null }; $script:X.Remove('hib') } }
    }
}

function Restore-Mode($o) {
    $key = [string]$o.Def.Key
    Log ('===== RESTORE: ' + $o.Def.Tag + ' =====')
    $n = 0
    foreach ($k in @($script:Reg.Keys)) {
        if ($script:Reg[$k].own -eq $key) { Restore-RegValue $k; $script:Reg.Remove($k); $n++ }
    }
    if ($script:X.ContainsKey('xown')) {
        foreach ($g in @($script:X['xown'].Keys)) {
            if ($script:X['xown'][$g] -eq $key) { Restore-XGroup $g; $script:X['xown'].Remove($g); $n++ }
        }
    }
    if (($script:Reg.Count -eq 0) -and (@($script:X.Keys | Where-Object { $_ -ne 'xown' }).Count -eq 0)) {
        $script:Reg = @{}; $script:X = @{}
        Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
    } else { Save-State }
    Log ('Restored {0} item(s) for {1}.' -f $n, $o.Def.Tag)
    return $n
}

function Invoke-RestoreMode($mo) {
    $o = $script:ModeByKey[[string]$mo.Key]
    $a = Show-Dlg ($UI.ConfirmRestoreMode -f $o.Def.Title) $UI.RestoreTtl @($UI.Restore, $UI.Cancel)
    if ($a -ne $UI.Restore) { return }
    Show-Page 'log'
    Set-Busy $true
    $n = Restore-Mode $o
    try { Refresh-Active } catch {}
    Set-Busy $false
    if ($n -eq 0) { [void](Show-Dlg $UI.NothingToRestore $UI.RestoreTtl @($UI.Ok)) }
    else {
        $q = Show-Dlg $UI.RestoredMode $UI.RestoreDoneTtl @($UI.Restart, $UI.Later)
        if ($q -eq $UI.Restart) { shutdown.exe /r /t 5 /c "$($UI.Brand): restore complete" }
    }
}

function Invoke-RestoreAll {
    $a = Show-Dlg $UI.ConfirmRestoreAll $UI.RestoreTtl @($UI.Restore, $UI.Cancel)
    if ($a -ne $UI.Restore) { return }
    Show-Page 'log'
    Set-Busy $true
    Restore-All
    try { Refresh-Active } catch {}
    Set-Busy $false
    $q = Show-Dlg $UI.RestoredAll $UI.RestoreDoneTtl @($UI.Restart, $UI.Later)
    if ($q -eq $UI.Restart) { shutdown.exe /r /t 5 /c "$($UI.Brand): restore complete" }
}

# ---------------------------------------------------------------- right-click menu: fine control per tweak
function Show-ModeMenu($mo) {
    $o = $script:ModeByKey[[string]$mo.Key]
    $cm = New-Object System.Windows.Forms.ContextMenuStrip
    $cm.ShowImageMargin = $false; $cm.ShowItemToolTips = $true
    try { $cm.Renderer = New-Object HX.DarkRenderer } catch {}
    $cm.Font = [HY.Fx]::F(9, $false)
    $cm.BackColor = (Rgb 10 15 30); $cm.ForeColor = (Rgb 220 230 245)
    $hd = New-Object System.Windows.Forms.ToolStripMenuItem(($UI.MenuHead + ' ' + $o.Def.Title))
    $hd.Enabled = $false; [void]$cm.Items.Add($hd)
    [void]$cm.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    foreach ($t in $o.Tweaks) {
        $nm = [string]$t.Name
        $on = [bool]$script:TwOn[$nm]
        if ($t.Opts) {
            $item = New-Object System.Windows.Forms.ToolStripMenuItem(('{0}{1}   [{2}]' -f $(if ($on) { [string][char]0x2714 + ' ' } else { '    ' }), $nm, $script:OptSel[$nm]))
            $item.ToolTipText = [string]$t.Desc
            $en = New-Object System.Windows.Forms.ToolStripMenuItem($UI.MenuEnable)
            $en.CheckOnClick = $true; $en.Checked = $on; $en.Tag = $nm
            $en.Add_Click({ param($s, $e) $script:TwOn[[string]$s.Tag] = [bool]$s.Checked })
            [void]$item.DropDownItems.Add($en)
            [void]$item.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
            foreach ($ok in $t.Opts.Keys) {
                $oi = New-Object System.Windows.Forms.ToolStripMenuItem([string]$ok)
                $oi.Checked = ([string]$ok -eq [string]$script:OptSel[$nm]); $oi.Tag = @($nm, [string]$ok)
                $oi.Add_Click({ param($s, $e) $script:OptSel[[string]$s.Tag[0]] = [string]$s.Tag[1] })
                [void]$item.DropDownItems.Add($oi)
            }
            [void]$cm.Items.Add($item)
        } else {
            $item = New-Object System.Windows.Forms.ToolStripMenuItem($nm)
            $item.CheckOnClick = $true; $item.Checked = $on; $item.Tag = $nm
            $item.ToolTipText = [string]$t.Desc
            $item.Add_Click({ param($s, $e) $script:TwOn[[string]$s.Tag] = [bool]$s.Checked })
            [void]$cm.Items.Add($item)
        }
    }
    [void]$cm.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $rs = New-Object System.Windows.Forms.ToolStripMenuItem($UI.MenuReset)
    $rs.Tag = [string]$mo.Key
    $rs.Add_Click({ param($s, $e)
        $oo = $script:ModeByKey[[string]$s.Tag]
        foreach ($tt in $oo.Tweaks) { $script:TwOn[$tt.Name] = [bool]$script:TwDef[$tt.Name] }
        Refresh-Active
    })
    [void]$cm.Items.Add($rs)
    $cm.Show($grid, $grid.MenuPoint)
}

# ---------------------------------------------------------------- events
$grid.add_ToggleClick({ Update-Counts })
$grid.add_RestoreClick({ param($s, $e) Invoke-RestoreMode $s.Clicked })
$grid.add_MenuClick({ param($s, $e) Show-ModeMenu $s.Clicked })
$topRow.Box.add_Changed({ $grid.Filter = $topRow.Box.Value })
$bApply.Add_Click({ Invoke-Selected })
$bRec.Add_Click({
    $recKeys = @('fps','gaming','keyboard','mouse','netfade','nvidia','system')
    foreach ($o in $script:Modes) { $o.Mode.Selected = ($recKeys -contains [string]$o.Def.Key) }
    $grid.Invalidate(); Update-Counts
})
$side.add_HomeClick({ Show-Page 'home' })
$side.add_LogClick({ Show-Page 'log' })
$side.add_ResetClick({ Invoke-RestoreAll })

# ---------------------------------------------------------------- live system status (CPU / RAM / GPU)
$script:statTimer = New-Object System.Windows.Forms.Timer
$script:statTimer.Interval = 1500
$script:statTimer.Add_Tick({
    try {
        $c = [HX.Native]::CpuLoad(); if ($c -ge 0) { $side.Cpu = [float]$c }
        $m = [HX.Native]::MemInfo(); if ($m) { $side.Ram = [float]$m[2] }
        $side.Gpu = [HY.GpuLoad]::Value
        $side.Invalidate()
    } catch {}
})

# ---------------------------------------------------------------- startup
try { (Get-Process -Id $PID).PriorityClass = 'High' } catch {}

$form.Add_Shown({
    try {
        $rc = New-Object System.Drawing.RectangleF(0, 0, $form.Width, $form.Height)
        $form.Region = New-Object System.Drawing.Region([HX.G]::Round($rc, 10))
        [HX.Native]::Dark($script:logBox.Handle)
        $form.WindowState = 'Normal'
        $form.TopMost = $true; $form.Activate(); $form.BringToFront(); $form.TopMost = $false
        [HX.Native]::Foreground($form.Handle)
        if ($MKElevated) { [HX.Native]::HideConsole() }
        [HY.GpuLoad]::Start()
        [void][HX.Native]::CpuLoad()
        $script:statTimer.Start()
        $grid.Relayout(); $grid.PlayIntro()
        $script:fadeTimer = New-Object System.Windows.Forms.Timer
        $script:fadeTimer.Interval = 15
        $script:fadeTimer.Add_Tick({
            $o = $form.Opacity + 0.09
            if ($o -ge 1) { $form.Opacity = 1; $script:fadeTimer.Stop() } else { $form.Opacity = $o }
        })
        $script:fadeTimer.Start()
        if (-not (Test-Path -LiteralPath $TourFlag)) {
            $script:tourTimer = New-Object System.Windows.Forms.Timer
            $script:tourTimer.Interval = 900
            $script:tourTimer.Add_Tick({
                $script:tourTimer.Stop()
                try { Show-Tour } catch { Log ('Tour error: ' + $_.Exception.Message) }
            })
            $script:tourTimer.Start()
        }
    } catch {
        Write-Host ($UI.Brand + ' startup error: ' + $_.Exception.Message) -ForegroundColor Red
    }
})
$form.Add_FormClosed({
    try { $script:statTimer.Stop(); [HY.GpuLoad]::Stop() } catch {}
})

# ---- realtime license heartbeat: re-checks the key while the app is open; revoke / expiry closes the app
if ($UseServer -and $script:LicKey) {
    $script:hbTimer = New-Object System.Windows.Forms.Timer
    $script:hbTimer.Interval = [Math]::Max(1, $HeartbeatMinutes) * 60000
    $script:hbTimer.Add_Tick({
        $r = Invoke-LicenseCheck $script:LicKey
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ($r.ok) { $script:LicLastOk = $now; return }
        if ($r.err -eq 'network' -or $r.err -eq 'rate_limited') {
            if (($now - $script:LicLastOk) -le ($GraceHours * 3600)) { return }
            $why = ('The license server could not be reached for more than {0} hours.' -f $GraceHours)
        } else {
            $why = ('Your license is no longer valid: ' + (Get-LicErrorText $r.err).ToLower() + '.')
            try { Remove-Item -LiteralPath $LicenseFile -Force -ErrorAction SilentlyContinue } catch {}
        }
        $script:hbTimer.Stop(); Log ('License check failed: ' + $r.err)
        [void](Show-Dlg ($why + "`r`n`r`nThe app will close now. Applied tweaks stay in place; restore can be run again after re-activation.") 'License' @('CLOSE'))
        $form.Close()
    })
    $script:hbTimer.Start()
}

Update-Counts
Update-Status
Refresh-Active
Show-Page 'home'
Log ('License: ' + $(if ($UseServer) { 'online (checked every ' + $HeartbeatMinutes + ' min)' } else { 'offline key list' }))
Log ('{0} v{1} ready. Restore data: C:\ProgramData\MostKill' -f $UI.Brand, $MKVersion)
Log ('PC: {0} | {1} GB RAM | {2} | {3}' -f $CpuName, $RamGB, $GpuName, $OsName)
Log ('Detected: {0} | system drive {1}. Defaults adapted to this PC.' -f $(if ($IsLaptop) { 'LAPTOP' } else { 'DESKTOP' }), $(if ($IsSSD) { 'SSD/NVMe' } else { 'HDD' }))
Log ('FiveM builds found: ' + ((Get-FiveMExes | Where-Object { $_ -like '*GTAProcess*' }) -join ', '))
Log 'Cards tagged ACTIVE are already applied on this PC. Right-click a card to pick individual tweaks.'
if ($script:Reg.Count -gt 0) { Log ('Existing restore data found: {0} registry values tracked.' -f $script:Reg.Count) }
$form.KeyPreview = $true
$form.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'F1') { try { Show-Tour } catch { Log ('Tour error: ' + $_.Exception.Message) } } })
[void]$form.ShowDialog()
