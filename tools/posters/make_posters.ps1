# Base art for the shop's old posters (fictional brands) drawn with GDI+ so Thai vowels/tone marks are shaped correctly.
# Run:  powershell -ExecutionPolicy Bypass -File tools/posters/make_posters.ps1
# Output: assets/textures/shack/raw/*.png (clean art; tools/blender/shack_dressing.py ages it into the final decals)
# Thai strings live in poster_text.json (UTF-8) because Windows PowerShell 5.1 reads .ps1 files as ANSI.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = Join-Path $root "assets\textures\shack\raw"
New-Item -ItemType Directory -Force $out | Out-Null
$T = Get-Content (Join-Path $PSScriptRoot "poster_text.json") -Raw -Encoding UTF8 | ConvertFrom-Json

function C($r, $g, $b) { [System.Drawing.Color]::FromArgb(255, $r, $g, $b) }
function Brush($c) { New-Object System.Drawing.SolidBrush $c }
function NewCanvas($w, $h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    return @($bmp, $g)
}
function Save($bmp, $g, $name) {
    $g.Dispose()
    $bmp.Save((Join-Path $out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "saved raw/$name.png"
}
# Text centred in a box, shrunk until it fits the width; optional dark outline for poster headlines
function Text($g, $s, $family, $size, $style, $color, $x, $y, $w, $h, $outline = $null) {
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    do {
        $font = New-Object System.Drawing.Font $family, $size, $style, ([System.Drawing.GraphicsUnit]::Pixel)
        $m = $g.MeasureString($s, $font)
        $size -= 2
    } while ($m.Width -gt $w -and $size -gt 8)
    $rect = New-Object System.Drawing.RectangleF $x, $y, $w, $h
    if ($outline) {
        $ob = Brush $outline
        foreach ($d in @(@(-3, 0), @(3, 0), @(0, -3), @(0, 3), @(-2, -2), @(2, 2), @(-2, 2), @(2, -2))) {
            $r2 = New-Object System.Drawing.RectangleF ($x + $d[0]), ($y + $d[1]), $w, $h
            $g.DrawString($s, $font, $ob, $r2, $sf)
        }
    }
    $g.DrawString($s, $font, (Brush $color), $rect, $sf)
}
$BOLD = [System.Drawing.FontStyle]::Bold
$REG = [System.Drawing.FontStyle]::Regular
$HEAD = "FreesiaUPC"
$BODY = "Leelawadee"

# ---------------------------------------------------------------- 1. fertilizer (green / gold buffalo)
$c = NewCanvas 512 768; $bmp = $c[0]; $g = $c[1]
$g.Clear((C 28 92 44))
$g.FillRectangle((Brush (C 186 32 28)), 0, 0, 512, 120)
Text $g $T.fertilizer.title $HEAD 120 $BOLD (C 250 214 70) 10 8 492 110 (C 70 10 8)
$gold = Brush (C 232 186 70)
$g.FillEllipse((Brush (C 18 60 28)), 106, 170, 300, 300)
$g.FillEllipse($gold, 186, 270, 140, 160)
$pen = New-Object System.Drawing.Pen (C 232 186 70), 26
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawArc($pen, 96, 200, 170, 130, 180, 110)
$g.DrawArc($pen, 246, 200, 170, 130, 250, 110)
$g.FillEllipse((Brush (C 18 60 28)), 216, 330, 24, 22); $g.FillEllipse((Brush (C 18 60 28)), 272, 330, 24, 22)
$g.DrawEllipse((New-Object System.Drawing.Pen (C 232 186 70), 6), 106, 170, 300, 300)
Text $g $T.fertilizer.sub $BODY 44 $BOLD (C 255 255 240) 20 490 472 80
$g.FillRectangle((Brush (C 250 214 70)), 0, 640, 512, 128)
Text $g $T.fertilizer.foot $BODY 34 $BOLD (C 30 60 30) 10 650 492 100
Save $bmp $g "Poster_Fertilizer"

# ---------------------------------------------------------------- 2. energy drink (red sunburst / brown bottle)
$c = NewCanvas 512 768; $bmp = $c[0]; $g = $c[1]
$g.Clear((C 200 40 26))
$cx = 256; $cy = 380
for ($i = 0; $i -lt 24; $i += 2) {
    $a0 = $i * [Math]::PI / 12; $a1 = ($i + 1) * [Math]::PI / 12
    $pts = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF $cx, $cy),
        (New-Object System.Drawing.PointF ($cx + 900 * [Math]::Cos($a0)), ($cy + 900 * [Math]::Sin($a0))),
        (New-Object System.Drawing.PointF ($cx + 900 * [Math]::Cos($a1)), ($cy + 900 * [Math]::Sin($a1))))
    $g.FillPolygon((Brush (C 236 120 30)), $pts)
}
$g.FillRectangle((Brush (C 92 48 22)), 206, 250, 100, 280)
$g.FillRectangle((Brush (C 92 48 22)), 236, 190, 40, 70)
$g.FillRectangle((Brush (C 230 190 40)), 236, 180, 40, 18)
$g.FillRectangle((Brush (C 250 220 70)), 206, 330, 100, 110)
Text $g $T.energy.label $HEAD 70 $BOLD (C 180 20 20) 206 330 100 110
Text $g $T.energy.title $HEAD 150 $BOLD (C 255 230 60) 10 20 492 150 (C 40 10 6)
Text $g $T.energy.sub $BODY 40 $BOLD (C 255 255 255) 10 560 492 70 (C 60 10 6)
Text $g $T.energy.foot $BODY 32 $BOLD (C 255 230 120) 10 640 492 90
Save $bmp $g "Poster_Energy"

