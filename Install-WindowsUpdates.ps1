#Requires -Version 5.1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Windows Update - API installer" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 1. Check SYSTEM
# ------------------------------------------------------------

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host "User: $currentUser"

if ($currentUser -ne "NT AUTHORITY\SYSTEM") {
    Write-Warning "Script is not running as SYSTEM."
    Write-Warning "Continue anyway..."
}

# ------------------------------------------------------------
# 2. Start required services
# ------------------------------------------------------------

Write-Host ""
Write-Host "[1] Starting Windows Update services..." -ForegroundColor Yellow

$services = @(
    "bits",
    "wuauserv",
    "cryptsvc"
)

foreach ($serviceName in $services) {

    $service = Get-Service -Name $serviceName -ErrorAction Stop

    if ($service.Status -ne "Running") {

        Write-Host "    Starting $serviceName..."

        try {
            Start-Service -Name $serviceName -ErrorAction Stop
        }
        catch {
            Write-Warning "Cannot start $serviceName : $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "    $serviceName already running"
    }
}

# ------------------------------------------------------------
# 3. KB filter
# ------------------------------------------------------------
#
# Put specific KBs here.
#
# Example:
# $TargetKBs = @(
#     "KB5071234",
#     "KB5072345"
# )
#
# Empty array = install ALL applicable updates
#

$TargetKBs = @(
    # "KB5071234"
)

# Normalize KB numbers
$TargetKBs = $TargetKBs |
    ForEach-Object {
        $_.ToUpper().Trim()
    }

# ------------------------------------------------------------
# 4. Create Windows Update API session
# ------------------------------------------------------------

Write-Host ""
Write-Host "[2] Creating Windows Update API session..." -ForegroundColor Yellow

$Session = New-Object -ComObject Microsoft.Update.Session

$Session.ClientApplicationID = "SYSTEM Windows Update API Installer"

$Searcher = $Session.CreateUpdateSearcher()

# ------------------------------------------------------------
# 5. Search updates
# ------------------------------------------------------------

Write-Host ""
Write-Host "[3] Searching for available updates..." -ForegroundColor Yellow
Write-Host "    Please wait..."

$SearchResult = $Searcher.Search(
    "IsInstalled=0 and IsHidden=0 and Type='Software'"
)

Write-Host ""
Write-Host "Found updates: $($SearchResult.Updates.Count)" -ForegroundColor Green

if ($SearchResult.Updates.Count -eq 0) {

    Write-Host ""
    Write-Host "No applicable updates found." -ForegroundColor Green
    exit 0
}

# ------------------------------------------------------------
# 6. Display updates
# ------------------------------------------------------------

Write-Host ""
Write-Host "Available updates:" -ForegroundColor Cyan
Write-Host ""

$AvailableUpdates = @()

for ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {

    $Update = $SearchResult.Updates.Item($i)

    $KBs = @($Update.KBArticleIDs)

    $KBText = if ($KBs.Count -gt 0) {
        ($KBs | ForEach-Object { "KB$_" }) -join ", "
    }
    else {
        "(no KB)"
    }

    $SizeMB = [math]::Round(
        $Update.MaxDownloadSize / 1MB,
        2
    )

    Write-Host "[$i] $KBText" -ForegroundColor White
    Write-Host "    $($Update.Title)"
    Write-Host "    Size: $SizeMB MB"
    Write-Host ""

    $AvailableUpdates += [PSCustomObject]@{
        Index = $i
        KB    = $KBText
        Title = $Update.Title
        Size  = $SizeMB
        Object = $Update
    }
}

# ------------------------------------------------------------
# 7. Select updates
# ------------------------------------------------------------

$UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

if ($TargetKBs.Count -eq 0) {

    Write-Host "[4] No KB filter specified." -ForegroundColor Yellow
    Write-Host "    All applicable updates will be installed."

    foreach ($item in $AvailableUpdates) {

        $update = $item.Object

        # Some updates require EULA acceptance
        if (-not $update.EulaAccepted) {
            try {
                $update.AcceptEula()
            }
            catch {
                Write-Warning "Cannot accept EULA: $($item.Title)"
            }
        }

        [void]$UpdatesToInstall.Add($update)
    }
}
else {

    Write-Host "[4] KB filter enabled:" -ForegroundColor Yellow
    Write-Host "    $($TargetKBs -join ', ')"

    foreach ($item in $AvailableUpdates) {

        $update = $item.Object

        $updateKBs = @(
            $update.KBArticleIDs |
            ForEach-Object {
                "KB$($_)"
            }
        )

        $match = $false

        foreach ($targetKB in $TargetKBs) {

            if ($updateKBs -contains $targetKB) {
                $match = $true
                break
            }
        }

        if ($match) {

            Write-Host ""
            Write-Host "    SELECTED: $($item.KB)" -ForegroundColor Green
            Write-Host "    $($item.Title)"

            if (-not $update.EulaAccepted) {
                try {
                    $update.AcceptEula()
                }
                catch {
                    Write-Warning "Cannot accept EULA."
                }
            }

            [void]$UpdatesToInstall.Add($update)
        }
    }
}

# ------------------------------------------------------------
# 8. Check selected updates
# ------------------------------------------------------------

Write-Host ""

if ($UpdatesToInstall.Count -eq 0) {

    Write-Host "No requested KB updates are currently available." `
        -ForegroundColor Yellow

    if ($TargetKBs.Count -gt 0) {

        Write-Host ""
        Write-Host "Requested KBs:" -ForegroundColor Yellow

        foreach ($kb in $TargetKBs) {
            Write-Host "    $kb"
        }

        Write-Host ""
        Write-Host "Possible reasons:"
        Write-Host "  - KB is already installed"
        Write-Host "  - KB is not applicable to this Windows version"
        Write-Host "  - KB has not yet been offered by Windows Update"
        Write-Host "  - KB was superseded by another update"
    }

    exit 0
}

Write-Host "Updates selected: $($UpdatesToInstall.Count)" `
    -ForegroundColor Green

# ------------------------------------------------------------
# 9. Download
# ------------------------------------------------------------

Write-Host ""
Write-Host "[5] Downloading updates..." -ForegroundColor Yellow

$Downloader = $Session.CreateUpdateDownloader()

$Downloader.Updates = $UpdatesToInstall

$DownloadResult = $Downloader.Download()

Write-Host ""
Write-Host "Download result code: $($DownloadResult.ResultCode)"

# ResultCode:
# 0 = NotStarted
# 1 = InProgress
# 2 = Succeeded
# 3 = SucceededWithErrors
# 4 = Failed
# 5 = Aborted

if (($DownloadResult.ResultCode -ne 2) -and
    ($DownloadResult.ResultCode -ne 3)) {

    Write-Host ""
    Write-Host "DOWNLOAD FAILED." -ForegroundColor Red

    for ($i = 0; $i -lt $UpdatesToInstall.Count; $i++) {

        $u = $UpdatesToInstall.Item($i)

        Write-Host ""
        Write-Host "Update: $($u.Title)"
        Write-Host "Downloaded: $($u.IsDownloaded)"
    }

    exit 1
}

# ------------------------------------------------------------
# 10. Verify downloaded updates
# ------------------------------------------------------------

$InstallCollection = New-Object -ComObject Microsoft.Update.UpdateColl

Write-Host ""
Write-Host "Downloaded updates:" -ForegroundColor Cyan

for ($i = 0; $i -lt $UpdatesToInstall.Count; $i++) {

    $u = $UpdatesToInstall.Item($i)

    $KBs = @(
        $u.KBArticleIDs |
        ForEach-Object { "KB$_" }
    )

    $KBText = if ($KBs.Count) {
        $KBs -join ", "
    }
    else {
        "(no KB)"
    }

    Write-Host ""
    Write-Host "$KBText"
    Write-Host "$($u.Title)"
    Write-Host "Downloaded: $($u.IsDownloaded)"

    if ($u.IsDownloaded) {
        [void]$InstallCollection.Add($u)
    }
}

if ($InstallCollection.Count -eq 0) {

    Write-Host ""
    Write-Host "No downloaded updates available for installation." `
        -ForegroundColor Red

    exit 1
}

# ------------------------------------------------------------
# 11. Install
# ------------------------------------------------------------

Write-Host ""
Write-Host "[6] Installing updates..." -ForegroundColor Yellow
Write-Host "    Do not close this console."
Write-Host ""

$Installer = $Session.CreateUpdateInstaller()

$Installer.Updates = $InstallCollection

$InstallResult = $Installer.Install()

# ------------------------------------------------------------
# 12. Installation results
# ------------------------------------------------------------

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " INSTALLATION RESULTS" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

for ($i = 0; $i -lt $InstallCollection.Count; $i++) {

    $u = $InstallCollection.Item($i)

    $Result = $InstallResult.GetUpdateResult($i)

    $KBs = @(
        $u.KBArticleIDs |
        ForEach-Object { "KB$_" }
    )

    $KBText = if ($KBs.Count) {
        $KBs -join ", "
    }
    else {
        "(no KB)"
    }

    Write-Host ""
    Write-Host "KB: $KBText"
    Write-Host "Title: $($u.Title)"
    Write-Host "Result code: $($Result.ResultCode)"
    Write-Host "HResult: $($Result.HResult)"

    switch ($Result.ResultCode) {

        0 {
            Write-Host "STATUS: Not started" -ForegroundColor Yellow
        }

        1 {
            Write-Host "STATUS: In progress" -ForegroundColor Yellow
        }

        2 {
            Write-Host "STATUS: SUCCESS" -ForegroundColor Green
        }

        3 {
            Write-Host "STATUS: SUCCESS WITH ERRORS" -ForegroundColor Yellow
        }

        4 {
            Write-Host "STATUS: FAILED" -ForegroundColor Red
        }

        5 {
            Write-Host "STATUS: ABORTED" -ForegroundColor Red
        }

        default {
            Write-Host "STATUS: UNKNOWN" -ForegroundColor Yellow
        }
    }
}

# ------------------------------------------------------------
# 13. Reboot requirement
# ------------------------------------------------------------

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan

if ($InstallResult.RebootRequired) {

    Write-Host "REBOOT REQUIRED: YES" -ForegroundColor Yellow

}
else {

    Write-Host "REBOOT REQUIRED: NO" -ForegroundColor Green
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 14. Final result
# ------------------------------------------------------------

$SuccessCount = 0
$FailedCount = 0

for ($i = 0; $i -lt $InstallCollection.Count; $i++) {

    $Result = $InstallResult.GetUpdateResult($i)

    if ($Result.ResultCode -eq 2) {
        $SuccessCount++
    }
    else {
        $FailedCount++
    }
}

Write-Host "Successful: $SuccessCount" -ForegroundColor Green
Write-Host "Failed:     $FailedCount" -ForegroundColor Red

if ($InstallResult.RebootRequired) {
    Write-Host ""
    Write-Host "Windows requires a reboot." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Finished."