# =====================================================================
#  22aroma — генератор оформления профиля GitHub
#  Создаёт баннеры и иконки в папке ./assets
#  Запуск:  powershell -ExecutionPolicy Bypass -File tools\generate-assets.ps1
# =====================================================================

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$Root   = Split-Path -Parent $PSScriptRoot
$Assets = Join-Path $Root 'assets'
$Source = 'C:\Users\User\Desktop\desktop\icon\круг.png'
if (-not (Test-Path $Assets)) { New-Item -ItemType Directory -Force -Path $Assets | Out-Null }

# ----------------------------- палитра -------------------------------
$C = @{
  Bg1    = [System.Drawing.Color]::FromArgb(255, 11, 13, 18)    # почти чёрный
  Bg2    = [System.Drawing.Color]::FromArgb(255, 22, 26, 36)    # тёмный графит
  Bg3    = [System.Drawing.Color]::FromArgb(255, 34, 39, 53)
  Text   = [System.Drawing.Color]::FromArgb(255, 232, 237, 245)
  Muted  = [System.Drawing.Color]::FromArgb(255, 154, 164, 182)
  Pink   = [System.Drawing.Color]::FromArgb(255, 255, 122, 162)
  Violet = [System.Drawing.Color]::FromArgb(255, 177, 140, 255)
  Cyan   = [System.Drawing.Color]::FromArgb(255, 110, 231, 249)
}

# ------------------------- низкоуровневые хелперы --------------------
function New-Canvas([int]$w, [int]$h) {
    $script:Bmp = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $script:Bmp.SetResolution(144, 144)
    $script:G = [System.Drawing.Graphics]::FromImage($script:Bmp)
    $script:G.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $script:G.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $script:G.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $script:G.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $script:G.Clear([System.Drawing.Color]::Transparent)
}

function New-RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# мягкое радиальное свечение
function Add-Glow($g, [single]$cx, [single]$cy, [single]$r, $color, [int]$alpha) {
    for ($i = 7; $i -ge 1; $i--) {
        $rr  = $r * (0.3 + 0.7 * ($i / 7.0))
        $a   = [int]([Math]::Max(2, $alpha / 10.0 * (9 - $i)))
        $pth = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $pth.AddEllipse($cx - $rr, $cy - $rr, $rr * 2, $rr * 2)
        $br  = [System.Drawing.Drawing2D.PathGradientBrush]::new($pth)
        $br.CenterColor    = [System.Drawing.Color]::FromArgb($a, $color.R, $color.G, $color.B)
        $br.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $color.R, $color.G, $color.B))
        $g.FillEllipse($br, $cx - $rr, $cy - $rr, $rr * 2, $rr * 2)
        $br.Dispose(); $pth.Dispose()
    }
}

# градиент из нескольких цветов
function New-MultiBrush($rect, $colors, [single]$angle) {
    $br = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, $colors[0], $colors[-1], $angle)
    $blend = [System.Drawing.Drawing2D.ColorBlend]::new()
    $cs = [System.Drawing.Color[]]::new($colors.Count)
    $ps = [single[]]::new($colors.Count)
    for ($i = 0; $i -lt $colors.Count; $i++) {
        $cs[$i] = $colors[$i]
        $ps[$i] = if ($colors.Count -eq 1) { 0 } else { $i / ($colors.Count - 1) }
    }
    $blend.Colors    = $cs
    $blend.Positions = $ps
    $br.InterpolationColors = $blend
    return $br
}

$Typo     = [System.Drawing.StringFormat]::GenericTypographic
$BigArea  = [System.Drawing.SizeF]::new(40000, 40000)

