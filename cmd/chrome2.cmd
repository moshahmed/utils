@echo off
:: WHAT: Script to launch multiple chromes
if [%1] == [] (
  @echo USAGE: CHROME2.CMD GMAILID CTMPDIR URL
  @echo USAGE: CHROME2.CMD me                 .. default gmail
  goto :eof
)

:: Find CHROME_EXE
@for %%D in (
    C:\Progra~2\Google\Chrome\Application\chrome.exe
    C:\Progra~1\Google\Chrome\Application\chrome.exe
    C:\Progra~1\Google\Chrome\Applic~1\chrome.exe
    C:\Users\%USERNAME%\AppData\Local\Google\Chrome\Application\chrome.exe
  ) do (
  @IF EXIST %%D (
    @set CHROME_EXE=%%D
    @echo CHROME_EXE=%CHROME_EXE%
    @break
  )
)

@IF not EXIST %CHROME_EXE% (
  @echo NO CHROME_EXE=%CHROME_EXE%
  goto :eof
)

:: Get the args
set GMAILID=%1
set CTMPDIR=%2
set URL=%3

:: Start default chrome
if [%GMAILID%] == [me] (
  @start %CHROME_EXE% %URL%
  goto :eof
)

:: Setup new temp directory for GMAILID
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

:: Launch Chrome
@echo   CHROME_EXE  --enable-udd-profiles /N --user-data-dir=%CDATA% %URL%
@start %CHROME_EXE% --enable-udd-profiles /N --user-data-dir=%CDATA% %URL%
goto :eof

