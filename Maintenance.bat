@echo off
title Server Maintenance
color 0A

:: Create "Server Maintenance" folder if it doesn't exist
if not exist "Server Maintenance\" mkdir "Server Maintenance"

:: Move all files/folders (except this script) into the folder
for %%F in (*) do (
    if not "%%F"=="%~nx0" (
        move "%%F" "Server Maintenance\%%F"
    )
)

:: Move all folders (except "Server Maintenance") 
for /D %%D in (*) do (
    if not "%%D"=="Server Maintenance" (
        move "%%D" "Server Maintenance\%%D"
    )
)

echo All files and folders moved to "Server Maintenance"!
pause
