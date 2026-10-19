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
        $o = @{ existed = $false; value = $null; kind = $null }
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

@{ G='Input'; Name='Mouse accel off + fast keyboard repeat'; Rec=$true
   Desc='MouseSpeed/Threshold1/Threshold2 = 0, KeyboardDelay 0, KeyboardSpeed 31 (current user, log off to apply).'
   Check={ (Test-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0') -and (Test-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardSpeed' '31') }
   Apply={
       $m = 'HKCU:\Control Panel\Mouse'
       Set-Reg $m 'MouseSpeed' '0' 'String'
       Set-Reg $m 'MouseThreshold1' '0' 'String'
       Set-Reg $m 'MouseThreshold2' '0' 'String'
       $k = 'HKCU:\Control Panel\Keyboard'
       Set-Reg $k 'KeyboardDelay' '0' 'String'
       Set-Reg $k 'KeyboardSpeed' '31' 'String'
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

# ---------------------------------------------------------------- GUI (dashboard style: monochrome, rounded cards, live system overview)
if (-not ('HX.Nav' -as [type])) {
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
    public static Color Bg    = Color.FromArgb(11, 11, 11);
    public static Color Side  = Color.FromArgb(13, 13, 13);
    public static Color Card  = Color.FromArgb(21, 21, 21);
    public static Color Card2 = Color.FromArgb(30, 30, 30);
    public static Color Line  = Color.FromArgb(40, 40, 40);
    public static Color Line2 = Color.FromArgb(66, 66, 66);
    public static Color Txt   = Color.FromArgb(240, 240, 240);
    public static Color Soft  = Color.FromArgb(200, 200, 200);
    public static Color Mut   = Color.FromArgb(130, 130, 130);
    public static Color Dim   = Color.FromArgb(96, 96, 96);
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
      g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
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
      G.Text(g, sub, Fnt.S(8.5f), Color.FromArgb(112, 112, 112), new RectangleF(27f, 54f, Math.Max(10, w - 54), 18f), StringAlignment.Near, StringAlignment.Near, false);
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
        if (Selected) G.Box(g, r, 12, Color.FromArgb(29, 29, 29), Color.FromArgb(64, 64, 64));
        else if (hover) G.Box(g, r, 12, Color.FromArgb(20, 20, 20), Color.Empty);
        float ts = 32f;
        RectangleF t = new RectangleF(8f, (Height - ts) / 2f, ts, ts);
        G.Box(g, t, 9, Selected ? Color.FromArgb(40, 40, 40) : Color.FromArgb(24, 24, 24), Color.FromArgb(Selected ? 78 : 50, Selected ? 78 : 50, Selected ? 78 : 50));
        Ico.Draw(g, Icon, t.X + ts / 2f, t.Y + ts / 2f, 16f, Ico.Tint(Icon));
        float tx = 52f;
        float bw = 0f;
        if (!string.IsNullOrEmpty(Badge)) {
          Font bf = Fnt.H(7.5f);
          bw = g.MeasureString(Badge, bf, 1000, G.TF).Width + 14f;
          RectangleF br = new RectangleF(Width - 12f - bw, (Height - 18f) / 2f, bw, 18f);
          G.Box(g, br, 9, Color.FromArgb(31, 31, 31), Color.FromArgb(56, 56, 56));
          G.Text(g, Badge, bf, Pal.Mut, br, StringAlignment.Center, StringAlignment.Center, false);
        }
        G.Text(g, Text, Fnt.H(10f), Selected ? Pal.Txt : Color.FromArgb(214, 214, 214), new RectangleF(tx, 0, Width - tx - bw - 16f, Height), StringAlignment.Near, StringAlignment.Center, false);
      } else {
        Color f = hover ? Color.FromArgb(26, 26, 26) : Color.FromArgb(18, 18, 18);
        if (down) f = Color.FromArgb(32, 32, 32);
        G.Box(g, r, 11, f, Selected ? Color.FromArgb(96, 96, 96) : Color.FromArgb(48, 48, 48));
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
        fill = down ? Color.FromArgb(205, 205, 205) : (hover ? Color.FromArgb(255, 255, 255) : Color.FromArgb(238, 238, 238));
        line = Color.Empty; txt = Color.FromArgb(12, 12, 12);
      } else if (Kind == 2) {
        fill = down ? Color.FromArgb(70, 24, 24) : (hover ? Color.FromArgb(52, 22, 22) : Color.FromArgb(26, 18, 18));
        line = Color.FromArgb(96, 44, 44); txt = Color.FromArgb(244, 128, 128);
      } else {
        fill = down ? Color.FromArgb(40, 40, 40) : (hover ? Color.FromArgb(32, 32, 32) : Color.FromArgb(24, 24, 24));
        line = hover ? Color.FromArgb(78, 78, 78) : Color.FromArgb(54, 54, 54); txt = Pal.Txt;
      }
      if (!Enabled) { fill = Color.FromArgb(20, 20, 20); txt = Pal.Dim; }
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
      Color on = Color.FromArgb(236, 236, 236), off = Color.FromArgb(44, 44, 44);
      G.Box(g, tr, tr.Height / 2f, G.Mix(off, on, pos), G.Mix(Color.FromArgb(70, 70, 70), on, pos));
      float d = tr.Height - 8f;
      float x = tr.X + 4f + pos * (tr.Width - 8f - d);
      using (SolidBrush b = new SolidBrush(G.Mix(Color.FromArgb(150, 150, 150), Color.FromArgb(14, 14, 14), pos)))
        g.FillEllipse(b, x, tr.Y + 4f, d, d);
    }
  }

  // ---------------------------------------------------------------- dark drop-down
  public class DarkTable : ProfessionalColorTable {
    public override Color ToolStripDropDownBackground { get { return Color.FromArgb(22, 22, 22); } }
    public override Color ImageMarginGradientBegin { get { return Color.FromArgb(22, 22, 22); } }
    public override Color ImageMarginGradientMiddle { get { return Color.FromArgb(22, 22, 22); } }
    public override Color ImageMarginGradientEnd { get { return Color.FromArgb(22, 22, 22); } }
    public override Color MenuBorder { get { return Color.FromArgb(64, 64, 64); } }
    public override Color MenuItemBorder { get { return Color.FromArgb(70, 70, 70); } }
    public override Color MenuItemSelected { get { return Color.FromArgb(44, 44, 44); } }
    public override Color MenuItemSelectedGradientBegin { get { return Color.FromArgb(44, 44, 44); } }
    public override Color MenuItemSelectedGradientEnd { get { return Color.FromArgb(44, 44, 44); } }
    public override Color CheckBackground { get { return Color.FromArgb(44, 44, 44); } }
    public override Color CheckSelectedBackground { get { return Color.FromArgb(52, 52, 52); } }
    public override Color CheckPressedBackground { get { return Color.FromArgb(52, 52, 52); } }
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
      m.BackColor = Color.FromArgb(22, 22, 22); m.ForeColor = Color.FromArgb(236, 236, 236); m.Font = Fnt.S(9f);
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
      G.Box(g, r, 9, hover ? Color.FromArgb(38, 38, 38) : Color.FromArgb(31, 31, 31), hover ? Color.FromArgb(84, 84, 84) : Color.FromArgb(58, 58, 58));
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
      Color c = Selected ? Color.FromArgb(26, 26, 26) : Pal.Card;
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
      G.Box(g, r, 14, Fill(), Selected ? Color.FromArgb(84, 84, 84) : Pal.Line);
      RectangleF t = new RectangleF(18f, (Height - 42f) / 2f, 42f, 42f);
      G.Box(g, t, 11, Color.FromArgb(31, 31, 31), Color.FromArgb(50, 50, 50));
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
      G.Text(g, Desc, Fnt.S(8.5f), Color.FromArgb(124, 124, 124), new RectangleF(x, 39f, avail, 34f), StringAlignment.Near, StringAlignment.Near, true);
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
      if (!t.IsEmpty) G.Box(g, t, 2.5f, (drag || hov) ? Color.FromArgb(120, 120, 120) : Color.FromArgb(62, 62, 62), Color.Empty);
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
      using (Pen p = new Pen(Color.FromArgb(34, 34, 34), 1f)) g.DrawLine(p, 0, 0, Width, 0);
    }
  }

  // ---------------------------------------------------------------- title bar (brand / status pill / user chip / window buttons)
  public class TopBar : Ctl {
    public string Brand = "HEE", Ver = "", Status = "SYSTEM READY", User = "USER", Role = "Administrator";
    public Color StatusColor = Color.FromArgb(120, 120, 120);
    public Image Logo; public bool Maxed; public int SideW = 216;
    public event EventHandler MinClick, MaxClick, CloseClick;
    Rectangle[] bt = new Rectangle[3]; int hot = -1;
    public TopBar() { Height = 41; BackColor = Color.FromArgb(12, 12, 12); }
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
      using (Pen p = new Pen(Color.FromArgb(36, 36, 36), 1f)) {
        g.DrawLine(p, 0, Height - 1, Width, Height - 1);
        g.DrawLine(p, SideW, 0, SideW, Height - 1);
      }
      // brand
      if (Logo != null) {
        try { g.DrawImage(Logo, new Rectangle(14, 5, 30, 30)); } catch (Exception) { }
      } else {
        G.Box(g, new RectangleF(14, 5, 30, 30), 8, Color.FromArgb(30, 30, 30), Color.FromArgb(56, 56, 56));
      }
      G.Track(g, Brand, Fnt.H(11f), Pal.Txt, 54f, 6f, 1.8f);
      G.Text(g, Ver, Fnt.S(7f), Pal.Dim, new RectangleF(54f, 23f, SideW - 60f, 12f), StringAlignment.Near, StringAlignment.Near, false);
      // status pill
      Font pf = Fnt.H(7.2f);
      float pw = G.TrackW(g, Status, pf, 1.4f) + 38f;
      RectangleF pr = new RectangleF(SideW + 19f, 8f, pw, 25f);
      G.Box(g, pr, 9, Color.FromArgb(20, 20, 20), Color.FromArgb(46, 46, 46));
      using (SolidBrush b = new SolidBrush(StatusColor)) g.FillEllipse(b, pr.X + 12f, pr.Y + 10f, 5f, 5f);
      G.Track(g, Status, pf, Color.FromArgb(150, 150, 150), pr.X + 24f, pr.Y + 7.5f, 1.4f);
      // user chip
      float right = bt[0].X - 18f;
      Font nf = Fnt.H(8.2f), rf = Fnt.S(7f);
      float nw = Math.Max(g.MeasureString(User, nf, 1000, G.TF).Width, g.MeasureString(Role, rf, 1000, G.TF).Width);
      float tx = right - nw;
      G.Text(g, User, nf, Pal.Txt, new RectangleF(tx, 7f, nw + 6f, 15f), StringAlignment.Near, StringAlignment.Near, false);
      G.Text(g, Role, rf, Pal.Dim, new RectangleF(tx, 22f, nw + 6f, 12f), StringAlignment.Near, StringAlignment.Near, false);
      RectangleF av = new RectangleF(tx - 40f, 6f, 28f, 28f);
      G.Box(g, av, 14, Color.FromArgb(28, 28, 28), Color.FromArgb(52, 52, 52));
      Ico.Draw(g, 16, av.X + 14f, av.Y + 14f, 15f, Pal.Soft);
      using (SolidBrush b = new SolidBrush(Pal.Side)) g.FillEllipse(b, av.Right - 8f, av.Bottom - 8f, 9f, 9f);
      using (SolidBrush b = new SolidBrush(Pal.Ok)) g.FillEllipse(b, av.Right - 6.5f, av.Bottom - 6.5f, 6f, 6f);
      // window buttons
      for (int i = 0; i < 3; i++) {
        if (hot == i) using (SolidBrush b = new SolidBrush(i == 2 ? Color.FromArgb(196, 43, 58) : Color.FromArgb(34, 34, 34))) g.FillRectangle(b, bt[i]);
        float cx = bt[i].X + bt[i].Width / 2f, cy = bt[i].Y + bt[i].Height / 2f;
        using (Pen p = new Pen(hot == i ? Color.White : Color.FromArgb(170, 170, 170), 1.2f)) {
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
      G.Box(g, r, 10, down ? Color.FromArgb(34, 34, 34) : (hover ? Color.FromArgb(28, 28, 28) : Color.FromArgb(18, 18, 18)), hover ? Color.FromArgb(80, 80, 80) : Color.FromArgb(44, 44, 44));
      Ico.Draw(g, Icon, Width / 2f, Height / 2f, 15f, hover ? Pal.Txt : Pal.Mut);
    }
  }

  public class Login : Ctl {
    public Image Logo; public string Brand = "HEE", Sub = "", Footer = "", Msg = ""; public Color MsgColor = Pal.Bad; public bool KeyFocus;
    public Rectangle BoxRect = new Rectangle(30, 182, 294, 44);
    public event EventHandler CloseClick;
    Rectangle cl = new Rectangle(322, 8, 24, 24); bool hotClose;
    public Login() { BackColor = Pal.Bg; }
    protected override void OnMouseMove(MouseEventArgs e) {
      bool h = cl.Contains(e.Location);
      if (h != hotClose) { hotClose = h; Cursor = h ? Cursors.Hand : Cursors.Default; Invalidate(); }
      base.OnMouseMove(e);
    }
    protected override void OnMouseDown(MouseEventArgs e) {
      base.OnMouseDown(e);
      if (e.Button != MouseButtons.Left) return;
      if (cl.Contains(e.Location)) { if (CloseClick != null) CloseClick(this, EventArgs.Empty); return; }
      Form f = FindForm(); if (f != null) Native.Drag(f.Handle);
    }
    protected override void OnPaint(PaintEventArgs e) {
      Graphics g = e.Graphics; G.Smooth(g);
      using (LinearGradientBrush lb = new LinearGradientBrush(new Rectangle(0, 0, Width, Height), Color.FromArgb(24, 24, 24), Color.FromArgb(9, 9, 9), 90f)) g.FillRectangle(lb, 0, 0, Width, Height);
      float cx = Width / 2f, cy = 66f;
      using (GraphicsPath gp = new GraphicsPath()) {
        gp.AddEllipse(cx - 92f, cy - 92f, 184f, 184f);
        using (PathGradientBrush pg = new PathGradientBrush(gp)) {
          pg.CenterColor = Color.FromArgb(34, 255, 255, 255); pg.SurroundColors = new Color[] { Color.FromArgb(0, 255, 255, 255) };
          g.FillPath(pg, gp);
        }
      }
      using (Pen p = new Pen(Color.FromArgb(46, 46, 46), 1f)) g.DrawEllipse(p, cx - 48f, cy - 48f, 96f, 96f);
      using (SolidBrush b = new SolidBrush(Color.FromArgb(6, 6, 6))) g.FillEllipse(b, cx - 42f, cy - 42f, 84f, 84f);
      using (Pen p = new Pen(Color.FromArgb(78, 78, 78), 1.5f)) g.DrawEllipse(p, cx - 42f, cy - 42f, 84f, 84f);
      if (Logo != null) { try { g.DrawImage(Logo, new RectangleF(cx - 36f, cy - 36f, 72f, 72f)); } catch (Exception) { } }
      using (SolidBrush b = new SolidBrush(Color.FromArgb(230, 255, 255, 255))) g.FillEllipse(b, cx + 40f, cy - 14f, 5f, 5f);
      Font tf = Fnt.H(17f); float tw = G.TrackW(g, Brand, tf, 34f);
      G.Track(g, Brand, tf, Pal.Txt, cx - tw / 2f, 122f, 34f);
      Font sf = Fnt.S(7.8f); float sw = G.TrackW(g, Sub, sf, 8f) + 14f;
      float sx = cx - sw / 2f;
      using (Pen p = new Pen(Pal.Dim, 1f)) g.DrawEllipse(p, sx, 159f, 6f, 6f);
      G.Track(g, Sub, sf, Pal.Dim, sx + 14f, 155f, 8f);
      G.Box(g, new RectangleF(BoxRect.X + 0.5f, BoxRect.Y + 0.5f, BoxRect.Width - 1, BoxRect.Height - 1), 12, Color.FromArgb(8, 8, 8), KeyFocus ? Color.FromArgb(120, 120, 120) : Color.FromArgb(46, 46, 46));
      Ico.Draw(g, 19, BoxRect.Right - 22f, BoxRect.Y + BoxRect.Height / 2f, 14f, Pal.Dim);
      G.Text(g, Msg, Fnt.S(8f), MsgColor, new RectangleF(30f, 230f, Width - 60f, 18f), StringAlignment.Center, StringAlignment.Center, false);
      float dy = 330f;
      using (Pen p = new Pen(Color.FromArgb(28, 255, 255, 255), 1f)) { g.DrawLine(p, 30f, dy, cx - 40f, dy); g.DrawLine(p, cx + 40f, dy, Width - 30f, dy); }
      G.Text(g, Footer, Fnt.S(7.8f), Pal.Dim, new RectangleF(cx - 40f, dy - 8f, 80f, 16f), StringAlignment.Center, StringAlignment.Center, false);
      G.Track(g, "CONTACT", Fnt.H(7.8f), Pal.Dim, 30f, 346f, 6f);
      using (Pen p = new Pen(hotClose ? Pal.Txt : Pal.Dim, 1.3f)) {
        g.DrawLine(p, cl.X + 8, cl.Y + 8, cl.Right - 8, cl.Bottom - 8); g.DrawLine(p, cl.Right - 8, cl.Y + 8, cl.X + 8, cl.Bottom - 8);
      }
      using (Pen p = new Pen(Color.FromArgb(56, 56, 56), 1f)) g.DrawRectangle(p, 0, 0, Width - 1, Height - 1);
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
      else using (LinearGradientBrush lb = new LinearGradientBrush(new Rectangle(0, 0, Width, Height), Color.FromArgb(15, 15, 15), Color.FromArgb(9, 9, 9), 90f)) g.FillRectangle(lb, 0, 0, Width, Height);
      G.DrawHead(g, Width, "DASHBOARD", "Realtime system overview");
      float top = 104f, bot = Height - 24f, gap = 15f, x0 = 27f, x1 = Width - 23f;
      float cw = (x1 - x0 - gap) / 2f;
      RectangleF L = new RectangleF(x0, top, cw, bot - top), R = new RectangleF(x0 + cw + gap, top, cw, bot - top);
      Color fill = Color.FromArgb(Backdrop != null ? 232 : 255, 20, 20, 20), ln = Color.FromArgb(48, 48, 48);
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
      using (Pen p = new Pen(Color.FromArgb(36, 36, 36), 5f)) g.DrawEllipse(p, ri);
      if (CpuPct >= 0f && shown > 0.3f)
        using (Pen p = new Pen(Color.FromArgb(240, 240, 240), 5f)) { p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; g.DrawArc(p, ri, -90f, 360f * Math.Min(100f, shown) / 100f); }
      string pc = (CpuPct >= 0f) ? ((int)Math.Round(shown)).ToString(CultureInfo.InvariantCulture) + "%" : "-";
      G.Text(g, pc, Fnt.H(16f), Pal.Txt, new RectangleF(rr.X, rr.Y + rr.Height / 2f - 22f, rr.Width, 28f), StringAlignment.Center, StringAlignment.Center, false);
      Font uf = Fnt.H(6.6f); float uw = G.TrackW(g, "USAGE", uf, 1.6f);
      G.Track(g, "USAGE", uf, Pal.Dim, rr.X + (rr.Width - uw) / 2f, rr.Y + rr.Height / 2f + 9f, 1.6f);
      // layout from the bottom
      float t2 = L.Bottom - 16f - 42f, t1 = t2 - 48f, sep = t1 - 14f;
      float ly = rr.Bottom + 22f;
      G.Track(g, "CPU USAGE REALTIME", Fnt.H(6.8f), Color.FromArgb(84, 84, 84), px, ly, 1.5f);
      string cur = (CpuPct >= 0f) ? ((int)Math.Round(CpuPct)).ToString(CultureInfo.InvariantCulture) + "%" : "-";
      G.Text(g, cur, Fnt.H(7.2f), Color.FromArgb(84, 84, 84), new RectangleF(px, ly - 2f, pr - px, 14f), StringAlignment.Far, StringAlignment.Near, false);
      RectangleF cr = new RectangleF(px, ly + 22f, pr - px, sep - 10f - (ly + 22f));
      if (cr.Height > 24f) DrawChart(g, cr);
      using (Pen p = new Pen(Color.FromArgb(36, 255, 255, 255), 1f)) g.DrawLine(p, px, sep, pr, sep);
      string[][] tiles = new string[][] { new string[] { "CORES", Cores }, new string[] { "CLOCK", Clock }, new string[] { "ARCH", Arch }, new string[] { "OS", Os } };
      float tww = (pr - px - 6f) / 2f;
      for (int i = 0; i < 4; i++) {
        RectangleF tr = new RectangleF(px + (i % 2) * (tww + 6f), (i < 2) ? t1 : t2, tww, 42f);
        G.Box(g, tr, 9, Color.FromArgb(23, 23, 23), Color.FromArgb(42, 42, 42));
        G.Track(g, tiles[i][0], Fnt.H(6.4f), Color.FromArgb(88, 88, 88), tr.X + 11f, tr.Y + 8f, 1.4f);
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
        G.Box(g, t, 10, Color.FromArgb(28, 28, 28), Color.FromArgb(48, 48, 48));
        Ico.Draw(g, it.Icon, t.X + 18f, t.Y + 18f, 16f, Color.FromArgb(206, 206, 206));
        float tx = px + 36f + 14f;
        float rightW = (it.Pct >= 0f) ? 84f : (it.Right.Length > 0 ? 62f : 0f);
        float avail = Math.Max(20f, pr - tx - rightW - 8f);
        float by = ry + (rowH - 40f) / 2f;
        G.Track(g, it.Label, Fnt.H(6.6f), Color.FromArgb(96, 96, 96), tx, by, 1.5f);
        G.Text(g, it.Value, Fnt.H(10.5f), Pal.Txt, new RectangleF(tx, by + 11f, avail, 18f), StringAlignment.Near, StringAlignment.Near, false);
        G.Text(g, it.Sub, Fnt.S(7.3f), Color.FromArgb(84, 84, 84), new RectangleF(tx, by + 30f, avail, 12f), StringAlignment.Near, StringAlignment.Near, false);
        if (it.Pct >= 0f) {
          string pt = ((int)Math.Round(it.Pct)).ToString(CultureInfo.InvariantCulture) + "%";
          G.Text(g, pt, Fnt.H(8.4f), Color.FromArgb(224, 224, 224), new RectangleF(pr - 84f, ry + rowH / 2f - 17f, 84f, 14f), StringAlignment.Far, StringAlignment.Near, false);
          RectangleF bar = new RectangleF(pr - 72f, ry + rowH / 2f + 3f, 72f, 3f);
          G.Box(g, bar, 1.5f, Color.FromArgb(44, 44, 44), Color.Empty);
          if (it.Pct > 0.5f) G.Box(g, new RectangleF(bar.X, bar.Y, Math.Max(3f, bar.Width * Math.Min(100f, it.Pct) / 100f), bar.Height), 1.5f, Color.FromArgb(236, 236, 236), Color.Empty);
        } else if (it.Right.Length > 0) {
          G.TrackR(g, it.Right.ToUpper(), Fnt.H(6.6f), Color.FromArgb(112, 112, 112), pr, ry + rowH / 2f - 5f, 1.3f);
        }
      }
    }
  }
}
'@
}

