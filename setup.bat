@echo off
:: Minecraft NeoForge Server Setup for Windows
:: Full version with IP display and backup system

:: Configuration
set MC_VERSION=1.21.1
set NEOFORGE_VERSION=21.1.186
set SERVER_JAR=server.jar
set CREATE_VERSION=0.7.0
set GEYSER_VERSION=2.2.3
set FLOODGATE_VERSION=2.2.4
set JAVA_MODS_DIR=mods\java
set BEDROCK_MODS_DIR=mods\bedrock

:: Title
title Minecraft NeoForge %MC_VERSION% Server Setup
color 0a
echo =============================================
echo Minecraft NeoForge Server Setup for Windows
echo Version: %MC_VERSION% with NeoForge %NEOFORGE_VERSION%
echo =============================================
echo.

:: Check admin rights
echo Checking administrator privileges...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Please run as Administrator!
    pause
    exit /b
)

:: Display network information
echo Getting network configuration...
echo.
for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr "IPv4"') do (
    for /f "tokens=*" %%B in ("%%A") do set LOCAL_IP=%%B
)
if "%LOCAL_IP%"=="" set LOCAL_IP=127.0.0.1

echo ===== SERVER ACCESS INFORMATION =====
echo Java Edition:    %LOCAL_IP%:25565
echo Bedrock Edition: %LOCAL_IP%:19132
echo.
echo Note: For external access, you'll need to:
echo 1. Configure port forwarding on your router
echo 2. Add firewall exceptions for these ports
echo =====================================
echo.

:: Install Chocolatey if needed
echo Checking for Chocolatey package manager...
where choco >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Chocolatey...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
    timeout /t 5 >nul
)

:: Install required software
echo Installing required packages...
choco install -y jdk17 curl wget unzip docker-desktop --force
if %errorLevel% neq 0 (
    echo Failed to install required packages!
    pause
    exit /b
)

:: Refresh PATH
for /f "usebackq tokens=2,*" %%A in (`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH`) do set PATH=%%B
set PATH=%PATH%;C:\Program Files\Docker\Docker\resources\bin

:: Create directory structure
echo Creating directory structure...
mkdir config world resource_packs behavior_packs scripts >nul 2>&1
mkdir %JAVA_MODS_DIR% %BEDROCK_MODS_DIR%\behavior_packs %BEDROCK_MODS_DIR%\resource_packs >nul 2>&1

:: Download NeoForge server
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
echo - Create: %CREATE_VERSION%
curl -L -o "%JAVA_MODS_DIR%\create-neoforge.jar" "https://www.curseforge.com/api/v1/mods/328085/files/6641610/download" --progress-bar
echo - JEI
curl -L -o "%JAVA_MODS_DIR%\jei-neoforge.jar" "https://cdn.modrinth.com/data/u6dRKJwZ/versions/TxS03dKM/jei-1.21.1-neoforge-19.21.0.247.jar" --progress-bar
echo - Geyser
curl -L -o "%JAVA_MODS_DIR%\geyser-neoforge.jar" "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge" --progress-bar
echo - Floodgate
curl -L -o "%JAVA_MODS_DIR%\floodgate-neoforge.jar" "https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar" --progress-bar
echo - WorldEdit
curl -L -o "%JAVA_MODS_DIR%\worldedit-neoforge.jar" "https://cdn.modrinth.com/data/1u6JkXh5/versions/WTAFvuRx/worldedit-mod-7.3.8.jar" --progress-bar
echo - Pixelmon
curl -L -o "%JAVA_MODS_DIR%\Pixelmon-neoforge.jar" "https://www.curseforge.com/api/v1/mods/389487/files/6701628/download" --progress-bar
echo - modernfix
curl -L -o "%JAVA_MODS_DIR%\modernfix.jar" "https://www.curseforge.com/api/v1/mods/790626/files/6609557/download" --progress-bar
echo - Simple voice chat
curl -L -o "%JAVA_MODS_DIR%\voicechat-neoforge.jar" "https://cdn.modrinth.com/data/9eGKb6K1/versions/DtuPswKw/voicechat-neoforge-1.21.6-2.5.32.jar" --progress-bar

