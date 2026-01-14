# Примеры использования Get-Invent-Optimized.ps1

## 1. Базовое использование

### 1.1 Локальная инвентаризация
```powershell
# Простейший вариант - инвентаризация локального компьютера
.\Get-Invent-Optimized.ps1

# С детальной информацией
.\Get-Invent-Optimized.ps1 -Full

# С verbose выводом для отладки
.\Get-Invent-Optimized.ps1 -Full -Verbose
```

### 1.2 Удаленная инвентаризация
```powershell
# Один удаленный компьютер
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01"

# Несколько компьютеров
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01", "SERVER02", "WORKSTATION01"

# С учетными данными
$credential = Get-Credential "DOMAIN\Admin"
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Credential $credential
```

## 2. Экспорт результатов

### 2.1 CSV экспорт (для Excel)
```powershell
# Простой экспорт
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -ExportPath "C:\Reports\server01.csv"

# Детальный экспорт
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Full -ExportPath "C:\Reports\server01_detailed.csv"

# Множественные серверы в один файл
$servers = Get-Content "C:\Servers\production_servers.txt"
.\Get-Invent-Optimized.ps1 -ComputerName $servers -ExportPath "C:\Reports\all_servers.csv"
```

### 2.2 JSON экспорт (для API/автоматизации)
```powershell
# Экспорт в JSON
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Full -ExportPath "C:\Reports\server01.json"

# Последующая обработка JSON
$jsonData = Get-Content "C:\Reports\server01.json" | ConvertFrom-Json
$jsonData.Summary | Where-Object { $_.TotalMemoryGB -lt 32 }
```

### 2.3 HTML экспорт (для отчетов)
```powershell
# Красивый HTML отчет
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Full -ExportPath "C:\Reports\server01_report.html"

# Открыть отчет в браузере после создания
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Full -ExportPath "C:\Reports\report.html"
Start-Process "C:\Reports\report.html"
```

### 2.4 XML экспорт (для PowerShell обработки)
```powershell
# Экспорт в XML
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Full -ExportPath "C:\Reports\server01.xml"

# Импорт и обработка
$data = Import-Clixml "C:\Reports\server01.xml"
$data.Summary | Select-Object ComputerName, TotalMemoryGB, TotalCores
```

## 3. Pipeline сценарии

### 3.1 Из текстового файла
```powershell
# servers.txt содержит список серверов (по одному на строку)
Get-Content "C:\Servers\servers.txt" | .\Get-Invent-Optimized.ps1 -Full
```

### 3.2 Из Active Directory
```powershell
# Все серверы в домене
Get-ADComputer -Filter "OperatingSystem -like '*Server*'" -Properties Name | 
    Select-Object -ExpandProperty Name | 
    .\Get-Invent-Optimized.ps1 -ExportPath "C:\Reports\domain_servers.csv"

# Серверы в конкретном OU
Get-ADComputer -Filter * -SearchBase "OU=Servers,DC=company,DC=local" | 
    Select-Object -ExpandProperty Name | 
    .\Get-Invent-Optimized.ps1 -Full

# Компьютеры, которые были онлайн в последние 30 дней
$date = (Get-Date).AddDays(-30)
Get-ADComputer -Filter {LastLogonDate -gt $date} -Properties LastLogonDate | 
    Select-Object -ExpandProperty Name | 
    .\Get-Invent-Optimized.ps1
```

### 3.3 Из CSV файла
```powershell
# computers.csv содержит колонку "ComputerName"
Import-Csv "C:\Servers\computers.csv" | 
    Select-Object -ExpandProperty ComputerName | 
    .\Get-Invent-Optimized.ps1 -ExportPath "C:\Reports\results.csv"
```

## 4. Фильтрация и анализ результатов

### 4.1 Сохранение в переменную
```powershell
# Собрать данные в переменную
$inventory = .\Get-Invent-Optimized.ps1 -ComputerName "SERVER01", "SERVER02", "SERVER03" -Full

# Анализ данных
$inventory | Format-Table ComputerName, TotalMemoryGB, TotalCores, TotalThreads
```

