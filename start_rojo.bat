@echo off
chcp 65001 >nul
echo ========================================================
echo   ⛽ ปั๊มหลอดท้ายทุ่ง - Rojo Live Sync Server (v7.7.1)
echo ========================================================

"%~dp0tools\rojo.exe" plugin install >nul
if exist "%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm" del "%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm"
echo [OK] ติดตั้งปลั๊กอิน Rojo 7.7.1 (RojoManagedPlugin) เรียบร้อยแล้ว — ถ้า Studio เปิดอยู่ให้ปิดแล้วเปิดใหม่!
echo.
echo กำลังเปิดเซิร์ฟเวอร์ Rojo ที่พอร์ต 34872...
echo 👉 ให้เปิดโปรแกรม Roblox Studio แล้วไปที่แท็บ Plugins -^> กดปุ่ม Rojo -^> กด Connect ได้เลย!
echo.
"%~dp0tools\rojo.exe" serve "%~dp0default.project.json"
pause
