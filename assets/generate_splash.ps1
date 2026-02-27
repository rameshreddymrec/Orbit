Add-Type -AssemblyName System.Drawing

$sourcePath = "d:\3\3\BlackHole-main\assets\orbit_logo_new.png"
$resPath = "d:\3\3\BlackHole-main\android\app\src\main\res"

$sizes = @{
    "mipmap-mdpi"    = 144
    "mipmap-hdpi"    = 216
    "mipmap-xhdpi"   = 288
    "mipmap-xxhdpi"  = 432
    "mipmap-xxxhdpi" = 576
}

$image = [System.Drawing.Image]::FromFile($sourcePath)

foreach ($folder in $sizes.Keys) {
    $size = $sizes[$folder]
    $destDir = Join-Path $resPath $folder
    $destFile = Join-Path $destDir "splash.png"

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir | Out-Null
    }

    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    
    # Add 10% padding to make logo "some small" while stable
    $padding = $size * 0.10
    $logoSize = $size - (2 * $padding)
    $g.DrawImage($image, $padding, $padding, $logoSize, $logoSize)
    
    $bmp.Save($destFile, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $bmp.Dispose()
    $g.Dispose()
    
    Write-Host "Created $destFile ($size x $size)"
}

$image.Dispose()
