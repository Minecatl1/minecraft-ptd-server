@echo off
:: Minecraft NeoForge Server Setup for Windows
:: Fixed version with reliable package installation

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
echo =============================================
echo.

:: Install Chocolatey if missing
echo Checking for Chocolatey...
where choco >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Chocolatey...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    timeout /t 10 >nul
    set PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin
)

:: Install dependencies with explicit sources
echo Installing required packages...
(
    choco install -y temurin17 --source="https://community.chocolatey.org/api/v2/"
    choco install -y curl --source="https://community.chocolatey.org/api/v2/"
    choco install -y wget --source="https://community.chocolatey.org/api/v2/"
    choco install -y unzip --source="https://community.chocolatey.org/api/v2/"
    choco install -y docker-desktop --source="https://community.chocolatey.org/api/v2/" --params="'/Quiet'"
) >nul 2>&1

if %errorlevel% neq 0 (
    echo Failed to install packages! Trying alternative methods...
    
    :: Fallback for Java
    if not exist "%ProgramFiles%\Java\jdk-17*" (
        echo Downloading Java 17 directly...
        curl -L -o jdk17.msi "https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_windows-x64_bin.msi" --silent
        msiexec /i jdk17.msi /quiet /norestart
        set JAVA_HOME=%ProgramFiles%\Java\jdk-17.0.2
        set PATH=%JAVA_HOME%\bin;%PATH%
    )
    
    :: Verify Docker
    where docker >nul 2>&1
    if %errorlevel% neq 0 (
        echo Downloading Docker Desktop directly...
        curl -L -o DockerDesktopInstaller.exe "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" --silent
        start /wait "" DockerDesktopInstaller.exe install --quiet
    )
)

:: Refresh PATH
for /f "usebackq tokens=2,*" %%A in (`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH`) do set PATH=%%B
set PATH=%PATH%;C:\Program Files\Docker\Docker\resources\bin

:: Verify installations
where java >nul 2>&1
if %errorlevel% neq 0 (
    echo Java installation failed!
    pause
    exit /b
)

where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo Docker installation failed!
    pause
    exit /b
)

:: Rest of your script continues here...
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
echo - Geyser (for Bedrock support)
curl -L -o "%JAVA_MODS_DIR%\geyser-neoforge.jar" "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge" --progress-bar
echo - Floodgate (for Xbox compatibility)
curl -L -o "%JAVA_MODS_DIR%\floodgate-neoforge.jar" "https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar" --progress-bar
echo - Pixelmon
curl -L -o "%JAVA_MODS_DIR%\Pixelmon-neoforge.jar" "https://www.curseforge.com/api/v1/mods/389487/files/6701628/download" --progress-bar

:: Configure Geyser for Xbox bridging
echo Configuring Geyser...
mkdir config\geyser >nul 2>&1
(
echo {
echo   "bedrock": {
echo     "address": "0.0.0.0",
echo     "port": 19132,
echo     "clone-remote-port": true,
echo     "motd1": "Xbox via Phone Bridge",
echo     "motd2": "Connect via mobile first"
echo   },
echo   "remote": {
echo     "address": "127.0.0.1",
echo     "port": 25565,
echo     "auth-type": "floodgate"
echo   },
echo   "floodgate-key-file": "./config/floodgate/key.pem"
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
echo     image: minecraft-neoforge-xbox-bridge:%MC_VERSION%
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

:: Completion
echo.
echo =============================================
echo SETUP COMPLETE!
echo.
echo To start server:
echo   1. Open Docker Desktop
echo   2. Run: docker-compose up -d
echo =============================================
pause
