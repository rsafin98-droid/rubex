# RUBEX tune (Windows) — выключает лишний фон, чтобы освободить RAM/CPU и ускорить сборку.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\tune.ps1             # СУХОЙ ПРОГОН: только план (можно без админа)
#   powershell -ExecutionPolicy Bypass -File .\tools\tune.ps1 -Apply      # применить (Запуск от админа обязателен)
#   powershell -ExecutionPolicy Bypass -File .\tools\tune.ps1 -Revert     # вернуть всё как было
#   powershell -ExecutionPolicy Bypass -File .\tools\tune.ps1 -Apply -PinPagefile -NoPowerPlan
#
# Ничего не удаляется с диска, ничего не деинсталлируется. Все изменения сохраняются
# в rubex-tune-backup.json рядом со скриптом — откат полный.

param(
  [switch]$Apply,
  [switch]$Revert,
  [switch]$PinPagefile,
  [switch]$NoPowerPlan
)

$ErrorActionPreference = 'SilentlyContinue'
$Backup = Join-Path (Get-Location) 'rubex-tune-backup.json'
$log = [Text.StringBuilder]::new()

function Note([string]$s) { Write-Host $s; [void]$log.AppendLine($s) }
function ToStartupType([string]$m) {
  switch ($m) {
    'Auto'     { return 'Automatic' }
    'Manual'   { return 'Manual' }
    'Disabled' { return 'Disabled' }
    default    { return 'Manual' }
  }
}

# --- что отключаем: только обновления/помощники/чужие агенты -----------------
$Services = @(
  'YandexBrowserService',        # апдейтер Яндекса — браузер обновится и сам
  'PlanetVPNService',            # 2-й VPN-стек на машине
  'VPNUnlimitedService',         # 3-й VPN-стек
  'AdobeARMservice',             # апдейтер Acrobat
  'Apple Mobile Device Service', # синхронизация iPhone через iTunes (для Safari/PWA не нужен)
  'Bonjour Service',             # поиск устройств Apple в сети
  'HPPrintScanDoctorService',    # HP «диагностика принтера»
  'hp-one-agent-service',        # HP Support Assistant
  'HP Comm Recover',             # HP Wireless Manager
  'SysMain',                     # супер-выборка: на свопящей машине — лишняя нагрузка
  'WSearch'                      # индексатор поиска
)
# только показать: неизвестные и системные — сам решишь после -Who
$Watch = @('IsAppService', 'HappService', 'WsDrvInst', 'AVP21.26', 'MDCoreSvc', 'ClickToRunSvc')
$RunKeys = @(
  'OneDriveSetup', 'Lesta Game Center', 'Adobe Acrobat Synchronizer', 'utweb',
  'Teams', 'PDFCLnch', 'MediaGet2', 'Proton VPN', 'YandexBrowserAutoLaunch'
)
$LeaveAlone = @('HPSEU_Host_Launcher', 'RtkAudUService', 'SecurityHealth', 'Multimedia Class Scheduler')

$runPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$svcPlan = New-Object System.Collections.ArrayList
$runPlan = New-Object System.Collections.ArrayList

# ============================ ОТКАТ =========================================
if ($Revert) {
  if (-not (Test-Path $Backup)) {
    Write-Host 'Нет rubex-tune-backup.json — откатывать нечего.' -ForegroundColor Yellow
    return
  }
  $st = Get-Content $Backup -Raw | ConvertFrom-Json
  Note '=== REVERT ==='
  foreach ($svc in $st.Services) {
    Set-Service -Name $svc.Name -StartupType (ToStartupType $svc.Start)
    Note ("  служба {0} -> {1}" -f $svc.Name, $svc.Start)
  }
  foreach ($rk in $st.RunKeys) {
    New-ItemProperty -Path $rk.Path -Name $rk.Name -Value $rk.Value -PropertyType ExpandString -Force
    Note ("  автостарт {0} восстановлен" -f $rk.Name)
  }
  powercfg /h /type full
  Note '  гибернация и Fast Startup включены обратно'
  Note '  Готово: выйди и зайди в систему (или перезагрузись).'
  Set-Content -Path (Join-Path (Get-Location) 'rubex-tune.txt') -Value $log.ToString() -Encoding UTF8
  return
}

# ============================ ПЛАН / ДЕЙСТВИЯ ================================
Note ("RUBEX TUNE | {0} | {1}" -f (Get-Date -Format s), $(if ($Apply) { 'ПРИМЕНЕНИЕ' } else { 'СУХОЙ ПРОГОН' }))
if (-not $Apply) { Note 'Менять ничего не буду. Реальный запуск: .\tools\tune.ps1 -Apply из PowerShell ОТ АДМИНА' }
Note ''

