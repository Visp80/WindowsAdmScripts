<#
.SYNOPSIS
    Advanced hardware inventory collection via CIM for local and remote computers
    
.DESCRIPTION
    Collects comprehensive hardware and system information from Windows computers using CIM.
    Supports remote computers, credentials, multiple export formats, and detailed reporting.
    Optimized for performance and reliability.
    
.PARAMETER ComputerName
    Name of the computer to inventory. Defaults to local computer.
    Supports multiple computers via pipeline or array.
    
.PARAMETER Credential
    PSCredential object for authentication to remote computers.
    
.PARAMETER Protocol
    Protocol to use for CIM connections (DCOM or WSMAN). Default is DCOM.
    
.PARAMETER Full
    Provides detailed information about all hardware components.
    
.PARAMETER ExportPath
    Path to export results. Supports CSV, JSON, HTML, XML formats based on file extension.
    
.PARAMETER Timeout
    Connection timeout in seconds. Default is 30 seconds.
    
.PARAMETER ThrottleLimit
    Maximum number of concurrent connections when querying multiple computers.
    
.PARAMETER IncludeComponents
    Specific components to include (ComputerSystem, OS, BIOS, Processor, Memory, Disk, Network, Video).
    
.PARAMETER ExcludeComponents
    Components to exclude from collection.
    
.EXAMPLE
    .\Get-Invent-Optimized.ps1
    Collects inventory from local computer
    
.EXAMPLE
    .\Get-Invent-Optimized.ps1 -ComputerName SERVER01 -Full -ThrottleLimit 3
    Collects detailed inventory from remote server with concurrency limit
    
.EXAMPLE
    .\Get-Invent-Optimized.ps1 -ComputerName SERVER01,SERVER02 -Protocol WSMAN -ExportPath "C:\inventory.json"
    Collects inventory from multiple servers using WSMAN and exports to JSON
    
.EXAMPLE
    Get-ADComputer -Filter * | Select-Object -ExpandProperty Name | .\Get-Invent-Optimized.ps1 -ThrottleLimit 10
    Collects inventory from all AD computers with high concurrency
    
.NOTES
    Author: Optimized version based on Get-Invent
    Version: 3.0
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
    [ValidateSet('DCOM', 'WSMAN')]
    [string]$Protocol = 'DCOM',
    
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
    [ValidateRange(1, 300)]
    [int]$Timeout = 30,
    
    [Parameter()]
    [ValidateRange(1, 50)]
    [int]$ThrottleLimit = 5,
    
    [Parameter()]
    [ValidateSet('ComputerSystem', 'OS', 'BIOS', 'Processor', 'Memory', 'Disk', 'Network', 'Video')]
    [string[]]$IncludeComponents = @('ComputerSystem', 'OS', 'BIOS', 'Processor', 'Memory', 'Disk', 'Network', 'Video'),
    
    [Parameter()]
    [ValidateSet('ComputerSystem', 'OS', 'BIOS', 'Processor', 'Memory', 'Disk', 'Network', 'Video')]
    [string[]]$ExcludeComponents = @()
)