:: Create Docker compose file
echo Creating docker-compose.yml...
(
echo version: '3.8'
echo services:
echo   minecraft:
echo     image: eclipse-temurin:17-jre
echo     container_name: minecraft-neoforge
echo     restart: unless-stopped
echo     environment:
echo       - MIN_RAM=4G
echo       - MAX_RAM=8G
echo       - EULA=TRUE
echo     volumes:
echo       - ./world:/server/world
echo       - ./config:/server/config
echo       - ./mods:/server/mods
echo       - ./resource_packs:/server/resource_packs
echo       - ./behavior_packs:/server/behavior_packs
echo       - ./backups:/server/backups
echo     ports:
echo       - "25565:25565/tcp"
echo       - "19132:19132/udp"
echo       - "24454:24454/udp"
) > docker-compose.yml

:: Create backup script
echo Creating backup script...
(
echo @echo off
echo :: Minecraft Server Backup Utility
echo :: Automatically keeps 5 days of backups
echo.
echo set BACKUP_DIR=backups
echo set SERVER_DIR=.
echo set DAYS_TO_KEEP=5
echo.
echo :: Get IP address
echo for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr "IPv4"') do (
echo    for /f "tokens=*" %%B in ("%%A") do set LOCAL_IP=%%B
echo )
echo if "%%LOCAL_IP%%"=="" set LOCAL_IP=127.0.0.1
echo.
echo echo #############################################
echo echo MINECRAFT SERVER BACKUP UTILITY
echo echo Server Address: %%LOCAL_IP%%:25565
echo echo Bedrock Address: %%LOCAL_IP%%:19132
echo echo #############################################
echo.
echo :: Create backup directory
echo if not exist "%%BACKUP_DIR%%" mkdir "%%BACKUP_DIR%%"
echo.
echo :: Generate timestamp
echo for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set TIMESTAMP=%%a
echo set TIMESTAMP=%%TIMESTAMP:~0,8%%_%%TIMESTAMP:~8,6%%
echo.
echo :: Create backup
echo echo Creating backup...
echo tar -czf "%%BACKUP_DIR%%\world_backup_%%TIMESTAMP%%.tar.gz" -C "%%SERVER_DIR%%" world config mods
echo if %%errorLevel%% neq 0 (
echo    echo Backup failed!
echo    pause
echo    exit /b
echo )
echo.
echo :: Remove old backups
echo echo Cleaning up backups older than %%DAYS_TO_KEEP%% days...
echo forfiles /p "%%BACKUP_DIR%%" /m "world_backup_*.tar.gz" /d -%%DAYS_TO_KEEP%% /c "cmd /c del @path"
echo.
echo echo Backup complete: %%BACKUP_DIR%%\world_backup_%%TIMESTAMP%%.tar.gz
echo pause
) > backup_server.bat

:: Create README file
(
echo Minecraft NeoForge Server
echo ========================
echo.
echo Server Information:
echo - Version: %MC_VERSION%
echo - NeoForge: %NEOFORGE_VERSION%
echo.
echo Connection Info:
echo - Java Edition: %LOCAL_IP%:25565
echo - Bedrock Edition: %LOCAL_IP%:19132
echo.
echo Management Commands:
echo - Start server: docker-compose up -d
echo - Stop server: docker-compose down
echo - Create backup: backup_server.bat
echo - Update mods: Update the files in %JAVA_MODS_DIR%
echo.
echo Backup automatically runs every 5 days
) > README.txt