function Rgb($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
$cBg   = Rgb 11 11 11
$cSide = Rgb 13 13 13
$cCard = Rgb 21 21 21
$cOk   = Rgb 74 222 128
$cWarn = Rgb 250 190 60
$cGray = Rgb 140 140 140

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

# ---------------------------------------------------------------- license key screen
# $LicenseHashes = SHA-256 of each valid key (key is trimmed + upper-cased first). Default key: HEE-2026-PRO  <- replace it.
# Make a hash:  [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes('YOUR-KEY'.ToUpper()))).Replace('-','').ToLower()
$RequireKey    = $true
$RememberKey   = $false   # $false = ask for the key on every launch, $true = remember it after the first success
$LicenseHashes = @('1ef6440a8104e6630254612d77afe827a6d473f1345e6823aec6bbeed98c62a7')
$ContactDiscord = ''      # e.g. https://discord.gg/xxxx
$ContactWeb     = ''      # e.g. https://yoursite.com
$ContactInstagram = ''    # e.g. https://instagram.com/yourname
$LicenseFile = Join-Path $DataDir 'license.dat'

function Get-KeyHash([string]$k) {
    $b = [System.Text.Encoding]::UTF8.GetBytes($k.Trim().ToUpperInvariant())
    $h = [System.Security.Cryptography.SHA256]::Create().ComputeHash($b)
    return (($h | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Invoke-Activate {
    $k = $script:lgBox.Text.Trim()
    if (-not $k) { $script:lgPanel.MsgColor = (Rgb 140 140 140); $script:lgPanel.Msg = 'ENTER YOUR KEY'; $script:lgPanel.Invalidate(); return }
    $h = Get-KeyHash $k
    if ($LicenseHashes -contains $h) {
        if ($RememberKey) { try { Set-Content -Path $LicenseFile -Value $h -Encoding ASCII } catch {} }
        else { try { Remove-Item -LiteralPath $LicenseFile -Force -ErrorAction SilentlyContinue } catch {} }
        $script:lgForm.Tag = 'ok'; $script:lgForm.Close()
    } else {
        $script:lgPanel.MsgColor = (Rgb 239 68 68); $script:lgPanel.Msg = 'INVALID KEY'; $script:lgPanel.Invalidate()
        $script:lgBox.SelectAll(); $script:lgBox.Focus()
    }
}

function Open-Link($url) {
    if ($url) { try { Start-Process $url } catch {} }
    else { $script:lgPanel.MsgColor = (Rgb 140 140 140); $script:lgPanel.Msg = 'LINK NOT SET'; $script:lgPanel.Invalidate() }
}

function Show-Login {
    $f = New-Object HX.HForm
    $f.FormBorderStyle = 'None'; $f.ClientSize = New-Object System.Drawing.Size(354, 380); $f.StartPosition = 'CenterScreen'
    $f.BackColor = (Rgb 11 11 11); $f.Text = 'Hee'; $f.KeyPreview = $true; $f.Tag = ''
    if ($script:LogoImg) { try { $f.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]$script:LogoImg).GetHicon()) } catch {} }
    $p = New-Object HX.Login
    $p.Dock = 'Fill'; $p.Logo = $script:LogoImg; $p.Brand = 'HEE'
    $p.Sub = ('REALTIME OPTIMIZER V' + ($MKVersion -replace '\s.*$', '')); $p.Footer = 'HEE 2026'
    $f.Controls.Add($p)
    $script:lgForm = $f; $script:lgPanel = $p

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.BorderStyle = 'None'; $tb.BackColor = (Rgb 8 8 8); $tb.ForeColor = (Rgb 240 240 240)
    $tb.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5); $tb.MaxLength = 64
    $tb.Location = New-Object System.Drawing.Point(46, 194); $tb.Size = New-Object System.Drawing.Size(232, 22)
    $p.Controls.Add($tb); $script:lgBox = $tb
    $tb.Add_GotFocus({ $script:lgPanel.KeyFocus = $true; $script:lgPanel.Invalidate() })
    $tb.Add_LostFocus({ $script:lgPanel.KeyFocus = $false; $script:lgPanel.Invalidate() })
    $tb.Add_TextChanged({ if ($script:lgPanel.Msg) { $script:lgPanel.Msg = ''; $script:lgPanel.Invalidate() } })
    $tb.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Return') { $e.SuppressKeyPress = $true; Invoke-Activate } })

    $b = New-Object HX.Btn
    $b.Kind = 1; $b.Text = 'ACTIVATE & ENTER'; $b.Size = New-Object System.Drawing.Size(294, 44); $b.Location = New-Object System.Drawing.Point(30, 258)
    $b.BackColor = (Rgb 17 17 17)
    $p.Controls.Add($b)
    $b.Add_Click({ Invoke-Activate })

    $x = 324
    foreach ($c in @(@(18, 'ig'), @(2, 'web'), @(17, 'dc'))) {
        $ib = New-Object HX.IconBtn
        $ib.Icon = [int]$c[0]; $ib.Tag = $c[1]; $ib.BackColor = (Rgb 12 12 12)
        $x -= 34; $ib.Location = New-Object System.Drawing.Point($x, 336); $x -= 8
        $ib.Add_Click({ param($s, $e)
            if ($s.Tag -eq 'dc') { Open-Link $ContactDiscord } elseif ($s.Tag -eq 'web') { Open-Link $ContactWeb } else { Open-Link $ContactInstagram } })
        $p.Controls.Add($ib)
    }
    $p.add_CloseClick({ $script:lgForm.Close() })
    $f.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape') { $s.Close() } })
    $f.Add_Shown({
        param($s, $e)
        $rc = New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)
        $s.Region = New-Object System.Drawing.Region([HX.G]::Round($rc, 14))
        $s.Activate(); $script:lgBox.Focus()
    })
    [void]$f.ShowDialog()
    $ok = ([string]$f.Tag -eq 'ok')
    $f.Dispose()
    return $ok
}

