# Get-Invent-Optimized - Advanced Hardware Inventory Tool

## Описание

Оптимизированная версия скрипта инвентаризации оборудования с использованием современных практик PowerShell и расширенным функционалом.

## Основные улучшения по сравнению с оригинальной версией

### ✅ Технические улучшения

1. **Миграция на CIM вместо WMI**
   - Использование `Get-CimInstance` вместо устаревшего `Get-WmiObject`
   - Лучшая производительность и надежность
   - Поддержка удаленных подключений через WinRM

2. **Полная обработка ошибок**
   - Try-Catch блоки для всех операций
   - Детальные сообщения об ошибках
   - Graceful degradation при недоступности компонентов

3. **Управление сессиями**
   - Безопасное создание и закрытие CIM сессий
   - Настраиваемый таймаут подключения
   - Поддержка учетных данных

4. **Pipeline поддержка**
   - Обработка множества компьютеров через pipeline
   - ValueFromPipeline и ValueFromPipelineByPropertyName

### 📊 Расширенный функционал

1. **Дополнительная информация**
   - Серийные номера (компьютер, диски, память)
   - Информация о BIOS/UEFI
   - Версия и дата драйверов
   - Uptime системы
   - Типы памяти (DDR3/DDR4/DDR5)
   - Статус сетевых адаптеров

2. **Экспорт в множество форматов**
   - CSV - для работы с Excel
   - JSON - для интеграции с API
   - HTML - красивые отчеты с CSS
   - XML - для обмена данными

3. **Progress Bar**
   - Визуальное отображение прогресса сбора данных
   - Информация о текущей операции

4. **Умное форматирование**
   - Автоматическое форматирование байтов (B, KB, MB, GB, TB)
   - Округление значений
   - Человекочитаемые статусы

## Требования

- **PowerShell**: версия 5.1 или выше
- **Права**: администратора для локального сбора, соответствующие права для удаленного
- **Протоколы**: WinRM для удаленных подключений
- **ОС**: Windows 7/Server 2008 R2 и выше

## Установка

```powershell
# Скачайте скрипт
Invoke-WebRequest -Uri "URL_TO_SCRIPT" -OutFile "Get-Invent-Optimized.ps1"

# Или клонируйте репозиторий
git clone https://github.com/your-repo/Get-Invent-Optimized.git
cd Get-Invent-Optimized
```

## Использование

### Базовые примеры

```powershell
# Локальная инвентаризация
.\Get-Invent-Optimized.ps1

# Удаленный компьютер
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01"

# Детальный отчет
.\Get-Invent-Optimized.ps1 -Full

# С учетными данными
$cred = Get-Credential
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Credential $cred -Full
```

### Экспорт результатов

```powershell
# Экспорт в CSV
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -ExportPath "C:\Reports\inventory.csv"

# Экспорт в JSON
.\Get-Invent-Optimized.ps1 -Full -ExportPath "C:\Reports\inventory.json"

# Экспорт в HTML с красивым форматированием
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Full -ExportPath "C:\Reports\inventory.html"

# Экспорт в XML
.\Get-Invent-Optimized.ps1 -ExportPath "C:\Reports\inventory.xml"
```

### Работа с множественными компьютерами

```powershell
# Через массив
$computers = @("SERVER01", "SERVER02", "SERVER03")
.\Get-Invent-Optimized.ps1 -ComputerName $computers -Full

# Через pipeline
Get-Content "servers.txt" | .\Get-Invent-Optimized.ps1 -Full

# Из Active Directory
Get-ADComputer -Filter "OperatingSystem -like '*Server*'" | 
    Select-Object -ExpandProperty Name | 
    .\Get-Invent-Optimized.ps1 -Credential $cred -ExportPath "C:\Reports\servers.csv"
```

### Расширенные сценарии

```powershell
# Инвентаризация с таймаутом и экспортом
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" `
                            -Credential $cred `
                            -Timeout 60 `
                            -Full `
                            -ExportPath "C:\Reports\report.html" `
                            -Verbose

# Сохранение результатов в переменную для дальнейшей обработки
$inventory = .\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Full

# Фильтрация компьютеров с малым объемом свободного места
$inventory | Where-Object { $_.TotalMemoryGB -lt 16 }

