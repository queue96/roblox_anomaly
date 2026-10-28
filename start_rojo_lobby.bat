@echo off
chcp 65001 >nul
title Rojo - Lobby (Port 34873)
echo ========================================================
echo   🛕 ปั๊มหลอดท้ายทุ่ง - Rojo Live Sync (LOBBY - Port 34873)
echo ========================================================

"%~dp0tools\rojo.exe" plugin install >nul
if exist "%~dp0tools\studio\ClaudeDevBridge.lua" copy /Y "%~dp0tools\studio\ClaudeDevBridge.lua" "%LOCALAPPDATA%\Roblox\Plugins\ClaudeDevBridge.lua" >nul
if exist "%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm" del "%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm"
echo [OK] ติดตั้งปลั๊กอิน Rojo 7.7.1 (RojoManagedPlugin) เรียบร้อยแล้ว
echo.
echo กำลังเปิดเซิร์ฟเวอร์ Rojo ที่พอร์ต 34873 (สำหรับ place Lobby)...
echo 👉 ใน Roblox Studio (แมพ Lobby) ไปที่แท็บ Plugins -^> กดปุ่ม Rojo -^> เปลี่ยน Port เป็น 34873 -^> กด Connect!
echo.
"%~dp0tools\rojo.exe" serve "%~dp0lobby.project.json" --port 34873
pause
