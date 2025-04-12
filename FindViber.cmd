@echo off
setlocal enabledelayedexpansion
echo.
for /d %%i in (C:\Users\*) do (
    echo "%%i"
	rem dir %%i\AppData\Roaming\ViberPC
	for /d %%v in (%%i\AppData\Roaming\ViberPC\38*) do (
	echo "%%v"
	dir %%v\viber.db
	)
    echo.
)

echo Scan complete.
rem pause