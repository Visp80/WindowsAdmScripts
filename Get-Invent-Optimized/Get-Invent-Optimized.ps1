<#
.SYNOPSIS
    Advanced hardware inventory collection via CIM for local and remote computers
    
.DESCRIPTION
    Collects comprehensive hardware and system information from Windows computers using CIM.
    Supports remote computers, credentials, multiple export formats, and detailed reporting.
    
.PARAMETER ComputerName
    Name of the computer to inventory. Defaults to local computer.
    Supports multiple computers via pipeline or array.
    
.PARAMETER Credential
    PSCredential object for authentication to remote computers.
    
.PARAMETER Full
    Provides detailed information about all hardware components.
    
.PARAMETER ExportPath
    Path to export results. Supports CSV, JSON, HTML formats based on file extension.
    
.PARAMETER Timeout
    Connection timeout in seconds. Default is 30 seconds.
    
.EXAMPLE
    .\Get-Invent-Optimized.ps1
    Collects inventory from local computer
    
.EXAMPLE
    .\Get-Invent-Optimized.ps1 -ComputerName SERVER01 -Full
    Collects detailed inventory from remote server
    
.EXAMPLE
    .\Get-Invent-Optimized.ps1 -ComputerName SERVER01 -Credential (Get-Credential) -ExportPath "C:\inventory.html"
    Collects inventory with credentials and exports to HTML
    
.EXAMPLE
    "SERVER01","SERVER02" | .\Get-Invent-Optimized.ps1 -Full
    Collects inventory from multiple servers via pipeline
    
.NOTES
    Author: Optimized version based on Get-Invent
    Version: 2.0
    Requires: PowerShell 5.1 or higher
    
.LINK
    https://github.com/Lifailon/Get-Invent
#>

[CmdletBinding()]
Param (
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias("CN", "Server", "Name")]
    [string[]]$ComputerName = $env:COMPUTERNAME,
    
    [Parameter()]
    [PSCredential]$Credential,
    
    [Parameter()]
    [switch]$Full,
    
    [Parameter()]
    [ValidateScript({
        $extension = [System.IO.Path]::GetExtension($_)
        if ($extension -notin @('.csv', '.json', '.html', '.xml')) {
            throw "Supported formats: .csv, .json, .html, .xml"
        }
        $true
    })]
    [string]$ExportPath,
    
    [Parameter()]
    [int]$Timeout = 30
)

