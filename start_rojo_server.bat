@echo off
chcp 65001 >nul
title Rojo - Pump Lot Server (Port 34872)
echo ========================================================
echo   ⛽ ปั๊มหลอดท้ายทุ่ง - Rojo Live Sync (SERVER - Port 34872)
echo ========================================================

"%~dp0tools\rojo.exe" plugin install >nul
if exist "%~dp0tools\studio\ClaudeDevBridge.lua" copy /Y "%~dp0tools\studio\ClaudeDevBridge.lua" "%LOCALAPPDATA%\Roblox\Plugins\ClaudeDevBridge.lua" >nul
if exist "%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm" del "%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm"
echo [OK] ติดตั้งปลั๊กอิน Rojo 7.7.1 (RojoManagedPlugin) เรียบร้อยแล้ว
echo.
echo กำลังเปิดเซิร์ฟเวอร์ Rojo ที่พอร์ต 34872 (สำหรับ place Pump Lot)...
echo 👉 ใน Roblox Studio (แมพปั๊ม) ไปที่แท็บ Plugins -^> กดปุ่ม Rojo -^> Port 34872 -^> กด Connect!
echo.
"%~dp0tools\rojo.exe" serve "%~dp0default.project.json" --port 34872
pause
