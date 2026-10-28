@echo off
chcp 65001 >nul
title Rojo Launcher (34872 ^& 34873)
echo ========================================================
echo   ⛽ ปั๊มหลอดท้ายทุ่ง - เปิด Rojo v7.7.1 ทั้ง 2 พอร์ตพร้อมกัน
echo ========================================================
echo  - หน้าต่าง "Rojo - Pump Lot (34872)" : สำหรับแมพหลัก (Server) พอร์ต 34872
echo  - หน้าต่าง "Rojo - Lobby (34873)"    : สำหรับแมพวัด (Lobby) พอร์ต 34873
echo.
"%~dp0tools\rojo.exe" plugin install >nul
if exist "%~dp0tools\studio\ClaudeDevBridge.lua" copy /Y "%~dp0tools\studio\ClaudeDevBridge.lua" "%LOCALAPPDATA%\Roblox\Plugins\ClaudeDevBridge.lua" >nul
if exist "%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm" del "%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm"

start "Rojo - Lobby (34873)" "%~dp0start_rojo_lobby.bat"
call "%~dp0start_rojo_server.bat"