Begin {
    # Initialize result collections
    $AllResults = New-Object System.Collections.ArrayList
    $AllDetailsResults = @{
        Memory = New-Object System.Collections.ArrayList
        PhysicalDisks = New-Object System.Collections.ArrayList
        LogicalDisks = New-Object System.Collections.ArrayList
        VideoCards = New-Object System.Collections.ArrayList
        NetworkAdapters = New-Object System.Collections.ArrayList
    }
    
    # Performance tracking
    $ScriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Cache for memory type translations
    $MemoryTypeCache = @{
        0 = "Unknown"
        1 = "Other"
        2 = "DRAM"
        3 = "Synchronous DRAM"
        4 = "Cache DRAM"
        5 = "EDO"
        6 = "EDRAM"
        7 = "VRAM"
        8 = "SRAM"
        9 = "RAM"
        10 = "ROM"
        11 = "Flash"
        12 = "EEPROM"
        13 = "FEPROM"
        14 = "EPROM"
        15 = "CDRAM"
        16 = "3DRAM"
        17 = "SDRAM"
        18 = "SGRAM"
        19 = "RDRAM"
        20 = "DDR"
        21 = "DDR2"
        22 = "DDR2 FB-DIMM"
        24 = "DDR3"
        25 = "FBD2"
        26 = "DDR4"
        34 = "DDR5"
    }
    
    # Cache for form factor translations
    $FormFactorCache = @{
        0 = "Unknown"
        1 = "Other"
        2 = "SIP"
        3 = "DIP"
        4 = "ZIP"
        5 = "SOJ"
        6 = "Proprietary"
        7 = "SIMM"
        8 = "DIMM"
        9 = "TSOP"
        10 = "PGA"
        11 = "RIMM"
        12 = "SODIMM"
        13 = "SRIMM"
        14 = "SMD"
        15 = "SSMP"
        16 = "QFP"
        17 = "TQFP"
        18 = "SOIC"
        19 = "LCC"
        20 = "PLCC"
        21 = "BGA"
        22 = "FPBGA"
        23 = "LGA"
    }
    
    # Function to get safe property value (PowerShell 5.1 compatible)
    function Get-SafeProperty {
        param(
            [PSObject]$Object,
            [string]$PropertyName,
            [string]$DefaultValue = "Unknown"
        )
        
        if ($null -eq $Object) {
            return $DefaultValue
        }
        
        $value = $Object.$PropertyName
        if ([string]::IsNullOrEmpty($value)) {
            return $DefaultValue
        }
        
        return $value
    }
    
    # Function to format bytes
    function Format-Bytes {
        param(
            [double]$Bytes,
            [int]$Precision = 2
        )
        
        if ($null -eq $Bytes -or $Bytes -eq 0) { 
            return "0 B" 
        }
        
        $sizes = @('B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB')
        $order = 0
        
        if ($Bytes -gt 0) {
            $order = [Math]::Floor([Math]::Log($Bytes, 1024))
            if ($order -gt ($sizes.Length - 1)) {
                $order = $sizes.Length - 1
            }
        }
        
        $size = [Math]::Round($Bytes / [Math]::Pow(1024, $order), $Precision)
        return "$size $($sizes[$order])"
    }
    
    # Function to create optimized CIM session
    function New-OptimizedCimSession {
        param(
            [string]$Computer,
            [PSCredential]$Cred,
            [string]$Protocol,
            [int]$TimeoutSec
        )
        
        try {
            Write-Verbose "Creating CIM session to $Computer using $Protocol protocol..."
            
            $sessionOption = if ($Protocol -eq 'WSMAN') {
                New-CimSessionOption -Protocol Wsman
            }
            else {
                New-CimSessionOption -Protocol Dcom
            }
            
            $sessionParams = @{
                ComputerName = $Computer
                SessionOption = $sessionOption
                OperationTimeoutSec = $TimeoutSec
                ErrorAction = 'Stop'
            }
            
            if ($Cred) {
                $sessionParams['Credential'] = $Cred
            }
            
            # Test connection first
            if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
                Write-Warning "Host $Computer is not reachable via ICMP"
            }
            
            $session = New-CimSession @sessionParams
            
            # Quick test query
            $testResult = Get-CimInstance -ClassName Win32_ComputerSystem -CimSession $session -ErrorAction SilentlyContinue
            if (-not $testResult) {
                throw "Failed to query basic system information"
            }
            
            Write-Verbose "Successfully connected to $Computer"
            return $session
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Error "Failed to create CIM session to $Computer : $errorMsg"
            
            # Try alternative protocol if primary fails
            if ($Protocol -eq 'DCOM') {
                Write-Verbose "Trying WSMAN protocol as fallback..."
                try {
                    $sessionOption = New-CimSessionOption -Protocol Wsman
                    $sessionParams['SessionOption'] = $sessionOption
                    $session = New-CimSession @sessionParams
                    Write-Verbose "Connected via WSMAN fallback"
                    return $session
                }
                catch {
                    Write-Error "Fallback connection also failed: $_"
                }
            }
            
            return $null
        }
    }
    
    # Function to get inventory with performance optimizations
    function Get-ComputerInventory {
        param(
            [string]$Computer,
            [Microsoft.Management.Infrastructure.CimSession]$CimSession
        )
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        try {
            Write-Verbose "Collecting data from $Computer..."
            
            # Query all required classes
            $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -CimSession $CimSession -ErrorAction SilentlyContinue
            $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $CimSession -ErrorAction SilentlyContinue
            $bios = Get-CimInstance -ClassName Win32_BIOS -CimSession $CimSession -ErrorAction SilentlyContinue
            $processors = Get-CimInstance -ClassName Win32_Processor -CimSession $CimSession -ErrorAction SilentlyContinue
            $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -CimSession $CimSession -ErrorAction SilentlyContinue
            $physicalDisks = Get-CimInstance -ClassName Win32_DiskDrive -CimSession $CimSession -ErrorAction SilentlyContinue
            $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk -CimSession $CimSession -ErrorAction SilentlyContinue | 
                Where-Object { $_.Size -gt 0 }
            $videoControllers = Get-CimInstance -ClassName Win32_VideoController -CimSession $CimSession -ErrorAction SilentlyContinue
            $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter -CimSession $CimSession -ErrorAction SilentlyContinue | 
                Where-Object { $_.MACAddress -ne $null }
            $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard -CimSession $CimSession -ErrorAction SilentlyContinue
            
            # Calculate totals with null safety
            $totalMemoryMB = if ($memory) { 
                ($memory | Measure-Object -Property Capacity -Sum -ErrorAction SilentlyContinue).Sum / 1MB 
            } else { 0 }
            
            $totalPhysicalDiskGB = if ($physicalDisks) { 
                ($physicalDisks | Measure-Object -Property Size -Sum -ErrorAction SilentlyContinue).Sum / 1GB 
            } else { 0 }
            
            $totalLogicalDiskGB = if ($logicalDisks) { 
                ($logicalDisks | Measure-Object -Property Size -Sum -ErrorAction SilentlyContinue).Sum / 1GB 
            } else { 0 }
            
            $totalVideoRAMGB = if ($videoControllers) { 
                ($videoControllers | Measure-Object -Property AdapterRAM -Sum -ErrorAction SilentlyContinue).Sum / 1GB 
            } else { 0 }
            
            # CPU information with null safety
            $cpuInfo = if ($processors) { $processors | Select-Object -First 1 } else { $null }
            $totalCores = if ($processors) { 
                ($processors | Measure-Object -Property NumberOfCores -Sum -ErrorAction SilentlyContinue).Sum 
            } else { 0 }
            
            $totalThreads = if ($processors) { 
                ($processors | Measure-Object -Property NumberOfLogicalProcessors -Sum -ErrorAction SilentlyContinue).Sum 
            } else { 0 }
            
            # Motherboard info with null safety
            $motherboardInfo = "Unknown"
            if ($baseBoard) {
                $manufacturer = Get-SafeProperty -Object $baseBoard -PropertyName "Manufacturer"
                $product = Get-SafeProperty -Object $baseBoard -PropertyName "Product"
                $version = Get-SafeProperty -Object $baseBoard -PropertyName "Version"
                $motherboardInfo = "{0} {1} {2}" -f $manufacturer, $product, $version
            }
            
            # Uptime calculation with null safety
            $uptimeFormatted = "Unknown"
            if ($operatingSystem -and $operatingSystem.LastBootUpTime) {
                $uptime = (Get-Date) - $operatingSystem.LastBootUpTime
                $uptimeFormatted = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
            }
            
            # BIOS date conversion
            $biosDateFormatted = "Unknown"
            if ($bios -and $bios.ReleaseDate) {
                try {
                    $biosDateFormatted = [Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate).ToString("yyyy-MM-dd")
                }
                catch {
                    $biosDateFormatted = $bios.ReleaseDate
                }
            }
            
            # Create summary object with all properties
            $summaryObject = [PSCustomObject]@{
                ComputerName = if ($computerSystem) { $computerSystem.Name } else { $Computer }
                Domain = Get-SafeProperty -Object $computerSystem -PropertyName "Domain"
                Owner = Get-SafeProperty -Object $computerSystem -PropertyName "PrimaryOwnerName"
                Manufacturer = Get-SafeProperty -Object $computerSystem -PropertyName "Manufacturer"
                Model = Get-SafeProperty -Object $computerSystem -PropertyName "Model"
                SerialNumber = Get-SafeProperty -Object $bios -PropertyName "SerialNumber"
                OperatingSystem = Get-SafeProperty -Object $operatingSystem -PropertyName "Caption"
                OSVersion = Get-SafeProperty -Object $operatingSystem -PropertyName "Version"
                OSArchitecture = Get-SafeProperty -Object $operatingSystem -PropertyName "OSArchitecture"
                InstallDate = if ($operatingSystem -and $operatingSystem.InstallDate) { 
                    try {
                        [Management.ManagementDateTimeConverter]::ToDateTime($operatingSystem.InstallDate)
                    }
                    catch {
                        $operatingSystem.InstallDate
                    }
                } else { $null }
                LastBootUpTime = if ($operatingSystem) { $operatingSystem.LastBootUpTime } else { $null }
                Uptime = $uptimeFormatted
                SystemType = Get-SafeProperty -Object $computerSystem -PropertyName "SystemType"
                Motherboard = $motherboardInfo
                BIOSVersion = Get-SafeProperty -Object $bios -PropertyName "SMBIOSBIOSVersion"
                BIOSDate = $biosDateFormatted
                ProcessorName = if ($cpuInfo) { $cpuInfo.Name.Trim() } else { "Unknown" }
                ProcessorCount = if ($processors) { $processors.Count } else { 0 }
                TotalCores = $totalCores
                TotalThreads = $totalThreads
                MaxClockSpeed = if ($cpuInfo) { "{0} MHz" -f $cpuInfo.MaxClockSpeed } else { "Unknown" }
                TotalMemoryMB = [Math]::Round($totalMemoryMB, 2)
                TotalMemoryGB = [Math]::Round($totalMemoryMB / 1024, 2)
                MemorySlots = if ($memory) { $memory.Count } else { 0 }
                PhysicalDiskCount = if ($physicalDisks) { $physicalDisks.Count } else { 0 }
                TotalPhysicalDiskGB = [Math]::Round($totalPhysicalDiskGB, 2)
                LogicalDiskCount = if ($logicalDisks) { $logicalDisks.Count } else { 0 }
                TotalLogicalDiskGB = [Math]::Round($totalLogicalDiskGB, 2)
                VideoCardCount = if ($videoControllers) { $videoControllers.Count } else { 0 }
                TotalVideoRAMGB = [Math]::Round($totalVideoRAMGB, 2)
                NetworkAdapterCount = if ($networkAdapters) { $networkAdapters.Count } else { 0 }
                CollectionTimeMs = $stopwatch.ElapsedMilliseconds
                CollectionDate = Get-Date
                Status = "Success"
            }
            
            # Collect detailed information if requested
            if ($Full) {
                # Memory Details
                if ($memory) {
                    foreach ($mem in $memory) {
                        $memObject = [PSCustomObject]@{
                            ComputerName = $Computer
                            Manufacturer = Get-SafeProperty -Object $mem -PropertyName "Manufacturer"
                            PartNumber = Get-SafeProperty -Object $mem -PropertyName "PartNumber"
                            SerialNumber = Get-SafeProperty -Object $mem -PropertyName "SerialNumber"
                            Capacity = Format-Bytes -Bytes $mem.Capacity
                            RawCapacity = $mem.Capacity
                            Speed = if ($mem.Speed) { "{0} MHz" -f $mem.Speed } else { "Unknown" }
                            FormFactor = if ($mem.FormFactor -and $FormFactorCache.ContainsKey([int]$mem.FormFactor)) { 
                                $FormFactorCache[[int]$mem.FormFactor] 
                            } else { "Unknown" }
                            MemoryType = if ($mem.MemoryType -and $MemoryTypeCache.ContainsKey([int]$mem.MemoryType)) { 
                                $MemoryTypeCache[[int]$mem.MemoryType] 
                            } else { "Unknown" }
                            DeviceLocator = Get-SafeProperty -Object $mem -PropertyName "DeviceLocator"
                            BankLabel = Get-SafeProperty -Object $mem -PropertyName "BankLabel" -DefaultValue ""
                        }
                        $null = $AllDetailsResults.Memory.Add($memObject)
                    }
                }
                
                # Physical Disk Details
                if ($physicalDisks) {
                    foreach ($disk in $physicalDisks) {
                        $diskObject = [PSCustomObject]@{
                            ComputerName = $Computer
                            Model = if ($disk.Model) { $disk.Model.Trim() } else { "Unknown" }
                            SerialNumber = Get-SafeProperty -Object $disk -PropertyName "SerialNumber"
                            Size = Format-Bytes -Bytes $disk.Size
                            RawSize = $disk.Size
                            InterfaceType = Get-SafeProperty -Object $disk -PropertyName "InterfaceType"
                            MediaType = Get-SafeProperty -Object $disk -PropertyName "MediaType"
                            Partitions = $disk.Partitions
                            Status = Get-SafeProperty -Object $disk -PropertyName "Status"
                            SCSIBus = $disk.SCSIBus
                            SCSILogicalUnit = $disk.SCSILogicalUnit
                            SCSIPort = $disk.SCSIPort
                            SCSITargetId = $disk.SCSITargetId
                        }
                        $null = $AllDetailsResults.PhysicalDisks.Add($diskObject)
                    }
                }
                
                # Logical Disk Details
                if ($logicalDisks) {
                    foreach ($disk in $logicalDisks) {
                        $freePercent = if ($disk.Size -gt 0) { 
                            [Math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2) 
                        } else { 0 }
                        
                        $diskObject = [PSCustomObject]@{
                            ComputerName = $Computer
                            DeviceID = $disk.DeviceID
                            VolumeName = if ($disk.VolumeName) { $disk.VolumeName } else { "" }
                            FileSystem = Get-SafeProperty -Object $disk -PropertyName "FileSystem"
                            TotalSize = Format-Bytes -Bytes $disk.Size
                            FreeSpace = Format-Bytes -Bytes $disk.FreeSpace
                            UsedSpace = Format-Bytes -Bytes ($disk.Size - $disk.FreeSpace)
                            FreePercent = $freePercent
                            UsedPercent = 100 - $freePercent
                            DriveType = switch ($disk.DriveType) {
                                0 { "Unknown" }
                                1 { "No Root Directory" }
                                2 { "Removable" }
                                3 { "Local Disk" }
                                4 { "Network" }
                                5 { "CD-ROM" }
                                6 { "RAM Disk" }
                                default { "Unknown" }
                            }
                        }
                        $null = $AllDetailsResults.LogicalDisks.Add($diskObject)
                    }
                }
                
                # Video Card Details
                if ($videoControllers) {
                    foreach ($video in $videoControllers) {
                        $driverDate = $null
                        if ($video.DriverDate) {
                            try {
                                $driverDate = [Management.ManagementDateTimeConverter]::ToDateTime($video.DriverDate)
                            }
                            catch {
                                $driverDate = $video.DriverDate
                            }
                        }
                        
                        $videoObject = [PSCustomObject]@{
                            ComputerName = $Computer
                            Name = Get-SafeProperty -Object $video -PropertyName "Name"
                            VideoProcessor = Get-SafeProperty -Object $video -PropertyName "VideoProcessor"
                            AdapterRAM = Format-Bytes -Bytes $video.AdapterRAM
                            RawAdapterRAM = $video.AdapterRAM
                            CurrentResolution = if ($video.CurrentHorizontalResolution -and $video.CurrentVerticalResolution) {
                                "{0}x{1}" -f $video.CurrentHorizontalResolution, $video.CurrentVerticalResolution
                            } else { "Unknown" }
                            RefreshRate = if ($video.CurrentRefreshRate) { "{0} Hz" -f $video.CurrentRefreshRate } else { "Unknown" }
                            DriverVersion = Get-SafeProperty -Object $video -PropertyName "DriverVersion"
                            DriverDate = $driverDate
                            Status = Get-SafeProperty -Object $video -PropertyName "Status"
                        }
                        $null = $AllDetailsResults.VideoCards.Add($videoObject)
                    }
                }
                
                # Network Adapter Details
                if ($networkAdapters) {
                    foreach ($adapter in $networkAdapters) {
                        $speed = "N/A"
                        if ($adapter.Speed -and $adapter.Speed -gt 0) {
                            $speed = Format-Bytes -Bytes $adapter.Speed -Precision 0
                        }
                        
                        $adapterObject = [PSCustomObject]@{
                            ComputerName = $Computer
                            Name = Get-SafeProperty -Object $adapter -PropertyName "Name"
                            Manufacturer = Get-SafeProperty -Object $adapter -PropertyName "Manufacturer"
                            MACAddress = Get-SafeProperty -Object $adapter -PropertyName "MACAddress"
                            Speed = $speed
                            AdapterType = Get-SafeProperty -Object $adapter -PropertyName "AdapterType"
                            NetConnectionStatus = switch ($adapter.NetConnectionStatus) {
                                0 { "Disconnected" }
                                1 { "Connecting" }
                                2 { "Connected" }
                                3 { "Disconnecting" }
                                4 { "Hardware not present" }
                                5 { "Hardware disabled" }
                                6 { "Hardware malfunction" }
                                7 { "Media disconnected" }
                                8 { "Authenticating" }
                                9 { "Authentication succeeded" }
                                10 { "Authentication failed" }
                                11 { "Invalid address" }
                                12 { "Credentials required" }
                                default { "Unknown ($($adapter.NetConnectionStatus))" }
                            }
                            PhysicalAdapter = if ($null -ne $adapter.PhysicalAdapter) { 
                                [bool]$adapter.PhysicalAdapter 
                            } else { $null }
                        }
                        $null = $AllDetailsResults.NetworkAdapters.Add($adapterObject)
                    }
                }
            }
            
            Write-Verbose "Completed inventory for $Computer in $($stopwatch.ElapsedMilliseconds)ms"
            return $summaryObject
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Error "Error collecting inventory from ${Computer}: $errorMsg"
            
            # Return error object
            return [PSCustomObject]@{
                ComputerName = $Computer
                Status = "Error"
                ErrorMessage = $errorMsg
                CollectionDate = Get-Date
                CollectionTimeMs = $stopwatch.ElapsedMilliseconds
            }
        }
        finally {
            $stopwatch.Stop()
        }
    }
    
    # Optimized export function
    function Export-InventoryResults {
        param(
            [object]$Data,
            [string]$Path,
            [switch]$FullData
        )
        
        $extension = [System.IO.Path]::GetExtension($Path).ToLower()
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $directory = [System.IO.Path]::GetDirectoryName($Path)
        
        if ([string]::IsNullOrEmpty($directory)) {
            $directory = Get-Location
            $Path = Join-Path $directory $Path
        }
        
        try {
            switch ($extension) {
                '.csv' {
                    if ($FullData) {
                        # Export multiple CSV files for detailed data
                        $summaryPath = Join-Path $directory "${fileName}_summary.csv"
                        $Data.Summary | Export-Csv -Path $summaryPath -NoTypeInformation -Encoding UTF8 -Force
                        
                        foreach ($key in $Data.Details.Keys) {
                            if ($Data.Details[$key].Count -gt 0) {
                                $detailPath = Join-Path $directory "${fileName}_${key}.csv"
                                $Data.Details[$key] | Export-Csv -Path $detailPath -NoTypeInformation -Encoding UTF8 -Force
                            }
                        }
                        Write-Host "Results exported to multiple CSV files in $directory" -ForegroundColor Green
                    }
                    else {
                        $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -Force
                        Write-Host "Results exported to CSV: $Path" -ForegroundColor Green
                    }
                }
                '.json' {
                    $jsonData = if ($FullData) {
                        @{
                            Summary = $Data.Summary
                            Details = @{
                                Memory = $Data.Details.Memory
                                PhysicalDisks = $Data.Details.PhysicalDisks
                                LogicalDisks = $Data.Details.LogicalDisks
                                VideoCards = $Data.Details.VideoCards
                                NetworkAdapters = $Data.Details.NetworkAdapters
                            }
                            Metadata = @{
                                Generated = Get-Date
                                ComputerCount = $Data.Summary.Count
                                ScriptVersion = "3.0"
                            }
                        }
                    }
                    else {
                        $Data
                    }
                    
                    $json = $jsonData | ConvertTo-Json -Depth 10
                    [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
                    Write-Host "Results exported to JSON: $Path" -ForegroundColor Green
                }
                '.xml' {
                    $Data | Export-Clixml -Path $Path -Depth 10
                    Write-Host "Results exported to XML: $Path" -ForegroundColor Green
                }
                '.html' {
                    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Hardware Inventory Report</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f8f9fa; 
            color: #333;
        }
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            background-color: white; 
            padding: 30px; 
            border-radius: 8px; 
            box-shadow: 0 2px 15px rgba(0,0,0,0.1);
        }
        h1 { 
            color: #2c3e50; 
            border-bottom: 3px solid #3498db; 
            padding-bottom: 15px; 
            margin-bottom: 30px;
        }
        h2 { 
            color: #34495e; 
            margin-top: 30px; 
            padding-bottom: 10px;
            border-bottom: 2px solid #ecf0f1;
        }
        .metadata { 
            background-color: #f8f9fa; 
            padding: 15px; 
            border-radius: 5px; 
            margin-bottom: 20px;
            border-left: 4px solid #3498db;
        }
        table { 
            border-collapse: collapse; 
            width: 100%; 
            margin-bottom: 20px;
            font-size: 14px;
        }
        th { 
            background-color: #3498db; 
            color: white; 
            padding: 12px 15px; 
            text-align: left; 
            font-weight: 600;
        }
        td { 
            padding: 10px 15px; 
            border-bottom: 1px solid #e0e0e0; 
            vertical-align: top;
        }
        tr:hover { 
            background-color: #f5f9fc; 
        }
        .status-success { 
            color: #27ae60; 
            font-weight: bold;
        }
        .status-error { 
            color: #e74c3c; 
            font-weight: bold;
        }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .summary-card {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #3498db;
        }
        .footer { 
            margin-top: 40px; 
            text-align: center; 
            color: #7f8c8d; 
            font-size: 12px; 
            border-top: 1px solid #ecf0f1; 
            padding-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hardware Inventory Report</h1>
        
        <div class="metadata">
            <strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')<br>
            <strong>Computers Processed:</strong> $($AllResults.Count)<br>
            <strong>Total Collection Time:</strong> $($ScriptStopwatch.Elapsed.ToString('hh\:mm\:ss'))
        </div>
"@
                    
                    # Summary section
                    $html += "<h2>Summary</h2>"
                    $html += "<div class='summary-grid'>"
                    foreach ($computer in $AllResults) {
                        $statusClass = if ($computer.Status -eq 'Success') { 'status-success' } else { 'status-error' }
                        $html += @"
                        <div class='summary-card'>
                            <strong>Computer:</strong> $($computer.ComputerName)<br>
                            <strong>OS:</strong> $($computer.OperatingSystem)<br>
                            <strong>Processor:</strong> $($computer.ProcessorName)<br>
                            <strong>Memory:</strong> $($computer.TotalMemoryGB) GB<br>
                            <strong>Disks:</strong> $($computer.TotalPhysicalDiskGB) GB<br>
                            <strong>Status:</strong> <span class='$statusClass'>$($computer.Status)</span><br>
                            <strong>Time:</strong> $($computer.CollectionTimeMs) ms
                        </div>
"@
                    }
                    $html += "</div>"
                    
                    # Detailed tables for full data
                    if ($Full) {
                        foreach ($key in @('Memory', 'PhysicalDisks', 'LogicalDisks', 'VideoCards', 'NetworkAdapters')) {
                            $details = $AllDetailsResults[$key]
                            if ($details.Count -gt 0) {
                                $html += "<h2>$key</h2>"
                                $html += "<table>"
                                $html += "<thead><tr>"
                                $firstItem = $details[0]
                                foreach ($property in $firstItem.PSObject.Properties.Name) {
                                    $html += "<th>$property</th>"
                                }
                                $html += "</tr></thead><tbody>"
                                
                                foreach ($item in $details) {
                                    $html += "<tr>"
                                    foreach ($property in $item.PSObject.Properties.Name) {
                                        $html += "<td>$($item.$property)</td>"
                                    }
                                    $html += "</tr>"
                                }
                                
                                $html += "</tbody></table>"
                            }
                        }
                    }
                    
                    $html += @"
        <div class="footer">
            Report generated by Get-Invent-Optimized v3.0
        </div>
    </div>
</body>
</html>
"@
                    
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
        $cimSession = New-OptimizedCimSession -Computer $computer -Cred $Credential -Protocol $Protocol -TimeoutSec $Timeout
        
        if ($cimSession) {
            try {
                # Get inventory
                $inventory = Get-ComputerInventory -Computer $computer -CimSession $cimSession
                
                if ($inventory) {
                    $null = $AllResults.Add($inventory)
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
        Write-Host "`n" + ("=" * 50) -ForegroundColor Yellow
        Write-Host "INVENTORY SUMMARY (Processed: $($AllResults.Count) computers)" -ForegroundColor Yellow
        Write-Host ("=" * 50) -ForegroundColor Yellow
        
        $AllResults | Format-Table -Property ComputerName, Status, OperatingSystem, ProcessorName, `
            @{Name="Memory(GB)"; Expression={$_.TotalMemoryGB}}, `
            @{Name="Disks(GB)"; Expression={$_.TotalPhysicalDiskGB}}, `
            CollectionTimeMs -AutoSize
        
        if ($Full) {
            Write-Host "`n" + ("=" * 50) -ForegroundColor Yellow
            Write-Host "DETAILED INFORMATION" -ForegroundColor Yellow
            Write-Host ("=" * 50) -ForegroundColor Yellow
            
            foreach ($key in @('Memory', 'PhysicalDisks', 'LogicalDisks', 'VideoCards', 'NetworkAdapters')) {
                $details = $