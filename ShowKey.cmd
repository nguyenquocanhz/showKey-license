@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

:: ============================================================
::  Windows License Manager v2.0
::  Author: QuocAnh @ Gems Software
::  Requires: Run as Administrator
:: ============================================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Vui long chuot phai va chon "Run as Administrator"
    pause & exit /b 1
)

:MENU
cls
echo.
echo  ╔══════════════════════════════════════════╗
echo  ║      WINDOWS LICENSE MANAGER v2.0       ║
echo  ╚══════════════════════════════════════════╝
echo.
echo   [1]  Xem License hien tai
echo   [2]  Detect loai License (OEM / Retail / Volume)
echo   [3]  Check Digital License (Win 10/11)
echo   [4]  Lay OEM Key tu BIOS/UEFI firmware
echo   [5]  Backup License ra file TXT
echo   [6]  Remove / Uninstall License Key
echo.
echo   [0]  Thoat
echo.
echo  ══════════════════════════════════════════════
set /p "choice=  Chon: "

if "%choice%"=="1" goto VIEW_LIC
if "%choice%"=="2" goto DETECT_LIC
if "%choice%"=="3" goto CHECK_DIGITAL
if "%choice%"=="4" goto CHECK_OEM
if "%choice%"=="5" goto BACKUP_LIC
if "%choice%"=="6" goto REMOVE_LIC
if "%choice%"=="0" exit /b 0

echo  Lua chon khong hop le.
timeout /t 2 >nul
goto MENU

:: ============================================================
:VIEW_LIC
cls
echo.
echo  [VIEW] Thong tin License hien tai
echo  ══════════════════════════════════════════════
echo.
echo  --- Thong tin co ban (slmgr /dli) ---
cscript //nologo %windir%\System32\slmgr.vbs /dli
echo.
echo  --- Chi tiet mo rong (slmgr /dlv) ---
cscript //nologo %windir%\System32\slmgr.vbs /dlv
echo.
pause & goto MENU

:: ============================================================
:DETECT_LIC
cls
echo.
echo  [DETECT] Phan loai License
echo  ══════════════════════════════════════════════
echo.

:: ProductName
set "PROD="
for /f "tokens=3*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul') do set "PROD=%%A %%B"
if defined PROD (echo  ProductName       : %PROD%) else (echo  ProductName       : Khong tim thay)

:: EditionID
set "EID="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul') do set "EID=%%A"
if defined EID (echo  EditionID         : %EID%) else (echo  EditionID         : Khong tim thay)

:: ProductKeyChannel -> phan biet Retail / OEM / Volume
set "PKC="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductKeyChannel 2^>nul') do set "PKC=%%A"
if defined PKC (
    echo  ProductKeyChannel : %PKC%
    if /i "%PKC%"=="OEM:DM"      echo  Loai              : OEM - Digital (BIOS embedded)
    if /i "%PKC%"=="OEM:NONSLP"  echo  Loai              : OEM - Non-SLP
    if /i "%PKC%"=="Retail"      echo  Loai              : Retail
    if /i "%PKC%"=="Volume:MAK"  echo  Loai              : Volume - MAK
    if /i "%PKC%"=="Volume:GVLK" echo  Loai              : Volume - KMS (GVLK)
) else (
    echo  ProductKeyChannel : Khong tim thay
)

:: ProductId
set "PID_="
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductId 2^>nul') do set "PID_=%%A"
if defined PID_ (echo  ProductId         : %PID_%) else (echo  ProductId         : Khong tim thay)

:: Dung PowerShell lay LicenseStatus va Description
echo.
echo  --- Licensing Detail (PowerShell WMI) ---
powershell -NoProfile -Command ^
  "Get-WmiObject -Query 'SELECT Name,Description,LicenseStatus,GracePeriodRemaining FROM SoftwareLicensingProduct WHERE LicenseStatus=1 AND Name LIKE \"Windows%%\"' | ForEach-Object { Write-Host ('  Name        : ' + $_.Name); Write-Host ('  Description : ' + $_.Description); Write-Host ('  Status      : ' + $_.LicenseStatus); Write-Host ('  Grace (min) : ' + $_.GracePeriodRemaining) }"

echo.
pause & goto MENU

:: ============================================================
:CHECK_DIGITAL
cls
echo.
echo  [DIGITAL] Kiem tra Digital License
echo  ══════════════════════════════════════════════
echo.

:: Check DigitalProductId trong registry
set "HAS_DIG=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DigitalProductId >nul 2>&1
if %errorLevel%==0 set "HAS_DIG=1"

set "HAS_DIG4=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DigitalProductId4 >nul 2>&1
if %errorLevel%==0 set "HAS_DIG4=1"

if "%HAS_DIG%"=="1"  (echo  [OK] DigitalProductId    : Co trong registry) else (echo  [--] DigitalProductId    : Khong co)
if "%HAS_DIG4%"=="1" (echo  [OK] DigitalProductId4   : Co trong registry) else (echo  [--] DigitalProductId4   : Khong co)

:: Dung PowerShell kiem tra IsKeyManagementServiceMachine va KeyManagementServiceProductKeyID
echo.
powershell -NoProfile -Command ^
  "$s = Get-WmiObject -Query 'SELECT * FROM SoftwareLicensingService'; if ($s.IsKeyManagementServiceMachine -eq 1) { Write-Host '  KMS Server    : Day la may KMS Server' } else { Write-Host '  KMS Server    : Khong phai KMS Server' }; Write-Host ('  KMS Machine   : ' + $s.KeyManagementServiceMachine); Write-Host ('  KMS Port      : ' + $s.KeyManagementServicePort)"

