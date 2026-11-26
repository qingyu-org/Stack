# FeatherStack 图标生成脚本
#
# 从矢量几何重新绘制标记，再按平台尺寸输出，避免从 1024px 位图反复缩放。
# 运行：powershell -NoProfile -ExecutionPolicy Bypass -File tools/generate_icons.ps1
#
# $markScale 控制标记相对 1024 画布的大小；0.70 比早期版本更小、留白更多。
Add-Type -AssemblyName System.Drawing

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$assets = Join-Path $root 'assets\icons'
$tmp = Join-Path $env:TEMP 'fs_icon_vector'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$markScale = 0.70
$white = [System.Drawing.Color]::FromArgb(255, 255, 255)
$darkBg = [System.Drawing.Color]::FromArgb(255, 11, 47, 39)
$jade = [System.Drawing.Color]::FromArgb(255, 14, 74, 58)
$ivory = [System.Drawing.Color]::FromArgb(255, 245, 241, 232)

function Draw-Mark($g, [int]$canvasSize, [System.Drawing.Color]$color, [int]$underlineAlpha) {
    $scale = ($canvasSize / 1024.0) * $markScale
    $state = $g.Save()
    $g.TranslateTransform($canvasSize / 2.0, $canvasSize / 2.0)
    $g.ScaleTransform($scale, $scale)
    $g.TranslateTransform(-512.0, -512.0)

    $brush = New-Object System.Drawing.SolidBrush($color)
    $underlineColor = [System.Drawing.Color]::FromArgb($underlineAlpha, $color.R, $color.G, $color.B)
    $underlinePen = New-Object System.Drawing.Pen($underlineColor, 16)
    $underlinePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $underlinePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($underlinePen, 338.0, 827.5, 681.0, 827.5)
    $underlinePen.Dispose()

    $linePen = New-Object System.Drawing.Pen($color, 24)
    $linePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $linePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $lines = @(
        @(520.0, 356.0, 642.0, 332.0),
        @(520.0, 447.0, 692.0, 421.0),
        @(520.0, 538.0, 722.0, 522.0),
        @(520.0, 630.0, 699.0, 630.0),
        @(520.0, 720.0, 641.0, 720.0)
    )
    foreach ($line in $lines) {
        $g.DrawLine($linePen, [single]$line[0], [single]$line[1], [single]$line[2], [single]$line[3])
    }
    $linePen.Dispose()

    $flag = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(330.0, 410.0),
        [System.Drawing.PointF]::new(414.0, 349.0),
        [System.Drawing.PointF]::new(414.0, 413.0),
        [System.Drawing.PointF]::new(330.0, 452.0)
    )
    $g.FillPolygon($brush, $flag)

    $stem = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 94.0
    $x = 414.0; $y = 236.0; $w = 94.0; $h = 564.0
    $stem.AddArc($x, $y, $r, $r, 180, 90)
    $stem.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
    $stem.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90)
    $stem.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
    $stem.CloseFigure()
    $g.FillPath($brush, $stem)
    $stem.Dispose()
    $brush.Dispose()

    $g.Restore($state)
}

