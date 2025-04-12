@echo off
setlocal enabledelayedexpansion
echo.
powershell -Command "Get-ADComputer -Filter * | Select-Object -ExpandProperty Name" > computers.txt
for /f "tokens=*" %%c in (computers.txt) do (
   echo "%%c"
     
		for /d %%i in (\\%%c\C$\Users\*) do (
				echo "%%i"
			rem dir %%i\AppData\Roaming\ViberPC
			for /d %%v in (%%i\AppData\Roaming\ViberPC\38*) do (
				echo "%%v"
				dir %%v\viber.db
				)
			echo.
			)
		)
	

del computers.txt
rem pause