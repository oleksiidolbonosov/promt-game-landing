$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$sourceDir = Join-Path $repo 'VideoOutput/AppStore_EN'
$outDir = $PSScriptRoot
$sourceFiles = @(
    '01-home.png', '02-daily-challenge.png', '03-packs.png',
    '04-gameplay.png', '05-answer-options.png', '06-leaderboard.png'
)

function New-RoundedPath([float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Radius) {
    $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $d = $Radius * 2
    $p.AddArc($X, $Y, $d, $d, 180, 90)
    $p.AddArc($X + $Width - $d, $Y, $d, $d, 270, 90)
    $p.AddArc($X + $Width - $d, $Y + $Height - $d, $d, $d, 0, 90)
    $p.AddArc($X, $Y + $Height - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return ,$p
}

function New-PhoneImage([string]$InputPath, [string]$OutputPath) {
    $canvas = [System.Drawing.Bitmap]::new(1600, 2500, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $body = New-RoundedPath 220 150 1160 2180 172
    for ($i = 18; $i -ge 1; $i--) {
        $alpha = [Math]::Min(38, [int](38 * (19 - $i) / 18))
        $shadow = New-RoundedPath (220 + $i) (150 + 18 + $i) 1160 2180 172
        $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($alpha, 0, 120, 255))
        $g.FillPath($shadowBrush, $shadow)
        $shadowBrush.Dispose(); $shadow.Dispose()
    }

    $bodyRect = [System.Drawing.Rectangle]::new(220, 150, 1160, 2180)
    $bodyBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $bodyRect,
        [System.Drawing.Color]::FromArgb(255, 206, 218, 232),
        [System.Drawing.Color]::FromArgb(255, 42, 54, 75),
        12.0
    )
    $g.FillPath($bodyBrush, $body)
    $innerBody = New-RoundedPath 232 162 1136 2156 162
    $innerBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 7, 13, 26))
    $g.FillPath($innerBrush, $innerBody)

    # Physical side controls stay outside the display: no notch, status bar, island or safe-area overlay.
    $buttonBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.Rectangle]::new(0, 0, 30, 150),
        [System.Drawing.Color]::FromArgb(255, 158, 185, 214),
        [System.Drawing.Color]::FromArgb(255, 48, 71, 102),
        0.0
    )
    foreach ($r in @(
        (New-RoundedPath 207 470 19 126 8),
        (New-RoundedPath 207 625 19 126 8),
        (New-RoundedPath 207 782 19 92 8),
        (New-RoundedPath 1374 585 19 238 8)
    )) { $g.FillPath($buttonBrush, $r); $r.Dispose() }

    $screenPath = New-RoundedPath 260 280 1080 1920 104
    $screen = [System.Drawing.Image]::FromFile($InputPath)
    $g.SetClip($screenPath)
    $g.DrawImage($screen, [System.Drawing.Rectangle]::new(260, 280, 1080, 1920))
    $g.ResetClip()
    $screen.Dispose()

    $rimPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(215, 185, 215, 242), 3.2)
    $g.DrawPath($rimPen, $body)
    $screenRim = New-RoundedPath 253 273 1094 1934 111
    $screenPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(220, 78, 170, 255), 3)
    $g.DrawPath($screenPen, $screenRim)
    $innerRim = New-RoundedPath 267 287 1066 1906 96
    $innerPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(120, 207, 231, 255), 1.5)
    $g.DrawPath($innerPen, $innerRim)

    $canvas.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    foreach ($d in @($g, $body, $bodyBrush, $innerBody, $innerBrush, $buttonBrush, $screenPath, $rimPen, $screenRim, $screenPen, $innerRim, $innerPen, $canvas)) { if ($d) { $d.Dispose() } }
}

foreach ($name in $sourceFiles) {
    $inPath = Join-Path $sourceDir $name
    if (!(Test-Path -LiteralPath $inPath)) { throw "Missing source screenshot: $inPath" }
    $stem = [IO.Path]::GetFileNameWithoutExtension($name)
    New-PhoneImage $inPath (Join-Path $outDir ($stem + '-iphone.png'))
}

function Draw-CenteredPhone([System.Drawing.Graphics]$Graphics, [string]$Path, [float]$CenterX, [float]$CenterY, [float]$Width, [float]$Height, [float]$Angle) {
    $phone = [System.Drawing.Image]::FromFile($Path)
    $src = [System.Drawing.Rectangle]::new(150, 75, 1300, 2350)
    $state = $Graphics.Save()
    $Graphics.TranslateTransform($CenterX, $CenterY)
    $Graphics.RotateTransform($Angle)
    $dest = [System.Drawing.Rectangle]::new([int](-$Width / 2), [int](-$Height / 2), [int]$Width, [int]$Height)
    $Graphics.DrawImage($phone, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $Graphics.Restore($state)
    $phone.Dispose()
}

$hero = [System.Drawing.Bitmap]::new(3840, 2160, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$hg = [System.Drawing.Graphics]::FromImage($hero)
$hg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$hg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$hg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$hg.Clear([System.Drawing.Color]::FromArgb(255, 4, 12, 32))
$bg = [System.Drawing.Image]::FromFile((Join-Path $outDir 'website-cosmic-bg.png'))
$scale = [Math]::Max(3840.0 / $bg.Width, 2160.0 / $bg.Height)
$bgW = [int][Math]::Ceiling($bg.Width * $scale); $bgH = [int][Math]::Ceiling($bg.Height * $scale)
$hg.DrawImage($bg, [System.Drawing.Rectangle]::new([int]((3840 - $bgW) / 2), [int]((2160 - $bgH) / 2), $bgW, $bgH))
$bg.Dispose()

# A clean three-screen website hero: home, unanswered gameplay, and leaderboard.
Draw-CenteredPhone $hg (Join-Path $outDir '01-home-iphone.png') 720 1110 970 1753 -3.5
Draw-CenteredPhone $hg (Join-Path $outDir '05-answer-options-iphone.png') 1920 1050 1020 1844 0
Draw-CenteredPhone $hg (Join-Path $outDir '06-leaderboard-iphone.png') 3120 1110 970 1753 3.5
$hero.Save((Join-Path $outDir 'website-showcase-hero.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
$jpegParams = [System.Drawing.Imaging.EncoderParameters]::new(1)
$jpegParams.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality, [long]92)
$hero.Save((Join-Path $outDir 'website-showcase-hero.jpg'), $jpegCodec, $jpegParams)
$jpegParams.Dispose()
foreach ($d in @($hg, $hero)) { $d.Dispose() }

Write-Output "Built six full-bleed device mockups and website-showcase-hero.png in $outDir"
