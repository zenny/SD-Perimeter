@ECHO OFF
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL /t REG_SZ /d "http://10.255.4.1/home-sdp.pac" /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v EnableAutoProxyResultCache /t REG_DWORD /d "0" /f

start /d "%PROGRAMFILES%\Internet Explorer" IEXPLORE.EXE github.com
set SleepTime=5
Timeout /T %SleepTime% /NoBreak>NUL
taskkill /IM iexplore.exe /FI "WINDOWTITLE eq GitHub
