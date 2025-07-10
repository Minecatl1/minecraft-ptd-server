@echo off
setlocal enabledelayedexpansion

:: =============================================
:: AUTO-JAVA 21 INSTALLER + PIXELMON FIX
:: =============================================

:: Check if Java 21 exists
where java >nul 2>&1
if %errorlevel% equ 0 (
    java -version 2>&1 | findstr /i "version 21" >nul
    if !errorlevel! equ 0 (
        echo [OK] Java 21 is installed
        goto START_SERVER
    )
)

:: --- Java 21 Installer ---
echo.
echo [WARNING] Java 21 not found! Installing...
echo.

:: Download Adoptium JDK 21 (Temurin)
set JDK_URL=https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jdk_x64_windows_hotspot_21.0.3_9.msi
set INSTALL_DIR=%ProgramFiles%\Eclipse Adoptium\jdk-21.0.3.9-hotspot

echo Downloading Java 21...
powershell -command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%JDK_URL%' -OutFile 'jdk21.msi'"

echo Installing Java 21 silently...
msiexec /i "jdk21.msi" INSTALLDIR="%INSTALL_DIR%" ADDLOCAL=FeatureMain,FeatureEnvironment /qn

:: Add to PATH
setx JAVA_HOME "%INSTALL_DIR%" /m
setx PATH "%PATH%;%INSTALL_DIR%\bin" /m

:: Cleanup
del jdk21.msi

:: --- Pixelmon Data Fix ---
:START_SERVER
echo.
echo Fixing Pixelmon TCG data...
rmdir /s /q "world\datapacks\pixelmon" 2>nul
rmdir /s /q "config\pixelmon" 2>nul

:: --- Start Server ---
echo.
echo Starting Minecraft server...
"%JAVA_HOME%\bin\java.exe" -Xmx12G -Xms2500M -jar server.jar nogui

pause