### 4.2 Фильтрация по параметрам
```powershell
# Серверы с памятью меньше 32 GB
$inventory | Where-Object { $_.TotalMemoryGB -lt 32 }

# Серверы с менее чем 8 ядрами
$inventory | Where-Object { $_.TotalCores -lt 8 }

# Серверы старше 2020 года
$inventory | Where-Object { $_.InstallDate -lt (Get-Date "2020-01-01") }

# Серверы с uptime больше 30 дней
$inventory | Where-Object { $_.LastBootUpTime -lt (Get-Date).AddDays(-30) }
```

### 4.3 Сортировка
```powershell
# По объему памяти (убывание)
$inventory | Sort-Object -Property TotalMemoryGB -Descending

# По количеству ядер
$inventory | Sort-Object -Property TotalCores

# По дате установки ОС
$inventory | Sort-Object -Property InstallDate
```

### 4.4 Группировка
```powershell
# Группировка по производителю
$inventory | Group-Object -Property Manufacturer

# Группировка по ОС
$inventory | Group-Object -Property OperatingSystem

# Группировка по количеству памяти
$inventory | Group-Object -Property {
    if ($_.TotalMemoryGB -lt 16) { "< 16 GB" }
    elseif ($_.TotalMemoryGB -lt 32) { "16-32 GB" }
    elseif ($_.TotalMemoryGB -lt 64) { "32-64 GB" }
    else { "> 64 GB" }
}
```

## 5. Расширенные сценарии

### 5.1 Еженедельный отчет по инфраструктуре
```powershell
# Скрипт для Task Scheduler
$date = Get-Date -Format "yyyy-MM-dd"
$reportPath = "C:\Reports\Weekly\Infrastructure_Report_$date.html"

# Получить список всех серверов
$servers = Get-ADComputer -Filter "OperatingSystem -like '*Server*'" | 
    Select-Object -ExpandProperty Name

# Собрать инвентаризацию
$servers | .\Get-Invent-Optimized.ps1 -Full -ExportPath $reportPath

# Отправить отчет по email (опционально)
Send-MailMessage -From "monitoring@company.com" `
                 -To "it-team@company.com" `
                 -Subject "Weekly Infrastructure Report - $date" `
                 -Body "Infrastructure inventory report attached" `
                 -Attachments $reportPath `
                 -SmtpServer "smtp.company.com"
```

### 5.2 Проверка соответствия стандартам
```powershell
# Собрать данные
$inventory = .\Get-Invent-Optimized.ps1 -ComputerName (Get-Content "C:\Servers\production.txt") -Full

# Определить стандарты
$requiredMemoryGB = 32
$requiredCores = 8
$maxUptimeDays = 90

# Проверка соответствия
$nonCompliant = $inventory | Where-Object {
    $_.TotalMemoryGB -lt $requiredMemoryGB -or
    $_.TotalCores -lt $requiredCores -or
    $_.LastBootUpTime -lt (Get-Date).AddDays(-$maxUptimeDays)
}

# Отчет о несоответствиях
if ($nonCompliant) {
    Write-Host "Found $($nonCompliant.Count) non-compliant servers:" -ForegroundColor Red
    $nonCompliant | Format-Table ComputerName, TotalMemoryGB, TotalCores, LastBootUpTime
} else {
    Write-Host "All servers are compliant!" -ForegroundColor Green
}
```

### 5.3 Сравнение конфигураций
```powershell
# Собрать данные с двух серверов
$server1 = .\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Full
$server2 = .\Get-Invent-Optimized.ps1 -ComputerName "SERVER02" -Full

# Сравнение
$comparison = [PSCustomObject]@{
    Property = @('ComputerName', 'TotalMemoryGB', 'TotalCores', 'TotalPhysicalDiskGB', 'OperatingSystem')
    Server1 = $server1.ComputerName, $server1.TotalMemoryGB, $server1.TotalCores, $server1.TotalPhysicalDiskGB, $server1.OperatingSystem
    Server2 = $server2.ComputerName, $server2.TotalMemoryGB, $server2.TotalCores, $server2.TotalPhysicalDiskGB, $server2.OperatingSystem
}

