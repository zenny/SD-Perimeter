@ECHO OFF
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL /t REG_SZ /d "" /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v EnableAutoProxyResultCache /f

start /d "%PROGRAMFILES%\Internet Explorer" IEXPLORE.EXE github.com
set SleepTime=5
Timeout /T %SleepTime% /NoBreak>NUL
taskkill /IM iexplore.exe /FI "WINDOWTITLE eq GitHub
