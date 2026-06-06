# paid_software_detector_clean_updates.py
# Ультра-чистий детектор платного ПО для Windows
# НЕ відображає оновлення Office/Windows (Security Update, Update for, Definition Update тощо)
# Запускати від імені адміністратора

import winreg
import os
import sys
from datetime import datetime
import subprocess
import json
import re

# Шляхи до реестру
UNINSTALL_KEYS = [
    r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    r"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
]

# Відоме платне ПО (основні пакети)
PAID_PATTERNS = [
    "Microsoft Office", "Microsoft Project", "Microsoft Visio",
    "Office 16 Click-to-Run", "RAD Studio", "1С:Підприємство", "1C:Enterprise",
    "Oracle.*Java", "Java.*Oracle", "Office Tab Enterprise"
]

# Системне сміття + усі оновлення Office/Windows
JUNK_AND_UPDATES_PATTERNS = [
    # Системні runtime та компоненти
    "Microsoft.NET.Native", "Microsoft.UI.Xaml", "Microsoft.VCLibs", "Microsoft.WinAppRuntime",
    "Microsoft.Services.Store", "Microsoft.DirectX", "Microsoft.HEIF", "Microsoft.HEVC",
    "Microsoft.AV1", "Microsoft.VP9", "Microsoft.MPEG2", "Microsoft.WebMedia", "Microsoft.Webp",
    "Microsoft.RawImage", "Microsoft.Widgets",
    "Microsoft.WindowsAlarms", "Microsoft.WindowsCalculator", "Microsoft.WindowsCamera",
    "Microsoft.WindowsMaps", "Microsoft.WindowsNotepad", "Microsoft.WindowsSoundRecorder",
    "Microsoft.WindowsScan", "Microsoft.Paint", "Microsoft.ScreenSketch", "Microsoft.StickyNotes",
    "Microsoft.BingWeather", "Microsoft.YourPhone", "Microsoft.ZuneMusic", "Microsoft.Xbox",
    "Visual C\\+\\+.*Redistributable", "Visual C\\+\\+.*Runtime",
    # Усі види оновлень Office/Windows
    "Security Update for", "Update for", "Definition Update for",
    "KB[0-9]+",  # будь-який патч з номером KB
    "Korrekturhilfen", "Proofing", "MUI", "Language", "Языковой пакет",
    "Web Components", "Необходимые компоненты для SSDT", "Обозреватель SQL Server",
    "Объекты управления Microsoft SQL Server", "Политики Microsoft SQL Server",
    "Системные типы Microsoft SQL Server", "Среда выполнения Microsoft Edge WebView2"
]

def regex_match(patterns, text):
    for pat in patterns:
        if re.search(pat, text, re.IGNORECASE):
            return True
    return False

def get_registry_programs():
    programs = []
    for base_key in [winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER]:
        for key_path in UNINSTALL_KEYS:
            try:
                key = winreg.OpenKey(base_key, key_path)
                for i in range(winreg.QueryInfoKey(key)[0]):
                    subkey_name = winreg.EnumKey(key, i)
                    try:
                        subkey = winreg.OpenKey(key, subkey_name)
                        display_name = None
                        display_version = ""
                        publisher = ""
                        try:
                            display_name = winreg.QueryValueEx(subkey, "DisplayName")[0]
                        except FileNotFoundError:
                            continue
                        try:
                            display_version = winreg.QueryValueEx(subkey, "DisplayVersion")[0]
                        except FileNotFoundError:
                            pass
                        try:
                            publisher = winreg.QueryValueEx(subkey, "Publisher")[0]
                        except FileNotFoundError:
                            pass
                        programs.append({
                            "name": display_name.strip(),
                            "version": str(display_version).strip(),
                            "publisher": publisher.strip(),
                            "source": "Registry"
                        })
                        subkey.Close()
                    except:
                        continue
                key.Close()
            except FileNotFoundError:
                continue
    return programs

def get_store_apps():
    ps_command = '''
    Get-AppxPackage | Where-Object { $_.NonRemovable -eq $false } |
    Select-Object Name, Version, Publisher | ConvertTo-Json
    '''
    try:
        result = subprocess.run(["powershell", "-Command", ps_command],
                                capture_output=True, text=True, encoding='utf-8')
        if result.returncode == 0:
            data = json.loads(result.stdout)
            if not isinstance(data, list):
                data = [data]
            return [{"name": app.get("Name", ""), "version": app.get("Version", ""),
                     "publisher": app.get("Publisher", ""), "source": "Store"} for app in data if app.get("Name")]
    except:
        pass
    return []

def is_junk_or_update(name):
    return regex_match(JUNK_AND_UPDATES_PATTERNS, name)

def is_paid(name):
    return regex_match(PAID_PATTERNS, name)

def main():
    desktop = os.path.join(os.path.expanduser("~"), "Desktop")
    report_path = os.path.join(desktop, "paid_report_clean.txt")

    paid_software = []
    free_software = []

    print("Збір програм з реестру...")
    registry_programs = get_registry_programs()

    print("Збір Store-додатків...")
    store_apps = get_store_apps()

    all_programs = registry_programs + store_apps

    for prog in all_programs:
        name = prog["name"]
        if not name or is_junk_or_update(name):
            continue

        version = prog["version"] or "(немає версії)"
        publisher = prog["publisher"] or "(немає видавця)"
        source = " (Store)" if prog["source"] == "Store" else ""

        entry = f"{name} | {version} | {publisher}{source}"

        if is_paid(name):
            paid_software.append(entry)
        else:
            free_software.append(entry)

    # Усунення дублікатів (зберігаємо унікальні)
    paid_software = sorted(list(set(paid_software)))
    free_software = sorted(list(set(free_software)))

    # Запис звіту
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("ULTRA-CLEAN PAID SOFTWARE REPORT - WINDOWS (без оновлень Office/Windows)\n")
        f.write(f"Date: {datetime.now().strftime('%m/%d/%Y %H:%M:%S')}\n")
        f.write("=" * 75 + "\n\n")

        f.write("PROPRIETARY/FREE DRIVERS:\n")
        f.write("-----------------------------------------------------------------------\n")
        f.write("Драйвери не аналізуються в цій версії (вільні за замовчуванням)\n\n")

        f.write("WINDOWS OPERATING SYSTEM:\n")
        f.write("-----------------------------------------------------------------------\n")
        f.write("Microsoft Windows — платна ОС\n\n")

        f.write("SIGNIFICANT PAID SOFTWARE:\n")
        f.write("-----------------------------------------------------------------------\n")
        if paid_software:
            for line in paid_software:
                f.write(line + "\n")
        else:
            f.write("Не виявлено (окрім Windows)\n")
        f.write("\n")

        f.write("FREE SOFTWARE (встановлено):\n")
        f.write("-----------------------------------------------------------------------\n")
        if free_software:
            for line in free_software:
                f.write(line + "\n")
        else:
            f.write("Не виявлено\n")

        f.write(f"\nЗвіт збережено: {report_path}")

    print(f"\nГотово! Чистий звіт без оновлень збережено: {report_path}")

if __name__ == "__main__":
    try:
        main()
    except PermissionError:
        print("Помилка: Запустіть скрипт від імені адміністратора.")
        sys.exit(1)