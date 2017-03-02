@echo off
:: WHAT: Script to launch multiple chromes
:: Find CHROME_EXE
:: set CHROME_EXE using registry
  @for /f "delims=" %%a in ('
    regtool list -v "/machine/SOFTWARE/Microsoft/Windows/CurrentVersion/App Paths/chrome.exe" ^| ^
    perl -ne "print if s/Path.*=\s*//"
  ') do (
    @set CHROME_DIR=%%a
  )

  @for /f "delims=" %%a in ('
    cygpath -dasm %CHROME_DIR%/*.exe
  ') do (
    @set CHROME_EXE=%%a
  )

:: fallback search for CHROME_EXE
  @for %%D in (
      %CHROME_EXE%
      C:\Progra~2\Google\Chrome\Application\chrome.exe
      C:\Progra~1\Google\Chrome\Application\chrome.exe
      C:\Progra~1\Google\Chrome\Applic~1\chrome.exe
      C:\Users\%USERNAME%\AppData\Local\Google\Chrome\Application\chrome.exe
    ) do (
    @IF EXIST %%D (
      @set  CHROME_EXE=%%D
      @echo CHROME_EXE=%CHROME_EXE%
      goto :found_chrome_exe
    )
  )

:: Final check for CHROME_EXE
  @IF not EXIST %CHROME_EXE% (
    @echo NO CHROME_EXE=%CHROME_EXE%
    goto :eof
  )
:found_chrome_exe
:: Get the args
  if [%1] == [] (
    @echo USAGE: CHROME2.CMD GMAILID CTMPDIR URL
    @echo USAGE: CHROME2.CMD me                 .. default gmail
    goto :eof
  )
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
:: Set chrome data dir
  set     CDATA=%CTMPDIR%\chrome2-data-%GMAILID%
  @echo   CDATA=%CDATA%
  @mkdir %CDATA%
:: Set start url
  if [%URL%] == [] (
    set URL=gmail.com
  )
:: Launch Chrome
  @echo   CHROME_EXE  --enable-udd-profiles /N --user-data-dir=%CDATA% %URL%
  @start %CHROME_EXE% --enable-udd-profiles /N --user-data-dir=%CDATA% %URL%
  goto :eof