# Сортировка по количеству ядер
$inventory | Sort-Object -Property TotalCores -Descending
```

## Параметры

| Параметр | Тип | Описание | По умолчанию |
|----------|-----|----------|--------------|
| `ComputerName` | String[] | Имя компьютера(ов) для инвентаризации | Локальный компьютер |
| `Credential` | PSCredential | Учетные данные для подключения | Текущий пользователь |
| `Full` | Switch | Показать детальную информацию | False |
| `ExportPath` | String | Путь для экспорта (.csv, .json, .html, .xml) | Не экспортируется |
| `Timeout` | Int | Таймаут подключения в секундах | 30 |

## Собираемая информация

### Краткий отчет (Summary)

- **Основная информация**: имя, домен, владелец, производитель, модель, серийный номер
- **ОС**: название, версия, архитектура, дата установки, последняя перезагрузка, uptime
- **Материнская плата**: производитель, модель, версия
- **BIOS**: версия, дата выпуска
- **Процессор**: модель, количество процессоров, ядер, потоков, частота
- **Память**: общий объем (MB/GB), количество слотов
- **Диски**: количество физических/логических дисков, общий объем
- **Видеокарты**: количество, общий объем видеопамяти
- **Сеть**: количество адаптеров
- **Дата сбора**: timestamp

### Детальный отчет (-Full)

#### Модули памяти
- Производитель, артикул, серийный номер
- Объем, частота
- Тип (DDR3/DDR4/DDR5)
- Form Factor (DIMM/SODIMM)
- Слот установки

#### Физические диски
- Модель, серийный номер
- Размер, интерфейс, тип носителя
- Количество разделов, статус

#### Логические диски
- Буква диска, метка тома
- Файловая система
- Общий размер, свободное место, занято
- Процент свободного места
- Тип диска (локальный/сетевой/съемный/CD-ROM)

#### Видеокарты
- Название, видеопроцессор
- Объем видеопамяти
- Текущее разрешение и частота обновления
- Версия драйвера и дата
- Статус

#### Сетевые адаптеры
- Название, производитель
- MAC-адрес
- Скорость соединения
- Тип адаптера
- Статус подключения

## Вывод

### Консольный вывод

```
Processing: SERVER01

Collecting data from SERVER01...
✓ Successfully collected inventory from SERVER01

========== INVENTORY SUMMARY ==========
ComputerName      : SERVER01
Domain           : company.local
Owner            : Administrator
Manufacturer     : Dell Inc.
Model            : PowerEdge R740
...

========== DETAILED INFORMATION ==========

--- Memory Modules ---
ComputerName Manufacturer PartNumber    Capacity Speed    MemoryType
------------ ------------ ----------    -------- -----    ----------
SERVER01     Samsung      M393A2K43DB3  16 GB    2933 MHz DDR4
...
```

### Экспортированные файлы

- **CSV**: Табличный формат для Excel/Google Sheets
- **JSON**: Структурированные данные для API
- **HTML**: Отчет с CSS стилями и таблицами
- **XML**: Объекты PowerShell для импорта

## Troubleshooting

### Проблема: "Access Denied" на удаленном компьютере

**Решение:**
```powershell
# Убедитесь, что WinRM включен на удаленном компьютере
Enable-PSRemoting -Force

# Добавьте компьютер в TrustedHosts (если не в домене)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "SERVER01" -Force

# Используйте учетные данные администратора
$cred = Get-Credential
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Credential $cred
```

### Проблема: Таймаут подключения

**Решение:**
```powershell
# Увеличьте таймаут
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Timeout 120

# Проверьте доступность компьютера
Test-NetConnection -ComputerName "SERVER01" -Port 5985
```

### Проблема: Неполные данные

**Решение:**
```powershell
# Запустите с verbose для диагностики
.\Get-Invent-Optimized.ps1 -ComputerName "SERVER01" -Verbose

# Проверьте права доступа
# Некоторые данные требуют администраторских прав
```

## Производительность

- **Локальный сбор**: 2-5 секунд
- **Удаленный сбор** (один компьютер): 5-15 секунд
- **Множественные компьютеры**: последовательная обработка

**Рекомендации:**
- Для инвентаризации большого количества компьютеров используйте параллельную обработку
- Увеличьте таймаут для медленных подключений
- Используйте `-Verbose` для диагностики проблем

## Безопасность

- ✅ Не хранит учетные данные
- ✅ Использует безопасные протоколы (WinRM/CIM)
- ✅ Поддержка Kerberos в доменной среде
- ✅ Автоматическое закрытие сессий
- ⚠️ Требует административных прав для полного сбора данных

## Сравнение с оригинальной версией

| Функция | Оригинал | Оптимизированная |
|---------|----------|------------------|
| WMI/CIM | Get-WmiObject (устаревший) | Get-CimInstance (современный) |
| Обработка ошибок | ❌ Нет | ✅ Полная |
| Pipeline поддержка | ❌ Нет | ✅ Да |
| Учетные данные | ❌ Нет | ✅ Да |
| Экспорт | ❌ Нет | ✅ CSV, JSON, HTML, XML |
| Progress Bar | ❌ Нет | ✅ Да |
| Детальная информация | Частично | Полная |
| Множественные компьютеры | ❌ Нет | ✅ Да |
| Форматирование размеров | Неточное | Точное (B/KB/MB/GB/TB) |
| Uptime | ❌ Нет | ✅ Да |
| Серийные номера | Частично | Полностью |
| Статусы | ❌ Нет | ✅ Да |
| Verbose режим | ❌ Нет | ✅ Да |

## Лицензия

MIT License - свободное использование и модификация

## Автор

Оптимизированная версия на основе [Get-Invent](https://github.com/Lifailon/Get-Invent)

## Обратная связь

Если вы нашли баг или хотите предложить улучшение:
1. Откройте Issue в GitHub
2. Создайте Pull Request
3. Напишите в комментариях

## Changelog

### Version 2.0 (Current)
- ✅ Миграция на CIM
- ✅ Полная обработка ошибок
- ✅ Pipeline поддержка
- ✅ Экспорт в 4 формата
- ✅ Расширенная информация
- ✅ Progress Bar
- ✅ Verbose режим

### Version 1.0 (Original)
- Базовый сбор информации через WMI
- Локальная и удаленная инвентаризация
