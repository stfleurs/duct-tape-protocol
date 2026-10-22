@echo off
setlocal EnableExtensions
REM ==========================================================
REM  Duct Tape Protocol launcher (Godot 4.3-stable)
REM  - finds Godot 4.3 in common places or on PATH
REM  - on a fresh clone/zip, imports the project once first
REM    (.godot/ is not in git; without it the game's custom
REM     classes like LevelData are unknown and the game breaks)
REM  - set GODOT_EXE=C:\path\to\Godot_v4.3-stable_win64.exe
REM    to point it at a specific Godot
REM ==========================================================
cd /d "%~dp0"

set "GODOT="
set "GODOT_CONSOLE="

if defined GODOT_EXE if exist "%GODOT_EXE%" set "GODOT=%GODOT_EXE%"

if not defined GODOT call :try "%~dp0Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%~dp0..\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%USERPROFILE%\.godot4\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%USERPROFILE%\Desktop\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%USERPROFILE%\Desktop\Godot_v4.3-stable_win64\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%USERPROFILE%\Downloads\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%USERPROFILE%\Downloads\Godot_v4.3-stable_win64\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%USERPROFILE%\Documents\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%USERPROFILE%\Godot\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%LOCALAPPDATA%\Godot\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "C:\Godot\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "C:\Godot_v4.3-stable_win64\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%ProgramFiles%\Godot\Godot_v4.3-stable_win64.exe"
if not defined GODOT call :try "%USERPROFILE%\scoop\apps\godot\current\godot.exe"
if not defined GODOT call :try "%ProgramFiles(x86)%\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not defined GODOT for /f "delims=" %%G in ('where Godot_v4.3-stable_win64.exe 2^>nul') do if not defined GODOT set "GODOT=%%G"
if not defined GODOT for /f "delims=" %%G in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%G"
if not defined GODOT for /f "delims=" %%G in ('where godot4 2^>nul') do if not defined GODOT set "GODOT=%%G"

if not defined GODOT (
  echo.
  echo  Could not find Godot 4.3.
  echo.
  echo  1. Download "Godot Engine 4.3-stable, Windows 64-bit, Standard" ^(not .NET^):
  echo     https://github.com/godotengine/godot/releases/tag/4.3-stable
  echo     ^(file: Godot_v4.3-stable_win64.exe.zip^)
  echo  2. Unzip it and put BOTH .exe files ^(Godot_v4.3-stable_win64.exe and
  echo     Godot_v4.3-stable_win64_console.exe^) in this game folder,
  echo     or in %USERPROFILE%\.godot4\
  echo  3. Run this file again.
  echo.
  pause
  exit /b 1
)

REM The console build sits next to the normal one in the official zip
set "GODOT_CONSOLE=%GODOT:.exe=_console.exe%"
if not exist "%GODOT_CONSOLE%" set "GODOT_CONSOLE=%GODOT%"

echo Using Godot: %GODOT%

if not exist ".godot\global_script_class_cache.cfg" (
  echo First run on this PC: importing the project, about 30 seconds...
  "%GODOT_CONSOLE%" --headless --path . --import
  if not exist ".godot\global_script_class_cache.cfg" (
    echo.
    echo  Import did not finish. Open the project once in the Godot 4.3 editor
    echo  ^("%GODOT%" -e --path .^), wait for it to load, close it, then try again.
    pause
    exit /b 1
  )
)

REM "--path ." (not "%~dp0", whose trailing backslash breaks the quote)
start "" "%GODOT%" --path .
exit /b 0

:try
if exist "%~1" set "GODOT=%~1"
exit /b 0
