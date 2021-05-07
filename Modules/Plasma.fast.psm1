# The faster you try make this the less "powershell" it actually is

$ErrorActionPreference = "Stop"

$Script:buffer = New-Object -TypeName "System.Text.StringBuilder" -ArgumentList 500000

Function Reset-HostBuffer {
    $Script:buffer.Clear() > $null
}

Function Clear-HostAndHideCursor {
    Clear-Host
    [Console]::CursorVisible = $false
}

Function Reset-Host {
    Clear-Host
    [Console]::CursorVisible = $true
}

# Plasma funcs

Function Invoke-DrawPlasmaFast {
    param (
        [int] $Frames,
        [int] $Width,
        [int] $Height
    )

    # use 2 characters per pixel because of terminal character height:width being ~2:1
    $pixelWidth = $Width / 2 - 1

    $hueShift = 0.0
    $plasma = Get-Plasma -Width $pixelWidth -Height $Height

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    for ($f = 0; $f -lt $Frames; $f++) {
        for ($y = 0; $y -lt $Height; $y++) {
            for ($x = 0; $x -lt $pixelWidth; $x++) {
                $H = (($hueShift + $plasma[$y][$x] % 1) * 360) / 60.0
                $XX = (1.0 - [Math]::Abs($H % 2 - 1))
                $rgb = @(0, 0, 0)

                $xIndex = (7 - [Math]::Floor($H)) % 3
                $cIndex = [int]($H / 2) % 3

                $rgb[$xIndex] = $XX
                $rgb[$cIndex] = 1.0

                $Script:buffer.Append(("$([Char]27)[48;2;{0};{1};{2}m  $([Char]27)[0m" -f [int]($rgb[0] * 255), [int]($rgb[1] * 255), [int]($rgb[2] * 255))) > $null
            }
            $Script:buffer.Append("`n") > $null
        }
        [Console]::SetCursorPosition(0,0)
        [Console]::Write($Script:buffer)
        $Script:buffer.Clear() > $null
        
        $hueShift = ($hueShift + 0.02) % 1
    }
    $fps = ($Frames / $stopwatch.ElapsedMilliseconds) * 1000
    Write-Host "FPS [$($fps)]      "
}

Function Get-Plasma {
    param (
        [int] $Width,
        [int] $Height
    )

    $plasma = @()

    for ($y = 0; $y -lt $Height; $y++) {
        $row = @()
        for ($x = 0; $x -lt $Width; $x++) {

            $value = [Math]::sin($x / 16.0)
            $value += [Math]::sin($y / 8.0)
            $value += [Math]::sin(($x + $y) / 16.0)
            $value += [Math]::sin([Math]::sqrt($x * $x + $y * $y) / 8.0)
            $value += 4 # shift range from -4 .. 4 to 0 .. 8
            $value /= 8 # bring range down to 0 .. 1

            if (-not ($value -ge 0.0 -and $value -le 1.0)) {
                throw "Hue value out of bounds"
            }
            $row += $value
        }
        $plasma += , $row
    }
    
    return $plasma
}

Export-ModuleMember -Function "Invoke-DrawPlasmaFast"