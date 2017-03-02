@echo off
:: Script to launch multiple independent copies of chromes on windows.
:: GPL(C) 2017 moshahmed

if [%1] == [] (
  @echo USAGE: CHROME2.CMD GMAILID CTMPDIR URL
  goto :eof
)

set GMAILID=%1
set CTMPDIR=%2
set URL=%3

if [%CTMPDIR%] == [] (
  set CTMPDIR=%TEMP%
)
@IF not EXIST %CTMPDIR%\nul (
  @echo chrome2.cmd missing CTMPDIR=%CTMPDIR%
  goto :eof
)

if [%URL%] == [] (
  set URL=gmail.com
)

set     CDATA=%CTMPDIR%\chrome2-data-%GMAILID%
@echo   CDATA=%CDATA%
@mkdir %CDATA%

@rem Launch Chrome
@for %%D in (
    C:\Progra~2\Google\Chrome\Application\chrome.exe
    C:\Progra~1\Google\Chrome\Application\chrome.exe
    C:\Progra~1\Google\Chrome\Applic~1\chrome.exe
    C:\Users\%USERNAME%\AppData\Local\Google\Chrome\Application\chrome.exe
  ) do (
  @IF EXIST %%D (
    @echo Found CHROME_EXE=%%D
    @echo CHROME_EXE --enable-udd-profiles /N --user-data-dir=%CDATA% %URL%
    @start       %%D --enable-udd-profiles /N --user-data-dir=%CDATA% %URL%
    @break
  )
  goto :eof
)
