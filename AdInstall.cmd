@echo off
REM Завантаження AnyDesk
powershell -Command "Invoke-WebRequest -Uri 'https://download.anydesk.com/AnyDesk.exe' -OutFile '%TEMP%\AnyDesk.exe'"

REM Встановлення в кастомну папку
set INSTALL_PATH="C:\Program Files\AnyDesk"
set PASSWORD=7777777

REM Тиха ?нсталяц?я
"%TEMP%\AnyDesk.exe" --install "%INSTALL_PATH%" --silent --start-with-win

REM Оч?кування завершення встановлення
timeout /t 5 /nobreak

REM Налаштування пароля
%INSTALL_PATH%\AnyDesk.exe --set-password %PASSWORD%

REM Видалення ?нсталятора
del "%TEMP%\AnyDesk.exe"

