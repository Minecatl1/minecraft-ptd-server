@echo off
SETLOCAL EnableDelayedExpansion
title Family Minecraft Server Setup Manager
color 0A

:: Configuration
set "MC_VERSION=1.21.1"
set "NEOFORGE_VERSION=21.1.186"
set "SERVER_JAR=server.jar"
set "JAVA_MODS_DIR=mods\java"
set "BEDROCK_MODS_DIR=mods\bedrock"
set "total_steps=7"
set "current_step=0"

:: Create Server Management folder
set "desktop=%USERPROFILE%\Desktop"
set "server_dir=%desktop%\Family Server Management"
mkdir "%server_dir%" 2>nul
cd /d "%server_dir%"

:: Check Windows version
ver | findstr /i "10." > nul || ver | findstr /i "11." > nul || (
    echo ERROR: This script requires Windows 10 or 11
    pause
    exit /b 1
)

:: Check admin rights
fltmc >nul 2>&1 || (
    echo ERROR: Please run as Administrator
    pause
    exit /b 1
)

:: Get current user
for /f "tokens=2 delims= " %%a in ('whoami /user /fo table /nh') do set "CURRENT_USER=%%a"

:: Progress display function
:show_progress
set /a "percent=(current_step*100)/total_steps"
set "progress_bar="
for /l %%i in (1,1,20) do (
    set /a "pos=percent / 5"
    if %%i leq !pos! (set "progress_bar=!progress_bar!■") else (set "progress_bar=!progress_bar!.")
)
echo.
echo [ !progress_bar! ] !percent!%% Complete
echo Step !current_step! of !total_steps!: %~1
echo.
goto :eof

:: Main execution
echo === Family Minecraft %MC_VERSION% Server Setup ===
echo Creating Family Server Management folder at:
echo "%server_dir%"
echo Please wait while we set up your server...
echo This may take 10-25 minutes depending on your internet speed

call :show_progress "Installing dependencies"
call :install_dependencies

set /a current_step+=1
call :show_progress "Creating directories"
call :setup_directories

set /a current_step+=1
call :show_progress "Downloading server"
call :download_minecraft_server

set /a current_step+=1
call :show_progress "Downloading mods"
call :download_java_mods

set /a current_step+=1
call :show_progress "Processing Bedrock addons"
call :process_mcaddons

set /a current_step+=1
call :show_progress "Creating Docker config"
call :create_docker_config

set /a current_step+=1
call :show_progress "Setting up backup system"
call :setup_backup_system

:: Fix permissions
icacls . /grant "%CURRENT_USER%":F /T >nul

set /a current_step+=1
call :show_progress "Finalizing setup"

echo === Setup Complete ===
echo Server will automatically restart if it crashes
echo Backups will be created every 4 days
echo.
echo Server files located at: 
echo "%server_dir%"
echo.
echo Start with: start-server.bat
echo Connect at:
echo - Java:    your-ip:25565
echo - Bedrock: your-ip:19132
echo - Voice:   your-ip:24454 (if enabled)
echo Also if you want console users to join use an phone and join the server there then tell the console users to friend the minecraft account so they can join
:: Create management scripts
call :create_management_scripts

echo.
echo Management scripts created in "%server_dir%"
echo - start-server.bat   : Start server with backup check
echo - stop-server.bat    : Stop server
echo - auto-restart.bat   : 24/7 operation with auto-restart
echo - backup-server.bat  : Create manual backup
echo - restore-backup.bat : Restore from backup
echo - update-mods.bat    : Update mods
echo.
echo NOTE: For 24/7 operation, run 'auto-restart.bat'
pause
exit /b

:install_dependencies
echo Installing dependencies...
echo Checking for Chocolatey...
if not exist "%ProgramData%\chocolatey\choco.exe" (
    echo Installing Chocolatey package manager...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
) else (
    echo Chocolatey already installed
)

