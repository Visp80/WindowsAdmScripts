# Найти актуальный путь к winget.exe
$WingetPath = (Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Recurse -File -Name "winget.exe" | Select-Object -First 1 | ForEach-Object { "$env:ProgramFiles\WindowsApps\$_" })

if ($WingetPath) {
    # Пример установки программы (например, Google Chrome)
    #& $WingetPath install --id Google.Chrome --silent --accept-package-agreements --accept-source-agreements

    # Или обновление всех программ
    & $WingetPath upgrade --silent --accept-package-agreements --accept-source-agreements
} else {
    Write-Error "winget.exe не найден!"
}