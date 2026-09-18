# RUBEX laptop diagnostics (Windows) — ТОЛЬКО ЧТЕНИЕ.
# Ничего не удаляет, не устанавливает, не меняет. Админ не нужен.
# Запуск из корня проекта (или из любой папки со скриптом):
#   powershell -ExecutionPolicy Bypass -File .\tools\diag-windows.ps1
#   powershell -ExecutionPolicy Bypass -File .\tools\diag-windows.ps1 -Deep
# Получится rubex-diag-<дата>.txt — приложи его в чат Arena (или вставь текстом).

param([switch]$Deep)

$ErrorActionPreference = 'SilentlyContinue'
$rep = [Text.StringBuilder]::new()

function Try2 {
  param([string]$Title, [scriptblock]$Body)
  [void]$rep.AppendLine("`n===== $Title =====")
  try {
    $r = & $Body | Out-String -Width 200
    if ([string]::IsNullOrWhiteSpace($r)) { [void]$rep.AppendLine('(пусто / недоступно без админа)') }
    else { [void]$rep.AppendLine($r.Trim()) }
  } catch { [void]$rep.AppendLine("не удалось: $($_.Exception.Message)") }
}

[void]$rep.AppendLine("RUBEX DIAG | $(Get-Date -Format s) | $($env:COMPUTERNAME) | user=$($env:USERNAME) | PS=$($PSVersionTable.PSVersion)")

Try2 'OS / АПТАЙМ' {
  $os = Get-CimInstance Win32_OperatingSystem
  "Product : $($os.Caption) build $($os.BuildNumber)"
  "Install : $($os.InstallDate)  |  Last boot: $($os.LastBootUpTime)  (аптайм $([int]((Get-Date) - $os.LastBootUpTime).TotalHours) ч)"
  $cs = Get-CimInstance Win32_ComputerSystem
  "Model   : $($cs.Manufacturer) $($cs.Model)"
  $bios = Get-CimInstance Win32_BIOS
  "BIOS    : $($bios.SMBIOSBIOSVersion)  ($($bios.ReleaseDate))"
}

Try2 'CPU / RAM / БАТАРЕЯ' {
  $cs = Get-CimInstance Win32_ComputerSystem
  $cpu = Get-CimInstance Win32_Processor
  "CPU     : $($cpu.Name.Trim())"
  "Cores   : логических $($cs.NumberOfLogicalProcessors), физических $($cpu.NumberOfCores)"
  "Load    : $((Get-CimInstance Win32_Processor).LoadPercentage)% сейчас"
  $free = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
  $tot = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
  "RAM     : всего $tot GB, свободно $free GB ($([math]::Round(100*($tot-$free)/$tot,1))% занято)"
  $b = Get-CimInstance Win32_Battery
  if ($b) { "Battery : $($b.EstimatedChargeRemaining)% ($($b.BatteryStatus))" }
  "PowerPlan: $((powercfg /getactivescheme) -join ' ')"
}

Try2 'ТОП-25 ПРОЦЕССОВ ПО ПАМЯТИ' {
  Get-Process | Sort-Object WS -Descending | Select-Object -First 25 Name,
    @{n='RAM_MB';e={[math]::Round($_.WS/1MB)}}, @{n='CPU_s';e={[math]::Round($_.CPU,1)}}, Id |
    Format-Table -AutoSize | Out-String
}

Try2 'ТОП CPU: СЭМПЛ 3 СЕКУНДЫ' {
  $a = Get-CimInstance Win32_Process
  Start-Sleep -Seconds 3
  $b = Get-CimInstance Win32_Process
  $d = foreach ($p in $b) {
    $o = $a | Where-Object ProcessId -eq $p.ProcessId
    if ($o) { [pscustomobject]@{ Name = $p.Name; Delta_s = [math]::Round(($p.UserModeTime - $o.UserModeTime) / 1e7, 2) } }
  }
  $d | Sort-Object Delta_s -Descending | Select-Object -First 15 | Format-Table -AutoSize | Out-String
}

