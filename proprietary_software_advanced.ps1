# Ultra-clean proprietary software detector for Windows
# Shows only meaningful proprietary software, hides all system junk
# Run as Administrator

$ErrorActionPreference = "SilentlyContinue"
$Desktop = [Environment]::GetFolderPath("Desktop")
$ReportFile = "$Desktop\proprietary_report.txt"

function Write-Report($text) {
    Write-Host $text
    $text | Out-File -FilePath $ReportFile -Encoding UTF8 -Append
}

Clear-Content $ReportFile -ErrorAction SilentlyContinue

Write-Report "ULTRA-CLEAN PROPRIETARY SOFTWARE REPORT - WINDOWS"
Write-Report "Date: $(Get-Date)"
Write-Report "=======================================================================`n"

# Known open-source patterns (expanded)
$OpenSource = @(
    "7-Zip", "Audacity", "Blender", "CrystalDiskInfo", "CrystalDiskMark",
    "FileZilla", "Firefox", "GIMP", "Git", "Greenshot", "Inkscape", "KeePass",
    "LibreOffice", "Notepad\+\+", "OBS Studio", "PuTTY", "Python", "qBittorrent",
    "ShareX", "SumatraPDF", "VeraCrypt", "VLC", "WinSCP", "Wireshark",
    "Visual Studio Code", "Node.js", "Adoptium", "Eclipse", "OpenRGB",
    "Telegram Desktop", "KaliLinux", "RustDesk", "Signal"
)

# Ultra-strict junk filter — всё, что нужно скрыть
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

# Registry programs
$UninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$Programs = Get-ItemProperty $UninstallKeys |
    Where-Object { $_.DisplayName -and $_.UninstallString } |
    Select-Object DisplayName, DisplayVersion, Publisher |
    Sort-Object DisplayName

# Store apps (non-system only)
$StoreApps = Get-AppxPackage | Where-Object { $_.NonRemovable -eq $false } |
    Select-Object Name, Version, Publisher

$MeaningfulProprietary = @()
$LikelyProprietary = @()
$OpenSourceFound = @()

# Process classic programs
foreach ($prog in $Programs) {
    $name = $prog.DisplayName

    # Skip junk
    $isJunk = $false
    foreach ($pattern in $JunkPatterns) {
        if ($name -match $pattern) { $isJunk = $true; break }
    }
    if ($isJunk) { continue }

    $isOpen = $false
    foreach ($pattern in $OpenSource) {
        if ($name -match $pattern) { $isOpen = $true; break }
    }

    if ($isOpen) {
        $OpenSourceFound += "$name | $($prog.DisplayVersion) | $($prog.Publisher)"
    }
    elseif ($prog.Publisher -match "Microsoft|Google|Adobe|Apple|AMD|NVIDIA|Oracle|SteelSeries") {
        # Only meaningful Microsoft stuff (Office, Edge, Chrome, etc.)
        if ($name -match "Office|Project|Visio|Edge|OneDrive|Teams") {
            $MeaningfulProprietary += "$name | $($prog.DisplayVersion) | $($prog.Publisher)"
        }
        elseif ($prog.Publisher -notmatch "Microsoft") {
            $MeaningfulProprietary += "$name | $($prog.DisplayVersion) | $($prog.Publisher)"
        }
    }
    else {
        $LikelyProprietary += "$name | $($prog.DisplayVersion) | $($prog.Publisher)"
    }
}

# Process Store apps — only non-system third-party or important
foreach ($app in $StoreApps) {
    $name = $app.Name
    $isJunk = $false
    foreach ($pattern in $JunkPatterns) {
        if ($name -match $pattern) { $isJunk = $true; break }
    }
    if ($isJunk) { continue }

    # Keep only meaningful third-party apps
    if ($name -match "WhatsApp|Clipchamp|FBReader|Python") {
        $MeaningfulProprietary += "$name | $($app.Version) | $($app.Publisher) (Store)"
    }
}

# Proprietary drivers
Write-Report "PROPRIETARY DRIVERS (closed-source):"
Write-Report "-----------------------------------------------------------------------"
$Drivers = Get-WmiObject Win32_PnPSignedDriver | Select-Object DeviceName, DriverProviderName, DriverVersion | Where-Object { $_.DriverProviderName }
$HasDriver = $false
foreach ($d in $Drivers) {
    if ($d.DriverProviderName -match "NVIDIA|AMD|ATI|SteelSeries|Realtek|Broadcom|Qualcomm|Razer|Logitech") {
        Write-Report "$($d.DeviceName) — $($d.DriverProviderName) v$($d.DriverVersion)"
        $HasDriver = $true
    }
}
if (-not $HasDriver) { Write-Report "None detected" }

# Core OS
Write-Report "`nWINDOWS OPERATING SYSTEM:"
Write-Report "-----------------------------------------------------------------------"
Write-Report "Microsoft Windows — fully proprietary core"

# Meaningful proprietary software
Write-Report "`nSIGNIFICANT PROPRIETARY SOFTWARE:"
Write-Report "-----------------------------------------------------------------------"
if ($MeaningfulProprietary.Count -eq 0) {
    Write-Report "None detected (besides Windows and drivers)"
} else {
    $MeaningfulProprietary | Sort-Object | ForEach-Object { Write-Report $_ }
}

# Third-party likely proprietary
Write-Report "`nTHIRD-PARTY PROPRIETARY SOFTWARE:"
Write-Report "-----------------------------------------------------------------------"
if ($LikelyProprietary.Count -eq 0) {
    Write-Report "None detected"
} else {
    $LikelyProprietary | Sort-Object | ForEach-Object { Write-Report $_ }
}

# Open-source for reference
Write-Report "`nOPEN-SOURCE SOFTWARE (installed):"
Write-Report "-----------------------------------------------------------------------"
if ($OpenSourceFound.Count -eq 0) {
    Write-Report "None detected"
} else {
    $OpenSourceFound | Sort-Object | ForEach-Object { Write-Report $_ }
}

Write-Report "`nReport saved to: $ReportFile"
Write-Host "`nUltra-clean report saved to Desktop: proprietary_report.txt" -ForegroundColor Green