:: Final instructions
echo.
echo =============================================
echo SETUP COMPLETE!
echo.
echo Your server is ready with these access points:
echo Java:    %LOCAL_IP%:25565
echo Bedrock: %LOCAL_IP%:19132
echo.
echo To start your server:
echo 1. Open Docker Desktop and wait for it to start
echo 2. Run: docker-compose up -d
echo.
echo To create a manual backup:
echo Run: backup_server.bat
echo.
echo A README.txt file has been created with these instructions
echo =============================================
pause@echo off
:: Minecraft NeoForge Server Setup for Windows
:: Full version with IP display and backup system

:: Configuration
set MC_VERSION=1.21.1
set NEOFORGE_VERSION=21.1.186
set SERVER_JAR=server.jar
set CREATE_VERSION=0.7.0
set GEYSER_VERSION=2.2.3
set FLOODGATE_VERSION=2.2.4
set JAVA_MODS_DIR=mods\java
set BEDROCK_MODS_DIR=mods\bedrock

:: Title
title Minecraft NeoForge %MC_VERSION% Server Setup
color 0a
echo =============================================
echo Minecraft NeoForge Server Setup for Windows
echo Version: %MC_VERSION% with NeoForge %NEOFORGE_VERSION%
echo =============================================
echo.

:: Check admin rights
echo Checking administrator privileges...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Please run as Administrator!
    pause
    exit /b
)

:: Display network information
echo Getting network configuration...
echo.
for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr "IPv4"') do (
    for /f "tokens=*" %%B in ("%%A") do set LOCAL_IP=%%B
)
if "%LOCAL_IP%"=="" set LOCAL_IP=127.0.0.1

echo ===== SERVER ACCESS INFORMATION =====
echo Java Edition:    %LOCAL_IP%:25565
echo Bedrock Edition: %LOCAL_IP%:19132
echo.
echo Note: For external access, you'll need to:
echo 1. Configure port forwarding on your router
echo 2. Add firewall exceptions for these ports
echo =====================================
echo.

:: Install Chocolatey if needed
echo Checking for Chocolatey package manager...
where choco >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Chocolatey...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
    timeout /t 5 >nul
)

:: Install required software
echo Installing required packages...
choco install -y jdk17 curl wget unzip docker-desktop --force
if %errorLevel% neq 0 (
    echo Failed to install required packages!
    pause
    exit /b
)

:: Refresh PATH
for /f "usebackq tokens=2,*" %%A in (`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH`) do set PATH=%%B
set PATH=%PATH%;C:\Program Files\Docker\Docker\resources\bin

:: Create directory structure
echo Creating directory structure...
mkdir config world resource_packs behavior_packs scripts >nul 2>&1
mkdir %JAVA_MODS_DIR% %BEDROCK_MODS_DIR%\behavior_packs %BEDROCK_MODS_DIR%\resource_packs >nul 2>&1

:: Download NeoForge server
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
echo - Create: %CREATE_VERSION%
curl -L -o "%JAVA_MODS_DIR%\create-neoforge.jar" "https://www.curseforge.com/api/v1/mods/328085/files/6641610/download" --progress-bar
echo - JEI
curl -L -o "%JAVA_MODS_DIR%\jei-neoforge.jar" "https://cdn.modrinth.com/data/u6dRKJwZ/versions/TxS03dKM/jei-1.21.1-neoforge-19.21.0.247.jar" --progress-bar
echo - Geyser
curl -L -o "%JAVA_MODS_DIR%\geyser-neoforge.jar" "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge" --progress-bar
echo - Floodgate
curl -L -o "%JAVA_MODS_DIR%\floodgate-neoforge.jar" "https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar" --progress-bar
echo - WorldEdit
curl -L -o "%JAVA_MODS_DIR%\worldedit-neoforge.jar" "https://cdn.modrinth.com/data/1u6JkXh5/versions/WTAFvuRx/worldedit-mod-7.3.8.jar" --progress-bar