Try2 'ДИСКИ И ЗДОРОВЬЕ' {
  Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    [pscustomobject]@{
      Drive     = $_.DeviceID
      Total_GB  = [math]::Round($_.Size / 1GB)
      Free_GB   = [math]::Round($_.FreeSpace / 1GB)
      Used_pct  = [math]::Round(100 * ($_.Size - $_.FreeSpace) / $_.Size, 1)
    }
  } | Format-Table -AutoSize | Out-String
  Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType,
    @{n='Size_GB';e={[math]::Round($_.Size/1GB)}}, HealthStatus | Format-Table -AutoSize | Out-String
}

Try2 'АВТОЗАПУСК (ГЛАВНЫЙ КАНАД ДЛЯ УСКОРЕНИЯ СТАРТА)' {
  '--- Win32_StartupCommand ---'
  Get-CimInstance Win32_StartupCommand | Select-Object User, Name, Location, Command | Format-Table -AutoSize -Wrap | Out-String
  '--- Реестр Run ---'
  foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
    if (Test-Path $k) {
      "(KEY) $k"
      (Get-Item $k).GetValueNames() | ForEach-Object { "   $_ = $((Get-ItemProperty $k).$_)" }
    }
  }
  '--- Задачи планировщика вне \Microsoft\ ---'
  Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' -and $_.State -ne 'Disabled' } |
    Select-Object TaskPath, TaskName, State | Format-Table -AutoSize | Out-String
}

Try2 'СЛУЖБЫ: РАБОТАЮТ, НЕ СИСТЕМНЫЕ' {
  $svc = Get-CimInstance Win32_Service | Where-Object { $_.State -eq 'Running' }
  "Всего работающих служб: $($svc.Count)"
  $svc | Where-Object { $_.PathName -notmatch 'C:\\Windows\\' } | ForEach-Object {
    $pid2 = $_.ProcessId
    $mem = if ($pid2) { [math]::Round(((Get-Process -Id $pid2).WorkingSet64 / 1MB), 0) } else { '?' }
    [pscustomobject]@{ Name = $_.Name; Start = $_.StartMode; RAM_MB = $mem; Path = $_.PathName }
  } | Sort-Object RAM_MB -Descending | Select-Object -First 20 | Format-Table -AutoSize -Wrap | Out-String
}

Try2 'DOCKER / WSL — ТУТ ОБЫЧНО И ЖИВЁТ ЛИШНИЕ ГБ' {
  '--- docker system df ---'
  if (Get-Command docker) {
    (docker system df 2>&1) -join "`n"
    '--- контейнеры ---'
    (docker ps -a --format '{{.Names}} | {{.Status}} | {{.Size}}' 2>&1) -join "`n"
    '--- образы (топ 15) ---'
    (docker images --format '{{.Repository}}:{{.Tag}} | {{.Size}}' 2>&1 | Select-Object -First 15) -join "`n"
    '--- тома ---'
    (docker volume ls 2>&1) -join "`n"
  } else { 'docker не найден в PATH' }
  '--- WSL дистрибутивы ---'
  $env:WSL_UTF8 = '1'
  if (Get-Command wsl.exe) { (wsl.exe -l -v 2>&1) -join "`n" }
  '--- размеры vhdx (они НЕ сжимаются сами!) ---'
  foreach ($d in @("$env:LOCALAPPDATA\Docker", "$env:LOCALAPPDATA\Packages")) {
    Get-ChildItem $d -Recurse -Include *.vhdx -EA SilentlyContinue | ForEach-Object {
      "{0,8:N1} GB  {1}" -f ($_.Length / 1GB), $_.FullName
    }
  }
}

