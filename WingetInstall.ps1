<#
.SYNOPSIS
    Скрипт для тиscaled-встановлення WinGet та його залежностей на корпоративні ПК.
    Виконувати з правами Адміністратора (SYSTEM).
#>

$ErrorActionPreference = "Stop"

# Тимчасова папка для завантаження
$tempFolder = "$env:SystemDrive\WingetInstallTemp"
if (-not (Test-Path $tempFolder)) { New-Item -Path $tempFolder -ItemType Directory | Out-Null }

# Посилання на останні версії WinGet та залежностей з офіційного GitHub/Microsoft
$urls = @(
    "https://github.com",
    "https://aka.ms",
    "https://github.com"
)

Write-Host "Завантаження компонентів WinGet..." -ForegroundColor Cyan
foreach ($url in $urls) {
    $fileName = Split-Path $url -Leaf
    $outputPath = Join-Path $tempFolder $fileName
    
    # Використовуємо TLS 1.2 для безпечного завантаження
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
}

Write-Host "Встановлення залежностей та WinGet..." -ForegroundColor Cyan
# Важливо: інсталюємо спочатку залежності (XAML, VCLibs), потім сам WinGet
Get-ChildItem -Path $tempFolder -Filter *.appx | ForEach-Object {
    Add-AppxProvisionedPackage -Online -PackagePath $_.FullName -SkipLicense | Out-Null
}

Get-ChildItem -Path $tempFolder -Filter *.msixbundle | ForEach-Object {
    Add-AppxProvisionedPackage -Online -PackagePath $_.FullName -SkipLicense | Out-Null
}

# Очищення тимчасових файлів
Remove-Item -Path $tempFolder -Recurse -Force | Out-Null

Write-Host "WinGet успішно інстальовано для всіх користувачів системи." -ForegroundColor Green