$av = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct
Note '--- Активный антивирус (исключения добавлять нужно в НЕГО) ---'
if ($av) { foreach ($a in $av) { Note ("  {0} | {1} | state={2}" -f $a.displayName, $a.pathToSignedProductExe, $a.productState) } }
else { Note '  не удалось прочитать (нужен админ)' }
Note ''

Note '--- Службы: отключаем ---'
foreach ($n in $Services) {
  $s = Get-CimInstance Win32_Service -Filter "Name='$n'"
  if (-not $s) { Note ("  {0,-30} — не найдена, пропускаю" -f $n); continue }
  [void]$svcPlan.Add([pscustomobject]@{ Name = $n; Start = $s.StartMode })
  Note ("  {0,-30} [{1}] {2}" -f $n, $s.StartMode, $s.DisplayName)
  if ($Apply) {
    Stop-Service -Name $n -Force
    Set-Service -Name $n -StartupType Disabled
  }
}
Note ''

Note '--- Службы: ТОЛЬКО показываю (неизвестное/системное — решай сам) ---'
foreach ($n in $Watch) {
  $s = Get-CimInstance Win32_Service -Filter "Name='$n'"
  if (-not $s) { continue }
  $exe = $s.PathName -replace '^"?([^ "]+).*', '$1'
  $prod = ''
  if (Test-Path $exe) { $prod = (Get-Item $exe).VersionInfo.ProductName }
  Note ("  {0,-22} [{1}] {2} | {3}" -f $n, $s.StartMode, $prod, $s.PathName)
}
Note ''

Note '--- Автозапуск: снимаем с Run-ключей ---'
$all = (Get-Item $runPath).GetValueNames()
foreach ($n in $RunKeys) {
  $hit = $all | Where-Object { $_ -like "$n*" } | Select-Object -First 1
  if (-not $hit) { Note ("  {0,-45} — нет в реестре, пропускаю" -f $n); continue }
  $val = (Get-ItemProperty -Path $runPath -Name $hit).$hit
  [void]$runPlan.Add([pscustomobject]@{ Path = $runPath; Name = $hit; Value = $val })
  Note ("  {0,-45} = {1}" -f $hit, $val)
  if ($Apply) { Remove-ItemProperty -Path $runPath -Name $hit }
}
Note ''
Note '--- Не трогаем намеренно ---'
foreach ($n in $LeaveAlone) { Note ("  {0}" -f $n) }
Note '  (HPSEU = горячие клавишы/Fn, RtkAud = звук, SecurityHealth = центр безопасности)'
Note ''

Note '--- Питание и память ---'
Note '  powercfg /h off   : гибернация + Fast Startup off, освобождает hiberfil.sys на C:'
if (-not $NoPowerPlan) { Note '  powercfg High performance : схема "Максимальная производительность"' }
else { Note '  -NoPowerPlan: схему питания не меняю' }
Note '  EnableTransparency = 0 : убирает размытие (Vega 3 + 5.9 ГБ RAM)'
if ($PinPagefile) { Note '  -PinPagefile : pagefile фиксированный 12288 МБ (без фризов при ресайзе)' }
else { Note '  pagefile: не трогаю (он тебе нужен: коммит 15 из 18 ГБ)' }

if ($Apply) {
  powercfg /h off
  Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name EnableTransparency -Value 0 -Type DWord
  if (-not $NoPowerPlan) { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c }
  if ($PinPagefile) {
    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.AutomaticManagedPagefile) { Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false } }
    $pf = Get-CimInstance Win32_PageFileSetting
    if ($pf) { Set-CimInstance -InputObject $pf -Property @{ InitialSize = 12288; MaximumSize = 12288 } }
    else { Note '  pagefile: параметр не найден — зафиксируй вручную: sysdm.cpl > Дополнительно > Быстродействие > Виртуальная память' }
  }
  [pscustomobject]@{ Services = $svcPlan; RunKeys = $runPlan } | ConvertTo-Json -Depth 5 | Set-Content -Path $Backup -Encoding UTF8
  Note ''
  Note ("Бэкап состояния: {0}   (откат: .\tools\tune.ps1 -Revert)" -f $Backup)
  Note 'Теперь перезагрузись — освобождение памяти будет видно сразу.'
}
else {
  Note ''
  Note ("Посчитано к отключению: служб {0}, автозапуска {1}." -f $svcPlan.Count, $runPlan.Count)
}

Set-Content -Path (Join-Path (Get-Location) 'rubex-tune.txt') -Value $log.ToString() -Encoding UTF8
Write-Host ''
Write-Host 'Отчёт: rubex-tune.txt' -ForegroundColor Green
