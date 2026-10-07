#requires -version 5.1
<#
.SYNOPSIS
    Installs all applicable Windows software updates.
    Works in Administrator and SYSTEM context.

.NOTES
    Save as: Install-WindowsUpdates.ps1
#>

$ErrorActionPreference = 'Stop'

# ---------------- CONFIG ----------------
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$LogFile = Join-Path $ScriptDir 'WindowsUpdateInstall.log'
$StateFile = Join-Path $ScriptDir 'WindowsUpdateInstall.state.json'
$TaskName = 'Install-WindowsUpdates-Continue'
$MaxCycles = 10

# ---------------- HELPERS ----------------
function Write-Log {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    Write-Host $line -ForegroundColor $Color
}

function Is-System {
    return ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)
}

function Get-PendingReboot {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { return $true }
    }

    try {
        $v = Get-ItemProperty `
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
            -Name PendingFileRenameOperations `
            -ErrorAction SilentlyContinue

        if ($null -ne $v.PendingFileRenameOperations) {
            return $true
        }
    } catch {}

    return $false
}

function Ensure-ServiceRunning {
    param([string]$Name)

    $svc = Get-Service -Name $Name -ErrorAction Stop

    if ($svc.Status -ne 'Running') {
        Write-Log "Starting service: $Name ..." Yellow
        Start-Service -Name $Name -ErrorAction Stop
        $svc.WaitForStatus('Running', '00:00:30')
    }

    Write-Log "$Name : $((Get-Service $Name).Status)" Green
}

