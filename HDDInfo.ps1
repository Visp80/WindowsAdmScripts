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