# ---------------------------------------------------------------- 3. engine oil (white / blue / green dragon band)
$c = NewCanvas 512 768; $bmp = $c[0]; $g = $c[1]
$g.Clear((C 238 236 226))
$g.FillRectangle((Brush (C 30 70 150)), 0, 520, 512, 248)
$dragon = New-Object System.Collections.Generic.List[System.Drawing.PointF]
for ($x = 0; $x -le 512; $x += 8) { $dragon.Add((New-Object System.Drawing.PointF $x, (300 + 40 * [Math]::Sin($x / 50.0)))) }
for ($x = 512; $x -ge 0; $x -= 8) { $dragon.Add((New-Object System.Drawing.PointF $x, (360 + 40 * [Math]::Sin($x / 50.0 + 0.6)))) }
$g.FillPolygon((Brush (C 34 130 60)), $dragon.ToArray())
$g.FillEllipse((Brush (C 34 130 60)), 420, 250, 90, 80)
$g.FillEllipse((Brush (C 250 220 60)), 470, 270, 16, 16)
$g.FillRectangle((Brush (C 200 40 30)), 150, 390, 160, 120)
$g.FillRectangle((Brush (C 200 40 30)), 270, 370, 30, 30)
$g.FillRectangle((Brush (C 250 240 230)), 165, 420, 130, 50)
Text $g $T.oil.pre $BODY 46 $BOLD (C 30 70 150) 10 20 492 70
Text $g $T.oil.title $HEAD 130 $BOLD (C 30 120 56) 10 80 492 150 (C 10 40 20)
Text $g $T.oil.sub $BODY 40 $BOLD (C 255 255 255) 10 540 492 80
Text $g $T.oil.foot $BODY 28 $REG (C 220 230 255) 10 630 492 100
Save $bmp $g "Poster_Oil"

