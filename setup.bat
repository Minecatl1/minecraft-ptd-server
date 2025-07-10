@echo off
setlocal enabledelayedexpansion

:: ==============================================
:: Minecraft NeoForge Server Installer
:: Version 1.0 - For Windows 10/11
:: ==============================================
:: This will install:
:: - Java 17+
:: - Docker Desktop
:: - NeoForge 1.21.1 Server
:: - Required Mods (Pixelmon, Geyser, etc.)
:: ==============================================

title Minecraft NeoForge Server Installer

:: Admin check
echo Checking administrator privileges...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Please run this installer as Administrator!
    echo Right-click on this file and select "Run as administrator"
    pause
    exit /b 1
)

:: Configuration
set MC_VERSION=1.21.1
set NEOFORGE_VERSION=21.1.186
set SERVER_JAR=server.jar
set JAVA_MODS_DIR=mods\
set BEDROCK_MODS_DIR=mods\bedrock

:: ==============================================
:: Installation Progress
:: ==============================================
echo.
echo ==============================================
echo Minecraft NeoForge Server Installation
echo ==============================================
echo.

:: Phase 1: Prerequisites
echo [1/4] Installing prerequisites...
echo ----------------------------------------------

:: Install Chocolatey if missing
echo Checking for Chocolatey package manager...
where choco >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Chocolatey...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && (
        setx PATH "%PATH%;%ALLUSERSPROFILE%\chocolatey\bin" /M
    )
    timeout /t 3 >nul
)

:: Install Java 17+
echo Checking Java installation...
where java >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Java 17...
    choco install -y temurin17 --params="/ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome"
) else (
    java -version 2>&1 | find "17." >nul
    if %errorLevel% neq 0 (
        echo Upgrading to Java 17...
        choco upgrade -y temurin17 --params="/ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome"
    )
)

:: Install Docker Desktop
echo Checking Docker installation...
where docker >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Docker Desktop...
    choco install -y docker-desktop
    echo.
    echo IMPORTANT: After this installer completes, please:
    echo 1. Open Docker Desktop from the Start menu
    echo 2. Accept the service agreement
    echo 3. Re-run this installer to complete setup
    pause
    exit
)

:: Verify Docker is running
echo Verifying Docker service...
docker ps >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Docker is not running!
    echo Please start Docker Desktop and try again
    pause
    exit /b 1
)

:: Phase 2: Server Setup
echo.
echo [2/4] Setting up server files...
echo ----------------------------------------------

:: Create directory structure
echo Creating directory structure...
mkdir config 2>nul
mkdir world 2>nul
mkdir resource_packs 2>nul
mkdir behavior_packs 2>nul
mkdir scripts 2>nul
mkdir logs 2>nul
mkdir backups 2>nul
mkdir %JAVA_MODS_DIR% 2>nul
mkdir %BEDROCK_MODS_DIR%\behavior_packs 2>nul
mkdir %BEDROCK_MODS_DIR%\resource_packs 2>nul

:: Download NeoForge server
echo Downloading NeoForge server...
powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://maven.neoforged.net/releases/net/neoforged/neoforge/%NEOFORGE_VERSION%/neoforge-%NEOFORGE_VERSION%-installer.jar', 'neoforge-installer.jar')"

echo Installing server...
java -jar neoforge-installer.jar --installServer
if not exist %SERVER_JAR% (
    echo ERROR: Server installation failed
    exit /b 1
)
del neoforge-installer.jar

:: Phase 3: Mod Installation
echo.
echo [3/4] Installing mods...
echo ----------------------------------------------