Try2 'RAM: ПЛАНКИ / СЛОТЫ / ЗАРЕЗЕРВИРОВАНО ВЕГАСОЙ' {
  '--- распознано ОС ---'
  $cs = Get-CimInstance Win32_ComputerSystem
  "Win32_ComputerSystem.TotalPhysicalMemory : {0:N2} ГБ" -f ($cs.TotalPhysicalMemory / 1GB)
  $osx = Get-CimInstance Win32_OperatingSystem
  "Win32_OperatingSystem.TotalVisibleMemory : {0:N2} ГБ" -f ($osx.TotalVisibleMemorySize / 1MB)
  "Свободно сейчас                          : {0:N2} ГБ" -f ($osx.FreePhysicalMemory / 1MB)
  $c = [math]::Round(($cs.TotalPhysicalMemory - $osx.TotalVisibleMemorySize * 1KB) / 1GB, 2)
  "Зарезервировано (iGPU/ACPI/Reserved)      : {0:N2} ГБ" -f $c
  '--- физические модули ---'
  Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
    [pscustomobject]@{
      Slot     = $_.DeviceLocator
      GB       = [math]::Round($_.Capacity / 1GB)
      Speed    = $_.Speed
      ConfMBps = $_.ConfiguredClockSpeed
      Vendor   = $_.Manufacturer
      Serial   = $_.SerialNumber
    }
  } | Format-Table -AutoSize | Out-String
  '--- сколько слотов всего ---'
  Get-CimInstance Win32_PhysicalMemoryArray | ForEach-Object {
    [pscustomobject]@{ Max_GB = [math]::Round($_.MaxCapacity / 1MB); Slots = $_.MemoryDevices; Used = ($_.TotalPhysicalMemory/1GB) }
  } | Format-Table -AutoSize | Out-String
  '--- сведения о видеоядре (Unified Addressing) ---'
  Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate,
    @{n='RAM_MB';e={[math]::Round($_.TotalMemory / 1MB)}} | Format-Table -AutoSize | Out-String
  '--- Hyper-V / WSL2 активны? ---'
  "HypervisorPresent: $($cs.HypervisorPresent)"
  "VirtualizationFirmwareEnabled: $((Get-CimInstance Win32_ComputerSystem).HyperVRequirementVirtualizationFirmwareEnabled)"
}

Try2 'СЕТЬ / VPN / DNS' {
  '--- адаптеры ---'
  Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress, DriverVersion | Format-Table -AutoSize | Out-String
  '--- DNS ---'
  Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } |
    Select-Object InterfaceAlias, @{n='DNS';e={ ($_.ServerAddresses -join ', ') }} | Format-Table -AutoSize | Out-String
  '--- VPN-туннели (Wintun: ест CPU на каждом соединении) ---'
  $t = Get-VpnConnection -EA SilentlyContinue
  if ($t) { $t | Select-Object Name, ServerAddress, ConnectionStatus | Format-Table -AutoSize | Out-String } else { 'нет' }
  '--- MTU активного адаптера ---'
  Get-NetIPInterface -AddressFamily IPv4 -ConnectionState Connected -EA SilentlyContinue |
    Select-Object InterfaceAlias, NlMtu, AutomaticMetric, RouteMetric | Format-Table -AutoSize | Out-String
}

Try2 'DEFENDER: НАВИГАЦИЯ ПО node_modules' {
  $pr = Get-MpPreference -EA SilentlyContinue
  if ($pr) {
    "RealTimeProtection: $($pr.DisableRealtimeMonitoring -notcontains $true)"
    "ExclusionPath     : $($pr.ExclusionPath -join '; ')"
    "ExclusionExtension: $($pr.ExclusionExtension -join '; ')"
    "ExclusionProcess  : $($pr.ExclusionProcess -join '; ')"
    "Threats за 14 дней: $((Get-MpThreatDetection -EA SilentlyContinue | Measure-Object).Count)"
  } else { 'Get-MpPreference недоступен без админа' }
}

