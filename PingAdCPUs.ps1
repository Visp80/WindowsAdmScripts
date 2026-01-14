<#
.SYNOPSIS
    Проверка доступности компьютеров домена через ping (без модуля AD)
.DESCRIPTION
    Скрипт получает список компьютеров из домена через ADSI и проверяет их доступность
#>

# Получаем текущий домен
try {
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
    $domainName = $domain.Name
    Write-Host "Подключение к домену: $domainName" -ForegroundColor Cyan
} catch {
    Write-Host "Ошибка: Не удалось определить домен. Убедитесь, что компьютер входит в домен." -ForegroundColor Red
    exit
}

# Создаём ADSI searcher для поиска компьютеров
Write-Host "Получение списка компьютеров из домена..." -ForegroundColor Cyan

$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.Filter = "(&(objectCategory=computer))"
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Add("name") | Out-Null
$searcher.PropertiesToLoad.Add("cn") | Out-Null

# Получаем все компьютеры
$computers = @()
try {
    $searchResults = $searcher.FindAll()
    foreach ($result in $searchResults) {
        $computerName = $result.Properties["name"][0]
        if ($computerName) {
            $computers += $computerName
        }
    }
    $searchResults.Dispose()
} catch {
    Write-Host "Ошибка при получении списка компьютеров: $_" -ForegroundColor Red
    exit
}

$computers = $computers | Sort-Object

# Создаём массив для результатов
$results = @()

# Счётчики
$total = $computers.Count
$online = 0
$offline = 0
$current = 0

Write-Host "Найдено компьютеров: $total" -ForegroundColor Yellow
Write-Host "Начинаем проверку..." -ForegroundColor Cyan
Write-Host ""

# Проверяем каждый компьютер
foreach ($computer in $computers) {
    $current++
    Write-Progress -Activity "Проверка доступности компьютеров" -Status "Проверка: $computer" -PercentComplete (($current / $total) * 100)
    
    # Пингуем компьютер (1 попытка, таймаут 1 секунда)
    $pingResult = Test-Connection -ComputerName $computer -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if ($pingResult) {
        Write-Host "[OK] $computer" -ForegroundColor Green
        $status = "Online"
        $online++
    } else {
        Write-Host "[FAIL] $computer" -ForegroundColor Red
        $status = "Offline"
        $offline++
    }
    
    # Добавляем результат в массив
    $results += [PSCustomObject]@{
        ComputerName = $computer
        Status = $status
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

Write-Progress -Activity "Проверка доступности компьютеров" -Completed

# Выводим статистику
Write-Host ""
Write-Host "=== СТАТИСТИКА ===" -ForegroundColor Cyan
Write-Host "Всего компьютеров: $total" -ForegroundColor Yellow
Write-Host "Доступны (Online): $online" -ForegroundColor Green
Write-Host "Недоступны (Offline): $offline" -ForegroundColor Red
Write-Host ""

# Экспортируем результаты в CSV
$reportPath = ".\ComputerPingReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
Write-Host "Отчёт сохранён: $reportPath" -ForegroundColor Green

# Опционально: показываем только недоступные компьютеры
Write-Host ""
$showOffline = Read-Host "Показать список недоступных компьютеров? (Y/N)"
if ($showOffline -eq "Y" -or $showOffline -eq "y") {
    Write-Host ""
    Write-Host "=== НЕДОСТУПНЫЕ КОМПЬЮТЕРЫ ===" -ForegroundColor Red
    $results | Where-Object {$_.Status -eq "Offline"} | ForEach-Object {
        Write-Host $_.ComputerName -ForegroundColor Red
    }
}