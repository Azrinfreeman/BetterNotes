Add-Type -AssemblyName System.Drawing

function New-RoundedPath([int]$x, [int]$y, [int]$width, [int]$height, [int]$radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

$size = 1024
$bitmap = [System.Drawing.Bitmap]::new($size, $size)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::FromArgb(255, 113, 81, 126))

$mint = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 170, 225, 202))
$peach = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 255, 177, 132))
$lemon = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 255, 229, 123))
$ink = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 80, 57, 89))

$back = New-RoundedPath 280 196 520 610 92
$graphics.FillPath($mint, $back)
$middle = New-RoundedPath 208 255 520 610 92
$graphics.FillPath($peach, $middle)
$front = New-RoundedPath 250 218 520 610 92
$graphics.FillPath($lemon, $front)

$graphics.FillRectangle($ink, 340, 360, 330, 28)
$graphics.FillRectangle($ink, 340, 440, 255, 28)
$graphics.FillRectangle($ink, 340, 520, 295, 28)
$graphics.FillRectangle($ink, 340, 600, 185, 28)

$output = Join-Path $PSScriptRoot '..\assets\icon.png'
$directory = Split-Path -Parent $output
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)

$back.Dispose()
$middle.Dispose()
$front.Dispose()
$mint.Dispose()
$peach.Dispose()
$lemon.Dispose()
$ink.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

Write-Output $output