Begin {
    # Initialize result collection
    $AllResults = [System.Collections.Generic.List[PSObject]]::new()
    $AllDetailsResults = @{
        Memory = [System.Collections.Generic.List[PSObject]]::new()
        PhysicalDisks = [System.Collections.Generic.List[PSObject]]::new()
        LogicalDisks = [System.Collections.Generic.List[PSObject]]::new()
        VideoCards = [System.Collections.Generic.List[PSObject]]::new()
        NetworkAdapters = [System.Collections.Generic.List[PSObject]]::new()
    }
    
    # Function to format bytes
    function Format-Bytes {
        param([double]$Bytes, [int]$Precision = 2)
        
        if ($Bytes -eq 0) { return "0 B" }
        
        $sizes = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
        $order = [Math]::Floor([Math]::Log($Bytes, 1024))
        $size = [Math]::Round($Bytes / [Math]::Pow(1024, $order), $Precision)
        
        return "$size $($sizes[$order])"
    }
    
    # Function to create CIM session with error handling
    function New-SafeCimSession {
        param(
            [string]$Computer,
            [PSCredential]$Cred,
            [int]$TimeoutSec
        )
        
        try {
            $sessionOption = New-CimSessionOption -Protocol Dcom
            $sessionParams = @{
                ComputerName = $Computer
                OperationTimeoutSec = $TimeoutSec
                SessionOption = $sessionOption
                ErrorAction = 'Stop'
            }
            
            if ($Cred) {
                $sessionParams['Credential'] = $Cred
            }
            
            $session = New-CimSession @sessionParams
            return $session
        }
        catch {
            Write-Error "Failed to create CIM session to $Computer : $_"
            return $null
        }
    }
    
    # Function to get inventory
    function Get-ComputerInventory {
        param(
            [string]$Computer,
            [Microsoft.Management.Infrastructure.CimSession]$CimSession
        )
        
        try {
            Write-Verbose "Collecting data from $Computer..."
            
            # Progress tracking
            $progressParams = @{
                Activity = "Collecting inventory from $Computer"
                Id = 1
            }
            
            # Computer System
            Write-Progress @progressParams -Status "Computer System" -PercentComplete 10
            $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -CimSession $CimSession -ErrorAction Stop
            
            # Operating System
            Write-Progress @progressParams -Status "Operating System" -PercentComplete 20
            $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $CimSession -ErrorAction Stop
            
            # BIOS
            Write-Progress @progressParams -Status "BIOS" -PercentComplete 25
            $bios = Get-CimInstance -ClassName Win32_BIOS -CimSession $CimSession -ErrorAction Stop
            
            # BaseBoard
            Write-Progress @progressParams -Status "Motherboard" -PercentComplete 30
            $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard -CimSession $CimSession -ErrorAction Stop
            
            # Processor
            Write-Progress @progressParams -Status "Processor" -PercentComplete 40
            $processors = Get-CimInstance -ClassName Win32_Processor -CimSession $CimSession -ErrorAction Stop
            
            # Memory
            Write-Progress @progressParams -Status "Memory" -PercentComplete 50
            $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -CimSession $CimSession -ErrorAction Stop
            
            # Physical Disks
            Write-Progress @progressParams -Status "Physical Disks" -PercentComplete 60
            $physicalDisks = Get-CimInstance -ClassName Win32_DiskDrive -CimSession $CimSession -ErrorAction Stop
            
            # Logical Disks
            Write-Progress @progressParams -Status "Logical Disks" -PercentComplete 70
            $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk -CimSession $CimSession -ErrorAction Stop | 
                Where-Object { $_.Size -ne $null }
            
            # Video Controllers
            Write-Progress @progressParams -Status "Video Cards" -PercentComplete 80
            $videoControllers = Get-CimInstance -ClassName Win32_VideoController -CimSession $CimSession -ErrorAction Stop
            
            # Network Adapters
            Write-Progress @progressParams -Status "Network Adapters" -PercentComplete 90
            $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter -CimSession $CimSession -ErrorAction Stop | 
                Where-Object { $_.MACAddress -ne $null }
            
            Write-Progress @progressParams -Completed
            
            # Calculate totals
            $totalMemoryMB = ($memory | Measure-Object -Property Capacity -Sum).Sum / 1MB
            $totalPhysicalDiskGB = ($physicalDisks | Measure-Object -Property Size -Sum).Sum / 1GB
            $totalLogicalDiskGB = ($logicalDisks | Measure-Object -Property Size -Sum).Sum / 1GB
            $totalVideoRAMGB = ($videoControllers | Measure-Object -Property AdapterRAM -Sum).Sum / 1GB
            
            # CPU information
            $cpuInfo = $processors | Select-Object -First 1
            $totalCores = ($processors | Measure-Object -Property NumberOfCores -Sum).Sum
            $totalThreads = ($processors | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
            
            # Motherboard info
            $motherboardInfo = "{0} {1} {2}" -f $baseBoard.Manufacturer, $baseBoard.Product, $baseBoard.Version
            
            # Uptime calculation
            $uptime = (Get-Date) - $operatingSystem.LastBootUpTime
            $uptimeFormatted = "{0} days, {1} hours, {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
            
            # Create summary object
            $summaryObject = [PSCustomObject]@{
                ComputerName = $computerSystem.Name
                Domain = $computerSystem.Domain
                Owner = $computerSystem.PrimaryOwnerName
                Manufacturer = $computerSystem.Manufacturer
                Model = $computerSystem.Model
                SerialNumber = $bios.SerialNumber
                OperatingSystem = $operatingSystem.Caption
                OSVersion = $operatingSystem.Version
                OSArchitecture = $operatingSystem.OSArchitecture
                InstallDate = $operatingSystem.InstallDate
                LastBootUpTime = $operatingSystem.LastBootUpTime
                Uptime = $uptimeFormatted
                SystemType = $computerSystem.SystemType
                Motherboard = $motherboardInfo
                BIOSVersion = $bios.SMBIOSBIOSVersion
                BIOSDate = $bios.ReleaseDate
                ProcessorName = $cpuInfo.Name
                ProcessorCount = $processors.Count
                TotalCores = $totalCores
                TotalThreads = $totalThreads
                MaxClockSpeed = "{0} MHz" -f $cpuInfo.MaxClockSpeed
                TotalMemoryMB = [Math]::Round($totalMemoryMB, 2)
                TotalMemoryGB = [Math]::Round($totalMemoryMB / 1024, 2)
                MemorySlots = $memory.Count
                PhysicalDiskCount = $physicalDisks.Count
                TotalPhysicalDiskGB = [Math]::Round($totalPhysicalDiskGB, 2)
                LogicalDiskCount = $logicalDisks.Count
                TotalLogicalDiskGB = [Math]::Round($totalLogicalDiskGB, 2)
                VideoCardCount = $videoControllers.Count
                TotalVideoRAMGB = [Math]::Round($totalVideoRAMGB, 2)
                NetworkAdapterCount = $networkAdapters.Count
                CollectionDate = Get-Date
            }
            
            # Collect detailed information if requested
            if ($Full) {
                # Memory Details
                foreach ($mem in $memory) {
                    $memObject = [PSCustomObject]@{
                        ComputerName = $Computer
                        Manufacturer = $mem.Manufacturer
                        PartNumber = $mem.PartNumber
                        SerialNumber = $mem.SerialNumber
                        Capacity = Format-Bytes -Bytes $mem.Capacity
                        Speed = "{0} MHz" -f $mem.ConfiguredClockSpeed
                        FormFactor = switch ($mem.FormFactor) {
                            8 { "DIMM" }
                            12 { "SODIMM" }
                            default { "Unknown" }
                        }
                        MemoryType = switch ($mem.MemoryType) {
                            20 { "DDR" }
                            21 { "DDR2" }
                            24 { "DDR3" }
                            26 { "DDR4" }
                            34 { "DDR5" }
                            default { "Unknown" }
                        }
                        DeviceLocator = $mem.DeviceLocator
                    }
                    $AllDetailsResults.Memory.Add($memObject)
                }
                
                # Physical Disk Details
                foreach ($disk in $physicalDisks) {
                    $diskObject = [PSCustomObject]@{
                        ComputerName = $Computer
                        Model = $disk.Model
                        SerialNumber = $disk.SerialNumber
                        Size = Format-Bytes -Bytes $disk.Size
                        InterfaceType = $disk.InterfaceType
                        MediaType = $disk.MediaType
                        Partitions = $disk.Partitions
                        Status = $disk.Status
                    }
                    $AllDetailsResults.PhysicalDisks.Add($diskObject)
                }
                
                # Logical Disk Details
                foreach ($disk in $logicalDisks) {
                    $freePercent = [Math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
                    $diskObject = [PSCustomObject]@{
                        ComputerName = $Computer
                        DeviceID = $disk.DeviceID
                        VolumeName = $disk.VolumeName
                        FileSystem = $disk.FileSystem
                        TotalSize = Format-Bytes -Bytes $disk.Size
                        FreeSpace = Format-Bytes -Bytes $disk.FreeSpace
                        UsedSpace = Format-Bytes -Bytes ($disk.Size - $disk.FreeSpace)
                        FreePercent = "{0}%" -f $freePercent
                        DriveType = switch ($disk.DriveType) {
                            2 { "Removable" }
                            3 { "Local Disk" }
                            4 { "Network" }
                            5 { "CD-ROM" }
                            default { "Unknown" }
                        }
                    }
                    $AllDetailsResults.LogicalDisks.Add($diskObject)
                }
                
                # Video Card Details
                foreach ($video in $videoControllers) {
                    $videoObject = [PSCustomObject]@{
                        ComputerName = $Computer
                        Name = $video.Name
                        VideoProcessor = $video.VideoProcessor
                        AdapterRAM = Format-Bytes -Bytes $video.AdapterRAM
                        CurrentResolution = "{0}x{1}" -f $video.CurrentHorizontalResolution, $video.CurrentVerticalResolution
                        RefreshRate = "{0} Hz" -f $video.CurrentRefreshRate
                        DriverVersion = $video.DriverVersion
                        DriverDate = $video.DriverDate
                        Status = $video.Status
                    }
                    $AllDetailsResults.VideoCards.Add($videoObject)
                }
                
                # Network Adapter Details
                foreach ($adapter in $networkAdapters) {
                    $adapterObject = [PSCustomObject]@{
                        ComputerName = $Computer
                        Name = $adapter.Name
                        Manufacturer = $adapter.Manufacturer
                        MACAddress = $adapter.MACAddress
                        Speed = if ($adapter.Speed) { Format-Bytes -Bytes $adapter.Speed } else { "N/A" }
                        AdapterType = $adapter.AdapterType
                        NetConnectionStatus = switch ($adapter.NetConnectionStatus) {
                            0 { "Disconnected" }
                            1 { "Connecting" }
                            2 { "Connected" }
                            3 { "Disconnecting" }
                            4 { "Hardware not present" }
                            5 { "Hardware disabled" }
                            6 { "Hardware malfunction" }
                            7 { "Media disconnected" }
                            default { "Unknown" }
                        }
                    }
                    $AllDetailsResults.NetworkAdapters.Add($adapterObject)
                }
            }
            
            return $summaryObject
            
        }
        catch {
            Write-Error "Error collecting inventory from ${Computer}: $_"
            return $null
        }
    }
    
    # Function to export results
    function Export-InventoryResults {
        param(
            [object]$Data,
            [string]$Path
        )
        
        $extension = [System.IO.Path]::GetExtension($Path).ToLower()
        
        try {
            switch ($extension) {
                '.csv' {
                    $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
                    Write-Host "Results exported to CSV: $Path" -ForegroundColor Green
                }
                '.json' {
                    $Data | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Encoding UTF8
                    Write-Host "Results exported to JSON: $Path" -ForegroundColor Green
                }
                '.xml' {
                    $Data | Export-Clixml -Path $Path -Encoding UTF8
                    Write-Host "Results exported to XML: $Path" -ForegroundColor Green
                }
                '.html' {
                    $html = $Data | ConvertTo-Html -Title "Hardware Inventory Report" -PreContent "<h1>Hardware Inventory Report</h1><p>Generated: $(Get-Date)</p>" |
                        Out-String
                    
                    # Add CSS styling
                    $css = @"
<style>
body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
table { border-collapse: collapse; width: 100%; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
th { background-color: #3498db; color: white; padding: 12px; text-align: left; }
td { padding: 10px; border-bottom: 1px solid #ddd; }
tr:hover { background-color: #f0f0f0; }
p { color: #7f8c8d; }
</style>
"@
                    $html = $html -replace '<head>', "<head>$css"
                    $html | Out-File -FilePath $Path -Encoding UTF8
                    Write-Host "Results exported to HTML: $Path" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Error "Failed to export results: $_"
        }
    }
}

Process {
    foreach ($computer in $ComputerName) {
        Write-Host "`nProcessing: $computer" -ForegroundColor Cyan
        
        # Create CIM session
        $cimSession = New-SafeCimSession -Computer $computer -Cred $Credential -TimeoutSec $Timeout
        
        if ($cimSession) {
            try {
                # Get inventory
                $inventory = Get-ComputerInventory -Computer $computer -CimSession $cimSession
                
                if ($inventory) {
                    $AllResults.Add($inventory)
                    Write-Host "✓ Successfully collected inventory from $computer" -ForegroundColor Green
                }
            }
            finally {
                # Clean up session
                Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
            }
        }
        else {
            Write-Warning "Skipping $computer due to connection failure"
        }
    }
}

End {
    # Display results
    if ($AllResults.Count -gt 0) {
        Write-Host "`n========== INVENTORY SUMMARY ==========" -ForegroundColor Yellow
        $AllResults | Format-List
        
        if ($Full) {
            Write-Host "`n========== DETAILED INFORMATION ==========" -ForegroundColor Yellow
            
            if ($AllDetailsResults.Memory.Count -gt 0) {
                Write-Host "`n--- Memory Modules ---" -ForegroundColor Cyan
                $AllDetailsResults.Memory | Format-Table -AutoSize
            }
            
            if ($AllDetailsResults.PhysicalDisks.Count -gt 0) {
                Write-Host "`n--- Physical Disks ---" -ForegroundColor Cyan
                $AllDetailsResults.PhysicalDisks | Format-Table -AutoSize
            }
            
            if ($AllDetailsResults.LogicalDisks.Count -gt 0) {
                Write-Host "`n--- Logical Disks ---" -ForegroundColor Cyan
                $AllDetailsResults.LogicalDisks | Format-Table -AutoSize
            }
            
            if ($AllDetailsResults.VideoCards.Count -gt 0) {
                Write-Host "`n--- Video Cards ---" -ForegroundColor Cyan
                $AllDetailsResults.VideoCards | Format-Table -AutoSize
            }
            
            if ($AllDetailsResults.NetworkAdapters.Count -gt 0) {
                Write-Host "`n--- Network Adapters ---" -ForegroundColor Cyan
                $AllDetailsResults.NetworkAdapters | Format-Table -AutoSize
            }
        }
        
        # Export if path specified
        if ($ExportPath) {
            if ($Full) {
                # Export all data including details
                $exportData = @{
                    Summary = $AllResults
                    Details = $AllDetailsResults
                }
                Export-InventoryResults -Data $exportData -Path $ExportPath
            }
            else {
                Export-InventoryResults -Data $AllResults -Path $ExportPath
            }
        }
        
        # Return results
        Write-Output $AllResults
    }
    else {
        Write-Warning "No inventory data collected"
    }
}
