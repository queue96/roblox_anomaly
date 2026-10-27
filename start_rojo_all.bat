@echo off
chcp 65001 >nul
echo ========================================================
echo   ⛽ ปั๊มหลอดท้ายทุ่ง - เปิด Rojo ทั้ง 2 place พร้อมกัน
echo ========================================================
echo  - หน้าต่าง "Rojo - Pump Lot" พอร์ต 34872 : Connect ในหน้าต่าง Pump Lot
echo  - หน้าต่าง "Rojo - Lobby" พอร์ต 34873 : Connect ในหน้าต่าง Lobby (เปลี่ยน Port เป็น 34873)
start "Rojo - Pump Lot (34872)" "%~dp0start_rojo.bat"
start "Rojo - Lobby (34873)" "%~dp0start_rojo_lobby.bat"
