# Скрипт для пошуку встановлених програм віддаленого керування
# Запускати від імені адміністратора для повного доступу

$RemoteTools = @(
    "AnyDesk"
    "TeamViewer"
    "Splashtop"
    "RustDesk"
    "LogMeIn"
    "GoToMyPC"
    "GoToAssist"
    "Chrome Remote Desktop"
    "RemotePC"
    "Ammyy Admin"
    "AeroAdmin"
    "Supremo"
    "Remote Utilities"
    "UltraVNC"
    "TightVNC"
    "RealVNC"
    "NoMachine"
    "Parsec"
    "Zoho Assist"
    "ConnectWise Control"
    "BeyondTrust"
    "DWService"
    "LiteManager"
)

$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$FoundTools = @()

foreach ($Path in $UninstallPaths) {
    Get-ItemProperty $Path -ErrorAction SilentlyContinue |
    Where-Object { $DisplayName = $_.DisplayName; $RemoteTools | Where-Object { $DisplayName -like "*$_*" } } |
    ForEach-Object {
        $FoundTools += [PSCustomObject]@{
            Name         = $_.DisplayName
            Version      = $_.DisplayVersion
            Publisher    = $_.Publisher
            UninstallString = $_.UninstallString
            InstallLocation = $_.InstallLocation
        }
    }
}

# Додаткова перевірка процесів (якщо запущені)
$RunningProcesses = Get-Process -ErrorAction SilentlyContinue | Select-Object Name, Path
$ProcessMatches = @(
    "AnyDesk", "TeamViewer", "Splashtop", "rustdesk", "LogMeIn", "chrome-remote", "RemotePC", "Supremo", "rutserv"  # rutserv для Remote Utilities тощо
)

foreach ($Proc in $RunningProcesses) {
    if ($ProcessMatches | Where-Object { $Proc.Name -like "*$_*" -or $Proc.Path -like "*$_*" }) {
        $FoundTools += [PSCustomObject]@{
            Name         = $Proc.Name + " (running process)"
            Version      = "N/A"
            Publisher    = "N/A"
            UninstallString = "N/A"
            InstallLocation = $Proc.Path
        }
    }
}

# Вивід результатів
if ($FoundTools.Count -gt 0) {
    Write-Host "Знайдено програми віддаленого керування:" -ForegroundColor Red
    $FoundTools | Format-Table -AutoSize
} else {
    Write-Host "Програми віддаленого керування не виявлено." -ForegroundColor Green
}