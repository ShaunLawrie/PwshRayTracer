$ErrorActionPreference = "Stop"
. "$PSScriptRoot/Classes.ps1"

function Convert-HsvToRgb {
    param(
        [double] $Hue,
        [double] $Saturation,
        [double] $Value
    )
    $chroma = $Value * $Saturation
    $H = $Hue / 60.0
    $X = $chroma * (1.0 - [Math]::Abs($H % 2 - 1))

    $m = $Value - $chroma
    $rgb = @($m, $m, $m)

    $xIndex = (7 - [Math]::Floor($H)) % 3
    $cIndex = [int]($H / 2) % 3

    $rgb[$xIndex] += $X
    $rgb[$cIndex] += $chroma

    return [Rgb]@{
        Red = [int]($rgb[0] * 255)
        Green = [int]($rgb[1] * 255)
        Blue = [int]($rgb[2] * 255)
    }
}

Function Get-Rgb {
    param(
        [int] $R,
        [int] $G,
        [int] $B
    )
    return [Rgb]@{
        Red = $R
        Green = $G
        Blue = $B
    }
}

Function Get-ColorBlock {
    param(
        [int] $R,
        [int] $G,
        [int] $B,
        [object] $Rgb
    )
    if(!$Rgb) {
        $Rgb = @{
            Red = $R
            Green = $G
            Blue = $B
        }
    }
    return "$([Char]27)[48;2;{0};{1};{2}m  $([Char]27)[0m" -f $Rgb.Red, $Rgb.Green, $Rgb.Blue
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

Export-ModuleMember -Function "*-*"