@echo off
"%SystemRoot%\System32\chcp.com" 936 >nul
setlocal EnableDelayedExpansion
title 无线网卡 5G 优先优化
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "NETSH=%SystemRoot%\System32\netsh.exe"

if /i "%~1"=="elev" goto run
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -Command "if(-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))){exit 1}"
if errorlevel 1 (
    echo 正在申请管理员权限，请在弹窗中点击“是”...
    "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList 'elev' -Verb RunAs -ErrorAction SilentlyContinue"
    exit /b
)

:run
cls
echo ============================================
echo        无线网卡 5G 优先一键优化
echo ============================================
echo.
echo [1/5] 识别无线网卡...
for /f "delims=" %%A in ('%PSEXE% -NoProfile -ExecutionPolicy Bypass -Command "(Get-NetAdapter -Physical | Where-Object {$_.PhysicalMediaType -eq 'Native 802.11'} | Select-Object -First 1).Name"') do set "WLAN=%%A"
if not defined WLAN for /f "delims=" %%A in ('%PSEXE% -NoProfile -ExecutionPolicy Bypass -Command "(Get-NetAdapter | Where-Object {$_.MediaType -eq 'Native 802.11'} | Select-Object -First 1).Name"') do set "WLAN=%%A"
if not defined WLAN goto nonic
echo     网卡：%WLAN%
echo.
echo [2/5] 记录优化前状态...
call :measure
set "B1=%B%"
set "S1=%S%"
set "SSID=%P%"
echo     频带：%B1%    协商速率：%S1%
echo.
echo [3/5] 设置首选频带为 5GHz...
for /f "delims=" %%A in ('%PSEXE% -NoProfile -ExecutionPolicy Bypass -Command "$n='%WLAN%';$p=Get-NetAdapterAdvancedProperty -Name $n | Where-Object { (($_.RegistryKeyword -match 'Preferred|RoamDesiredBand') -or ($_.DisplayName -match '首选频带|首选频段|Preferred Band')) -and ($_.DisplayName -notmatch 'Miracast|漫游|Roaming|Aggress') -and ($_.RegistryKeyword -notmatch 'Wfd') } | Select-Object -First 1;if(-not $p){$p=Get-NetAdapterAdvancedProperty -Name $n | Where-Object { ($_.RegistryKeyword -match 'BandSelect|BandSelection') -or ($_.DisplayName -match '频带选择|频段选择|Band Selection') } | Select-Object -First 1};$done='未找到频带选项';if($p){$v=(Get-NetAdapterAdvancedProperty -Name $n -RegistryKeyword $p.RegistryKeyword -All).ValidDisplayValues | Where-Object { ($_ -match '5') -and ($_ -notmatch '6G|6 GHz|2\.4') -and ($_ -match 'Hz|赫') } | Select-Object -First 1;if($v){try{Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword $p.RegistryKeyword -DisplayValue $v -NoRestart -ErrorAction Stop;$done=$v}catch{$done='设置失败'}}};$done"') do set "BANDSET=%%A"
echo     结果：%BANDSET%
echo.
echo [4/5] 关闭网卡节能选项...
for /f "delims=" %%A in ('%PSEXE% -NoProfile -ExecutionPolicy Bypass -Command "$n='%WLAN%';$ok='设置失败，请手动处理';try{Set-NetAdapterPowerManagement -Name $n -AllowComputerToTurnOffDevice Disabled -ErrorAction Stop;$ok='已关闭'}catch{$g=(Get-NetAdapter -Name $n).InterfaceGuid;$c=Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).NetCfgInstanceId -eq $g };if($c){Set-ItemProperty -Path $c.PSPath -Name PnPCapabilities -Value 24 -Type DWord -ErrorAction SilentlyContinue;$ok='已关闭'}};$ok"') do set "PWR=%%A"
echo     结果：%PWR%
echo.
echo [5/5] 重新连接网络并复测...
if defined SSID (
    "%NETSH%" wlan disconnect >nul 2>&1
    "%SystemRoot%\System32\timeout.exe" /t 3 /nobreak >nul
    "%NETSH%" wlan connect name="%SSID%" >nul 2>&1
    "%SystemRoot%\System32\timeout.exe" /t 8 /nobreak >nul
)
call :measure
set "B2=%B%"
set "S2=%S%"
if not "%B2%"=="未知" goto done2
"%SystemRoot%\System32\timeout.exe" /t 8 /nobreak >nul
call :measure
set "B2=%B%"
set "S2=%S%"
:done2
echo     频带：%B2%    协商速率：%S2%
echo.
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms;$l=[char]10;$t='网卡：%WLAN%'+$l+$l+'优化前：频带 %B1% ／ 速率 %S1%'+$l+'优化后：频带 %B2% ／ 速率 %S2%'+$l+$l+'首选频带：%BANDSET%'+$l+'节能电源：%PWR%';[System.Windows.Forms.MessageBox]::Show($t,'无线网卡 5G 优化结果',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)|Out-Null"
exit /b

:measure
for /f "tokens=1,2,3 delims=|" %%A in ('%PSEXE% -NoProfile -ExecutionPolicy Bypass -Command "$n='%WLAN%';$o=(& (Join-Path $env:SystemRoot 'System32\netsh.exe') wlan show interfaces) -join [char]10;$b='未知';if($o -match '6\s*GHz'){$b='6GHz'}elseif($o -match '5\s*GHz'){$b='5GHz'}elseif($o -match '2\.4\s*GHz'){$b='2.4GHz'};$r='-';if($o -match '(?im)[ \t]*Mbps[\)\s]*:[ \t]*(\d+\.?\d*)'){$r=$matches[1]+' Mbps'}else{$r=(Get-NetAdapter -Name $n).LinkSpeed};$p='';if($o -match '(?im)^[ \t]*SSID[ \t]*:[ \t]*([^\r\n]+)'){$p=$matches[1].Trim()};$b+'|'+$r+'|'+$p"') do (
    set "B=%%A"
    set "S=%%B"
    set "P=%%C"
)
exit /b

:nonic
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms;[System.Windows.Forms.MessageBox]::Show('未检测到可用的无线网卡，请确认无线网卡已启用后再运行。','无线网卡 5G 优化结果',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)|Out-Null"
exit /b