$LicenseOk = (-not $RequireKey)
if (-not $LicenseOk -and $RememberKey -and (Test-Path -LiteralPath $LicenseFile)) {
    try { if ($LicenseHashes -contains ((Get-Content -LiteralPath $LicenseFile -Raw).Trim())) { $LicenseOk = $true } } catch {}
}
if (-not $LicenseOk) { $LicenseOk = Show-Login }
if (-not $LicenseOk) { exit }
Log 'License accepted.'

# ---- hardware facts for the dashboard
$HwCpu = $null; $HwBoard = $null; $HwOs = $null
try { $HwCpu   = Get-CimInstance Win32_Processor | Select-Object -First 1 } catch {}
try { $HwBoard = Get-CimInstance Win32_BaseBoard | Select-Object -First 1 } catch {}
try { $HwOs    = Get-CimInstance Win32_OperatingSystem } catch {}
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$thr = 0; $ghz = '-'
if ($HwCpu) {
    $thr = [int]$HwCpu.NumberOfLogicalProcessors
    $ghz = ([math]::Round($HwCpu.MaxClockSpeed / 1000, 2)).ToString($inv) + ' GHz'
}
$osShort = ($OsName -replace '^Microsoft\s+', '')
$osBuild = ''; if ($HwOs) { $osBuild = [string]$HwOs.BuildNumber }
$boardTxt = 'Unknown'; if ($HwBoard -and $HwBoard.Product) { $boardTxt = (('{0} {1}' -f $HwBoard.Manufacturer, $HwBoard.Product) -replace '\s+', ' ').Trim() }
$gpuList = @($GpuName -split ' \+ ')
$netName = 'No connection'; $netDesc = 'No active adapter'; $netState = 'Offline'
try {
    $na = Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    if ($na) { $netName = [string]$na.Name; $netDesc = [string]$na.InterfaceDescription; $netState = 'Online' }
} catch {}

