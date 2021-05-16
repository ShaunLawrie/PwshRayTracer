$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Classes.ps1"
Import-Module "$PSScriptRoot/RayVector.psm1" -Force
Import-Module "$PSScriptRoot/ConsoleColors.psm1" -Force

function New-Sphere {
    param(
        [float] $X,
        [float] $Y,
        [float] $Z,
        [float] $Radius,
        [object] $Rgb
    )
    if(!$Rgb) {
        $Rgb = [Rgb](Get-Rgb -R 60 -G 40 -B 10)
    }
    return [sphere]@{
        X = [float] $X
        Y = [float] $Y
        Z = [float] $Z
        Radius = [float] $Radius
        Rgb = [rgb] $Rgb
    }
}

function Get-SphereIntersection {
    param(
        [object] $Sphere,
        [object] $Ray
    )
    if($Sphere.X -eq $Ray.X -and $Sphere.Y -eq $Ray.Y) {
        return $Ray
    } else {
        return $null
    }
}

Export-ModuleMember -Function "*-*"