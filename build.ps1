# Builds Pointer-O-MATIC.exe using the C# compiler built into Windows (.NET Framework 4.x).
# Run:  powershell -ExecutionPolicy Bypass -File build.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $root 'src\PointerOMatic.cs'
$ico  = Join-Path $root 'src\icon.ico'
$out  = Join-Path $root 'Pointer-O-MATIC.exe'
$csc  = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }

# Draw the app icon (red arrow) if it isn't there yet. Sizes stored as PNG images inside the .ico.
if (-not (Test-Path $ico)) {
    Add-Type -AssemblyName System.Drawing
    $sizes = 16, 32, 48, 256
    $images = foreach ($s in $sizes) {
        $bmp = New-Object System.Drawing.Bitmap $s, $s
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = 'AntiAlias'
        $m = $s * 0.08; $len = $s - 2 * $m; $t = $len * 0.75; $top = ($s - $t) / 2
        $head = $t * 0.9; $shaft = $t * 0.45; $hx = $m + $len - $head
        $pts = [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF $m, ($top + ($t - $shaft) / 2)),
            (New-Object System.Drawing.PointF $hx, ($top + ($t - $shaft) / 2)),
            (New-Object System.Drawing.PointF $hx, $top),
            (New-Object System.Drawing.PointF ($m + $len), ($top + $t / 2)),
            (New-Object System.Drawing.PointF $hx, ($top + $t)),
            (New-Object System.Drawing.PointF $hx, ($top + ($t + $shaft) / 2)),
            (New-Object System.Drawing.PointF $m, ($top + ($t + $shaft) / 2)))
        $g.FillPolygon([System.Drawing.Brushes]::Red, $pts)
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 0, 0, 0)), ([Math]::Max(1, $s / 32))
        $g.DrawPolygon($pen, $pts)
        $g.Dispose()
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        , $ms.ToArray()
    }
    $fs = [System.IO.File]::Create($ico)
    $w = New-Object System.IO.BinaryWriter $fs
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $s = $sizes[$i]; $dim = if ($s -ge 256) { 0 } else { $s }
        $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32)
        $w.Write([uint32]$images[$i].Length); $w.Write([uint32]$offset)
        $offset += $images[$i].Length
    }
    foreach ($img in $images) { $w.Write($img) }
    $w.Close()
    Write-Host "Created $ico"
}

& $csc /nologo /target:winexe /optimize+ /out:"$out" /win32icon:"$ico" `
    /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "$src"
if ($LASTEXITCODE -ne 0) { throw "Build failed" }
Write-Host "Built $out"

# Package a release zip: the .exe, README and LICENSE (the .ini is created on first run).
$version = [regex]::Match((Get-Content $src -Raw), 'AssemblyVersion\("(\d+)\.(\d+)').Groups
$zipName = "Pointer-O-MATIC-v$($version[1].Value).$($version[2].Value).zip"
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$zip = Join-Path $dist $zipName
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $out, (Join-Path $root 'README.md'), (Join-Path $root 'LICENSE') -DestinationPath $zip
Write-Host "Packaged $zip"