function Show-UpdateServices {
    try {
        Write-Log "Checking Windows Update service configuration..."

        $sm = New-Object -ComObject Microsoft.Update.ServiceManager
        $services = @($sm.Services)

        foreach ($s in $services) {
            Write-Log ("Update service: {0} | Managed={1} | DefaultAU={2} | RegisteredAU={3}" -f `
                $s.Name, $s.IsManaged, $s.IsDefaultAUService, $s.IsRegisteredWithAU)
        }
    }
    catch {
        Write-Log "Could not enumerate Update services: $($_.Exception.Message)" Yellow
    }
}

function Show-UpdatePolicies {
    $paths = @(
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    )

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Write-Log "Policy key exists: $p" Yellow
            try {
                $props = Get-ItemProperty $p
                foreach ($prop in $props.PSObject.Properties) {
                    if ($prop.Name -notmatch '^PS') {
                        Write-Log "  $($prop.Name) = $($prop.Value)"
                    }
                }
            } catch {}
        }
    }
}

function Create-ContinuationTask {
    param([string]$ScriptPath)

    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name

        $action = New-ScheduledTaskAction `
            -Execute 'PowerShell.exe' `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

        $trigger = New-ScheduledTaskTrigger -AtStartup

        $principal = New-ScheduledTaskPrincipal `
            -UserId 'SYSTEM' `
            -LogonType ServiceAccount `
            -RunLevel Highest

        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable

        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings `
            -Force | Out-Null

        Write-Log "Continuation task created: $TaskName" Green
        return $true
    }
    catch {
        Write-Log "Failed to create continuation task: $($_.Exception.Message)" Red
        return $false
    }
}

function Remove-ContinuationTask {
    try {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Log "Continuation task removed." Green
        }
    } catch {
        Write-Log "Could not remove continuation task: $($_.Exception.Message)" Yellow
    }
}

function Search-Updates {
    Write-Log "[SEARCH] Creating Windows Update API session..." Cyan

    $session = New-Object -ComObject Microsoft.Update.Session
    $session.ClientApplicationID = 'Install-All-Windows-Updates'

    $searcher = $session.CreateUpdateSearcher()

    Write-Log "[SEARCH] Searching for applicable software updates..." Yellow
    Write-Log "[SEARCH] This can take several minutes..." Yellow

    $result = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")

    Write-Log "[SEARCH] Search completed. Updates found: $($result.Updates.Count)" Green

    return @{
        Session = $session
        SearchResult = $result
    }
}

function Install-Updates {
    param(
        $Session,
        $Updates
    )

    if ($Updates.Count -eq 0) {
        return @{
            Installed = 0
            Failed = 0
            RebootRequired = $false
        }
    }

    Write-Log "Preparing update collection..." Cyan

    $collection = New-Object -ComObject Microsoft.Update.UpdateColl

    for ($i = 0; $i -lt $Updates.Count; $i++) {
        $u = $Updates.Item($i)

        $title = $u.Title

        if (-not $u.EulaAccepted) {
            try {
                $u.AcceptEula()
            } catch {}
        }

        [void]$collection.Add($u)

        Write-Log ("  [{0}/{1}] {2}" -f ($i + 1), $Updates.Count, $title)
    }

    Write-Log "Downloading $($collection.Count) update(s)..." Cyan

    $downloader = $Session.CreateUpdateDownloader()
    $downloader.Updates = $collection

    $downloadResult = $downloader.Download()

    Write-Log "Download result code: $($downloadResult.ResultCode)" Green

    # Rebuild collection with downloaded updates only
    $installCollection = New-Object -ComObject Microsoft.Update.UpdateColl

    for ($i = 0; $i -lt $collection.Count; $i++) {
        $u = $collection.Item($i)

        if ($u.IsDownloaded) {
            [void]$installCollection.Add($u)
        }
        else {
            Write-Log "NOT downloaded: $($u.Title)" Red
        }
    }

    if ($installCollection.Count -eq 0) {
        Write-Log "No downloaded updates are available for installation." Red
        return @{
            Installed = 0
            Failed = $collection.Count
            RebootRequired = $false
        }
    }

    Write-Log "Installing $($installCollection.Count) update(s)..." Cyan

    $installer = $Session.CreateUpdateInstaller()
    $installer.Updates = $installCollection

    $installResult = $installer.Install()

    $installed = 0
    $failed = 0

    for ($i = 0; $i -lt $installCollection.Count; $i++) {
        $u = $installCollection.Item($i)
        $r = $installResult.GetUpdateResult($i)

        $title = $u.Title
        $code = $r.ResultCode
        $hr = $r.HResult

        if ($code -eq 2 -or $code -eq 3) {
            $installed++
            Write-Log "INSTALLED: $title | Result=$code | HResult=$hr" Green
        }
        else {
            $failed++
            Write-Log "FAILED: $title | Result=$code | HResult=$hr" Red
        }
    }

    return @{
        Installed = $installed
        Failed = $failed
        RebootRequired = [bool]$installResult.RebootRequired
    }
}

# ---------------- START ----------------

New-Item -ItemType File -Path $LogFile -Force | Out-Null

Write-Log "============================================================" Cyan
Write-Log " WINDOWS UPDATE - INSTALL ALL AVAILABLE UPDATES" Cyan
Write-Log "============================================================" Cyan

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isSystem = $identity.IsSystem

Write-Log "User: $($identity.Name)"

if ($isSystem) {
    Write-Log "Context: SYSTEM" Green
}
else {
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "WARNING: Script is not running elevated." Yellow
        Write-Log "Please run PowerShell as Administrator." Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-Log "Context: Administrator" Green
}

try {
    # Services
    Write-Log "[1] Checking Windows Update services..." Cyan

    Ensure-ServiceRunning 'wuauserv'
    Ensure-ServiceRunning 'bits'
    Ensure-ServiceRunning 'cryptsvc'

    # Diagnostics
    Write-Log "[2] Checking update sources and policies..." Cyan
    Show-UpdateServices
    Show-UpdatePolicies

    # Pending reboot before searching
    if (Get-PendingReboot) {
        Write-Log "A pending reboot was detected." Yellow

        if ($ScriptDir) {
            Create-ContinuationTask -ScriptPath $PSCommandPath | Out-Null
        }

        Write-Log "Restarting Windows in 30 seconds..." Yellow
        shutdown.exe /r /t 30 /c "Windows Update installation requires a restart."
        exit 0
    }

    # Update cycles
    for ($cycle = 1; $cycle -le $MaxCycles; $cycle++) {

        Write-Log "============================================================" Cyan
        Write-Log " UPDATE CYCLE $cycle / $MaxCycles" Cyan
        Write-Log "============================================================" Cyan

        $data = Search-Updates

        $updates = $data.SearchResult.Updates

        if ($updates.Count -eq 0) {
            Write-Log "Windows Update reports: 0 applicable updates." Green

            Remove-ContinuationTask

            Write-Log "============================================================" Green
            Write-Log " ALL AVAILABLE UPDATES ARE INSTALLED" Green
            Write-Log "============================================================" Green
            break
        }

        $result = Install-Updates `
            -Session $data.Session `
            -Updates $updates

        Write-Log "Cycle result: Installed=$($result.Installed), Failed=$($result.Failed), RebootRequired=$($result.RebootRequired)"

        if ($result.Failed -gt 0) {
            Write-Log "One or more updates failed. See the log for details." Red
        }

        if ($result.RebootRequired -or (Get-PendingReboot)) {
            Write-Log "A reboot is required." Yellow

            $created = Create-ContinuationTask -ScriptPath $PSCommandPath

            if ($created) {
                Write-Log "Windows will continue update installation after reboot." Green
                Write-Log "Restarting Windows in 30 seconds..." Yellow
                shutdown.exe /r /t 30 /c "Continuing Windows Update installation."
                exit 0
            }
            else {
                Write-Log "Could not create continuation task. Reboot manually and run the script again." Red
                break
            }
        }

        if ($result.Installed -eq 0) {
            Write-Log "No update was installed in this cycle. Stopping to avoid an endless loop." Yellow
            break
        }

        Start-Sleep -Seconds 5
    }
}
catch {
    Write-Log "============================================================" Red
    Write-Log "ERROR" Red
    Write-Log $_.Exception.ToString() Red
    Write-Log "============================================================" Red
}
finally {
    Write-Log "Script finished." Cyan

    if (-not $isSystem) {
        Write-Host ""
        Read-Host "Press Enter to close"
    }
}
