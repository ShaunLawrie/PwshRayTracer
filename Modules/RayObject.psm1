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
        $Rgb = Get-Rgb -R 255 -G 120 -B 120
    }
    return [sphere]@{
        Center = [vec3] @{
            X = $X
            Y = $Y
            Z = $Z
        }
        Radius = [float] $Radius
        Rgb = [rgb] $Rgb
    }
}

function Get-SphereIntersection {
    param(
        [object] $Sphere,
        [object] $Ray
    )
    $originCentered = Get-VectorSubtraction -Subtract $Sphere.Center -From $Ray.Origin
    $floatA = Get-VectorDotProduct -VectorA $Ray.Direction -VectorB $Ray.Direction
    $floatB = 2.0 * (Get-VectorDotProduct -VectorA $originCentered -VectorB $Ray.Direction)
    $floatC = (Get-VectorDotProduct -VectorA $originCentered -VectorB $originCentered) - ($Sphere.Radius * $Sphere.Radius)
    $discriminant = ($floatB * $floatB) - (4 * $floatA * $floatC)
    if($discriminant -lt 0) {
        # no hit
        return $null
    } else {
        $t = (($floatB * -1) - [math]::Sqrt($discriminant)) / (2.0 * $floatA)
        $distanceInDirection = Get-VectorScalarMultiple -Vector $Ray.Direction -Multiplier $t
        $point = Get-VectorAddition -Add $distanceInDirection -To $Ray.Origin
        return $point
    }
}

Export-ModuleMember -Function "*-*"