:: Create Docker compose file
echo Creating docker-compose.yml...
(
echo version: '3.8'
echo services:
echo   minecraft:
echo     image: eclipse-temurin:17-jre
echo     container_name: minecraft-neoforge
echo     restart: unless-stopped
echo     environment:
echo       - MIN_RAM=4G
echo       - MAX_RAM=8G
echo       - EULA=TRUE
echo     volumes:
echo       - ./world:/server/world
echo       - ./config:/server/config
echo       - ./mods:/server/mods
echo       - ./resource_packs:/server/resource_packs
echo       - ./behavior_packs:/server/behavior_packs
echo       - ./backups:/server/backups
echo     ports:
echo       - "25565:25565/tcp"
echo       - "19132:19132/udp"
) > docker-compose.yml

:: Create backup script
echo Creating backup script...
(
echo @echo off
echo :: Minecraft Server Backup Utility
echo :: Automatically keeps 5 days of backups
echo.
echo set BACKUP_DIR=backups
echo set SERVER_DIR=.
echo set DAYS_TO_KEEP=5
echo.
echo :: Get IP address
echo for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr "IPv4"') do (
echo    for /f "tokens=*" %%B in ("%%A") do set LOCAL_IP=%%B
echo )
echo if "%%LOCAL_IP%%"=="" set LOCAL_IP=127.0.0.1
echo.
echo echo #############################################
echo echo MINECRAFT SERVER BACKUP UTILITY
echo echo Server Address: %%LOCAL_IP%%:25565
echo echo Bedrock Address: %%LOCAL_IP%%:19132
echo echo #############################################
echo.
echo :: Create backup directory
echo if not exist "%%BACKUP_DIR%%" mkdir "%%BACKUP_DIR%%"
echo.
echo :: Generate timestamp
echo for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set TIMESTAMP=%%a
echo set TIMESTAMP=%%TIMESTAMP:~0,8%%_%%TIMESTAMP:~8,6%%
echo.
echo :: Create backup
echo echo Creating backup...
echo tar -czf "%%BACKUP_DIR%%\world_backup_%%TIMESTAMP%%.tar.gz" -C "%%SERVER_DIR%%" world config mods
echo if %%errorLevel%% neq 0 (
echo    echo Backup failed!
echo    pause
echo    exit /b
echo )
echo.
echo :: Remove old backups
echo echo Cleaning up backups older than %%DAYS_TO_KEEP%% days...
echo forfiles /p "%%BACKUP_DIR%%" /m "world_backup_*.tar.gz" /d -%%DAYS_TO_KEEP%% /c "cmd /c del @path"
echo.
echo echo Backup complete: %%BACKUP_DIR%%\world_backup_%%TIMESTAMP%%.tar.gz
echo pause
) > backup_server.bat

:: Create README file
(
echo Minecraft NeoForge Server
echo ========================
echo.
echo Server Information:
echo - Version: %MC_VERSION%
echo - NeoForge: %NEOFORGE_VERSION%
echo.
echo Connection Info:
echo - Java Edition: %LOCAL_IP%:25565
echo - Bedrock Edition: %LOCAL_IP%:19132
echo.
echo Management Commands:
echo - Start server: docker-compose up -d
echo - Stop server: docker-compose down
echo - Create backup: backup_server.bat
echo - Update mods: Update the files in %JAVA_MODS_DIR%
echo.
echo Backup automatically runs every 5 days
) > README.txt

:: Final instructions
echo.
echo =============================================
echo SETUP COMPLETE!
echo.
echo Your server is ready with these access points:
echo Java:    %LOCAL_IP%:25565
echo Bedrock: %LOCAL_IP%:19132
echo.
echo To start your server:
echo 1. Open Docker Desktop and wait for it to start
echo 2. Run: docker-compose up -d
echo.
echo To create a manual backup:
echo Run: backup_server.bat
echo.
echo A README.txt file has been created with these instructions
echo =============================================
pause
