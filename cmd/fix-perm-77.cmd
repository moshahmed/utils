:: Fix permissions to let admin write files to pwd.
:: moshahmed at gmail

:: Made admin the owner
takeown /F . /A /R /D Y > nul:

:: This command is required
icacls . /reset /T  | grep --color Failed
icacls . /t /grant Everyone:(OI)(CI)F | grep --color Failed
icacls . /setowner "Administrators" /T /C  | grep --color Failed

accesschk.exe -qd .
