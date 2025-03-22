@echo off
:: Set the current folder path
set "source=%cd%"

:: Set the CS2 cfg folder path
set "destination=C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive\game\csgo"

:: Ensure the destination folder exists
if not exist "%destination%" (
    echo Destination folder does not exist: %destination%
    pause
    exit /b
)

:: Copy .cfg files from source to destination
echo Copying .cfg files from "%source%" to "%destination%"...
xcopy "%source%\*.cfg" "%destination%" /Y

:: Check for errors
if errorlevel 1 (
    echo An error occurred during the copy process.
    pause
    exit /b
)

echo Copy operation completed successfully.
pause