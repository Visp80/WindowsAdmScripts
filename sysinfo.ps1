Write-Host "`n=== OPERATING SYSTEM ==="
Get-CimInstance Win32_OperatingSystem |
    Format-List Caption,Version,BuildNumber,OSArchitecture

Write-Host "`n=== BIOS ==="
Get-CimInstance Win32_BIOS |
    Format-List Manufacturer,SMBIOSBIOSVersion,ReleaseDate

Write-Host "`n=== MOTHERBOARD ==="
Get-CimInstance Win32_BaseBoard |
    Format-List Manufacturer,Product,Version

Write-Host "`n=== CPU ==="
Get-CimInstance Win32_Processor |
    Format-List Name,NumberOfCores,NumberOfLogicalProcessors,
        VirtualizationFirmwareEnabled,
        VMMonitorModeExtensions,
        SecondLevelAddressTranslationExtensions

Write-Host "`n=== SYSTEM ==="
Get-CimInstance Win32_ComputerSystem |
    Format-List TotalPhysicalMemory,HypervisorPresent,Domain

Write-Host "`n=== TPM ==="
Get-Tpm |
    Format-List TpmPresent,TpmReady,TpmEnabled,SpecVersion

Write-Host "`n=== SECURE BOOT ==="
try {
    Confirm-SecureBootUEFI
} catch {
    Write-Host "UEFI/Secure Boot недоступний або система завантажена в Legacy BIOS"
}