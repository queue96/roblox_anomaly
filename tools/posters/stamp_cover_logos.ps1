Add-Type -AssemblyName System.Drawing

$rawDir = "c:\xampp\htdocs\roblox_anomaly\assets\thumbnails\raw"
$outDir = "c:\xampp\htdocs\roblox_anomaly\assets\thumbnails"
$artDir = "C:\Users\ZeroOne\.gemini\antigravity\brain\7a90a2f9-c20c-4236-b88f-abe39b61d5cf"

# UTF-8 Thai title: "ปั๊มหลอดท้ายทุ่ง"
$thaiTitle = [System.Text.Encoding]::UTF8.GetString([byte[]]@(
    0xE0,0xB8,0x9B, 0xE0,0xB8,0xB1, 0xE0,0xB9,0x8A, 0xE0,0xB8,0xA1,
    0xE0,0xB8,0xAB, 0xE0,0xB8,0xA5, 0xE0,0xB8,0xAD, 0xE0,0xB8,0x94,
    0xE0,0xB8,0x97, 0xE0,0xB9,0x89, 0xE0,0xB8,0xB2, 0xE0,0xB8,0xA2,
    0xE0,0xB8,0x97, 0xE0,0xB8,0xB8, 0xE0,0xB9,0x88, 0xE0,0xB8,0x87
))
$subText = "Anomaly"

function DrawLogo($bmp, $alignRight) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $w = $bmp.Width
    $h = $bmp.Height
    $isSquare = ($w -eq $h)

    $cx = if ($alignRight) { [int]($w * 0.77) } else { [int]($w * 0.50) }
    $cy = if ($isSquare) { [int]($h * 0.80) } else { [int]($h * 0.82) }

    # Dark soft glow behind logo like Somtum Anomaly
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gw = if ($isSquare) { 780 } else { 640 }
    $gh = if ($isSquare) { 250 } else { 210 }
    $glowRect = New-Object System.Drawing.Rectangle ($cx - [int]($gw / 2)), ($cy - [int]($gh * 0.45)), $gw, $gh
    $path.AddEllipse($glowRect)
    $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
    $pgb.CenterColor = [System.Drawing.Color]::FromArgb(225, 0, 0, 0)
    $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.FillPath($pgb, $path)

    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    $mainSize = if ($isSquare) { 108 } else { 92 }
    $subSize  = if ($isSquare) { 68 } else { 56 }
    $mainFont = New-Object System.Drawing.Font "Leelawadee UI", $mainSize, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $subFont  = New-Object System.Drawing.Font "Georgia", $subSize, ([System.Drawing.FontStyle]::Italic -bor [System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)

    $blackBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 5, 2, 2))
    $whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 245, 242, 238))
    $redBrush   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 195, 24, 24))

    # Draw Main Title with thick dark shadow/stroke
    $mainY = if ($isSquare) { $cy - 28 } else { $cy - 22 }
    foreach ($dx in -7..7) {
        foreach ($dy in -7..7) {
            if (($dx * $dx + $dy * $dy) -le 45) {
                $g.DrawString($thaiTitle, $mainFont, $blackBrush, ($cx + $dx), ($mainY + $dy), $sf)
            }
        }
    }
    $g.DrawString($thaiTitle, $mainFont, $whiteBrush, $cx, $mainY, $sf)

    # Draw "Anomaly" in crimson red below
    $subY = if ($isSquare) { $cy + 62 } else { $cy + 52 }
    foreach ($dx in -5..5) {
        foreach ($dy in -5..5) {
            if (($dx * $dx + $dy * $dy) -le 22) {
                $g.DrawString($subText, $subFont, $blackBrush, ($cx + $dx), ($subY + $dy), $sf)
            }
        }
    }
    $g.DrawString($subText, $subFont, $redBrush, $cx, $subY, $sf)

    $g.Dispose()
}

$jobs = @(
    @("graded_shot1_cctv_counter.png",      "ingame_1_cctv_counter.png",      $true),
    @("graded_shot2_counter_closeup.png",   "ingame_2_counter_closeup.png",   $false),
    @("graded_shot3_ghost_back_red.png",    "ingame_3_ghost_back_red.png",    $false),
    @("graded_shot4_fuelpumps_closeup.png", "ingame_4_fuelpumps_closeup.png", $false),
    @("graded_icon1_dancer.png",            "icon_1_dancer.png",              $false),
    @("graded_icon2_takhon.png",            "icon_2_takhon.png",              $false),
    @("graded_icon3_pop.png",               "icon_3_pop.png",                 $false),
    @("graded_icon4_pump.png",              "icon_4_pump.png",                $false)
)

foreach ($j in $jobs) {
    $src = Join-Path $rawDir $j[0]
    $dst = Join-Path $outDir $j[1]
    $art = Join-Path $artDir $j[1]
    $cleanDst = Join-Path $outDir ("clean_" + $j[1])

    Copy-Item -Force $src $cleanDst
    $img = [System.Drawing.Bitmap]::FromFile($src)
    $bmp = New-Object System.Drawing.Bitmap $img.Width, $img.Height
    $g0 = [System.Drawing.Graphics]::FromImage($bmp)
    $g0.DrawImage($img, 0, 0, $img.Width, $img.Height)
    $g0.Dispose()
    $img.Dispose()

    DrawLogo $bmp $j[2]
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Save($art, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "SAVED: $dst"
}