echo Installing required packages...
choco install -y docker-desktop jdk17 wget unzip --no-progress
if errorlevel 1 (
    echo Failed to install dependencies
    exit /b 1
)

echo Starting Docker service...
net start docker >nul 2>&1
echo Adding user to docker group...
net localgroup dockerusers %CURRENT_USER% /add >nul 2>&1
exit /b 0

:setup_directories
echo Creating directory structure...
mkdir config 2>nul
mkdir world 2>nul
mkdir resource_packs 2>nul
mkdir behavior_packs 2>nul
mkdir scripts 2>nul
mkdir logs 2>nul
mkdir backups 2>nul
mkdir %JAVA_MODS_DIR% 2>nul
mkdir %BEDROCK_MODS_DIR% 2>nul
mkdir %BEDROCK_MODS_DIR%\behavior_packs 2>nul
mkdir %BEDROCK_MODS_DIR%\resource_packs 2>nul
exit /b 0

:download_minecraft_server
echo Downloading NeoForge...
powershell -Command "(New-Object Net.WebClient).DownloadFile('https://maven.neoforged.net/releases/net/neoforged/neoforge/%NEOFORGE_VERSION%/neoforge-%NEOFORGE_VERSION%-installer.jar', 'neoforge-installer.jar')"
if not exist "neoforge-installer.jar" (
    echo Failed to download NeoForge
    exit /b 1
)