function New-Hw($icon, $label, $value, $sub, $right, $live) {
    $i = New-Object HX.HwItem
    $i.Icon = [int]$icon; $i.Label = [string]$label; $i.Value = [string]$value; $i.Sub = [string]$sub; $i.Right = [string]$right; $i.Live = [int]$live
    return $i
}

# ---- window skeleton: [top bar] / [sidebar | pages]
$form = New-Object HX.HForm
$form.FormBorderStyle = 'None'
$form.ClientSize = New-Object System.Drawing.Size(1100, 680)
$form.MinimumSize = New-Object System.Drawing.Size(980, 620)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $cBg; $form.ForeColor = (Rgb 240 240 240)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$form.Text = 'Hee ' + $MKVersion

$content = New-Object System.Windows.Forms.Panel
$content.Dock = 'Fill'; $content.BackColor = $cBg
$side = New-Object System.Windows.Forms.Panel
$side.Dock = 'Left'; $side.Width = 216; $side.BackColor = $cSide
$top = New-Object HX.TopBar
$top.Dock = 'Top'; $top.Height = 41
$form.Controls.Add($content); $form.Controls.Add($side); $form.Controls.Add($top)

$top.Brand = 'HEE'; $top.Ver = ('v' + $MKVersion); $top.User = $env:COMPUTERNAME; $top.Role = 'Administrator'

