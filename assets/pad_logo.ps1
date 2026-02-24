Add-Type -AssemblyName System.Drawing

$sourcePath = "d:\3\3\BlackHole-main\assets\app_logo_v4.png"
$destPath = "d:\3\3\BlackHole-main\assets\app_logo_v4_aligned.png"

$image = [System.Drawing.Image]::FromFile($sourcePath)
$padding = 0.15 # 15% padding

$newWidth = [int]($image.Width * (1 + $padding))
$newHeight = [int]($image.Height * (1 + $padding))
$bmp = New-Object System.Drawing.Bitmap $newWidth, $newHeight

$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Black) # Black background

$x = ($newWidth - $image.Width) / 2
$y = ($newHeight - $image.Height) / 2

$g.DrawImage($image, $x, $y, $image.Width, $image.Height)

$bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)

$image.Dispose()
$bmp.Dispose()
$g.Dispose()

Write-Host "Created padded logo at $destPath"