function New-MasterFull([System.Drawing.Color]$bg, [System.Drawing.Color]$markColor, [string]$dest) {
    $size = 2048
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear($bg)
    Draw-Mark $g $size $markColor 51
    $g.Dispose()
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function New-MasterRounded([System.Drawing.Color]$bg, [System.Drawing.Color]$markColor, [string]$dest) {
    $size = 2048
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $inset = [int]($size * 0.08)
    $inner = [int]($size - 2 * $inset)
    $rect = [System.Drawing.Rectangle]::new($inset, $inset, $inner, $inner)
    $radius = [int]($inner * 0.225)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.SetClip($path)
    $brush = New-Object System.Drawing.SolidBrush($bg)
    $g.FillRectangle($brush, 0, 0, $size, $size)
    $brush.Dispose()
    Draw-Mark $g $size $markColor 51
    $g.ResetClip()
    $path.Dispose()
    $g.Dispose()
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function New-MasterForeground([System.Drawing.Color]$markColor, [string]$dest) {
    $size = 2048
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    Draw-Mark $g $size $markColor 51
    $g.Dispose()
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$lightFull = Join-Path $tmp 'light-full.png'
$darkFull = Join-Path $tmp 'dark-full.png'
$lightRounded = Join-Path $tmp 'light-rounded.png'
$darkRounded = Join-Path $tmp 'dark-rounded.png'
$lightFg = Join-Path $tmp 'light-fg.png'
$darkFg = Join-Path $tmp 'dark-fg.png'
$monoFg = Join-Path $tmp 'mono-fg.png'

New-MasterFull $white $jade $lightFull
New-MasterFull $darkBg $ivory $darkFull
New-MasterRounded $white $jade $lightRounded
New-MasterRounded $darkBg $ivory $darkRounded
New-MasterForeground $jade $lightFg
New-MasterForeground $ivory $darkFg
New-MasterForeground $white $monoFg

function Write-FromMaster([string]$master, [string]$dest, [int]$size, [bool]$opaque) {
    $src = [System.Drawing.Image]::FromFile($master)
    $format = if ($opaque) { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb } else { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb }
    $bmp = New-Object System.Drawing.Bitmap($size, $size, $format)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    if ($opaque) {
        $g.Clear([System.Drawing.Color]::White)
    } else {
        $g.Clear([System.Drawing.Color]::Transparent)
    }
    $rect = [System.Drawing.Rectangle]::new(0, 0, $size, $size)
    $g.DrawImage($src, $rect, 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $src.Dispose()
}

# In-app assets
Write-FromMaster $lightFull (Join-Path $assets 'featherstack-default.png') 1024 $true
Write-FromMaster $darkFull (Join-Path $assets 'featherstack-dark.png') 1024 $true
Write-FromMaster $lightFg (Join-Path $assets 'featherstack-foreground.png') 1024 $false
Write-FromMaster $monoFg (Join-Path $assets 'featherstack-monochrome.png') 1024 $false

# iOS app icons (opaque RGB, no alpha)
function Update-IosSet([string]$dir, [string]$master) {
    Get-ChildItem $dir -Filter '*.png' | ForEach-Object {
        if ($_.Name -match '-([0-9.]+)x([0-9.]+)@([0-9])x\.png$') {
            $size = [int][Math]::Round([double]$matches[1] * [int]$matches[3])
            if ($size -gt 0) { Write-FromMaster $master $_.FullName $size $true }
        }
    }
}
$iosAssets = Join-Path $root 'ios\Runner\Assets.xcassets'
Update-IosSet (Join-Path $iosAssets 'AppIcon.appiconset') $lightFull
Update-IosSet (Join-Path $iosAssets 'icon_2.appiconset') $lightFull
Update-IosSet (Join-Path $iosAssets 'icon_dark.appiconset') $darkFull

# iOS widget icons (rounded, transparent corners)
$widget = Join-Path $root 'ios\ServerStatusWidgetExtension\Assets.xcassets'
Write-FromMaster $lightRounded (Join-Path $widget 'MonoDashAppIconLight.imageset\MonoDashAppIconLight@2x.png') 120 $false
Write-FromMaster $lightRounded (Join-Path $widget 'MonoDashAppIconLight.imageset\MonoDashAppIconLight@3x.png') 180 $false
Write-FromMaster $darkRounded (Join-Path $widget 'MonoDashAppIconDark.imageset\MonoDashAppIconDark@2x.png') 120 $false
Write-FromMaster $darkRounded (Join-Path $widget 'MonoDashAppIconDark.imageset\MonoDashAppIconDark@3x.png') 180 $false

# macOS rounded icons
$mac = Join-Path $root 'macos\Runner\Assets.xcassets\AppIcon.appiconset'
foreach ($size in @(16, 32, 64, 128, 256, 512, 1024)) {
    Write-FromMaster $lightRounded (Join-Path $mac "app_icon_$size.png") $size $false
}

# Android icons
$androidRes = Join-Path $root 'android\app\src\main\res'
$densitySizes = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
$fgSizes = @{ 'mdpi' = 108; 'hdpi' = 162; 'xhdpi' = 216; 'xxhdpi' = 324; 'xxxhdpi' = 432 }
foreach ($density in $densitySizes.Keys) {
    $dir = Join-Path $androidRes "mipmap-$density"
    $legacy = $densitySizes[$density]
    Write-FromMaster $lightFull (Join-Path $dir 'ic_launcher.png') $legacy $true
    Write-FromMaster $lightFull (Join-Path $dir 'ic_launcher_2.png') $legacy $true
    Write-FromMaster $darkFull (Join-Path $dir 'ic_launcher_dark.png') $legacy $true
    $fg = $fgSizes[$density]
    Write-FromMaster $lightFg (Join-Path $dir 'ic_launcher_2_foreground.png') $fg $false
    Write-FromMaster $darkFg (Join-Path $dir 'ic_launcher_dark_foreground.png') $fg $false
    Write-FromMaster $monoFg (Join-Path $dir 'ic_launcher_2_monochrome.png') $fg $false
    Write-FromMaster $monoFg (Join-Path $dir 'ic_launcher_dark_monochrome.png') $fg $false
}

# Web icons
$web = Join-Path $root 'web'
Write-FromMaster $lightFull (Join-Path $web 'icons\Icon-192.png') 192 $true
Write-FromMaster $lightFull (Join-Path $web 'icons\Icon-512.png') 512 $true
Write-FromMaster $lightFull (Join-Path $web 'icons\Icon-maskable-192.png') 192 $true
Write-FromMaster $lightFull (Join-Path $web 'icons\Icon-maskable-512.png') 512 $true
Write-FromMaster $lightRounded (Join-Path $web 'favicon.png') 32 $false

# Windows ICO
$icoSizes = @(16, 24, 32, 48, 64, 128, 256)
$icoPngs = @()
foreach ($size in $icoSizes) {
    $p = Join-Path $tmp "ico-$size.png"
    Write-FromMaster $lightRounded $p $size $false
    $icoPngs += $p
}
$icoPath = Join-Path $root 'windows\runner\resources\app_icon.ico'
$fs = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$icoSizes.Count)
$offset = 6 + 16 * $icoSizes.Count
for ($i = 0; $i -lt $icoSizes.Count; $i++) {
    $size = $icoSizes[$i]
    $bytes = [System.IO.File]::ReadAllBytes($icoPngs[$i])
    $dim = if ($size -ge 256) { 0 } else { $size }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim)
    $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([UInt16]1); $bw.Write([UInt16]32)
    $bw.Write([UInt32]$bytes.Length); $bw.Write([UInt32]$offset)
    $offset += $bytes.Length
}
foreach ($p in $icoPngs) {
    $bw.Write([System.IO.File]::ReadAllBytes($p))
}
$bw.Flush(); $bw.Dispose(); $fs.Dispose()

Write-Output 'vector icons regenerated'
