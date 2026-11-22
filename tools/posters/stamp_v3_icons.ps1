Add-Type -AssemblyName System.Drawing

$rawDir = "c:\xampp\htdocs\roblox_anomaly\assets\thumbnails\raw"
$outDir = "c:\xampp\htdocs\roblox_anomaly\assets\thumbnails"
$artDir = "C:\Users\ZeroOne\.gemini\antigravity\brain\68732567-3bf2-4f8b-b4a5-91d0410ff9e9"

$thaiTitle = [System.Text.Encoding]::UTF8.GetString([byte[]]@(
    0xE0,0xB8,0x9B, 0xE0,0xB8,0xB1, 0xE0,0xB9,0x8A, 0xE0,0xB8,0xA1,
    0xE0,0xB8,0xAB, 0xE0,0xB8,0xA5, 0xE0,0xB8,0xAD, 0xE0,0xB8,0x94,
    0xE0,0xB8,0x97, 0xE0,0xB9,0x89, 0xE0,0xB8,0xB2, 0xE0,0xB8,0xA2,
    0xE0,0xB8,0x97, 0xE0,0xB8,0xB8, 0xE0,0xB9,0x88, 0xE0,0xB8,0x87
))
$subText = "Anomaly"

function DrawLogo($bmp) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $w = $bmp.Width
    $h = $bmp.Height
    $cx = [int]($w * 0.50)
    $cy = [int]($h * 0.80)

    # Dark soft glow behind logo
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gw = 820
    $gh = 265
    $glowRect = New-Object System.Drawing.Rectangle ($cx - [int]($gw / 2)), ($cy - [int]($gh * 0.45)), $gw, $gh
    $path.AddEllipse($glowRect)
    $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
    $pgb.CenterColor = [System.Drawing.Color]::FromArgb(230, 0, 0, 0)
    $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.FillPath($pgb, $path)

    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    $mainSize = 114
    $subSize  = 74
    $mainFont = New-Object System.Drawing.Font "Leelawadee UI", $mainSize, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $subFont  = New-Object System.Drawing.Font "Georgia", $subSize, ([System.Drawing.FontStyle]::Italic -bor [System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)

    $blackBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 5, 2, 2))
    $whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 250, 246, 240))
    $redBrush   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 235, 38, 38))

    $mainY = $cy - 30
    foreach ($dx in -8..8) {
        foreach ($dy in -8..8) {
            if (($dx * $dx + $dy * $dy) -le 52) {
                $g.DrawString($thaiTitle, $mainFont, $blackBrush, ($cx + $dx), ($mainY + $dy), $sf)
            }
        }
    }
    $g.DrawString($thaiTitle, $mainFont, $whiteBrush, $cx, $mainY, $sf)

    $subY = $cy + 64
    foreach ($dx in -6..6) {
        foreach ($dy in -6..6) {
            if (($dx * $dx + $dy * $dy) -le 28) {
                $g.DrawString($subText, $subFont, $blackBrush, ($cx + $dx), ($subY + $dy), $sf)
            }
        }
    }
    $g.DrawString($subText, $subFont, $redBrush, $cx, $subY, $sf)

    $g.Dispose()
}

$jobs = @(
    @("v3_graded_pop_pump.png",     "icon_v3_1_pop_pump.png"),
    @("v3_graded_icon3_pop.png",    "icon_v3_2_pop_bright.png"),
    @("v3_graded_icon4_pump.png",   "icon_v3_3_pump_pop.png"),
    @("v3_graded_icon2_takhon.png", "icon_v3_4_takhon_pump.png"),
    @("v3_graded_krasue_pump.png",  "icon_v3_5_krasue_pump.png"),
    @("v3_graded_icon1_dancer.png", "icon_v3_6_dancer.png")
)

foreach ($j in $jobs) {
    $src = Join-Path $rawDir $j[0]
    $dst = Join-Path $outDir $j[1]
    $art = Join-Path $artDir $j[1]

    $img = [System.Drawing.Bitmap]::FromFile($src)
    $bmp = New-Object System.Drawing.Bitmap $img.Width, $img.Height
    $g0 = [System.Drawing.Graphics]::FromImage($bmp)
    $g0.DrawImage($img, 0, 0, $img.Width, $img.Height)
    $g0.Dispose()
    $img.Dispose()

    DrawLogo $bmp
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Save($art, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "SAVED: $dst"
}