# ---------------------------------------------------------------- 4. wall calendar (2535 = 1992, August)
$c = NewCanvas 512 768; $bmp = $c[0]; $g = $c[1]
$g.Clear((C 246 242 228))
$sky = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 30), (New-Object System.Drawing.Point 0, 250), (C 120 170 220), (C 230 220 190)
$g.FillRectangle($sky, 20, 30, 472, 220)
$g.FillRectangle((Brush (C 80 150 60)), 20, 200, 472, 110)
for ($i = 0; $i -lt 14; $i++) { $g.DrawLine((New-Object System.Drawing.Pen (C 60 120 40), 3), (20 + $i * 36), 310, (240 + $i * 8), 200) }
$g.FillPolygon((Brush (C 90 60 40)), [System.Drawing.Point[]]@((New-Object System.Drawing.Point 330, 200), (New-Object System.Drawing.Point 380, 160), (New-Object System.Drawing.Point 430, 200)))
$g.FillRectangle((Brush (C 120 84 50)), 340, 200, 80, 40)
$g.FillEllipse((Brush (C 40 40 40)), 120, 6, 18, 18); $g.FillEllipse((Brush (C 40 40 40)), 374, 6, 18, 18)
$g.FillRectangle((Brush (C 190 30 30)), 20, 316, 472, 56)
Text $g $T.calendar.year $HEAD 64 $BOLD (C 255 240 210) 20 316 472 56
Text $g $T.calendar.month $HEAD 64 $BOLD (C 40 40 40) 20 372 472 54
$digits = $T.calendar.digits
function ThaiNum($n) { (($n.ToString()).ToCharArray() | ForEach-Object { $digits[[int]::Parse($_)] }) -join "" }
$cw = 472 / 7
for ($d = 0; $d -lt 7; $d++) {
    $col = if ($d -eq 0) { (C 190 30 30) } else { (C 40 40 40) }
    Text $g $T.calendar.days[$d] $BODY 26 $BOLD $col (20 + $d * $cw) 428 $cw 34
}
# 1 Aug 2535 (1992) was a Saturday
$start = 6
for ($day = 1; $day -le 31; $day++) {
    $slot = $start + $day - 1
    $r = [Math]::Floor($slot / 7); $k = $slot % 7
    $col = if ($k -eq 0) { (C 190 30 30) } else { (C 50 50 50) }
    Text $g (ThaiNum $day) $BODY 28 $REG $col (20 + $k * $cw) (464 + $r * 40) $cw 38
}
Text $g $T.calendar.shop $BODY 24 $BOLD (C 120 30 30) 20 712 472 50
Save $bmp $g "Calendar"

# ---------------------------------------------------------------- 5. yantra cloth (red ink on cream cloth)
$c = NewCanvas 512 512; $bmp = $c[0]; $g = $c[1]
$g.Clear((C 232 222 192))
$ink = C 150 28 24
$p4 = New-Object System.Drawing.Pen $ink, 4
$p2 = New-Object System.Drawing.Pen $ink, 2
$g.DrawRectangle($p4, 24, 24, 464, 464); $g.DrawRectangle($p2, 36, 36, 440, 440)
for ($i = 1; $i -lt 3; $i++) { $g.DrawLine($p2, (36 + $i * 440 / 3), 36, (36 + $i * 440 / 3), 476); $g.DrawLine($p2, 36, (36 + $i * 440 / 3), 476, (36 + $i * 440 / 3)) }
$g.DrawLine($p2, 36, 36, 476, 476); $g.DrawLine($p2, 476, 36, 36, 476)
$g.DrawEllipse($p4, 196, 196, 120, 120)
$spiral = New-Object System.Collections.Generic.List[System.Drawing.PointF]
for ($sp = 0; $sp -le 36; $sp++) { $a = $sp * 0.5; $rr = 4 + $sp * 1.4; $spiral.Add((New-Object System.Drawing.PointF (256 + $rr * [Math]::Cos($a)), (256 + $rr * [Math]::Sin($a)))) }
$g.DrawLines($p4, $spiral.ToArray())
$rng = New-Object System.Random 7
$chars = $T.yantra.chars
for ($cell = 0; $cell -lt 9; $cell++) {
    if ($cell -eq 4) { continue }
    $cx0 = 36 + ($cell % 3) * 440 / 3; $cy0 = 36 + [Math]::Floor($cell / 3) * 440 / 3
    for ($j = 0; $j -lt 4; $j++) {
        $ch = $chars[$rng.Next($chars.Length)]
        Text $g ([string]$ch) $HEAD 54 $BOLD $ink ($cx0 + 8 + ($j % 2) * 64) ($cy0 + 10 + [Math]::Floor($j / 2) * 64) 60 60
    }
}
Save $bmp $g "Yantra"

# ---------------------------------------------------------------- 6. cardboard sign for the bottled-fuel rack (marker pen)
$c = NewCanvas 512 256; $bmp = $c[0]; $g = $c[1]
$g.Clear((C 176 140 96))
$g.FillRectangle((Brush (C 160 124 82)), 0, 120, 512, 6)
$g.TranslateTransform(256, 128); $g.RotateTransform(-3); $g.TranslateTransform(-256, -128)
Text $g $T.fuelsign.line1 $HEAD 120 $BOLD (C 24 20 18) 10 6 492 130
Text $g $T.fuelsign.line2 $HEAD 84 $BOLD (C 170 24 20) 10 130 492 110
Save $bmp $g "FuelSign"