echo Installing server...
java -jar neoforge-installer.jar --installServer
if errorlevel 1 (
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

:: Proper mod list implementation
set "mod_index=0"
set "mod_files[0]=create-neoforge.jar"
set "mod_urls[0]=https://www.curseforge.com/api/v1/mods/328085/files/6641610/download"
set "mod_files[1]=jei-neoforge.jar"
set "mod_urls[1]=https://cdn.modrinth.com/data/u6dRKJwZ/versions/TxS03dKM/jei-1.21.1-neoforge-19.21.0.247.jar"
set "mod_files[2]=geyser-neoforge.jar"
set "mod_urls[2]=https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge"
set "mod_files[3]=floodgate-neoforge.jar"
set "mod_urls[3]=https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar"
set "mod_files[4]=Worldedit-neoforge.jar"
set "mod_urls[4]=https://cdn.modrinth.com/data/1u6JkXh5/versions/WTAFvuRx/worldedit-mod-7.3.8.jar"
set "mod_files[5]=Pixelmon-neoforge.jar"
set "mod_urls[5]=https://www.curseforge.com/api/v1/mods/389487/files/6701628/download"
set "mod_files[6]=modernfix.jar"
set "mod_urls[6]=https://www.curseforge.com/api/v1/mods/790626/files/6609557/download"
set "mod_files[7]=Voicechat-neoforge.jar"
set "mod_urls[7]=https://cdn.modrinth.com/data/9eGKb6K1/versions/DtuPswKw/voicechat-neoforge-1.21.6-2.5.32.jar"
set "mod_files[8]=ftn-converter.jar"
set "mod_urls[8]=https://cdn.modrinth.com/data/u58R1TMW/versions/KrmWHpgS/connector-2.0.0-beta.8%%2B1.21.1-full.jar"
set "mod_files[9]=forged-fabric-api.jar"
set "mod_urls[9]=https://github.com/Sinytra/ForgifiedFabricAPI/releases/download/0.115.6%%2B2.1.1%%2B1.21.1/forgified-fabric-api-0.115.6+2.1.1+1.21.1.jar"
set "mod_files[10]=connecter-extras.jar"
set "mod_urls[10]=https://cdn.modrinth.com/data/FYpiwiBR/versions/dgLCqZyo/ConnectorExtras-1.12.1%%2B1.21.1.jar"
set "mod_files[11]=chest-cavity.jar"
set "mod_urls[11]=https://cdn.modrinth.com/data/eo1wLeXR/versions/rtvJdDF9/chestcavity-2.17.1.jar"
set "mod_files[12]=cloth-config.jar"
set "mod_urls[12]=https://cdn.modrinth.com/data/9s6osm5g/versions/izKINKFg/cloth-config-15.0.140-neoforge.jar"
set "mod_files[13]=forge-api.jar"
set "mod_urls[13]=https://cdn.modrinth.com/data/P7dR8mSH/versions/VP2WqQA9/fabric-api-0.116.2%%2B1.21.1.jar"

setlocal enabledelayedexpansion
:mod_download_loop
if defined mod_files[%mod_index%] (
    set "mod_name=!mod_files[%mod_index%]!"
    set "mod_url=!mod_urls[%mod_index%]!"
    
    echo Downloading !mod_name!...
    powershell -Command "(New-Object Net.WebClient).DownloadFile('!mod_url!', '%JAVA_MODS_DIR%\!mod_name!')"
    if not exist "%JAVA_MODS_DIR%\!mod_name!" (
        echo Failed to download !mod_name!
        exit /b 1
    )
    
    set /a mod_index+=1
    goto :mod_download_loop
)
endlocal
exit /b 0

:process_mcaddons
echo Processing Bedrock addons...
if not exist "%BEDROCK_MODS_DIR%\*.mcaddon" (
    echo No .mcaddon files found
    exit /b 0
)

for /r "%BEDROCK_MODS_DIR%" %%f in (*.mcaddon) do (
    echo Processing %%f...
    powershell -Command "Expand-Archive -Path '%%f' -DestinationPath '%BEDROCK_MODS_DIR%\temp' -Force"
    
    if exist "%BEDROCK_MODS_DIR%\temp\behavior_packs" (
        xcopy /s /e /y "%BEDROCK_MODS_DIR%\temp\behavior_packs\*" "%BEDROCK_MODS_DIR%\behavior_packs\" >nul
    )
    if exist "%BEDROCK_MODS_DIR%\temp\resource_packs" (
        xcopy /s /e /y "%BEDROCK_MODS_DIR%\temp\resource_packs\*" "%BEDROCK_MODS_DIR%\resource_packs\" >nul
    )
    
    rd /s /q "%BEDROCK_MODS_DIR%\temp" 2>nul
    del "%%f"
)

:: For Windows Home (no symlinks) - copy instead
xcopy /s /e /y "%BEDROCK_MODS_DIR%\behavior_packs\*" "behavior_packs\" >nul
xcopy /s /e /y "%BEDROCK_MODS_DIR%\resource_packs\*" "resource_packs\" >nul
exit /b 0

:create_docker_config
echo Creating Docker configuration...

(
echo FROM eclipse-temurin:17-jre-jammy
echo.
echo # Install dependencies
echo RUN apt-get update ^&^& apt-get install -y ^
echo     libxi6 libgl1-mesa-glx ^&^& ^
echo     rm -rf /var/lib/apt/lists/*
echo.
echo WORKDIR /server
echo COPY . .
echo.
echo # Health check
echo HEALTHCHECK --interval=30s --timeout=5s ^
echo     CMD netstat -tuln ^| grep -q 25565 ^|^| exit 1
echo.
echo # Auto-restart on crash
echo CMD ["sh", "-c", "while true; do java -Xms$MIN_RAM -Xmx$MAX_RAM ^
echo -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions ^
echo -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled ^
echo -jar %SERVER_JAR% nogui; echo 'Server crashed, restarting in 10 seconds...'; sleep 10; done"]
echo.
echo EXPOSE 25565/tcp 19132/udp 24454/udp
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
echo.
echo volumes:
echo   minecraft_data:
echo     driver: local
) > docker-compose.yml
exit /b 0

:setup_backup_system
echo Creating backup system...
mkdir backups 2>nul

:: Create backup script with single backup approach
(
    echo @echo off
    echo setlocal
    echo.
    echo echo [%%date%% %%time%%] Starting server backup...
    echo.
    echo :: Stop server to ensure consistent state
    echo docker-compose stop
    echo timeout /t 10 /nobreak ^>nul
    echo.
    echo :: Delete previous backup if exists
    echo del /q backups\latest_backup.zip 2^>nul
    echo.
    echo :: Create new backup
    echo powershell Compress-Archive -Path world, config, mods -DestinationPath "backups\latest_backup.zip" -CompressionLevel Optimal
    echo.
    echo :: Start server
    echo docker-compose up -d
    echo.
    echo echo [%%date%% %%time%%] Backup complete: backups\latest_backup.zip
    echo endlocal
) > backup-server.bat

:: Create scheduled task for automatic backups
(
    echo $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument '/c backup-server.bat'
    echo $trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 4 -At 3am
    echo $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    echo $principal = New-ScheduledTaskPrincipal -UserId "%USERDOMAIN%\%USERNAME%" -LogonType S4U -RunLevel Highest
    echo Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "MinecraftBackup" -Description "Auto-backup Minecraft server" -Settings $settings -Principal $principal
) > create-backup-task.ps1

echo Scheduled task script created. To enable automatic backups:
echo 1. Run PowerShell as Administrator
echo 2. Navigate to: "%server_dir%"
echo 3. Run: .\create-backup-task.ps1
echo.
exit /b 0

:create_management_scripts
:: Create start-server.bat with backup restoration
(
    echo @echo off
    echo SETLOCAL EnableDelayedExpansion
    echo.
    echo echo Checking for world data...
    echo if exist "world\level.dat" (
    echo    echo World data found. Starting server...
    echo ) else (
    echo    echo No world data found. Checking for backup...
    echo    if exist "backups\latest_backup.zip" (
    echo        echo Restoring from latest backup...
    echo        powershell -Command "Expand-Archive -Path 'backups\latest_backup.zip' -DestinationPath '.' -Force"
    echo        echo Backup restored successfully!
    echo    ) else (
    echo        echo No backup available. Starting fresh world...
    echo    )
    echo )
    echo.
    echo echo Starting Minecraft Server...
    echo docker-compose up -d
    echo echo Server is now running in the background
    echo echo Use "stop-server.bat" to stop the server
    echo pause
) > start-server.bat

:: Create stop-server.bat
(
    echo @echo off
    echo echo Stopping Minecraft Server...
    echo docker-compose stop
    echo echo Server has been stopped
    echo pause
) > stop-server.bat

:: Create auto-restart script
(
    echo @echo off
    echo :restart_loop
    echo docker-compose up
    echo echo Server crashed or stopped. Restarting in 10 seconds...
    echo timeout /t 10
    echo goto restart_loop
) > auto-restart.bat

:: Create restore-backup.bat
(
    echo @echo off
    echo SETLOCAL EnableDelayedExpansion
    echo.
    echo if exist "backups\latest_backup.zip" (
    echo    echo Restoring from latest backup...
    echo    docker-compose stop
    echo    timeout /t 5 /nobreak >nul
    echo    powershell -Command "Expand-Archive -Path 'backups\latest_backup.zip' -DestinationPath '.' -Force"
    echo    echo Backup restored successfully!
    echo    echo Start server with start-server.bat
    echo ) else (
    echo    echo No backup available!
    echo )
    echo pause
) > restore-backup.bat

:: Create mod update script
(
    echo @echo off
    echo SETLOCAL EnableDelayedExpansion
    echo.
    echo echo Updating mods...
    echo docker-compose stop
    echo timeout /t 5 /nobreak >nul
    echo.
    echo :: Re-download all mods
    echo call "%~dp0setup-server.bat" :download_java_mods
    echo.
    echo echo Mods updated successfully!
    echo echo Starting server...
    echo docker-compose up -d
    echo pause
) > update-mods.bat
exit /b 0
