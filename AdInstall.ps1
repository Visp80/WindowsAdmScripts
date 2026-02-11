# Завантаження AnyDesk
$url = "https://download.anydesk.com/AnyDesk.exe"
$installer = "$env:TEMP\AnyDesk.exe"
Invoke-WebRequest -Uri $url -OutFile $installer

# Встановлення в кастомну папку
$installPath = "C:\Program Files\AnyDesk"
$password = "Ca72135901"

# Тиха інсталяція
Start-Process -FilePath $installer -ArgumentList "--install `"$installPath`" --silent" -Wait

# Налаштування пароля (після встановлення)
$anydesk = "$installPath\AnyDesk.exe"

$password | & $anydesk --set-password  _full_access

Restart-Service "AnyDesk" -Force

# Видалення інсталятора
Remove-Item $installer