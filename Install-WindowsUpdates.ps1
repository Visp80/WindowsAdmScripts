#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$LogFile = "C:\Windows\Temp\WindowsUpdate-System.log"

function Log {
    param(
        [string]$Message,
        [string]$Color = "Gray"
    )

    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"

    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# ============================================================
# START
# ============================================================

New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force |
    Out-Null

Log "============================================================" Cyan
Log " WINDOWS UPDATE - INSTALL ALL AVAILABLE UPDATES" Cyan
Log "============================================================" Cyan

# ============================================================
# SYSTEM CHECK
# ============================================================

$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name

Log "User: $user"

if ($user -ne "NT AUTHORITY\SYSTEM") {
    Log "WARNING: Script is NOT running as SYSTEM." Yellow
}

# ============================================================
# SERVICES
# ============================================================

Log ""
Log "[1] Checking Windows Update services..." Yellow

$services = @(
    "wuauserv",
    "bits",
    "cryptsvc"
)

foreach ($name in $services) {

    try {

        $svc = Get-Service -Name $name -ErrorAction Stop

        Log "$name : $($svc.Status)"

        if ($svc.Status -ne "Running") {

            Log "Starting $name..." Yellow

            Start-Service -Name $name -ErrorAction Stop

            # Wait max 60 sec
            $timeout = 60

            while ((Get-Service $name).Status -ne "Running" -and $timeout -gt 0) {

                Start-Sleep -Seconds 1
                $timeout--
            }

            if ((Get-Service $name).Status -eq "Running") {
                Log "$name started." Green
            }
            else {
                throw "$name did not start within 60 seconds."
            }
        }

    }
    catch {

        Log "ERROR starting $name : $($_.Exception.Message)" Red
        exit 1
    }
}

# ============================================================
# WINDOWS UPDATE API
# ============================================================

Log ""
Log "[2] Creating Windows Update API session..." Yellow

try {

    $Session = New-Object -ComObject Microsoft.Update.Session

    $Session.ClientApplicationID =
        "SYSTEM - Install All Windows Updates"

    $Searcher = $Session.CreateUpdateSearcher()

}
catch {

    Log "ERROR creating Windows Update session:" Red
    Log $_.Exception.Message Red
    exit 1
}

# ============================================================
# SEARCH
# ============================================================

Log ""
Log "[3] Searching for ALL applicable updates..." Yellow
Log "This may take several minutes..." Yellow

try {

    $SearchResult = $Searcher.Search(
        "IsInstalled=0 and IsHidden=0 and Type='Software'"
    )

}
catch {

    Log "ERROR during Windows Update search:" Red
    Log $_.Exception.Message Red

    exit 1
}

$count = $SearchResult.Updates.Count

Log ""
Log "Updates found: $count" Green

if ($count -eq 0) {

    Log "Windows reports that there are no applicable updates." Green
    Log "Finished."

    exit 0
}

# ============================================================
# DISPLAY UPDATES
# ============================================================

Log ""
Log "AVAILABLE UPDATES:" Cyan
Log "------------------------------------------------------------"

$Updates = New-Object -ComObject Microsoft.Update.UpdateColl

for ($i = 0; $i -lt $count; $i++) {

    $Update = $SearchResult.Updates.Item($i)

    $KBs = @(
        $Update.KBArticleIDs |
        ForEach-Object { "KB$_" }
    )

    if ($KBs.Count -gt 0) {
        $KBText = $KBs -join ", "
    }
    else {
        $KBText = "(no KB)"
    }

    $sizeMB = [math]::Round(
        $Update.MaxDownloadSize / 1MB,
        2
    )

    Log "[$($i + 1)/$count] $KBText" White
    Log "    $($Update.Title)"
    Log "    Size: $sizeMB MB"

    # Accept EULA
    if (-not $Update.EulaAccepted) {

        try {
            $Update.AcceptEula()
            Log "    EULA accepted."
        }
        catch {
            Log "    WARNING: Cannot accept EULA." Yellow
        }
    }

    [void]$Updates.Add($Update)
}

# ============================================================
# DOWNLOAD
# ============================================================

Log ""
Log "[4] DOWNLOADING $($Updates.Count) updates..." Yellow
Log "Please wait..." Yellow

try {

    $Downloader = $Session.CreateUpdateDownloader()

    $Downloader.Updates = $Updates

    $DownloadResult = $Downloader.Download()

}
catch {

    Log "DOWNLOAD ERROR:" Red
    Log $_.Exception.Message Red

    exit 1
}

Log ""
Log "Download ResultCode: $($DownloadResult.ResultCode)"

# ============================================================
# CHECK DOWNLOAD
# ============================================================

$DownloadedUpdates =
    New-Object -ComObject Microsoft.Update.UpdateColl

for ($i = 0; $i -lt $Updates.Count; $i++) {

    $Update = $Updates.Item($i)

    $KBs = @(
        $Update.KBArticleIDs |
        ForEach-Object { "KB$_" }
    )

    $KBText = if ($KBs.Count) {
        $KBs -join ", "
    }
    else {
        "(no KB)"
    }

    if ($Update.IsDownloaded) {

        Log "DOWNLOADED: $KBText" Green

        [void]$DownloadedUpdates.Add($Update)

    }
    else {

        Log "NOT DOWNLOADED: $KBText" Red
    }
}

if ($DownloadedUpdates.Count -eq 0) {

    Log "No updates were downloaded." Red
    exit 1
}

# ============================================================
# INSTALL
# ============================================================

Log ""
Log "[5] INSTALLING $($DownloadedUpdates.Count) updates..." Yellow
Log "This may take a long time." Yellow
Log ""

try {

    $Installer = $Session.CreateUpdateInstaller()

    $Installer.Updates = $DownloadedUpdates

    $InstallResult = $Installer.Install()

}
catch {

    Log "INSTALLATION ERROR:" Red
    Log $_.Exception.Message Red

    exit 1
}

# ============================================================
# RESULTS
# ============================================================

Log ""
Log "============================================================" Cyan
Log " INSTALLATION RESULTS" Cyan
Log "============================================================" Cyan

$Success = 0
$Failed = 0

for ($i = 0; $i -lt $DownloadedUpdates.Count; $i++) {

    $Update = $DownloadedUpdates.Item($i)

    $Result = $InstallResult.GetUpdateResult($i)

    $KBs = @(
        $Update.KBArticleIDs |
        ForEach-Object { "KB$_" }
    )

    $KBText = if ($KBs.Count) {
        $KBs -join ", "
    }
    else {
        "(no KB)"
    }

    Log ""
    Log "$KBText"
    Log "$($Update.Title)"

    Log "ResultCode: $($Result.ResultCode)"
    Log "HResult:    $($Result.HResult)"

    switch ($Result.ResultCode) {

        0 {
            Log "STATUS: NOT STARTED" Yellow
            $Failed++
        }

        1 {
            Log "STATUS: IN PROGRESS" Yellow
        }

        2 {
            Log "STATUS: SUCCESS" Green
            $Success++
        }

        3 {
            Log "STATUS: SUCCESS WITH ERRORS" Yellow
            $Failed++
        }

        4 {
            Log "STATUS: FAILED" Red
            $Failed++
        }

        5 {
            Log "STATUS: ABORTED" Red
            $Failed++
        }

        default {
            Log "STATUS: UNKNOWN" Yellow
            $Failed++
        }
    }
}

# ============================================================
# REBOOT
# ============================================================

Log ""
Log "============================================================" Cyan

if ($InstallResult.RebootRequired) {

    Log "REBOOT REQUIRED: YES" Yellow

}
else {

    Log "REBOOT REQUIRED: NO" Green
}

Log "============================================================"

Log ""
Log "Successful: $Success" Green
Log "Failed:     $Failed" Red

Log ""
Log "Log file:"
Log $LogFile

Log ""
Log "Windows Update installation finished."