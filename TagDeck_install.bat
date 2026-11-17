@echo off
setlocal EnableExtensions
rem ======================================================================================
rem  TagDeck - install / update (Windows).   (c) 2026 Thanasis Karageorgos
rem  Put this file next to TagDeck.py (or TagDeck_<version>.py) and double-click it. With several versions
rem  in the folder the NEWEST one is installed (1.10 is newer than 1.9).
rem  The program goes into the TagDeck folder next to this file (TagDeck.exe, with its icon
rem  and its version in the file properties).
rem    - not there yet  -> new install (settings, undo logs and caches of an older install,
rem                        also of the old SeratoTagger folder, are copied over)
rem    - already there  -> update: ONLY TagDeck.exe and _internal are replaced.
rem  Settings, config_backups, undo_logs, crate_backups, caches and the log are never deleted.
rem  Before an update the settings are copied to TagDeck\config_backups with the date.
rem  Faster builds: the build files are kept in %LOCALAPPDATA%\TagDeck_build and the Python
rem  packages are installed only when one is missing. "TagDeck_install.bat clean" starts
rem  the build from zero (if a build ever behaves oddly).
rem ======================================================================================
cd /d "%~dp0"
set "HERE=%~dp0"
set "HERE=%HERE:~0,-1%"
set "DEST=%HERE%\TagDeck"
set "OLDDEST=%HERE%\SeratoTagger"
set "WORK=%LOCALAPPDATA%\TagDeck_build"