$comparison | Format-Table -AutoSize
```

### 5.4 Поиск серверов с низким свободным местом
```powershell
# Сбор данных с детализацией
$results = Get-Content "C:\Servers\servers.txt" | 
    .\Get-Invent-Optimized.ps1 -Full

# Анализ логических дисков (требуется доступ к детальным данным)
# Примечание: в текущей версии детальные данные возвращаются отдельно
# Рекомендуется экспортировать в JSON и обработать

.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Full -ExportPath "C:\temp\server01.json"
$data = Get-Content "C:\temp\server01.json" | ConvertFrom-Json

# Проверка дисков с менее чем 20% свободного места
$data.Details.LogicalDisks | Where-Object {
    [int]($_.FreePercent -replace '%','') -lt 20
}
```

### 5.5 Массовая инвентаризация с логированием
```powershell
# Скрипт с логированием
$logPath = "C:\Logs\Inventory_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$servers = Get-Content "C:\Servers\all_servers.txt"
$results = @()

Start-Transcript -Path $logPath

foreach ($server in $servers) {
    Write-Host "`nProcessing: $server" -ForegroundColor Cyan
    try {
        $result = .\Get-Invent-Optimized.ps1 -ComputerName $server -ErrorAction Stop
        $results += $result
        Write-Host "✓ Success: $server" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed: $server - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Stop-Transcript

# Экспорт успешных результатов
if ($results.Count -gt 0) {
    $results | Export-Csv -Path "C:\Reports\Inventory_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
    Write-Host "`nSuccessfully processed $($results.Count) of $($servers.Count) servers" -ForegroundColor Green
}
```

## 6. Интеграция с другими инструментами

### 6.1 Экспорт в SQL Server
```powershell
# Собрать данные
$inventory = .\Get-Invent-Optimized.ps1 -ComputerName (Get-Content "servers.txt")

# Подключение к SQL
$connectionString = "Server=SQL01;Database=Inventory;Integrated Security=True;"
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
$connection.Open()

# Вставка данных
foreach ($item in $inventory) {
    $query = @"
INSERT INTO Servers (ComputerName, OperatingSystem, TotalMemoryGB, TotalCores, CollectionDate)
VALUES ('$($item.ComputerName)', '$($item.OperatingSystem)', $($item.TotalMemoryGB), $($item.TotalCores), '$($item.CollectionDate)')
"@
    $command = New-Object System.Data.SqlClient.SqlCommand($query, $connection)
    $command.ExecuteNonQuery() | Out-Null
}

$connection.Close()
Write-Host "Data inserted into SQL Server" -ForegroundColor Green
```

### 6.2 Интеграция с SharePoint
```powershell
# Сбор и экспорт
$inventory = .\Get-Invent-Optimized.ps1 -ComputerName (Get-Content "servers.txt") -Full
$csvPath = "C:\temp\inventory.csv"
$inventory | Export-Csv -Path $csvPath -NoTypeInformation

# Загрузка в SharePoint (требуется PnP PowerShell)
Connect-PnPOnline -Url "https://company.sharepoint.com/sites/IT" -Interactive
Add-PnPFile -Path $csvPath -Folder "Shared Documents/Inventory"
Write-Host "File uploaded to SharePoint" -ForegroundColor Green
```

### 6.3 Webhook уведомления
```powershell
# Собрать данные о критичных серверах
$critical = .\Get-Invent-Optimized.ps1 -ComputerName "PROD-SQL01", "PROD-WEB01" -Full

# Проверить соответствие
$issues = $critical | Where-Object { 
    $_.TotalMemoryGB -lt 64 -or 
    $_.TotalCores -lt 16 
}

# Отправить webhook в Teams/Slack если есть проблемы
if ($issues) {
    $webhook = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    $message = @{
        text = "⚠️ Critical servers below specifications:`n"
        attachments = @(
            @{
                color = "danger"
                fields = $issues | ForEach-Object {
                    @{
                        title = $_.ComputerName
                        value = "Memory: $($_.TotalMemoryGB)GB, Cores: $($_.TotalCores)"
                        short = $false
                    }
                }
            }
        )
    } | ConvertTo-Json -Depth 5
    
    Invoke-RestMethod -Uri $webhook -Method Post -Body $message -ContentType 'application/json'
}
```

## 7. Автоматизация через Task Scheduler

### 7.1 Ежедневная инвентаризация
```powershell
# Создание задания
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument @"
-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Get-Invent-Optimized.ps1" -ComputerName (Get-Content "C:\Servers\servers.txt") -ExportPath "C:\Reports\Daily\Inventory_$(Get-Date -Format 'yyyyMMdd').csv"
"@

$trigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"
$principal = New-ScheduledTaskPrincipal -UserId "DOMAIN\ServiceAccount" -LogonType Password
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName "DailyInventory" `
                       -Action $action `
                       -Trigger $trigger `
                       -Principal $principal `
                       -Settings $settings `
                       -Description "Daily hardware inventory collection"
```

## 8. Troubleshooting сценарии

### 8.1 Тестирование доступности перед инвентаризацией
```powershell
$servers = Get-Content "servers.txt"
$onlineServers = @()

foreach ($server in $servers) {
    if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
        Write-Host "✓ $server is online" -ForegroundColor Green
        $onlineServers += $server
    } else {
        Write-Host "✗ $server is offline" -ForegroundColor Red
    }
}

# Инвентаризация только онлайн серверов
if ($onlineServers.Count -gt 0) {
    .\Get-Invent-Optimized.ps1 -ComputerName $onlineServers -Full
}
```

### 8.2 Повторные попытки при неудаче
```powershell
function Invoke-InventoryWithRetry {
    param(
        [string]$ComputerName,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 5
    )
    
    $attempt = 0
    $success = $false
    
    while (-not $success -and $attempt -lt $MaxRetries) {
        $attempt++
        Write-Host "Attempt $attempt of $MaxRetries for $ComputerName" -ForegroundColor Yellow
        
        try {
            $result = .\Get-Invent-Optimized.ps1 -ComputerName $ComputerName -ErrorAction Stop
            $success = $true
            return $result
        }
        catch {
            Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($attempt -lt $MaxRetries) {
                Start-Sleep -Seconds $RetryDelay
            }
        }
    }
    
    Write-Host "All attempts failed for $ComputerName" -ForegroundColor Red
    return $null
}

# Использование
$servers = "SERVER01", "SERVER02", "SERVER03"
$results = $servers | ForEach-Object { Invoke-InventoryWithRetry -ComputerName $_ }
```

## 9. Отчетность и визуализация

### 9.1 Сводная статистика
```powershell
$inventory = .\Get-Invent-Optimized.ps1 -ComputerName (Get-Content "servers.txt")

# Статистика
Write-Host "`n=== Infrastructure Statistics ===" -ForegroundColor Cyan
Write-Host "Total Servers: $($inventory.Count)"
Write-Host "Total Memory: $([Math]::Round(($inventory | Measure-Object -Property TotalMemoryGB -Sum).Sum, 2)) GB"
Write-Host "Total Cores: $(($inventory | Measure-Object -Property TotalCores -Sum).Sum)"
Write-Host "Total Storage: $([Math]::Round(($inventory | Measure-Object -Property TotalPhysicalDiskGB -Sum).Sum, 2)) GB"
Write-Host "Average Memory per Server: $([Math]::Round(($inventory | Measure-Object -Property TotalMemoryGB -Average).Average, 2)) GB"

# Группировка по ОС
Write-Host "`n=== OS Distribution ===" -ForegroundColor Cyan
$inventory | Group-Object -Property OperatingSystem | 
    ForEach-Object { Write-Host "$($_.Name): $($_.Count)" }
```

Эти примеры покрывают большинство практических сценариев использования скрипта. Адаптируйте их под свои нужды!
