$ErrorActionPreference = "Stop"
. "$PSScriptRoot/Classes.ps1"

function Write-HostBuffer {
    param(
        [string] $Buffer
    )
    [Console]::SetCursorPosition(0,0)
    Write-Host -NoNewline $Buffer
}

Function Clear-HostAndHideCursor {
    Clear-Host
    [Console]::CursorVisible = $false
}

Function Reset-Host {
    Clear-Host
    [Console]::CursorVisible = $true
}

Function Convert-HsvToRgb {
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

# Two chars wide to compensate for character width vs height in a terminal window
Function Get-ColorBlock {
    param(
        [int] $R,
        [int] $G,
        [int] $B,
        [object] $Rgb,
        [switch] $Halfwidth
    )
    if(!$Rgb) {
        $Rgb = @{
            Red = $R
            Green = $G
            Blue = $B
        }
    }
    $spaces = if($Halfwidth) { " " } else { "  " }
    return "$([Char]27)[48;2;{0};{1};{2}m$spaces$([Char]27)[0m" -f $Rgb.Red, $Rgb.Green, $Rgb.Blue
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