rem ---- the newest TagDeck_<version>.py next to this file
set "SRCPY="
for /f "delims=" %%f in ('powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%HERE%' -Filter 'TagDeck_*.py' | Sort-Object { try { [version]($_.BaseName.Substring(8)) } catch { [version]'0.0' } } | Select-Object -Last 1 -ExpandProperty Name"') do set "SRCPY=%%f"
if not defined SRCPY if exist "%HERE%\TagDeck.py" set "SRCPY=TagDeck.py"
if not defined SRCPY if exist "%HERE%\serato_tagger_pilot.py" set "SRCPY=serato_tagger_pilot.py"
if not defined SRCPY (
  echo No TagDeck_^<version^>.py was found next to this file: %HERE%
  pause
  exit /b 1
)
set "VER="
for /f "delims=" %%v in ('powershell -NoProfile -Command "$n='%SRCPY%'; if ($n -like 'TagDeck_*') { $n.Substring(8, $n.Length - 11) } else { $m = Select-String -LiteralPath '%HERE%\%SRCPY%' -Pattern '^APP_VERSION = .([0-9.]+).' | Select-Object -First 1; if ($m) { $m.Matches[0].Groups[1].Value } else { '?' } }"') do set "VER=%%v"
set "OLDVER="
if exist "%DEST%\TagDeck.exe" for /f "delims=" %%v in ('powershell -NoProfile -Command "(Get-Item -LiteralPath '%DEST%\TagDeck.exe').VersionInfo.ProductVersion"') do set "OLDVER=%%v"
echo.
echo Installing TagDeck %VER%  (%SRCPY%)
if defined OLDVER echo Installed now: TagDeck %OLDVER%
if not defined OLDVER if exist "%DEST%\TagDeck.exe" echo Installed now: TagDeck (version not known)
echo Program folder: %DEST%

rem ---- the program must be closed while its files are replaced
:waitclose
set "RUNNING="
tasklist /FI "IMAGENAME eq TagDeck.exe" 2>nul | find /I "TagDeck.exe" >nul && set "RUNNING=1"
tasklist /FI "IMAGENAME eq SeratoTagger.exe" 2>nul | find /I "SeratoTagger.exe" >nul && set "RUNNING=1"
if not defined RUNNING goto build
echo.
echo TagDeck (or the old Serato Tagger) is running. Close it, then press a key here.
pause >nul
goto waitclose

:build
set "CLEANARG="
if /I "%~1"=="clean" (
  set "CLEANARG=--clean"
  if exist "%WORK%" rmdir /s /q "%WORK%"
)
if not exist "%WORK%" mkdir "%WORK%"
echo.
echo Checking the Python packages...
py -c "import PySide6, mutagen, numpy, av, PyInstaller" >nul 2>&1
if errorlevel 1 (
  echo Installing the missing Python packages...
  py -m pip install pyinstaller PySide6 mutagen numpy av || goto error
) else (
  echo All there.
)
rem ---- the theme fonts (Inter, Space Grotesk, free OFL licence) are built into the program.
rem      1.0: looked for next to this file, in the program folders and in the build folder;
rem      downloaded (once) into the build folder, which is always writable.
set "FONTDIR="
for %%d in ("%HERE%\fonts" "%DEST%\fonts" "%OLDDEST%\fonts" "%WORK%\fonts") do if not defined FONTDIR if exist "%%~d\Inter.ttf" set "FONTDIR=%%~d"
if not defined FONTDIR call :getfonts
if not defined FONTDIR if exist "%WORK%\fonts\Inter.ttf" set "FONTDIR=%WORK%\fonts"
set "FONTARG="
if defined FONTDIR set FONTARG=--add-data "%FONTDIR%;fonts"
if defined FONTDIR echo Theme fonts: %FONTDIR%
if not defined FONTDIR echo The fonts could not be found or downloaded: the program uses the Windows fonts instead.
rem ---- always the same name inside the build folder, so the kept build files can be reused
copy /y "%HERE%\%SRCPY%" "%WORK%\TagDeck.py" >nul || goto error
set "ICONARG="
py "%WORK%\TagDeck.py" --write-icon "%WORK%\tagdeck.ico"
if exist "%WORK%\tagdeck.ico" set ICONARG=--icon "%WORK%\tagdeck.ico"
if not defined ICONARG echo The icon could not be made: the .exe gets the standard icon.
set "VERARG="
py "%WORK%\TagDeck.py" --write-version-file "%WORK%\version.txt"
if exist "%WORK%\version.txt" set VERARG=--version-file "%WORK%\version.txt"
echo.
echo Building TagDeck %VER% (the first time takes a few minutes, later ones less)...
py -m PyInstaller --noconfirm %CLEANARG% --onedir --windowed --name TagDeck %ICONARG% %VERARG% ^
  --distpath "%WORK%\dist" --workpath "%WORK%\build" --specpath "%WORK%" ^
  --collect-all av %FONTARG% ^
  --exclude-module tkinter --exclude-module PIL --exclude-module yaml ^
  --exclude-module soundfile --exclude-module miniaudio --exclude-module serato_tools ^
  "%WORK%\TagDeck.py" || goto error
if not exist "%WORK%\dist\TagDeck\TagDeck.exe" goto error

if exist "%DEST%\tagdeck_config.json" goto update
if exist "%DEST%\tagger_config.json" goto update

rem ---- new install: create the folder, take over an older install if there is one
if not exist "%DEST%" mkdir "%DEST%"
if not exist "%DEST%" goto error
set "SRC="
if exist "%HERE%\install_dir.txt" set /p SRC=<"%HERE%\install_dir.txt"
if defined SRC call :checksrc
if not defined SRC if exist "%OLDDEST%\tagger_config.json" set "SRC=%OLDDEST%"
if not defined SRC if exist "%HERE%\dist\SeratoTagger\tagger_config.json" set "SRC=%HERE%\dist\SeratoTagger"
if not defined SRC if exist "%HERE%\SeratoTagger.exe" if exist "%HERE%\tagger_config.json" set "SRC=%HERE%"
if not defined SRC (
  echo.
  echo New install - no older settings were found.
  goto copyprog
)
echo.
echo Taking over settings, undo logs and caches from: %SRC%
echo (copied, the originals stay where they are)
for %%n in (tagdeck_config.json tagger_config.json tagdeck_debug.log tagger_debug.log quality_cache.json research_cache.json) do if exist "%SRC%\%%n" copy /y "%SRC%\%%n" "%DEST%\" >nul
for %%d in (undo_logs crate_backups config_backups waveform_cache cover_cache themes) do if exist "%SRC%\%%d" robocopy "%SRC%\%%d" "%DEST%\%%d" /E /NFL /NDL /NJH /NJS /NP >nul
goto copyprog

rem ---- update: keep a dated copy of the settings
:update
echo.
echo Updating. Your settings, undo logs and caches are kept.
if not exist "%DEST%\config_backups" mkdir "%DEST%\config_backups"
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do (
  if exist "%DEST%\tagdeck_config.json" copy /y "%DEST%\tagdeck_config.json" "%DEST%\config_backups\tagdeck_config_%%t.json" >nul
  if exist "%DEST%\tagger_config.json" copy /y "%DEST%\tagger_config.json" "%DEST%\config_backups\tagger_config_%%t.json" >nul
)

rem ---- replace only the program itself
:copyprog
copy /y "%WORK%\dist\TagDeck\TagDeck.exe" "%DEST%\" >nul || goto error
robocopy "%WORK%\dist\TagDeck\_internal" "%DEST%\_internal" /MIR /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto error
if defined FONTDIR if /I not "%FONTDIR%"=="%DEST%\fonts" robocopy "%FONTDIR%" "%DEST%\fonts" /E /NFL /NDL /NJH /NJS /NP >nul
if exist "%HERE%\smoke_test.bat" copy /y "%HERE%\smoke_test.bat" "%DEST%\" >nul

rem ---- older program files next to this one go to old_versions (moved, nothing deleted)
set "MOVED="
for %%f in ("%HERE%\TagDeck_*.py" "%HERE%\serato_tagger_pilot.py" "%HERE%\install_update.bat") do (
  if /I not "%%~nxf"=="%SRCPY%" if exist "%%~f" (
    if not exist "%HERE%\old_versions" mkdir "%HERE%\old_versions"
    move /y "%%~f" "%HERE%\old_versions\" >nul && set "MOVED=1"
  )
)
if defined MOVED echo Older program files were moved to old_versions\

rem ---- leftovers of older versions: deleted only if you say Y
set "OLDDIST="
if exist "%HERE%\dist" set "OLDDIST=1"
if exist "%HERE%\dist\SeratoTagger\tagger_config.json" if /I not "%SRC%"=="%HERE%\dist\SeratoTagger" set "OLDDIST="
set "OLDEXE="
if exist "%HERE%\SeratoTagger.exe" set "OLDEXE=1"
set "OLDPROG="
if exist "%OLDDEST%\SeratoTagger.exe" set "OLDPROG=1"
if not exist "%DEST%\tagdeck_config.json" if not exist "%DEST%\tagger_config.json" set "OLDPROG="
set "ANY="
if defined OLDDIST set "ANY=1"
if defined OLDEXE set "ANY=1"
if defined OLDPROG set "ANY=1"
if exist "%HERE%\build" set "ANY=1"
if exist "%HERE%\SeratoTagger.spec" set "ANY=1"
if exist "%HERE%\install_dir.txt" set "ANY=1"
if exist "%HERE%\update.bat" set "ANY=1"
if exist "%HERE%\build_portable.bat" set "ANY=1"
if not defined ANY goto done
echo.
echo Files of older versions were found in %HERE%:
if defined OLDDIST echo   dist\                  old program copy
if exist "%HERE%\build" echo   build\                 old build files
if exist "%HERE%\SeratoTagger.spec" echo   SeratoTagger.spec      old build file
if defined OLDEXE echo   SeratoTagger.exe, _internal\   old program in this folder
if defined OLDPROG echo   SeratoTagger\           the old Serato Tagger program folder (its settings are in TagDeck\ now)
if exist "%HERE%\install_dir.txt" echo   install_dir.txt        not needed any more
if exist "%HERE%\update.bat" echo   update.bat             replaced by TagDeck_install.bat
if exist "%HERE%\build_portable.bat" echo   build_portable.bat     replaced by TagDeck_install.bat
if exist "%HERE%\dist\SeratoTagger\tagger_config.json" if not defined OLDDIST echo   (dist\ is kept: it has settings that were not taken over)
echo Not deleted in any case: the TagDeck_*.py files, old_versions, settings, undo_logs and caches.
choice /C YN /M "Delete the files listed above"
if errorlevel 2 goto done
if defined OLDDIST rmdir /s /q "%HERE%\dist"
if exist "%HERE%\build" rmdir /s /q "%HERE%\build"
if exist "%HERE%\SeratoTagger.spec" del /q "%HERE%\SeratoTagger.spec"
if defined OLDEXE del /q "%HERE%\SeratoTagger.exe"
if defined OLDEXE if exist "%HERE%\_internal" rmdir /s /q "%HERE%\_internal"
if defined OLDPROG rmdir /s /q "%OLDDEST%"
if exist "%HERE%\install_dir.txt" del /q "%HERE%\install_dir.txt"
if exist "%HERE%\update.bat" del /q "%HERE%\update.bat"
if exist "%HERE%\build_portable.bat" del /q "%HERE%\build_portable.bat"
echo Deleted.

:done
echo.
echo ==============================================================
echo  Done: TagDeck %VER%. Start: %DEST%\TagDeck.exe
echo  (shortcuts to the old SeratoTagger.exe must be made again)
echo  Your settings, undo logs and caches were kept.
echo  Quick check: smoke_test.bat
echo ==============================================================
pause
exit /b 0

:getfonts
echo.
echo Downloading the theme fonts (Inter, Space Grotesk) from github.com/google/fonts ...
if not exist "%WORK%\fonts" mkdir "%WORK%\fonts"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $b='https://github.com/google/fonts/raw/main/ofl/'; $d='%WORK%\fonts\'; try { Invoke-WebRequest -UseBasicParsing ($b+'inter/Inter%%5Bopsz,wght%%5D.ttf') -OutFile ($d+'Inter.ttf'); Invoke-WebRequest -UseBasicParsing ($b+'spacegrotesk/SpaceGrotesk%%5Bwght%%5D.ttf') -OutFile ($d+'SpaceGrotesk.ttf'); Invoke-WebRequest -UseBasicParsing ($b+'inter/OFL.txt') -OutFile ($d+'OFL-Inter.txt'); Invoke-WebRequest -UseBasicParsing ($b+'spacegrotesk/OFL.txt') -OutFile ($d+'OFL-SpaceGrotesk.txt') } catch { Remove-Item -Force -ErrorAction SilentlyContinue ($d+'Inter.ttf'); exit 1 }"
if errorlevel 1 echo Download failed (no internet, or blocked): the build goes on without them.
exit /b 0

rem ---- install_dir.txt of the old update.bat: use it only if it holds settings
:checksrc
set "SRC=%SRC:"=%"
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"
if /I "%SRC%"=="%DEST%" set "SRC="
if defined SRC if not exist "%SRC%\tagger_config.json" if not exist "%SRC%\tagdeck_config.json" set "SRC="
exit /b 0

:error
echo.
echo INSTALL / UPDATE FAILED - nothing in your settings was changed.
echo Copy the text above and send it.
pause
exit /b 1