Try2 'МЕСТО В ХОТЕ: КУСКИ' {
  $paths = @(
    "$env:TEMP", "$env:LOCALAPPDATA\Temp", "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data", "$env:LOCALAPPDATA\Google\Chrome\User Data",
    "$env:LOCALAPPDATA\npm-cache", "$env:LOCALAPPDATA\pnpm", "$env:APPDATA\npm",
    "$env:USERPROFILE\.nuget\packages", "$env:LOCALAPPDATA\JetBrains", "$env:LOCALAPPDATA\pip\Cache",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer", "$env:LOCALAPPDATA\CrashDumps",
    "$env:USERPROFILE\Downloads", "$env:LOCALAPPDATA\Microsoft\Windows\WER",
    "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell", "$env:USERPROFILE\.gradle\caches",
    "$env:USERPROFILE\.cache", "$env:LOCALAPPDATA\Docker", "$env:USERPROFILE\.wslconfig",
    "$env:APPDATA\Code\Cache", "$env:APPDATA\Code\CachedData", "$env:APPDATA\Code\logs"
  )
  foreach ($p in $paths) {
    if (Test-Path $p) {
      if ((Get-Item $p).PSIsContainer) {
        $mb = [math]::Round(((Get-ChildItem $p -Recurse -File -EA SilentlyContinue |
          Measure-Object Length -Sum).Sum / 1MB), 1)
      } else { $mb = [math]::Round(((Get-Item $p).Length / 1MB), 2) }
      "{0,10:N1} MB  {1}" -f $mb, $p
    }
  }
  '--- .wslconfig (если есть — вот его содержимое) ---'
  $w = "$env:USERPROFILE\.wslconfig"
  if (Test-Path $w) { Get-Content $w -Raw }
  '--- node_modules / .next рядом с проектами ---'
  Get-ChildItem "$env:USERPROFILE" -Directory -Depth 3 -EA SilentlyContinue |
    Where-Object { $_.Name -in 'node_modules', '.next', '.venv', 'target', 'build' } |
    Select-Object -First 25 -ExpandProperty FullName
}

Try2 'ОБНОВЛЕНИЯ / ПЕРЕЗАГРУЗКА' {
  '--- pending reboot ---'
  $kb = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
  if (Test-Path $kb) { 'RebootPending: ДА (CBS)' } else { 'RebootPending (CBS): нет' }
  $au = 'HKLM:\SOFTWARE\Microsoft\Windows\Update\Auto Update\RebootRequired'
  if (Test-Path $au) { 'RebootRequired: ДА (WU)' }
  '--- последние обновления ---'
  Get-CimInstance Win32_QuickFixEngineering | Sort-Object InstalledOn -Descending |
    Select-Object -First 8 HotFixID, Description, InstalledOn | Format-Table -AutoSize | Out-String
}

Try2 'ОШИБКИ СИСТЕМЫ ЗА 3 ДНЯ' {
  Get-WinEvent -FilterHashtable @{ LogName = 'Application', 'System'; Level = 1, 2, 3; StartTime = (Get-Date).AddDays(-3) } -MaxEvents 25 -EA SilentlyContinue |
    Select-Object TimeCreated, Id, ProviderName, @{n='Msg';e={ (($_.Message -split "`r?`n")[0]) }} |
    Format-Table -AutoSize -Wrap | Out-String
}

if ($Deep) {
  Try2 'ТОП-30 ПАПОК >300MB В ПРОФИЛЕ (медленно: 2-10 мин)' {
    $r = Get-ChildItem $env:USERPROFILE -Directory -EA SilentlyContinue | ForEach-Object {
      $s = (Get-ChildItem $_.FullName -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum
      if ($s -gt 300MB) { [pscustomobject]@{ GB = [math]::Round($s / 1GB, 2); Path = $_.FullName } }
    }
    $r | Sort-Object GB -Descending | Select-Object -First 30 | Format-Table -AutoSize | Out-String
  }
}

[void]$rep.AppendLine("`n===== КОНЕЦ =====")
$Out = Join-Path (Get-Location) "rubex-diag-$(Get-Date -Format yyyyMMdd-HHmmss).txt"
Set-Content -Path $Out -Value $rep.ToString() -Encoding UTF8
Write-Host "Готово: $Out" -ForegroundColor Green
Write-Host 'Пришли этот .txt в чат (или вставь содержимое текстом) — соберу план чистки и ускорения.'
