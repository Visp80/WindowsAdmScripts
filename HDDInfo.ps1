Write-Host "`n=== SATA CONTROLLERS ==="

Get-CimInstance Win32_SCSIController |
    Format-List Name,Manufacturer,DeviceID,Status

Get-CimInstance Win32_IDEController |
    Format-List Name,PNPDeviceID,Status

Write-Host "`n=== STORAGE CONTROLLERS ==="

Get-PnpDevice -PresentOnly |
    Where-Object {
        $_.Class -in @("SCSIAdapter","HDC","System")
    } |
    Format-Table Class,FriendlyName,Status -AutoSize

Write-Host "`n=== BOOT MODE ==="

Get-ItemProperty `
    "HKLM:\SYSTEM\CurrentControlSet\Control" |
    Select-Object PEFirmwareType
	
	
Write-Host "`n=== ADDitional ==="	

Get-CimInstance Win32_DiskDrive |
    Select-Object Model,Index,PNPDeviceID |
    Format-List

Get-PnpDevice -PresentOnly |
    Where-Object {
        $_.InstanceId -match 'PCI\\VEN_8086&DEV_1C00|PCI\\VEN_8086&DEV_1C08|PCI\\VEN_1106&DEV_0415'
    } |
    Format-List FriendlyName,InstanceId,Status

$keys = @(
    'HKLM:\SYSTEM\CurrentControlSet\Services\storahci',
    'HKLM:\SYSTEM\CurrentControlSet\Services\iaStorV',
    'HKLM:\SYSTEM\CurrentControlSet\Services\msahci',
    'HKLM:\SYSTEM\CurrentControlSet\Services\pciide'
)

foreach ($key in $keys) {
    if (Test-Path $key) {
        $p = Get-ItemProperty $key
        [PSCustomObject]@{
            Driver = Split-Path $key -Leaf
            Start  = $p.Start
        }
    }
}

bcdedit /enum 

Get-Disk |
    Format-Table Number,FriendlyName,PartitionStyle,IsBoot,IsSystem
	
	
	
Write-Host "`n=== LEVEL2  ==="		

$disks = Get-CimInstance Win32_DiskDrive

foreach ($disk in $disks) {
    "`n========== $($disk.Model) =========="
    $id = $disk.PNPDeviceID

    for ($i = 0; $i -lt 6 -and $id; $i++) {
        $dev = Get-PnpDevice -InstanceId $id -ErrorAction SilentlyContinue
        $parent = Get-PnpDeviceProperty `
            -InstanceId $id `
            -KeyName 'DEVPKEY_Device_Parent' `
            -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            Level       = $i
            Device      = $dev.FriendlyName
            InstanceId  = $id
        } | Format-List

        $id = $parent.Data
    }
}

Get-CimInstance Win32_PnPSignedDriver |
    Where-Object {
        $_.DeviceID -match 'PCI\\VEN_8086&DEV_1C00|PCI\\VEN_8086&DEV_1C08|PCI\\VEN_1106&DEV_0415'
    } |
    Format-List DeviceName,DriverProviderName,DriverVersion,InfName,DeviceID
	