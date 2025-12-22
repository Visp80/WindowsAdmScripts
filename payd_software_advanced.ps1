

$ErrorActionPreference = "SilentlyContinue"
$Desktop = [Environment]::GetFolderPath("Desktop")
$ReportFile = "paid_report.txt"

function Write-Report($text) {
    Write-Host $text
    $text | Out-File -FilePath $ReportFile -Encoding UTF8 -Append
}

Clear-Content $ReportFile -ErrorAction SilentlyContinue

Write-Report "ULTRA-CLEAN PAID SOFTWARE REPORT - WINDOWS"
Write-Report "Date: $(Get-Date)"
Write-Report "=======================================================================`n"

# Known paid software patterns (платне ПО)
$PaidPatterns = @(
    "Microsoft Office", "Microsoft Project", "Microsoft Visio", "Office 16 Click-to-Run",
    "RAD Studio", "1С:Підприємство", "1C:Enterprise",
    "Oracle.*Java", "Java.*Oracle", "Office Tab Enterprise",
    "AnyDesk.*Professional"  # якщо є платна версія, але в вас free
)

# Junk filter (те саме, що раніше)
$JunkPatterns = @(
    "Microsoft\.NET\.Native", "Microsoft\.UI\.Xaml", "Microsoft\.VCLibs", "Microsoft\.WinAppRuntime",
    "Microsoft\.Services\.Store", "Microsoft\.DirectX", "Microsoft\.HEIF", "Microsoft\.HEVC",
    "Microsoft\.AV1", "Microsoft\.VP9", "Microsoft\.MPEG2", "Microsoft\.WebMedia", "Microsoft\.Webp",
    "Microsoft\.RawImage", "Microsoft\.Widgets", "Microsoft\.D3DMapping",
    "Microsoft\.WindowsAlarms", "Microsoft\.WindowsCalculator", "Microsoft\.WindowsCamera",
    "Microsoft\.WindowsMaps", "Microsoft\.WindowsNotepad", "Microsoft\.WindowsSoundRecorder",
    "Microsoft\.WindowsScan", "Microsoft\.Paint", "Microsoft\.ScreenSketch", "Microsoft\.StickyNotes",
    "Microsoft\.BingWeather", "Microsoft\.YourPhone", "Microsoft\.ZuneMusic", "Microsoft\.Xbox",
    "Microsoft\.StartExperiences", "Microsoft\.StorePurchase", "Microsoft\.FeedbackHub",
    "Microsoft\.QuickAssist", "Microsoft\.CrossDevice", "Microsoft\.WebExperience",
    "Visual C\+\+.*Redistributable", "Visual C\+\+.*Runtime",
    "Kits Configuration Installer", "Application Verifier", "Windows App Certification Kit",
    "SDK Debuggers", "MSI Development Tools", "WPT", "Windows SDK Signing Tools",
    "Windows SDK EULA", "Windows Software Development Kit", "Update Health Tools"
)

# Registry + Store apps (те саме)
$UninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$Programs = Get-ItemProperty $UninstallKeys |
    Where-Object { $_.DisplayName -and $_.UninstallString } |
    Select-Object DisplayName, DisplayVersion, Publisher |
    Sort-Object DisplayName

$StoreApps = Get-AppxPackage | Where-Object { $_.NonRemovable -eq $false } |
    Select-Object Name, Version, Publisher

$PaidSoftware = @()
$FreeSoftware = @()

# Process programs
foreach ($prog in $Programs) {
    $name = $prog.DisplayName

    $isJunk = $false
    foreach ($pattern in $JunkPatterns) {
        if ($name -match $pattern) { $isJunk = $true; break }
    }
    if ($isJunk) { continue }

    $isPaid = $false
    foreach ($pattern in $PaidPatterns) {
        if ($name -match $pattern) { $isPaid = $true; break }
    }

    if ($isPaid) {
        $PaidSoftware += "$name | $($prog.DisplayVersion) | $($prog.Publisher)"
    } else {
        $FreeSoftware += "$name | $($prog.DisplayVersion) | $($prog.Publisher)"
    }
}

# Store apps (те саме фільтрування)
foreach ($app in $StoreApps) {
    $name = $app.Name
    $isJunk = $false
    foreach ($pattern in $JunkPatterns) {
        if ($name -match $pattern) { $isJunk = $true; break }
    }
    if ($isJunk) { continue }

    $isPaid = $false
    foreach ($pattern in $PaidPatterns) {
        if ($name -match $pattern) { $isPaid = $true; break }
    }

    if ($isPaid) {
        $PaidSoftware += "$name | $($app.Version) | $($app.Publisher) (Store)"
    } else {
        $FreeSoftware += "$name | $($app.Version) | $($app.Publisher) (Store)"
    }
}

# Drivers (безкоштовні, але згадуємо)
Write-Report "PROPRIETARY/FREE DRIVERS:"
Write-Report "-----------------------------------------------------------------------"
$Drivers = Get-WmiObject Win32_PnPSignedDriver | Select-Object DeviceName, DriverProviderName, DriverVersion | Where-Object { $_.DriverProviderName }
$HasDriver = $false
foreach ($d in $Drivers) {
    if ($d.DriverProviderName -match "SteelSeries|AMD|NVIDIA") {
        Write-Report "$($d.DeviceName) — $($d.DriverProviderName) v$($d.DriverVersion) (free)"
        $HasDriver = $true
    }
}
if (-not $HasDriver) { Write-Report "None detected" }

# OS
Write-Report "`nWINDOWS OPERATING SYSTEM:"
Write-Report "-----------------------------------------------------------------------"
Write-Report "Microsoft Windows — paid OS"

# Paid
Write-Report "`nSIGNIFICANT PAID SOFTWARE:"
Write-Report "-----------------------------------------------------------------------"
if ($PaidSoftware.Count -eq 0) {
    Write-Report "None detected"
} else {
    $PaidSoftware | Sort-Object | ForEach-Object { Write-Report $_ }
}

# Free
Write-Report "`nFREE SOFTWARE (installed):"
Write-Report "-----------------------------------------------------------------------"
if ($FreeSoftware.Count -eq 0) {
    Write-Report "None detected"
} else {
    $FreeSoftware | Sort-Object | ForEach-Object { Write-Report $_ }
}

Write-Report "`nReport saved to: $ReportFile"
Write-Host "`nPaid software report saved to Desktop: paid_report.txt" -ForegroundColor Green