:: Download Java mods
echo Downloading mods...
set "MOD_LIST=create-neoforge.jar https://www.curseforge.com/api/v1/mods/328085/files/6641610/download
jei-neoforge.jar https://cdn.modrinth.com/data/u6dRKJwZ/versions/TxS03dKM/jei-1.21.1-neoforge-19.21.0.247.jar
geyser-neoforge.jar https://cdn.modrinth.com/data/wKkoqHrH/versions/3rUDJIS0/geyser-neoforge-Geyser-Neoforge-2.4.4-b705.jar
floodgate-neoforge.jar https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar
Pixelmon-neoforge.jar https://cdn.modrinth.com/data/59ZceYlU/versions/ekKbNviQ/Pixelmon-1.21.1-9.3.5-universal.jar
modernfix.jar https://www.curseforge.com/api/v1/mods/790626/files/6609557/download
forged-fabric-api.jar https://github.com/Sinytra/ForgifiedFabricAPI/releases/download/0.115.6%%2B2.1.1%%2B1.21.1/forgified-fabric-api-0.115.6+2.1.1+1.21.1.jar
cloth-config.jar https://cdn.modrinth.com/data/9s6osm5g/versions/izKINKFg/cloth-config-15.0.140-neoforge.jar"

for /f "tokens=1,2" %%a in ("%MOD_LIST%") do (
    echo Installing %%a...
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('%%b', '%JAVA_MODS_DIR%\%%a')"
)

:: Process Bedrock addons
echo Setting up Bedrock support...
for /r "%BEDROCK_MODS_DIR%" %%f in (*.mcaddon) do (
    powershell -Command "Expand-Archive -Path '%%f' -DestinationPath '%BEDROCK_MODS_DIR%\temp' -Force"
    robocopy "%BEDROCK_MODS_DIR%\temp\behavior_packs" "%BEDROCK_MODS_DIR%\behavior_packs" /E >nul
    robocopy "%BEDROCK_MODS_DIR%\temp\resource_packs" "%BEDROCK_MODS_DIR%\resource_packs" /E >nul
    rmdir /s /q "%BEDROCK_MODS_DIR%\temp"
    del "%%f"
)

:: Phase 4: Docker Configuration
echo.
echo [4/4] Configuring Docker...
echo ----------------------------------------------

:: Create Docker configuration
echo Generating Docker files...
(
echo FROM eclipse-temurin:17-jre-jammy
echo;
echo RUN apt-get update ^&^& apt-get install -y ^
echo     libxi6 libgl1-mesa-glx ^
echo     ^&^& rm -rf /var/lib/apt/lists/*
echo;
echo WORKDIR /server
echo COPY . .
echo;
echo HEALTHCHECK --interval=30s --timeout=5s ^
echo     CMD netstat -tuln ^| grep -q 25565 || exit 1
echo;
echo EXPOSE 25565/tcp 19132/udp 24454/udp
echo;
echo CMD ["sh", "-c", "java -Xms!MIN_RAM! -Xmx!MAX_RAM! ^
echo -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions ^
echo -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled ^
echo -jar %SERVER_JAR% nogui"]
) > Dockerfile

(
echo version: '3.8'
echo;
echo services:
echo   minecraft:
echo     build: .
echo     image: minecraft-neoforge-pixelmon:%MC_VERSION%
echo     container_name: mc-neoforge
echo     restart: unless-stopped
echo     environment:
echo       - MIN_RAM=6G
echo       - MAX_RAM=16G
echo       - EULA=TRUE
echo     volumes:
echo       - ./world:/server/world
echo       - ./config:/server/config
echo       - ./mods:/server/mods
echo       - ./resource_packs:/server/resource_packs
echo       - ./behavior_packs:/server/behavior_packs
echo       - ./logs:/server/logs
echo       - ./backups:/server/backups
echo     ports:
echo       - "25565:25565/tcp"
echo       - "19132:19132/udp"
echo       - "24454:24454/udp"
echo     ulimits:
echo       memlock: -1
echo       nofile: 65535
echo     deploy:
echo       resources:
echo         limits:
echo           memory: 12G
echo;
echo volumes:
echo   minecraft_data:
echo     driver: local
) > docker-compose.yml

:: ==============================================
:: Installation Complete
:: ==============================================
echo.
echo ==============================================
echo INSTALLATION COMPLETE
echo ==============================================
echo.
echo Server successfully installed!
echo.
echo To start your server:
echo 1. Open Docker Desktop
echo 2. Open a command prompt in this folder
echo 3. Run: docker-compose up -d
echo 4. or run the run.bat to start the server on the hardwere its self
echo.
echo Connection Info:
echo - Java Edition:    your-ip:25565
echo - Bedrock Edition: your-ip:19132
echo.
echo Press any key to exit...
pause >nul
