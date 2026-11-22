@echo off
rem X-Perl development: the game loads X-Perl from a git worktree of this repository through two junctions,
rem
rem     <client>\Interface\AddOns\XPerl  ->  <main checkout>\.addon-link  ->  <active worktree>
rem
rem The first is made once per game client ("install"); switching worktrees only replaces the second, so every
rem client follows. Not packaged (.pkgmeta).
rem
rem     dev-link                          make the worktree this file is in the active one
rem     dev-link install <AddOns folder>  point a client's AddOns\XPerl at the active worktree; a real XPerl
rem                                       folder there is kept as XPerl.installed
rem     dev-link uninstall <AddOns folder> remove that link and put XPerl.installed back
rem     dev-link status [<AddOns folder>] show where the links point
setlocal EnableExtensions

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "COMMON="
for /f "delims=" %%G in ('git -C "%ROOT%" rev-parse --path-format^=absolute --git-common-dir 2^>nul') do set "COMMON=%%G"
if not defined COMMON (
	echo dev-link: "%ROOT%" is not a git checkout, or git is not on PATH.
	exit /b 1
)
rem The main checkout is the one that holds the shared .git folder
for %%G in ("%COMMON%\..") do set "MAIN=%%~fG"
set "LINK=%MAIN%\.addon-link"

if "%~1"=="" goto activate
if /i "%~1"=="install" goto install
if /i "%~1"=="uninstall" goto uninstall
if /i "%~1"=="status" goto status
goto usage

:activate
call :replace_junction "%LINK%" "%ROOT%" || exit /b 1
set "BRANCH="
for /f "delims=" %%G in ('git -C "%ROOT%" branch --show-current 2^>nul') do set "BRANCH=%%G"
echo Active worktree: "%ROOT%" [%BRANCH%]
echo In game: /reload, or restart the game if a TOC file changed.
exit /b 0

:install
call :addons_arg "%~2" || exit /b 1
if not exist "%LINK%\" (
	call :replace_junction "%LINK%" "%ROOT%" || exit /b 1
	echo Active worktree: "%ROOT%"
)
set "TARGET=%ADDONS%\XPerl"
call :is_junction "%TARGET%"
if not errorlevel 1 (
	rmdir "%TARGET%" || exit /b 1
) else if exist "%TARGET%" (
	if exist "%ADDONS%\XPerl.installed" (
		echo dev-link: "%TARGET%" and "%ADDONS%\XPerl.installed" both exist; move one of them away first.
		exit /b 1
	)
	ren "%TARGET%" XPerl.installed || exit /b 1
	echo Kept the installed X-Perl as "%ADDONS%\XPerl.installed".
)
mklink /J "%TARGET%" "%LINK%" >nul || exit /b 1
echo "%TARGET%" now loads the active worktree. Restart the game if it is running.
exit /b 0

:uninstall
call :addons_arg "%~2" || exit /b 1
set "TARGET=%ADDONS%\XPerl"
call :is_junction "%TARGET%"
if errorlevel 1 (
	echo dev-link: "%TARGET%" is not a link made by dev-link; left alone.
	exit /b 1
)
rmdir "%TARGET%" || exit /b 1
if exist "%ADDONS%\XPerl.installed" (
	ren "%ADDONS%\XPerl.installed" XPerl || exit /b 1
	echo Restored the installed X-Perl.
) else (
	echo Removed the link; there was no installed X-Perl to restore.
)
exit /b 0

:status
call :show "%LINK%"
if "%~2"=="" exit /b 0
call :addons_arg "%~2" || exit /b 1
call :show "%ADDONS%\XPerl"
exit /b 0

:usage
echo Usage: dev-link [install ^<AddOns folder^> ^| uninstall ^<AddOns folder^> ^| status [^<AddOns folder^>]]
echo   no argument: make "%ROOT%" the worktree the game loads
exit /b 1

rem ---------------------------------------------------------------------------------------------------------------

rem :replace_junction <link> <target> - (re)points a junction; refuses to touch a real folder
:replace_junction
call :is_junction "%~1"
if not errorlevel 1 (
	rmdir "%~1" || exit /b 1
) else if exist "%~1" (
	echo dev-link: "%~1" exists and is not a junction; left alone.
	exit /b 1
)
mklink /J "%~1" "%~2" >nul || exit /b 1
exit /b 0

rem :is_junction <path> - errorlevel 0 when path is a junction (a reparse point: "l" in its attributes)
:is_junction
if not exist "%~1" exit /b 1
set "ATTR="
for %%A in ("%~1") do set "ATTR=%%~aA"
if "%ATTR:l=%"=="%ATTR%" exit /b 1
exit /b 0

rem :addons_arg <folder> - sets ADDONS to the client's AddOns folder
:addons_arg
if "%~1"=="" (
	echo dev-link: give the client's Interface\AddOns folder, e.g. "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
	exit /b 1
)
if not exist "%~1\" (
	echo dev-link: "%~1" is not a folder.
	exit /b 1
)
set "ADDONS=%~f1"
if "%ADDONS:~-1%"=="\" set "ADDONS=%ADDONS:~0,-1%"
exit /b 0

rem :show <path> - prints where a junction points
:show
call :is_junction "%~1"
if errorlevel 1 (
	if exist "%~1" (echo "%~1" is a real folder, not a link) else (echo "%~1" does not exist)
	exit /b 0
)
for %%P in ("%~1\..") do set "PARENT=%%~fP"
for /f "tokens=2 delims=[]" %%T in ('dir /AL "%PARENT%" ^| findstr /I /C:" %~nx1 ["') do echo "%~1" -^> "%%T"
exit /b 0