echo.
echo  --- Ket qua kich hoat (slmgr /xpr) ---
cscript //nologo %windir%\System32\slmgr.vbs /xpr
echo.
pause & goto MENU

:: ============================================================
:CHECK_OEM
cls
echo.
echo  [OEM] Lay Product Key tu BIOS/UEFI firmware
echo  ══════════════════════════════════════════════
echo.
echo  Dang doc OEM key tu ACPI/WMI...
echo.

powershell -NoProfile -Command ^
  "try { $key = (Get-WmiObject -Query 'SELECT OA3xOriginalProductKey FROM SoftwareLicensingService').OA3xOriginalProductKey; if ($key) { Write-Host ('  OEM Key (BIOS): ' + $key) } else { Write-Host '  OEM Key       : Khong co key trong firmware (may khong co OEM embedded)' } } catch { Write-Host ('  Loi: ' + $_.Exception.Message) }"

echo.
:: Fallback: thu doc qua wmic thong thuong
echo  --- Fallback WMIC ---
wmic path SoftwareLicensingService get OA3xOriginalProductKey 2>nul

echo.
pause & goto MENU

:: ============================================================
:BACKUP_LIC
cls
echo.
echo  [BACKUP] Xuat thong tin License ra file TXT
echo  ══════════════════════════════════════════════
echo.

:: Tao ten file theo ngay gio
set "DT=%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "DT=%DT: =0%"
set "OUTFILE=%USERPROFILE%\Desktop\winlic_backup_%DT%.txt"

echo  Dang xuat ra: %OUTFILE%
echo  Vui long doi...
echo.

(
    echo ============================================================
    echo   WINDOWS LICENSE BACKUP
    echo   Ngay backup: %date% %time%
    echo   May tinh   : %COMPUTERNAME%
    echo   User       : %USERNAME%
    echo ============================================================
    echo.

    echo [1] REGISTRY INFO
    echo ============================================================
    reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName
    reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v EditionID
    reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductKeyChannel
    reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductId
    reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v BuildLabEx
    echo.

    echo [2] THONG TIN CO BAN - slmgr /dli
    echo ============================================================
    cscript //nologo %windir%\System32\slmgr.vbs /dli
    echo.

    echo [3] CHI TIET MO RONG - slmgr /dlv
    echo ============================================================
    cscript //nologo %windir%\System32\slmgr.vbs /dlv
    echo.

    echo [4] NGAY HET HAN - slmgr /xpr
    echo ============================================================
    cscript //nologo %windir%\System32\slmgr.vbs /xpr
    echo.

    echo [5] OEM KEY TU FIRMWARE
    echo ============================================================
    powershell -NoProfile -Command "(Get-WmiObject -Query 'SELECT OA3xOriginalProductKey FROM SoftwareLicensingService').OA3xOriginalProductKey"
    echo.

    echo [6] DIGITAL LICENSE
    echo ============================================================
    reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DigitalProductId  >nul 2>&1 && echo DigitalProductId  : TON TAI  || echo DigitalProductId  : KHONG CO
    reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DigitalProductId4 >nul 2>&1 && echo DigitalProductId4 : TON TAI  || echo DigitalProductId4 : KHONG CO
    echo.

    echo [7] POWERSHELL WMI DETAIL
    echo ============================================================
    powershell -NoProfile -Command "Get-WmiObject -Query 'SELECT Name,Description,LicenseStatus,GracePeriodRemaining FROM SoftwareLicensingProduct WHERE LicenseStatus=1 AND Name LIKE \"Windows%%\"' | Format-List"
    echo.

    echo ============================================================
    echo   END OF BACKUP
    echo ============================================================
) > "%OUTFILE%" 2>&1

if exist "%OUTFILE%" (
    echo  [OK] Backup thanh cong!
    echo  File: %OUTFILE%
    echo.
    set /p "open=Mo file ngay? (Y/N): "
    if /i "!open!"=="Y" notepad "%OUTFILE%"
) else (
    echo  [ERROR] Khong tao duoc file backup.
)

echo.
pause & goto MENU

:: ============================================================
:REMOVE_LIC
cls
echo.
echo  [REMOVE] Go cai dat Product Key
echo  ══════════════════════════════════════════════
echo.
echo  CANH BAO:
echo   - /upk  : Uninstall product key khoi Windows
echo   - /cpky : Xoa key khoi registry (an toan truoc khi ban may)
echo   - Sau do Windows se CHUA KICH HOAT
echo.
set /p "confirm=  Ban chac chan? Nhap YES de tiep tuc: "
if /i "%confirm%" neq "YES" (
    echo  Huy bo.
    timeout /t 2 >nul
    goto MENU
)

echo.
echo  Dang uninstall product key...
cscript //nologo %windir%\System32\slmgr.vbs /upk
echo.
echo  Dang xoa key khoi registry...
cscript //nologo %windir%\System32\slmgr.vbs /cpky
echo.
echo  [DONE] Product key da duoc go bo.
echo  Windows se hien thi trang thai chua kich hoat.
echo.
pause & goto MENU