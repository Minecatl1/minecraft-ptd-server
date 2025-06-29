@echo off
:: Minecraft NeoForge Server Setup for Windows (Stable Version)
:: Fixed to remain open and show errors

:: Enable colors and extended features
SETLOCAL EnableDelayedExpansion
title Minecraft Server Setup
color 07

:: Configuration
set "MC_VERSION=1.21.1"
set "NEOFORGE_VERSION=21.1.186"
set "SERVER_JAR=server.jar"
set "JAVA_MODS_DIR=mods\java"
set "BEDROCK_MODS_DIR=mods\bedrock"

:: Check admin rights
fltmc >nul 2>&1 || (
    echo ERROR: Please run as Administrator
    pause
    exit /b 1
)

:: Main menu
:menu
cls
echo ==============================
echo  Minecraft NeoForge %MC_VERSION% Setup
echo ==============================
echo 1. Full Automated Setup
echo 2. Install Dependencies Only
echo 3. Download Mods Only
echo 4. Exit
echo.
set /p choice="Select option (1-4): "

if "%choice%"=="1" goto full_setup
if "%choice%"=="2" goto dependencies
if "%choice%"=="3" goto download_mods
if "%choice%"=="4" exit /b
goto menu

:full_setup
call :dependencies
call :setup_directories
call :download_server
call :download_java_mods
call :process_mcaddons
call :docker_config
goto success

:dependencies
echo Installing dependencies...
winget install -e --id Oracle.JavaRuntimeEnvironment || (
    echo Failed to install Java
    exit /b 1
)

winget install -e --id Docker.DockerDesktop || (
    echo Failed to install Docker
    exit /b 1
)

echo Please ensure Docker Desktop is running manually
timeout /t 5 >nul
exit /b 0

:setup_directories
echo Creating directory structure...
mkdir "config" "world" "resource_packs" "behavior_packs" "scripts" "logs" "backups" 2>nul
mkdir "%JAVA_MODS_DIR%" "%BEDROCK_MODS_DIR%\behavior_packs" "%BEDROCK_MODS_DIR%\resource_packs" 2>nul
exit /b 0

:download_server
echo Downloading NeoForge...
powershell -Command "(New-Object Net.WebClient).DownloadFile('https://maven.neoforged.net/releases/net/neoforged/neoforge/%NEOFORGE_VERSION%/neoforge-%NEOFORGE_VERSION%-installer.jar', 'neoforge-installer.jar')" || (
    echo Failed to download NeoForge
    exit /b 1
)

echo Installing server...
java -jar neoforge-installer.jar --installServer || (
    echo NeoForge installation failed!
    exit /b 1
)

if not exist "%SERVER_JAR%" (
    echo Server jar missing!
    exit /b 1
)
del neoforge-installer.jar 2>nul
exit /b 0

:download_java_mods
echo Downloading Java mods...

set "MOD_LIST=(
"create-neoforge.jar https://cdn.modrinth.com/data/Xbc0uyRg/versions/0.7.0/create-neoforge-0.7.0.jar"
"jei-neoforge.jar https://cdn.modrinth.com/data/u6dRKJwZ/versions/TxS03dKM/jei-1.21.1-neoforge-19.21.0.247.jar"
"geyser-neoforge.jar https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge"
"floodgate-neoforge.jar https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar"
"Worldedit-neoforge.jar https://cdn.modrinth.com/data/1u6JkXh5/versions/WTAFvuRx/worldedit-mod-7.3.8.jar"
"Pixelmon-neoforge.jar https://cdn.modrinth.com/data/pixelmon/versions/latest/download"
"modernfix.jar https://cdn.modrinth.com/data/6Qy4JFHi/versions/latest/download"
"Voicechat-neoforge.jar https://cdn.modrinth.com/data/9eGKb6K1/versions/DtuPswKw/voicechat-neoforge-1.21.6-2.5.32.jar"
)"

for /F "tokens=1,2" %%A in ('echo %MOD_LIST%') do (
    echo Downloading %%A...
    powershell -Command "(New-Object Net.WebClient).DownloadFile('%%B', '%JAVA_MODS_DIR%\%%A')" || (
        echo Failed to download %%A
        exit /b 1
    )
)
exit /b 0

:process_mcaddons
echo Processing Bedrock addons...
for /R "%BEDROCK_MODS_DIR%" %%F in (*.mcaddon) do (
    echo Extracting %%F...
    powershell -Command "Expand-Archive -Path '%%F' -DestinationPath '%BEDROCK_MODS_DIR%\temp' -Force" || (
        echo Failed to extract %%F
        exit /b 1
    )
    
    if exist "%BEDROCK_MODS_DIR%\temp\behavior_packs" (
        xcopy /s /e /y "%BEDROCK_MODS_DIR%\temp\behavior_packs" "%BEDROCK_MODS_DIR%\behavior_packs" >nul
    )
    
    if exist "%BEDROCK_MODS_DIR%\temp\resource_packs" (
        xcopy /s /e /y "%BEDROCK_MODS_DIR%\temp\resource_packs" "%BEDROCK_MODS_DIR%\resource_packs" >nul
    )
    
    rd /s /q "%BEDROCK_MODS_DIR%\temp" 2>nul
    del "%%F"
)
exit /b 0

:docker_config
echo Creating Docker configuration...

(
echo version: '3.8'
echo.
echo services:
echo   minecraft:
echo     image: eclipse-temurin:17-jre
echo     container_name: mc-neoforge
echo     restart: unless-stopped
echo     environment:
echo       - MIN_RAM=6G
echo       - MAX_RAM=10G
echo       - EULA=TRUE
echo     volumes:
echo       - ./world:/server/world
echo       - ./mods:/server/mods
echo     ports:
echo       - "25565:25565/tcp"
echo       - "19132:19132/udp"
echo       - "24454:24454/udp"
) > docker-compose.yml

exit /b 0

:success
echo.
echo ===================================
echo  SETUP COMPLETED SUCCESSFULLY!
echo ===================================
echo Run the server with:
echo   docker-compose up -d
echo.
echo Connect at:
echo   Java Edition:    your-ip:25565
echo   Bedrock Edition: your-ip:19132
echo   Voice Chat:      your-ip:24454
echo.
pause
