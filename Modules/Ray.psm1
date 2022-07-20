$ErrorActionPreference = "Stop"
. "$PSScriptRoot/Classes.ps1"

function New-Ray {
    param(
        [System.Numerics.Vector3] $Origin,
        [System.Numerics.Vector3] $Direction
    )
    return [Ray]@{
        Origin = $Origin
        Direction = $Direction
    }
}

# https://raytracing.github.io/books/RayTracingInOneWeekend.html#rays,asimplecamera,andbackground/therayclass
function Get-RayPoint {
    param (
        [object] $Ray,
        [float] $T
    )
    $distance = $Ray.Direction * $T 
    $point = $Ray.Origin + $distance
    return $point
}

function Test-RayHitSphere {
    param (
        [object] $Ray,
        [float] $TMin,
        [float] $TMax,
        [object] $Sphere
    )

    $oc = $Ray.Origin - $Sphere.Center
    $a = $Ray.Direction.LengthSquared()
    $halfB = [System.Numerics.Vector3]::Dot($oc, $Ray.Direction)
    $c = $oc.LengthSquared() - ($Sphere.Radius * $Sphere.Radius)
    $discriminant = ($halfB * $halfB) - ($a * $c)

    if($discriminant -lt 0) {
        return $false
    }

    $sqrtd = [Math]::Sqrt($discriminant)

    $root = (-$halfB - $sqrtd) / $a;
    if ($root -lt $TMin -or $TMax -lt $root) {
        $root = (-$halfB + $sqrtd) / $a
        if ($root -lt $TMin -or $TMmax -lt $root) {
            return $false
        }
    }

    $hitPoint = Get-RayPoint -Ray $Ray -T $root
    $outwardNormal = ($hitPoint - $Sphere.Center) / $Sphere.Radius;

    # rec.set_face_normal(r, outward_normal);
    $frontFace = [System.Numerics.Vector3]::Dot($Ray.Direction, $outwardNormal) -lt 0
    $normal = if($frontFace) { $outwardNormal } else { -$outwardNormal }

    $hitRecord = [HitRecord]@{
        Point = $hitPoint
        Normal = $normal
        T = $root
        FrontFace = $frontFace
        Material = $Sphere.Material
    }

    return $hitRecord
}

function Get-RayClosestHit {
    param (
        [object] $Ray,
        [array] $Objects,
        [float] $TMin,
        [float] $TMax
    )
    $hitRecordForClosestObject = $null
    $closestSoFar = $TMax

    foreach($object in $Objects) {
        if($object -is [Sphere]) {
            $result = Test-RayHitSphere -Ray $Ray -Sphere $object -TMin $TMin -TMax $closestSoFar
            if($result) {
                $closestSoFar = $result.T
                $hitRecordForClosestObject = $result
            }
        }
    }

    return $hitRecordForClosestObject
}

function Get-RayColor {
    param (
        [object] $Ray,
        [array] $Scene,
        [int] $Depth,
        [string] $Diffuse
    )

    if ($Depth -le 0) {
        return [Rgb]@{
            Red = 0
            Green = 0
            Blue = 0
        }
    }

    $hitRecord = Get-RayClosestHit -Ray $Ray -TMin 0.001 -TMax ([float]::PositiveInfinity) -Objects $Scene

    $result = [Rgb]@{
        Red = 0
        Green = 0
        Blue = 0
    }

    # Fallback to generated background
    if($hitRecord) {
        if($Diffuse -eq "scattered") {
            # Material simulation
            $scattered = Get-VectorScattered -Ray $Ray -HitRecord $hitRecord
            if($scattered) {
                $color = Get-RayColor -Ray $scattered.Direction -Scene $Scene -Depth ($Depth - 1) -Diffuse $Diffuse
                $result = [Rgb]@{
                    Red = [Math]::Min($scattered.Attenuation.Red * $color.Red, 255)
                    Green = [Math]::Min($scattered.Attenuation.Green * $color.Green, 255)
                    Blue = [Math]::Min($scattered.Attenuation.Blue * $color.Blue, 255)
                }
            }
        } else {
            # Simple tracing
            $diffuseDirection = switch($Diffuse) {
                "simple" { Get-VectorRandomInUnitSphere }
                "lambertian" { Get-VectorRandomUnit }
                "hemispherical" { Get-VectorRandomInHemisphere -Normal $hitRecord.Normal }
                default { throw "Unknown diffuse type '$Diffuse'" }
            }

            $target = $hitRecord.Point + $hitRecord.Normal + $diffuseDirection
            $reflectedRay = New-Ray -Origin $hitRecord.Point -Direction ($target - $hitRecord.Point)
            $color = Get-RayColor -Ray $reflectedRay -Scene $Scene -Depth ($Depth - 1) -Diffuse $Diffuse
            $result = [Rgb]@{
                Red = [Math]::Min(0.5 * ($color.Red), 255)
                Green = [Math]::Min(0.5 * ($color.Green), 255)
                Blue = [Math]::Min(0.5 * ($color.Blue), 255)
            }
        }
    } else {
        $unitDirection = [System.Numerics.Vector3]::Normalize($Ray.Direction)
        $t = 0.5 * ($unitDirection.Y + 1.0)
        $start = [Rgb]@{
            Red = 255 * (1.0 - $t)
            Green = 255 * (1.0 - $t)
            Blue = 255 * (1.0 - $t)
        }
        $end = [Rgb]@{
            Red = 127 * $t
            Green = 178 * $t
            Blue = 255 * $t
        }
        $result = [Rgb]@{
            Red = [Math]::Min($start.Red + $end.Red, 255)
            Green = [Math]::Min($start.Green + $end.Green, 255)
            Blue = [Math]::Min($start.Blue + $end.Blue, 255)
        }
    }
    return $result
}

Export-ModuleMember -Function "*-*"