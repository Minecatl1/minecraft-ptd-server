@echo off
:: Minecraft NeoForge Server Setup for Windows
:: Includes: Create, Pixelmon, ModernFix, WorldEdit, JEI
:: Xbox support via phone bridge

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
echo Mods: Create, Pixelmon, ModernFix, WorldEdit, JEI
echo =============================================
echo.

:: Network detection
for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr "IPv4"') do (
    for /f "tokens=*" %%B in ("%%A") do set LOCAL_IP=%%B
)
if "%LOCAL_IP%"=="" set LOCAL_IP=127.0.0.1

echo ===== XBOX CONNECTION GUIDE =====
echo 1. On your PHONE:
echo    - Connect to %LOCAL_IP%:19132
echo    - Keep game running in background
echo 2. On XBOX:
echo    - Join via "Friends" tab
echo =================================
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
echo - WorldEdit
curl -L -o "%JAVA_MODS_DIR%\Worldedit-neoforge.jar" "https://cdn.modrinth.com/data/1u6JkXh5/versions/WTAFvuRx/worldedit-mod-7.3.8.jar" --progress-bar
echo - JEI
curl -L -o "%JAVA_MODS_DIR%\jei-neoforge.jar" "https://cdn.modrinth.com/data/u6dRKJwZ/versions/TxS03dKM/jei-1.21.1-neoforge-19.21.0.247.jar" --progress-bar
echo - Geyser (for Bedrock)
curl -L -o "%JAVA_MODS_DIR%\geyser-neoforge.jar" "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge" --progress-bar
echo - Floodgate (for Xbox)
curl -L -o "%JAVA_MODS_DIR%\floodgate-neoforge.jar" "https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar" --progress-bar

:: Configure Geyser for phone bridging
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

:: Create management scripts
(
echo @echo off
echo :: Backup Script - Keeps 7 days of backups
echo set BACKUP_DIR=backups
echo set DAYS_TO_KEEP=7
echo.
echo mkdir %%BACKUP_DIR%% >nul 2>&1
echo for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set TIMESTAMP=%%a
echo set TIMESTAMP=%%TIMESTAMP:~0,8%%_%%TIMESTAMP:~8,6%%
echo.
echo tar -czf "%%BACKUP_DIR%%\world_%%TIMESTAMP%%.tar.gz" world config mods
echo forfiles /p "%%BACKUP_DIR%%" /m "world_*.tar.gz" /d -%%DAYS_TO_KEEP%% /c "cmd /c del @path"
) > scripts\backup.bat

:: Completion
echo.
echo =============================================
echo SETUP COMPLETE!
echo.
echo To start server:
echo   1. Open Docker Desktop
echo   2. Run: docker-compose up -d
echo.
echo Xbox players must:
echo   1. Connect via phone first (see instructions above)
echo   2. Join through Xbox Friends tab
echo =============================================
pause
