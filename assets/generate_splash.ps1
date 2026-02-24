Add-Type -AssemblyName System.Drawing

$sourcePath = "d:\3\3\BlackHole-main\assets\app_logo_v3_aligned.png"
$resPath = "d:\3\3\BlackHole-main\android\app\src\main\res"

# Map of density folders to dimensions (approximate standard sizes for splash icons)
# mdpi: 48x48 (1x) - but splash usually larger, let's go with 144x144 base for xxxhdpi = 4x
# actually for a centered usage in launch_background, we want it to be visible but not huge.
# let's assume base size 192x192 for xxxhdpi, scaling down.
# xxxhdpi (4x) = 192
# xxhdpi (3x) = 144
# xhdpi (2x) = 96
# hdpi (1.5x) = 72
# mdpi (1x) = 48
# Let's double these to ensure quality on high res screens: 384, 288, 192, 144, 96.

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
    $g.DrawImage($image, 0, 0, $size, $size)
    
    $bmp.Save($destFile, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $bmp.Dispose()
    $g.Dispose()
    
    Write-Host "Created $destFile ($size x $size)"
}

$image.Dispose()