if ($script:LogoImg) {
    $top.Logo = $script:LogoImg
    try { $form.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]$script:LogoImg).GetHicon()) } catch {}
}

$top.add_CloseClick({ $form.Close() })
$top.add_MinClick({ $form.WindowState = 'Minimized' })
$top.add_MaxClick({
    if ($form.WindowState -eq 'Maximized') { $form.WindowState = 'Normal' }
    else { $form.MaximizedBounds = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea; $form.WindowState = 'Maximized' }
})
$form.Add_SizeChanged({
    $top.Maxed = ($form.WindowState -eq 'Maximized'); $top.Invalidate()
    if ($form.WindowState -eq 'Maximized') { $form.Region = $null }
    elseif ($form.WindowState -eq 'Normal') {
        $rc = New-Object System.Drawing.RectangleF(0, 0, $form.Width, $form.Height)
        $form.Region = New-Object System.Drawing.Region([HX.G]::Round($rc, 10))
    }
})

# ---- page registry
$PageDefs = [ordered]@{
    'Setting'   = @{ Icon = 1; Groups = @('CPU / Scheduler', 'Power');    Sub = 'Scheduler, timer resolution and power plan tweaks' }
    'Network'   = @{ Icon = 2; Groups = @('Network');                     Sub = 'TCP, DNS, QoS and adapter tweaks for lower ping' }
    'Input Lag' = @{ Icon = 3; Groups = @('Graphics / Games');            Sub = 'Game DVR, GPU scheduling and driver latency tweaks' }
    'Keyboard'  = @{ Icon = 4; Groups = @('Input');                       Sub = 'Keyboard and mouse input queue tweaks' }
    'System'    = @{ Icon = 5; Groups = @('Memory / Disk', 'Misc');       Sub = 'Memory, disk, telemetry and cleanup tweaks' }
}
foreach ($g in @($Tweaks | ForEach-Object { $_.G } | Select-Object -Unique)) {
    $known = $false
    foreach ($pd in $PageDefs.Values) { if ($pd.Groups -contains $g) { $known = $true } }
    if (-not $known) { $PageDefs['System'].Groups += $g }
}
$iconMap = @{ 'CPU / Scheduler' = 14; 'Power' = 5; 'Memory / Disk' = 9; 'Input' = 4; 'Graphics / Games' = 10; 'Network' = 2; 'Misc' = 1 }

$script:Pages      = [ordered]@{}
$script:Navs       = [ordered]@{}
$script:Rows       = New-Object System.Collections.ArrayList
$script:ApplyBtns  = New-Object System.Collections.ArrayList
$script:TweakPages = New-Object System.Collections.ArrayList

function New-PageShell($key) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = 'Fill'; $p.BackColor = $cBg; $p.Visible = $false
    $content.Controls.Add($p)
    $script:Pages[$key] = $p
    return $p
}

# dark tooltip for the full tweak description
$tipFont = New-Object System.Drawing.Font('Segoe UI', 9)
$tip = New-Object System.Windows.Forms.ToolTip
$tip.OwnerDraw = $true; $tip.InitialDelay = 500; $tip.AutoPopDelay = 14000
$tip.add_Popup({
    param($s, $e)
    $t = $s.GetToolTip($e.AssociatedControl)
    $m = [System.Windows.Forms.TextRenderer]::MeasureText($t, $tipFont, (New-Object System.Drawing.Size(360, 0)), 'WordBreak')
    $e.ToolTipSize = New-Object System.Drawing.Size(($m.Width + 24), ($m.Height + 18))
})
$tip.add_Draw({
    param($s, $e)
    $bb = New-Object System.Drawing.SolidBrush((Rgb 26 26 26))
    $e.Graphics.FillRectangle($bb, $e.Bounds); $bb.Dispose()
    $pp = New-Object System.Drawing.Pen((Rgb 70 70 70))
    $e.Graphics.DrawRectangle($pp, 0, 0, ($e.Bounds.Width - 1), ($e.Bounds.Height - 1)); $pp.Dispose()
    $rc = New-Object System.Drawing.Rectangle(12, 9, ($e.Bounds.Width - 24), ($e.Bounds.Height - 18))
    [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $e.ToolTipText, $tipFont, $rc, (Rgb 215 215 215), 'WordBreak')
})