# текст с трекингом (letter-spacing); возвращает занятую ширину
function Draw-Tracked($g, [string]$text, $font, $brush, [single]$x, [single]$y, [single]$track = 0) {
    $cx = $x
    foreach ($ch in $text.ToCharArray()) {
        $g.DrawString([string]$ch, $font, $brush, [System.Drawing.PointF]::new($cx, $y), $Typo)
        $cx += $g.MeasureString([string]$ch, $font, $BigArea, $Typo).Width + $track
    }
    return ($cx - $x - $track)
}
function Measure-Tracked($g, [string]$text, $font, [single]$track = 0) {
    $w = 0.0
    foreach ($ch in $text.ToCharArray()) { $w += $g.MeasureString([string]$ch, $font, $BigArea, $Typo).Width + $track }
    return [Math]::Max(0.0, $w - $track)
}

function Save-Png($bmp, $g, [string]$name) {
    $g.Dispose()
    $path = Join-Path $Assets $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("  {0,-22} {1,6} KB" -f $name, [Math]::Round((Get-Item $path).Length / 1KB, 1))
    $bmp.Dispose()
}

function Solid([int]$a, $color) { [System.Drawing.Color]::FromArgb($a, $color.R, $color.G, $color.B) }

# =====================================================================
#  1. Аватар: чистый и в неоновой рамке
# =====================================================================
Write-Host 'Аватар'
$src = [System.Drawing.Image]::FromFile($Source)

$catSize = 420
New-Canvas $catSize $catSize
$G.DrawImage($src, 0, 0, $catSize, $catSize)
Save-Png $Bmp $G 'cat.png'

$ring = 520
New-Canvas $ring $ring
Add-Glow $G ($ring / 2) ($ring / 2) 250 $C.Pink 120
Add-Glow $G ($ring / 2) ($ring / 2) 235 $C.Violet 75
$G.FillEllipse([System.Drawing.SolidBrush]::new((Solid 22 ([System.Drawing.Color]::White))), 38, 38, $ring - 76, $ring - 76)
$G.DrawEllipse([System.Drawing.Pen]::new((Solid 120 $C.Violet), 2),   16, 16, $ring - 32, $ring - 32)
$G.DrawEllipse([System.Drawing.Pen]::new((Solid 220 $C.Pink), 3),    34, 34, $ring - 68, $ring - 68)
$G.DrawImage($src, 50, 50, $ring - 100, $ring - 100)
Save-Png $Bmp $G 'avatar.png'
$src.Dispose()

# =====================================================================
#  2. Главный баннер
# =====================================================================
Write-Host 'Баннер'
$W = 1400; $H = 470
New-Canvas $W $H
$panel = New-RoundRect 0 0 $W $H 34
$G.SetClip($panel)

$G.FillRectangle((New-MultiBrush ([System.Drawing.Rectangle]::new(0, 0, $W, $H)) @($C.Bg1, $C.Bg2) 25), 0, 0, $W, $H)
$G.FillRectangle((New-MultiBrush ([System.Drawing.Rectangle]::new(0, 0, $W, $H)) @((Solid 0 ([System.Drawing.Color]::White)), $C.Bg3) 100), 0, 0, $W, $H)

Add-Glow $G 230  100 420 $C.Pink   95
Add-Glow $G 1230 380 400 $C.Cyan   70
Add-Glow $G 660  500 450 $C.Violet 80

# сетка точек
$dot = [System.Drawing.SolidBrush]::new((Solid 22 ([System.Drawing.Color]::White)))
for ($x = 22; $x -lt $W; $x += 26) {
    for ($y = 22; $y -lt $H; $y += 26) { $G.FillEllipse($dot, $x, $y, 2, 2) }
}

# диагональные лучи света
$ray = [System.Drawing.Drawing2D.GraphicsPath]::new()
$ray.AddPolygon(@(
    [System.Drawing.PointF]::new(-120, $H), [System.Drawing.PointF]::new(260, 0),
    [System.Drawing.PointF]::new(470, 0),    [System.Drawing.PointF]::new(60, $H)))
$G.FillPath([System.Drawing.SolidBrush]::new((Solid 5 ([System.Drawing.Color]::White))), $ray)

