@echo off
chcp 65001 >nul
echo ========================================================
echo   ⛽ ปั๊มหลอดท้ายทุ่ง - Rojo Live Sync (LOBBY place) (v7.7.1)
echo ========================================================

if not exist "%LOCALAPPDATA%\Roblox\Plugins" mkdir "%LOCALAPPDATA%\Roblox\Plugins"
copy /Y "%~dp0tools\Rojo.rbxm" "%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm" >nul
echo [OK] ติดตั้งปลั๊กอิน Rojo ลงใน Roblox Studio เรียบร้อยแล้ว!
echo.
echo กำลังเปิดเซิร์ฟเวอร์ Rojo ที่พอร์ต 34873 (สำหรับ place Lobby)...
echo 👉 ให้เปิดโปรแกรม Roblox Studio แล้วไปที่แท็บ Plugins -^> เปิดหน้าต่าง Lobby -^> กดปุ่ม Rojo -^> เปลี่ยน Port เป็น 34873 -^> กด Connect (ห้าม Connect ที่ Pump Lot)
echo.
"%~dp0tools\rojo.exe" serve "%~dp0lobby.project.json"
pause
