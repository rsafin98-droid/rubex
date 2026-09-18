# RUBEX cleanup helper (Windows) — по умолчанию ТОЛЬКО СЧИТЫВАЕТ.
# Ничего не удаляет, пока ты не скажешь -Apply. Админ не нужен (кроме -DeepSystem).
#
#   powershell -ExecutionPolicy Bypass -File .\tools\cleanup-windows.ps1              # что можно освободить
#   powershell -ExecutionPolicy Bypass -File .\tools\cleanup-windows.ps1 -Apply        # удалить кэши из списка
#   powershell -ExecutionPolicy Bypass -File .\tools\cleanup-windows.ps1 -Apply -PmCache -NodeModules C:\path\to\project
#
# В конце печатает «освобождено X ГБ».

param(
  [switch]$Apply,
  [switch]$PmCache,
  [switch]$DeepSystem,
  [string]$NodeModules = ''
)

$ErrorActionPreference = 'SilentlyContinue'
$script:freed = 0L
$log = [Text.StringBuilder]::new()

function Say([string]$s) { Write-Host $s; [void]$log.AppendLine($s) }
function DirSizeMB([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { return -1 }
  $i = Get-Item -LiteralPath $p
  if (-not $i.PSIsContainer) { return [math]::Round($i.Length / 1MB, 1) }
  $sum = (Get-ChildItem -LiteralPath $p -Recurse -File -Force -EA SilentlyContinue |
    Measure-Object -Property Length -Sum).Sum
  if ($null -eq $sum) { $sum = 0 }
  return [math]::Round($sum / 1MB, 1)
}
function Report([string]$label, [string]$path) {
  $mb = DirSizeMB $path
  if ($mb -lt 0) { return }
  Say ("[счёт ] {0,-42} {1,10:N1} MB  (сам не трогаю — реши вручную)" -f $label, $mb)
}
function Empty([string]$label, [string]$path) {
  $mb = DirSizeMB $path
  if ($mb -lt 0) { return }
  $mark = 'счёт'
  if ($Apply) { $mark = 'ОЧИСТКА' }
  Say ("[{0}] {1,-42} {2,10:N1} MB" -f $mark, $label, $mb)
  if ($Apply) {
    Get-ChildItem -LiteralPath $path -Recurse -Force -EA SilentlyContinue |
      Remove-Item -Recurse -Force -EA SilentlyContinue
    $after = DirSizeMB $path
    if ($after -lt 0) { $after = 0 }
    if ($after -lt $mb) { $script:freed += [long](($mb - $after) * 1MB) }
  }
}

Say ("RUBEX cleanup | {0} | режим: {1}" -f (Get-Date -Format s), $(if ($Apply) { 'ПРИМЕНЕНИЕ' } else { 'СУХОЙ ПРОГОН (ничего не удаляю)' }))
$v = Get-Volume -DriveLetter C
$freeBefore = [math]::Round($v.SizeRemaining / 1GB, 2)
Say ("Свободно на C: ДО: {0} ГБ из {1} ГБ" -f $freeBefore, [math]::Round($v.Size / 1GB, 1))
$os = Get-CimInstance Win32_OperatingSystem
$ramTot = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$ramFree = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$commit = [math]::Round(($os.TotalVirtualMemorySize - $os.FreeVirtualMemory) / 1MB, 2)
Say ("Память: {0} ГБ всего / свободно {1} ГБ | commit {2} ГБ" -f $ramTot, $ramFree, $commit)
Say ''

Say '--- Пользовательский хлам (безопасно) ---'
Empty 'Temp (юзер)'            "$env:TEMP"
Empty 'LocalAppData\Temp'      "$env:LOCALAPPDATA\Temp"
Empty 'CrashDumps'             "$env:LOCALAPPDATA\CrashDumps"
Empty 'WER (отчёты об ошибках)' "$env:LOCALAPPDATA\Microsoft\Windows\WER"
if ($Apply) { Clear-RecycleBin -Force -EA SilentlyContinue }
Say '[ОЧИСТКА/счёт] Корзина — Clear-RecycleBin'
Empty 'Explorer-иконки (кэш)'  "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
Empty 'Windows Error Reporting' "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportQueue"

Say ''
Say '--- Браузер: только Cache/Code Cache/GPUCache (пароли и закладки не трогаем) ---'
foreach ($br in @('Google\Chrome\User Data', 'Microsoft\Edge\User Data')) {
  $base = Join-Path $env:LOCALAPPDATA $br
  if (Test-Path $base) {
    foreach ($prof in (Get-ChildItem $base -Directory -EA SilentlyContinue | Where-Object { $_.Name -like 'Default' -or $_.Name -like 'Profile *' })) {
      foreach ($c in @('Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage')) {
        $p = Join-Path $prof.FullName $c
        if (Test-Path -LiteralPath $p) {
          $mb = DirSizeMB $p
          Say ("  {0,-14} {1,9:N1} MB  {2}" -f $br.Split('\')[0], $mb, $p.Replace($env:USERPROFILE, '~'))
          if ($Apply) {
            Get-ChildItem -LiteralPath $p -Recurse -Force -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue
            $after = DirSizeMB $p
            if ($after -lt 0) { $after = 0 }
            if ($after -lt $mb) { $script:freed += [long](($mb - $after) * 1MB) }
          }
        }
      }
    }
  }
}

Say ''
Say '--- Сборка/пакетные кэши (пересоздадутся сами) ---'
if (Get-Command npm) {
  $npmCache = (npm config get cache 2>&1) -join ''
  Empty 'npm cache' $npmCache
}
Empty 'pnpm store'    "$env:LOCALAPPDATA\pnpm\store"
Empty 'pip cache'     "$env:LOCALAPPDATA\pip\Cache"
Empty 'NuGet'         "$env:USERPROFILE\.nuget\packages"
Report 'JetBrains (caches/logs)' "$env:LOCALAPPDATA\JetBrains"
Empty 'VS Code Cache' "$env:APPDATA\Code\Cache"
Empty 'VS Code CachedData' "$env:APPDATA\Code\CachedData"
Empty 'VS Code logs'  "$env:APPDATA\Code\logs"
Empty 'Gradle caches' "$env:USERPROFILE\.gradle\caches"
Empty 'node-gyp'      "$env:USERPROFILE\AppData\Local\node-gyp\Cache"

if ($PmCache) {
  Say ''
  Say '--- Проектные node_modules / .next (переставится/пересоберётся) ---'
  $roots = @("$env:USERPROFILE\source", "$env:USERPROFILE\projects", "$env:USERPROFILE\dev", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents")
  if ($NodeModules) { $roots = @($NodeModules) }
  foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    Get-ChildItem $r -Directory -Recurse -Depth 4 -EA SilentlyContinue |
      Where-Object { $_.Name -in 'node_modules', '.next' } | ForEach-Object {
        $mb = DirSizeMB $_.FullName
        Say ("  {0,9:N1} MB  {1}" -f $mb, $_.FullName)
        if ($Apply) {
          Remove-Item -LiteralPath $_.FullName -Recurse -Force -EA SilentlyContinue
          if ($mb -gt 0) { $script:freed += [long]($mb * 1MB) }
        }
      }
  }
}

Say ''
Say '--- Docker / WSL (если есть) ---'
if (Get-Command docker) {
  Say '  docker system df:'
  (docker system df 2>&1) | ForEach-Object { Say ("    " + $_) }
  if ($Apply) {
    Say '  prune: docker system prune -f (без -a, тома и активные образы не трогаем)'
    (docker system prune -f 2>&1) | ForEach-Object { Say ("    " + $_) }
    $env:WSL_UTF8 = '1'
  }
  Say '  !!! .vhdx Docker Desktop сам не сжимается. Освободить вручную:'
  Say '      wsl --shutdown'
  Say '      diskpart → select vdisk file="<путь>\docker_data.vhdx" → compact vdisk'
}
foreach ($d in @("$env:LOCALAPPDATA\Docker", "$env:LOCALAPPDATA\Packages")) {
  Get-ChildItem $d -Recurse -Include *.vhdx -EA SilentlyContinue | ForEach-Object {
    Say ("  VHDX {0,7:N1} GB  {1}" -f ($_.Length / 1GB), $_.Name)
  }
}

if ($DeepSystem) {
  Say ''
  Say '--- Системное (только с админ-PowerShell) ---'
  Empty 'WU download cache' "$env:windir\SoftwareDistribution\Download"
  Empty 'Temp (системный)'  "$env:windir\Temp"
  Empty 'Prefetch'          "$env:windir\Prefetch"
  $hib = "$env:SystemDrive\hiberfil.sys"
  if (Test-Path $hib) {
    $mb = DirSizeMB $hib
    Say ("  hiberfil.sys {0:N1} MB — освобождается командой: powercfg /h off" -f ($mb / 1024))
  }
  $pagefile = Get-CimInstance Win32_PageFileUsage
  if ($pagefile) {
    Say ("  pagefile: назначено {0} МБ, пик {1} МБ (не удаляй вручную)" -f $pagefile.AllocatedBaseSize, $pagefile.CurrentUsage)
  }
}

Say ''
Say '--- Ещё полезно (я это сам не делаю, команды для тебя) ---'
Say '  Storage Sense:      Settings → System → Storage → Sense (включить + "Temporary files")'
Say '  Автозагрузка:       Get-CimInstance Win32_StartupCommand | Select Name,Command'
Say '  Дефендер-исключение: Add-MpPreference -ExclusionPath "<папка проекта>" (запустить от админа)'
Say '  Гибернация (минус ~RAM ГБ): powercfg /h off'
Say ''
$freedGB = [math]::Round($script:freed / 1GB, 2)
if ($Apply) {
  $freeAfter = [math]::Round((Get-Volume -DriveLetter C).SizeRemaining / 1GB, 2)
  Say ("Освобождено ~{0} ГБ. Свободно на C: ПОСЛЕ: {1} ГБ (было {2})" -f $freedGB, $freeAfter, $freeBefore)
  Say 'Совет: после чистки перезагрузись и проверь "Свободно" + скорость сборки.'
} else {
  Say ("Если посчитанное реально удалять: запусти с -Apply (примерно {0} ГБ к освобождению)." -f $freedGB)
}

Set-Content -Path (Join-Path (Get-Location) 'rubex-cleanup.txt') -Value $log.ToString() -Encoding UTF8