# --- текстовый блок ---
$nameFont = [System.Drawing.Font]::new('Segoe UI Black', 104, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$tagFont  = [System.Drawing.Font]::new('Cascadia Code', 32, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$chipFont = [System.Drawing.Font]::new('Cascadia Mono SemiBold', 22, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$nameW = $G.MeasureString('22aroma', $nameFont, $BigArea, $Typo).Width
$nameBrush = New-MultiBrush ([System.Drawing.Rectangle]::new(104, 100, [int]$nameW + 4, 130)) @($C.Pink, $C.Violet, $C.Cyan) 0

$shadow = [System.Drawing.SolidBrush]::new((Solid 45 $C.Pink))
$G.DrawString('22aroma', $nameFont, $shadow,   [System.Drawing.PointF]::new(109, 106), $Typo)
$G.DrawString('22aroma', $nameFont, $shadow,   [System.Drawing.PointF]::new(106, 103), $Typo)
$G.DrawString('22aroma', $nameFont, $nameBrush, [System.Drawing.PointF]::new(104, 100), $Typo)

Draw-Tracked $G 'КОД · КОТИКИ · КРАСОТА' $tagFont ([System.Drawing.SolidBrush]::new($C.Muted)) 108 248 3 | Out-Null

$G.FillRectangle((New-MultiBrush ([System.Drawing.Rectangle]::new(108, 308, 520, 3)) @((Solid 0 $C.Pink), $C.Pink, $C.Violet) 0), 108, 308, 520, 2)

$cx = 108
foreach ($chip in @('full-stack', 'design', 'open source')) {
    $chipW = [int][Math]::Round((Measure-Tracked $G $chip $chipFont 2)) + 58
    $rr = New-RoundRect $cx 342 $chipW 48 24
    $G.FillPath([System.Drawing.SolidBrush]::new((Solid 38 $C.Bg1)), $rr)
    $G.DrawPath([System.Drawing.Pen]::new((Solid 150 $C.Pink), 1.6), $rr)
    Draw-Tracked $G $chip $chipFont ([System.Drawing.SolidBrush]::new($C.Text)) ($cx + 29) 355 2 | Out-Null
    $cx += $chipW + 16
}

# моно-подпись справа снизу
$signFont = [System.Drawing.Font]::new('Cascadia Mono SemiBold', 21, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
Draw-Tracked $G '~/22aroma $ ' $signFont ([System.Drawing.SolidBrush]::new((Solid 150 $C.Muted))) 1096 402 2 | Out-Null
$G.FillRectangle([System.Drawing.SolidBrush]::new($C.Cyan), 1248, 400, 9, 20)

# --- кот справа ---
$cat  = [System.Drawing.Image]::FromFile((Join-Path $Assets 'cat.png'))
$catS = 296; $catX = 1000; $catY = 87
Add-Glow $G ($catX + $catS / 2) ($catY + $catS / 2) 265 $C.Pink 110
$G.DrawImage($cat, $catX, $catY, $catS, $catS)
$G.DrawEllipse([System.Drawing.Pen]::new((Solid 90 $C.Pink), 2), $catX, $catY, $catS, $catS)
$G.DrawEllipse([System.Drawing.Pen]::new((Solid 45 ([System.Drawing.Color]::White)), 1), ($catX + 5), ($catY + 5), ($catS - 10), ($catS - 10))
$cat.Dispose()

# угловые скобки
$br = [System.Drawing.Pen]::new((Solid 70 $C.Pink), 2.2)
foreach ($corner in @(@(34, 34, 1, 1), @(($W - 34), 34, -1, 1), @(34, ($H - 34), 1, -1), @(($W - 34), ($H - 34), -1, -1))) {
    $x0 = $corner[0]; $y0 = $corner[1]; $dx = $corner[2]; $dy = $corner[3]
    $G.DrawLine($br, $x0, $y0, ($x0 + 30 * $dx), $y0)
    $G.DrawLine($br, $x0, $y0, $x0, ($y0 + 30 * $dy))
}

$G.ResetClip()
$G.DrawPath([System.Drawing.Pen]::new((Solid 44 ([System.Drawing.Color]::White)), 1.4), $panel)
Save-Png $Bmp $G 'header.png'

# =====================================================================
#  3. Разделитель
# =====================================================================
New-Canvas 900 44
$mid = 450
Add-Glow $G $mid 22 46 $C.Pink 120
$G.FillRectangle((New-MultiBrush ([System.Drawing.Rectangle]::new(0, 0, $mid - 18, 2)) @((Solid 0 $C.Violet), $C.Violet) 0), 0, 21, $mid - 18, 2)
$G.FillRectangle((New-MultiBrush ([System.Drawing.Rectangle]::new($mid + 18, 0, $mid - 18, 2)) @($C.Cyan, (Solid 0 $C.Cyan)) 0), $mid + 18, 21, $mid - 18, 2)
$diamond = [System.Drawing.Drawing2D.GraphicsPath]::new()
$diamond.AddPolygon(@(
    [System.Drawing.PointF]::new($mid - 9, 22), [System.Drawing.PointF]::new($mid, 13),
    [System.Drawing.PointF]::new($mid + 9, 22), [System.Drawing.PointF]::new($mid, 31)))
$G.FillPath([System.Drawing.SolidBrush]::new($C.Text), $diamond)
Save-Png $Bmp $G 'divider.png'

# =====================================================================
#  4. Заголовки секций
# =====================================================================
Write-Host 'Заголовки секций'
$sections = [ordered]@{
    'sec-about.png'    = @('ОБО МНЕ',    $C.Pink)
    'sec-stack.png'    = @('СТЕК',       $C.Violet)
    'sec-stats.png'    = @('СТАТИСТИКА', $C.Cyan)
    'sec-projects.png' = @('ПРОЕКТЫ',    $C.Pink)
    'sec-contact.png'  = @('КОНТАКТЫ',   $C.Violet)
}
$secFont = [System.Drawing.Font]::new('Segoe UI Semibold', 30, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

foreach ($name in $sections.Keys) {
    $text   = $sections[$name][0]
    $accent = $sections[$name][1]
    $scratch = [System.Drawing.Bitmap]::new(8, 8)
    $sg = [System.Drawing.Graphics]::FromImage($scratch)
    $sg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $tw     = Measure-Tracked $sg $text $secFont 7
    $sg.Dispose(); $scratch.Dispose()
    $sh     = 80
    $dotR   = 12
    $textX  = 30 + $dotR * 2 + 34
    $sw     = [int]($textX + $tw + 46)
    New-Canvas $sw $sh

    Add-Glow $G ($sw / 2) ($sh / 2) ($sw / 2) $accent 90
    $pill = New-RoundRect 1 1 ($sw - 2) ($sh - 2) (($sh - 2) / 2)
    $G.FillPath((New-MultiBrush ([System.Drawing.Rectangle]::new(0, 0, $sw, $sh)) @((Solid 235 $C.Bg3), (Solid 235 $C.Bg1)) 90), $pill)
    $G.DrawPath([System.Drawing.Pen]::new((Solid 135 $accent), 1.8), $pill)

    $dcx = 30 + $dotR; $dcy = $sh / 2
    Add-Glow $G $dcx $dcy 30 $accent 220
    $G.FillEllipse([System.Drawing.SolidBrush]::new($accent), ($dcx - $dotR), ($dcy - $dotR), ($dotR * 2), ($dotR * 2))
    $G.FillEllipse([System.Drawing.SolidBrush]::new([System.Drawing.Color]::White), ($dcx - 4), ($dcy - 4), 8, 8)

    Draw-Tracked $G $text $secFont (New-MultiBrush ([System.Drawing.Rectangle]::new($textX, 0, $tw + 20, $sh)) @($C.Text, $accent) 0) $textX 21 7 | Out-Null
    Save-Png $Bmp $G $name
}

Write-Host "`nГотово -> $Assets"
