$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot/ConsoleColors.psm1" -Force
Import-Module "$PSScriptRoot/ConsoleDrawing.psm1" -Force

Function Invoke-DrawPlasma {
    param (
        [int] $Frames,
        [int] $Width,
        [int] $Height
    )
    # use 2 characters per pixel because of terminal character height:width being ~2:1
    $pixelWidth = [Math]::Round($Width / 2.0, [MidpointRounding]::ToZero)
    $plasma = Get-Plasma -Width $pixelWidth -Height $Height
    $buffer = ""
    $hueShift = 0.0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    for ($f = 0; $f -lt $Frames; $f++) {
        for ($y = 0; $y -lt $Height; $y++) {
            for ($x = 0; $x -lt $pixelWidth; $x++) {
                $hue = ($hueShift + $plasma[$y][$x] % 1) * 360
                $rgb = Convert-HsvToRgb -Hue $hue -Saturation 1.0 -Value 1.0
                $buffer += Get-ColorBlock -R $rgb.Red -G $rgb.Green -B $rgb.Blue
            }
            $buffer += "`n"
        }
        Write-HostBuffer -Buffer $buffer
        $buffer = ""
        $hueShift = ($hueShift + 0.02) % 1
    }
    $fps = ($Frames / $stopwatch.ElapsedMilliseconds) * 1000
    Write-Host "FPS [$($fps)]      "
}

Export-ModuleMember -Function "Invoke-DrawPlasma"