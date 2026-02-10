# Завантаження AnyDesk
$url = "https://download.anydesk.com/AnyDesk.exe"
$installer = "$env:TEMP\AnyDesk.exe"
Invoke-WebRequest -Uri $url -OutFile $installer

# Встановлення в кастомну папку
$installPath = "C:\Program Files\AnyDesk"
$password = "7777777"

# Тиха інсталяція
Start-Process -FilePath $installer -ArgumentList "--install `"$installPath`" --silent" -Wait

# Налаштування пароля (після встановлення)
$anydesk = "$installPath\AnyDesk.exe"
Start-Process -FilePath $anydesk -ArgumentList "--set-password $password" -Wait

# Видалення інсталятора
#Remove-Item $installer