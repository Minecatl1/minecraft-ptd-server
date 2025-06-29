@echo off
:: Minecraft NeoForge Server Setup for Windows
:: Equivalent to your Linux shell script

:: Colors (Windows VT-100 escape codes)
SET RED=[91m
SET GREEN=[92m
SET YELLOW=[93m
SET BLUE=[94m
SET NC=[0m

:: Configuration
SET MC_VERSION=1.21.1
SET NEOFORGE_VERSION=21.1.186
SET SERVER_JAR=server.jar
SET JAVA_MODS_DIR=mods\java
SET BEDROCK_MODS_DIR=mods\bedrock

:: Check admin rights
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo %RED%Please run as Administrator%NC%
    pause
    exit /b 1
)

:: Download function with progress
:download_file
powershell -Command "(New-Object Net.WebClient).DownloadFile('%1', '%2')"
IF %ERRORLEVEL% NEQ 0 (
    echo %RED%Failed to download %1%NC%
    exit /b 1
)
exit /b 0

:: Install dependencies
:dependencies
echo %YELLOW%Installing dependencies...%NC%
winget install -e --id Oracle.JavaRuntimeEnvironment
winget install -e --id Docker.DockerDesktop
echo %YELLOW%Please manually start Docker Desktop after installation.%NC%
timeout /t 5
exit /b 0

:: Directory structure
:setup_directories
echo %YELLOW%Creating directories...%NC%
mkdir config world resource_packs behavior_packs scripts logs backups 2>nul
mkdir "%JAVA_MODS_DIR%" "%BEDROCK_MODS_DIR%\behavior_packs" "%BEDROCK_MODS_DIR%\resource_packs" 2>nul
exit /b 0

:: Download NeoForge server
:download_server
echo %YELLOW%Downloading NeoForge...%NC%
call :download_file "https://maven.neoforged.net/releases/net/neoforged/neoforge/%NEOFORGE_VERSION%/neoforge-%NEOFORGE_VERSION%-installer.jar" "neoforge-installer.jar"

echo %YELLOW%Installing server...%NC%
java -jar neoforge-installer.jar --installServer
IF %ERRORLEVEL% NEQ 0 (
    echo %RED%NeoForge installation failed!%NC%
    exit /b 1
)

IF NOT EXIST "%SERVER_JAR%" (
    echo %RED%Server jar missing!%NC%
    exit /b 1
)
del neoforge-installer.jar 2>nul
exit /b 0

:: Java mod downloads
:download_java_mods
echo %BLUE%=== Downloading Java Mods ===%NC%

:: Mod URLs - Using Modrinth/CurseForge where possible
set "MODS[0]=create-neoforge.jar https://cdn.modrinth.com/data/Xbc0uyRg/versions/0.7.0/create-neoforge-0.7.0.jar"
set "MODS[1]=jei-neoforge.jar https://cdn.modrinth.com/data/u6dRKJwZ/versions/TxS03dKM/jei-1.21.1-neoforge-19.21.0.247.jar"
set "MODS[2]=geyser-neoforge.jar https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge"
set "MODS[3]=floodgate-neoforge.jar https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar"
set "MODS[4]=Worldedit-neoforge.jar https://cdn.modrinth.com/data/1u6JkXh5/versions/WTAFvuRx/worldedit-mod-7.3.8.jar"
set "MODS[5]=Pixelmon-neoforge.jar https://cdn.modrinth.com/data/pixelmon/versions/latest/download"
set "MODS[6]=modernfix.jar https://cdn.modrinth.com/data/6Qy4JFHi/versions/latest/download"
set "MODS[7]=Voicechat-neoforge.jar https://cdn.modrinth.com/data/9eGKb6K1/versions/DtuPswKw/voicechat-neoforge-1.21.6-2.5.32.jar"

for /f "tokens=1,2 delims= " %%A in ('set MODS[') do (
    call :download_file "%%B" "%JAVA_MODS_DIR%\%%A"
    IF %ERRORLEVEL% NEQ 0 exit /b 1
)
exit /b 0

:: Process Bedrock addons
:process_mcaddons
echo %BLUE%=== Processing Bedrock Addons ===%NC%
for /R "%BEDROCK_MODS_DIR%" %%F in (*.mcaddon) do (
    powershell -Command "Expand-Archive -Path '%%F' -DestinationPath '%BEDROCK_MODS_DIR%\temp' -Force"
    robocopy "%BEDROCK_MODS_DIR%\temp\behavior_packs" "%BEDROCK_MODS_DIR%\behavior_packs" /E >nul
    robocopy "%BEDROCK_MODS_DIR%\temp\resource_packs" "%BEDROCK_MODS_DIR%\resource_packs" /E >nul
    rmdir /s /q "%BEDROCK_MODS_DIR%\temp"
    del "%%F"
)
exit /b 0

:: Docker configuration
:docker_config
echo %YELLOW%Creating Docker configuration...%NC%

(
  echo FROM eclipse-temurin:17-jre-jammy
  echo WORKDIR /server
  echo COPY . .
  echo EXPOSE 25565/tcp 19132/udp 24454/udp
  echo CMD ["sh", "-c", "java -Xms%%MIN_RAM%% -Xmx%%MAX_RAM%% -XX:+UseG1GC -jar %SERVER_JAR% nogui"]
) > Dockerfile

(
  echo version: '3.8'
  echo services:
  echo   minecraft:
  echo     build: .
  echo     image: minecraft-neoforge-pixelmon:%MC_VERSION%
  echo     container_name: mc-neoforge
  echo     restart: unless-stopped
  echo     environment:
  echo       - MIN_RAM=6G
  echo       - MAX_RAM=10G
  echo     volumes:
  echo       - ./world:/server/world
  echo       - ./mods:/server/mods
  echo     ports:
  echo       - "25565:25565/tcp"
  echo       - "19132:19132/udp"
  echo       - "24454:24454/udp"
) > docker-compose.yml
exit /b 0

:: Main execution
echo %BLUE%=== Minecraft %MC_VERSION% NeoForge Server Setup ===%NC%
call :dependencies
call :setup_directories
call :download_server
call :download_java_mods
call :process_mcaddons
call :docker_config

echo %GREEN%=== Setup Complete ===%NC%
echo Start with: %YELLOW%docker-compose up -d%NC%
echo Connect at:
echo - Java:    your-ip:25565
echo - Bedrock: your-ip:19132
echo - Voice:   your-ip:24454
pause