# ---- dashboard page
$pDash = New-PageShell 'dash'
$dash = New-Object HX.Dash
$dash.Dock = 'Fill'
$dash.CpuName = $CpuName
$dash.CpuSub  = ('{0} cores {1}' -f $thr, $ghz)
$dash.Cores   = ('{0} cores' -f $thr)
$dash.Clock   = $ghz
$dash.Arch    = $(if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' })
$dash.Os      = $osShort
$gpuSub = 'Graphics Adapter'; if ($gpuList.Count -gt 1) { $gpuSub = ('Graphics Adapter + {0} more' -f ($gpuList.Count - 1)) }
[void]$dash.Items.Add((New-Hw 9  'MEMORY'      ('{0} GB' -f $RamGB) 'Physical memory' '' 1))
[void]$dash.Items.Add((New-Hw 10 'GRAPHICS'    $gpuList[0] $gpuSub 'Active' 0))
[void]$dash.Items.Add((New-Hw 11 'STORAGE C:'  '-' 'System drive' '' 2))
[void]$dash.Items.Add((New-Hw 12 'MOTHERBOARD' $boardTxt 'Mainboard' '' 0))
[void]$dash.Items.Add((New-Hw 13 'NETWORK'     $netName $netDesc $netState 0))
[void]$dash.Items.Add((New-Hw 0  'SYSTEM'      $osShort ('Build {0}  {1}' -f $osBuild, $env:COMPUTERNAME) '' 0))
# optional custom backdrop: put background.png / background.jpg next to the script or in ProgramData\MostKill
foreach ($bd in @($PSScriptRoot, $DataDir)) {
    if (-not $bd) { continue }
    foreach ($bn in 'background.png', 'background.jpg', 'background.jpeg') {
        $bf = Join-Path $bd $bn
        if ((-not $dash.Backdrop) -and (Test-Path -LiteralPath $bf)) {
            try {
                $script:BgStream = New-Object System.IO.MemoryStream (,[System.IO.File]::ReadAllBytes($bf))
                $dash.Backdrop = [System.Drawing.Image]::FromStream($script:BgStream)
            } catch {}
        }
    }
}
$pDash.Controls.Add($dash)

# ---- tweak pages
function Update-Counts {
    $tot = 0
    foreach ($pk in $PageDefs.Keys) {
        $rs = @($script:Rows | Where-Object { $_.Page -eq $pk })
        $c = @($rs | Where-Object { $_.Tog.Checked }).Count
        $tot += $c
        $script:Navs[$pk].Badge = ('{0}/{1}' -f $c, $rs.Count)
        $script:Navs[$pk].Invalidate()
    }
    foreach ($b in $script:ApplyBtns) { $b.Text = "APPLY SELECTED [$tot]"; $b.Invalidate() }
}

foreach ($pk in $PageDefs.Keys) {
    $def = $PageDefs[$pk]
    $p = New-PageShell $pk
    [void]$script:TweakPages.Add($p)

    $sm = New-Object HX.Scroll
    $sm.Dock = 'Fill'; $sm.BackColor = $cBg; $sm.Content.BackColor = $cBg
    $bar = New-Object HX.ActBar
    $bar.Dock = 'Bottom'; $bar.BackColor = $cBg
    $head = New-Object HX.Head
    $head.Dock = 'Top'; $head.BackColor = $cBg; $head.Title = $pk.ToUpper(); $head.Sub = $def.Sub
    $p.Controls.Add($sm); $p.Controls.Add($bar); $p.Controls.Add($head)

    # header buttons: ALL / CLEAR for this page
    $bClear = New-Object HX.Btn; $bClear.Kind = 0; $bClear.Text = 'CLEAR'; $bClear.Size = New-Object System.Drawing.Size(76, 30); $bClear.Tag = $pk; $bClear.BackColor = $cBg
    $bAll   = New-Object HX.Btn; $bAll.Kind = 0;   $bAll.Text = 'ALL';   $bAll.Size = New-Object System.Drawing.Size(76, 30);   $bAll.Tag = $pk;   $bAll.BackColor = $cBg
    $head.Controls.Add($bClear); $head.Controls.Add($bAll)
    $head.RightItems.Add($bClear); $head.RightItems.Add($bAll)
    $head.Lay()
    $bAll.Add_Click({   param($s, $e) foreach ($r in $script:Rows) { if ($r.Page -eq $s.Tag) { $r.Tog.Checked = $true } } })
    $bClear.Add_Click({ param($s, $e) foreach ($r in $script:Rows) { if ($r.Page -eq $s.Tag) { $r.Tog.Checked = $false } } })

    # action bar
    $bRec = New-Object HX.Btn; $bRec.Kind = 0; $bRec.Text = 'SELECT RECOMMENDED'; $bRec.Size = New-Object System.Drawing.Size(200, 42); $bRec.BackColor = $cBg
    $bNone = New-Object HX.Btn; $bNone.Kind = 0; $bNone.Text = 'SELECT NONE'; $bNone.Size = New-Object System.Drawing.Size(140, 42); $bNone.BackColor = $cBg
    $bApply = New-Object HX.Btn; $bApply.Kind = 1; $bApply.Text = 'APPLY SELECTED'; $bApply.Size = New-Object System.Drawing.Size(240, 46); $bApply.BackColor = $cBg
    $bar.Controls.Add($bRec); $bar.Controls.Add($bNone); $bar.Controls.Add($bApply)
    $bar.LeftItems.Add($bRec); $bar.LeftItems.Add($bNone); $bar.RightItems.Add($bApply)
    $bar.Lay()
    [void]$script:ApplyBtns.Add($bApply)
    $bRec.Add_Click({  foreach ($r in $script:Rows) { $r.Tog.Checked = [bool]$r.T.Rec } })
    $bNone.Add_Click({ foreach ($r in $script:Rows) { $r.Tog.Checked = $false } })
    $bApply.Add_Click({ Invoke-Selected })

    # cards
    $y = 14
    $multi = ($def.Groups.Count -gt 1)
    foreach ($g in $def.Groups) {
        $items = @($Tweaks | Where-Object { $_.G -eq $g })
        if ($items.Count -eq 0) { continue }
        if ($multi) {
            $sec = New-Object HX.Sec
            $sec.Text = $g.ToUpper(); $sec.BackColor = $cBg
            $sec.Location = New-Object System.Drawing.Point(27, $y); $sec.Size = New-Object System.Drawing.Size(600, 34)
            $sm.Content.Controls.Add($sec)
            $y += 36
        }
        $ic = 1; if ($iconMap.ContainsKey($g)) { $ic = [int]$iconMap[$g] }
        foreach ($t in $items) {
            $card = New-Object HX.Row
            $card.BackColor = $cBg
            $card.Title = $t.Name; $card.Desc = $t.Desc; $card.Rec = [bool]$t.Rec; $card.IconId = $ic
            if ($t.Check) { try { if (& $t.Check) { $card.Applied = $true } } catch {} }
            $card.Location = New-Object System.Drawing.Point(27, $y)
            $card.Size = New-Object System.Drawing.Size(700, 86)
            $cmb = $null
            if ($t.Opts) {
                $cmb = $card.AddDrop()
                foreach ($k in $t.Opts.Keys) { [void]$cmb.Items.Add([string]$k) }
                $cmb.Invalidate()
            }
            $card.SetSelected([bool]$t.Rec)
            $card.Tog.add_CheckedChanged({ Update-Counts })
            $tip.SetToolTip($card, [string]$t.Desc)
            $sm.Content.Controls.Add($card)
            [void]$script:Rows.Add(@{ T = $t; G = $g; Page = $pk; Card = $card; Tog = $card.Tog; Cmb = $cmb })
            $y += 96
        }
    }
    $sm.SetContentHeight($y + 14)
}

# ---- activity log page
$pLog = New-PageShell 'log'
$logHost = New-Object System.Windows.Forms.Panel
$logHost.Dock = 'Fill'; $logHost.BackColor = $cBg; $logHost.Padding = New-Object System.Windows.Forms.Padding(27, 18, 27, 24)
$logCard = New-Object HX.Card
$logCard.Dock = 'Fill'; $logCard.BackColor = $cBg; $logCard.Fill = $cCard
$script:logBox = New-Object System.Windows.Forms.TextBox
$script:logBox.Multiline = $true; $script:logBox.ReadOnly = $true; $script:logBox.ScrollBars = 'Vertical'
$script:logBox.BorderStyle = 'None'; $script:logBox.BackColor = $cCard; $script:logBox.ForeColor = (Rgb 200 200 200)
$script:logBox.Font = New-Object System.Drawing.Font('Consolas', 9.5); $script:logBox.Dock = 'Fill'
$logCard.Controls.Add($script:logBox); $logHost.Controls.Add($logCard)
$logHead = New-Object HX.Head
$logHead.Dock = 'Top'; $logHead.BackColor = $cBg; $logHead.Title = 'ACTIVITY LOG'; $logHead.Sub = 'Every action is written here and to ProgramData\MostKill\log.txt'
$pLog.Controls.Add($logHost); $pLog.Controls.Add($logHead)

# ---- about page
$pAbout = New-PageShell 'about'
$aboutHost = New-Object System.Windows.Forms.Panel
$aboutHost.Dock = 'Fill'; $aboutHost.BackColor = $cBg; $aboutHost.Padding = New-Object System.Windows.Forms.Padding(27, 18, 27, 24)
$info = New-Object HX.InfoCard
$info.Dock = 'Fill'; $info.BackColor = $cBg; $info.Heading = 'HEE'; $info.Tagline = 'FiveM / Windows performance tuner. Every change is recorded first, so RESET puts the originals back.'
$aboutHost.Controls.Add($info)
$aboutHead = New-Object HX.Head
$aboutHead.Dock = 'Top'; $aboutHead.BackColor = $cBg; $aboutHead.Title = 'ABOUT'; $aboutHead.Sub = 'Version, paths and detected hardware'
$bOpen = New-Object HX.Btn; $bOpen.Kind = 0; $bOpen.Text = 'OPEN DATA FOLDER'; $bOpen.Size = New-Object System.Drawing.Size(168, 30); $bOpen.BackColor = $cBg
$aboutHead.Controls.Add($bOpen); $aboutHead.RightItems.Add($bOpen); $aboutHead.Lay()
$bOpen.Add_Click({ try { Start-Process explorer.exe -ArgumentList ('"{0}"' -f $DataDir) } catch {} })
$pAbout.Controls.Add($aboutHost); $pAbout.Controls.Add($aboutHead)

function Refresh-About {
    $info.Lines.Clear()
    $lines = @(
        @('Version',       ('v' + $MKVersion)),
        @('Processor',     $CpuName),
        @('Graphics',      $GpuName),
        @('Memory',        ('{0} GB' -f $RamGB)),
        @('Windows',       $OsName),
        @('Profile',       ('{0} | {1}' -f $(if ($IsLaptop) { 'Laptop' } else { 'Desktop' }), $(if ($IsSSD) { 'SSD / NVMe' } else { 'HDD' }))),
        @('Data folder',   $DataDir),
        @('Log file',      $LogFile),
        @('Tracked values', ('{0} registry values saved for RESET' -f $script:Reg.Count))
    )
    foreach ($l in $lines) { $info.Lines.Add(([string[]]@([string]$l[0], [string]$l[1]))) }
    $info.Invalidate()
}

# ---- sidebar
function New-Nav($text, $icon, $tag, $y, $style) {
    $n = New-Object HX.Nav
    $n.Text = $text; $n.Icon = [int]$icon; $n.Tag = $tag; $n.Style = [int]$style; $n.BackColor = $cSide
    $hh = 46; if ($style -eq 1) { $hh = 36 }
    $n.Location = New-Object System.Drawing.Point(8, $y); $n.Size = New-Object System.Drawing.Size(200, $hh)
    $n.Add_Click({ param($s, $e) Invoke-Nav $s.Tag })
    $side.Controls.Add($n)
    $script:Navs[$tag] = $n
    return $n
}
function New-Cap($text, $y) {
    $c = New-Object HX.Sec
    $c.Text = $text; $c.Line = $false; $c.BackColor = $cSide; $c.Height = 30
    $c.Location = New-Object System.Drawing.Point(18, $y); $c.Size = New-Object System.Drawing.Size(180, 30)
    $side.Controls.Add($c)
}
New-Cap 'MAIN' 8
[void](New-Nav 'Dashboard' 0 'dash' 40 0)
New-Cap 'OPTIMIZER' 94
$ny = 124
foreach ($pk in $PageDefs.Keys) { [void](New-Nav $pk $PageDefs[$pk].Icon $pk $ny 0); $ny += 54 }
[void](New-Nav 'Reset' 6 'reset' $ny 0)
$sideDiv = New-Object System.Windows.Forms.Panel
$sideDiv.Height = 1; $sideDiv.Width = 192; $sideDiv.Left = 12; $sideDiv.BackColor = (Rgb 34 34 34)
$side.Controls.Add($sideDiv)
$nAct   = New-Nav 'ACTIVITY LOG' 7 'log' 500 1
$nAbout = New-Nav 'ABOUT' 8 'about' 540 1
$sideLine = New-Object System.Windows.Forms.Panel
$sideLine.Dock = 'Right'; $sideLine.Width = 1; $sideLine.BackColor = (Rgb 34 34 34)
$side.Controls.Add($sideLine)
function Place-Side {
    $nAct.Top = $side.Height - 92; $nAbout.Top = $side.Height - 50; $sideDiv.Top = $side.Height - 106
}
$side.Add_Resize({ Place-Side })

# ---- navigation / status
function Show-Page($key) {
    foreach ($k in @($script:Pages.Keys)) { $script:Pages[$k].Visible = ($k -eq $key) }
    foreach ($k in @($script:Navs.Keys)) { $script:Navs[$k].Selected = ($k -eq $key); $script:Navs[$k].Invalidate() }
    if ($key -eq 'log') { $script:logBox.SelectionStart = $script:logBox.TextLength; $script:logBox.ScrollToCaret() }
    if ($key -eq 'about') { Refresh-About }
}
function Invoke-Nav($tag) {
    if ($tag -eq 'reset') { Invoke-Restore } else { Show-Page $tag }
}
function Update-Status {
    if (($script:Reg.Count + $script:X.Count) -gt 0) { $top.SetStatus('OPTIMIZED', $cOk) }
    else { $top.SetStatus('SYSTEM READY', $cGray) }
}
function Refresh-Active {
    foreach ($r in $script:Rows) {
        $ok = $false
        if ($r.T.Check) { try { $ok = [bool](& $r.T.Check) } catch {} }
        $r.Card.Applied = $ok; $r.Card.Invalidate()
    }
}
function Set-Busy($b) {
    $side.Enabled = -not $b
    foreach ($p in $script:TweakPages) { $p.Enabled = -not $b }
    if ($b) { $top.SetStatus('WORKING', $cWarn) } else { Update-Status }
    [System.Windows.Forms.Application]::DoEvents()
}

# ---- dark message dialog (buttons: first = primary)
function Show-Dlg([string]$msg, [string]$ttl, [string[]]$btns) {
    $d = New-Object System.Windows.Forms.Form
    $d.FormBorderStyle = 'None'; $d.StartPosition = 'CenterParent'; $d.ShowInTaskbar = $false
    $d.BackColor = (Rgb 22 22 22); $d.KeyPreview = $true; $d.Tag = ''
    $mf = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $sz = [System.Windows.Forms.TextRenderer]::MeasureText($msg, $mf, (New-Object System.Drawing.Size(396, 0)), 'WordBreak')
    $mh = [Math]::Max(22, $sz.Height + 4)
    $d.ClientSize = New-Object System.Drawing.Size(444, (28 + 30 + $mh + 26 + 42 + 24))
    $lt = New-Object System.Windows.Forms.Label
    $lt.Text = $ttl.ToUpper(); $lt.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11); $lt.ForeColor = (Rgb 240 240 240)
    $lt.AutoSize = $true; $lt.Location = New-Object System.Drawing.Point(24, 24); $lt.BackColor = $d.BackColor
    $lm = New-Object System.Windows.Forms.Label
    $lm.Text = $msg; $lm.Font = $mf; $lm.ForeColor = (Rgb 170 170 170); $lm.BackColor = $d.BackColor
    $lm.Location = New-Object System.Drawing.Point(24, 58); $lm.Size = New-Object System.Drawing.Size(396, $mh)
    $d.Controls.Add($lt); $d.Controls.Add($lm)
    $bx = 444 - 24
    for ($i = 0; $i -lt $btns.Count; $i++) {
        $b = New-Object HX.Btn
        $b.Text = $btns[$i]; $b.Kind = $(if ($i -eq 0) { 1 } else { 0 }); $b.BackColor = $d.BackColor
        $b.Size = New-Object System.Drawing.Size(([Math]::Max(104, ($btns[$i].Length * 11 + 36))), 40)
        $bx -= $b.Width
        $b.Location = New-Object System.Drawing.Point($bx, ($d.ClientSize.Height - 24 - 40))
        $bx -= 10
        $b.Add_Click({ param($s, $e) $f = $s.FindForm(); $f.Tag = $s.Text; $f.Close() })
        $d.Controls.Add($b)
    }
    $d.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape') { $s.Close() } })
    $d.Add_Paint({
        param($s, $e)
        $pp = New-Object System.Drawing.Pen((Rgb 64 64 64))
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

# ---- apply / restore
function Invoke-Selected {
    $sel = @($script:Rows | Where-Object { $_.Tog.Checked })
    if ($sel.Count -eq 0) { Log 'Nothing selected.'; Show-Page 'log'; return }
    $a = Show-Dlg ("Apply {0} selected tweak(s)?`r`n`r`nOriginal values are saved first - RESET puts them back." -f $sel.Count) 'Apply tweaks' @('APPLY', 'CANCEL')
    if ($a -ne 'APPLY') { return }
    Show-Page 'log'
    Set-Busy $true
    New-Checkpoint
    $ok = 0; $fail = 0
    foreach ($r in $sel) {
        try {
            $v = $null
            if ($r.Cmb) { $v = $r.T.Opts[[string]$r.Cmb.SelectedItem] }
            $sb = $r.T.Apply
            & $sb $v
            Log ('OK    ' + $r.T.Name)
            $ok++
        } catch { Log ('FAIL  ' + $r.T.Name + ' : ' + $_.Exception.Message); $fail++ }
    }
    Save-State
    Log ('Finished: {0} applied, {1} failed. Restart Windows to apply everything.' -f $ok, $fail)
    try { Refresh-Active } catch {}
    Set-Busy $false
    $q = Show-Dlg ("Done ($ok applied, $fail failed).`r`n`r`nRestart Windows now? (needed for most tweaks)") 'Finished' @('RESTART', 'LATER')
    if ($q -eq 'RESTART') { shutdown.exe /r /t 5 /c "Hee: restarting to apply tweaks" }
}

function Invoke-Restore {
    $a = Show-Dlg 'Restore every value changed by Hee to its original state?' 'Reset' @('RESTORE', 'CANCEL')
    if ($a -ne 'RESTORE') { return }
    Show-Page 'log'
    Set-Busy $true
    Restore-All
    try { Refresh-Active } catch {}
    Set-Busy $false
    $q = Show-Dlg "Everything restored.`r`n`r`nRestart Windows now?" 'Reset complete' @('RESTART', 'LATER')
    if ($q -eq 'RESTART') { shutdown.exe /r /t 5 /c "Hee: restore complete" }
}

# ---- startup
try { (Get-Process -Id $PID).PriorityClass = 'High' } catch {}
$script:wheel = New-Object HX.WheelFilter
[System.Windows.Forms.Application]::AddMessageFilter($script:wheel)

$form.Add_Shown({
    try {
        $rc = New-Object System.Drawing.RectangleF(0, 0, $form.Width, $form.Height)
        $form.Region = New-Object System.Drawing.Region([HX.G]::Round($rc, 10))
        [HX.Native]::Dark($script:logBox.Handle)
        Place-Side
        $form.WindowState = 'Normal'
        $form.TopMost = $true; $form.Activate(); $form.BringToFront(); $form.TopMost = $false
        [HX.Native]::Foreground($form.Handle)
        if ($MKElevated) { [HX.Native]::HideConsole() }
    } catch {
        Write-Host ('Hee startup error: ' + $_.Exception.Message) -ForegroundColor Red
    }
})
$form.Add_FormClosed({ try { [System.Windows.Forms.Application]::RemoveMessageFilter($script:wheel) } catch {} })

Update-Counts
Update-Status
Show-Page 'dash'
Log ('Hee v{0} ready. Restore data: C:\ProgramData\MostKill' -f $MKVersion)
Log ('PC: {0} | {1} GB RAM | {2} | {3}' -f $CpuName, $RamGB, $GpuName, $OsName)
Log ('Detected: {0} | system drive {1}. Recommended selection adapted to this PC.' -f $(if ($IsLaptop) { 'LAPTOP' } else { 'DESKTOP' }), $(if ($IsSSD) { 'SSD/NVMe' } else { 'HDD' }))
Log ('FiveM builds found: ' + ((Get-FiveMExes | Where-Object { $_ -like '*GTAProcess*' }) -join ', '))
Log 'Cards tagged ACTIVE are already applied on this PC.'
if ($script:Reg.Count -gt 0) { Log ('Existing restore data found: {0} registry values tracked.' -f $script:Reg.Count) }
[void]$form.ShowDialog()
