@echo off
:: Minecraft NeoForge Server Setup for Windows
:: Includes Create, Pixelmon, ModernFix + Bedrock Support

:: Configuration
set MC_VERSION=1.21.1
set NEOFORGE_VERSION=21.1.186
set SERVER_JAR=server.jar
set JAVA_MODS_DIR=mods\java
set BEDROCK_MODS_DIR=mods\bedrock

:: Admin check
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Please run as Administrator!
    pause
    exit /b
)

:: Title
title Minecraft NeoForge %MC_VERSION% Server Setup
color 0a
echo =============================================
echo Minecraft NeoForge Server Setup for Windows
echo Version: %MC_VERSION% with NeoForge %NEOFORGE_VERSION%
echo Mods: Create, Pixelmon, ModernFix + Bedrock Support
echo =============================================
echo.

:: Network detection
for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr "IPv4"') do (
    for /f "tokens=*" %%B in ("%%A") do set LOCAL_IP=%%B
)
if "%LOCAL_IP%"=="" set LOCAL_IP=127.0.0.1

echo ===== SERVER ACCESS =====
echo Java:    %LOCAL_IP%:25565
echo Bedrock: %LOCAL_IP%:19132
echo ========================
echo.

:: Install Chocolatey if missing
where choco >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Chocolatey...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
    timeout /t 5 >nul
)

:: Install dependencies
echo Installing required packages...
choco install -y jdk17 curl wget unzip docker-desktop --force
if %errorlevel% neq 0 (
    echo Failed to install packages!
    pause
    exit /b
)

:: Refresh PATH
for /f "usebackq tokens=2,*" %%A in (`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH`) do set PATH=%%B
set PATH=%PATH%;C:\Program Files\Docker\Docker\resources\bin

:: Create directories
echo Creating directory structure...
mkdir config world resource_packs behavior_packs scripts logs backups >nul 2>&1
mkdir %JAVA_MODS_DIR% %BEDROCK_MODS_DIR%\behavior_packs %BEDROCK_MODS_DIR%\resource_packs >nul 2>&1

:: Download NeoForge
echo Downloading NeoForge server...
curl -L -o neoforge-installer.jar "https://maven.neoforged.net/releases/net/neoforged/neoforge/%NEOFORGE_VERSION%/neoforge-%NEOFORGE_VERSION%-installer.jar" --progress-bar

:: Install server
echo Installing server...
java -jar neoforge-installer.jar --installServer
if not exist "%SERVER_JAR%" (
    echo Server installation failed!
    pause
    exit /b
)
del neoforge-installer.jar >nul 2>&1

:: Download Java mods
echo Downloading mods...
echo - Create
curl -L -o "%JAVA_MODS_DIR%\create-neoforge.jar" "https://www.curseforge.com/api/v1/mods/328085/files/6641610/download" --progress-bar
echo - Pixelmon
curl -L -o "%JAVA_MODS_DIR%\Pixelmon-neoforge.jar" "https://www.curseforge.com/api/v1/mods/389487/files/6701628/download" --progress-bar
echo - ModernFix
curl -L -o "%JAVA_MODS_DIR%\modernfix.jar" "https://www.curseforge.com/api/v1/mods/790626/files/6609557/download" --progress-bar
echo - Geyser (for Bedrock)
curl -L -o "%JAVA_MODS_DIR%\geyser-neoforge.jar" "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge" --progress-bar
echo - Floodgate (for Xbox via phone)
curl -L -o "%JAVA_MODS_DIR%\floodgate-neoforge.jar" "https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar" --progress-bar

:: Configure Geyser for phone bridging
mkdir config\geyser >nul 2>&1
(
echo {
echo   "bedrock": {
echo     "address": "0.0.0.0",
echo     "port": 19132,
echo     "motd1": "Xbox via Phone Bridge",
echo     "motd2": "Connect via mobile first"
echo   },
echo   "remote": {
echo     "address": "127.0.0.1",
echo     "port": 25565,
echo     "auth-type": "floodgate"
echo   }
echo }
) > config\geyser\config.yml

:: Create Docker config
echo Creating Docker configuration...
(
echo FROM eclipse-temurin:17-jre-jammy
echo.
echo RUN apt-get update ^&^& apt-get install -y ^
echo     libxi6 libgl1-mesa-glx ^
echo     ^&^& rm -rf /var/lib/apt/lists/*
echo.
echo WORKDIR /server
echo COPY . .
echo.
echo HEALTHCHECK --interval=30s --timeout=5s ^
echo     CMD netstat -tuln ^| grep -q 25565 ^|^| exit 1
echo.
echo EXPOSE 25565/tcp 19132/udp
echo.
echo CMD ["sh", "-c", "java -Xms%%MIN_RAM%% -Xmx%%MAX_RAM%% ^
echo -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions ^
echo -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled ^
echo -jar %SERVER_JAR% nogui"]
) > Dockerfile

(
echo version: '3.8'
echo.
echo services:
echo   minecraft:
echo     build: .
echo     image: minecraft-neoforge-pixelmon:%MC_VERSION%
echo     container_name: mc-neoforge
echo     restart: unless-stopped
echo     environment:
echo       - MIN_RAM=6G
echo       - MAX_RAM=10G
echo       - EULA=TRUE
echo     volumes:
echo       - ./world:/server/world
echo       - ./config:/server/config
echo       - ./mods:/server/mods
echo       - ./resource_packs:/server/resource_packs
echo       - ./behavior_packs:/server/behavior_packs
echo     ports:
echo       - "25565:25565/tcp"
echo       - "19132:19132/udp"
echo     ulimits:
echo       memlock: -1
echo       nofile: 65535
) > docker-compose.yml

:: Create Xbox connection guide
(
echo Xbox Connection Guide
echo ====================
echo 1. On your MOBILE PHONE:
echo    - Connect to: %LOCAL_IP%:19132
echo    - Keep the game RUNNING IN BACKGROUND
echo 2. On your XBOX:
echo    - Go to "Friends" tab
echo    - Join your mobile player's game
echo.
echo Troubleshooting:
echo - Ensure phone and Xbox are on same network
echo - Mobile app must stay open during play
) > XBOX_GUIDE.txt

:: Completion
echo.
echo =============================================
echo SETUP COMPLETE!
echo.
echo Mods Installed:
echo - Create
echo - Pixelmon
echo - ModernFix
echo - Geyser/Floodgate (Bedrock)
echo.
echo Xbox players: Follow instructions in XBOX_GUIDE.txt
echo Start server: docker-compose up -d
echo =============================================
pause
